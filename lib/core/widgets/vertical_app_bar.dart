import 'package:flutter/material.dart';
import '../theme.dart';
import 'glass_app_bar.dart';
import 'vertical_logo.dart';

/// AppBar unique et partagée pour tous les écrans mobiles (installateur ET
/// CT) — logo Vertical toujours présent en haut à gauche (leading), avec la
/// flèche de retour juste avant lui quand l'écran peut être dépilé (même
/// position relative partout : [retour?] [logo] [titre?] ... [actions?]).
/// Construite sur [GlassAppBar] (effet verre dépoli) plutôt qu'en dupliquant
/// sa logique — UNE SEULE implémentation de l'AppBar dans toute l'app.
///
/// [showBackButton] : `null` (défaut) déduit automatiquement la présence de
/// la flèche depuis la pile de navigation ([Navigator.canPop]), comme le
/// ferait une AppBar standard — un écran racine (accueil) n'en affiche donc
/// jamais sans avoir à le préciser. Force `true`/`false` pour les cas où ce
/// calcul ne convient pas.
class VerticalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final bool? showBackButton;
  final Color backgroundColor;
  final Color foregroundColor;

  const VerticalAppBar({
    super.key,
    this.title,
    this.actions,
    this.showBackButton,
    this.backgroundColor = AppColors.encre,
    this.foregroundColor = Colors.white,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final showBack = showBackButton ?? Navigator.of(context).canPop();

    // Largeurs calculées avec une marge généreuse plutôt qu'ajustées au
    // pixel près : le logo (assets/images/Vertical.svg, ratio intrinsèque
    // 500×350) rendu à 30px de haut mesure ~43px de large, +16px de padding
    // de la bulle blanche (voir VerticalLogo, bubble:true) ≈ 59px — une
    // ConstrainedBox trop juste ici a déjà produit un vrai RenderFlex
    // overflow (voir l'historique de ce fichier). Mieux vaut un peu d'espace
    // vide avant le titre qu'un débordement.
    const logoBubbleWidth = 60.0;
    final leadingWidth = showBack ? 56.0 + 8 + logoBubbleWidth : 16.0 + logoBubbleWidth;

    return GlassAppBar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      centerTitle: false,
      automaticallyImplyLeading: false,
      leadingWidth: leadingWidth,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBack) ...[
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: Icon(Icons.arrow_back, color: foregroundColor),
              tooltip: 'Retour',
            ),
            const SizedBox(width: 8),
          ] else
            const SizedBox(width: 16),
          // `bubble: true` (fond blanc derrière le logo) garantit le
          // contraste sur la bande sombre, quelle que soit sa teinte exacte
          // — même traitement que BoShell (back-office) et l'accueil
          // installateur, seul point de rendu du logo dans toute l'app.
          const VerticalLogo(height: 30, bubble: true),
        ],
      ),
      title: title,
      actions: actions,
    );
  }
}
