import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../data/api_client.dart';
import '../../data/models/user.dart';
import '../../state/admin_state.dart';
import '../../state/auth_state.dart';
import '../../state/chantier_state.dart';
import 'widgets/bo_back_button.dart';
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
  final _contactEmailController = TextEditingController();
  String? _coordinateurTravauxId;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final isAdmin = context.read<AuthState>().currentUser?.role == UserRole.admin;
      if (isAdmin && context.read<AdminState>().tousLesComptes.isEmpty) {
        context.read<AdminState>().fetch();
      }
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
    _contactEmailController.dispose();
    super.dispose();
  }

  String get _elapsedLabel {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '$m min ${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthState>().currentUser?.role == UserRole.admin;
    final coordinateursTravaux = context.watch<AdminState>().tousLesComptes.where((u) => u.role == UserRole.coordinateurTravaux).toList();

    return BoShell(
      activeNav: 'chantiers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BoBackButton(),
          Row(
            children: [
              Text('Nouveau chantier', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('Temps de saisie : $_elapsedLabel', style: const TextStyle(fontSize: 12, color: AppColors.acier)),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              final left = _buildLeftColumn(isAdmin: isAdmin, coordinateursTravaux: coordinateursTravaux);
              final right = _buildRightColumn();
              if (!isWide) return Column(children: [left, const SizedBox(height: 4), right]);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: left),
                  const SizedBox(width: 24),
                  Expanded(child: right),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 260,
            child: ElevatedButton.icon(
              onPressed: () => _creerChantier(context),
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('Créer le chantier'),
            ),
          ),
        ],
      ),
    );
  }

  // Regex indépendantes par champ plutôt qu'un découpage positionnel par
  // séparateur : l'ancienne version supposait un format rigide "Client —
  // Adresse, Ville — Contact Tel" et, dès que l'ERP collé n'utilisait pas
  // exactement ce séparateur, `split` ne trouvait rien et TOUT le texte
  // brut finissait dans le champ Client, les autres restant vides. Chaque
  // champ est maintenant repéré par son propre motif, peu importe l'ordre
  // ou la ponctuation du texte source.
  static final _emailRegex = RegExp(r'[\w.+-]+@[\w-]+\.[A-Za-z]{2,}');
  static final _telephoneRegex = RegExp(r'(?:\+33[\s.-]?|0)[1-9](?:[\s.-]?\d{2}){4}');
  static final _villeRegex = RegExp(
    r"\d{5}\s+[A-Za-zÀ-ÖØ-öø-ÿ][\wÀ-ÖØ-öø-ÿ'-]*(?:\s[A-Za-zÀ-ÖØ-öø-ÿ][\wÀ-ÖØ-öø-ÿ'-]*)*",
  );
  static final _contactLabelRegex = RegExp(r'(?:contact|resp\.?(?:\s*site)?)\s*:?\s*', caseSensitive: false);
  static final _civiliteRegex = RegExp(r"(?:M\.|Mme|Mlle)\s+[A-ZÀ-Ö][\wÀ-ÖØ-öø-ÿ'-]*");
  static final _clientLabelRegex = RegExp(r'client\s*:?\s*', caseSensitive: false);
  static final _separatorSplitRegex = RegExp(r'[\n,;]|[\s]?[-–—][\s]?');
  static final _edgeSeparatorsRegex = RegExp(r'^[\s,;\-–—:]+|[\s,;\-–—:]+$');

  void _parseCollage() {
    final cleaned = _collageController.text.replaceAll('«', '').replaceAll('»', '').trim();
    if (cleaned.isEmpty) return;

    final email = _emailRegex.firstMatch(cleaned)?.group(0);
    final telephone = _telephoneRegex.firstMatch(cleaned)?.group(0)?.trim();
    final ville = _villeRegex.firstMatch(cleaned)?.group(0);
    final client = _extractClient(cleaned);
    final contact = _extractContact(cleaned, telephone: telephone);
    final adresse = _extractAdresse(cleaned, client: client, ville: ville);

    if (client != null && client.isNotEmpty) _clientController.text = client;
    if (adresse != null && adresse.isNotEmpty) _adresseController.text = adresse;
    if (ville != null) _villeController.text = ville;
    if (contact != null && contact.isNotEmpty) _contactNomController.text = contact;
    if (telephone != null) _contactTelController.text = telephone;
    if (email != null) _contactEmailController.text = email;

    setState(() => _collageValide = true);
  }

  /// Société/client — après "Client :" si présent, sinon la première ligne
  /// (jusqu'au premier séparateur).
  String? _extractClient(String text) {
    final labelMatch = _clientLabelRegex.firstMatch(text);
    final source = labelMatch != null ? text.substring(labelMatch.end) : text;
    final firstSegment = source.split(_separatorSplitRegex).first.trim();
    return firstSegment.isEmpty ? null : firstSegment;
  }

  /// Nom du contact — après un mot-clé ("Contact :", "Resp. site :"...) si
  /// présent, sinon une civilité isolée ("M.", "Mme", "Mlle") suivie d'un nom.
  /// Le résultat s'arrête au numéro de téléphone repéré séparément, s'il y en a un.
  String? _extractContact(String text, {String? telephone}) {
    String segment;
    final labelMatch = _contactLabelRegex.firstMatch(text);
    if (labelMatch != null) {
      segment = text.substring(labelMatch.end);
    } else {
      final civiliteMatch = _civiliteRegex.firstMatch(text);
      if (civiliteMatch == null) return null;
      segment = text.substring(civiliteMatch.start);
    }
    if (telephone != null) {
      final telIndex = segment.indexOf(telephone);
      if (telIndex != -1) segment = segment.substring(0, telIndex);
    }
    final firstLine = segment.split(RegExp(r'[\n]|[\s]?[-–—][\s]?')).first;
    return firstLine.trim().isEmpty ? null : firstLine.trim();
  }

  /// Adresse — ce qui reste entre la fin du nom client et le début de la
  /// ville repérée (code postal + nom), une fois les séparateurs de bordure
  /// retirés. Approche "par soustraction" plutôt que positionnelle : peu
  /// importe le séparateur utilisé entre les segments.
  String? _extractAdresse(String text, {String? client, String? ville}) {
    var start = 0;
    if (client != null) {
      final clientIndex = text.indexOf(client);
      if (clientIndex != -1) start = clientIndex + client.length;
    }
    var end = text.length;
    if (ville != null) {
      final villeIndex = text.indexOf(ville, start);
      if (villeIndex != -1) end = villeIndex;
    }
    if (start >= end) return null;
    final segment = text.substring(start, end).replaceAll(_edgeSeparatorsRegex, '');
    return segment.isEmpty ? null : segment;
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
      'coordinateurTravauxId': ?_coordinateurTravauxId,
      'contactEmail': ?(_contactEmailController.text.trim().isEmpty ? null : _contactEmailController.text.trim()),
    };

    final router = GoRouter.of(context);
    try {
      await context.read<ChantierState>().createChantier(body);
      router.go('/backoffice/ct/chantiers/$reference');
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Widget _buildLeftColumn({required bool isAdmin, required List<User> coordinateursTravaux}) {
    return Column(
      children: [
        if (isAdmin)
          BoPanel(
            title: 'CT responsable',
            child: DropdownButtonFormField<String>(
              initialValue: _coordinateurTravauxId,
              isExpanded: true,
              hint: const Text('Aucun (optionnel)', style: TextStyle(fontSize: 12)),
              items: coordinateursTravaux
                  .map((u) => DropdownMenuItem(value: u.id, child: Text(u.fullName, style: const TextStyle(fontSize: 12.5))))
                  .toList(),
              onChanged: (value) => setState(() => _coordinateurTravauxId = value),
            ),
          ),
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
          _editableKv('Email', _contactEmailController),
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _parseCollage,
                icon: const Icon(Icons.auto_fix_high, size: 16),
                label: const Text('Valider le découpage'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 38), padding: const EdgeInsets.symmetric(horizontal: 16)),
              ),
              if (_collageValide) ...[
                const SizedBox(width: 10),
                const Icon(Icons.check_circle, color: AppColors.vert, size: 18),
                const SizedBox(width: 6),
                const Text('Relisez et corrigez si besoin ci-dessus', style: TextStyle(fontSize: 11.5, color: AppColors.acier)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _editableKv(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 78, child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.acier))),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
