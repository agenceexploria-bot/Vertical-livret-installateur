/// Contenu figé du gabarit officiel Vertical (formulaire PV interactif) —
/// libellés et identifiants tels que fournis par Vertical, reproduits à la
/// lettre. Miroir de backend/src/lib/pvFormulaireDefinition.ts : les deux
/// listes doivent rester synchronisées si le gabarit évolue.
// TODO(2026-08-31) : duplication manuelle avec le fichier backend ci-dessus
// (voir son TODO) — à factoriser au prochain tour de nettoyage.
class PvChecklistItemDef {
  final String id;
  final String libelle;
  const PvChecklistItemDef(this.id, this.libelle);
}

const pvSection1Titre = "Le client a réceptionné ce jour l'installation";
const pvSection1 = <PvChecklistItemDef>[
  PvChecklistItemDef('1.1', 'Complète en bon état sans défaut visible'),
  PvChecklistItemDef('1.2', "L'installation fonctionne normalement conformément aux performances"),
  PvChecklistItemDef('1.3', "Mode secours, l'installation fonctionne sans risques pour l'utilisation"),
  PvChecklistItemDef('1.4', 'Prise des photos par le poseur le jour de la fin de chantier'),
];

const pvSection2Titre = 'Le client a reçu les instructions et documents';
const pvSection2 = <PvChecklistItemDef>[
  PvChecklistItemDef('2.1', 'Utilisation dispositifs urgence et sécurité'),
  PvChecklistItemDef('2.2', 'Ensemble des documents techniques (notices)'),
  PvChecklistItemDef('2.3', 'Déclarations CE'),
  PvChecklistItemDef('2.4', 'Instruction déverrouillage'),
  PvChecklistItemDef('2.5', 'Certains éléments demandant un contrôle et un graissage 2 fois par an minimum'),
];

const pvSection3Titre = 'Le client souhaite des services supplémentaires';
const pvSection3 = <PvChecklistItemDef>[
  PvChecklistItemDef('3.1', "Envoi d'un contrat d'entretien"),
];

const pvNatureDePoseOptions = <String>[
  'Monte-charge accompagné',
  'Monte-charge accessible non accompagné',
  'Monte-charge non accessible',
  'Monte-plats',
  'Autre (habillage…)',
];

const pvTemoignageMention =
    'Pourriez-vous rédiger un court témoignage client afin de nous aider dans notre développement ?';

enum PvReponseValue { oui, non }

/// Réponse à un item de checklist (sections 1 à 3) — [reponse] reste `null`
/// tant que l'installateur/le client n'a pas coché Oui ou Non.
class PvChecklistReponse {
  final String id;
  PvReponseValue? reponse;
  String observation;
  PvChecklistReponse({required this.id, this.reponse, this.observation = ''});

  Map<String, dynamic> toJson() => {
        'id': id,
        'reponse': reponse?.name,
        'observation': observation.trim().isEmpty ? null : observation.trim(),
      };
}

/// Réponses complètes du formulaire PV interactif — voir la structure JSON
/// attendue par POST /chantiers/:reference/pv/reponses (backend/src/lib/pvFormPdf.ts).
class PvFormReponses {
  String maitreOeuvre = '';
  String operation = '';
  String lot = '';
  final List<PvChecklistReponse> receptionInstallation;
  final List<PvChecklistReponse> documentsRemis;
  final List<PvChecklistReponse> servicesSupplementaires;
  final Set<String> natureDePose = {};
  String quantite = '';
  String reserves = '';
  String remarques = '';
  String temoignageClient = '';

  PvFormReponses()
      : receptionInstallation = pvSection1.map((d) => PvChecklistReponse(id: d.id)).toList(),
        documentsRemis = pvSection2.map((d) => PvChecklistReponse(id: d.id)).toList(),
        servicesSupplementaires = pvSection3.map((d) => PvChecklistReponse(id: d.id)).toList();

  /// Nombre total de questions (sections 1 à 3) restées sans réponse Oui/Non
  /// — le backend refuse la soumission tant qu'il en reste (voir
  /// pvReponsesSchema côté serveur), comme sur le PV papier où chaque point
  /// doit être tranché (au pire "Non" avec observation).
  int get nombreQuestionsSansReponse =>
      [...receptionInstallation, ...documentsRemis, ...servicesSupplementaires].where((r) => r.reponse == null).length;

  bool get checklistComplete => nombreQuestionsSansReponse == 0;

  Map<String, dynamic> toJson() => {
        'identite': {
          'maitreOeuvre': maitreOeuvre.trim().isEmpty ? null : maitreOeuvre.trim(),
          'operation': operation.trim().isEmpty ? null : operation.trim(),
          'lot': lot.trim().isEmpty ? null : lot.trim(),
        },
        'receptionInstallation': receptionInstallation.map((r) => r.toJson()).toList(),
        'documentsRemis': documentsRemis.map((r) => r.toJson()).toList(),
        'servicesSupplementaires': servicesSupplementaires.map((r) => r.toJson()).toList(),
        'natureDePose': natureDePose.toList(),
        'quantite': quantite.trim().isEmpty ? null : quantite.trim(),
        'reserves': reserves.trim().isEmpty ? null : reserves.trim(),
        'remarques': remarques.trim().isEmpty ? null : remarques.trim(),
        'temoignageClient': temoignageClient.trim().isEmpty ? null : temoignageClient.trim(),
      };
}
