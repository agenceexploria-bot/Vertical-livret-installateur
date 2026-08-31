import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/build_info.dart';

void main() {
  group('BuildInfo', () {
    test('shortCommitSha ne dépasse jamais 7 caractères', () {
      expect(BuildInfo.shortCommitSha.length, lessThanOrEqualTo(7));
    });

    test('label combine la version et le SHA court', () {
      expect(BuildInfo.label, 'v${BuildInfo.version} · ${BuildInfo.shortCommitSha}');
    });

    test('sans --dart-define (flutter test), retombe sur "dev"', () {
      // Confirme le comportement par défaut en environnement de test/dev
      // local, où --dart-define=APP_COMMIT_SHA n'est jamais fourni.
      expect(BuildInfo.commitSha, 'dev');
    });
  });
}
