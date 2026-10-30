import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import 'app_theme.dart';
import 'database_helper.dart';

class HomePage extends StatefulWidget {
  final String title;
  const HomePage({super.key, required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _audioPlayer = AudioPlayer();

  // Controle de qual item está expandido (por índice)
  int? expandedIndex;

  // Instância do ajudante de banco de dados
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Buscar dados locais ao iniciar
  late Future<List<Map<String, dynamic>>> _futurePalavras = _dbHelper
      .getPalavras();

  // Paginação
  static const int _itensPorPagina = 5;
  int _paginaAtual = 0;

  // controle para entrada manual da página
  final TextEditingController _pageInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _sincronizarESincronizarDados();
  }

  @override
  void dispose() {
    _pageInputController.dispose();
    super.dispose();
  }

  Future<void> _sincronizarESincronizarDados() async {
    try {
      await _dbHelper.sincronizarComApi();

      if (mounted) {
        setState(() {
          _futurePalavras = _dbHelper.getPalavras();
          _paginaAtual = 0;
          expandedIndex = null;
          _pageInputController.text = (_paginaAtual + 1).toString();
        });
      }
    } catch (e) {
      print("Erro na sincronização em segundo plano: $e");
    }
  }

  void _irParaPagina(int pagina, int totalPaginas) {
    if (pagina < 1 || pagina > totalPaginas) {
      return;
    }

    setState(() {
      _paginaAtual = pagina - 1;
      expandedIndex = null;
      _pageInputController.text = pagina.toString();
    });
  }

  List<int> _paginasParaExibir(int totalPaginas) {
    final paginas = <int>[];

    if (totalPaginas <= 7) {
      for (int i = 1; i <= totalPaginas; i++) {
        paginas.add(i);
      }
      return paginas;
    }

    // Sempre mostra primeira página
    paginas.add(1);

    if (_paginaAtual > 3) {
      paginas.add(-1); // ellipsis
    }

    final inicio = (_paginaAtual < 3) ? 2 : _paginaAtual - 1;
    final fim = (_paginaAtual > totalPaginas - 4)
        ? totalPaginas - 1
        : _paginaAtual + 1;

    for (int i = inicio; i <= fim; i++) {
      if (i > 1 && i < totalPaginas) {
        paginas.add(i);
      }
    }

    if (_paginaAtual < totalPaginas - 3) {
      paginas.add(-1); // ellipsis
    }

    // sempre mostra última página
    paginas.add(totalPaginas);

    // remove duplicados
    final semDuplicados = <int>[];
    for (final p in paginas) {
      if (p == -1) {
        semDuplicados.add(-1);
      } else if (!semDuplicados.contains(p)) {
        semDuplicados.add(p);
      }
    }

    return semDuplicados;
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
            // Campo de busca
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
                    _paginaAtual = 0;
                    expandedIndex = null;
                    _futurePalavras = _dbHelper.searchPalavras(valor);
                    _pageInputController.text = '1';
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

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

                  final totalPaginas = (words.length / _itensPorPagina).ceil();

                  if (_paginaAtual >= totalPaginas) {
                    _paginaAtual = totalPaginas - 1;
                  }

                  _pageInputController.text = (_paginaAtual + 1).toString();

                  final start = _paginaAtual * _itensPorPagina;
                  final end = math.min(start + _itensPorPagina, words.length);
                  final paginaAtual = words.sublist(start, end);

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: paginaAtual.length,
                          itemBuilder: (context, index) {
                            final isExpanded = expandedIndex == index;
                            final item = paginaAtual[index];

                            final tags =
                                (item['tags'] as List<dynamic>? ?? const [])
                                    .map((e) => e.toString().trim())
                                    .where((e) => e.isNotEmpty)
                                    .toList();

                            final tagText = tags.isEmpty
                                ? 'tag • tag • tag'
                                : tags.join(' • ');

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
                                        if (item['audio_url'] != null &&
                                            item['audio_url']
                                                .toString()
                                                .isNotEmpty)
                                          GestureDetector(
                                            onTap: () async {
                                              try {
                                                await _audioPlayer.play(
                                                  DeviceFileSource(
                                                    item['local_audio_path'],
                                                  ),
                                                );
                                              } catch (e) {
                                                print(
                                                  "Erro ao reproduzir áudio: $e",
                                                );
                                              }
                                            },
                                            child: Container(
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
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item['portugues'] ?? '',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.primary.withOpacity(
                                          0.7,
                                        ),
                                      ),
                                    ),
                                    if (isExpanded) ...[
                                      const SizedBox(height: 10),
                                      Text(
                                        item['significado'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppTheme.primary.withOpacity(
                                            0.8,
                                          ),
                                        ),
                                      ),
                                      if (item['local_media_path'] != null &&
                                          item['local_media_path']
                                              .toString()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.black38,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: Image.file(
                                              File(item['local_media_path']),
                                              fit: BoxFit.contain,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return const Center(
                                                      child: Padding(
                                                        padding: EdgeInsets.all(
                                                          20.0,
                                                        ),
                                                        child: Icon(
                                                          Icons.broken_image,
                                                          size: 36,
                                                          color: Colors.black45,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],

                                    const SizedBox(height: 8),

                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: SingleChildScrollView(
                                              scrollDirection: Axis.horizontal,
                                              child: Text(
                                                tagText,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppTheme.primary
                                                      .withOpacity(0.65),
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        TextButton(
                                          onPressed: () {},
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                            backgroundColor: AppTheme.primary
                                                .withOpacity(0.08),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                          ),
                                          child: Text(
                                            'avalie',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

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
                        ),
                      ),

                      if (totalPaginas > 1)
                        Container(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Row(
                            children: [
                              // botão anterior
                              SizedBox(
                                width: 28,
                                child: IconButton(
                                  onPressed: _paginaAtual > 0
                                      ? () {
                                          setState(() {
                                            _paginaAtual--;
                                            expandedIndex = null;
                                            _pageInputController.text =
                                                (_paginaAtual + 1).toString();
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.chevron_left),
                                  color: AppTheme.primary,
                                  splashRadius: 18,
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ),

                              // numeração das páginas
                              Expanded(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 0,
                                  children: () {
                                    final paginas = _paginasParaExibir(
                                      totalPaginas,
                                    );

                                    return paginas.map((p) {
                                      if (p == -1) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            '...',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        );
                                      }

                                      final selected = p == _paginaAtual + 1;

                                      return InkWell(
                                        onTap: () =>
                                            _irParaPagina(p, totalPaginas),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Text(
                                            '$p',
                                            style: TextStyle(
                                              fontSize: selected ? 15 : 13,
                                              color: selected
                                                  ? AppTheme.primary
                                                  : AppTheme.primary
                                                        .withOpacity(0.7),
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList();
                                  }(),
                                ),
                              ),

                              // botão próximo
                              SizedBox(
                                width: 28,
                                child: IconButton(
                                  onPressed: _paginaAtual < totalPaginas - 1
                                      ? () {
                                          setState(() {
                                            _paginaAtual++;
                                            expandedIndex = null;
                                            _pageInputController.text =
                                                (_paginaAtual + 1).toString();
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.chevron_right),
                                  color: AppTheme.primary,
                                  splashRadius: 18,
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ),

                              // campo de página
                              const SizedBox(width: 10),
                              SizedBox(
                                width: 44,
                                child: TextField(
                                  controller: _pageInputController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  onSubmitted: (valor) {
                                    final valorInt = int.tryParse(valor);
                                    if (valorInt != null) {
                                      _irParaPagina(valorInt, totalPaginas);
                                    }
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary.withOpacity(
                                          0.25,
                                        ),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary.withOpacity(
                                          0.25,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: AppTheme.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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
