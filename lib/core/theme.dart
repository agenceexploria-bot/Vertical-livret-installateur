import 'package:flutter/material.dart';

class AppColors {
  // Couleurs de base
  static const Color encre = Color(0xFF17222E);
  static const Color acier = Color(0xFF4C5E6E);
  static const Color acierClair = Color(0xFF98A3AE);
  static const Color lignes = Color(0xFFD8DDE2);
  static const Color fond = Color(0xFFF7F8F9);
  static const Color blanc = Color(0xFFFFFFFF);

  // Couleurs d'état
  static const Color vert = Color(0xFF1E7F5C);
  static const Color rouge = Color(0xFFB02E2E);
  static const Color orange = Color(0xFFE85D0F);

  // Rouge du logo (si différent du rouge d'état)
  static const Color rougeLogo = Color(0xFFE11F1B);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.fond,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.orange,
        primary: AppColors.orange,
        onPrimary: Colors.white,
        surface: AppColors.blanc,
        onSurface: AppColors.encre,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppColors.encre,
          fontFamily: '', // Police système
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: AppColors.encre,
        ),
        bodyLarge: TextStyle(
          fontSize: 13,
          color: AppColors.encre,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: AppColors.acier,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: AppColors.acierClair,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.blanc,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(9),
          side: const BorderSide(color: AppColors.lignes, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.encre,
          side: const BorderSide(color: AppColors.lignes, width: 1),
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
