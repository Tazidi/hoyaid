import 'package:flutter_test/flutter_test.dart';
import 'package:hoyaid/core/theme/app_theme.dart';

void main() {
  test('tema memakai tipografi global yang terbaca', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      expect(theme.textTheme.bodyMedium?.fontFamily, 'Roboto');
      expect(theme.textTheme.bodyMedium?.height, 1.5);
      expect(theme.textTheme.titleLarge?.fontWeight?.value, 700);
    }
  });
}
