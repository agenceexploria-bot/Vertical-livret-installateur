import '../../data/models/chantier.dart';

/// Cloisonnement strict de l'espace SAV — le contexte de navigation d'une
/// fiche chantier (liste de repli, onglet actif, route de la fiche) dépend
/// du [ChantierType], jamais de la façon dont on y est arrivé (URL directe,
/// notification, bouton "Retour" sans historique) : une fiche SAV reste
/// dans l'espace SAV. Pure, testable sans BoShell ni GoRouter. Voir
/// router.dart pour les deux routes de fiche (/chantiers/:ref et /sav/:ref,
/// même écran BoChantierDetailScreen).
String chantierListeRoute(ChantierType type) => type == ChantierType.sav ? '/backoffice/ct/sav' : '/backoffice/ct';

String chantierActiveNav(ChantierType type) => type == ChantierType.sav ? 'sav' : 'chantiers';

String chantierDetailRoute(ChantierType type, String reference) =>
    type == ChantierType.sav ? '/backoffice/ct/sav/$reference' : '/backoffice/ct/chantiers/$reference';
