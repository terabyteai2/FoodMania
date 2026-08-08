import 'package:flutter_test/flutter_test.dart';

import 'package:local_pos/src/features/settings/customer_menu_themes.dart';

// Must stay in lockstep with ALLOWED_MENU_THEMES in backend/routers/menu.py
// and the keys in customer_menu/frontend/src/themes/index.js.
const _expectedSlugs = <String>{'sultans_hearth', 'brick', 'lantern', 'marble'};

void main() {
  test('exposes exactly the four expected themes with unique slugs', () {
    expect(customerMenuThemes, hasLength(4));
    final slugs = customerMenuThemes.map((t) => t.slug).toSet();
    expect(slugs, hasLength(4));
    expect(slugs, equals(_expectedSlugs));
  });

  test('each theme exposes a 5-colour palette', () {
    for (final theme in customerMenuThemes) {
      expect(
        theme.palette,
        hasLength(5),
        reason: '${theme.slug} should expose 5 swatches',
      );
    }
  });

  test('default slug matches the registry default', () {
    expect(defaultCustomerMenuTheme, 'sultans_hearth');
    expect(customerMenuThemes.first.slug, defaultCustomerMenuTheme);
  });

  test('resolver falls back to default on unknown slug', () {
    expect(resolveCustomerMenuTheme(null).slug, defaultCustomerMenuTheme);
    expect(
      resolveCustomerMenuTheme('not_a_theme').slug,
      defaultCustomerMenuTheme,
    );
    expect(resolveCustomerMenuTheme('brick').slug, 'brick');
  });
}
