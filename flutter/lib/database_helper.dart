import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
      version: 9,
      onCreate: _onCreate,
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
        tags TEXT
      )
    ''');
  }

  Future<void> sincronizarComApi() async {
    try {
      // endereço da api que sincroniza
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
            },
            conflictAlgorithm: ConflictAlgorithm.replace, // Substitui se já existir ID igual
          );
        }
        print("Sincronização realizada com sucesso!");
      }
    } catch (e) {
      print("Erro ao conectar com a API FastAPI: $e");
    }
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