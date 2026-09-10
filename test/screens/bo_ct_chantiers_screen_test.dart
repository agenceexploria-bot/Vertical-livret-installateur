import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/data/models/chantier.dart';
import 'package:vertical_app/data/models/user.dart';
import 'package:vertical_app/screens/backoffice/bo_ct_chantiers_screen.dart';

Chantier _chantier(String reference, {bool pvSigne = false, List<User> installateursRattaches = const [], Set<String> livretsOuverts = const {}}) =>
    Chantier(
      reference: reference,
      client: 'Client $reference',
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
      referenceAffaire: 'AF-$reference',
      receptionMarchandises: const [],
      autoControle: const [],
      pvSigne: pvSigne,
      installateursRattaches: installateursRattaches,
      livretsOuverts: livretsOuverts,
    );

User _installateur(String id) => User(id: id, nom: 'Nom', prenom: 'Prenom', role: UserRole.installateur);

void main() {
  group('chantiersPourSegment (filtre "À traiter" — groupe exclusif)', () {
    // Rattaché mais livret jamais ouvert : "à traiter" (voir _aLivretNonOuvert).
    final aTraiter = _chantier('A-TRAITER', installateursRattaches: [_installateur('u1')], livretsOuverts: {});
    // Rattaché et livret ouvert : jamais "à traiter", quel que soit le segment.
    final pret = _chantier('PRET', installateursRattaches: [_installateur('u2')], livretsOuverts: {'u2'});
    final termine = _chantier('TERMINE', pvSigne: true);

    final tous = [aTraiter, pret, termine];
    final enCours = [aTraiter, pret];
    final termines = [termine];

    test('segment "À traiter" ne renvoie QUE les chantiers réellement à traiter, jamais "En cours" en entier', () {
      final result = chantiersPourSegment(TableauChantiersSegment.aTraiter, tous: tous, enCours: enCours, termines: termines);

      expect(result.map((c) => c.reference), ['A-TRAITER']);
      expect(result, isNot(contains(pret)), reason: 'PRET est "en cours" mais pas "à traiter" : ne doit jamais apparaître ici');
    });

    test('segment "En cours" renvoie la liste En cours complète, jamais réduite au sous-ensemble "à traiter"', () {
      final result = chantiersPourSegment(TableauChantiersSegment.enCours, tous: tous, enCours: enCours, termines: termines);

      // Avant la correction, un ancien filtre "à traiter" cumulé aurait pu
      // réduire cette liste à [aTraiter] seul — exactement le bug corrigé.
      expect(result, enCours);
      expect(result, contains(pret));
    });

    test('segment "Terminés" renvoie la liste Terminés, indépendamment de "à traiter"', () {
      final result = chantiersPourSegment(TableauChantiersSegment.termines, tous: tous, enCours: enCours, termines: termines);
      expect(result, termines);
    });

    test('segment "Tous" renvoie tous les chantiers, indépendamment de "à traiter"', () {
      final result = chantiersPourSegment(TableauChantiersSegment.tous, tous: tous, enCours: enCours, termines: termines);
      expect(result, tous);
    });
  });

  group('renduVuePour (bascule tuiles/liste)', () {
    const breakpoint = 700.0;

    test('en dessous du seuil : toujours des cartes empilées, quel que soit le choix de vue', () {
      expect(renduVuePour(largeurDisponible: 500, vueListe: false, breakpoint: breakpoint), ChantiersRenduVue.cartesEmpilees);
      expect(renduVuePour(largeurDisponible: 500, vueListe: true, breakpoint: breakpoint), ChantiersRenduVue.cartesEmpilees);
    });

    test('au-dessus du seuil : respecte le choix de vue (tuiles ou liste)', () {
      expect(renduVuePour(largeurDisponible: 1200, vueListe: false, breakpoint: breakpoint), ChantiersRenduVue.tuiles);
      expect(renduVuePour(largeurDisponible: 1200, vueListe: true, breakpoint: breakpoint), ChantiersRenduVue.liste);
    });
  });
}
