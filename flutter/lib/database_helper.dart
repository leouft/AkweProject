import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

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
      version: 3,
      onCreate: _onCreate,
    );
  }

  // Cria a tabela na primeira vez que o app abre
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE palavras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        akwe TEXT,
        portugues TEXT,
        significado TEXT
      )
    ''');
  }

  Future<void> sincronizarComApi() async {
    try {
      // endereço da api que sincroniza
      final url = Uri.parse('http://192.168.5.107:8000/api/sync'); 
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> listaDePalavras = json.decode(response.body);
        final db = await database;

        // Limpa todo o banco de dados
        await db.delete('palavras');

        // Insere o banco 100% atualizado da API
        for (var item in listaDePalavras) {
          await db.insert(
            'palavras',
            {
              'akwe': item['akwe'],          // Coluna conforme sua API retorna
              'portugues': item['portugues'],
              'significado': item['significado'],
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

  // Método para buscar todas as palavras cadastradas no banco
  Future<List<Map<String, dynamic>>> getPalavras() async {
    final db = await database;
    return await db.query('palavras');
  }

  // Método para buscar uma palavra específica
  Future<List<Map<String, dynamic>>> searchPalavras(String query) async {
    final db = await database;
    
    // Se a busca estiver vazia, retorna todas as palavras
    if (query.trim().isEmpty) {
      return await getPalavras();
    }

    // Faz a consulta no SQLite filtrando com LIKE
    return await db.query(
      'palavras',
      where: 'akwe LIKE ? OR portugues LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
  } 
}