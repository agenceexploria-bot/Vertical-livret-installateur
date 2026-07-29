import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/password_field.dart';
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
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _societeController = TextEditingController();
  String _status = 'Salarié';

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _nextStep() async {
    if (_step == 1) {
      if (_nomController.text.trim().isEmpty || _prenomController.text.trim().isEmpty) {
        _showError('Nom et prénom sont obligatoires.');
        return;
      }
      if (!_emailRegex.hasMatch(_emailController.text.trim())) {
        _showError('Un email valide est obligatoire — il sert aussi à vous connecter.');
        return;
      }
      final ok = await context.read<AuthState>().requestEmailCode(_emailController.text.trim());
      if (!mounted) return;
      if (!ok) {
        _showError(context.read<AuthState>().lastError ?? 'Impossible d\'envoyer le code de vérification.');
        return;
      }
      setState(() => _step++);
      return;
    }

    if (_step == 2) {
      if (_codeController.text.trim().length != 6) {
        _showError('Saisissez les 6 chiffres reçus par email.');
        return;
      }
      final ok = await context.read<AuthState>().verifyEmailCode(_emailController.text.trim(), _codeController.text.trim());
      if (!mounted) return;
      if (!ok) {
        _showError(context.read<AuthState>().lastError ?? 'Code incorrect.');
        return;
      }
      setState(() => _step++);
      return;
    }

    if (_step == 3) {
      if (_passwordController.text.length < 6) {
        _showError('Le mot de passe doit contenir au moins 6 caractères.');
        return;
      }
      if (_passwordController.text != _confirmController.text) {
        _showError('Les mots de passe ne correspondent pas.');
        return;
      }
      setState(() => _step++);
      return;
    }

    final mobile = _mobileController.text.trim();
    final success = await context.read<AuthState>().signup(
          nom: _nomController.text,
          prenom: _prenomController.text,
          mobile: mobile.isEmpty ? null : mobile,
          password: _passwordController.text,
          email: _emailController.text.trim(),
          sousTraitant: _status == 'Sous-traitant',
          societe: _societeController.text.isEmpty ? null : _societeController.text,
        );

    if (!mounted) return;
    if (success) {
      context.go('/pending');
    } else {
      _showError(context.read<AuthState>().lastError ?? 'Inscription impossible');
    }
  }

  Future<void> _renvoyerCode() async {
    final ok = await context.read<AuthState>().requestEmailCode(_emailController.text.trim());
    if (!mounted) return;
    _showError(ok ? 'Un nouveau code a été envoyé par email.' : (context.read<AuthState>().lastError ?? 'Envoi impossible.'));
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: context.watch<AuthState>().isLoading ? null : _nextStep,
                    child: context.watch<AuthState>().isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_step == 4 ? 'Terminer' : 'Continuer'),
                  ),
                  if (_step == 1) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(foregroundColor: Colors.black),
                      child: const Text('Vous avez déjà un compte ? Connectez-vous'),
                    ),
                  ],
                ],
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
            _buildField(
              'Téléphone mobile',
              _mobileController,
              hint: 'Facultatif — avec l\'indicatif pays, ex : +33612345678',
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildField('Email', _emailController),
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
            const Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.orange),
            const SizedBox(height: 24),
            Text('Validation par email', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              'Saisissez le code à 6 chiffres envoyé à ${_emailController.text.trim()}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              child: TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _nextStep(),
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(onPressed: _renvoyerCode, child: const Text('Renvoyer le code')),
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

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    bool obscure = false,
    TextInputType? keyboardType,
  }) {
    if (obscure) {
      return PasswordField(
        controller: ctrl,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _nextStep(),
        decoration: InputDecoration(labelText: label, hintText: hint),
      );
    }
    return TextField(
      controller: ctrl,
      textInputAction: TextInputAction.next,
      keyboardType: keyboardType,
      onSubmitted: (_) => _nextStep(),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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
}
