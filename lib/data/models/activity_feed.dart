import 'user.dart';

class InscriptionEnAttente {
  final String id;
  final String fullName;
  final UserRole role;
  final DateTime createdAt;

  InscriptionEnAttente({required this.id, required this.fullName, required this.role, required this.createdAt});

  factory InscriptionEnAttente.fromJson(Map<String, dynamic> json) => InscriptionEnAttente(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        role: userRoleFromJson(json['role'] as String),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class AnomalieSignalee {
  final String chantierReference;
  final String client;
  final String libelle;
  final String categorie;
  final bool critique;
  final String? validePar;
  final DateTime? valideAt;

  AnomalieSignalee({
    required this.chantierReference,
    required this.client,
    required this.libelle,
    required this.categorie,
    required this.critique,
    this.validePar,
    this.valideAt,
  });

  factory AnomalieSignalee.fromJson(Map<String, dynamic> json) => AnomalieSignalee(
        chantierReference: json['chantierReference'] as String,
        client: json['client'] as String,
        libelle: json['libelle'] as String,
        categorie: json['categorie'] as String,
        critique: json['critique'] as bool,
        validePar: json['validePar'] as String?,
        valideAt: json['valideAt'] != null ? DateTime.parse(json['valideAt'] as String) : null,
      );
}

class PvRecent {
  final String chantierReference;
  final String client;
  final String? pvSigneur;
  final DateTime? pvSigneAt;

  PvRecent({required this.chantierReference, required this.client, this.pvSigneur, this.pvSigneAt});

  factory PvRecent.fromJson(Map<String, dynamic> json) => PvRecent(
        chantierReference: json['chantierReference'] as String,
        client: json['client'] as String,
        pvSigneur: json['pvSigneur'] as String?,
        pvSigneAt: json['pvSigneAt'] != null ? DateTime.parse(json['pvSigneAt'] as String) : null,
      );
}

class RexEnAttente {
  final String chantierReference;
  final String client;
  final String? rexTranscription;
  final DateTime? rexSoumisAt;

  RexEnAttente({required this.chantierReference, required this.client, this.rexTranscription, this.rexSoumisAt});

  factory RexEnAttente.fromJson(Map<String, dynamic> json) => RexEnAttente(
        chantierReference: json['chantierReference'] as String,
        client: json['client'] as String,
        rexTranscription: json['rexTranscription'] as String?,
        rexSoumisAt: json['rexSoumisAt'] != null ? DateTime.parse(json['rexSoumisAt'] as String) : null,
      );
}

class ActivityFeed {
  final List<InscriptionEnAttente> inscriptionsEnAttente;
  final List<AnomalieSignalee> anomalies;
  final List<PvRecent> pvRecents;
  final List<RexEnAttente> rexEnAttente;

  ActivityFeed({
    required this.inscriptionsEnAttente,
    required this.anomalies,
    required this.pvRecents,
    required this.rexEnAttente,
  });

  factory ActivityFeed.fromJson(Map<String, dynamic> json) => ActivityFeed(
        inscriptionsEnAttente: ((json['inscriptionsEnAttente'] as List?) ?? [])
            .map((e) => InscriptionEnAttente.fromJson(e as Map<String, dynamic>))
            .toList(),
        anomalies: ((json['anomalies'] as List?) ?? []).map((e) => AnomalieSignalee.fromJson(e as Map<String, dynamic>)).toList(),
        pvRecents: ((json['pvRecents'] as List?) ?? []).map((e) => PvRecent.fromJson(e as Map<String, dynamic>)).toList(),
        rexEnAttente: ((json['rexEnAttente'] as List?) ?? []).map((e) => RexEnAttente.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
