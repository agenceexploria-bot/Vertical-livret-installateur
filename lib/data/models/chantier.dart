import 'point_controle.dart';
import 'user.dart';
import 'document_terrain.dart';
import 'document_chantier.dart';

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
  final String? chargeAffairesId;
  final String? chargeAffairesNom;
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
  // Modules 1-3 : documents de référence déposés par le CA (PPSPS, plans...).
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
    required this.horaires,
    required this.consignes,
    required this.typeMonteCharge,
    required this.capacite,
    required this.niveaux,
    required this.referenceAffaire,
    this.chargeAffairesId,
    this.chargeAffairesNom,
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
    List<DocumentChantier>? documentsChantier,
  })  : installateursRattaches = installateursRattaches ?? [],
        livretsOuverts = livretsOuverts ?? {},
        docsTerrain = docsTerrain ?? [],
        documentsChantier = documentsChantier ?? [];

  double get progressionReception => receptionMarchandises.isEmpty
      ? 0
      : receptionMarchandises.where((p) => p.isComplete).length / receptionMarchandises.length;

  double get progressionAutoControle => autoControle.isEmpty
      ? 0
      : autoControle.where((p) => p.isComplete).length / autoControle.length;

  /// Le module PV se débloque soit parce que le back-office l'a déjà rempli
  /// (pvSigne, vérifié séparément par l'appelant), soit dès que
  /// l'auto-contrôle atteint 90% — la décision finale de signer reste au
  /// back-office (voir refonte du flux PV).
  bool get canSignPV => progressionAutoControle >= 0.9;

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
        chargeAffairesId: json['chargeAffairesId'] as String?,
        chargeAffairesNom: json['chargeAffairesNom'] as String?,
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
        'horaires': horaires,
        'consignes': consignes,
        'typeMonteCharge': typeMonteCharge,
        'capacite': capacite,
        'niveaux': niveaux,
        'referenceAffaire': referenceAffaire,
        'chargeAffairesId': chargeAffairesId,
        'chargeAffairesNom': chargeAffairesNom,
        'syncStatus': syncStatus.name,
        'receptionMarchandises': receptionMarchandises.map((p) => p.toJson()).toList(),
        'autoControle': autoControle.map((p) => p.toJson()).toList(),
        'rexValide': rexValide,
        'rexTranscription': rexTranscription,
        'pvSigne': pvSigne,
        'pvSigneur': pvSigneur,
        'pvSigneAt': pvSigneAt?.toIso8601String(),
        'pvSignatureImagePath': pvSignatureImagePath,
        'installateursRattaches': installateursRattaches.map((u) => u.toJson()).toList(),
        'livretsOuverts': livretsOuverts.toList(),
        'docsTerrain': docsTerrain.map((d) => d.toJson()).toList(),
        'documentsChantier': documentsChantier.map((d) => d.toJson()).toList(),
      };
}
