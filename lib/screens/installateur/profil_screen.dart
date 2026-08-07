import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/avatar_capture.dart';
import '../../core/document_capture.dart';
import '../../core/platform/mobile_detector.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/user_avatar.dart';
import '../../data/api_client.dart';
import '../../data/models/user.dart';
import '../../state/auth_state.dart';
import '../backoffice/widgets/bo_back_button.dart';

/// Écran de profil, partagé par l'app mobile installateur et le back-office
/// Web (atteint depuis le menu "Profil" de BoShell) — [isMobileDevice] fait
/// diverger l'affichage : cadre "téléphone" simulé ([ResponsiveLayout]) sur
/// mobile, mise en page centrée et aérée façon back-office sur desktop (voir
/// [_buildDesktop]). Les dialogues d'édition/ajout de certificat sont
/// partagés entre les deux.
class ProfilScreen extends StatelessWidget {
  const ProfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    final user = authState.currentUser;
    final offlineExpiry = authState.offlineExpiry;

    if (!isMobileDevice()) {
      return _buildDesktop(context, user, offlineExpiry);
    }

    return ResponsiveLayout(
      appBar: GlassAppBar(
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
            // Les certificats (habilitations électriques, CACES...) ne
            // concernent que les installateurs sur le terrain — inutile pour
            // les autres rôles, qui n'en ont jamais.
            if (user?.role == UserRole.installateur) ...[
              const SizedBox(height: 32),
              Text('Habilitations', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              ...user!.habilitations.map((h) => _buildHabilitationItem(h)),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => _openAddCertificatDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un certificat'),
              ),
            ],
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

  /// Version desktop (back-office Web) : centrée, largeur bornée à 860px
  /// pour rester lisible sur grand écran, informations regroupées dans des
  /// `Card` Material plutôt que dans le bloc de texte brut de la version
  /// mobile.
  Widget _buildDesktop(BuildContext context, User? user, DateTime? offlineExpiry) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BoBackButton(),
                Center(child: _ProfileAvatarPicker(user: user, radius: 56)),
                const SizedBox(height: 16),
                Center(child: Text('Mon profil', style: Theme.of(context).textTheme.titleLarge)),
                const SizedBox(height: 24),
                _buildInfosCardDesktop(context, user),
                const SizedBox(height: 20),
                _buildSecuriteCardDesktop(context, offlineExpiry),
                // Les certificats (habilitations électriques, CACES...) ne
                // concernent que les installateurs sur le terrain — ne monte
                // pas cette carte du tout pour les autres rôles.
                if (user?.role == UserRole.installateur) ...[
                  const SizedBox(height: 20),
                  _buildHabilitationsCardDesktop(context, user),
                ],
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'Vertical Monte-Charges — v1.0.0 · Les certificats sont confidentiels.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.acierClair),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfosCardDesktop(BuildContext context, User? user) {
    return Card(
      elevation: 2,
      color: AppColors.blanc,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Informations personnelles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.encre)),
                const Spacer(),
                if (user != null)
                  IconButton(
                    onPressed: () => _openEditProfilDialog(context, user),
                    icon: const Icon(Icons.edit_outlined, color: AppColors.acier, size: 20),
                    tooltip: 'Modifier mon profil',
                  ),
              ],
            ),
            const Divider(height: 24, color: AppColors.lignes),
            _infoRow(Icons.person_outline, 'Nom', user?.fullName ?? '—'),
            _infoRow(Icons.badge_outlined, 'Rôle', user != null ? _roleLabel(user.role) : '—'),
            if (user?.status != null) _infoRow(Icons.work_outline, 'Type', _statutLabel(user!)),
            _infoRow(Icons.phone_outlined, 'Mobile', user?.mobile ?? '—'),
            _infoRow(Icons.email_outlined, 'Email', user?.email ?? '—', isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuriteCardDesktop(BuildContext context, DateTime? offlineExpiry) {
    return Card(
      elevation: 2,
      color: AppColors.blanc,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Session et sécurité', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.encre)),
            const Divider(height: 24, color: AppColors.lignes),
            // Le mode hors-ligne (cache Drift) n'existe que sur l'app mobile
            // installateur — sur le Web, cette mention n'a pas de sens et ne
            // doit jamais s'afficher, quelle que soit la valeur d'offlineExpiry.
            if (!kIsWeb) ...[
              _infoRow(
                Icons.schedule_outlined,
                'Session',
                offlineExpiry != null ? 'Valable hors-ligne jusqu\'au ${DateFormat('dd/MM/yyyy').format(offlineExpiry)}' : '—',
                isLast: true,
              ),
              const SizedBox(height: 20),
            ],
            ElevatedButton.icon(
              onPressed: () => context.read<AuthState>().logout(),
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Déconnexion'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(220, 48)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHabilitationsCardDesktop(BuildContext context, User? user) {
    final habilitations = user?.habilitations ?? const <Habilitation>[];
    return Card(
      elevation: 2,
      color: AppColors.blanc,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Habilitations / Certificats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.encre)),
            const SizedBox(height: 16),
            if (habilitations.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Aucune habilitation enregistrée.', style: TextStyle(fontSize: 13, color: AppColors.acierClair)),
              )
            else ...[
              for (final h in habilitations) _buildHabilitationItem(h),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: () => _openAddCertificatDialog(context),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Ajouter un certificat'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(220, 46)),
            ),
          ],
        ),
      ),
    );
  }

  /// Rôle réel de l'utilisateur connecté (`user.role`) — jamais déduit ni
  /// approximé à partir d'autres champs, contrairement à l'ancien texte
  /// "Salarié Vertical" affiché pour tout le monde peu importe le rôle.
  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.installateur:
        return 'Installateur';
      case UserRole.chargeAffaires:
        return 'Chargé d\'Affaires';
      case UserRole.qualite:
        return 'Qualité';
      case UserRole.direction:
        return 'Direction';
      case UserRole.admin:
        return 'Administrateur';
    }
  }

  /// Salarié/Sous-traitant (`user.status`) — distinct du rôle : un CA ou un
  /// Admin n'a pas ce champ renseigné (nullable), seuls les appelants
  /// vérifient `user.status != null` avant d'appeler cette méthode.
  String _statutLabel(User user) {
    return user.status == UserStatus.sousTraitant
        ? 'Sous-traitant${user.societe != null ? ' · ${user.societe}' : ''}'
        : 'Salarié';
  }

  /// Ligne icône + libellé + valeur des cartes desktop — [isLast] omet le
  /// séparateur bas (dernière ligne d'une carte).
  Widget _infoRow(IconData icon, String label, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: isLast ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFEEF1F3)))),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.acier),
          const SizedBox(width: 14),
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.acierClair))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.encre, fontWeight: FontWeight.w600))),
        ],
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
          Center(child: _ProfileAvatarPicker(user: user, radius: 44)),
          const SizedBox(height: 16),
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
          Text(user != null ? _roleLabel(user.role) : '-', style: const TextStyle(color: AppColors.acierClair)),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          if (user?.status != null) _buildRow('Type', _statutLabel(user!), true),
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
        color: AppColors.blanc,
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

/// Grand avatar avec pastille appareil photo en overlay (bas-droite) —
/// ouvre [AvatarCapture.pickViaBottomSheet] au clic, puis envoie le résultat
/// via [AuthState.uploadAvatar]. Affiche un indicateur de chargement à la
/// place de l'avatar pendant l'envoi plutôt qu'un état bloqué sans retour.
class _ProfileAvatarPicker extends StatefulWidget {
  final User? user;
  final double radius;

  const _ProfileAvatarPicker({required this.user, required this.radius});

  @override
  State<_ProfileAvatarPicker> createState() => _ProfileAvatarPickerState();
}

class _ProfileAvatarPickerState extends State<_ProfileAvatarPicker> {
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    final result = await AvatarCapture.pickViaBottomSheet(context, hasAvatar: widget.user?.avatarUrl != null);
    if (result == null || !mounted) return;

    setState(() => _isUploading = true);
    final authState = context.read<AuthState>();
    final ok = result.remove ? await authState.removeAvatar() : await authState.uploadAvatar(result.dataUrl!);
    if (!mounted) return;
    setState(() => _isUploading = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AuthState>().lastError ?? (result.remove ? 'Impossible de supprimer la photo.' : 'Impossible d\'envoyer la photo.')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.radius * 2;
    return SizedBox(
      width: diameter + 8,
      height: diameter + 8,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 4,
            child: _isUploading
                ? SizedBox(
                    width: diameter,
                    height: diameter,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.lignes, shape: BoxShape.circle),
                      child: Center(child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2.5)),
                    ),
                  )
                : UserAvatar(user: widget.user, radius: widget.radius),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _isUploading ? null : _pickAndUpload,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
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
    final picked = await DocumentCapture.pickFile();
    if (picked == null) return;
    setState(() {
      _file = picked.dataUrl;
      _fileLabel = picked.fileName;
    });
  }

  Future<void> _envoyer() async {
    setState(() => _isSubmitting = true);
    try {
      await context.read<AuthState>().addHabilitation(
            titre: _titreController.text.trim(),
            dateExpiration: _dateExpiration!,
            file: _file!,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec de l\'envoi du certificat — réessayez.')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
              decoration: const InputDecoration(labelText: 'Prénom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nomController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nom'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile',
                hintText: 'Facultatif — avec l\'indicatif pays, ex : +33612345678',
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
