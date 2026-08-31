/// Identifiant de build affiché dans l'UI (bas du back-office, profil
/// installateur) — le SHA est injecté au build via --dart-define (voir
/// `flutter build web --dart-define=APP_COMMIT_SHA=...` dans
/// .github/workflows/deploy.yml), jamais codé en dur : ça permet de
/// confirmer en un coup d'œil la version réellement chargée face à un
/// problème de cache PWA (voir README, section "Vérifications manuelles
/// terrain"). En dev local (`flutter run`, sans --dart-define), reste sur
/// la valeur par défaut 'dev'.
class BuildInfo {
  static const String commitSha = String.fromEnvironment('APP_COMMIT_SHA', defaultValue: 'dev');

  static String get shortCommitSha => commitSha.length >= 7 ? commitSha.substring(0, 7) : commitSha;

  // Gardé aligné à la main avec `version:` dans pubspec.yaml — un
  // package_info_plus dédié serait disproportionné pour ce seul usage
  // d'affichage, le SHA (lui automatique) est la partie qui compte
  // vraiment pour diagnostiquer un problème de cache.
  static const String version = '1.0.0';

  static String get label => 'v$version · $shortCommitSha';
}
