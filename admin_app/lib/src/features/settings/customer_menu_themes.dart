import 'package:flutter/material.dart';

/// The single source of truth for the 8 customer-menu themes the admin
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

const String defaultCustomerMenuTheme = 'napoli_trattoria';

const List<CustomerMenuThemeSpec> customerMenuThemes = <CustomerMenuThemeSpec>[
  CustomerMenuThemeSpec(
    slug: 'napoli_trattoria',
    nameEn: 'Napoli Trattoria',
    nameBn: 'নাপোলি ত্রাত্তোরিয়া',
    taglineEn: 'Wood-fired pizza · rustic warm',
    taglineBn: 'কাঠের চুলায় পিৎজা · উষ্ণ',
    palette: [
      Color(0xFFC8392E),
      Color(0xFF1A1614),
      Color(0xFF4A6B3A),
      Color(0xFFF2E8D5),
      Color(0xFFFFB547),
    ],
    sampleHeading: 'LA PIZZA',
    headingFontFamilyHint: null,
    headingIsItalic: false,
  ),
  CustomerMenuThemeSpec(
    slug: 'tuscan_herb',
    nameEn: 'Tuscan Herb',
    nameBn: 'টাস্কান হার্ব',
    taglineEn: "Pasta · nonna's kitchen",
    taglineBn: 'পাস্তা · দাদীর রান্নাঘর',
    palette: [
      Color(0xFF8FA382),
      Color(0xFFC97A5A),
      Color(0xFF2C2A1F),
      Color(0xFFF4ECDC),
      Color(0xFF5A1F26),
    ],
    sampleHeading: 'La Pasta',
    headingFontFamilyHint: 'serif',
    headingIsItalic: true,
  ),
  CustomerMenuThemeSpec(
    slug: 'amalfi_breeze',
    nameEn: 'Amalfi Breeze',
    nameBn: 'আমালফি ব্রিজ',
    taglineEn: 'Mocktails · cool & citrus',
    taglineBn: 'মকটেল · ঠাণ্ডা সিট্রাস',
    palette: [
      Color(0xFF2E6F8E),
      Color(0xFFF5D547),
      Color(0xFF9DD4B5),
      Color(0xFFFBFAF5),
      Color(0xFFE89A8A),
    ],
    sampleHeading: 'Frescos',
    headingFontFamilyHint: null,
    headingIsItalic: true,
  ),
  CustomerMenuThemeSpec(
    slug: 'milano_roast',
    nameEn: 'Milano Roast',
    nameBn: 'মিলানো রোস্ট',
    taglineEn: 'Coffee · editorial minimal',
    taglineBn: 'কফি · সাদাসিধে এডিটোরিয়াল',
    palette: [
      Color(0xFF3B2A1F),
      Color(0xFFE8D5B7),
      Color(0xFFB89556),
      Color(0xFFFAF7F2),
      Color(0xFF15110D),
    ],
    sampleHeading: 'ESPRESSO',
    headingFontFamilyHint: null,
    headingIsItalic: false,
  ),
  CustomerMenuThemeSpec(
    slug: 'sultans_hearth',
    nameEn: "Sultan's Hearth",
    nameBn: 'সুলতানের চুলা',
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
    slug: 'charcoal_lodge',
    nameEn: 'The Charcoal Lodge',
    nameBn: 'চারকোল লজ',
    taglineEn: 'Grill · smoky butcher',
    taglineBn: 'গ্রিল · ধোঁয়াটে কসাইখানা',
    palette: [
      Color(0xFF1C1C1E),
      Color(0xFF5C5852),
      Color(0xFF8B2828),
      Color(0xFFA0814D),
      Color(0xFFE8E2D4),
    ],
    sampleHeading: 'PRIME CUT',
    headingFontFamilyHint: 'serif',
    headingIsItalic: false,
  ),
  CustomerMenuThemeSpec(
    slug: 'bengal_bistro',
    nameEn: 'Gourmet Bengal Bistro',
    nameBn: 'গুর্মে বেঙ্গল বিস্ত্রো',
    taglineEn: 'Fuchka · street food, plated',
    taglineBn: 'ফুচকা · প্লেটে রাস্তার খাবার',
    palette: [
      Color(0xFFF5F2EB),
      Color(0xFF2C3E66),
      Color(0xFFD9A431),
      Color(0xFF7BA88C),
      Color(0xFF6B3825),
    ],
    sampleHeading: 'ফুচকা / Fuchka',
    headingFontFamilyHint: 'serif',
    headingIsItalic: false,
  ),
  CustomerMenuThemeSpec(
    slug: 'grand_mughal',
    nameEn: 'The Grand Mughal',
    nameBn: 'গ্র্যান্ড মুঘল',
    taglineEn: 'Biryani · saffron & pearl',
    taglineBn: 'বিরিয়ানি · জাফরান ও মুক্তা',
    palette: [
      Color(0xFF3A1F3D),
      Color(0xFFE8A33D),
      Color(0xFFF4EEDF),
      Color(0xFFB8923A),
      Color(0xFF5E1F2A),
    ],
    sampleHeading: 'KACCHI',
    headingFontFamilyHint: 'serif',
    headingIsItalic: false,
  ),
];

CustomerMenuThemeSpec resolveCustomerMenuTheme(String? slug) {
  for (final theme in customerMenuThemes) {
    if (theme.slug == slug) return theme;
  }
  return customerMenuThemes.first;
}
