/// Contenu figé du gabarit officiel Vertical (formulaire PV interactif) —
/// libellés et identifiants tels que fournis par Vertical, à reproduire à la
/// lettre dans le formulaire ET dans le PDF généré. Source de vérité unique
/// côté backend : la génération du PDF (voir pvFormPdf.ts) s'appuie
/// exclusivement sur ces listes pour l'ordre et les libellés affichés, jamais
/// sur ce que le client a soumis — un item manquant ou mal ordonné côté app
/// n'invalide donc jamais la mise en page du document final.
export interface PvChecklistItemDef {
  id: string;
  libelle: string;
}

export const PV_SECTION_1_TITRE = "Le client a réceptionné ce jour l'installation";
export const PV_SECTION_1: PvChecklistItemDef[] = [
  { id: '1.1', libelle: 'Complète en bon état sans défaut visible' },
  { id: '1.2', libelle: "L'installation fonctionne normalement conformément aux performances" },
  { id: '1.3', libelle: "Mode secours, l'installation fonctionne sans risques pour l'utilisation" },
  { id: '1.4', libelle: 'Prise des photos par le poseur le jour de la fin de chantier' },
];

export const PV_SECTION_2_TITRE = 'Le client a reçu les instructions et documents';
export const PV_SECTION_2: PvChecklistItemDef[] = [
  { id: '2.1', libelle: 'Utilisation dispositifs urgence et sécurité' },
  { id: '2.2', libelle: 'Ensemble des documents techniques (notices)' },
  { id: '2.3', libelle: 'Déclarations CE' },
  { id: '2.4', libelle: 'Instruction déverrouillage' },
  { id: '2.5', libelle: 'Certains éléments demandant un contrôle et un graissage 2 fois par an minimum' },
];

export const PV_SECTION_3_TITRE = 'Le client souhaite des services supplémentaires';
export const PV_SECTION_3: PvChecklistItemDef[] = [{ id: '3.1', libelle: "Envoi d'un contrat d'entretien" }];

export const PV_NATURE_POSE_OPTIONS = [
  'Monte-charge accompagné',
  'Monte-charge accessible non accompagné',
  'Monte-charge non accessible',
  'Monte-plats',
  'Autre (habillage…)',
];

export const PV_TEMOIGNAGE_MENTION =
  'Pourriez-vous rédiger un court témoignage client afin de nous aider dans notre développement ?';

export const PV_MENTIONS_LEGALES = [
  "En signant ce document, le client déclare que le mode d'emploi de l'installation lui a été remis et qu'il le laisse à la disposition de tous ceux qui sont autorisés à s'en servir.",
  "Il s'engage à ce que l'installation soit utilisée de façon appropriée et maintenue en bon état, comme prévu par la notice.",
  "L'entretien est obligatoire dès la mise en service d'un appareil (point 2.5). La garantie du produit ne se substitue pas à l'entretien.",
  "L'absence d'entretien et maintenance peut affecter la sécurité des utilisateurs, engager la responsabilité du Responsable de l'établissement et remettre en cause la garantie du fabricant.",
  'Les vérifications des organismes de contrôle technique ne se substituent pas à la maintenance.',
];
