import 'point_controle.dart';
import 'user.dart';
import 'document_terrain.dart';
import 'document_chantier.dart';

enum ChantierSyncStatus { nouveau, charge }

/// Retour d'expérience d'un installateur sur un chantier — plusieurs entrées
/// possibles par chantier (voir [Chantier.rex]).
class Rex {
  final String id;
  final String? transcription;
  final String? audioPath;
  final DateTime soumisAt;

  Rex({required this.id, this.transcription, this.audioPath, required this.soumisAt});

  factory Rex.fromJson(Map<String, dynamic> json) => Rex(
        id: json['id'] as String,
        transcription: json['transcription'] as String?,
        audioPath: json['audioPath'] as String?,
        soumisAt: DateTime.parse(json['soumisAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'transcription': transcription,
        'audioPath': audioPath,
        'soumisAt': soumisAt.toIso8601String(),
      };
}

class Chantier {
  final String reference;
  final String client;
  final String adresse;
  final String ville;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String contactNom;
  final String contactTel;
  final String? contactEmail;
  final String horaires;
  final List<String> consignes;
  final String typeMonteCharge;
  final String capacite;
  final int niveaux;
  final String referenceAffaire;
  final String? coordinateurTravauxId;
  final String? coordinateurTravauxNom;
  ChantierSyncStatus syncStatus;

  final List<PointControle> receptionMarchandises;
  final List<PointControle> autoControle;
  // Plusieurs REX possibles par chantier — un installateur peut compléter son
  // retour s'il a oublié quelque chose (voir Rex, chantiers.ts POST/DELETE .../rex).
  final List<Rex> rex;
  // Gabarit PDF déposé par le back-office — ne vaut PAS validation (voir
  // pvSigne, qui ne passe à true qu'une fois signé par le client via
  // l'installateur). pvSignatureImagePath devient alors le PDF final
  // (gabarit + signature fusionnés).
  String? pvPdfPath;
  bool pvSigne;
  String? pvSigneur;
  String? pvFonctionSignataire;
  DateTime? pvSigneAt;
  String? pvSignatureImagePath;

  // Rattachement (EX-04) : liste des installateurs autorisés à voir ce chantier.
  final List<User> installateursRattaches;
  // Vérification de la veille (EX-22) : ids des installateurs ayant ouvert leur livret.
  final Set<String> livretsOuverts;
  // Module 8 (EX-10 à EX-13) : dépôts terrain de l'installateur.
  final List<DocumentTerrain> docsTerrain;
  // Modules 1-3 : documents de référence déposés par le CT (PPSPS, plans...).
  final List<DocumentChantier> documentsChantier;

  Chantier({
    required this.reference,
    required this.client,
    required this.adresse,
    required this.ville,
    required this.dateDebut,
    required this.dateFin,
    required this.contactNom,
    required this.contactTel,
    this.contactEmail,
    required this.horaires,
    required this.consignes,
    required this.typeMonteCharge,
    required this.capacite,
    required this.niveaux,
    required this.referenceAffaire,
    this.coordinateurTravauxId,
    this.coordinateurTravauxNom,
    this.syncStatus = ChantierSyncStatus.nouveau,
    required this.receptionMarchandises,
    required this.autoControle,
    List<Rex>? rex,
    this.pvPdfPath,
    this.pvSigne = false,
    this.pvSigneur,
    this.pvFonctionSignataire,
    this.pvSigneAt,
    this.pvSignatureImagePath,
    List<User>? installateursRattaches,
    Set<String>? livretsOuverts,
    List<DocumentTerrain>? docsTerrain,
    List<DocumentChantier>? documentsChantier,
  })  : rex = rex ?? [],
        installateursRattaches = installateursRattaches ?? [],
        livretsOuverts = livretsOuverts ?? {},
        docsTerrain = docsTerrain ?? [],
        documentsChantier = documentsChantier ?? [];

  double get progressionReception => receptionMarchandises.isEmpty
      ? 0
      : receptionMarchandises.where((p) => p.isComplete).length / receptionMarchandises.length;

  double get progressionAutoControle => autoControle.isEmpty
      ? 0
      : autoControle.where((p) => p.isComplete).length / autoControle.length;

  /// Le module PV se débloque soit parce que le back-office a déjà déposé le
  /// gabarit (pvPdfPath, vérifié séparément par l'appelant), soit dès que
  /// l'auto-contrôle atteint 90%.
  bool get canSignPV => progressionAutoControle >= 0.9;

  /// Le back-office a déposé un gabarit, mais le client ne l'a pas encore
  /// signé — l'installateur peut le consulter et le faire signer.
  bool get pvEnAttenteSignature => pvPdfPath != null && !pvSigne;

  factory Chantier.fromJson(Map<String, dynamic> json) => Chantier(
        reference: json['reference'] as String,
        client: json['client'] as String,
        adresse: json['adresse'] as String,
        ville: json['ville'] as String,
        dateDebut: DateTime.parse(json['dateDebut'] as String),
        dateFin: DateTime.parse(json['dateFin'] as String),
        contactNom: json['contactNom'] as String,
        contactTel: json['contactTel'] as String,
        contactEmail: json['contactEmail'] as String?,
        horaires: json['horaires'] as String,
        consignes: List<String>.from(json['consignes'] as List? ?? []),
        typeMonteCharge: json['typeMonteCharge'] as String,
        capacite: json['capacite'] as String,
        niveaux: json['niveaux'] as int,
        referenceAffaire: json['referenceAffaire'] as String,
        coordinateurTravauxId: json['coordinateurTravauxId'] as String?,
        coordinateurTravauxNom: json['coordinateurTravauxNom'] as String?,
        syncStatus: ChantierSyncStatus.values.firstWhere((s) => s.name == json['syncStatus'], orElse: () => ChantierSyncStatus.nouveau),
        receptionMarchandises: ((json['receptionMarchandises'] as List?) ?? [])
            .map((p) => PointControle.fromJson(p as Map<String, dynamic>))
            .toList(),
        autoControle: ((json['autoControle'] as List?) ?? [])
            .map((p) => PointControle.fromJson(p as Map<String, dynamic>))
            .toList(),
        rex: ((json['rex'] as List?) ?? []).map((r) => Rex.fromJson(r as Map<String, dynamic>)).toList(),
        pvPdfPath: json['pvPdfPath'] as String?,
        pvSigne: json['pvSigne'] as bool? ?? false,
        pvSigneur: json['pvSigneur'] as String?,
        pvFonctionSignataire: json['pvFonctionSignataire'] as String?,
        pvSigneAt: json['pvSigneAt'] != null ? DateTime.parse(json['pvSigneAt'] as String) : null,
        pvSignatureImagePath: json['pvSignatureImagePath'] as String?,
        installateursRattaches: ((json['installateursRattaches'] as List?) ?? [])
            .map((u) => User.fromJson(u as Map<String, dynamic>))
            .toList(),
        livretsOuverts: Set<String>.from(json['livretsOuverts'] as List? ?? []),
        docsTerrain: ((json['docsTerrain'] as List?) ?? [])
            .map((d) => DocumentTerrain.fromJson(d as Map<String, dynamic>))
            .toList(),
        documentsChantier: ((json['documentsChantier'] as List?) ?? [])
            .map((d) => DocumentChantier.fromJson(d as Map<String, dynamic>))
            .toList(),
      );

  /// Miroir de [fromJson] — utilisé pour réécrire le cache local (Drift)
  /// après une mise à jour optimiste hors-ligne (voir ChantierRepository).
  Map<String, dynamic> toJson() => {
        'reference': reference,
        'client': client,
        'adresse': adresse,
        'ville': ville,
        'dateDebut': dateDebut.toIso8601String(),
        'dateFin': dateFin.toIso8601String(),
        'contactNom': contactNom,
        'contactTel': contactTel,
        'contactEmail': contactEmail,
        'horaires': horaires,
        'consignes': consignes,
        'typeMonteCharge': typeMonteCharge,
        'capacite': capacite,
        'niveaux': niveaux,
        'referenceAffaire': referenceAffaire,
        'coordinateurTravauxId': coordinateurTravauxId,
        'coordinateurTravauxNom': coordinateurTravauxNom,
        'syncStatus': syncStatus.name,
        'receptionMarchandises': receptionMarchandises.map((p) => p.toJson()).toList(),
        'autoControle': autoControle.map((p) => p.toJson()).toList(),
        'rex': rex.map((r) => r.toJson()).toList(),
        'pvPdfPath': pvPdfPath,
        'pvSigne': pvSigne,
        'pvSigneur': pvSigneur,
        'pvFonctionSignataire': pvFonctionSignataire,
        'pvSigneAt': pvSigneAt?.toIso8601String(),
        'pvSignatureImagePath': pvSignatureImagePath,
        'installateursRattaches': installateursRattaches.map((u) => u.toJson()).toList(),
        'livretsOuverts': livretsOuverts.toList(),
        'docsTerrain': docsTerrain.map((d) => d.toJson()).toList(),
        'documentsChantier': documentsChantier.map((d) => d.toJson()).toList(),
      };
}
