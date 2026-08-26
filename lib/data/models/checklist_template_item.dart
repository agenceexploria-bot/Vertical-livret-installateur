enum ChecklistTemplateType { reception, autoControle }

/// Item d'une liste de réception ou de contrôle, appliqué à la création de
/// chaque nouveau chantier (voir POST /chantiers côté backend) — géré par
/// l'Admin (ajout, renommage, suppression), sans effet rétroactif sur les
/// chantiers déjà créés.
class ChecklistTemplateItem {
  final String id;
  final ChecklistTemplateType type;
  final String categorie;
  final String libelle;
  final bool critique;
  final int ordre;

  ChecklistTemplateItem({
    required this.id,
    required this.type,
    required this.categorie,
    required this.libelle,
    required this.critique,
    required this.ordre,
  });

  factory ChecklistTemplateItem.fromJson(Map<String, dynamic> json) => ChecklistTemplateItem(
        id: json['id'] as String,
        type: ChecklistTemplateType.values.firstWhere((t) => t.name == json['type']),
        categorie: json['categorie'] as String,
        libelle: json['libelle'] as String,
        critique: json['critique'] as bool,
        ordre: json['ordre'] as int,
      );
}
