import 'package:flutter/material.dart';

const Map<String, Color> kCategoryBgTints = {
  'Burgers': Color(0xFFFBEFCD),
  'Pizza': Color(0xFFFBE3E2),
  'Rice & Curry': Color(0xFFE4FBC9),
  'Kebab': Color(0xFFFFE8D6),
  'Sides': Color(0xFFE3EAFC),
  'Salads': Color(0xFFF0FADF),
  'Beverages': Color(0xFFEDE0F9),
  'Desserts': Color(0xFFFDE4F0),
  'Seafood': Color(0xFFD5F5F5),
  'Breakfast': Color(0xFFFEF5D4),
  'Combos': Color(0xFFEDF1F7),
};

final _tintsList = kCategoryBgTints.values.toList();

Color resolveCategoryBg(String category) {
  final key = category.toLowerCase().trim();
  for (final entry in kCategoryBgTints.entries) {
    if (entry.key.toLowerCase() == key) return entry.value;
  }
  return _tintsList[(key.hashCode & 0x7FFFFFFF) % _tintsList.length];
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
