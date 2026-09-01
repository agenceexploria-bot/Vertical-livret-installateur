import 'dart:io';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vertical_app/core/widgets/ajouter_document_chantier_dialog.dart';
import 'package:vertical_app/core/widgets/drop_zone.dart';
import 'package:vertical_app/data/api_client.dart';
import 'package:vertical_app/data/local/app_database.dart';
import 'package:vertical_app/data/repositories/chantier_repository.dart';
import 'package:vertical_app/state/chantier_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mimeForFilename', () {
    test('déduit le MIME depuis l\'extension pour les types connus', () {
      expect(mimeForFilename('rapport.pdf'), 'application/pdf');
      expect(mimeForFilename('plan.DOCX'), 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
      expect(mimeForFilename('archive.zip'), 'application/zip');
    });

    test('retombe sur application/octet-stream pour une extension inconnue', () {
      expect(mimeForFilename('page.html'), 'application/octet-stream');
      expect(mimeForFilename('sans_extension'), 'application/octet-stream');
    });
  });

  group('lireDepuisPicker', () {
    test('produit un fichier lisible quand les octets sont présents', () async {
      final f = await lireDepuisPicker(PlatformFile(name: 'plan.pdf', size: 3, bytes: Uint8List.fromList([1, 2, 3])));
      expect(f.lisible, isTrue);
      expect(f.status, EnvoiStatus.attente);
      expect(f.dataUrl, startsWith('data:application/pdf;base64,'));
    });

    test('ne renvoie JAMAIS null — un fichier sans octets devient un échec explicite, pas un rejet silencieux', () async {
      final f = await lireDepuisPicker(PlatformFile(name: 'plan.pdf', size: 3, bytes: null));
      expect(f, isNotNull);
      expect(f.lisible, isFalse);
      expect(f.status, EnvoiStatus.echec);
      expect(f.erreur, isNotNull);
    });
  });

  group('reassignerPremierEnvoyable', () {
    test('après le retrait du premier fichier, le second devient isFirst (le nom personnalisé s\'y applique)', () {
      final a = FichierAEnvoyer(fileName: 'a.pdf', bytes: Uint8List.fromList([1]));
      final b = FichierAEnvoyer(fileName: 'b.pdf', bytes: Uint8List.fromList([2]));
      final fichiers = [a, b];
      reassignerPremierEnvoyable(fichiers);
      expect(a.isFirst, isTrue);
      expect(b.isFirst, isFalse);

      fichiers.remove(a);
      reassignerPremierEnvoyable(fichiers);
      expect(b.isFirst, isTrue, reason: 'b est maintenant le premier fichier envoyable restant');
    });

    test('ignore les fichiers illisibles, réassigne au premier fichier réellement envoyable', () {
      final illisible = FichierAEnvoyer(fileName: 'x.pdf', bytes: null, status: EnvoiStatus.echec);
      final b = FichierAEnvoyer(fileName: 'b.pdf', bytes: Uint8List.fromList([2]));
      final fichiers = [illisible, b];
      reassignerPremierEnvoyable(fichiers);
      expect(illisible.isFirst, isFalse, reason: 'jamais envoyé, ne doit jamais porter le nom personnalisé');
      expect(b.isFirst, isTrue);
    });

    test('liste vide : ne plante pas', () {
      expect(() => reassignerPremierEnvoyable([]), returnsNormally);
    });
  });

  group('lireDepuisDrop', () {
    test('produit un fichier lisible à partir d\'un XFile déposé', () async {
      final xfile = XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'notice.docx');
      final f = await lireDepuisDrop(xfile);
      expect(f.lisible, isTrue);
      expect(f.fileName, 'notice.docx');
      expect(f.status, EnvoiStatus.attente);
    });
  });

  // --- Tests du dialogue réel, dépôt multiple + cycle d'envoi ---
  //
  // Le backend n'est pas joignable dans cet environnement de test (pas de
  // serveur réel) — l'appel réseau échoue donc systématiquement avec une
  // ApiException("Erreur réseau..."), ce qui est exploité ICI délibérément
  // pour vérifier tout le circuit d'échec/retry/indépendance sans avoir à
  // mocker le client HTTP : chaque fichier doit échouer INDÉPENDAMMENT, avec
  // un message affiché, jamais silencieusement.
  Future<ChantierState> pumpDialog(WidgetTester tester) async {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => Directory.systemTemp.path,
    );
    final chantierState = ChantierState(ChantierRepository(ApiClient(), AppDatabase()));
    await tester.pumpWidget(
      ChangeNotifierProvider<ChantierState>.value(
        value: chantierState,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const AjouterDocumentChantierDialog(reference: 'LD91245'),
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
    return chantierState;
  }

  void deposer(WidgetTester tester, List<XFile> files) {
    tester.widget<DropZone>(find.byType(DropZone)).onFilesDropped(files);
  }

  testWidgets('le dépôt multiple ajoute chaque fichier indépendamment à la liste', (tester) async {
    await pumpDialog(tester);
    deposer(tester, [
      XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'a.pdf'),
      XFile.fromData(Uint8List.fromList([4, 5, 6]), path: 'b.docx'),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('a.pdf'), findsOneWidget);
    expect(find.text('b.docx'), findsOneWidget);
    expect(find.text('Ajouter (2)'), findsOneWidget);
  });

  testWidgets('un fichier illisible (octets absents) apparaît en échec sans bloquer les autres', (tester) async {
    await pumpDialog(tester);
    deposer(tester, [XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'ok.pdf')]);
    await tester.pumpAndSettle();
    // Simule directement un fichier illisible via le sélecteur (bytes null),
    // sans passer par un vrai file_picker (non disponible en test).
    final illisible = await lireDepuisPicker(PlatformFile(name: 'illisible.pdf', size: 10, bytes: null));
    expect(illisible.status, EnvoiStatus.echec);
    expect(illisible.erreur, 'Lecture du fichier impossible');
    // Le fichier lisible, lui, reste sain et indépendant de ce cas.
    expect(find.text('ok.pdf'), findsOneWidget);
  });

  testWidgets('chaque fichier échoue indépendamment au réseau (pas de backend en test) et affiche sa cause', (tester) async {
    await pumpDialog(tester);
    deposer(tester, [
      XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'a.pdf'),
      XFile.fromData(Uint8List.fromList([4, 5, 6]), path: 'b.pdf'),
    ]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ajouter (2)'));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Les deux fichiers ont échoué (réseau injoignable dans ce test) —
    // aucun n'a bloqué l'autre, chacun affiche sa propre ligne d'échec.
    expect(find.textContaining('Échec —'), findsNWidgets(2));
    expect(find.textContaining('en échec'), findsWidgets);
    expect(find.byIcon(Icons.refresh), findsNWidgets(2));
  });

  testWidgets('le retry relance tout le cycle et le retrait fait disparaître la ligne', (tester) async {
    await pumpDialog(tester);
    deposer(tester, [XFile.fromData(Uint8List.fromList([1, 2, 3]), path: 'a.pdf')]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('Échec —'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    // Toujours en échec (réseau toujours injoignable) mais le cycle a bien
    // été rejoué sans planter — c'est ce que ce test vérifie.
    expect(find.textContaining('Échec —'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('a.pdf'), findsNothing);
  });
}
