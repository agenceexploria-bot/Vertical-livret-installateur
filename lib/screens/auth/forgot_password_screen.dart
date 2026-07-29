import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/vertical_logo.dart';
import '../../state/auth_state.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez votre adresse email.')),
      );
      return;
    }

    final authState = context.read<AuthState>();
    final ok = await authState.requestPasswordReset(email);
    if (!mounted) return;
    if (ok) {
      context.push('/reset-password', extra: email);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.lastError ?? 'Impossible d\'envoyer le code.')),
      );
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
              Text('Mot de passe oublié', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              const Text(
                'Saisissez votre adresse email : si un compte y est associé, vous recevrez un code à 6 chiffres pour réinitialiser votre mot de passe.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.acier),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 24),
              if (authState.isLoading)
                const CircularProgressIndicator(color: AppColors.orange)
              else
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Envoyer le code'),
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
