import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/dashboard/dashboard_screen.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_item.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_payment_method.dart';
import 'package:local_pos/src/models/order_service_type.dart';
import 'package:local_pos/src/models/order_source.dart';
import 'package:local_pos/src/models/order_status.dart';

Widget _scoped(PosAppController controller, Widget child) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

MenuItem _menuItem() {
  final now = DateTime(2026, 5, 22, 12);
  return MenuItem(
    id: 'menu-1',
    name: 'Burger',
    description: 'Juicy burger.',
    category: 'Mains',
    price: 220,
    isAvailable: true,
    createdAt: now,
    updatedAt: now,
  );
}

class _OrderFlowController extends PosAppController {
  @override
  Future<OrderModel> createManualOrder({
    required List<OrderRequestItem> requestedItems,
    String? customerName,
    String? tableNo,
    String? note,
    OrderServiceType? serviceType,
    int? covers,
    OrderPaymentMethod? paymentMethod,
  }) async {
    final now = DateTime(2026, 5, 24, 12);
    final orderItems = <OrderItem>[];
    var total = 0.0;
    for (final request in requestedItems) {
      final menuItem = menuItems.firstWhere(
        (item) => item.id == request.menuItemId,
      );
      final lineTotal = menuItem.price * request.qty;
      total += lineTotal;
      orderItems.add(
        OrderItem(
          id: 'line-${menuItem.id}',
          orderId: 'order-1',
          menuItemId: menuItem.id,
          name: menuItem.name,
          nameEn: menuItem.nameEn,
          nameBn: menuItem.nameBn,
          qty: request.qty,
          price: menuItem.price,
          lineTotal: lineTotal,
        ),
      );
    }
    return OrderModel(
      id: 'order-1',
      orderNo: 'ORD-1',
      status: OrderStatus.accepted,
      total: total,
      subtotal: total,
      source: OrderSource.manual,
      serviceType: serviceType,
      tableNo: tableNo,
      paymentMethod: paymentMethod,
      sequenceNo: 1,
      items: orderItems,
      createdAt: now,
      updatedAt: now,
    );
  }
}

void main() {
  testWidgets('dashboard manager FAB opens the new order flow', (tester) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..menuItems = [_menuItem()];

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    expect(find.byTooltip('New order'), findsOneWidget);

    await tester.tap(find.byTooltip('New order'));
    await tester.pumpAndSettle();

    expect(find.text("Where's this order for?"), findsOneWidget);

    controller.dispose();
  });

  testWidgets('new order final step keeps bill details visible', (
    tester,
  ) async {
    final item = _menuItem();
    final controller = _OrderFlowController()
      ..language = AppLanguage.en
      ..menuItems = [item];

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    await tester.tap(find.byTooltip('New order'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parcel').first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Burger'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create order'));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text('Order created').evaluate().isNotEmpty) break;
    }
    await tester.pump(const Duration(seconds: 3));

    expect(find.text('Order created'), findsWidgets);
    expect(find.text('Print receipt'), findsOneWidget);
    expect(find.text('Burger'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    controller.dispose();
  });
}
