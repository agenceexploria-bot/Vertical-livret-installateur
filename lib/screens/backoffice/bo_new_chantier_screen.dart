import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../state/chantier_state.dart';
import 'widgets/bo_shell.dart';
import 'widgets/bo_panel.dart';

class BoNewChantierScreen extends StatefulWidget {
  const BoNewChantierScreen({super.key});

  @override
  State<BoNewChantierScreen> createState() => _BoNewChantierScreenState();
}

class _BoNewChantierScreenState extends State<BoNewChantierScreen> {
  static const _modeles = ['Accompagné', 'Non accompagné', 'Non access.', 'Monte-plats'];
  int _modeleIndex = 1;
  int _elapsedSeconds = 0;
  Timer? _timer;
  bool _collageValide = false;
  final _refAffaireController = TextEditingController();
  final _collageController = TextEditingController();
  final _clientController = TextEditingController();
  final _adresseController = TextEditingController();
  final _villeController = TextEditingController();
  final _contactNomController = TextEditingController();
  final _contactTelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _refAffaireController.dispose();
    _collageController.dispose();
    _clientController.dispose();
    _adresseController.dispose();
    _villeController.dispose();
    _contactNomController.dispose();
    _contactTelController.dispose();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '$m min ${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return BoShell(
      activeNav: 'chantiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Nouveau chantier', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('Temps de saisie : $_elapsedLabel', style: const TextStyle(fontSize: 10, color: AppColors.acier)),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final left = _buildLeftColumn();
              final right = _buildRightColumn();
              if (!isWide) return Column(children: [left, const SizedBox(height: 12), right]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 20),
                  Expanded(child: right),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 220,
            child: ElevatedButton(
              onPressed: () => _creerChantier(context),
              child: const Text('Créer le chantier'),
            ),
          ),
        ],
      ),
    );
  }

  void _parseCollage() {
    final cleaned = _collageController.text.replaceAll('«', '').replaceAll('»', '').trim();
    if (cleaned.isEmpty) return;

    final parts = cleaned.split('—').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();

    if (parts.isNotEmpty) _clientController.text = parts[0];

    if (parts.length > 1) {
      final addressPart = parts[1];
      final lastComma = addressPart.lastIndexOf(',');
      if (lastComma != -1) {
        _adresseController.text = addressPart.substring(0, lastComma).trim();
        _villeController.text = addressPart.substring(lastComma + 1).trim();
      } else {
        _adresseController.text = addressPart;
      }
    }

    if (parts.length > 2) {
      final contactPart = parts[2];
      final phoneMatch = RegExp(r'0\d[\s.-]?\d{2}[\s.-]?\d{2}[\s.-]?\d{2}[\s.-]?\d{2}').firstMatch(contactPart);
      if (phoneMatch != null) {
        _contactTelController.text = phoneMatch.group(0)!.trim();
        _contactNomController.text = contactPart
            .replaceFirst(phoneMatch.group(0)!, '')
            .replaceFirst(RegExp(r'^resp\.?\s*site\s*:?\s*', caseSensitive: false), '')
            .trim();
      } else {
        _contactNomController.text = contactPart;
      }
    }

    setState(() => _collageValide = true);
  }

  Future<void> _creerChantier(BuildContext context) async {
    final reference = _refAffaireController.text.trim();
    if (reference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La référence affaire ERP est obligatoire.')),
      );
      return;
    }
    if (_clientController.text.trim().isEmpty ||
        _adresseController.text.trim().isEmpty ||
        _villeController.text.trim().isEmpty ||
        _contactNomController.text.trim().isEmpty ||
        _contactTelController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Client, adresse, ville et contact sont obligatoires — collez ou saisissez-les.')),
      );
      return;
    }
    if (context.read<ChantierState>().findByReference(reference) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cette référence existe déjà.')),
      );
      return;
    }

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
      'typeMonteCharge': _modeles[_modeleIndex],
      'capacite': '500 kg',
      'niveaux': 2,
      'referenceAffaire': reference,
    };

    final router = GoRouter.of(context);
    try {
      await context.read<ChantierState>().createChantier(body);
      router.go('/backoffice/ca/chantiers/$reference');
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _buildLeftColumn() {
    return Column(
      children: [
        BoPanel(
          title: '1 · Modèle de chantier',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(border: Border.all(color: AppColors.lignes, width: 1.5), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: List.generate(_modeles.length, (i) {
                    final isOn = i == _modeleIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _modeleIndex = i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(color: isOn ? AppColors.encre : Colors.white),
                          alignment: Alignment.center,
                          child: Text(
                            _modeles[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: isOn ? Colors.white : AppColors.acier),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pré-remplit : 6 documents requis, checklists réception (5 pts) et auto-contrôle (11 pts), consignes types',
                style: TextStyle(fontSize: 9.5, color: AppColors.acier),
              ),
            ],
          ),
        ),
        BoPanel(
          title: '2 · Référence affaire ERP (obligatoire)',
          child: TextField(
            controller: _refAffaireController,
            decoration: const InputDecoration(
              hintText: 'LD91245',
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return BoPanel(
      title: '3 · Collage intelligent',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.acierClair, width: 1.5, style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(7),
              color: const Color(0xFFEDF0F2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('COLLER LES INFOS CLIENT DEPUIS L\'ERP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.acier)),
                const SizedBox(height: 4),
                TextField(
                  controller: _collageController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11),
                  decoration: const InputDecoration(
                    hintText: '« Transgourmet Ouest — 12 av. des Landes, 44800 Saint-Herblain — Resp. site : Mme Guillou 06 45 12 33 87 »',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _collageValide = false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _editableKv('Client', _clientController),
          _editableKv('Adresse', _adresseController),
          _editableKv('Ville', _villeController),
          _editableKv('Contact', _contactNomController),
          _editableKv('Téléphone', _contactTelController),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton(
                onPressed: _parseCollage,
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 14)),
                child: const Text('Valider le découpage', style: TextStyle(fontSize: 11.5)),
              ),
              if (_collageValide) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle, color: AppColors.vert, size: 18),
                const SizedBox(width: 4),
                const Text('Relisez et corrigez si besoin ci-dessus', style: TextStyle(fontSize: 10, color: AppColors.acier)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _editableKv(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 70, child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.acier))),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
