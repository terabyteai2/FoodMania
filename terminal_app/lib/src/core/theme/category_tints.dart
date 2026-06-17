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
