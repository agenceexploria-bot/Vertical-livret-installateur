import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/vertical_logo.dart';
import '../../state/auth_state.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key});

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  bool _checking = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    await context.read<AuthState>().refreshCurrentUser();
    if (!mounted) return;
    setState(() => _checking = false);
    if (context.read<AuthState>().currentUser?.isActive == true) {
      context.go('/');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toujours en attente de validation par un chargé d\'affaires.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VerticalLogo(height: 50),
            const SizedBox(height: 60),
            const Icon(Icons.hourglass_empty, size: 64, color: AppColors.acierClair),
            const SizedBox(height: 32),
            Text(
              'Compte en attente de validation',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Un chargé d\'affaires doit valider votre inscription avant que vous ne puissiez voir vos chantiers. Vous recevrez une notification dès que ce sera fait.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.acier),
            ),
            const SizedBox(height: 40),
            if (_checking)
              const CircularProgressIndicator(color: AppColors.orange)
            else
              OutlinedButton(
                onPressed: _checkStatus,
                child: const Text('Vérifier mon statut'),
              ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => context.read<AuthState>().logout(),
              child: const Text('Déconnexion'),
            ),
          ],
        ),
      ),
    );
  }
}
