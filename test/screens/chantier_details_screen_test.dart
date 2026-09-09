import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/screens/installateur/chantier_details_screen.dart';

/// Module SAV — la fiche chantier masque réception marchandises,
/// auto-contrôle et documents terrain pour une intervention SAV (aucun
/// point de contrôle créé côté backend, voir POST .../sav). Pure, sans
/// BuildContext ni ChantierState — voir [visibleModules].
void main() {
  group('visibleModules', () {
    test('un chantier d\'installation affiche tous les modules, dans l\'ordre', () {
      expect(visibleModules(ChantierType.installation), [
        ChantierModule.fiche,
        ChantierModule.docsAdmin,
        ChantierModule.tech,
        ChantierModule.reception,
        ChantierModule.autoControle,
        ChantierModule.pv,
        ChantierModule.rex,
        ChantierModule.terrain,
      ]);
    });

    test('une intervention SAV masque réception marchandises, auto-contrôle et documents terrain', () {
      final modules = visibleModules(ChantierType.sav);

      expect(modules, [
        ChantierModule.fiche,
        ChantierModule.docsAdmin,
        ChantierModule.tech,
        ChantierModule.pv,
        ChantierModule.rex,
      ]);
      expect(modules, isNot(contains(ChantierModule.reception)));
      expect(modules, isNot(contains(ChantierModule.autoControle)));
      expect(modules, isNot(contains(ChantierModule.terrain)));
    });

    test('les deux types conservent fiche/documents administratifs/dossier technique/PV/REX', () {
      for (final type in ChantierType.values) {
        final modules = visibleModules(type);
        expect(modules, containsAll([
          ChantierModule.fiche,
          ChantierModule.docsAdmin,
          ChantierModule.tech,
          ChantierModule.pv,
          ChantierModule.rex,
        ]));
      }
    });
  });
}
