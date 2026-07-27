import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/coming_soon.dart';
import '../../core/theme.dart';
import '../../core/widgets/vertical_logo.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../state/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _submit() async {
    final authState = context.read<AuthState>();
    final success = await authState.login(_identifierController.text, _passwordController.text);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.lastError ?? 'Identifiants incorrects')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    return ResponsiveLayout(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              const SizedBox(height: 120, child: VerticalLogo(height: 150)),
              const SizedBox(height: 40),
              
              TextField(
                controller: _identifierController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Mobile ou email',
                  hintText: 'ex: 06 52 41 78 90',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                ),
              ),
              const SizedBox(height: 24),

              if (authState.isLoading)
                const CircularProgressIndicator(color: AppColors.orange)
              else
                ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Se connecter'),
                ),
              
              const SizedBox(height: 16),
              TextButton(onPressed: () => showComingSoon(context), child: const Text('Mot de passe oublié ?', style: TextStyle(color: AppColors.encre, fontSize: 13))),
              
              const SizedBox(height: 32),
              const Divider(color: AppColors.lignes),
              const SizedBox(height: 24),
              
              OutlinedButton(
                onPressed: () => context.push('/signup'),
                child: const Text('Créer un compte installateur'),
              ),
              
              const SizedBox(height: 40),
              
              if (authState.offlineExpiry != null) ...[
                Text(
                  'Connecté hier — vos livrets restent accessibles sans réseau jusqu\'au 28/07',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
