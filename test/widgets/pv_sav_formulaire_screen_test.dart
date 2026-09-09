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
import 'package:vertical_app/screens/client/pv_sav_formulaire_screen.dart';
import 'package:vertical_app/state/chantier_state.dart';

/// Même principe que pv_formulaire_screen_test.dart : tests contre le VRAI
/// écran (pas une reproduction).
Chantier _savDeTest({bool pvSigne = false}) {
  return Chantier.fromJson({
    'reference': 'SAV-LD64397-1',
    'client': 'Transgourmet Ouest',
    'adresse': '12 avenue des Landes',
    'ville': 'Saint-Herblain (44)',
    'dateDebut': '2026-09-09T00:00:00.000Z',
    'dateFin': '2026-09-09T00:00:00.000Z',
    'contactNom': 'Contact Transgourmet',
    'contactTel': '0200000000',
    'horaires': '8h00-18h00',
    'consignes': ['Consignes standard'],
    'typeMonteCharge': 'Monte-charge accompagné',
    'capacite': '500 kg',
    'niveaux': 3,
    'referenceAffaire': 'AF-2026-042',
    'syncStatus': 'charge',
    'type': 'sav',
    'parentReference': 'LD64397',
    'descriptionIntervention': 'Bruit anormal en cabine',
    'rex': [],
    'pvSigne': pvSigne,
    'livretsOuverts': [],
    'receptionMarchandises': [],
    'autoControle': [],
    'installateursRattaches': [],
    'docsTerrain': [],
  });
}

Future<ChantierState> _pumpEcran(WidgetTester tester, {bool pvSigne = false}) async {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    channel,
    (call) async => Directory.systemTemp.path,
  );

  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final chantierState = ChantierState(ChantierRepository(ApiClient(), AppDatabase()));
  chantierState.selectChantier(_savDeTest(pvSigne: pvSigne));

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const PvSavFormulaireScreen()),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('affiche les informations du chantier d\'origine en en-tête', (tester) async {
    await _pumpEcran(tester);
    expect(find.text('LD64397'), findsOneWidget);
    expect(find.text('Transgourmet Ouest'), findsOneWidget);
  });

  testWidgets('la section Description est ouverte par défaut, les autres sont repliées', (tester) async {
    await _pumpEcran(tester);
    expect(find.widgetWithText(TextField, 'Description de l\'intervention'), findsOneWidget);
    expect(find.byType(SignaturePad), findsNothing);
  });

  testWidgets('le bouton de validation est grisé tant que description et signature manquent', (tester) async {
    await _pumpEcran(tester);

    final bouton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Valider le procès-verbal'));
    expect(bouton.onPressed, isNull);
    expect(find.textContaining('Description de l\'intervention requise'), findsWidgets);
  });

  testWidgets('remplir description, pièces (optionnel), nom/fonction et tracer la signature active le bouton', (tester) async {
    await _pumpEcran(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Description de l\'intervention'), 'Remplacement du contacteur de porte.');
    await tester.pump();

    await tester.tap(find.text('Signature'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Nom du signataire (client)'), 'M. Weber');
    await tester.enterText(find.widgetWithText(TextField, 'Fonction du signataire'), 'Client');
    await tester.pump();

    var bouton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Valider le procès-verbal'));
    expect(bouton.onPressed, isNull, reason: 'la signature elle-même n\'est pas encore tracée');

    final signatureFinder = find.byType(SignaturePad);
    await tester.dragFrom(tester.getCenter(signatureFinder), const Offset(40, 0));
    await tester.pumpAndSettle();

    bouton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Valider le procès-verbal'));
    expect(bouton.onPressed, isNotNull, reason: 'tout est renseigné, le bouton doit être actif');
  });

  testWidgets('un PV SAV déjà signé redirige sans afficher le formulaire', (tester) async {
    await _pumpEcran(tester, pvSigne: true);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('Valider le procès-verbal'), findsNothing);
  });
}
