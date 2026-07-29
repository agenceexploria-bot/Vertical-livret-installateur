import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/vertical_logo.dart';
import '../../state/auth_state.dart';

class BoAccessRequestScreen extends StatefulWidget {
  const BoAccessRequestScreen({super.key});

  @override
  State<BoAccessRequestScreen> createState() => _BoAccessRequestScreenState();
}

class _BoAccessRequestScreenState extends State<BoAccessRequestScreen> {
  final _nomController = TextEditingController();
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _fonctionController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fond,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.blanc,
              border: Border.all(color: AppColors.lignes),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                const SizedBox(height: 70, child: VerticalLogo(height: 70)),
                const SizedBox(height: 8),
                const Text(
                  'DEMANDE D\'ACCÈS — ESPACE INTERNE',
                  style: TextStyle(fontSize: 10, color: AppColors.acier, letterSpacing: 1, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _field('Nom et prénom', _nomController, hint: 'Julien Bernard'),
                const SizedBox(height: 12),
                _field('Email professionnel', _emailController, hint: 'j.bernard@exemple.fr'),
                const SizedBox(height: 12),
                _field('Téléphone mobile', _mobileController, hint: '06 12 34 56 78'),
                const SizedBox(height: 12),
                _field('Fonction', _fonctionController, hint: 'Chargé d\'affaires'),
                const SizedBox(height: 12),
                _field('Mot de passe', _passwordController, obscure: true),
                const SizedBox(height: 12),
                _field('Confirmer', _confirmController, obscure: true),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF0F2),
                    borderRadius: BorderRadius.circular(6),
                    border: const Border(left: BorderSide(color: AppColors.orange, width: 3)),
                  ),
                  child: const Text(
                    'La demande est validée par un administrateur avant activation du compte — vous recevrez un email de confirmation.',
                    style: TextStyle(fontSize: 10.5, color: AppColors.acier),
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : () => _submit(context),
                  child: _isSubmitting
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Envoyer ma demande'),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text('Déjà un compte ? ', style: TextStyle(fontSize: 11.5, color: AppColors.acier)),
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Text('Se connecter', style: TextStyle(fontSize: 11.5, color: AppColors.orange, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {String? hint, bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.acier)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscure,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => _submit(context),
          decoration: InputDecoration(
            hintText: hint,
          ),
        ),
      ],
    );
  }

  Future<void> _submit(BuildContext context) async {
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final authState = context.read<AuthState>();
    final nomComplet = _nomController.text.trim().split(RegExp(r'\s+'));
    final prenom = nomComplet.isNotEmpty ? nomComplet.first : _nomController.text;
    final nom = nomComplet.length > 1 ? nomComplet.sublist(1).join(' ') : '—';

    final success = await authState.signupInterne(
      nom: nom,
      prenom: prenom,
      mobile: _mobileController.text,
      password: _passwordController.text,
      email: _emailController.text,
      role: 'chargeAffaires',
    );

    // Le compte est créé mais non validé : on se déconnecte immédiatement,
    // il ne doit rester connecté nulle part avant validation par un Admin.
    await authState.logout();

    if (!context.mounted) return;
    setState(() => _isSubmitting = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.lastError ?? 'Impossible d\'envoyer la demande.')),
      );
      return;
    }

    context.go('/backoffice/acces/confirmation');
  }
}
