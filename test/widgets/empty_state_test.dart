import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/widgets/empty_state.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('affiche le message et le cercle d\'icône par défaut', (tester) async {
    await pump(tester, const EmptyState(icon: Icons.inbox_outlined, message: 'Rien à afficher.'));
    await tester.pumpAndSettle();

    expect(find.text('Rien à afficher.'), findsOneWidget);
    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
  });

  testWidgets('le bouton d\'action n\'apparaît que si actionLabel et onAction sont tous les deux fournis', (tester) async {
    await pump(tester, const EmptyState(icon: Icons.inbox_outlined, message: 'Rien à afficher.'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter'), findsNothing);

    var tapped = false;
    await pump(
      tester,
      EmptyState(icon: Icons.inbox_outlined, message: 'Rien à afficher.', actionLabel: 'Ajouter', onAction: () => tapped = true),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ajouter'), findsOneWidget);

    await tester.tap(find.text('Ajouter'));
    expect(tapped, isTrue);
  });

  testWidgets('illustration (monte-charge) remplace le cercle d\'icône quand fournie, sans erreur de rendu', (tester) async {
    await pump(
      tester,
      const EmptyState(message: 'Aucun REX soumis pour l\'instant.', illustration: MonteChargeIllustration()),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Aucun REX soumis pour l\'instant.'), findsOneWidget);
  });
}
