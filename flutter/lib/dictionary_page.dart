import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'database_helper.dart';

class HomePage extends StatefulWidget {
  final String title;
  const HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Controle de qual item está expandido (por índice)
  int? expandedIndex = null;

  // Instância do ajudante de banco de dados
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 1. Inicializamos o future diretamente buscando o que já está no SQLite local
  late Future<List<Map<String, dynamic>>> _futurePalavras = _dbHelper.getPalavras();

  @override
  void initState() {
    super.initState();
    // 2. Disparamos a sincronização com a API em segundo plano
    _sincronizarESincronizarDados();
  }

  // Função que busca na API e atualiza a tela se houver novos dados
  Future<void> _sincronizarESincronizarDados() async {
    try {
      await _dbHelper.sincronizarComApi();
      
      // Garante que o widget ainda está ativo na tela antes de atualizar o estado
      if (mounted) {
        setState(() {
          // Atualiza o Future para recarregar com os dados novos que vieram do FastAPI
          _futurePalavras = _dbHelper.getPalavras();
        });
      }
    } catch (e) {
      print("Erro na sincronização em segundo plano: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dicionário',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: AppTheme.primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 1. Campo de busca fixo no topo
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'O que você procura?',
                  hintStyle: TextStyle(
                    color: AppTheme.primary.withOpacity(0.5),
                    fontStyle: FontStyle.italic,
                  ),
                  border: InputBorder.none,
                  suffixIcon: Icon(
                    Icons.search,
                    color: AppTheme.primary.withOpacity(0.7),
                  ),
                ),
                onChanged: (valor) {
                  setState(() {
                    _futurePalavras = _dbHelper.searchPalavras(valor);
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // 2. A lista de palavras com Expanded (fazendo o ListView rolar nativamente)
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _futurePalavras,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Erro ao carregar dados: ${snapshot.error}'),
                    );
                  }

                  final List<Map<String, dynamic>> words = snapshot.data ?? [];

                  if (words.isEmpty) {
                    return const Center(
                      child: Text('Nenhuma palavra encontrada no banco.'),
                    );
                  }

                  // Agora o ListView.builder gerencia a rolagem sozinho de forma ultra eficiente
                  return ListView.builder(
                    itemCount: words.length,
                    itemBuilder: (context, index) {
                      final isExpanded = expandedIndex == index;
                      final item = words[index];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            expandedIndex = isExpanded ? null : index;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.black.withOpacity(0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item['akwe'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.volume_up_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['portugues'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.primary.withOpacity(0.7),
                                ),
                              ),
                              if (isExpanded) ...[
                                const SizedBox(height: 10),
                                Text(
                                  item['significado'] ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.primary.withOpacity(0.8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  height: 120,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.black38,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.image_outlined,
                                      size: 36,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Icon(
                                  isExpanded
                                      ? Icons.arrow_drop_down
                                      : Icons.arrow_right,
                                  color: AppTheme.primary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}