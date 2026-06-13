/// Standard inventory units — stored value vs display label.
class InventoryUnits {
  InventoryUnits._();

  static const kg = 'kg';
  static const g = 'g';
  static const L = 'L';
  static const mL = 'mL';
  static const pcs = 'pcs';

  static const List<String> all = [kg, g, L, mL, pcs];

  static String displayLabel(String unit, {bool isBn = false}) {
    switch (normalize(unit)) {
      case g:
        return isBn ? 'গ্রাম' : 'gm';
      case L:
        return isBn ? 'লিটার' : 'ltr';
      case mL:
        return isBn ? 'মিলি' : 'ml';
      case kg:
        return isBn ? 'কেজি' : 'kg';
      case pcs:
        return isBn ? 'পিস' : 'pcs';
      default:
        return unit;
    }
  }

  static String normalize(String raw) {
    final u = raw.trim().toLowerCase();
    if (u == 'gm' || u == 'gram' || u == 'grams') return g;
    if (u == 'ltr' || u == 'liter' || u == 'litre') return L;
    if (u == 'ml' || u == 'milliliter') return mL;
    if (u == 'kg' || u == 'kilo') return kg;
    if (u == 'pc' || u == 'pcs' || u == 'piece' || u == 'pieces') return pcs;
    if (all.contains(raw)) return raw;
    if (u == 'l') return L;
    return pcs;
  }

  static String formatQuantity(double qty, String unit, {bool isBn = false}) {
    final label = displayLabel(unit, isBn: isBn);
    final formatted = qty == qty.roundToDouble()
        ? qty.toStringAsFixed(0)
        : qty.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
    return '$formatted $label';
  }
}
