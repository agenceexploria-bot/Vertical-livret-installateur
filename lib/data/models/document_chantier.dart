enum TypeDocumentChantier { securite, technique }

TypeDocumentChantier typeDocumentChantierFromJson(String value) =>
    TypeDocumentChantier.values.firstWhere((t) => t.name == value);

/// Document de référence déposé par le CA (PPSPS, plans, notices...) —
/// consulté en lecture seule par l'installateur (Modules 1-3). À ne pas
/// confondre avec [DocumentTerrain], que l'installateur dépose lui-même.
class DocumentChantier {
  final String id;
  final TypeDocumentChantier type;
  final String nom;
  final String filePath;
  final DateTime createdAt;

  DocumentChantier({
    required this.id,
    required this.type,
    required this.nom,
    required this.filePath,
    required this.createdAt,
  });

  factory DocumentChantier.fromJson(Map<String, dynamic> json) => DocumentChantier(
        id: json['id'] as String,
        type: typeDocumentChantierFromJson(json['type'] as String),
        nom: json['nom'] as String,
        filePath: json['filePath'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'nom': nom,
        'filePath': filePath,
        'createdAt': createdAt.toIso8601String(),
      };
}
