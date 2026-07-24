enum CategorieDocument { bonLivraison, documentClient, habilitation, constat, autre }

CategorieDocument categorieFromJson(String value) => CategorieDocument.values.firstWhere((c) => c.name == value);

class DocumentTerrain {
  final String? id;
  final String titre;
  final CategorieDocument categorie;
  final DateTime horodatage;
  final String auteur;
  bool envoye;
  final String? filePath;

  DocumentTerrain({
    this.id,
    required this.titre,
    required this.categorie,
    required this.horodatage,
    required this.auteur,
    this.envoye = true,
    this.filePath,
  });

  String get categorieLabel {
    switch (categorie) {
      case CategorieDocument.bonLivraison:
        return 'Bon de livraison';
      case CategorieDocument.documentClient:
        return 'Document client';
      case CategorieDocument.habilitation:
        return 'Habilitation / certificat';
      case CategorieDocument.constat:
        return 'Constat (photo/PDF)';
      case CategorieDocument.autre:
        return 'Autre';
    }
  }

  factory DocumentTerrain.fromJson(Map<String, dynamic> json) => DocumentTerrain(
        id: json['id'] as String?,
        titre: json['titre'] as String,
        categorie: categorieFromJson(json['categorie'] as String),
        horodatage: DateTime.parse(json['horodatage'] as String),
        auteur: json['auteur'] as String? ?? '',
        // Le serveur ne renvoie que des documents déjà envoyés ; `envoye:
        // false` n'apparaît que sur une entrée optimiste ajoutée localement
        // au cache pendant que l'envoi est en file d'attente hors-ligne.
        envoye: json['envoye'] as bool? ?? true,
        filePath: json['filePath'] as String?,
      );

  /// Miroir de [fromJson] — utilisé pour réécrire le cache local (Drift)
  /// après un ajout optimiste hors-ligne.
  Map<String, dynamic> toJson() => {
        'id': id,
        'titre': titre,
        'categorie': categorie.name,
        'horodatage': horodatage.toIso8601String(),
        'auteur': auteur,
        'envoye': envoye,
        'filePath': filePath,
      };
}
