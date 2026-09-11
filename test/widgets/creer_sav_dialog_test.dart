import 'dart:io';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vertical_app/data/api_client.dart';
import 'package:vertical_app/data/local/app_database.dart';
import 'package:vertical_app/data/repositories/chantier_repository.dart';
import 'package:vertical_app/screens/backoffice/widgets/creer_sav_dialog.dart';
import 'package:vertical_app/screens/backoffice/widgets/nouveau_chantier_rapide_dialog.dart';
import 'package:vertical_app/state/chantier_state.dart';
import 'package:vertical_app/state/comptes_state.dart';

/// Doublure du point d'entrée générique "Nouveau" (voir bo_ct_chantiers_screen.dart
/// / ct_home_screen.dart) : ni ChantierState ni ComptesState n'exposent de
/// setter direct pour leurs listes — [createChantier] et [ComptesState.fetch]
/// sont les seuls chemins pour les peupler en test, donc cette doublure sert
/// à la fois de source pour le chantier d'installation existant (autocomplete)
/// et pour capturer les arguments transmis à la création du SAV.
class _FakeApiClient extends ApiClient {
  final Map<String, dynamic> chantierInstallationJson;
  final Map<String, dynamic> savChantierJson;
  final List<Map<String, dynamic>> comptesJson;
  String? lastReference;
  String? lastDescription;
  String? lastInstallateurId;

  _FakeApiClient({required this.chantierInstallationJson, required this.savChantierJson, required this.comptesJson});

  @override
  Future<Map<String, dynamic>> createChantier(Map<String, dynamic> body) async => {'chantier': chantierInstallationJson};

  @override
  Future<Map<String, dynamic>> createSav(
    String reference, {
    required String descriptionProbleme,
    required String installateurId,
    String? savDate,
  }) async {
    lastReference = reference;
    lastDescription = descriptionProbleme;
    lastInstallateurId = installateurId;
    return {'chantier': savChantierJson};
  }

  @override
  Future<List<dynamic>> getComptes() async => comptesJson;
}

Map<String, dynamic> _chantierJson({required String reference, required String client, String type = 'installation', String? parentReference}) => {
      'reference': reference,
      'client': client,
      'adresse': '4 rue des Frères Lumière',
      'ville': 'Meyzieu (69)',
      'dateDebut': '2026-07-21T00:00:00.000Z',
      'dateFin': '2026-07-23T00:00:00.000Z',
      'contactNom': 'M. Weber',
      'contactTel': '0612345678',
      'horaires': '6h30-17h00',
      'consignes': <String>[],
      'typeMonteCharge': 'Monte-charge non accompagné',
      'capacite': '300 kg',
      'niveaux': 2,
      'referenceAffaire': 'AF-2026-001',
      'syncStatus': 'charge',
      'rex': <Map<String, dynamic>>[],
      'pvSigne': false,
      'livretsOuverts': <String>[],
      'receptionMarchandises': <Map<String, dynamic>>[],
      'autoControle': <Map<String, dynamic>>[],
      'installateursRattaches': <Map<String, dynamic>>[],
      'docsTerrain': <Map<String, dynamic>>[],
      'type': type,
      'parentReference': ?parentReference,
    };

Map<String, dynamic> _compteJson({required String id, required String prenom, required String nom}) => {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'role': 'installateur',
      'status': 'salarie',
      'isActive': true,
      'suspendu': false,
      'habilitations': <Map<String, dynamic>>[],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  /// Prépare l'état (chantier d'installation existant + installateur actif)
  /// et ouvre le dialogue générique (sans chantier présélectionné) — le
  /// point d'entrée "Nouveau" du back-office/mobile CT.
  Future<_FakeApiClient> pumpDialog(WidgetTester tester) async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => Directory.systemTemp.path,
    );

    final api = _FakeApiClient(
      chantierInstallationJson: _chantierJson(reference: 'LD64397', client: 'Costockage'),
      savChantierJson: _chantierJson(reference: 'SAV-LD64397-1', client: 'Costockage', type: 'sav', parentReference: 'LD64397'),
      comptesJson: [_compteJson(id: 'user-1', prenom: 'Marin', nom: 'Dupont')],
    );
    final chantierState = ChantierState(ChantierRepository(api, AppDatabase()));
    await chantierState.createChantier({});
    final comptesState = ComptesState(api);
    await comptesState.fetch();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ChantierState>.value(value: chantierState),
          ChangeNotifierProvider<ComptesState>.value(value: comptesState),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => CreerSavDialog(chantierDetailPath: (ref) => '/backoffice/ct/chantiers/$ref'),
                ),
                child: const Text('ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    return api;
  }

  testWidgets('sans chantier d\'origine sélectionné, la création est bloquée avec un message clair', (tester) async {
    final api = await pumpDialog(tester);

    await tester.enterText(find.byType(TextField).at(1), 'Bruit anormal en cabine');
    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(find.text('Choisissez le chantier terminé.'), findsOneWidget);
    expect(api.lastReference, isNull, reason: 'createSav ne doit jamais être appelé sans chantier terminé sélectionné');
  });

  testWidgets('sélection du chantier via l\'autocomplete + description + installateur -> création OK', (tester) async {
    final api = await pumpDialog(tester);

    // Recherche par référence dans le champ autocomplete (premier TextField).
    await tester.enterText(find.byType(TextField).at(0), 'LD64397');
    await tester.pumpAndSettle();
    expect(find.text('LD64397 — Costockage'), findsOneWidget);
    await tester.tap(find.text('LD64397 — Costockage'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'Bruit anormal en cabine');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marin Dupont').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Créer'));
    await tester.pumpAndSettle();

    expect(api.lastReference, 'LD64397');
    expect(api.lastDescription, 'Bruit anormal en cabine');
    expect(api.lastInstallateurId, 'user-1');
    expect(find.byType(CreerSavDialog), findsNothing, reason: 'le dialogue se ferme après une création réussie');
  });

  testWidgets('bouton "Nouveau chantier" : le mini-formulaire crée le chantier et le présélectionne au retour', (tester) async {
    await pumpDialog(tester);

    await tester.tap(find.text('Nouveau chantier'));
    await tester.pumpAndSettle();
    expect(find.byType(NouveauChantierRapideDialog), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Référence'), 'LD64397');
    await tester.enterText(find.widgetWithText(TextField, 'Client'), 'Costockage');
    await tester.enterText(find.widgetWithText(TextField, 'Ville'), 'Meyzieu (69)');
    await tester.tap(find.text('Créer').last);
    await tester.pumpAndSettle();

    expect(find.byType(NouveauChantierRapideDialog), findsNothing, reason: 'retour au dialogue SAV après création');
    expect(find.byType(CreerSavDialog), findsOneWidget);
    expect(find.text('LD64397 — Costockage'), findsOneWidget, reason: 'chantier fraîchement créé présélectionné dans le champ');
  });
}
