/// Champs extraits d'un bloc de texte collé depuis l'ERP lors de la création
/// d'un chantier — voir [CollageParser.parse].
class ParsedCollage {
  final String? client;
  final String? adresse;
  final String? ville;
  final String? contact;
  final String? telephone;
  final String? email;

  const ParsedCollage({this.client, this.adresse, this.ville, this.contact, this.telephone, this.email});
}

/// Extrait client, adresse, ville, contact, téléphone et email d'un bloc de
/// texte collé depuis l'ERP — une regex indépendante par champ plutôt qu'un
/// découpage positionnel par séparateur, pour ne pas dépendre du format exact
/// (ponctuation, ordre) utilisé par l'ERP source.
class CollageParser {
  static final _emailRegex = RegExp(r'[\w.+-]+@[\w-]+\.[A-Za-z]{2,}');
  static final _telephoneRegex = RegExp(r'(?:\+33[\s.-]?|0)[1-9](?:[\s.-]?\d{2}){4}');

  // Ville : deux motifs par ordre de priorité — un code postal (5 chiffres)
  // suivi du nom (motif principal, le plus fiable), puis à défaut le mot-clé
  // "Ville" suivi du nom (motif secondaire, pour les cas sans code postal).
  // Le nom capturé peut compter plusieurs mots (espaces) et contenir
  // tiret/apostrophe ; les suffixes parasites ("Cedex", "Cedex 2", "France")
  // sont retirés ensuite par [_stripVilleSuffixes].
  static final _villePostalRegex = RegExp(
    r"\d{5}\s+([A-Za-zÀ-ÖØ-öø-ÿ][\wÀ-ÖØ-öø-ÿ'-]*(?:[ \t]+[A-Za-zÀ-ÖØ-öø-ÿ][\wÀ-ÖØ-öø-ÿ'-]*)*)",
  );
  static final _villeLabelRegex = RegExp(
    r"\bville\s*:?\s*([A-Za-zÀ-ÖØ-öø-ÿ][\wÀ-ÖØ-öø-ÿ'-]*(?:[ \t]+[A-Za-zÀ-ÖØ-öø-ÿ][\wÀ-ÖØ-öø-ÿ'-]*)*)",
    caseSensitive: false,
  );
  static final _villeSuffixRegex = RegExp(r'\s+(cedex\s*\d*|france)$', caseSensitive: false);

  static final _contactLabelRegex = RegExp(r'(?:contact|resp\.?(?:\s*site)?)\s*:?\s*', caseSensitive: false);
  static final _civiliteRegex = RegExp(r"(?:M\.|Mme|Mlle)\s+[A-ZÀ-Ö][\wÀ-ÖØ-öø-ÿ'-]*");
  static final _clientLabelRegex = RegExp(r'client\s*:?\s*', caseSensitive: false);
  static final _separatorSplitRegex = RegExp(r'[\n,;]|[\s]?[-–—][\s]?');
  static final _edgeSeparatorsRegex = RegExp(r'^[\s,;\-–—:]+|[\s,;\-–—:]+$');

  static ParsedCollage parse(String rawText) {
    final text = rawText.replaceAll('«', '').replaceAll('»', '').trim();
    if (text.isEmpty) return const ParsedCollage();

    final email = _emailRegex.firstMatch(text)?.group(0);
    final telephone = _telephoneRegex.firstMatch(text)?.group(0)?.trim();
    final villeMatch = _extractVille(text);
    final client = _extractClient(text);
    final contact = _extractContact(text, telephone: telephone);
    final adresse = _extractAdresse(text, client: client, villeStart: villeMatch?.start);

    return ParsedCollage(
      client: client,
      adresse: adresse,
      ville: villeMatch?.ville,
      contact: contact,
      telephone: telephone,
      email: email,
    );
  }

  /// Renvoie la ville nettoyée (sans code postal ni suffixe parasite) ainsi
  /// que la position où commence le motif complet dans [text] — cette
  /// position sert de borne à [_extractAdresse], qui a besoin de savoir où
  /// s'arrête l'adresse dans le texte source, pas seulement le nom de ville.
  static ({int start, String ville})? _extractVille(String text) {
    final postal = _villePostalRegex.firstMatch(text);
    if (postal != null) {
      final ville = _stripVilleSuffixes(postal.group(1)!);
      if (ville.isNotEmpty) return (start: postal.start, ville: ville);
    }
    final label = _villeLabelRegex.firstMatch(text);
    if (label != null) {
      final ville = _stripVilleSuffixes(label.group(1)!);
      if (ville.isNotEmpty) return (start: label.start, ville: ville);
    }
    return null;
  }

  static String _stripVilleSuffixes(String raw) {
    var result = raw;
    Match? match;
    while ((match = _villeSuffixRegex.firstMatch(result)) != null) {
      result = result.substring(0, match!.start);
    }
    return result.trim();
  }

  /// Société/client — après "Client :" si présent, sinon la première ligne
  /// (jusqu'au premier séparateur).
  static String? _extractClient(String text) {
    final labelMatch = _clientLabelRegex.firstMatch(text);
    final source = labelMatch != null ? text.substring(labelMatch.end) : text;
    final firstSegment = source.split(_separatorSplitRegex).first.trim();
    return firstSegment.isEmpty ? null : firstSegment;
  }

  /// Nom du contact — après un mot-clé ("Contact :", "Resp. site :"...) si
  /// présent, sinon une civilité isolée ("M.", "Mme", "Mlle") suivie d'un nom.
  /// Le résultat s'arrête au numéro de téléphone repéré séparément, s'il y en a un.
  static String? _extractContact(String text, {String? telephone}) {
    String segment;
    final labelMatch = _contactLabelRegex.firstMatch(text);
    if (labelMatch != null) {
      segment = text.substring(labelMatch.end);
    } else {
      final civiliteMatch = _civiliteRegex.firstMatch(text);
      if (civiliteMatch == null) return null;
      segment = text.substring(civiliteMatch.start);
    }
    if (telephone != null) {
      final telIndex = segment.indexOf(telephone);
      if (telIndex != -1) segment = segment.substring(0, telIndex);
    }
    final firstLine = segment.split(RegExp(r'[\n]|[\s]?[-–—][\s]?')).first;
    return firstLine.trim().isEmpty ? null : firstLine.trim();
  }

  /// Adresse — ce qui reste entre la fin du nom client et le début du motif
  /// de ville repéré ([villeStart]), une fois les séparateurs de bordure
  /// retirés. Approche "par soustraction" plutôt que positionnelle : peu
  /// importe le séparateur utilisé entre les segments.
  static String? _extractAdresse(String text, {String? client, int? villeStart}) {
    var start = 0;
    if (client != null) {
      final clientIndex = text.indexOf(client);
      if (clientIndex != -1) start = clientIndex + client.length;
    }
    var end = text.length;
    if (villeStart != null && villeStart >= start) end = villeStart;
    if (start >= end) return null;
    final segment = text.substring(start, end).replaceAll(_edgeSeparatorsRegex, '');
    return segment.isEmpty ? null : segment;
  }
}
