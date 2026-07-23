/// Checklists par défaut d'un nouveau chantier, conformes au CDC V0.2 : le
/// module 5 (auto-contrôle) est organisé par étape de montage, avec les
/// points de sécurité critiques (portes palières, serrures, asservissements)
/// marqués `critique` pour imposer une photo de détail bloquante côté app.
export const RECEPTION_POINTS = Array.from({ length: 5 }, (_, i) => ({
  type: 'reception' as const,
  categorie: 'Réception',
  libelle: `Réception point ${i + 1}`,
  critique: false,
  ordre: i,
}));

export const AUTO_CONTROLE_POINTS = [
  { categorie: 'Mécanique', libelle: 'Fixation du treuil et des poulies', critique: false },
  { categorie: 'Mécanique', libelle: 'Alignement des rails de guidage', critique: false },
  { categorie: 'Mécanique', libelle: 'Serrage des attaches de câbles', critique: false },
  { categorie: 'Mécanique', libelle: 'Niveau et aplomb de la structure', critique: false },
  { categorie: 'Portes palières', libelle: 'Verrouillage des portes palières', critique: true },
  { categorie: 'Portes palières', libelle: 'Serrures de gâches', critique: true },
  { categorie: 'Portes palières', libelle: 'Asservissement porte/cabine', critique: true },
  { categorie: 'Portes palières', libelle: 'Étanchéité des seuils de porte', critique: false },
  { categorie: 'Essais', libelle: 'Essai de charge nominale', critique: false },
  { categorie: 'Essais', libelle: 'Essai des fins de course', critique: false },
  { categorie: 'Essais', libelle: "Essai du dispositif d'arrêt d'urgence", critique: true },
].map((p, i) => ({ type: 'autoControle' as const, ordre: i, ...p }));
