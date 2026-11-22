import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Caminho onde o banco SQLite fica salvo no celular
    String path = join(await getDatabasesPath(), 'dicionario_akwe.db');
    
    return await openDatabase(
      path,
      version: 14,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 14) {
          await db.execute(
            'ALTER TABLE palavras '
            'ADD COLUMN quantidade_consultas INTEGER DEFAULT 0',
          );
          await db.execute(
            'ALTER TABLE palavras '
            'ADD COLUMN reproducoes_audio INTEGER DEFAULT 0',
          );
        }
      },
    );
  }

  // Cria a tabela na primeira vez que o app abre
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE palavras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        id_traducao INTEGER,
        akwe TEXT,
        portugues TEXT,
        significado TEXT,
        audio_url TEXT,
        media_url TEXT,
        local_audio_path TEXT,
        local_media_path TEXT,
        tags TEXT,
        nivel_clareza REAL,
        quantidade_avaliacoes INTEGER DEFAULT 0,
        quantidade_consultas INTEGER DEFAULT 0,
        reproducoes_audio INTEGER DEFAULT 0,
        atualizado_em TEXT
      )
    ''');
  }

  Future<bool> sincronizarComApi() async {
    try {
      // 1. Consulta os metadados leves do servidor primeiro
      final metaUrl = Uri.parse('${Config.baseUrl}/api/sync/meta');
      final metaResponse = await http.get(metaUrl);

      if (metaResponse.statusCode == 200) {
        final servidorMeta = json.decode(metaResponse.body);
        final int servidorTotal = servidorMeta['total_registros'] ?? 0;
        final int servidorMaxId = servidorMeta['max_id'] ?? 0;
        final String? servidorUltimaAtualizacao = servidorMeta['ultima_atualizacao'];

        // 2. Consulta o estado atual do SQLite local
        final db = await database;
        final localCountResult = await db.rawQuery('SELECT COUNT(*) as count, MAX(id_traducao) as max_id, MAX(atualizado_em) as ultima_atualizacao FROM palavras');
        
        if (localCountResult.isNotEmpty) {
          final localRow = localCountResult.first;
          final int localTotal = (localRow['count'] as int?) ?? 0;
          final int localMaxId = (localRow['max_id'] as int?) ?? 0;
          final String? localUltimaAtualizacao = localRow['ultima_atualizacao'] as String?;

          // 3. Se os metadados forem idênticos, NENHUMA alteração ocorreu. Ignora o sync pesado!
          if (localTotal == servidorTotal && 
              localMaxId == servidorMaxId && 
              localUltimaAtualizacao == servidorUltimaAtualizacao) {
            print("Banco local já está atualizado. Sincronização ignorada.");
            return false;
          }
        }
      }
        
      // 4. Se houver alterações, baixa a lista completa do /api/sync
      final url = Uri.parse('${Config.baseUrl}/api/sync'); 
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> listaDePalavras = json.decode(response.body);
        final db = await database;
        final appDir = await getApplicationDocumentsDirectory();

        // Limpa todo o banco de dados
        await db.delete('palavras');

        // Insere o banco 100% atualizado da API
        for (var item in listaDePalavras) {
          String? localAudioPath;
          String? localMediaPath;

          if (item['media_url'] != null && item['media_url'].toString().isNotEmpty) {
            try {
              final mediaUri = Uri.parse(item['media_url']);
              final mediaResponse = await http.get(mediaUri);
              if (mediaResponse.statusCode == 200) {
                final fileName = basename(mediaUri.path);
                final localFile = File('${appDir.path}/$fileName');
                await localFile.writeAsBytes(mediaResponse.bodyBytes);
                localMediaPath = localFile.path;
              }
            } catch (e) {
              print("Erro ao baixar mídia do Supabase: $e");
            }
          }

          if (item['audio_url'] != null && item['audio_url'].toString().isNotEmpty) {
            try {
              final audioUri = Uri.parse(item['audio_url']);
              final audioResponse = await http.get(audioUri);
              if (audioResponse.statusCode == 200) {
                final fileName = basename(audioUri.path);
                final localFile = File('${appDir.path}/$fileName');
                await localFile.writeAsBytes(audioResponse.bodyBytes);
                localAudioPath = localFile.path;
              }
            } catch (e) {
              print("Erro ao baixar áudio do Supabase: $e");
            }
          }

          await db.insert(
            'palavras',
            {
              'id_traducao': item['id_traducao'],
              'akwe': item['akwe'],          
              'portugues': item['portugues'],
              'significado': item['significado'],
              'audio_url': item['audio_url'],
              'media_url': item['media_url'],
              'local_audio_path': localAudioPath,
              'local_media_path': localMediaPath,
              'tags': jsonEncode(item['tags'] ?? []),
              'nivel_clareza':
                (item['nivel_clareza'] as num?)?.toDouble() ?? 0.0,
              'quantidade_avaliacoes':
                item['quantidade_avaliacoes'] ?? 0,
              'quantidade_consultas':
                item['quantidade_consultas'] ?? 0,
              'reproducoes_audio':
                item['reproducoes_audio'] ?? 0,
              'atualizado_em': item['atualizado_em'],
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        print("Sincronização realizada com sucesso!");
        return true;
      }
    } catch (e) {
      print("Erro ao conectar com a API FastAPI: $e");
    }
    return false;
  }

  Future<Map<String, dynamic>> buscarAvaliacao(int idTraducao) async {
    final prefs = await SharedPreferences.getInstance();

    String? avaliadorId = prefs.getString('avaliador_id');
    avaliadorId ??= const Uuid().v4();
    await prefs.setString('avaliador_id', avaliadorId);

    final url = Uri.parse(
      '${Config.baseUrl}/api/traducoes/$idTraducao/clareza'
      '?avaliador_id=${Uri.encodeQueryComponent(avaliadorId)}',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Erro ao buscar avaliação');
    }

    return json.decode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> atualizarClareza(
    int idTraducao,
    int novaClareza,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    String? avaliadorId = prefs.getString('avaliador_id');
    avaliadorId ??= const Uuid().v4();
    await prefs.setString('avaliador_id', avaliadorId);

    final url = Uri.parse(
      '${Config.baseUrl}/api/traducoes/$idTraducao/clareza',
    );

    final response = await http.patch(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'nivel_clareza': novaClareza,
        'avaliador_id': avaliadorId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao enviar avaliação: ${response.statusCode}',
      );
    }

    final resultado =
        json.decode(response.body) as Map<String, dynamic>;

    final db = await database;
    await db.update(
      'palavras',
      {
        'nivel_clareza':
            (resultado['nivel_clareza'] as num).toDouble(),
        'quantidade_avaliacoes':
            resultado['quantidade_avaliacoes'] ?? 0,
      },
      where: 'id_traducao = ?',
      whereArgs: [idTraducao],
    );

    return resultado;
  }

  Future<bool> registrarConsulta(int idTraducao) async {
    try {
      final url = Uri.parse(
        '${Config.baseUrl}/api/traducoes/$idTraducao/consultar',
      );
      final response = await http.patch(url);

      if (response.statusCode == 200) {
        final resultado =
            json.decode(response.body) as Map<String, dynamic>;
        final db = await database;

        await db.update(
          'palavras',
          {
            'quantidade_consultas':
                resultado['quantidade_consultas'] ?? 0,
          },
          where: 'id_traducao = ?',
          whereArgs: [idTraducao],
        );
        return true;
      }

      print(
        'Erro ao registrar consulta: '
        '${response.statusCode} ${response.body}',
      );
    } catch (e) {
      print("Erro ao registrar consulta: $e");
    }
    return false;
  }

  Future<bool> registrarReproducaoAudio(int idTraducao) async {
    try {
      final url = Uri.parse(
        '${Config.baseUrl}/api/traducoes/$idTraducao/reproduzir-audio',
      );
      final response = await http.patch(url);

      if (response.statusCode == 200) {
        final resultado =
            json.decode(response.body) as Map<String, dynamic>;
        final db = await database;

        await db.update(
          'palavras',
          {
            'reproducoes_audio':
                resultado['reproducoes_audio'] ?? 0,
          },
          where: 'id_traducao = ?',
          whereArgs: [idTraducao],
        );
        return true;
      }

      print(
        'Erro ao registrar reprodução: '
        '${response.statusCode} ${response.body}',
      );
    } catch (e) {
      print("Erro ao registrar reprodução de áudio: $e");
    }
    return false;
  }

  // Helper para converter o campo 'tags' de string JSON para List<dynamic>
  List<Map<String, dynamic>> _formatarPalavras(
    List<Map<String, Object?>> maps,
  ) {
    return maps.map((map) {
      final novoMap = Map<String, dynamic>.from(map);

      if (novoMap['tags'] is String) {
        try {
          novoMap['tags'] = jsonDecode(novoMap['tags']);
        } catch (_) {
          novoMap['tags'] = [];
        }
      } else {
        novoMap['tags'] ??= [];
      }

      return novoMap;
    }).toList();
  }

  // Método para buscar todas as palavras cadastradas no banco
  Future<List<Map<String, dynamic>>> getPalavras() async {
    final db = await database;
    final resultado = await db.query('palavras');
    return _formatarPalavras(resultado);
  }

  // Método para buscar uma palavra específica
  Future<List<Map<String, dynamic>>> searchPalavras(String query) async {
    final db = await database;

    if (query.trim().isEmpty) {
      return getPalavras();
    }

    final resultado = await db.query(
      'palavras',
      where: 'akwe LIKE ? OR portugues LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );

    return _formatarPalavras(resultado);
  }
}