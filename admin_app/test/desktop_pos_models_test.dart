import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/features/desktop_pos/widgets/menu_line_customizer.dart';
import 'package:local_pos/src/models/desktop_pos.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_item.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_payment_method.dart';
import 'package:local_pos/src/models/order_source.dart';
import 'package:local_pos/src/models/order_status.dart';

void main() {
  test('desktop settings synthesize a backward-compatible Main floor', () {
    final settings = DesktopPosSettings.fromJson(
      const {},
      fallbackTableCount: 3,
    );

    expect(settings.floorLayout.single.name, 'Main');
    expect(settings.floorLayout.single.tables.map((table) => table.label), [
      '1',
      '2',
      '3',
    ]);
    expect(settings.vatRatePercent, 0);
    expect(settings.serviceChargePercent, 0);
  });

  test('desktop settings allow a counter-only Main floor with zero tables', () {
    final settings = DesktopPosSettings.fromJson(
      const {},
      fallbackTableCount: 0,
    );

    expect(settings.floorLayout.single.name, 'Main');
    expect(settings.floorLayout.single.tables, isEmpty);
  });

  test('menu customizer is required only for configured choices', () {
    final plain = _menuItem();
    final withOption = _menuItem(tags: const ['option:Large:30']);
    final withSizeAlias = _menuItem(tags: const ['size:Medium:10']);
    final withAddOn = _menuItem(tags: const ['addon:20:Cheese']);

    expect(desktopMenuNeedsCustomization(plain), isFalse);
    expect(desktopMenuOptionsFor(plain).single.label, isEmpty);
    expect(desktopMenuNeedsCustomization(withOption), isTrue);
    expect(
      desktopConfiguredMenuOptionsFor(withSizeAlias).single.label,
      'Medium',
    );
    expect(desktopMenuNeedsCustomization(withAddOn), isTrue);
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
      final option = desktopConfiguredMenuOptionsFor(item).single;
      final addOn = item.extras.addOns.single;
      final selection = DesktopMenuLineSelection(
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

  test('desktop order snapshots survive SQLite map round trip', () {
    final now = DateTime(2026, 6, 2, 12);
    final order = OrderModel(
      id: 'order-1',
      orderNo: 'ORD-1',
      status: OrderStatus.served,
      total: 110,
      subtotal: 100,
      vatRatePercent: 5,
      vatAmount: 5,
      serviceChargeRatePercent: 10,
      serviceChargeAmount: 10,
      discountLabel: 'Staff 5%',
      discountAmount: 5,
      shiftId: 'shift-1',
      settledAt: now,
      billingSnapshot: const {'totalAmount': 110},
      kotBatches: const [
        {'id': 'kot-1'},
      ],
      items: [
        OrderItem(
          id: 'line-1',
          orderId: 'order-1',
          menuItemId: 'rice',
          name: 'Rice',
          qty: 1,
          price: 100,
          lineTotal: 100,
          costPriceSnapshot: 40,
          note: 'No chilli',
          kotBatchId: 'kot-1',
          kotSentAt: now,
        ),
      ],
      source: OrderSource.desktopPos,
      paymentMethod: OrderPaymentMethod.nagad,
      createdAt: now,
      updatedAt: now,
    );

    final decoded = OrderModel.fromMap(order.toMap(), items: order.items);

    expect(decoded.source, OrderSource.desktopPos);
    expect(decoded.paymentMethod, OrderPaymentMethod.nagad);
    expect(decoded.shiftId, 'shift-1');
    expect(decoded.billingSnapshot['totalAmount'], 110);
    expect(decoded.kotBatches.single['id'], 'kot-1');
    expect(decoded.items.single.note, 'No chilli');
  });

  test('shift denomination maps survive SQLite map round trip', () {
    final shift = PosShift(
      id: 'shift-1',
      status: 'open',
      openingCash: 1100,
      openingDenominations: const {'500': 2, '100': 1},
      openedAt: DateTime(2026, 6, 2, 8),
    );

    expect(PosShift.fromMap(shift.toMap()).openingDenominations, {
      '500': 2,
      '100': 1,
    });
  });

  test('report aggregates survive offline cache JSON round trip', () {
    const report = PosReportSnapshot(
      sales: 850,
      orders: 4,
      covers: 11,
      paymentSplit: {'cash': 500, 'nagad': 350},
      hourlySales: {12: 400, 13: 450},
      priorSameWeekdayHourlyAverage: {12: 300},
      coversByHour: {12: 5, 13: 6},
      auditCounts: {'refund': 1},
      items: [
        {'name': 'Rice', 'qty': 3, 'margin': 120},
      ],
      staff: [
        {'accountId': 'staff-1', 'orders': 4},
      ],
    );

    final decoded = PosReportSnapshot.fromJson(report.toJson());

    expect(decoded.paymentSplit['nagad'], 350);
    expect(decoded.priorSameWeekdayHourlyAverage[12], 300);
    expect(decoded.coversByHour[13], 6);
    expect(decoded.auditCounts['refund'], 1);
  });
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
