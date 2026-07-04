import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/orders/orders_screen.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_item.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_source.dart';
import 'package:local_pos/src/models/order_status.dart';
import 'package:local_pos/src/models/server_config.dart';
import 'package:local_pos/src/services/sync_service.dart';

Widget _scoped(PosAppController controller, Widget child) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

PosAppController _controller() => PosAppController()..language = AppLanguage.en;

MenuItem _menuItem({bool available = true}) {
  final now = DateTime(2026, 5, 22, 12);
  return MenuItem(
    id: 'menu-1',
    name: 'Burger',
    description: 'Juicy burger.',
    category: 'Mains',
    price: 220,
    isAvailable: available,
    createdAt: now,
    updatedAt: now,
  );
}

OrderModel _order({
  required OrderStatus status,
  DateTime? createdAt,
  OrderSource source = OrderSource.cloud,
  int sequenceNo = 1,
  String orderNo = 'ORD-1',
  List<OrderItem> items = const [],
}) {
  final at = createdAt ?? DateTime.now();
  return OrderModel(
    id: 'order-$sequenceNo-${status.name}-${at.millisecondsSinceEpoch}',
    orderNo: orderNo,
    status: status,
    source: source,
    total: 220,
    items: items,
    sequenceNo: sequenceNo,
    createdAt: at,
    updatedAt: at,
  );
}

OrderItem _line(String name, {String nameBn = ''}) {
  return OrderItem(
    id: 'line-$name',
    orderId: 'order',
    menuItemId: 'menu',
    name: name,
    nameEn: name,
    nameBn: nameBn,
    qty: 1,
    price: 220,
    lineTotal: 220,
  );
}

void _markOnline(PosAppController controller) {
  controller.cloudConfig = CloudConfig(
    baseUrl: 'https://example.com',
    enabled: true,
    deviceToken: 'token',
    autoSyncIntervalSeconds: 30,
  );
  controller.serverConfig = ServerConfig(
    serverId: 'server',
    restaurantId: 'restaurant',
    outletId: 'outlet',
    restaurantName: 'Scan Cafe',
    outletName: 'Main',
  );
  controller.syncState = SyncRuntimeState(
    isSyncing: false,
    cloudConnected: true,
    pendingCount: 0,
    failedCount: 0,
    logs: const [],
  );
}

void main() {
  testWidgets('empty pending tab shows quiet order CTA', (tester) async {
    final controller = _controller()..menuItems = [_menuItem()];
    _markOnline(controller);

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));

    expect(find.text('Quiet for now'), findsOneWidget);
    expect(find.text('New order'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    expect(find.text('System Online & Connected'), findsNothing);
    expect(find.text('Customer Menu Link: Active'), findsNothing);

    controller.dispose();
  });

  testWidgets('create CTA disables when no menu items are available', (
    tester,
  ) async {
    final controller = _controller()..menuItems = [_menuItem(available: false)];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));

    expect(find.text('New order'), findsOneWidget);
    expect(
      find.text('Add available menu items before creating orders.'),
      findsOneWidget,
    );

    controller.dispose();
  });

  testWidgets('empty state can clear active filters', (tester) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final controller = _controller()
      ..menuItems = [_menuItem()]
      ..orders = [_order(status: OrderStatus.pending, createdAt: yesterday)];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('today'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('Clear filters'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Clear filters'), findsNothing);
    expect(find.text('#1'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('empty completed tab does not link to ongoing orders', (
    tester,
  ) async {
    final controller = _controller()
      ..menuItems = [_menuItem()]
      ..orders = [_order(status: OrderStatus.accepted)];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('View ongoing orders instead'), findsNothing);
    expect(find.text('New order'), findsOneWidget);
    expect(find.byTooltip('New order'), findsOneWidget);
    expect(
      tester
          .getRect(find.text('New order'))
          .overlaps(tester.getRect(find.byTooltip('New order'))),
      isFalse,
    );

    controller.dispose();
  });

  testWidgets('empty state hides connection diagnostics', (tester) async {
    final controller = _controller()..menuItems = [_menuItem()];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));

    expect(find.text('System connection needs attention'), findsNothing);
    expect(find.text('Customer Menu Link: Not ready'), findsNothing);

    controller.dispose();
  });

  testWidgets('order search matches numbers, Bengali digits, and item names', (
    tester,
  ) async {
    final controller = _controller()
      ..menuItems = [_menuItem()]
      ..orders = [
        _order(
          status: OrderStatus.pending,
          sequenceNo: 42,
          orderNo: 'ORD-42',
          items: [_line('Chicken Burger', nameBn: 'চিকেন বার্গার')],
        ),
        _order(
          status: OrderStatus.accepted,
          sequenceNo: 43,
          orderNo: 'ORD-43',
          items: [_line('Fish Curry', nameBn: 'মাছ কারি')],
        ),
      ];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.pumpAndSettle();

    // Search is collapsed behind a top-bar icon (v4.2); open it first.
    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'burger');
    await tester.pumpAndSettle();
    expect(find.text('#42'), findsOneWidget);
    expect(find.text('#43'), findsNothing);

    await tester.enterText(find.byType(TextField).first, '৪২');
    await tester.pumpAndSettle();
    expect(find.text('#42'), findsOneWidget);

    // Both pending (#42) and accepted (#43) now share the Ongoing tab, so the
    // search filters within it — no tab switch needed.
    await tester.enterText(find.byType(TextField).first, 'fish');
    await tester.pumpAndSettle();
    expect(find.text('#43'), findsOneWidget);
    expect(find.text('#42'), findsNothing);

    controller.dispose();
  });
}
