import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vertical_app/core/widgets/vertical_app_bar.dart';
import 'package:vertical_app/core/widgets/vertical_logo.dart';

void main() {
  Future<void> pumpAppBar(WidgetTester tester, VerticalAppBar appBar) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(appBar: appBar, body: const SizedBox.shrink()),
      ),
    );
  }

  testWidgets('affiche toujours le logo, quel que soit l\'écran', (tester) async {
    await pumpAppBar(tester, const VerticalAppBar(showBackButton: false));
    expect(tester.takeException(), isNull);
    expect(find.byType(VerticalLogo), findsOneWidget);
  });

  testWidgets('showBackButton: false — pas de flèche de retour, jamais d\'overflow sur un mobile standard (360px)', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAppBar(tester, const VerticalAppBar(showBackButton: false, title: Text('Titre un peu long pour tester')));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('showBackButton: true — flèche affichée avant le logo (même position relative), jamais d\'overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAppBar(tester, const VerticalAppBar(showBackButton: true, title: Text('Titre un peu long pour tester')));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    final backRect = tester.getTopLeft(find.byIcon(Icons.arrow_back));
    final logoRect = tester.getTopLeft(find.byType(VerticalLogo));
    expect(backRect.dx, lessThan(logoRect.dx), reason: 'la flèche de retour précède le logo');
  });

  testWidgets('la flèche de retour dépile la route', (tester) async {
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        GoRoute(path: '/a', builder: (context, state) => Scaffold(body: TextButton(onPressed: () => context.push('/b'), child: const Text('aller'))),),
        GoRoute(
          path: '/b',
          builder: (context, state) => const Scaffold(appBar: VerticalAppBar(title: Text('Écran B')), body: SizedBox.shrink()),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('aller'));
    await tester.pumpAndSettle();
    expect(find.text('Écran B'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget, reason: 'canPop() est vrai depuis /b, la flèche doit apparaître automatiquement');

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('aller'), findsOneWidget, reason: 'retour à /a');
  });

  testWidgets('titre et actions optionnels s\'affichent quand fournis', (tester) async {
    await pumpAppBar(
      tester,
      VerticalAppBar(
        showBackButton: false,
        title: const Text('Mon titre'),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert))],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Mon titre'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });
}
