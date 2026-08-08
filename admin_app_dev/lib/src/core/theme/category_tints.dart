import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// One randomized category palette: pale card background, complementary chip
/// border/text, and the saturated accent stripe color.
class CategoryPalette {
  const CategoryPalette({
    required this.background,
    required this.border,
    required this.text,
    required this.accent,
  });

  final Color background;
  final Color border;
  final Color text;
  final Color accent;
}

/// The ten palettes the assigner randomizes over — derived from the original
/// eleven name-keyed entries. Desserts is omitted because it is identical to
/// the vanilla [kCategoryBgDefault], which stays reserved for 'All' / 'General'
/// / unknown categories.
const List<CategoryPalette> kCategoryPalettes = [
  CategoryPalette(
    background: kTintSoftPeach,
    border: Color(0xFFFFC2B3),
    text: Color(0xFF9E2A0B),
    accent: Color(0xFFE0982E),
  ),
  CategoryPalette(
    background: kTintMutedCoral,
    border: Color(0xFFFFB8A8),
    text: Color(0xFFB91C1C),
    accent: Color(0xFFE0524E),
  ),
  CategoryPalette(
    background: kTintWarmAmber,
    border: Color(0xFFF0D48F),
    text: Color(0xFF7A4A0E),
    accent: Color(0xFFD9722E),
  ),
  CategoryPalette(
    background: kTintButterYellow,
    border: Color(0xFFFDE68A),
    text: Color(0xFF92400E),
    accent: Color(0xFFE0B33A),
  ),
  CategoryPalette(
    background: kTintMintCream,
    border: Color(0xFF86EFAC),
    text: Color(0xFF166534),
    accent: Color(0xFF5BA84F),
  ),
  CategoryPalette(
    background: kTintSageTint,
    border: Color(0xFFA8C3B0),
    text: Color(0xFF2D4A36),
    accent: Color(0xFF3FA85C),
  ),
  CategoryPalette(
    background: kTintSoftOlive,
    border: Color(0xFFBCCAC0),
    text: Color(0xFF3B4F40),
    accent: Color(0xFF2BA7A7),
  ),
  CategoryPalette(
    background: kTintSoftLavender,
    border: Color(0xFFD8CBF2),
    text: Color(0xFF57408C),
    accent: Color(0xFF7C5CD6),
  ),
  CategoryPalette(
    background: kTintIceBlue,
    border: Color(0xFFB9D3EE),
    text: Color(0xFF1E4E78),
    accent: Color(0xFF3E7BC0),
  ),
  CategoryPalette(
    background: kTintWarmSand,
    border: Color(0xFFE0D6C2),
    text: Color(0xFF5F5540),
    accent: Color(0xFF5A6475),
  ),
];

/// Local palette assignment store: real menu categories are mapped to
/// [kCategoryPalettes] indices at random (regardless of their names) on first
/// sight, and the mapping is persisted in SharedPreferences so the add-items
/// tints stay stable across restarts.
class CategoryPaletteAssigner {
  CategoryPaletteAssigner._();

  static final CategoryPaletteAssigner instance = CategoryPaletteAssigner._();

  static const String _prefsKey = 'category_palette_assignments';

  final Map<String, int> _assignments = {};
  final Random _random = Random();
  bool _loaded = false;

  /// Loaded from SharedPreferences during app boot; resolvers keep the
  /// name-keyed maps until this completes so no colors change mid-frame.
  bool get isLoaded => _loaded;

  /// Loads persisted assignments. Safe to call repeatedly.
  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((key, value) {
        if (key is String && value is int) _assignments[key] = value;
      });
    } catch (_) {
      // Corrupt or missing entry — start fresh; assignments happen lazily.
    }
  }

  /// Palette index for [category], preferring the persisted assignment and
  /// otherwise assigning a random not-yet-used palette (so the first ten
  /// categories are visually distinct). The assignment persists immediately.
  int paletteIndexFor(String category) {
    final existing = _assignments[category];
    if (existing != null) return existing;
    final used = _assignments.values.toSet();
    final available = [
      for (var i = 0; i < kCategoryPalettes.length; i++)
        if (!used.contains(i)) i,
    ];
    final index = available.isNotEmpty
        ? available[_random.nextInt(available.length)]
        : _random.nextInt(kCategoryPalettes.length);
    _assignments[category] = index;
    unawaited(_persist());
    return index;
  }

  /// Drops every stored assignment so categories re-randomize on next use.
  Future<void> reset() async {
    _assignments.clear();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_prefsKey);
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_prefsKey, jsonEncode(_assignments));
    } catch (_) {
      // Best-effort — the in-memory map keeps this session consistent.
    }
  }
}

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
  final trimmed = category.trim();
  final key = trimmed.toLowerCase();
  if (key.isEmpty || key == 'all' || key == 'general') {
    return kCategoryBgDefault;
  }
  if (CategoryPaletteAssigner.instance.isLoaded) {
    return kCategoryPalettes[
            CategoryPaletteAssigner.instance.paletteIndexFor(trimmed)]
        .background;
  }
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
  final trimmed = category.trim();
  final key = trimmed.toLowerCase();
  if (key.isEmpty || key == 'all' || key == 'general') {
    return kCategoryChipDefault;
  }
  if (CategoryPaletteAssigner.instance.isLoaded) {
    final palette = kCategoryPalettes[
        CategoryPaletteAssigner.instance.paletteIndexFor(trimmed)];
    return CategoryChipColors(
      background: palette.background,
      border: palette.border,
      text: palette.text,
    );
  }
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
  final trimmed = category.trim();
  final key = trimmed.toLowerCase();
  if (key.isEmpty || key == 'all' || key == 'general') {
    return _accentsList[0];
  }
  if (CategoryPaletteAssigner.instance.isLoaded) {
    return kCategoryPalettes[
            CategoryPaletteAssigner.instance.paletteIndexFor(trimmed)]
        .accent;
  }
  for (final entry in kCategoryAccents.entries) {
    if (entry.key.toLowerCase() == key) return entry.value;
  }
  return _accentsList[(key.hashCode & 0x7FFFFFFF) % _accentsList.length];
}
