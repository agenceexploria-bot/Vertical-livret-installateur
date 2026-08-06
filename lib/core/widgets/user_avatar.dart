import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../../data/models/user.dart';

/// Avatar circulaire d'un utilisateur : sa photo de profil si elle existe
/// (mise en cache via [CachedNetworkImage], pas rechargée à chaque affichage),
/// sinon ses initiales sur fond de couleur — y compris si l'URL casse
/// (fichier supprimé, réseau indisponible...), pour ne jamais laisser un
/// cercle vide. Utilisé partout où un avatar est affiché (barre du
/// back-office, en-têtes mobiles, fiche profil) pour un rendu cohérent.
class UserAvatar extends StatelessWidget {
  final User? user;
  final double radius;

  const UserAvatar({super.key, required this.user, this.radius = 15});

  String get _initials {
    final u = user;
    if (u == null) return '?';
    return '${u.prenom.isNotEmpty ? u.prenom[0] : ''}${u.nom.isNotEmpty ? u.nom[0] : ''}'.toUpperCase();
  }

  Widget _buildInitials() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.acier,
      child: Text(
        _initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.75),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user?.avatarUrl;
    if (avatarUrl == null || avatarUrl.isEmpty) return _buildInitials();

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatarUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildInitials(),
        errorWidget: (context, url, error) => _buildInitials(),
      ),
    );
  }
}
