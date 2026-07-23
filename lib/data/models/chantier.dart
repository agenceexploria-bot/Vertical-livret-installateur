import 'point_controle.dart';
import 'user.dart';
import 'document_terrain.dart';

enum ChantierSyncStatus { nouveau, charge }

class Chantier {
  final String reference;
  final String client;
  final String adresse;
  final String ville;
  final DateTime dateDebut;
  final DateTime dateFin;
  final String contactNom;
  final String contactTel;
  final String horaires;
  final List<String> consignes;
  final String typeMonteCharge;
  final String capacite;
  final int niveaux;
  final String referenceAffaire;
  ChantierSyncStatus syncStatus;

  final List<PointControle> receptionMarchandises;
  final List<PointControle> autoControle;
  bool rexValide;
  String? rexTranscription;
  bool pvSigne;
  String? pvSigneur;
  DateTime? pvSigneAt;
  String? pvSignatureImagePath;

  // Rattachement (EX-04) : liste des installateurs autorisés à voir ce chantier.
  final List<User> installateursRattaches;
  // Vérification de la veille (EX-22) : ids des installateurs ayant ouvert leur livret.
  final Set<String> livretsOuverts;
  // Module 8 (EX-10 à EX-13) : dépôts terrain de l'installateur.
  final List<DocumentTerrain> docsTerrain;

  Chantier({
    required this.reference,
    required this.client,
    required this.adresse,
    required this.ville,
    required this.dateDebut,
    required this.dateFin,
    required this.contactNom,
    required this.contactTel,
    required this.horaires,
    required this.consignes,
    required this.typeMonteCharge,
    required this.capacite,
    required this.niveaux,
    required this.referenceAffaire,
    this.syncStatus = ChantierSyncStatus.nouveau,
    required this.receptionMarchandises,
    required this.autoControle,
    this.rexValide = false,
    this.rexTranscription,
    this.pvSigne = false,
    this.pvSigneur,
    this.pvSigneAt,
    this.pvSignatureImagePath,
    List<User>? installateursRattaches,
    Set<String>? livretsOuverts,
    List<DocumentTerrain>? docsTerrain,
  })  : installateursRattaches = installateursRattaches ?? [],
        livretsOuverts = livretsOuverts ?? {},
        docsTerrain = docsTerrain ?? [];

  double get progressionReception => receptionMarchandises.isEmpty
      ? 0
      : receptionMarchandises.where((p) => p.isComplete).length / receptionMarchandises.length;

  double get progressionAutoControle => autoControle.isEmpty
      ? 0
      : autoControle.where((p) => p.isComplete).length / autoControle.length;

  bool get canSignPV => progressionAutoControle == 1.0;

  factory Chantier.fromJson(Map<String, dynamic> json) => Chantier(
        reference: json['reference'] as String,
        client: json['client'] as String,
        adresse: json['adresse'] as String,
        ville: json['ville'] as String,
        dateDebut: DateTime.parse(json['dateDebut'] as String),
        dateFin: DateTime.parse(json['dateFin'] as String),
        contactNom: json['contactNom'] as String,
        contactTel: json['contactTel'] as String,
        horaires: json['horaires'] as String,
        consignes: List<String>.from(json['consignes'] as List? ?? []),
        typeMonteCharge: json['typeMonteCharge'] as String,
        capacite: json['capacite'] as String,
        niveaux: json['niveaux'] as int,
        referenceAffaire: json['referenceAffaire'] as String,
        syncStatus: ChantierSyncStatus.values.firstWhere((s) => s.name == json['syncStatus'], orElse: () => ChantierSyncStatus.nouveau),
        receptionMarchandises: ((json['receptionMarchandises'] as List?) ?? [])
            .map((p) => PointControle.fromJson(p as Map<String, dynamic>))
            .toList(),
        autoControle: ((json['autoControle'] as List?) ?? [])
            .map((p) => PointControle.fromJson(p as Map<String, dynamic>))
            .toList(),
        rexValide: json['rexValide'] as bool? ?? false,
        rexTranscription: json['rexTranscription'] as String?,
        pvSigne: json['pvSigne'] as bool? ?? false,
        pvSigneur: json['pvSigneur'] as String?,
        pvSigneAt: json['pvSigneAt'] != null ? DateTime.parse(json['pvSigneAt'] as String) : null,
        pvSignatureImagePath: json['pvSignatureImagePath'] as String?,
        installateursRattaches: ((json['installateursRattaches'] as List?) ?? [])
            .map((u) => User.fromJson(u as Map<String, dynamic>))
            .toList(),
        livretsOuverts: Set<String>.from(json['livretsOuverts'] as List? ?? []),
        docsTerrain: ((json['docsTerrain'] as List?) ?? [])
            .map((d) => DocumentTerrain.fromJson(d as Map<String, dynamic>))
            .toList(),
      );
}
