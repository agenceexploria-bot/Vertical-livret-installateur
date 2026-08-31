import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:vertical_app/data/api_client.dart';
import 'package:vertical_app/data/local/app_database.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/data/repositories/chantier_repository.dart';
import 'package:vertical_app/core/widgets/signature_pad.dart';
import 'package:vertical_app/screens/client/pv_formulaire_screen.dart';
import 'package:vertical_app/state/chantier_state.dart';

/// Tests contre le VRAI écran (pas une reproduction) — après la 3e
/// régression de visibilité sur ce formulaire (bouton de validation, pavé de
/// signature), seule une preuve sur le widget réel compte. AppDatabase
/// (Drift) a besoin de path_provider, indisponible tel quel en `flutter
/// test` : on mocke son canal pour pointer vers un répertoire temporaire réel.
Chantier _chantierDeTest({bool pvSigne = false}) {
  return Chantier.fromJson({
    'reference': 'LD91245',
    'client': 'Transgourmet Ouest',
    'adresse': '12 avenue des Landes',
    'ville': 'Saint-Herblain (44)',
    'dateDebut': '2026-08-04T00:00:00.000Z',
    'dateFin': '2026-08-05T00:00:00.000Z',
    'contactNom': 'Contact Transgourmet',
    'contactTel': '0200000000',
    'horaires': '8h00-18h00',
    'consignes': ['Consignes standard'],
    'typeMonteCharge': 'Monte-charge accompagné',
    'capacite': '500 kg',
    'niveaux': 3,
    'referenceAffaire': 'AF-2026-042',
    'syncStatus': 'charge',
    'rex': [],
    'pvSigne': pvSigne,
    'livretsOuverts': [],
    'receptionMarchandises': [],
    'autoControle': [],
    'installateursRattaches': [],
    'docsTerrain': [],
  });
}

/// [tall] agrandit la fenêtre de test pour que tout le formulaire (assez
/// long) tienne sans avoir à faire défiler explicitement dans chaque test —
/// sauf le test dédié au défilement lui-même, qui garde la taille normale
/// pour prouver que scroller fonctionne vraiment (voir plus bas).
Future<ChantierState> _pumpEcran(WidgetTester tester, {bool pvSigne = false, bool tall = true}) async {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async => Directory.systemTemp.path,
  );

  if (tall) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  final chantierState = ChantierState(ChantierRepository(ApiClient(), AppDatabase()));
  chantierState.selectChantier(_chantierDeTest(pvSigne: pvSigne));

  // Un vrai GoRouter minimal : le verrou "déjà signé" appelle context.go
  // dans un post-frame callback, qui a besoin d'un GoRouter ancêtre pour ne
  // pas planter le test — même s'il n'est jamais réellement exercé dans les
  // autres tests (aucun ne va jusqu'à la validation).
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const PvFormulaireScreen()),
      GoRoute(path: '/confirmation', builder: (context, state) => const Scaffold(body: Text('confirmation'))),
    ],
  );

  await tester.pumpWidget(
    ChangeNotifierProvider<ChantierState>.value(
      value: chantierState,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return chantierState;
}

/// Coche "Oui" sur toutes les questions Oui/Non visibles à l'écran — utilisé
/// après avoir ouvert successivement chaque section de checklist.
/// [ButtonSegment] n'est qu'une description de données pour [SegmentedButton]
/// — jamais un Widget dans l'arbre rendu — donc on cible directement le
/// texte "Oui" affiché (chaque item de checklist n'en montre qu'un).
Future<void> _repondreOuiATout(WidgetTester tester) async {
  final ouiTexts = find.text('Oui');
  final count = ouiTexts.evaluate().length;
  for (var i = 0; i < count; i++) {
    await tester.tap(ouiTexts.at(i));
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Chaque test construit son propre AppDatabase jetable (voir _pumpEcran) —
  // le warning "multiple databases" de Drift ne s'applique pas ici (chacune
  // a son propre fichier temporaire, jamais partagé).
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('affiche les informations du chantier en en-tête', (tester) async {
    await _pumpEcran(tester);
    expect(find.text('Transgourmet Ouest'), findsOneWidget);
    expect(find.text('AF-2026-042'), findsOneWidget);
  });

  testWidgets('la section 1 est ouverte par défaut, les autres sont repliées', (tester) async {
    await _pumpEcran(tester);
    // 4 questions en section 1 (1.1 à 1.4) visibles d'emblée...
    expect(find.textContaining('1.1'), findsOneWidget);
    // ...mais pas celles de la section 2 (2.1 à 2.5), repliée.
    expect(find.textContaining('2.1'), findsNothing);
  });

  testWidgets('taper sur le titre d\'une section l\'ouvre et referme la précédente (mode exclusif)', (tester) async {
    await _pumpEcran(tester);
    expect(find.textContaining('1.1'), findsOneWidget);

    await tester.tap(find.text('Section 2 — Documents remis au client'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1.1'), findsNothing, reason: 'la section 1 doit se replier');
    expect(find.textContaining('2.1'), findsOneWidget, reason: 'la section 2 doit s\'ouvrir');

    // Un second tap sur le même titre la referme.
    await tester.tap(find.text('Section 2 — Documents remis au client'));
    await tester.pumpAndSettle();
    expect(find.textContaining('2.1'), findsNothing);
  });

  testWidgets('le bouton de validation est grisé et liste ce qui manque tant que le formulaire est incomplet', (tester) async {
    await _pumpEcran(tester);

    final bouton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Valider le procès-verbal'));
    expect(bouton.onPressed, isNull, reason: 'rien n\'est rempli, le bouton doit être désactivé');
    expect(find.textContaining('Section 1 :'), findsOneWidget);
    // 2 occurrences attendues : la pastille d'avertissement sur le titre de
    // la section Signature, et la même raison reprise dans le récapitulatif
    // sous le bouton de validation.
    expect(find.textContaining('Signature du client manquante'), findsNWidgets(2));
  });

  testWidgets('le formulaire entier est scrollable : la section Signature, tout en bas, reste atteignable', (tester) async {
    // Taille d'écran normale (pas agrandie) : sans un vrai scroll qui
    // fonctionne, "Signature" serait hors-écran et injoignable — exactement
    // la classe de bug que cette réécriture doit éliminer.
    await _pumpEcran(tester, tall: false);

    final titreSignature = find.text('Signature');
    await tester.ensureVisible(titreSignature);
    await tester.pumpAndSettle();
    await tester.tap(titreSignature);
    await tester.pumpAndSettle();

    final signatureFinder = find.byType(SignaturePad);
    await tester.ensureVisible(signatureFinder);
    await tester.pumpAndSettle();
    expect(signatureFinder, findsOneWidget);
    expect(tester.getSize(signatureFinder).height, greaterThan(0));
  });

  testWidgets(
    'le pavé de signature se rend avec une hauteur non nulle, reste tactile, et le bouton s\'active une fois tout complété',
    (tester) async {
      await _pumpEcran(tester);

      // Répond "Oui" partout, section par section (il faut ouvrir chaque
      // section pour que ses champs soient montés et donc trouvables).
      await _repondreOuiATout(tester); // section 1, déjà ouverte

      await tester.tap(find.text('Section 2 — Documents remis au client'));
      await tester.pumpAndSettle();
      await _repondreOuiATout(tester);

      await tester.tap(find.text('Section 3 — Services et nature de pose'));
      await tester.pumpAndSettle();
      await _repondreOuiATout(tester);

      await tester.tap(find.text('Signature'));
      await tester.pumpAndSettle();

      final signatureFinder = find.byType(SignaturePad);
      expect(signatureFinder, findsOneWidget, reason: 'le pavé de signature doit être monté une fois la section ouverte');
      final taille = tester.getSize(signatureFinder);
      expect(taille.height, greaterThan(0), reason: 'jamais une hauteur nulle');

      await tester.enterText(find.widgetWithText(TextField, 'Nom du signataire (client)'), 'M. Weber');
      await tester.enterText(find.widgetWithText(TextField, 'Fonction du signataire'), 'Client');
      await tester.pump();

      // Toujours incomplet : la signature elle-même n'est pas encore tracée.
      var bouton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Valider le procès-verbal'));
      expect(bouton.onPressed, isNull);

      await tester.dragFrom(tester.getCenter(signatureFinder), const Offset(40, 0));
      await tester.pumpAndSettle();

      bouton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Valider le procès-verbal'));
      expect(bouton.onPressed, isNotNull, reason: 'tout est renseigné, le bouton doit maintenant être actif');
      expect(find.textContaining('Avant de valider'), findsNothing);
    },
  );

  testWidgets('un chantier déjà signé redirige sans afficher le formulaire', (tester) async {
    await _pumpEcran(tester, pvSigne: true);
    // La redirection passe par go_router (context.go), absent de ce test —
    // on vérifie seulement que le formulaire n'est jamais construit, ce qui
    // est le vrai risque (rouvrir un PV déjà signé en édition).
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('Valider le procès-verbal'), findsNothing);
  });
}
