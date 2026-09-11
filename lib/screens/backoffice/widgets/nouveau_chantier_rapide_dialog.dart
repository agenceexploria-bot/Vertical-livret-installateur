import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme.dart';
import '../../../data/api_client.dart';
import '../../../data/models/chantier.dart';
import '../../../state/chantier_state.dart';

/// Mini-formulaire de création rapide d'un chantier ANCIEN (existant avant la
/// mise en place du système — donc sans livret ni modules actifs), ouvert
/// depuis le sélecteur du dialogue SAV ([CreerSavDialog]) quand le chantier
/// terminé recherché n'existe pas encore en base. Ne demande que le strict
/// nécessaire (référence, client, ville) ; les autres champs requis par la
/// route POST /chantiers (adresse, contact, horaires, type de monte-charge,
/// capacité, niveaux, référence affaire) reçoivent une valeur de repli —
/// modifiables ensuite via la fiche chantier standard si besoin. Renvoie le
/// [Chantier] créé (via Navigator.pop) pour que l'appelant le présélectionne
/// directement, ou `null` si annulé.
class NouveauChantierRapideDialog extends StatefulWidget {
  const NouveauChantierRapideDialog({super.key});

  @override
  State<NouveauChantierRapideDialog> createState() => _NouveauChantierRapideDialogState();
}

class _NouveauChantierRapideDialogState extends State<NouveauChantierRapideDialog> {
  final _referenceController = TextEditingController();
  final _clientController = TextEditingController();
  final _villeController = TextEditingController();
  bool _isSubmitting = false;
  String? _erreur;

  @override
  void dispose() {
    _referenceController.dispose();
    _clientController.dispose();
    _villeController.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    final reference = _referenceController.text.trim();
    final client = _clientController.text.trim();
    final ville = _villeController.text.trim();
    if (reference.isEmpty || client.isEmpty || ville.isEmpty) {
      setState(() => _erreur = 'Référence, client et ville sont requis.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _erreur = null;
    });
    final maintenant = DateTime.now().toIso8601String();
    try {
      final created = await context.read<ChantierState>().createChantier({
        'reference': reference,
        'client': client,
        'ville': ville,
        'adresse': 'Non renseignée',
        'dateDebut': maintenant,
        'dateFin': maintenant,
        'contactNom': 'Non renseigné',
        'contactTel': 'Non renseigné',
        'horaires': 'Non renseignés',
        'typeMonteCharge': 'Non renseigné',
        'capacite': 'Non renseignée',
        'niveaux': 1,
        'referenceAffaire': reference,
      });
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on ApiException catch (e) {
      setState(() {
        _erreur = e.message;
        _isSubmitting = false;
      });
    } catch (_) {
      setState(() {
        _erreur = 'Une erreur est survenue. Réessayez.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau chantier'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pour un chantier ancien, non suivi dans l\'application (pas de livret ni de modules). Les autres informations pourront être complétées plus tard depuis la fiche chantier.',
              style: TextStyle(fontSize: 12, color: AppColors.acierClair),
            ),
            const SizedBox(height: 14),
            TextField(controller: _referenceController, decoration: const InputDecoration(labelText: 'Référence')),
            const SizedBox(height: 12),
            TextField(controller: _clientController, decoration: const InputDecoration(labelText: 'Client')),
            const SizedBox(height: 12),
            TextField(controller: _villeController, decoration: const InputDecoration(labelText: 'Ville')),
            if (_erreur != null) ...[
              const SizedBox(height: 10),
              Text(_erreur!, style: const TextStyle(color: AppColors.rouge, fontSize: 12.5)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _creer,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Créer'),
        ),
      ],
    );
  }
}
