import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/password_field.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/vertical_logo.dart';
import '../../state/auth_state.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, this.email = ''});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  late final _emailController = TextEditingController(text: widget.email);
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || code.length != 6) {
      _showError('Saisissez votre email et les 6 chiffres reçus par email.');
      return;
    }
    if (password.length < 6) {
      _showError('Le mot de passe doit contenir au moins 6 caractères.');
      return;
    }
    if (password != _confirmController.text) {
      _showError('Les mots de passe ne correspondent pas.');
      return;
    }

    final authState = context.read<AuthState>();
    final ok = await authState.resetPassword(email: email, code: code, password: password);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mot de passe réinitialisé — connectez-vous avec le nouveau.')),
      );
      context.go('/login');
    } else {
      _showError(authState.lastError ?? 'Code invalide ou expiré.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    return ResponsiveLayout(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const SizedBox(height: 120, child: VerticalLogo(height: 150)),
              const SizedBox(height: 40),
              Text('Nouveau mot de passe', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                'Saisissez le code à 6 chiffres reçu par email ainsi que votre nouveau mot de passe.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.acier),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'Code reçu par email', counterText: ''),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _passwordController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Nouveau mot de passe'),
              ),
              const SizedBox(height: 16),
              PasswordField(
                controller: _confirmController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Confirmation'),
              ),
              const SizedBox(height: 24),
              if (authState.isLoading)
                const CircularProgressIndicator(color: AppColors.orange)
              else
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Réinitialiser le mot de passe'),
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const Text('Retour à la connexion', style: TextStyle(color: AppColors.encre, fontSize: 13)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
