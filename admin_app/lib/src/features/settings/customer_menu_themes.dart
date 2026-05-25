import 'package:flutter/material.dart';

/// The single source of truth for the customer-menu themes the admin
/// can pick in Settings. Slugs MUST match `ALLOWED_MENU_THEMES` in
/// backend/routers/menu.py and the keys exported from
/// customer_menu/frontend/src/themes/index.js.
class CustomerMenuThemeSpec {
  const CustomerMenuThemeSpec({
    required this.slug,
    required this.nameEn,
    required this.nameBn,
    required this.taglineEn,
    required this.taglineBn,
    required this.palette,
    required this.sampleHeading,
    required this.headingFontFamilyHint,
    required this.headingIsItalic,
  });

  final String slug;
  final String nameEn;
  final String nameBn;
  final String taglineEn;
  final String taglineBn;
  final List<Color> palette;
  final String sampleHeading;
  final String? headingFontFamilyHint;
  final bool headingIsItalic;

  String displayName({required bool isBn}) => isBn ? nameBn : nameEn;
  String tagline({required bool isBn}) => isBn ? taglineBn : taglineEn;
  Color get primary => palette.isEmpty ? Colors.black : palette.first;
}

const String defaultCustomerMenuTheme = 'sultans_hearth';

const List<CustomerMenuThemeSpec> customerMenuThemes = <CustomerMenuThemeSpec>[
  CustomerMenuThemeSpec(
    slug: 'sultans_hearth',
    nameEn: 'Hearth',
    nameBn: 'হার্থ',
    taglineEn: 'Kebab · ember & gold',
    taglineBn: 'কাবাব · আগুন ও সোনা',
    palette: [
      Color(0xFF5C1A1B),
      Color(0xFF1A1410),
      Color(0xFFC9A24B),
      Color(0xFFE26B2C),
      Color(0xFFF0E5D0),
    ],
    sampleHeading: 'KEBAB',
    headingFontFamilyHint: 'serif',
    headingIsItalic: false,
  ),
  CustomerMenuThemeSpec(
    slug: 'brick',
    nameEn: 'Brick',
    nameBn: 'ব্রিক',
    taglineEn: 'Café · pizza & youth energy',
    taglineBn: 'ক্যাফে · পিৎজা ও তরুণ আড্ডা',
    palette: [
      Color(0xFFC9583A),
      Color(0xFFF4EBDC),
      Color(0xFFE89A4A),
      Color(0xFF2A2420),
      Color(0xFF4A6B3A),
    ],
    sampleHeading: 'PIZZA',
    headingFontFamilyHint: null,
    headingIsItalic: false,
  ),
  CustomerMenuThemeSpec(
    slug: 'lantern',
    nameEn: 'Lantern',
    nameBn: 'ল্যান্টার্ন',
    taglineEn: 'Desi-Chinese · moody bistro',
    taglineBn: 'দেশি-চাইনিজ · মুডি বিস্ত্রো',
    palette: [
      Color(0xFFE8744A),
      Color(0xFF14181A),
      Color(0xFF5FB8C4),
      Color(0xFF2F5D4F),
      Color(0xFFEDE8DD),
    ],
    sampleHeading: 'Noodles',
    headingFontFamilyHint: 'serif',
    headingIsItalic: true,
  ),
  CustomerMenuThemeSpec(
    slug: 'marble',
    nameEn: 'Marble',
    nameBn: 'মার্বেল',
    taglineEn: 'Bakery · premium café',
    taglineBn: 'বেকারি · প্রিমিয়াম ক্যাফে',
    palette: [
      Color(0xFF3B2A1F),
      Color(0xFFFBF8F2),
      Color(0xFFB89556),
      Color(0xFF9DAE94),
      Color(0xFFE8C8B8),
    ],
    sampleHeading: 'Patisserie',
    headingFontFamilyHint: 'serif',
    headingIsItalic: true,
  ),
];

CustomerMenuThemeSpec resolveCustomerMenuTheme(String? slug) {
  for (final theme in customerMenuThemes) {
    if (theme.slug == slug) return theme;
  }
  return customerMenuThemes.first;
}
