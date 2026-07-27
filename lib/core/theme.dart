import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Couleurs de marque — reprises du vrai logo Vertical (anthracite + rouge),
  // le site officiel n'étant pas accessible pour vérification directe
  // (protégé par Cloudflare). `encre` et `orange` gardent leur nom historique
  // pour ne pas casser les dizaines d'usages existants dans l'app — seule la
  // valeur a changé.
  static const Color encre = Color(0xFF2D2A26);
  static const Color acier = Color(0xFF4C5E6E);
  static const Color acierClair = Color(0xFF98A3AE);
  static const Color lignes = Color(0xFFD8DDE2);
  static const Color fond = Color(0xFFF7F8F9);
  static const Color blanc = Color(0xFFFFFFFF);

  // Couleurs d'état
  static const Color vert = Color(0xFF1E7F5C);
  static const Color rouge = Color(0xFFB02E2E);
  static const Color orange = Color(0xFFE11F1B);
}

/// Ton clair du orange (utilisé pour les dégradés boutons/glow) — dérivé de
/// [AppColors.orange] plutôt qu'une constante séparée, pour ne jamais
/// diverger de la charte si l'orange de base change un jour.
Color get _orangeClair => Color.lerp(AppColors.orange, Colors.white, 0.35)!;

/// Construit un dégradé + une ombre douce colorée pour un état de bouton
/// donné — partagé entre le thème global (ElevatedButton) et tout bouton
/// personnalisé qui voudrait le même style.
BoxDecoration appButtonDecoration(Set<WidgetState> states, {double radius = 16}) {
  final disabled = states.contains(WidgetState.disabled);
  if (disabled) {
    return BoxDecoration(
      color: AppColors.lignes,
      borderRadius: BorderRadius.circular(radius),
    );
  }
  final pressed = states.contains(WidgetState.pressed);
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [_orangeClair, AppColors.orange],
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.orange.withValues(alpha: pressed ? 0.22 : 0.35),
        blurRadius: pressed ? 12 : 22,
        offset: Offset(0, pressed ? 3 : 8),
      ),
    ],
  );
}

class AppTheme {
  static TextTheme get _textTheme => TextTheme(
        titleLarge: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.encre),
        titleMedium: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.encre),
        bodyLarge: GoogleFonts.outfit(fontSize: 13, color: AppColors.encre),
        bodyMedium: GoogleFonts.outfit(fontSize: 13, color: AppColors.acier),
        bodySmall: GoogleFonts.outfit(fontSize: 11, color: AppColors.acierClair),
      );

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
        surfaceTint: Colors.transparent,
      ),
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      // AppCard peint ses propres ombres/dégradés (voir app_card.dart) — ce
      // thème ne sert que de filet de sécurité pour un éventuel `Card` brut.
      cardTheme: CardThemeData(
        color: AppColors.blanc,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.fond,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: const UnderlineInputBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.lignes, width: 1.4),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.lignes, width: 1.4),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.orange, width: 2.4),
        ),
        errorBorder: const UnderlineInputBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.rouge, width: 1.4),
        ),
        focusedErrorBorder: const UnderlineInputBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.rouge, width: 2.4),
        ),
        labelStyle: GoogleFonts.outfit(color: AppColors.acier, fontSize: 13),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          return GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.focused) ? AppColors.orange : AppColors.acier,
          );
        }),
        hintStyle: GoogleFonts.outfit(color: AppColors.acierClair, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          textStyle: WidgetStatePropertyAll(GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold)),
          backgroundBuilder: (context, states, child) {
            return Container(
              decoration: appButtonDecoration(states),
              alignment: Alignment.center,
              child: child,
            );
          },
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.encre,
          side: const BorderSide(color: AppColors.lignes, width: 1),
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
