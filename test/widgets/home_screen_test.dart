import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/theme.dart';
import 'package:vertical_app/core/widgets/glass_app_bar.dart';
import 'package:vertical_app/core/widgets/responsive_layout.dart';
import 'package:vertical_app/core/widgets/vertical_logo.dart';
import 'package:vertical_app/screens/installateur/home_screen.dart';

/// Reproduit exactement la structure de [InstallateurHomeScreen] (même
/// ResponsiveLayout/GlassAppBar/bottomNavigationBar, même Padding + Column +
/// 2 HomeTile) avec des données factices — évite de monter tout l'arbre de
/// providers (NetworkState a besoin d'un vrai Connectivity/AppDatabase/
/// SyncEngine, AuthState d'un AuthRepository, etc.) alors que ce test ne
/// porte que sur la mise en page : logo dans la bande sombre (à gauche),
/// "Accueil" juste en dessous, les deux tuiles visibles sans scroll.
Widget _buildScreen(BuildContext context) {
  return ResponsiveLayout(
    appBar: const GlassAppBar(
      title: VerticalLogo(height: 30, bubble: true),
      centerTitle: false,
      backgroundColor: AppColors.encre,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBar: Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(color: AppColors.blanc, border: Border(top: BorderSide(color: AppColors.lignes))),
      child: const Text('Connecté en tant que Test Installateur', textAlign: TextAlign.center),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accueil', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Expanded(
            child: HomeTile(
              titre: 'Mes chantiers',
              sousTitre: 'Installations en cours et terminées',
              icon: Icons.construction_outlined,
              count: 3,
              onTap: () {},
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: HomeTile(
              titre: 'Interventions SAV',
              sousTitre: 'Service après-vente',
              icon: Icons.build_outlined,
              count: 1,
              onTap: () {},
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: Builder(builder: _buildScreen)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('360×640 (mobile standard) : logo dans l\'AppBar (à gauche), "Accueil" en dessous, tuiles visibles sans scroll', (tester) async {
    await _pumpAt(tester, const Size(360, 640));

    expect(tester.takeException(), isNull, reason: 'aucun débordement (RenderFlex overflow) ne doit survenir');

    // Logo dans la bande sombre, une seule fois, aligné à gauche (pas centré).
    expect(find.byType(VerticalLogo), findsOneWidget);
    final logoRect = tester.getTopLeft(find.byType(VerticalLogo));
    expect(logoRect.dx, lessThan(100), reason: 'le logo doit être aligné à gauche de l\'AppBar, pas centré');
    expect(logoRect.dy, lessThan(56), reason: 'le logo est dans la bande sombre (AppBar), pas dans le corps');

    // "Accueil" apparaît une seule fois désormais (plus de doublon AppBar +
    // corps) — juste sous la bande du logo.
    expect(find.text('Accueil'), findsOneWidget);
    final accueilRect = tester.getTopLeft(find.text('Accueil'));
    expect(accueilRect.dy, greaterThanOrEqualTo(56), reason: '"Accueil" est sous l\'AppBar (56px), jamais dedans');

    expect(find.text('Mes chantiers'), findsOneWidget);
    expect(find.text('Interventions SAV'), findsOneWidget);

    // Les deux tuiles doivent être dans le viewport, pas seulement dans
    // l'arbre — "findsOneWidget" seul n'exclut pas un widget rendu hors
    // écran (0 hauteur ou position au-delà de la fenêtre).
    final tuile1 = tester.getRect(find.text('Mes chantiers'));
    final tuile2 = tester.getRect(find.text('Interventions SAV'));
    expect(tuile1.bottom, lessThanOrEqualTo(640));
    expect(tuile2.bottom, lessThanOrEqualTo(640));
    expect(tuile1.height, greaterThan(0));
    expect(tuile2.height, greaterThan(0));
  });

  testWidgets('écran bas (360×550) : toujours pas d\'overflow — le logo, désormais dans l\'AppBar, n\'occupe plus de budget dans le corps',
      (tester) async {
    await _pumpAt(tester, const Size(360, 550));
    expect(tester.takeException(), isNull);
    expect(find.text('Mes chantiers'), findsOneWidget);
    expect(find.text('Interventions SAV'), findsOneWidget);
  });

  testWidgets('sous-titres des tuiles à taille lisible (≥14px), jamais minuscules', (tester) async {
    await _pumpAt(tester, const Size(360, 640));

    final sousTitre1 = tester.widget<Text>(find.text('Installations en cours et terminées'));
    final sousTitre2 = tester.widget<Text>(find.text('Service après-vente'));
    expect(sousTitre1.style?.fontSize, greaterThanOrEqualTo(14));
    expect(sousTitre2.style?.fontSize, greaterThanOrEqualTo(14));
  });
}
