import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/models/order_item.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_payment_method.dart';
import 'package:local_pos/src/models/order_service_type.dart';
import 'package:local_pos/src/models/order_status.dart';

void main() {
  test('legacy order maps default subtotal and VAT fields safely', () {
    final order = OrderModel.fromMap({
      'id': 'old-1',
      'orderNo': 'ORD-1',
      'status': OrderStatus.accepted.value,
      'total': 420,
      'createdAt': '2026-05-23T10:00:00Z',
      'updatedAt': '2026-05-23T10:00:00Z',
    });

    expect(order.subtotal, 420);
    expect(order.vatRatePercent, 0);
    expect(order.vatAmount, 0);
    expect(order.serviceType, isNull);
    expect(order.paymentMethod, isNull);
    expect(order.covers, isNull);
  });

  test('order metadata roundtrips through map and json payloads', () {
    final order = OrderModel(
      id: 'new-1',
      orderNo: 'ORD-2',
      status: OrderStatus.accepted,
      total: 525,
      subtotal: 500,
      vatRatePercent: 5,
      vatAmount: 25,
      serviceType: OrderServiceType.dineIn,
      covers: 3,
      paymentMethod: OrderPaymentMethod.bkash,
      items: const [],
      createdAt: DateTime.parse('2026-05-23T10:00:00Z'),
      updatedAt: DateTime.parse('2026-05-23T10:00:00Z'),
    );

    final remapped = OrderModel.fromMap(order.toMap());
    expect(remapped.serviceType, OrderServiceType.dineIn);
    expect(remapped.paymentMethod, OrderPaymentMethod.bkash);
    expect(remapped.covers, 3);
    expect(remapped.subtotal, 500);
    expect(remapped.vatRatePercent, 5);
    expect(remapped.vatAmount, 25);

    expect(order.toJson()['serviceType'], 'dine_in');
    expect(order.toJson()['paymentMethod'], 'bkash');
    expect(order.toJson()['vatAmount'], 25);
  });

  test('order item bilingual names roundtrip and localize', () {
    final item = OrderItem(
      id: 'line-1',
      orderId: 'order-1',
      menuItemId: 'menu-1',
      name: 'Chicken Burger',
      nameEn: 'Chicken Burger',
      nameBn: 'চিকেন বার্গার',
      qty: 2,
      price: 220,
      lineTotal: 440,
    );

    final remapped = OrderItem.fromMap(item.toMap());
    expect(remapped.toJson()['nameEn'], 'Chicken Burger');
    expect(remapped.toJson()['nameBn'], 'চিকেন বার্গার');
    expect(remapped.localizedName(AppLanguage.en), 'Chicken Burger');
    expect(remapped.localizedName(AppLanguage.bn), 'চিকেন বার্গার');

    final legacy = OrderItem.fromMap({
      'id': 'line-2',
      'orderId': 'order-1',
      'menuItemId': 'menu-2',
      'name': 'Tea / চা',
      'qty': 1,
      'price': 20,
      'lineTotal': 20,
    });
    expect(legacy.localizedName(AppLanguage.en), 'Tea');
    expect(legacy.localizedName(AppLanguage.bn), 'চা');
  });
}
