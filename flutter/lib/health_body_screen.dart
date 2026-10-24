import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_theme.dart';
import 'health_symptoms_screen.dart';

class HealthBodyScreen extends StatefulWidget {
  const HealthBodyScreen({super.key});

  @override
  State<HealthBodyScreen> createState() => _HealthBodyScreenState();
}

class _HealthBodyScreenState extends State<HealthBodyScreen> {
  String? selectedBodyPart;

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

            // Exibição da silhueta SVG do Figma com foco isolado na cabeça
            // Exibição da silhueta SVG do Figma com alinhamento perfeito
            Expanded(
              child: Center(
                child: SizedBox(
                  width: 200,
                  height: 380,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Corpo inteiro estático ao fundo em cinzento
                      SvgPicture.asset(
                        'assets/images/content.svg',
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                          Colors.grey.shade400,
                          BlendMode.srcIn,
                        ),
                      ),

                      // 2. Se a cabeça foi selecionada, mostramos a cabeça colorida exatamente alinhada por cima
                      if (selectedBodyPart == 'cabeca')
                        Positioned.fill(
                          child: ClipRect(
                            clipper: HeadClipper(), // Recorte preciso apenas na zona superior
                            child: SvgPicture.asset(
                              'assets/images/content.svg',
                              fit: BoxFit.contain,
                              colorFilter: const ColorFilter.mode(
                                AppTheme.accentBeige,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),

                      // 3. Área interativa de toque posicionada exatamente sobre a cabeça
                      Positioned(
                        top: 25, // Ajuste fino da posição vertical do toque
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              selectedBodyPart =
                                  selectedBodyPart == 'cabeca' ? null : 'cabeca';
                            });
                          },
                          child: Container(
                            width: 65,
                            height: 65,
                            color: Colors.transparent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Botão Avançar
            Padding(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: GestureDetector(
                onTap: selectedBodyPart != null
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HealthSymptomsScreen(
                              bodyPart: selectedBodyPart!,
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
                    color: selectedBodyPart != null
                        ? AppTheme.accentBeige
                        : Colors.grey.shade300,
                    border: Border.all(
                      color: selectedBodyPart != null
                          ? AppTheme.primary
                          : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: selectedBodyPart != null
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
// Classe auxiliar para recortar exatamente a região da cabeça (cerca de 25% superior da imagem)
class HeadClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    // Define a área de recorte: do topo (0) até à altura onde termina a cabeça/pescoço
    return Rect.fromLTWH(0, 0, size.width, size.height * 0.26);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) => false;
}