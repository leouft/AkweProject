import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_theme.dart';
import 'health_symptoms_screen.dart';

class BodyPartAsset {
  final String id;
  final String label;
  final String assetPath;

  const BodyPartAsset({
    required this.id,
    required this.label,
    required this.assetPath,
  });
}

class HealthBodyScreen extends StatefulWidget {
  const HealthBodyScreen({super.key});

  @override
  State<HealthBodyScreen> createState() => _HealthBodyScreenState();
}

class _HealthBodyScreenState extends State<HealthBodyScreen> {
  String? selectedBodyPartId;

  static const double _bodyWidth = 220;
  static const double _bodyHeight = 380;

  final List<BodyPartAsset> _bodyParts = const [
    BodyPartAsset(
      id: 'cabeca',
      label: 'Cabeça',
      assetPath: 'assets/images/cabeca.svg',
    ),
    BodyPartAsset(
      id: 'superior_dir',
      label: 'Superior direito',
      assetPath: 'assets/images/superior_dir.svg',
    ),
    BodyPartAsset(
      id: 'superior_esq',
      label: 'Superior esquerdo',
      assetPath: 'assets/images/superior_esq.svg',
    ),
    BodyPartAsset(
      id: 'braco_dir',
      label: 'Braço direito',
      assetPath: 'assets/images/braco_dir.svg',
    ),
    BodyPartAsset(
      id: 'braco_esq',
      label: 'Braço esquerdo',
      assetPath: 'assets/images/braco_esq.svg',
    ),
    BodyPartAsset(
      id: 'antebraco_dir',
      label: 'Antebraço direito',
      assetPath: 'assets/images/antebraço_dir.svg',
    ),
    BodyPartAsset(
      id: 'antebraco_esq',
      label: 'Antebraço esquerdo',
      assetPath: 'assets/images/antebraço_esq.svg',
    ),
    BodyPartAsset(
      id: 'mao_dir',
      label: 'Mão direita',
      assetPath: 'assets/images/mao_dir.svg',
    ),
    BodyPartAsset(
      id: 'mao_esq',
      label: 'Mão esquerda',
      assetPath: 'assets/images/mao_esq.svg',
    ),
    BodyPartAsset(
      id: 'coxa_esq_tela',
      label: 'Coxa (esquerda na tela)',
      assetPath: 'assets/images/coxaes.svg',
    ),
    BodyPartAsset(
      id: 'coxa_dir_tela',
      label: 'Coxa (direita na tela)',
      assetPath: 'assets/images/coxadi.svg',
    ),
    BodyPartAsset(
      id: 'canela_esq_tela',
      label: 'Canela (esquerda na tela)',
      assetPath: 'assets/images/canelaes.svg',
    ),
    BodyPartAsset(
      id: 'canela_dir_tela',
      label: 'Canela (direita na tela)',
      assetPath: 'assets/images/caneladi.svg',
    ),
    BodyPartAsset(
      id: 'pe_esq_tela',
      label: 'Pé (esquerdo na tela)',
      assetPath: 'assets/images/pees.svg',
    ),
    BodyPartAsset(
      id: 'pe_dir_tela',
      label: 'Pé (direito na tela)',
      assetPath: 'assets/images/ped.svg',
    ),
    BodyPartAsset(
      id: 'perna_esq_tela',
      label: 'Perna completa (esquerda na tela)',
      assetPath: 'assets/images/pernaes.svg',
    ),
    BodyPartAsset(
      id: 'perna_dir_tela',
      label: 'Perna completa (direita na tela)',
      assetPath: 'assets/images/pernadi.svg',
    ),
  ];

  String? _detectBodyPart(Offset localPos) {
    final double nx = localPos.dx / _bodyWidth;
    final double ny = localPos.dy / _bodyHeight;

    // Cabeça
    if (nx >= 0.38 && nx <= 0.62 && ny >= 0.02 && ny <= 0.18) {
      return 'cabeca';
    }

    // Lado esquerdo na tela
    if (nx < 0.50) {
      if (ny >= 0.17 && ny <= 0.29) return 'superior_esq';
      if (ny > 0.29 && ny <= 0.40) return 'braco_esq';
      if (ny > 0.40 && ny <= 0.50) return 'antebraco_esq';
      if (ny > 0.50 && ny <= 0.63) return 'mao_esq';
      if (ny > 0.63 && ny <= 0.76) return 'coxa_esq_tela';
      if (ny > 0.76 && ny <= 0.89) return 'canela_esq_tela';
      if (ny > 0.89 && ny <= 0.96) return 'pe_esq_tela';
    }

    // Lado direito na tela
    if (nx >= 0.50) {
      if (ny >= 0.17 && ny <= 0.29) return 'superior_dir';
      if (ny > 0.29 && ny <= 0.40) return 'braco_dir';
      if (ny > 0.40 && ny <= 0.50) return 'antebraco_dir';
      if (ny > 0.50 && ny <= 0.63) return 'mao_dir';
      if (ny > 0.63 && ny <= 0.76) return 'coxa_dir_tela';
      if (ny > 0.76 && ny <= 0.89) return 'canela_dir_tela';
      if (ny > 0.89 && ny <= 0.96) return 'pe_dir_tela';
    }

    return null;
  }

  void _handleTapDown(TapDownDetails details) {
    final String? hitId = _detectBodyPart(details.localPosition);
    if (hitId == null) return;

    setState(() {
      selectedBodyPartId = selectedBodyPartId == hitId ? null : hitId;
    });
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
              'Selecione uma parte do\ncorpo:',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: _handleTapDown,
                  child: SizedBox(
                    width: _bodyWidth,
                    height: _bodyHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        SvgPicture.asset(
                          'assets/images/content.svg',
                          fit: BoxFit.contain,
                        ),
                        for (final part in _bodyParts)
                          if (selectedBodyPartId == part.id)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: 0.75,
                                  child: SvgPicture.asset(
                                    part.assetPath,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: GestureDetector(
                onTap: selectedBodyPartId != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HealthSymptomsScreen(
                              bodyPart: selectedBodyPartId!,
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
                    color: selectedBodyPartId != null
                        ? AppTheme.accentBeige
                        : Colors.grey.shade300,
                    border: Border.all(
                      color: selectedBodyPartId != null
                          ? AppTheme.primary
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: selectedBodyPartId != null
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
