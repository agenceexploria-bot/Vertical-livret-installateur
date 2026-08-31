import 'dart:math';

/// Diacritiques latines usuelles ramenées à leur lettre ASCII de base — les
/// caractères non couverts (tirets cadratins, points médians...) sont de
/// toute façon absorbés par la substitution générique de
/// [sanitizeBlobFilename].
const _diacritics = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ç': 'c', 'ñ': 'n', 'œ': 'oe', 'æ': 'ae',
};

final _uniqueSuffixRandom = Random();

/// Borne passée à `Random.nextInt` pour le suffixe unique — DOIT rester un
/// littéral décimal, jamais `1 << 32`. En Dart web (dart2js/DDC), les
/// opérateurs bit à bit (`<<`, `>>`, `&`, `|`, `^`, `~`) sont tronqués à 32
/// bits ; `1 << 32` y vaut alors 0 (constaté en prod : `Random().nextInt(0)`
/// lève `RangeError`, jamais silencieux). Sur la VM (donc en `flutter
/// test`), `1 << 32` vaut bien 4294967296 — le bug était invisible en test
/// et n'apparaissait qu'en build web réel. `0xFFFFFFFF` (4294967295) est un
/// nombre entier, pas le résultat d'un décalage : sa valeur est identique
/// sur VM et web.
const blobSuffixRandomMax = 0xFFFFFFFF;

/// Transforme un nom de fichier utilisateur (accents, espaces, tirets
/// cadratins, points médians...) en un chemin sûr pour Vercel Blob :
/// uniquement lettres ASCII, chiffres et tirets, avec un suffixe unique pour
/// qu'un envoi de plusieurs fichiers ne désigne jamais deux fois le même
/// blob. Le nom d'origine, lui, continue d'être affiché tel quel dans
/// l'interface (voir `nomFichierOriginal`) — cette fonction ne sert qu'au
/// chemin de stockage.
String sanitizeBlobFilename(String original) {
  final dotIndex = original.lastIndexOf('.');
  final hasExtension = dotIndex > 0 && dotIndex < original.length - 1;
  final base = hasExtension ? original.substring(0, dotIndex) : original;
  final rawExtension = hasExtension ? original.substring(dotIndex + 1).toLowerCase() : '';
  final extension = RegExp(r'^[a-z0-9]{1,10}$').hasMatch(rawExtension) ? rawExtension : '';

  final withoutAccents = StringBuffer();
  for (final rune in base.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    withoutAccents.write(_diacritics[char] ?? char);
  }

  final slug = withoutAccents
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final safeBase = slug.isEmpty ? 'fichier' : slug;
  final suffix = '${DateTime.now().microsecondsSinceEpoch}-${_uniqueSuffixRandom.nextInt(blobSuffixRandomMax)}';

  return extension.isEmpty ? '$safeBase-$suffix' : '$safeBase-$suffix.$extension';
}
