import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/activity_feed.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/screens/backoffice/bo_admin_dashboard_screen.dart';

RexEnAttente _rex(String reference, ChantierType type) => RexEnAttente(chantierReference: reference, client: 'Client $reference', chantierType: type);

void main() {
  group('rexEnAttentePourType (séparation stricte REX chantiers / REX SAV)', () {
    test('un flux mélangé se sépare sans fuite d\'un type vers l\'autre', () {
      final all = [
        _rex('LD1', ChantierType.installation),
        _rex('SAV-LD1-1', ChantierType.sav),
        _rex('LD2', ChantierType.installation),
        _rex('SAV-LD2-1', ChantierType.sav),
      ];

      final chantiers = rexEnAttentePourType(all, ChantierType.installation);
      final sav = rexEnAttentePourType(all, ChantierType.sav);

      expect(chantiers.map((r) => r.chantierReference), ['LD1', 'LD2']);
      expect(sav.map((r) => r.chantierReference), ['SAV-LD1-1', 'SAV-LD2-1']);
      // Aucune entrée SAV du côté chantiers, et réciproquement — jamais mélangés.
      expect(chantiers.every((r) => r.chantierType == ChantierType.installation), isTrue);
      expect(sav.every((r) => r.chantierType == ChantierType.sav), isTrue);
      expect(chantiers.length + sav.length, all.length);
    });

    test('liste vide : les deux filtres renvoient une liste vide, sans planter', () {
      expect(rexEnAttentePourType(const [], ChantierType.installation), isEmpty);
      expect(rexEnAttentePourType(const [], ChantierType.sav), isEmpty);
    });
  });
}
