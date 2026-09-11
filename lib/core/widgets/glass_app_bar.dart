import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

/// AppBar en verre dépoli (fond semi-transparent + flou du contenu qui
/// défile derrière) — remplace `AppBar` partout dans l'app mobile pour
/// l'esthétique glassmorphism, en gardant les mêmes paramètres usuels.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Color backgroundColor;
  final Color foregroundColor;
  // `null` = comportement historique (adaptatif à la plateforme, comme
  // AppBar par défaut) — n'affecte aucun des appels existants qui ne le
  // renseignent pas. Ajouté pour l'accueil installateur, qui a besoin d'un
  // logo aligné à gauche plutôt que centré (voir home_screen.dart).
  final bool? centerTitle;
  // Les trois suivants (leading/leadingWidth/automaticallyImplyLeading) sont
  // passés tels quels à l'AppBar sous-jacente — `null`/valeurs par défaut
  // Flutter, comme AppBar, tant qu'un appelant ne les renseigne pas.
  // Ajoutés pour VerticalAppBar, qui construit son propre leading
  // (flèche de retour + logo) plutôt que de laisser AppBar l'inférer.
  final Widget? leading;
  final double? leadingWidth;
  final bool automaticallyImplyLeading;

  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.backgroundColor = AppColors.encre,
    this.foregroundColor = Colors.white,
    this.centerTitle,
    this.leading,
    this.leadingWidth,
    this.automaticallyImplyLeading = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AppBar(
          title: title,
          centerTitle: centerTitle,
          actions: actions,
          leading: leading,
          leadingWidth: leadingWidth,
          automaticallyImplyLeading: automaticallyImplyLeading,
          backgroundColor: backgroundColor.withValues(alpha: 0.8),
          foregroundColor: foregroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
    );
  }
}
