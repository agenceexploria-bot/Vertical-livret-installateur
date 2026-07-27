import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/widgets/vertical_logo.dart';
import '../../data/models/user.dart';
import '../../state/auth_state.dart';

class BoLoginScreen extends StatefulWidget {
  const BoLoginScreen({super.key});

  @override
  State<BoLoginScreen> createState() => _BoLoginScreenState();
}

class _BoLoginScreenState extends State<BoLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();

    return Scaffold(
      backgroundColor: AppColors.fond,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.blanc,
              border: Border.all(color: AppColors.lignes),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                const SizedBox(height: 80, child: VerticalLogo(height: 80)),
                const SizedBox(height: 10),
                const Text(
                  'LIVRET INSTALLATEUR — ESPACE INTERNE',
                  style: TextStyle(fontSize: 10, color: AppColors.acier, letterSpacing: 1, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Email professionnel', style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    hintText: 's.martin@actiwork.fr',
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Mot de passe', style: Theme.of(context).textTheme.bodySmall),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(),
                ),
                const SizedBox(height: 20),
                if (authState.isLoading)
                  const CircularProgressIndicator(color: AppColors.orange)
                else
                  ElevatedButton(
                    onPressed: () => _login(context),
                    child: const Text('Se connecter'),
                  ),
                const SizedBox(height: 10),
                const Text(
                  'Mot de passe oublié ? · Vérification en 2 étapes activée',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: AppColors.acierClair),
                ),
                const SizedBox(height: 20),
                const Divider(color: AppColors.lignes),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    const Text('Nouveau chargé d\'affaires ? ', style: TextStyle(fontSize: 11.5, color: AppColors.acier)),
                    GestureDetector(
                      onTap: () => context.push('/backoffice/acces'),
                      child: const Text('Demander un accès', style: TextStyle(fontSize: 11.5, color: AppColors.orange, fontWeight: FontWeight.bold)),
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

  Future<void> _login(BuildContext context) async {
    final authState = context.read<AuthState>();
    final success = await authState.login(_emailController.text, _passwordController.text);

    if (!context.mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authState.lastError ?? 'Identifiants incorrects')),
      );
      return;
    }

    final role = authState.currentUser?.role;
    const boRoles = {UserRole.chargeAffaires, UserRole.qualite, UserRole.direction, UserRole.admin};
    if (!boRoles.contains(role)) {
      await authState.logout();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce compte est un compte installateur — utilisez l\'app mobile.')),
      );
      return;
    }

    // Les comptes CA/Qualité créés via "Demander un accès" restent bloqués
    // tant qu'un Admin ne les a pas validés (Admin et Direction sont créés
    // déjà actifs, hors de ce circuit de validation).
    const rolesSoumisValidation = {UserRole.chargeAffaires, UserRole.qualite};
    if (rolesSoumisValidation.contains(role) && !authState.currentUser!.isActive) {
      await authState.logout();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compte en attente de validation par un administrateur.')),
      );
      return;
    }

    context.go('/backoffice');
  }
}
