import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/vertical_logo.dart';
import '../../state/auth_state.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _step = 1;
  
  final _nomController = TextEditingController();
  final _prenomController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _societeController = TextEditingController();
  String _status = 'Salarié';

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  Future<void> _nextStep() async {
    if (_step < 4) {
      if (_step == 1) {
        if (_nomController.text.trim().isEmpty || _prenomController.text.trim().isEmpty || _mobileController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nom, prénom et mobile sont obligatoires.')),
          );
          return;
        }
        if (!_emailRegex.hasMatch(_emailController.text.trim())) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Un email valide est obligatoire — il sert aussi à vous connecter.')),
          );
          return;
        }
      }
      if (_step == 3) {
        if (_passwordController.text.length < 6) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le mot de passe doit contenir au moins 6 caractères.')),
          );
          return;
        }
        if (_passwordController.text != _confirmController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Les mots de passe ne correspondent pas.')),
          );
          return;
        }
      }
      setState(() => _step++);
      return;
    }

    final success = await context.read<AuthState>().signup(
          nom: _nomController.text,
          prenom: _prenomController.text,
          mobile: _mobileController.text,
          password: _passwordController.text,
          email: _emailController.text.trim(),
          sousTraitant: _status == 'Sous-traitant',
          societe: _societeController.text.isEmpty ? null : _societeController.text,
        );

    if (!mounted) return;
    if (success) {
      context.go('/pending');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.read<AuthState>().lastError ?? 'Inscription impossible')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildProgress(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildStepContent(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: ElevatedButton(
                onPressed: context.watch<AuthState>().isLoading ? null : _nextStep,
                child: context.watch<AuthState>().isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_step == 4 ? 'Terminer' : 'Continuer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          bool active = index + 1 <= _step;
          return Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: active ? AppColors.orange : AppColors.lignes,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 1:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VerticalLogo(height: 40),
            const SizedBox(height: 32),
            Text('Vos informations', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            _buildField('Prénom', _prenomController),
            const SizedBox(height: 16),
            _buildField('Nom', _nomController),
            const SizedBox(height: 16),
            _buildField('Téléphone mobile', _mobileController, hint: 'Identifiant de connexion'),
            const SizedBox(height: 16),
            _buildField('Email', _emailController, hint: 'Sert aussi à vous connecter'),
            const SizedBox(height: 24),
            const Text('Statut', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusBtn('Salarié'),
                const SizedBox(width: 8),
                _buildStatusBtn('Sous-traitant'),
              ],
            ),
            if (_status == 'Sous-traitant') ...[
              const SizedBox(height: 16),
              _buildField('Société', _societeController),
            ],
            const SizedBox(height: 32),
            const Text(
              'Vos données sont protégées et traitées uniquement par Vertical.',
              style: TextStyle(fontSize: 11, color: AppColors.acierClair),
            ),
          ],
        );
      case 2:
        return Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.sms_outlined, size: 48, color: AppColors.orange),
            const SizedBox(height: 24),
            Text('Validation SMS', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
              'Saisissez le code à 4 chiffres envoyé au mobile renseigné.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => _buildCodeBox()),
            ),
            const SizedBox(height: 24),
            TextButton(onPressed: () {}, child: const Text('Renvoyer le code')),
          ],
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sécurité', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text('Choisissez un mot de passe robuste.'),
            const SizedBox(height: 32),
            _buildField('Mot de passe', _passwordController, obscure: true),
            const SizedBox(height: 16),
            _buildField('Confirmation', _confirmController, obscure: true),
            const SizedBox(height: 24),
            const Text(
              'Au moins 10 caractères — une phrase simple suffit.',
              style: TextStyle(fontSize: 12, color: AppColors.acierClair),
            ),
          ],
        );
      case 4:
        return const Column(
          children: [
            SizedBox(height: 60),
            Icon(Icons.check_circle_outline, size: 80, color: AppColors.vert),
            SizedBox(height: 32),
            Text('Inscription complète', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text(
              'Votre compte est en cours de création. Vous pourrez accéder à vos chantiers dès validation par un chargé d\'affaires.',
              textAlign: TextAlign.center,
            ),
          ],
        );
      default:
        return Container();
    }
  }

  Widget _buildField(String label, TextEditingController ctrl, {String? hint, bool obscure = false}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(9))),
      ),
    );
  }

  Widget _buildStatusBtn(String label) {
    bool active = _status == label;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: active ? AppColors.encre : Colors.white,
          foregroundColor: active ? Colors.white : AppColors.encre,
        ),
        onPressed: () => setState(() => _status = label),
        child: Text(label),
      ),
    );
  }

  Widget _buildCodeBox() {
    return Container(
      width: 50,
      height: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lignes),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Center(child: Text('—', style: TextStyle(color: AppColors.acierClair))),
    );
  }
}
