import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme.dart';

/// Illustration monte-charge (assets/images/monte_charge.svg), sobre et
/// monochrome — utilisée comme [EmptyState.illustration] pour les états
/// vides propres à la fiche chantier/SAV (REX, documents, auto-contrôle...),
/// plus parlante qu'un cercle d'icône Material générique dans ce contexte.
class MonteChargeIllustration extends StatelessWidget {
  final double height;

  const MonteChargeIllustration({super.key, this.height = 52});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/monte_charge.svg',
      height: height,
      colorFilter: const ColorFilter.mode(AppColors.acierClair, BlendMode.srcIn),
    );
  }
}

/// État vide générique (liste/tableau sans résultat) : icône, message et
/// bouton d'action optionnel, centrés — remplace un simple "Aucun résultat."
/// perdu dans un tableau vide. Utilisé dans tout le back-office (listes de
/// chantiers, comptes...) pour une expérience cohérente. [illustration], si
/// fourni (voir [MonteChargeIllustration]), remplace le cercle d'icône basé
/// sur [icon] — les deux paramètres ne sont pas mutuellement exclusifs pour
/// l'appelant, mais un seul est rendu (illustration prioritaire).
class EmptyState extends StatelessWidget {
  final IconData? icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final Widget? illustration;

  const EmptyState({
    super.key,
    this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon = Icons.add,
    this.illustration,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ??
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(color: AppColors.fond, shape: BoxShape.circle),
                  child: Icon(icon, size: 30, color: AppColors.acierClair),
                ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.acier),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 20)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
