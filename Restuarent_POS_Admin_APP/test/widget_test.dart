import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';

void main() {
  test('app theme exposes the Local POS color system', () {
    final theme = AppTheme.light();

    expect(theme.colorScheme.primary.toARGB32(), PosColors.primary.toARGB32());
    expect(theme.colorScheme.secondary.toARGB32(), PosColors.accent.toARGB32());
    expect(theme.useMaterial3, isTrue);
  });
}
