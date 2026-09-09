/// Lien direct vers la fiche installateur d'un chantier (route
/// /chantier/:ref, voir router.dart) — construit ici plutôt que par
/// interpolation directe dans chaque écran ("Copier le lien", voir
/// bo_chantier_detail_screen.dart et ct_chantier_detail_screen.dart), pour
/// que le format exact (notamment le `#` — Flutter Web y route par hash,
/// `usePathUrlStrategy` n'est jamais appelé ici) reste unique et testable
/// sans Clipboard ni navigateur.
String chantierLinkUrl({required String origin, required String reference}) => '$origin/#/chantier/$reference';
