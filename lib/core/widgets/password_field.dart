import 'package:flutter/material.dart';

/// Champ de mot de passe avec icône œil pour afficher/masquer la saisie en
/// clair — l'état d'affichage est propre à chaque champ (utile notamment dans
/// les dialogues de réinitialisation, où plusieurs instances peuvent coexister).
class PasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final InputDecoration decoration;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const PasswordField({
    super.key,
    this.controller,
    this.decoration = const InputDecoration(),
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      decoration: widget.decoration.copyWith(
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
