import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/widgets/responsive_layout.dart';
import 'package:vertical_app/core/widgets/vertical_pattern_background.dart';

void main() {
  testWidgets('se rend sans erreur et occupe tout l\'espace disponible', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SizedBox(width: 300, height: 500, child: VerticalPatternBackground())),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(VerticalPatternBackground), findsOneWidget);
    expect(tester.getSize(find.byType(VerticalPatternBackground)), const Size(300, 500));
  });

  testWidgets('ResponsiveLayout applique le filigrane par défaut, sous le contenu, sans casser le layout', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveLayout(
          child: Center(child: Text('Contenu de l\'écran')),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(VerticalPatternBackground), findsOneWidget);
    expect(find.text('Contenu de l\'écran'), findsOneWidget);

    // Le filigrane est bien SOUS le contenu (premier dans le Stack), jamais
    // au-dessus — sans quoi il masquerait le contenu réel de l'écran.
    final stack = tester.widget<Stack>(find.byType(Stack).first);
    expect(stack.children.first, isA<Positioned>());
  });

  testWidgets('showPattern: false désactive le filigrane pour un écran qui n\'en a pas besoin', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveLayout(
          showPattern: false,
          child: Center(child: Text('Plein écran')),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(VerticalPatternBackground), findsNothing);
    expect(find.text('Plein écran'), findsOneWidget);
  });
}
