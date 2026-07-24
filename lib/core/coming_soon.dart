import 'package:flutter/material.dart';

/// À brancher sur les actions non encore implémentées, pour ne jamais
/// laisser un bouton silencieusement sans effet.
void showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Fonctionnalité en cours de développement')),
  );
}
