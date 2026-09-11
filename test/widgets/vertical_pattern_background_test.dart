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

  test('espacement du filigrane réduit — motif dense (40-50px), pas clairsemé', () {
    expect(verticalPatternSpacing, greaterThanOrEqualTo(40));
    expect(verticalPatternSpacing, lessThanOrEqualTo(50));
  });

  test('set d\'icônes riche et 100% chantier — aucune icône hors-thème (ex: ancre)', () {
    expect(verticalPatternIcons.length, greaterThanOrEqualTo(12));
    expect(verticalPatternIcons.toSet().length, verticalPatternIcons.length, reason: 'aucun doublon');
    expect(verticalPatternIcons, isNot(contains(Icons.anchor_outlined)));
    expect(verticalPatternIcons, isNot(contains(Icons.anchor)));
  });

  test('bruit du filigrane déterministe — même position + même canal = toujours la même valeur', () {
    final a = verticalPatternJitter(3, 7, 1);
    final b = verticalPatternJitter(3, 7, 1);
    expect(a, equals(b), reason: 'aucun flickering : deux peintures produisent la même disposition');
    expect(a, inInclusiveRange(0.0, 1.0));

    // Des canaux différents (décalage X, décalage Y, rotation, taille, icône)
    // pour la même position ne doivent pas dégénérer en une seule constante.
    final valeurs = List.generate(5, (salt) => verticalPatternJitter(3, 7, salt));
    expect(valeurs.toSet().length, greaterThan(1));
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
