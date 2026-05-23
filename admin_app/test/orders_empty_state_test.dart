import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/orders/orders_screen.dart';
import 'package:local_pos/src/models/menu_item.dart';
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
}) {
  final at = createdAt ?? DateTime.now();
  return OrderModel(
    id: 'order-${status.name}-${at.millisecondsSinceEpoch}',
    orderNo: 'ORD-1',
    status: status,
    source: source,
    total: 220,
    items: const [],
    sequenceNo: 1,
    createdAt: at,
    updatedAt: at,
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

  testWidgets('empty pending tab links to accepted orders when available', (
    tester,
  ) async {
    final controller = _controller()
      ..menuItems = [_menuItem()]
      ..orders = [_order(status: OrderStatus.accepted)];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pending'));
    await tester.pumpAndSettle();

    expect(find.text('View accepted orders instead'), findsOneWidget);
    await tester.tap(find.text('View accepted orders instead'));
    await tester.pumpAndSettle();

    expect(find.text('#1'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('empty state hides connection diagnostics', (tester) async {
    final controller = _controller()..menuItems = [_menuItem()];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));

    expect(find.text('System connection needs attention'), findsNothing);
    expect(find.text('Customer Menu Link: Not ready'), findsNothing);

    controller.dispose();
  });
}
