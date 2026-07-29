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
  // Fond à peine teinté (à peine plus gris qu'un blanc pur) plutôt qu'un
  // thème sombre — le blanc franc était jugé trop agressif, mais un vrai
  // fond sombre était trop marqué. Confort visuel discret.
  static const Color fond = Color(0xFFF2F0ED);
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
/// personnalisé qui voudrait le même style. Le survol (hors pression)
/// accentue légèrement l'ombre, pour un retour visuel fluide dès que la
/// souris passe sur le bouton — l'animation elle-même vient de l'AnimatedContainer
/// qui enveloppe ce décor (voir backgroundBuilder ci-dessous).
BoxDecoration appButtonDecoration(Set<WidgetState> states, {double radius = 16}) {
  final disabled = states.contains(WidgetState.disabled);
  if (disabled) {
    return BoxDecoration(
      color: AppColors.lignes,
      borderRadius: BorderRadius.circular(radius),
    );
  }
  final pressed = states.contains(WidgetState.pressed);
  final hovered = !pressed && states.contains(WidgetState.hovered);
  // Au survol, le dégradé est nettement éclairci (pas seulement l'ombre) —
  // un changement de teinte sur la face du bouton est bien plus perceptible
  // qu'une variation d'ombre portée à peine visible sous un aplat coloré.
  final topColor = hovered ? Color.lerp(_orangeClair, Colors.white, 0.25)! : _orangeClair;
  final bottomColor = hovered ? Color.lerp(AppColors.orange, Colors.white, 0.15)! : AppColors.orange;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [topColor, bottomColor],
    ),
    boxShadow: [
      BoxShadow(
        color: AppColors.orange.withValues(alpha: pressed ? 0.22 : (hovered ? 0.5 : 0.35)),
        blurRadius: pressed ? 12 : (hovered ? 30 : 22),
        offset: Offset(0, pressed ? 3 : (hovered ? 12 : 8)),
      ),
    ],
  );
}

class AppTheme {
  // Tailles nettement augmentées par rapport à la base précédente (17/15/13/13/11)
  // pour rester lisible de loin, notamment dans les tableaux et menus du
  // back-office — vient s'ajouter au boost global de MediaQuery.textScaler
  // (voir app.dart) pour les tailles codées en dur écran par écran.
  static TextTheme get _textTheme => TextTheme(
        titleLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.encre),
        titleMedium: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.encre),
        bodyLarge: GoogleFonts.outfit(fontSize: 17, color: AppColors.encre),
        bodyMedium: GoogleFonts.outfit(fontSize: 17, color: AppColors.acier),
        bodySmall: GoogleFonts.outfit(fontSize: 14, color: AppColors.acierClair),
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
      // Teinte de survol par défaut pour tout InkWell/ListTile/PopupMenuItem
      // qui ne définit pas la sienne (menus déroulants, lignes de tableau,
      // liens back-office...) — un gris de la charte, discret sur fond clair.
      hoverColor: AppColors.acier.withValues(alpha: 0.1),
      textTheme: _textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
        labelStyle: GoogleFonts.outfit(color: AppColors.acier, fontSize: 16),
        floatingLabelStyle: WidgetStateTextStyle.resolveWith((states) {
          return GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.focused) ? AppColors.orange : AppColors.acier,
          );
        }),
        hintStyle: GoogleFonts.outfit(color: AppColors.acierClair, fontSize: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 52)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          textStyle: WidgetStatePropertyAll(GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
          backgroundBuilder: (context, states, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: appButtonDecoration(states),
              alignment: Alignment.center,
              child: child,
            );
          },
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppColors.encre),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 52)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          textStyle: WidgetStatePropertyAll(GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold)),
          // Bordure qui fonce légèrement au survol (gris de la charte),
          // en plus du fond fondu ci-dessous.
          side: WidgetStateProperty.resolveWith((states) {
            final hovered = !states.contains(WidgetState.disabled) && states.contains(WidgetState.hovered);
            return BorderSide(color: hovered ? AppColors.acier : AppColors.lignes, width: 1);
          }),
          backgroundBuilder: (context, states, child) {
            final hovered = !states.contains(WidgetState.disabled) && states.contains(WidgetState.hovered);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: hovered ? AppColors.acier.withValues(alpha: 0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: child,
            );
          },
        ),
      ),
    );
  }
}
