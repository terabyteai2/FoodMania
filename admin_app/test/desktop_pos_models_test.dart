import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/models/desktop_pos.dart';
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
