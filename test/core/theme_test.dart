import 'package:flutter_test/flutter_test.dart';
import 'package:vertical_app/core/theme.dart';
import 'package:vertical_app/core/widgets/vertical_pattern_background.dart';

void main() {
  testWidgets('champs de saisie opaques — fond rempli, distinct du filigrane (aucune transparence)', (tester) async {
    final inputTheme = AppTheme.lightTheme.inputDecorationTheme;
    expect(inputTheme.filled, isTrue);
    expect(inputTheme.fillColor, AppColors.blanc);
    expect(
      inputTheme.fillColor,
      isNot(verticalPatternBackgroundColor),
      reason: 'le fond des champs doit être visuellement distinct du fond du filigrane',
    );
  });
}

