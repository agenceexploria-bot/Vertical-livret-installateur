import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/theme.dart';
import 'package:vertical_app/core/widgets/glass_app_bar.dart';
import 'package:vertical_app/core/widgets/responsive_layout.dart';
import 'package:vertical_app/core/widgets/vertical_logo.dart';
import 'package:vertical_app/screens/installateur/home_screen.dart';

/// Reproduit exactement la structure de [InstallateurHomeScreen] (même
/// ResponsiveLayout/GlassAppBar/bottomNavigationBar, même Padding +
/// LayoutBuilder + HomeLogoHeader + 2 HomeTile) avec des données factices —
/// évite de monter tout l'arbre de providers (NetworkState a besoin d'un
/// vrai Connectivity/AppDatabase/SyncEngine, AuthState d'un AuthRepository,
/// etc.) alors que ce test ne porte que sur la mise en page : logo + les
/// deux tuiles doivent rester visibles sans scroll sur un écran mobile
/// standard (voir home_screen.dart, HomeLogoHeader).
Widget _buildScreen() {
  return ResponsiveLayout(
    appBar: const GlassAppBar(
      title: Text('Accueil'),
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
          );
        },
      ),
    ),
  );
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MaterialApp(home: _buildScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('360×640 (mobile standard) : logo (64px) + les deux tuiles visibles sans scroll ni overflow', (tester) async {
    await _pumpAt(tester, const Size(360, 640));

    expect(tester.takeException(), isNull, reason: 'aucun débordement (RenderFlex overflow) ne doit survenir');
    expect(find.byType(VerticalLogo), findsOneWidget);
    // 2 : le titre de la GlassAppBar dit aussi "Accueil" — seul le second
    // (sous le logo) nous intéresse ici, voir HomeLogoHeader.
    expect(find.text('Accueil'), findsNWidgets(2));
    expect(find.text('Mes chantiers'), findsOneWidget);
    expect(find.text('Interventions SAV'), findsOneWidget);

    final logoWidget = tester.widget<VerticalLogo>(find.byType(VerticalLogo));
    expect(logoWidget.height, 64.0, reason: 'taille normale sur un mobile standard, pas le repli d\'urgence');

    // Les deux tuiles doivent être dans le viewport, pas seulement dans
    // l'arbre — "findsOneWidget" seul n'exclut pas un widget rendu hors
    // écran (0 hauteur ou position au-delà de la fenêtre).
    final logo = tester.getRect(find.byType(VerticalLogo));
    final tuile1 = tester.getRect(find.text('Mes chantiers'));
    final tuile2 = tester.getRect(find.text('Interventions SAV'));
    expect(logo.top, greaterThanOrEqualTo(0));
    expect(tuile1.bottom, lessThanOrEqualTo(640));
    expect(tuile2.bottom, lessThanOrEqualTo(640));
    expect(tuile1.height, greaterThan(0));
    expect(tuile2.height, greaterThan(0));
  });

  testWidgets('grand écran (largeur ≥ 600) : le logo passe à 80px', (tester) async {
    await _pumpAt(tester, const Size(700, 1000));

    expect(tester.takeException(), isNull);
    final logoWidget = tester.widget<VerticalLogo>(find.byType(VerticalLogo));
    expect(logoWidget.height, 80.0);
  });

  testWidgets('écran bas (360×620) : le logo réduit à 48px, les deux tuiles restent visibles sans overflow', (tester) async {
    await _pumpAt(tester, const Size(360, 620));

    expect(tester.takeException(), isNull, reason: 'jamais le logo ne doit pousser les tuiles hors écran');
    final logoWidget = tester.widget<VerticalLogo>(find.byType(VerticalLogo));
    expect(logoWidget.height, 48.0);

    final tuile1 = tester.getRect(find.text('Mes chantiers'));
    final tuile2 = tester.getRect(find.text('Interventions SAV'));
    expect(tuile1.bottom, lessThanOrEqualTo(620));
    expect(tuile2.bottom, lessThanOrEqualTo(620));
  });
}
