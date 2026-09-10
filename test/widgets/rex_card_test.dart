import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/screens/backoffice/widgets/rex_audio_player.dart';
import 'package:vertical_app/screens/backoffice/widgets/rex_card.dart';

void main() {
  Future<void> pump(WidgetTester tester, Rex rex, {VoidCallback? onTelechargerAudio, VoidCallback? onSupprimer}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RexCard(rex: rex, onTelechargerAudio: onTelechargerAudio, onSupprimer: onSupprimer),
        ),
      ),
    );
  }

  testWidgets('REX avec audio : le lecteur et le bouton de téléchargement sont affichés', (tester) async {
    final rex = Rex(id: 'r1', transcription: 'Tout s\'est bien passé', audioPath: 'https://blob.vercel-storage.com/rex-audio.webm', soumisAt: DateTime(2026, 9, 1, 10, 30));

    await pump(tester, rex, onTelechargerAudio: () {});

    expect(find.byType(RexAudioPlayer), findsOneWidget);
    expect(find.text('Télécharger l\'audio'), findsOneWidget);
    expect(find.text('Tout s\'est bien passé'), findsOneWidget);
  });

  testWidgets('REX texte seul (sans audio) : ni lecteur ni bouton de téléchargement', (tester) async {
    final rex = Rex(id: 'r2', transcription: 'RAS sur ce chantier', audioPath: null, soumisAt: DateTime(2026, 9, 1, 10, 30));

    await pump(tester, rex);

    expect(find.byType(RexAudioPlayer), findsNothing);
    expect(find.text('Télécharger l\'audio'), findsNothing);
    expect(find.text('RAS sur ce chantier'), findsOneWidget);
  });

  testWidgets('REX vocal sans transcription : message de repli, pas de lecteur vide en son absence', (tester) async {
    final rex = Rex(id: 'r3', transcription: null, audioPath: null, soumisAt: DateTime(2026, 9, 1, 10, 30));

    await pump(tester, rex);

    expect(find.text('(note vocale sans transcription)'), findsOneWidget);
    expect(find.byType(RexAudioPlayer), findsNothing);
  });

  testWidgets('bouton supprimer visible seulement si onSupprimer est fourni', (tester) async {
    final rex = Rex(id: 'r4', transcription: 'Texte', audioPath: null, soumisAt: DateTime(2026, 9, 1));

    await pump(tester, rex);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await pump(tester, rex, onSupprimer: () {});
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });
}
