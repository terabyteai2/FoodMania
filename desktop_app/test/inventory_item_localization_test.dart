import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/models/inventory_item.dart';
import 'package:local_pos/src/models/inventory_unit.dart';

void main() {
  InventoryItem item(String name) {
    final now = DateTime(2026, 5, 25, 12);
    return InventoryItem(
      id: name,
      name: name,
      category: 'raw',
      unit: InventoryUnits.kg,
      quantity: 1,
      minThreshold: 0,
      costPerUnit: 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  test(
    'inventory item names localize from bilingual or common stock names',
    () {
      expect(item('Chicken / চিকেন').localizedName(AppLanguage.bn), 'চিকেন');
      expect(item('Chicken / চিকেন').localizedName(AppLanguage.en), 'Chicken');
      expect(item('Salt').localizedName(AppLanguage.bn), 'লবণ');
      expect(item('Onion').nameBn, 'পেঁয়াজ');
    },
  );
}
