import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/api_client.dart';
import '../../state/chantier_state.dart';

/// Création de chantier depuis le mobile CT — version simplifiée du
/// formulaire Web (BoNewChantierScreen), sans le collage intelligent ni le
/// choix de modèle : les champs essentiels suffisent pour une saisie rapide
/// en déplacement.
class CtNewChantierScreen extends StatefulWidget {
  const CtNewChantierScreen({super.key});

  @override
  State<CtNewChantierScreen> createState() => _CtNewChantierScreenState();
}

class _CtNewChantierScreenState extends State<CtNewChantierScreen> {
  bool _isSubmitting = false;
  final _referenceController = TextEditingController();
  final _clientController = TextEditingController();
  final _adresseController = TextEditingController();
  final _villeController = TextEditingController();
  final _contactNomController = TextEditingController();
  final _contactTelController = TextEditingController();
  final _typeMonteChargeController = TextEditingController(text: 'Non accompagné');
  final _capaciteController = TextEditingController(text: '500 kg');

  @override
  void dispose() {
    _referenceController.dispose();
    _clientController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _contactNomController.dispose();
    _contactTelController.dispose();
    _typeMonteChargeController.dispose();
    _capaciteController.dispose();
    super.dispose();
  }

  Future<void> _creer() async {
    final reference = _referenceController.text.trim();
    if (reference.isEmpty ||
        _clientController.text.trim().isEmpty ||
        _adresseController.text.trim().isEmpty ||
        _villeController.text.trim().isEmpty ||
        _contactNomController.text.trim().isEmpty ||
        _contactTelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Référence, client, adresse, ville et contact sont obligatoires.')),
      );
      return;
    }
    if (context.read<ChantierState>().findByReference(reference) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cette référence existe déjà.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final now = DateTime.now();
    final body = {
      'reference': reference,
      'client': _clientController.text.trim(),
      'adresse': _adresseController.text.trim(),
      'ville': _villeController.text.trim(),
      'dateDebut': now.add(const Duration(days: 14)).toIso8601String(),
      'dateFin': now.add(const Duration(days: 15)).toIso8601String(),
      'contactNom': _contactNomController.text.trim(),
      'contactTel': _contactTelController.text.trim(),
      'horaires': '8h00-18h00',
      'consignes': ['Consignes standard'],
      'typeMonteCharge': _typeMonteChargeController.text.trim(),
      'capacite': _capaciteController.text.trim(),
      'niveaux': 2,
      'referenceAffaire': reference,
    };

    final router = GoRouter.of(context);
    try {
      await context.read<ChantierState>().createChantier(body);
      router.go('/ct/chantier/$reference');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Nouveau chantier'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _referenceController,
            decoration: const InputDecoration(labelText: 'Référence affaire ERP', hintText: 'LD91245'),
          ),
          const SizedBox(height: 12),
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
          TextField(controller: _typeMonteChargeController, decoration: const InputDecoration(labelText: 'Type de monte-charge')),
          const SizedBox(height: 12),
          TextField(controller: _capaciteController, decoration: const InputDecoration(labelText: 'Capacité')),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _creer,
            child: _isSubmitting
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Créer le chantier'),
          ),
        ],
      ),
    );
  }
}
