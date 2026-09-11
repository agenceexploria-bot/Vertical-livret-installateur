import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/widgets/glass_app_bar.dart';
import '../../core/widgets/responsive_layout.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/widgets/vertical_logo.dart';
import '../../state/auth_state.dart';
import '../../state/network_state.dart';
import '../../state/chantier_state.dart';

/// Accueil installateur — module SAV : deux tuiles menant chacune à sa
/// propre liste ("Mes chantiers" pour les installations, voir
/// ChantiersInstallationScreen ; "Interventions SAV", voir SavListScreen).
/// Le fetch est déclenché ici une seule fois, les deux écrans de liste
/// lisent ensuite le même ChantierState déjà chargé (et refont un fetch
/// défensif si on les atteint directement, voir leur propre initState).
class InstallateurHomeScreen extends StatefulWidget {
  const InstallateurHomeScreen({super.key});

  @override
  State<InstallateurHomeScreen> createState() => _InstallateurHomeScreenState();
}

class _InstallateurHomeScreenState extends State<InstallateurHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthState>().currentUser;
      if (user != null) {
        context.read<ChantierState>().fetchChantiers(user);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final networkState = context.watch<NetworkState>();
    final chantierState = context.watch<ChantierState>();
    final authState = context.watch<AuthState>();
    final user = authState.currentUser;

    return ResponsiveLayout(
      appBar: GlassAppBar(
        title: const Text('Accueil'),
        backgroundColor: AppColors.encre,
        foregroundColor: Colors.white,
        actions: [
          Icon(networkState.isOnline ? Icons.wifi : Icons.wifi_off, color: Colors.white),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.push('/profil'),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: UserAvatar(user: user, radius: 15),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.blanc,
          border: Border(top: BorderSide(color: AppColors.lignes)),
        ),
        child: Text(
          'Connecté en tant que ${user?.fullName ?? ''}',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
      child: chantierState.isLoading && chantierState.chantiers.isEmpty
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      HomeLogoHeader(constraints: constraints),
                      const SizedBox(height: 14),
                      Expanded(
                        child: HomeTile(
                          titre: 'Mes chantiers',
                          sousTitre: 'Installations en cours et terminées',
                          icon: Icons.construction_outlined,
                          count: chantierState.chantiersInstallationList.length,
                          onTap: () => context.push('/mes-chantiers'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: HomeTile(
                          titre: 'Interventions SAV',
                          sousTitre: 'Service après-vente',
                          icon: Icons.build_outlined,
                          count: chantierState.chantiersSavList.length,
                          onTap: () => context.push('/sav'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

/// Logo + "Accueil" au-dessus des tuiles — hauteur du logo adaptative
/// (priorité absolue : les deux tuiles doivent rester visibles sans scroll
/// sur un écran mobile standard, voir home_screen_test.dart). 64px sur
/// mobile, jusqu'à 80px sur grand écran ; repli à 48px si la hauteur
/// réellement disponible pour ce bloc + les deux tuiles est trop serrée
/// (petit écran, clavier...) — jamais le logo ne doit pousser les tuiles
/// hors écran. Le seuil "grand écran" se base sur MediaQuery (largeur
/// réelle de l'appareil/fenêtre), pas sur [constraints] : ResponsiveLayout
/// plafonne la largeur de contenu à 500px pour simuler un mobile même sur
/// le Web, donc constraints.maxWidth ne dépasse jamais ce seuil.
/// [constraints], lui, sert au repli sur la hauteur (jamais plafonnée de la
/// même façon par ResponsiveLayout).
class HomeLogoHeader extends StatelessWidget {
  final BoxConstraints constraints;

  const HomeLogoHeader({super.key, required this.constraints});

  @override
  Widget build(BuildContext context) {
    final base = MediaQuery.sizeOf(context).width >= 600 ? 80.0 : 64.0;
    // Sur un mobile standard (360×640, la cible visée), la hauteur dispo pour
    // ce bloc + les deux tuiles mesure ~479px une fois AppBar, barre du bas
    // et padding déduits — [base] y tient encore confortablement (mesuré,
    // voir home_screen_test.dart) ; en dessous de 470, le contenu des tuiles
    // (titre + sous-titre + badge) ne tient plus à 64px, d'où le repli 48px.
    final logoHeight = constraints.maxHeight < 470 ? 48.0 : base;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VerticalLogo(height: logoHeight),
        const SizedBox(height: 4),
        Text('Accueil', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class HomeTile extends StatelessWidget {
  final String titre;
  final String sousTitre;
  final IconData icon;
  final int count;
  final VoidCallback onTap;

  const HomeTile({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.icon,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.encre,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Icon(icon, size: 44, color: Colors.white),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titre,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sousTitre,
                      // Sur une seule ligne : à deux lignes, ce sous-titre
                      // fait déborder la tuile une fois la hauteur réduite
                      // par le logo compact au-dessus (voir HomeLogoHeader
                      // et home_screen_test.dart).
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
