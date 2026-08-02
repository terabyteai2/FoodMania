import 'package:flutter/material.dart';

// ── Category card-tint palette ──
// Four families chosen for the add-items picker cards:
//   neutral  · warm & appetizing (red/orange/yellow) · fresh & healthy (green)
//   · calm & premium (blue/purple/warm gray)

// Neutral base
const Color kTintWarmVanilla = Color(0xFFFFFDF7);
const Color kTintSoftPorcelain = Color(0xFFF8FAFC);
const Color kTintWarmCream = Color(0xFFFAF7F2);
const Color kTintCoolMist = Color(0xFFF3F4F6);

// Warm & Appetizing
const Color kTintSoftPeach = Color(0xFFFFF5F2);
const Color kTintMutedCoral = Color(0xFFFFEEEA);
const Color kTintButterYellow = Color(0xFFFFFBEB);
const Color kTintWarmAmber = Color(0xFFFFF8E7);

// Fresh & Healthy
const Color kTintMintCream = Color(0xFFF0FDF4);
const Color kTintSageTint = Color(0xFFF1F5F2);
const Color kTintSoftOlive = Color(0xFFF4F7F4);

// Calm & Premium
const Color kTintIceBlue = Color(0xFFF0F7FF);
const Color kTintSoftLavender = Color(0xFFF8F5FF);
const Color kTintWarmSand = Color(0xFFF7F5F0);

/// Fallback tint for unknown categories / 'General'.
const Color kCategoryBgDefault = kTintWarmVanilla;

const Map<String, Color> kCategoryBgTints = {
  'Burgers': kTintSoftPeach,
  'Pizza': kTintMutedCoral,
  'Kebab': kTintWarmAmber,
  'Breakfast': kTintButterYellow,
  'Salads': kTintMintCream,
  'Rice & Curry': kTintSageTint,
  'Seafood': kTintSoftOlive,
  'Beverages': kTintSoftLavender,
  'Sides': kTintIceBlue,
  'Combos': kTintWarmSand,
  'Desserts': kTintWarmVanilla,
};

Color resolveCategoryBg(String category) {
  final key = category.toLowerCase().trim();
  for (final entry in kCategoryBgTints.entries) {
    if (entry.key.toLowerCase() == key) return entry.value;
  }
  return kCategoryBgDefault;
}

// ── Category chip pairing: bg tint + complementary border & text ──

class CategoryChipColors {
  const CategoryChipColors({
    required this.background,
    required this.border,
    required this.text,
  });

  final Color background;
  final Color border;
  final Color text;
}

/// Fallback chip pairing for unknown categories / 'All' / 'General'.
const CategoryChipColors kCategoryChipDefault = CategoryChipColors(
  background: kTintWarmVanilla,
  border: Color(0xFFEADCC9),
  text: Color(0xFF5C4A33),
);

const Map<String, CategoryChipColors> kCategoryChipColors = {
  'Burgers': CategoryChipColors(
    background: kTintSoftPeach,
    border: Color(0xFFFFC2B3),
    text: Color(0xFF9E2A0B),
  ),
  'Pizza': CategoryChipColors(
    background: kTintMutedCoral,
    border: Color(0xFFFFB8A8),
    text: Color(0xFFB91C1C),
  ),
  'Kebab': CategoryChipColors(
    background: kTintWarmAmber,
    border: Color(0xFFF0D48F),
    text: Color(0xFF7A4A0E),
  ),
  'Breakfast': CategoryChipColors(
    background: kTintButterYellow,
    border: Color(0xFFFDE68A),
    text: Color(0xFF92400E),
  ),
  'Salads': CategoryChipColors(
    background: kTintMintCream,
    border: Color(0xFF86EFAC),
    text: Color(0xFF166534),
  ),
  'Rice & Curry': CategoryChipColors(
    background: kTintSageTint,
    border: Color(0xFFA8C3B0),
    text: Color(0xFF2D4A36),
  ),
  'Seafood': CategoryChipColors(
    background: kTintSoftOlive,
    border: Color(0xFFBCCAC0),
    text: Color(0xFF3B4F40),
  ),
  'Beverages': CategoryChipColors(
    background: kTintSoftLavender,
    border: Color(0xFFD8CBF2),
    text: Color(0xFF57408C),
  ),
  'Sides': CategoryChipColors(
    background: kTintIceBlue,
    border: Color(0xFFB9D3EE),
    text: Color(0xFF1E4E78),
  ),
  'Combos': CategoryChipColors(
    background: kTintWarmSand,
    border: Color(0xFFE0D6C2),
    text: Color(0xFF5F5540),
  ),
  'Desserts': CategoryChipColors(
    background: kTintWarmVanilla,
    border: Color(0xFFEADCC9),
    text: Color(0xFF5C4A33),
  ),
};

CategoryChipColors resolveCategoryChip(String category) {
  final key = category.toLowerCase().trim();
  for (final entry in kCategoryChipColors.entries) {
    if (entry.key.toLowerCase() == key) return entry.value;
  }
  return kCategoryChipDefault;
}

/// Saturated per-category accent palette — distinct from the pale
/// [kCategoryBgTints] image tints. Used as the left color-code stripe on the
/// add-items picker cards so each category reads at a glance.
const Map<String, Color> kCategoryAccents = {
  'Burgers': Color(0xFFE0982E),
  'Pizza': Color(0xFFE0524E),
  'Rice & Curry': Color(0xFF3FA85C),
  'Kebab': Color(0xFFD9722E),
  'Sides': Color(0xFF3E7BC0),
  'Salads': Color(0xFF5BA84F),
  'Beverages': Color(0xFF7C5CD6),
  'Desserts': Color(0xFFE06AA6),
  'Seafood': Color(0xFF2BA7A7),
  'Breakfast': Color(0xFFE0B33A),
  'Combos': Color(0xFF5A6475),
};

final _accentsList = kCategoryAccents.values.toList();

Color resolveCategoryAccent(String category) {
  final key = category.toLowerCase().trim();
  for (final entry in kCategoryAccents.entries) {
    if (entry.key.toLowerCase() == key) return entry.value;
  }
  return _accentsList[(key.hashCode & 0x7FFFFFFF) % _accentsList.length];
}
