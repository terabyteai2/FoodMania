import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/core/widgets/tf_design_system.dart';
import 'package:local_pos/src/features/orders/order_list_filters.dart';
import 'package:local_pos/src/features/orders/orders_screen.dart';
import 'package:local_pos/src/models/account_role.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_source.dart';
import 'package:local_pos/src/models/order_status.dart';
import 'package:local_pos/src/models/server_config.dart';

Widget _scoped(PosAppController controller, Widget child) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

PosAppController _controller() => PosAppController()..language = AppLanguage.en;

OrderModel _completed({
  required DateTime createdAt,
  int sequenceNo = 1,
}) {
  return OrderModel(
    id: 'order-$sequenceNo-${createdAt.millisecondsSinceEpoch}',
    orderNo: 'ORD-$sequenceNo',
    status: OrderStatus.served,
    source: OrderSource.cloud,
    total: 220,
    items: const [],
    sequenceNo: sequenceNo,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

ServerConfig _config({bool shiftEnabled = false, int? shiftStartMinute, int? shiftEndMinute}) {
  return ServerConfig(
    serverId: 'server',
    restaurantId: 'restaurant',
    outletId: 'outlet',
    restaurantName: 'Scan Cafe',
    outletName: 'Main',
    shiftHoursEnabled: shiftEnabled,
    shiftStartMinute: shiftStartMinute,
    shiftEndMinute: shiftEndMinute,
  );
}

Finder _tabBadge(String digit) => find.descendant(
      of: find.byType(TfTabs),
      matching: find.text(digit),
    );

void main() {
  testWidgets('completed tab defaults to today without shift configured', (
    tester,
  ) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final yesterday = today.subtract(const Duration(days: 1));
    final controller = _controller()
      ..serverConfig = _config()
      ..orders = [
        _completed(createdAt: today, sequenceNo: 1),
        _completed(createdAt: yesterday, sequenceNo: 2),
      ];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('#W1'), findsOneWidget);
    expect(find.text('#W2'), findsNothing);
    // Badge shows the shift-scoped count, not the total.
    expect(_tabBadge('1'), findsOneWidget);
    expect(_tabBadge('2'), findsNothing);
    expect(find.text('See all'), findsOneWidget);

    // Lifting the scope shows every completed order.
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.text('#W1'), findsOneWidget);
    expect(find.text('#W2'), findsOneWidget);
    expect(find.text('All completed orders'), findsOneWidget);
    expect(_tabBadge('2'), findsOneWidget);

    // And back to the shift.
    await tester.tap(find.text('Current shift'));
    await tester.pumpAndSettle();

    expect(find.text('#W1'), findsOneWidget);
    expect(find.text('#W2'), findsNothing);
    expect(_tabBadge('1'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('shift hours wrap past midnight and anchor the running shift', (
    tester,
  ) async {
    final bounds = OrderListFilters.shiftBoundsFor(
      DateTime.now(),
      startMinute: 10 * 60,
      endMinute: 2 * 60,
    );
    final inShift = bounds.startInclusive!.add(const Duration(minutes: 1));
    final beforeShift = bounds.startInclusive!.subtract(
      const Duration(minutes: 1),
    );
    final controller = _controller()
      ..serverConfig = _config(shiftEnabled: true, shiftStartMinute: 10 * 60, shiftEndMinute: 2 * 60)
      ..orders = [
        _completed(createdAt: inShift, sequenceNo: 1),
        _completed(createdAt: beforeShift, sequenceNo: 2),
      ];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('#W1'), findsOneWidget);
    expect(find.text('#W2'), findsNothing);
    expect(_tabBadge('1'), findsOneWidget);

    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.text('#W1'), findsOneWidget);
    expect(find.text('#W2'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('empty current shift offers a See all shortcut', (tester) async {
    // Place the only completed order well before the running shift's start so
    // it is outside the scope at any hour of day the suite runs.
    final bounds = OrderListFilters.shiftBoundsFor(
      DateTime.now(),
      startMinute: 10 * 60,
      endMinute: 2 * 60,
    );
    final outOfShift = bounds.startInclusive!.subtract(
      const Duration(hours: 3),
    );
    final controller = _controller()
      ..serverConfig = _config(shiftEnabled: true, shiftStartMinute: 10 * 60, shiftEndMinute: 2 * 60)
      ..orders = [_completed(createdAt: outOfShift, sequenceNo: 7)];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    // The pinned See-all CTA stays hidden for the empty state; the empty
    // state itself carries the shortcut instead.
    expect(find.text('No completed orders in this shift yet.'), findsOneWidget);
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();

    expect(find.text('#W7'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('owner date range takes over the shift scope and back', (
    tester,
  ) async {
    // A 24h shift anchored on today keeps the fixtures deterministic at any
    // run hour: today noon is inside, yesterday noon is outside.
    final now = DateTime.now();
    final todayNoon = DateTime(now.year, now.month, now.day, 12);
    final yesterday = todayNoon.subtract(const Duration(days: 1));
    final controller = _controller()
      ..realAccountRole = AccountRole.owner
      ..serverConfig = _config(shiftEnabled: true, shiftStartMinute: 0, shiftEndMinute: 0)
      ..orders = [
        _completed(createdAt: todayNoon, sequenceNo: 1),
        _completed(createdAt: yesterday, sequenceNo: 2),
      ];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('#W1'), findsOneWidget);
    expect(find.text('#W2'), findsNothing);

    // Picking "yesterday" hands the completed tab to the date range.
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yesterday'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('#W2'), findsOneWidget);
    expect(find.text('#W1'), findsNothing);
    expect(find.text('All completed orders'), findsOneWidget);

    // Back to "all time" returns to the shift scope.
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All time'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(find.text('#W1'), findsOneWidget);
    expect(find.text('#W2'), findsNothing);
    expect(find.text('All completed orders'), findsNothing);

    controller.dispose();
  });

  testWidgets('switching to Ongoing returns Completed to the shift scope', (
    tester,
  ) async {
    final now = DateTime.now();
    final todayNoon = DateTime(now.year, now.month, now.day, 12);
    final yesterday = todayNoon.subtract(const Duration(days: 1));
    final controller = _controller()
      ..serverConfig = _config()
      ..orders = [
        _completed(createdAt: todayNoon, sequenceNo: 1),
        _completed(createdAt: yesterday, sequenceNo: 2),
      ];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See all'));
    await tester.pumpAndSettle();
    expect(find.text('#W2'), findsOneWidget);

    await tester.tap(find.text('Ongoing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    // Leaving the tab reset the lifted scope; back is shift-scoped again.
    expect(find.text('#W2'), findsNothing);
    expect(find.text('#W1'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('disabled shift mode shows today scope regardless of '
      'configured hours',
      (tester) async {
    final now = DateTime.now();
    final todayNoon = DateTime(now.year, now.month, now.day, 12);
    final yesterday = todayNoon.subtract(const Duration(days: 1));
    final controller = _controller()
      ..serverConfig = _config(
        shiftStartMinute: 10 * 60,
        shiftEndMinute: 2 * 60,
      ) // shiftEnabled defaults to false
      ..orders = [
        _completed(createdAt: todayNoon, sequenceNo: 1),
        _completed(createdAt: yesterday, sequenceNo: 2),
      ];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    // Disabled mode falls back to calendar-today scope.
    expect(find.text('#W1'), findsOneWidget);
    expect(find.text('#W2'), findsNothing);

    controller.dispose();
  });

  testWidgets('completed headers follow the shift day', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    final now = DateTime.now();
    final bounds = OrderListFilters.shiftBoundsFor(
      now,
      startMinute: 10 * 60,
      endMinute: 2 * 60,
    );
    final lateNight = bounds.endExclusive!.subtract(
      const Duration(minutes: 60),
    );
    final controller = _controller()
      ..serverConfig = _config(
        shiftEnabled: true,
        shiftStartMinute: 10 * 60,
        shiftEndMinute: 2 * 60,
      )
      ..orders = [
        _completed(createdAt: lateNight, sequenceNo: 1),
      ];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    final headerDate = OrderListFilters.shiftDayFor(
      lateNight,
      10 * 60,
    );
    expect(
      find.text(AppStrings.of(AppLanguage.en).formatDateHeader(headerDate)),
      findsOneWidget,
    );

    controller.dispose();
  });

  test('metrics today totals follow the shift window only when enabled', () {
    final bounds = OrderListFilters.shiftBoundsFor(
      DateTime.now(),
      startMinute: 10 * 60,
      endMinute: 2 * 60,
    );
    final lateNight = bounds.endExclusive!.subtract(
      const Duration(minutes: 30),
    );
    final earlyMorning = bounds.startInclusive!.subtract(
      const Duration(minutes: 1),
    );
    final controller = _controller()
      ..serverConfig = _config(
        shiftEnabled: true,
        shiftStartMinute: 10 * 60,
        shiftEndMinute: 2 * 60,
      )
      ..orders = [
        _completed(createdAt: lateNight, sequenceNo: 1),
        _completed(createdAt: earlyMorning, sequenceNo: 2),
      ];

    // lateNight falls inside the shift window; earlyMorning does not.
    expect(controller.metrics.todayOrders, 1);
    expect(controller.metrics.totalSales, 220);

    // With shift disabled both orders are scored against calendar-today.
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final calendarCount = controller.orders
        .where((o) => !o.createdAt.isBefore(todayStart))
        .length;
    controller.serverConfig = _config(
      shiftStartMinute: 10 * 60,
      shiftEndMinute: 2 * 60,
    ); // disabled
    expect(controller.metrics.todayOrders, calendarCount);
    expect(controller.metrics.totalSales, 220 * 2);

    controller.dispose();
  });
}