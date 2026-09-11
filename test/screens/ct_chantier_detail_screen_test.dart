import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/screens/coordinateur_travaux/ct_chantier_detail_screen.dart';

Chantier _chantier({bool pvSigne = false, String? pvSignatureImagePath}) => Chantier(
      reference: 'LD00001',
      client: 'Client',
      adresse: '1 rue Test',
      ville: 'Testville',
      dateDebut: DateTime(2026, 1, 1),
      dateFin: DateTime(2026, 1, 3),
      contactNom: 'M. Test',
      contactTel: '0600000000',
      horaires: '8h-17h',
      consignes: const [],
      typeMonteCharge: 'Monte-charge',
      capacite: '300 kg',
      niveaux: 2,
      referenceAffaire: 'AF-LD00001',
      receptionMarchandises: const [],
      autoControle: const [],
      pvSigne: pvSigne,
      pvSignatureImagePath: pvSignatureImagePath,
    );

void main() {
  // Bug signalé : "impossible de télécharger le PV" — la fiche mobile CT
  // n'a jamais eu de bouton de téléchargement du PV signé (voir
  // ct_chantier_detail_screen.dart, _pvDownloadButton). pvSignatureDownloadUrl
  // en est la logique pure, testée ici sans monter tout l'écran
  // (Provider/GoRouter, coûteux à mettre en place — voir bo_ct_chantiers_screen_test.dart
  // pour le même choix sur l'écran liste).
  group('pvSignatureDownloadUrl', () {
    test('renvoie l\'URL quand le PV est signé et le fichier est un PDF', () {
      final chantier = _chantier(pvSigne: true, pvSignatureImagePath: 'https://blob.vercel-storage.com/pv-signe-abc.pdf');
      expect(pvSignatureDownloadUrl(chantier), 'https://blob.vercel-storage.com/pv-signe-abc.pdf');
    });

    test('renvoie null si le PV n\'est pas signé', () {
      final chantier = _chantier(pvSigne: false, pvSignatureImagePath: 'https://blob.vercel-storage.com/pv-signe-abc.pdf');
      expect(pvSignatureDownloadUrl(chantier), isNull);
    });

    test('renvoie null si aucun fichier de signature n\'est enregistré', () {
      final chantier = _chantier(pvSigne: true, pvSignatureImagePath: null);
      expect(pvSignatureDownloadUrl(chantier), isNull);
    });

    test('renvoie null si le fichier n\'est pas un PDF (signature au doigt seul, ancien flux)', () {
      final chantier = _chantier(pvSigne: true, pvSignatureImagePath: 'https://blob.vercel-storage.com/signature-abc.png');
      expect(pvSignatureDownloadUrl(chantier), isNull);
    });

    test('insensible à la casse de l\'extension', () {
      final chantier = _chantier(pvSigne: true, pvSignatureImagePath: 'https://blob.vercel-storage.com/pv-signe-abc.PDF');
      expect(pvSignatureDownloadUrl(chantier), isNotNull);
    });
  });
}
