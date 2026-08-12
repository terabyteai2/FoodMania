import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Category card-fill palette ──
// Nine muted colors assigned to the add-items picker cards. Each category is
// matched to one palette (random-but-persisted, see CategoryPaletteAssigner);
// the background is the saturated fill, border is a darker shade of it, and
// text is white except on the lightest fills (yellow/light green/light gray)
// which take a dark ink instead.
const Color kCategoryBgDefault = Color(0xFFFFFDF7);

/// Dark ink used for text on the lightest category fills.
const Color kCategoryOnFillDark = Color(0xFF4A3B0A);
const Color kCategoryTextWhite = Colors.white;

/// One randomized category palette: saturated card background, complementary
/// chip border, and the text color that stays readable on it.
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

/// The nine palettes the assigner randomizes over. Backgrounds are the chosen
/// palette; borders are the background darkened ~28%; text is white except on
/// the three lightest fills (which exceed the 0.55 luminance threshold used by
/// [onCategoryFill]).
const List<CategoryPalette> kCategoryPalettes = [
  CategoryPalette(
    background: Color(0xFFA3BFDA),
    border: Color(0xFF758A9D),
    text: kCategoryTextWhite,
    accent: Color(0xFFA3BFDA),
  ),
  CategoryPalette(
    background: Color(0xFFAACF97),
    border: Color(0xFF7A956D),
    text: kCategoryOnFillDark,
    accent: Color(0xFFAACF97),
  ),
  CategoryPalette(
    background: Color(0xFF84C3B6),
    border: Color(0xFF5F8C83),
    text: kCategoryTextWhite,
    accent: Color(0xFF84C3B6),
  ),
  CategoryPalette(
    background: Color(0xFFDE8893),
    border: Color(0xFFA0626A),
    text: kCategoryTextWhite,
    accent: Color(0xFFDE8893),
  ),
  CategoryPalette(
    background: Color(0xFFA1C98A),
    border: Color(0xFF749163),
    text: kCategoryTextWhite,
    accent: Color(0xFFA1C98A),
  ),
  CategoryPalette(
    background: Color(0xFFC2AACC),
    border: Color(0xFF8C7A93),
    text: kCategoryTextWhite,
    accent: Color(0xFFC2AACC),
  ),
  CategoryPalette(
    background: Color(0xFFF5DD7D),
    border: Color(0xFFB09F5A),
    text: kCategoryOnFillDark,
    accent: Color(0xFFF5DD7D),
  ),
  CategoryPalette(
    background: Color(0xFFBD9B7F),
    border: Color(0xFF88705B),
    text: kCategoryTextWhite,
    accent: Color(0xFFBD9B7F),
  ),
  CategoryPalette(
    background: Color(0xFFCACCCB),
    border: Color(0xFF919392),
    text: kCategoryOnFillDark,
    accent: Color(0xFFCACCCB),
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
  /// otherwise assigning a random not-yet-used palette (so the first nine
  /// categories are visually distinct). The assignment persists immediately.
  /// Persisted indices are clamped to the current palette length so an
  /// assignment made against an older, longer palette can never index
  /// out of bounds.
  int paletteIndexFor(String category) {
    final existing = _assignments[category];
    if (existing != null) return existing % kCategoryPalettes.length;
    final used = _assignments.values
        .map((i) => i % kCategoryPalettes.length)
        .toSet();
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
  'Burgers': Color(0xFFA3BFDA),
  'Pizza': Color(0xFFDE8893),
  'Kebab': Color(0xFFF5DD7D),
  'Breakfast': Color(0xFFAACF97),
  'Salads': Color(0xFFA1C98A),
  'Rice & Curry': Color(0xFF84C3B6),
  'Seafood': Color(0xFFC2AACC),
  'Beverages': Color(0xFFBD9B7F),
  'Sides': Color(0xFFCACCCB),
  'Combos': Color(0xFFA3BFDA),
  'Desserts': Color(0xFFDE8893),
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

// ── Category chip pairing: bg fill + complementary border & text ──

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
  background: kCategoryBgDefault,
  border: Color(0xFFEADCC9),
  text: Color(0xFF5C4A33),
);

const Map<String, CategoryChipColors> kCategoryChipColors = {
  'Burgers': CategoryChipColors(
    background: Color(0xFFA3BFDA),
    border: Color(0xFF758A9D),
    text: kCategoryTextWhite,
  ),
  'Pizza': CategoryChipColors(
    background: Color(0xFFDE8893),
    border: Color(0xFFA0626A),
    text: kCategoryTextWhite,
  ),
  'Kebab': CategoryChipColors(
    background: Color(0xFFF5DD7D),
    border: Color(0xFFB09F5A),
    text: kCategoryOnFillDark,
  ),
  'Breakfast': CategoryChipColors(
    background: Color(0xFFAACF97),
    border: Color(0xFF7A956D),
    text: kCategoryOnFillDark,
  ),
  'Salads': CategoryChipColors(
    background: Color(0xFFA1C98A),
    border: Color(0xFF749163),
    text: kCategoryTextWhite,
  ),
  'Rice & Curry': CategoryChipColors(
    background: Color(0xFF84C3B6),
    border: Color(0xFF5F8C83),
    text: kCategoryTextWhite,
  ),
  'Seafood': CategoryChipColors(
    background: Color(0xFFC2AACC),
    border: Color(0xFF8C7A93),
    text: kCategoryTextWhite,
  ),
  'Beverages': CategoryChipColors(
    background: Color(0xFFBD9B7F),
    border: Color(0xFF88705B),
    text: kCategoryTextWhite,
  ),
  'Sides': CategoryChipColors(
    background: Color(0xFFCACCCB),
    border: Color(0xFF919392),
    text: kCategoryOnFillDark,
  ),
  'Combos': CategoryChipColors(
    background: Color(0xFFA3BFDA),
    border: Color(0xFF758A9D),
    text: kCategoryTextWhite,
  ),
  'Desserts': CategoryChipColors(
    background: Color(0xFFDE8893),
    border: Color(0xFFA0626A),
    text: kCategoryTextWhite,
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

/// Saturated per-category accent palette — the same background fills, used as
/// the left color-code stripe on the add-items picker cards so each category
/// reads at a glance.
const Map<String, Color> kCategoryAccents = {
  'Burgers': Color(0xFFA3BFDA),
  'Pizza': Color(0xFFDE8893),
  'Rice & Curry': Color(0xFF84C3B6),
  'Kebab': Color(0xFFF5DD7D),
  'Sides': Color(0xFFCACCCB),
  'Salads': Color(0xFFA1C98A),
  'Beverages': Color(0xFFBD9B7F),
  'Desserts': Color(0xFFDE8893),
  'Seafood': Color(0xFFC2AACC),
  'Breakfast': Color(0xFFAACF97),
  'Combos': Color(0xFFA3BFDA),
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