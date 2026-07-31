/// Coordonnées fixes de la zone de signature sur le gabarit PV déposé par le
/// back-office — seule source de vérité désormais : la fusion gabarit +
/// signature se fait entièrement ici (voir pvMerge.ts), l'app ne rasterise
/// plus jamais le PDF original. Le gabarit ayant toujours la même mise en
/// page, ces valeurs sont codées en dur — à ajuster pour correspondre
/// exactement au modèle de document réel.
///
/// Unité : points PDF (1 point = 1/72 pouce ; une page A4 fait 595 x 842 pts),
/// mesurés depuis le coin BAS-GAUCHE de la page — convention standard PDF
/// (pdf-lib utilise la même convention pour Page.drawImage).
export const PvTemplateConfig = {
  /// Page où insérer la signature (1 = première page). null = dernière page
  /// du document, quel que soit son nombre de pages.
  signaturePageNumber: null as number | null,

  signatureX: 350,
  signatureY: 80,
  signatureWidth: 180,
  signatureHeight: 70,
};
