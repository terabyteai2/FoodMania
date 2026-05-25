import 'package:flutter_test/flutter_test.dart';

import 'package:local_pos/src/features/settings/customer_menu_themes.dart';

// Must stay in lockstep with ALLOWED_MENU_THEMES in backend/routers/menu.py
// and the keys in customer_menu/frontend/src/themes/index.js.
const _expectedSlugs = <String>{
  'napoli_trattoria',
  'tuscan_herb',
  'amalfi_breeze',
  'milano_roast',
  'sultans_hearth',
  'charcoal_lodge',
  'bengal_bistro',
  'grand_mughal',
};

void main() {
  test('exposes exactly the eight expected themes with unique slugs', () {
    expect(customerMenuThemes, hasLength(8));
    final slugs = customerMenuThemes.map((t) => t.slug).toSet();
    expect(slugs, hasLength(8));
    expect(slugs, equals(_expectedSlugs));
  });

  test('each theme exposes a 5-colour palette', () {
    for (final theme in customerMenuThemes) {
      expect(theme.palette, hasLength(5),
          reason: '${theme.slug} should expose 5 swatches');
    }
  });

  test('default slug matches the registry default', () {
    expect(defaultCustomerMenuTheme, 'napoli_trattoria');
    expect(customerMenuThemes.first.slug, defaultCustomerMenuTheme);
  });

  test('resolver falls back to default on unknown slug', () {
    expect(resolveCustomerMenuTheme(null).slug, defaultCustomerMenuTheme);
    expect(resolveCustomerMenuTheme('not_a_theme').slug,
        defaultCustomerMenuTheme);
    expect(resolveCustomerMenuTheme('tuscan_herb').slug, 'tuscan_herb');
  });
}
