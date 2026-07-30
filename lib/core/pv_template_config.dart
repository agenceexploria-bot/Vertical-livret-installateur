/// Coordonnées fixes de la zone de signature sur le gabarit PV déposé par le
/// back-office. Le gabarit ayant toujours la même mise en page, ces valeurs
/// sont codées en dur — à AJUSTER UNE SEULE FOIS pour correspondre exactement
/// à votre modèle de document réel (les valeurs ci-dessous sont des exemples
/// plausibles, pas mesurées sur un vrai gabarit).
///
/// Unité : points PDF (1 point = 1/72 pouce ; une page A4 fait 595 x 842 pts),
/// mesurés depuis le coin BAS-GAUCHE de la page — convention standard PDF.
class PvTemplateConfig {
  /// Page où insérer la signature (1 = première page). null = dernière page
  /// du document, quel que soit son nombre de pages.
  static const int? signaturePageNumber = null;

  static const double signatureX = 350;
  static const double signatureY = 80;
  static const double signatureWidth = 180;
  static const double signatureHeight = 70;
}
