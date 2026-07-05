import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_item.dart';

/// One configured line in the working ticket: a menu item + an optional
/// size/option choice + selected add-ons + quantity + kitchen note.
///
/// Mirrors the reused `DesktopMenuLineSelection` bridge to `OrderRequestItem`,
/// but is owned by desktop_app so the register stays independent of the
/// rejected `desktop_pos` UI layer.
class CartLine {
  CartLine({
    required this.item,
    this.optionLabel = '',
    this.optionPriceDelta = 0,
    this.addOns = const <MenuAddOn>[],
    this.qty = 1,
    this.note,
  });

  final MenuItem item;
  final String optionLabel;
  final double optionPriceDelta;
  final List<MenuAddOn> addOns;
  int qty;
  final String? note;

  double get unitPrice {
    final addOnTotal = addOns.fold<double>(0, (sum, addOn) => sum + addOn.price);
    final value = item.price + optionPriceDelta + addOnTotal;
    return value < 0 ? 0 : double.parse(value.toStringAsFixed(2));
  }

  double get lineTotal => double.parse((unitPrice * qty).toStringAsFixed(2));

  String get modifierLabel {
    final labels = <String>[];
    if (optionLabel.trim().isNotEmpty) labels.add(optionLabel.trim());
    for (final addOn in addOns) {
      if (addOn.name.trim().isNotEmpty) labels.add(addOn.name.trim());
    }
    return labels.join(', ');
  }

  /// Identity used to merge duplicate taps of the same configured item.
  String get mergeKey => [
        item.id,
        optionLabel.trim().toLowerCase(),
        optionPriceDelta.toStringAsFixed(2),
        for (final addOn in addOns) '${addOn.name}:${addOn.price}',
        note?.trim() ?? '',
      ].join('|');

  String displayName(AppLanguage language) {
    final base = item.localizedName(language);
    final mods = modifierLabel;
    return mods.isEmpty ? base : '$base ($mods)';
  }

  OrderRequestItem toRequestItem() {
    final mods = modifierLabel.trim();
    final cleanNote = note?.trim();
    return OrderRequestItem(
      menuItemId: item.id,
      qty: qty,
      note: cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
      unitPrice: unitPrice,
      nameSuffix: mods.isEmpty ? null : mods,
    );
  }
}
