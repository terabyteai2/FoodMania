import '../core/localization/app_strings.dart';
import 'inventory_unit.dart';

class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.minThreshold,
    required this.costPerUnit,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
  });

  final String id;
  final String name;
  final String category;
  final String unit;
  final double quantity;
  final double minThreshold;
  final double costPerUnit;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLowStock => quantity > 0 && quantity <= minThreshold;
  bool get isOutOfStock => quantity <= 0;
  String get nameEn => _splitName(name).$1;
  String get nameBn {
    final (english, bangla) = _splitName(name);
    if (bangla.isNotEmpty) return bangla;
    return banglaFallbackForEnglish(english);
  }

  String localizedName(AppLanguage language) {
    return localizedInventoryName(name, language);
  }

  String get searchText =>
      [name, nameEn, nameBn, category].join(' ').toLowerCase();

  InventoryItem copyWith({
    String? id,
    String? name,
    String? category,
    String? unit,
    double? quantity,
    double? minThreshold,
    double? costPerUnit,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      minThreshold: minThreshold ?? this.minThreshold,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'unit': unit,
      'quantity': quantity,
      'minThreshold': minThreshold,
      'costPerUnit': costPerUnit,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InventoryItem.fromMap(Map<String, Object?> map) {
    return InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String,
      category: map['category'] as String? ?? '',
      unit: InventoryUnits.normalize(
        map['unit'] as String? ?? InventoryUnits.pcs,
      ),
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0,
      minThreshold: (map['minThreshold'] as num?)?.toDouble() ?? 0,
      costPerUnit: (map['costPerUnit'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  static String localizedInventoryName(String name, AppLanguage language) {
    final (english, bangla) = _splitName(name);
    if (language == AppLanguage.bn) {
      if (bangla.isNotEmpty) return bangla;
      final translated = banglaFallbackForEnglish(english);
      if (translated.isNotEmpty) return translated;
      return english.isNotEmpty ? english : name.trim();
    }
    if (english.isNotEmpty) return english;
    return bangla.isNotEmpty ? bangla : name.trim();
  }

  static String localizedNameParts({
    required String nameEn,
    required String nameBn,
    required AppLanguage language,
  }) {
    final english = nameEn.trim();
    final bangla = nameBn.trim();
    if (language == AppLanguage.bn) {
      if (bangla.isNotEmpty) return bangla;
      final translated = banglaFallbackForEnglish(english);
      if (translated.isNotEmpty) return translated;
      return english;
    }
    return english.isNotEmpty ? english : bangla;
  }

  static String banglaFallbackForEnglish(String value) {
    final normalized = _normalizeNameKey(value);
    if (normalized.isEmpty) return '';
    final exact = _commonBanglaNames[normalized];
    if (exact != null) return exact;
    if (normalized.endsWith('s')) {
      final singular =
          _commonBanglaNames[normalized.substring(0, normalized.length - 1)];
      if (singular != null) return singular;
    }
    final words = normalized.split(' ');
    if (words.length > 1) {
      final translated = words
          .map((word) => _commonBanglaNames[word] ?? '')
          .where((word) => word.isNotEmpty)
          .toList(growable: false);
      if (translated.length == words.length) return translated.join(' ');
    }
    return '';
  }

  static (String, String) _splitName(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return ('', '');
    if (raw.contains('/')) {
      final parts = raw.split('/');
      final english = parts.first.trim();
      final bangla = parts.skip(1).join('/').trim();
      return (english, bangla);
    }
    if (_containsBengali(raw)) return ('', raw);
    return (raw, '');
  }

  static String _normalizeNameKey(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static bool _containsBengali(String value) {
    return RegExp(r'[\u0980-\u09FF]').hasMatch(value);
  }
}

const Map<String, String> _commonBanglaNames = {
  'atta': 'আটা',
  'banana': 'কলা',
  'beef': 'বিফ',
  'beef bone': 'বিফ হাড়',
  'bread': 'পাউরুটি',
  'bun': 'বান',
  'butter': 'বাটার',
  'cabbage': 'বাঁধাকপি',
  'capsicum': 'ক্যাপসিকাম',
  'carrot': 'গাজর',
  'cheese': 'চিজ',
  'chicken': 'চিকেন',
  'chicken breast': 'চিকেন ব্রেস্ট',
  'chicken leg': 'চিকেন লেগ',
  'chili': 'মরিচ',
  'chilli': 'মরিচ',
  'coriander': 'ধনিয়া',
  'coriander leaves': 'ধনেপাতা',
  'cream': 'ক্রিম',
  'cucumber': 'শসা',
  'curd': 'দই',
  'dal': 'ডাল',
  'egg': 'ডিম',
  'fish': 'মাছ',
  'flour': 'ময়দা',
  'garam masala': 'গরম মসলা',
  'garlic': 'রসুন',
  'ginger': 'আদা',
  'green chili': 'কাঁচা মরিচ',
  'green chilli': 'কাঁচা মরিচ',
  'ketchup': 'কেচাপ',
  'lemon': 'লেবু',
  'lime': 'লেবু',
  'maida': 'ময়দা',
  'masala': 'মসলা',
  'mayonnaise': 'মেয়োনিজ',
  'milk': 'দুধ',
  'mint': 'পুদিনা',
  'mustard oil': 'সরিষার তেল',
  'mutton': 'মাটন',
  'noodles': 'নুডলস',
  'oil': 'তেল',
  'onion': 'পেঁয়াজ',
  'pasta': 'পাস্তা',
  'potato': 'আলু',
  'red chili': 'শুকনা মরিচ',
  'red chilli': 'শুকনা মরিচ',
  'rice': 'চাল',
  'salt': 'লবণ',
  'sauce': 'সস',
  'soy sauce': 'সয়া সস',
  'soybean oil': 'সয়াবিন তেল',
  'spice': 'মসলা',
  'spices': 'মসলা',
  'sugar': 'চিনি',
  'tea': 'চা',
  'tomato': 'টমেটো',
  'tomato sauce': 'টমেটো সস',
  'turmeric': 'হলুদ',
  'vinegar': 'ভিনেগার',
  'water': 'পানি',
  'yogurt': 'দই',
};
