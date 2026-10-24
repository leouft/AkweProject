import 'package:flutter/material.dart';

class AppTheme {
  // Cores do projeto com o formato correto (0xFF no lugar de #)
  static const Color primary = Color(0xFFC87A4B); // Terracota / Laranja
  static const Color background = Color(0xFFFDFBF7); // Fundo creme
  static const Color cardBackground = Color(0xFFF5EFE6); // Soft bege
  static const Color accentBeige = Color(0xFFE5C19C); // Destaque/Seleção
  static const Color textPrimary = Color(0xFF222222);

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
      ),
      useMaterial3: true,
    );
  }
}