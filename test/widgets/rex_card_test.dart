import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/screens/backoffice/widgets/rex_audio_controller.dart';
import 'package:vertical_app/screens/backoffice/widgets/rex_audio_player.dart';
import 'package:vertical_app/screens/backoffice/widgets/rex_card.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Rex rex, {
    VoidCallback? onTelechargerAudio,
    VoidCallback? onSupprimer,
    Future<void> Function()? onTranscrire,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RexCard(
            rex: rex,
            audioController: RexAudioController(),
            onTelechargerAudio: onTelechargerAudio,
            onSupprimer: onSupprimer,
            onTranscrire: onTranscrire,
          ),
        ),
      ),
    );
  }

  testWidgets('REX avec audio : le lecteur et le bouton de téléchargement sont affichés', (tester) async {
    final rex = Rex(
      id: 'r1',
      transcription: 'Tout s\'est bien passé',
      audioPath: 'https://blob.vercel-storage.com/rex-audio.webm',
      soumisAt: DateTime(2026, 9, 1, 10, 30),
      auteur: 'Marin Dupont',
    );

    await pump(tester, rex, onTelechargerAudio: () {});

    expect(find.byType(RexAudioPlayer), findsOneWidget);
    expect(find.byTooltip('Télécharger l\'audio'), findsOneWidget);
    expect(find.textContaining('Marin Dupont'), findsOneWidget);
  });

  testWidgets('REX sans auteur connu (créé avant l\'ajout du champ) : repli "Auteur inconnu"', (tester) async {
    final rex = Rex(id: 'r5', transcription: 'Texte', audioPath: null, soumisAt: DateTime(2026, 9, 1), auteur: null);

    await pump(tester, rex);

    expect(find.textContaining('Auteur inconnu'), findsOneWidget);
  });

  testWidgets('REX texte seul (sans audio) : pas de lecteur ni de bouton de téléchargement', (tester) async {
    final rex = Rex(id: 'r2', transcription: 'RAS sur ce chantier', audioPath: null, soumisAt: DateTime(2026, 9, 1, 10, 30));

    await pump(tester, rex);

    expect(find.byType(RexAudioPlayer), findsNothing);
    expect(find.byTooltip('Télécharger l\'audio'), findsNothing);
  });

  testWidgets('bouton supprimer visible seulement si onSupprimer est fourni', (tester) async {
    final rex = Rex(id: 'r4', transcription: 'Texte', audioPath: null, soumisAt: DateTime(2026, 9, 1));

    await pump(tester, rex);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await pump(tester, rex, onSupprimer: () {});
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  group('transcription repliée par défaut', () {
    testWidgets('la transcription n\'est pas affichée tant qu\'on n\'a pas cliqué sur "Afficher la transcription"', (tester) async {
      final rex = Rex(id: 'r20', transcription: 'Une transcription à dérouler', audioPath: null, soumisAt: DateTime(2026, 9, 1));

      await pump(tester, rex);

      expect(find.byType(SelectableText), findsNothing);
      expect(find.text('Une transcription à dérouler'), findsNothing);
      expect(find.byTooltip('Afficher la transcription'), findsOneWidget);
    });

    testWidgets('toggle : un clic déroule (texte sélectionnable visible), un second replie', (tester) async {
      final rex = Rex(id: 'r21', transcription: 'Une transcription à dérouler', audioPath: null, soumisAt: DateTime(2026, 9, 1));

      await pump(tester, rex);

      await tester.tap(find.byTooltip('Afficher la transcription'));
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsOneWidget);
      final selectable = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(selectable.data, 'Une transcription à dérouler');
      expect(find.byTooltip('Masquer la transcription'), findsOneWidget);

      await tester.tap(find.byTooltip('Masquer la transcription'));
      await tester.pumpAndSettle();

      expect(find.byType(SelectableText), findsNothing);
      expect(find.byTooltip('Afficher la transcription'), findsOneWidget);
    });

    testWidgets('sans transcription : le bouton est grisé (désactivé), tooltip "Aucune transcription"', (tester) async {
      final rex = Rex(
        id: 'r22',
        transcription: null,
        audioPath: 'https://blob.vercel-storage.com/rex-audio.webm',
        soumisAt: DateTime(2026, 9, 1),
      );

      await pump(tester, rex);

      expect(find.byTooltip('Aucune transcription'), findsOneWidget);
      final button = tester.widget<IconButton>(find.ancestor(of: find.byTooltip('Aucune transcription'), matching: find.byType(IconButton)));
      expect(button.onPressed, isNull);

      // Un tap sur un IconButton désactivé ne fait rien — la transcription
      // reste introuvable dans l'arbre.
      await tester.tap(find.byTooltip('Aucune transcription'));
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsNothing);
    });
  });

  group('bouton copier', () {
    testWidgets('visible seulement si la transcription est non vide, copie dans le presse-papier', (tester) async {
      final rex = Rex(id: 'r6', transcription: 'Une transcription à copier', audioPath: null, soumisAt: DateTime(2026, 9, 1));

      final copies = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copies.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      await pump(tester, rex);
      expect(find.byTooltip('Copier la transcription'), findsOneWidget);

      await tester.tap(find.byTooltip('Copier la transcription'));
      await tester.pumpAndSettle();

      expect(copies, ['Une transcription à copier']);
      expect(find.text('Transcription copiée'), findsOneWidget);
    });

    testWidgets('absent si le REX n\'a pas de transcription', (tester) async {
      final rex = Rex(
        id: 'r7',
        transcription: null,
        audioPath: 'https://blob.vercel-storage.com/rex-audio.webm',
        soumisAt: DateTime(2026, 9, 1),
      );

      await pump(tester, rex);
      expect(find.byTooltip('Copier la transcription'), findsNothing);
    });
  });

  group('bouton transcrire', () {
    testWidgets('visible si le REX a un audio, avec spinner pendant le traitement', (tester) async {
      final rex = Rex(
        id: 'r8',
        transcription: null,
        audioPath: 'https://blob.vercel-storage.com/rex-audio.webm',
        soumisAt: DateTime(2026, 9, 1),
      );

      final completer = Completer<void>();

      await pump(tester, rex, onTranscrire: () => completer.future);
      expect(find.byTooltip('Transcrire'), findsOneWidget);

      await tester.tap(find.byTooltip('Transcrire'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Transcrire'), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('reste visible sur un REX déjà transcrit — tooltip "Relancer la transcription" (écrase l\'existante)', (tester) async {
      final rex = Rex(
        id: 'r9',
        transcription: 'Déjà transcrit',
        audioPath: 'https://blob.vercel-storage.com/rex-audio.webm',
        soumisAt: DateTime(2026, 9, 1),
      );

      await pump(tester, rex, onTranscrire: () async {});
      expect(find.byTooltip('Relancer la transcription'), findsOneWidget);
      expect(find.byTooltip('Transcrire'), findsNothing);
    });

    testWidgets('absent si le REX n\'a pas d\'audio', (tester) async {
      final rex = Rex(id: 'r10', transcription: 'Texte', audioPath: null, soumisAt: DateTime(2026, 9, 1));

      await pump(tester, rex, onTranscrire: () async {});
      expect(find.byTooltip('Transcrire'), findsNothing);
      expect(find.byTooltip('Relancer la transcription'), findsNothing);
    });

    testWidgets('absent si aucun callback onTranscrire n\'est fourni', (tester) async {
      final rex = Rex(
        id: 'r11',
        transcription: null,
        audioPath: 'https://blob.vercel-storage.com/rex-audio.webm',
        soumisAt: DateTime(2026, 9, 1),
      );

      await pump(tester, rex);
      expect(find.byTooltip('Transcrire'), findsNothing);
    });
  });

  testWidgets('la carte reste plafonnée à 600px de large sur un écran très large', (tester) async {
    tester.view.physicalSize = const Size(2000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final rex = Rex(id: 'r12', transcription: 'Texte', audioPath: null, soumisAt: DateTime(2026, 9, 1));
    await pump(tester, rex);

    final size = tester.getSize(find.byType(RexCard));
    expect(size.width, lessThanOrEqualTo(600));
  });
}
