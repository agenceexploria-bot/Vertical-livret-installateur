import 'package:flutter/material.dart';
import '../data/api_client.dart';
import '../data/models/checklist_template_item.dart';

/// Listes de réception/contrôle (Admin) — voir BoAdminChecklistsScreen.
class ChecklistTemplatesState extends ChangeNotifier {
  final ApiClient _api;
  List<ChecklistTemplateItem> _items = [];
  bool _isLoading = false;

  ChecklistTemplatesState(this._api);

  List<ChecklistTemplateItem> get items => _items;
  bool get isLoading => _isLoading;

  List<ChecklistTemplateItem> itemsOfType(ChecklistTemplateType type) =>
      _items.where((i) => i.type == type).toList()..sort((a, b) => a.ordre.compareTo(b.ordre));

  Future<void> fetch() async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = await _api.getChecklistTemplates();
      _items = data.map((i) => ChecklistTemplateItem.fromJson(i as Map<String, dynamic>)).toList();
    } catch (_) {
      // Droits insuffisants ou serveur injoignable : la liste reste telle quelle.
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ajouter({required ChecklistTemplateType type, required String categorie, required String libelle, bool critique = false}) async {
    final data = await _api.addChecklistTemplateItem(type: type.name, categorie: categorie, libelle: libelle, critique: critique);
    _items = [..._items, ChecklistTemplateItem.fromJson(data['item'] as Map<String, dynamic>)];
    notifyListeners();
  }

  Future<void> renommer(ChecklistTemplateItem item, String nouveauLibelle) async {
    final data = await _api.updateChecklistTemplateItem(item.id, libelle: nouveauLibelle);
    _replace(ChecklistTemplateItem.fromJson(data['item'] as Map<String, dynamic>));
  }

  /// Optimistic UI : l'item disparaît immédiatement, avec restauration en cas
  /// d'échec réseau réel.
  Future<void> supprimer(ChecklistTemplateItem item) async {
    final previous = _items;
    _items = _items.where((i) => i.id != item.id).toList();
    notifyListeners();
    try {
      await _api.deleteChecklistTemplateItem(item.id);
    } catch (e) {
      _items = previous;
      notifyListeners();
      rethrow;
    }
  }

  void _replace(ChecklistTemplateItem updated) {
    final index = _items.indexWhere((i) => i.id == updated.id);
    if (index != -1) {
      _items = [..._items];
      _items[index] = updated;
      notifyListeners();
    }
  }
}
