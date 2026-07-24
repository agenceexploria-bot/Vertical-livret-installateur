import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/document_capture.dart';
import '../../core/theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../data/models/user.dart';
import '../../state/auth_state.dart';

class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final user = authState.currentUser;
    final offlineExpiry = authState.offlineExpiry;

    return ResponsiveLayout(
      appBar: AppBar(
        title: const Text('Profil'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(context, user, offlineExpiry),
            const SizedBox(height: 32),
            Text('Habilitations', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (user != null) ...user.habilitations.map((h) => _buildHabilitationItem(h)),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _openAddCertificatDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un certificat'),
            ),
            const SizedBox(height: 48),
            Center(
              child: TextButton(
                onPressed: () => context.read<AuthState>().logout(),
                child: const Text('Déconnexion', style: TextStyle(color: AppColors.rouge, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Vertical Monte-Charges — v1.0.0\nLes certificats sont confidentiels.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.acierClair),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddCertificatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => const _AddCertificatDialog(),
    );
  }

  Widget _buildInfoCard(BuildContext context, User? user, DateTime? offlineExpiry) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.encre,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(user?.fullName ?? '', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              if (user != null)
                IconButton(
                  onPressed: () => _openEditProfilDialog(context, user),
                  icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                  tooltip: 'Modifier mon profil',
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(user?.societe ?? 'Salarié Vertical', style: const TextStyle(color: AppColors.acierClair)),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          _buildRow('Mobile', user?.mobile ?? '-', true),
          _buildRow('Email', user?.email ?? '-', true),
          _buildRow(
            'Session',
            offlineExpiry != null ? 'Valable hors-ligne jusqu\'au ${DateFormat('dd/MM/yyyy').format(offlineExpiry)}' : '-',
            true,
          ),
        ],
      ),
    );
  }

  void _openEditProfilDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (dialogContext) => _EditProfilDialog(user: user),
    );
  }

  Widget _buildRow(String label, String value, bool onDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label : ', style: TextStyle(color: onDark ? AppColors.acierClair : AppColors.acierClair, fontSize: 13)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: onDark ? Colors.white : AppColors.encre, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabilitationItem(Habilitation h) {
    final (label, color) = h.isExpired
        ? ('Expirée', AppColors.rouge)
        : h.expiresSoon
            ? ('Expire bientôt', AppColors.orange)
            : ('À jour', AppColors.vert);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.lignes),
      ),
      child: InkWell(
        onTap: h.filePath == null ? null : () => launchUrl(Uri.parse(h.filePath!)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.titre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'Expire le ${DateFormat('dd/MM/yyyy').format(h.dateExpiration)}${h.filePath != null ? ' · voir le certificat' : ''}',
                    style: const TextStyle(fontSize: 11, color: AppColors.acierClair),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.acierClair)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddCertificatDialog extends StatefulWidget {
  const _AddCertificatDialog();

  @override
  State<_AddCertificatDialog> createState() => _AddCertificatDialogState();
}

class _AddCertificatDialogState extends State<_AddCertificatDialog> {
  final _titreController = TextEditingController();
  DateTime? _dateExpiration;
  String? _file;
  String? _fileLabel;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titreController.dispose();
    super.dispose();
  }

  bool get _peutEnvoyer => _titreController.text.trim().isNotEmpty && _dateExpiration != null && _file != null;

  Future<void> _choisirDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _dateExpiration = picked);
  }

  Future<void> _choisirFichier() async {
    final file = await DocumentCapture.pickFile();
    if (file == null) return;
    setState(() {
      _file = file;
      _fileLabel = file.startsWith('data:application/pdf') ? 'PDF sélectionné' : 'Image sélectionnée';
    });
  }

  Future<void> _envoyer() async {
    setState(() => _isSubmitting = true);
    await context.read<AuthState>().addHabilitation(
          titre: _titreController.text.trim(),
          dateExpiration: _dateExpiration!,
          file: _file!,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajouter un certificat'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titreController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Titre',
                hintText: 'Habilitation électrique BR',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7))),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _choisirDate,
              icon: const Icon(Icons.event_outlined),
              label: Text(_dateExpiration == null ? 'Date d\'expiration' : DateFormat('dd/MM/yyyy').format(_dateExpiration!)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _choisirFichier,
              icon: const Icon(Icons.attach_file),
              label: Text(_fileLabel ?? 'Choisir un fichier (PDF ou image)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _peutEnvoyer && !_isSubmitting ? _envoyer : null,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Ajouter'),
        ),
      ],
    );
  }
}

class _EditProfilDialog extends StatefulWidget {
  final User user;
  const _EditProfilDialog({required this.user});

  @override
  State<_EditProfilDialog> createState() => _EditProfilDialogState();
}

class _EditProfilDialogState extends State<_EditProfilDialog> {
  late final _nomController = TextEditingController(text: widget.user.nom);
  late final _prenomController = TextEditingController(text: widget.user.prenom);
  late final _emailController = TextEditingController(text: widget.user.email ?? '');
  late final _mobileController = TextEditingController(text: widget.user.mobile ?? '');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  bool get _peutEnvoyer => _nomController.text.trim().isNotEmpty && _prenomController.text.trim().isNotEmpty && _emailController.text.trim().isNotEmpty;

  Future<void> _envoyer() async {
    setState(() => _isSubmitting = true);
    final ok = await context.read<AuthState>().updateProfile(
          nom: _nomController.text.trim(),
          prenom: _prenomController.text.trim(),
          email: _emailController.text.trim(),
          mobile: _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<AuthState>().lastError ?? 'Modification impossible')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modifier mon profil'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _prenomController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Prénom', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7)))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nomController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7)))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7)))),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mobileController,
              decoration: const InputDecoration(
                labelText: 'Mobile',
                hintText: 'Facultatif',
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(7))),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _peutEnvoyer && !_isSubmitting ? _envoyer : null,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }
}
