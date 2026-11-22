import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_theme.dart';

// --- TELA DA GRADE DE SINTOMAS (Saúde - 3 e Saúde - 4) ---
class HealthSymptomsScreen extends StatefulWidget {
  final String bodyPart;

  const HealthSymptomsScreen({super.key, required this.bodyPart});

  @override
  State<HealthSymptomsScreen> createState() => _HealthSymptomsScreenState();
}

class _HealthSymptomsScreenState extends State<HealthSymptomsScreen> {
  int? selectedSymptomIndex;

  // Todas as identificações possíveis para partes superiores do corpo humano
  static const Set<String> _upperLimbParts = {
    'superior',
    'superiores',
    'membro_superior',
    'membros_superiores',
    'superior_dir',
    'superior_esq',
    'braco',
    'bracos',
    'braco_dir',
    'braco_esq',
    'antebraco',
    'antebracos',
    'antebraco_dir',
    'antebraco_esq',
    'mao',
    'maos',
    'mao_dir',
    'mao_esq',
    'ombro',
    'ombros',
    'ombro_dir',
    'ombro_esq',
    'cotovelo',
    'cotovelos',
    'cotovelo_dir',
    'cotovelo_esq',
  };

  // Lista de sintomas da cabeça
  final List<Map<String, String>> headSymptoms = [
    {'label': 'Dor de cabeça', 'icon': 'assets/icons/dor_cabeca.svg'},
    {'label': 'Enxaqueca', 'icon': 'assets/icons/enxaqueca.svg'},
    {'label': 'Espirro/Gripe', 'icon': 'assets/icons/espirro_gripe.svg'},
    {'label': 'Tontura', 'icon': 'assets/icons/tontura.svg'},
    {'label': 'Febre', 'icon': 'assets/icons/febre.svg'},
    {'label': 'Tosse', 'icon': 'assets/icons/tosse.svg'},
    {
      'label': 'Problema de audição',
      'icon': 'assets/icons/problema_de_audicao.svg',
    },
    {'label': 'Manchas/Alergia', 'icon': 'assets/icons/manchas_alergia.svg'},
    {'label': 'Dor de dente', 'icon': 'assets/icons/dor_de_dente.svg'},
  ];

  // Lista de sintomas para membros superiores (braços, antebraços, mãos etc.)
  final List<Map<String, String>> upperLimbSymptoms = [
    {'label': 'Dormência na mão', 'icon': 'assets/icons/dormao.svg'},
    {'label': 'Dor no ombro', 'icon': 'assets/icons/dorombro.svg'},
    {'label': 'Dor no cotovelo', 'icon': 'assets/icons/dorcotovelo.svg'},
    {'label': 'Dor geral', 'icon': 'assets/icons/dorgeral.svg'},
    {'label': 'Fratura', 'icon': 'assets/icons/fratura.svg'},
    {'label': 'Dor no braço', 'icon': 'assets/icons/dorbraco.svg'},
    {'label': 'Ferimento na mão', 'icon': 'assets/icons/machucadom.svg'},
    {'label': 'Hematoma', 'icon': 'assets/icons/ematoma.svg'},
    {'label': 'Braço inchado', 'icon': 'assets/icons/bracoinchado.svg'},
    {'label': 'Queimação', 'icon': 'assets/icons/queimacao.svg'},
    {'label': 'Formigamento', 'icon': 'assets/icons/formigamento.svg'},
    {'label': 'Sensação de peso', 'icon': 'assets/icons/peso.svg'},
    {'label': 'Rigidez', 'icon': 'assets/icons/rigidez.svg'},
  ];

  bool get _isUpperLimb {
    final normalized = widget.bodyPart.trim().toLowerCase();
    if (_upperLimbParts.contains(normalized)) {
      return true;
    }
    return normalized.contains('superior') ||
        normalized.contains('braco') ||
        normalized.contains('antebraco') ||
        normalized.contains('mao') ||
        normalized.contains('ombro') ||
        normalized.contains('cotovelo');
  }

  List<Map<String, String>> get symptoms {
    if (_isUpperLimb) {
      return upperLimbSymptoms;
    }
    return headSymptoms;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saúde',
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
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'Selecione uma sintoma:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Grade de sintomas
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: GridView.builder(
                  itemCount: symptoms.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemBuilder: (context, index) {
                    final isSelected = selectedSymptomIndex == index;
                    final symptom = symptoms[index];

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedSymptomIndex = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.accentBeige
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppTheme.primary
                                : Colors.black.withOpacity(0.1),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SvgPicture.asset(
                          symptom['icon'] as String,
                          width: 36,
                          height: 36,
                          colorFilter: _isUpperLimb
                              ? null
                              : const ColorFilter.mode(
                                  AppTheme.primary,
                                  BlendMode.srcIn,
                                ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Botão Avançar
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: GestureDetector(
                onTap: selectedSymptomIndex != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HealthDetailScreen(
                              symptomName:
                                  symptoms[selectedSymptomIndex!]['label'] as String? ?? '',
                            ),
                          ),
                        );
                      }
                    : null,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selectedSymptomIndex != null
                        ? AppTheme.accentBeige
                        : Colors.grey.shade300,
                    border: Border.all(
                      color: selectedSymptomIndex != null
                          ? AppTheme.primary
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: selectedSymptomIndex != null
                        ? Colors.white
                        : Colors.grey.shade500,
                    size: 28,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- TELA DE DETALHE / RELATO DO SINTOMA (Saúde - 5) ---
class HealthDetailScreen extends StatelessWidget {
  final String symptomName;

  const HealthDetailScreen({super.key, required this.symptomName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Saúde',
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              const Text(
                'Sintoma:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 30),

              // Card 1: Relato do sintoma em akwe
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Text(
                      'Relato do sintoma\nem akwe...',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Card 2: Relato do sintoma em português
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Text(
                  'Relato do sintoma\nem português...',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              const Spacer(),

              // Botões inferiores (Confirmar / Cancelar)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botão Confirmar (Check)
                  GestureDetector(
                    onTap: () {
                      Navigator.popUntil(context, (route) => route.isFirst);
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentBeige,
                        border: Border.all(color: AppTheme.primary, width: 2),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),

                  // Botão Cancelar (X)
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentBeige,
                        border: Border.all(color: AppTheme.primary, width: 2),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}