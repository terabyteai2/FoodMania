import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/features/orders/menu_line_customizer.dart';
import 'package:local_pos/src/models/menu_item.dart';

void main() {
  test('menu customizer is required only for configured choices', () {
    final plain = _menuItem();
    final withOption = _menuItem(tags: const ['option:Large:30']);
    final withSizeAlias = _menuItem(tags: const ['size:Medium:10']);
    final withAddOn = _menuItem(tags: const ['addon:20:Cheese']);

    expect(menuLineNeedsCustomization(plain), isFalse);
    expect(menuLineOptionsFor(plain).single.label, isEmpty);
    expect(menuLineNeedsCustomization(withOption), isTrue);
    expect(
      configuredMenuLineOptionsFor(withSizeAlias).single.label,
      'Medium',
    );
    expect(menuLineNeedsCustomization(withAddOn), isTrue);
  });

  test('menu extras round trip size options as order variants', () {
    final extras = MenuItemExtras.fromTags(const [
      'option:Large:30',
      'size:Medium:10',
      'addon:15:Cheese',
    ]);

    expect(extras.options.map((option) => option.name).toList(), [
      'Large',
      'Medium',
    ]);
    expect(extras.options.map((option) => option.priceDelta).toList(), [
      30,
      10,
    ]);
    expect(extras.toTags(), [
      'option:Large:30',
      'option:Medium:10',
      'addon:15:Cheese',
    ]);
  });

  test(
    'menu customizer selection carries price and suffix into request item',
    () {
      final item = _menuItem(
        tags: const ['option:Large:30', 'addon:15:Cheese'],
      );
      final option = configuredMenuLineOptionsFor(item).single;
      final addOn = item.extras.addOns.single;
      final selection = MenuLineSelection(
        item: item,
        option: option,
        addOns: [addOn],
        qty: 2,
      );

      final request = selection.toRequestItem();

      expect(selection.unitPrice, 145);
      expect(selection.lineTotal, 290);
      expect(request.unitPrice, 145);
      expect(request.nameSuffix, 'Large, Cheese');
    },
  );
}

MenuItem _menuItem({List<String> tags = const []}) {
  final now = DateTime(2026, 6, 2, 12);
  return MenuItem(
    id: 'menu-1',
    name: 'Burger',
    description: '',
    category: 'Food',
    price: 100,
    isAvailable: true,
    tags: tags,
    createdAt: now,
    updatedAt: now,
  );
}
