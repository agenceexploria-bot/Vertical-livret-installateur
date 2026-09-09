import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/router.dart';

void main() {
  group('loginRedirectWith / loginRedirectFrom (lien direct -> login -> retour)', () {
    test('mémorise la destination d\'origine dans /login?from=...', () {
      final redirect = loginRedirectWith(Uri.parse('/chantier/LD70850'));
      expect(redirect, '/login?from=%2Fchantier%2FLD70850');
    });

    test('round-trip complet : la destination lue après re-parsing correspond exactement à l\'originale', () {
      // Reproduit ce que GoRouter fait réellement : la chaîne renvoyée par
      // loginRedirectWith est re-parsée en Uri (state.uri) au prochain
      // passage dans redirect() — voir router.dart.
      final redirect = loginRedirectWith(Uri.parse('/chantier/LD70850'));
      final reparsed = Uri.parse(redirect);

      expect(loginRedirectFrom(reparsed), '/chantier/LD70850');
    });

    test('conserve les paramètres de route déjà substitués, même avec des caractères spéciaux', () {
      final redirect = loginRedirectWith(Uri.parse('/chantier/LD45Test tobi'));
      final reparsed = Uri.parse(redirect);

      // Uri normalise l'espace en %20 dès le premier parse (avant même
      // l'encodage du paramètre from) — représentation correcte et
      // fonctionnellement identique, GoRouter la recevrait de la même façon
      // en navigation réelle.
      expect(loginRedirectFrom(reparsed), '/chantier/LD45Test%20tobi');
    });

    test('renvoie null (comportement par défaut : home) quand /login n\'a pas de paramètre from', () {
      expect(loginRedirectFrom(Uri.parse('/login')), isNull);
    });

    test('renvoie null si le paramètre from est présent mais vide', () {
      expect(loginRedirectFrom(Uri.parse('/login?from=')), isNull);
    });
  });
}
