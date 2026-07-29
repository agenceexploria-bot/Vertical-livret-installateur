import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/api_client.dart';
import '../../data/models/chantier.dart';
import '../../state/chantier_state.dart';

/// Modification d'un chantier depuis le mobile CA — mêmes champs que
/// _ModifierChantierDialog (Web), en écran plein pour le mobile plutôt qu'une
/// boîte de dialogue.
class CaEditChantierScreen extends StatefulWidget {
  const CaEditChantierScreen({super.key});

  @override
  State<CaEditChantierScreen> createState() => _CaEditChantierScreenState();
}

class _CaEditChantierScreenState extends State<CaEditChantierScreen> {
  Chantier? _chantier;
  bool _isSubmitting = false;
  final _clientController = TextEditingController();
  final _adresseController = TextEditingController();
  final _villeController = TextEditingController();
  final _contactNomController = TextEditingController();
  final _contactTelController = TextEditingController();
  final _horairesController = TextEditingController();
  final _typeMonteChargeController = TextEditingController();
  final _capaciteController = TextEditingController();
  final _referenceAffaireController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final ref = GoRouterState.of(context).pathParameters['ref'] ?? '';
    final chantier = context.read<ChantierState>().findByReference(ref);
    _chantier = chantier;
    if (chantier != null) {
      _clientController.text = chantier.client;
      _adresseController.text = chantier.adresse;
      _villeController.text = chantier.ville;
      _contactNomController.text = chantier.contactNom;
      _contactTelController.text = chantier.contactTel;
      _horairesController.text = chantier.horaires;
      _typeMonteChargeController.text = chantier.typeMonteCharge;
      _capaciteController.text = chantier.capacite;
      _referenceAffaireController.text = chantier.referenceAffaire;
    }
  }

  @override
  void dispose() {
    _clientController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _contactNomController.dispose();
    _contactTelController.dispose();
    _horairesController.dispose();
    _typeMonteChargeController.dispose();
    _capaciteController.dispose();
    _referenceAffaireController.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    setState(() => _isSubmitting = true);
    try {
      await context.read<ChantierState>().updateChantier(_chantier!.reference, {
        'client': _clientController.text.trim(),
        'adresse': _adresseController.text.trim(),
        'ville': _villeController.text.trim(),
        'contactNom': _contactNomController.text.trim(),
        'contactTel': _contactTelController.text.trim(),
        'horaires': _horairesController.text.trim(),
        'typeMonteCharge': _typeMonteChargeController.text.trim(),
        'capacite': _capaciteController.text.trim(),
        'referenceAffaire': _referenceAffaireController.text.trim(),
      });
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chantier = _chantier;
    if (chantier == null) {
      return ResponsiveLayout(
        appBar: GlassAppBar(title: const Text('Chantier introuvable'), backgroundColor: AppColors.encre, foregroundColor: Colors.white),
        child: const SizedBox.shrink(),
      );
    }

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: Text('Modifier ${chantier.reference}'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _clientController, decoration: const InputDecoration(labelText: 'Client')),
          const SizedBox(height: 12),
          TextField(controller: _adresseController, decoration: const InputDecoration(labelText: 'Adresse')),
          const SizedBox(height: 12),
          TextField(controller: _villeController, decoration: const InputDecoration(labelText: 'Ville')),
          const SizedBox(height: 12),
          TextField(controller: _contactNomController, decoration: const InputDecoration(labelText: 'Contact — nom')),
          const SizedBox(height: 12),
          TextField(controller: _contactTelController, decoration: const InputDecoration(labelText: 'Contact — téléphone')),
          const SizedBox(height: 12),
          TextField(controller: _horairesController, decoration: const InputDecoration(labelText: 'Horaires')),
          const SizedBox(height: 12),
          TextField(controller: _typeMonteChargeController, decoration: const InputDecoration(labelText: 'Type de monte-charge')),
          const SizedBox(height: 12),
          TextField(controller: _capaciteController, decoration: const InputDecoration(labelText: 'Capacité')),
          const SizedBox(height: 12),
          TextField(controller: _referenceAffaireController, decoration: const InputDecoration(labelText: 'Référence affaire (ERP)')),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _enregistrer,
            child: _isSubmitting
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
