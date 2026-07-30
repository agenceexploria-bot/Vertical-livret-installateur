enum PointStatus { vide, conforme, nonConforme }

class PointControle {
  final String id;
  final String libelle;
  final String categorie;
  final bool critique;
  final bool photoRequise;
  PointStatus status;
  String? photoPath;
  String? validePar;
  DateTime? valideAt;

  PointControle({
    required this.id,
    required this.libelle,
    this.categorie = 'generale',
    this.critique = false,
    this.photoRequise = true,
    this.status = PointStatus.vide,
    this.photoPath,
    this.validePar,
    this.valideAt,
  });

  /// Règle commune à tous les modules de contrôle (réception marchandises et
  /// auto-contrôle) : un point conforme n'a plus besoin de photo pour être
  /// complet ; seule une anomalie (nonConforme) exige une photo, pour en
  /// apporter la preuve.
  bool get isComplete => status == PointStatus.conforme || (status == PointStatus.nonConforme && photoPath != null);

  factory PointControle.fromJson(Map<String, dynamic> json) => PointControle(
        id: json['id'] as String,
        libelle: json['libelle'] as String,
        categorie: json['categorie'] as String? ?? 'generale',
        critique: json['critique'] as bool? ?? false,
        photoRequise: json['photoRequise'] as bool? ?? true,
        status: PointStatus.values.firstWhere((s) => s.name == json['status']),
        photoPath: json['photoPath'] as String?,
        validePar: json['validePar'] as String?,
        valideAt: json['valideAt'] != null ? DateTime.parse(json['valideAt'] as String) : null,
      );

  /// Miroir de [fromJson] — utilisé pour réécrire le cache local (Drift)
  /// après une mise à jour optimiste hors-ligne.
  Map<String, dynamic> toJson() => {
        'id': id,
        'libelle': libelle,
        'categorie': categorie,
        'critique': critique,
        'photoRequise': photoRequise,
        'status': status.name,
        'photoPath': photoPath,
        'validePar': validePar,
        'valideAt': valideAt?.toIso8601String(),
      };
}
