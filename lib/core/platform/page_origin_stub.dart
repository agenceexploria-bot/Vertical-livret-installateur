/// Implémentation par défaut (mobile natif) — pas de notion d'origine de
/// page en dehors du Web ; ApiClient.baseUrl est déjà une URL absolue sur
/// mobile (voir ApiClient._uploadsCallbackUrl), cette valeur n'y est donc
/// jamais utilisée.
String? get currentPageOrigin => null;
