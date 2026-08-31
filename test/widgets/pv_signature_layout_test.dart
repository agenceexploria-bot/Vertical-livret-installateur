import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/widgets/signature_pad.dart';

/// Reproduit fidèlement la structure de _buildSignatureStep dans
/// pv_formulaire_screen.dart (Column → Expanded(SingleChildScrollView) →
/// footer) pour vérifier, indépendamment du reste de l'app (pas besoin de
/// ChantierState/routing), que le SignaturePad — dans son Container(height:
/// 160) exact — se rend bien avec une taille non nulle et reste
/// interactif. Sert à trancher entre "widget oublié dans la migration" et
/// "widget monté mais écrasé à hauteur 0" évoqués dans le rapport de bug.
Widget _buildSignatureStepReplica({required ValueChanged<bool> onSignatureChanged}) {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Signature'),
                  const SizedBox(height: 200), // simule le contenu au-dessus (date, champs, case Vertical...)
                  const Text('Cachet et signature du client'),
                  const SizedBox(height: 6),
                  Container(
                    height: 160,
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                    child: SignaturePad(key: const Key('signature-pad'), onChanged: onSignatureChanged),
                  ),
                  const SizedBox(height: 4),
                  TextButton(onPressed: () {}, child: const Text('Effacer la signature')),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(onPressed: () {}, child: const Text('Précédent')),
                  const Spacer(),
                  ElevatedButton(onPressed: () {}, child: const Text('Valider le procès-verbal')),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('le SignaturePad se rend avec une hauteur non nulle dans le layout footer fixe', (tester) async {
    await tester.pumpWidget(_buildSignatureStepReplica(onSignatureChanged: (_) {}));
    await tester.pumpAndSettle();

    final finder = find.byKey(const Key('signature-pad'));
    expect(finder, findsOneWidget, reason: 'le SignaturePad doit être monté dans l\'arbre de widgets');

    final size = tester.getSize(finder);
    expect(size.height, greaterThan(0), reason: 'le SignaturePad ne doit jamais être rendu à hauteur 0');
    // 160 moins l'inset implicite de 1px par côté que Container ajoute pour
    // son bord (BoxDecoration.border) quand aucun padding explicite n'est
    // fourni — comportement normal, pas un défaut du layout.
    expect(size.height, closeTo(158, 0.5), reason: 'la hauteur doit correspondre au Container(height: 160) qui l\'enveloppe (moins le bord)');
  });

  testWidgets('le SignaturePad reste interactif (un tracé notifie bien onChanged)', (tester) async {
    var signatureVide = true;
    await tester.pumpWidget(_buildSignatureStepReplica(onSignatureChanged: (vide) => signatureVide = vide));
    await tester.pumpAndSettle();

    final finder = find.byKey(const Key('signature-pad'));
    await tester.dragFrom(tester.getCenter(finder), const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(signatureVide, isFalse, reason: 'un tracé sur le pavé doit désactiver l\'état "signature vide"');
  });
}
