import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/screens/backoffice/chantier_route.dart';

void main() {
  group('Cloisonnement de l\'espace SAV — routage dérivé du type, jamais du point d\'entrée', () {
    test('chantierListeRoute : SAV renvoie vers la liste SAV, installation vers la liste Chantiers', () {
      expect(chantierListeRoute(ChantierType.sav), '/backoffice/ct/sav');
      expect(chantierListeRoute(ChantierType.installation), '/backoffice/ct');
    });

    test('chantierActiveNav : l\'onglet actif reflète le type réel, jamais "chantiers" par défaut pour un SAV', () {
      expect(chantierActiveNav(ChantierType.sav), 'sav');
      expect(chantierActiveNav(ChantierType.installation), 'chantiers');
    });

    test('chantierDetailRoute : la route de fiche distingue SAV et Chantiers pour la même référence', () {
      expect(chantierDetailRoute(ChantierType.sav, 'SAV-LD70850-1'), '/backoffice/ct/sav/SAV-LD70850-1');
      expect(chantierDetailRoute(ChantierType.installation, 'LD70850'), '/backoffice/ct/chantiers/LD70850');
    });
  });
}
