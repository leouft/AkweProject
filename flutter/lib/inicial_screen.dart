import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'dictionary_page.dart';
import 'health_body_screen.dart'; // <--- 1. Adicionado o import da tela de saúde

class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Akwẽ App',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primary,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'O que gostaria de ver?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMenuOption(
                  context,
                  icon: Icons.favorite,
                  label: 'Saúde',
                  onTap: () {
                    // <--- 2. Navegação implementada para o módulo de saúde
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HealthBodyScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 40),
                _buildMenuOption(
                  context,
                  icon: Icons.menu_book,
                  label: 'Educação',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const HomePage(title: 'Dicionário Akwẽ'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(50),
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.background,
              border: Border.all(color: AppTheme.primary, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Icon(icon, size: 42, color: AppTheme.primary),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.primary,
          ),
        )
      ],
    );
  }
}