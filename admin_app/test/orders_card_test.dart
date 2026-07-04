import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/core/widgets/tf_design_system.dart';
import 'package:local_pos/src/features/orders/orders_screen.dart';
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

PosAppController _controller() => PosAppController()..language = AppLanguage.en;

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

OrderItem _line(String name, {int qty = 1, double lineTotal = 220}) {
  return OrderItem(
    id: 'line-$name',
    orderId: 'order',
    menuItemId: 'menu',
    name: name,
    nameEn: name,
    nameBn: '',
    qty: qty,
    price: 220,
    lineTotal: lineTotal,
  );
}

OrderModel _order({
  required OrderStatus status,
  DateTime? createdAt,
  int sequenceNo = 1,
  List<OrderItem> items = const [],
  OrderPaymentMethod? paymentMethod,
  OrderServiceType? serviceType,
  String? tableNo,
  String? createdByRole,
  String? discountLabel,
  double discountAmount = 0,
  double total = 220,
}) {
  final at = createdAt ?? DateTime.now();
  return OrderModel(
    id: 'order-$sequenceNo-${status.name}',
    orderNo: 'ORD-$sequenceNo',
    status: status,
    source: OrderSource.manual,
    total: total,
    items: items,
    sequenceNo: sequenceNo,
    paymentMethod: paymentMethod,
    serviceType: serviceType,
    tableNo: tableNo,
    createdByRole: createdByRole,
    discountLabel: discountLabel,
    discountAmount: discountAmount,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  testWidgets('completed card renders the owner record anatomy', (
    tester,
  ) async {
    final controller = _controller()
      ..menuItems = [_menuItem()]
      ..orders = [
        _order(
          status: OrderStatus.completed,
          createdAt: DateTime(2026, 7, 4, 18, 35),
          sequenceNo: 7,
          items: [
            _line('Chicken Burger', qty: 2, lineTotal: 440),
            _line('Fresh Water', qty: 1, lineTotal: 20),
          ],
          paymentMethod: OrderPaymentMethod.cash,
          tableNo: '4',
          createdByRole: 'waiter',
          total: 460,
        ),
      ];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    // Header: serial + Completed pill + time-of-day from createdAt.
    expect(find.text('#7'), findsOneWidget);
    expect(find.text('6:35 PM'), findsOneWidget);
    // Per-line amounts + qty gutter.
    expect(find.text('2×'), findsOneWidget);
    expect(find.text('৳440'), findsOneWidget);
    expect(find.text('৳20'), findsOneWidget);
    // Total block; no Discount row when discountAmount == 0.
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('৳460'), findsOneWidget);
    expect(find.textContaining('Discount'), findsNothing);
    // Meta line: payment · type · by role.
    expect(find.text('Cash · Table 4 · by Waiter'), findsOneWidget);
    // Owner record is full-clarity — the old 0.82 dim is gone.
    expect(
      find.byWidgetPredicate((w) => w is Opacity && w.opacity == 0.82),
      findsNothing,
    );
    // No action buttons on completed cards.
    expect(find.text('KOT'), findsNothing);
    expect(find.text('Bill'), findsNothing);

    controller.dispose();
  });

  testWidgets('completed card shows a labeled discount row only when > 0', (
    tester,
  ) async {
    final controller = _controller()
      ..menuItems = [_menuItem()]
      ..orders = [
        _order(
          status: OrderStatus.completed,
          createdAt: DateTime(2026, 7, 4, 13, 5),
          items: [_line('Chicken Burger')],
          discountLabel: 'Iftar offer',
          discountAmount: 50,
          total: 170,
        ),
      ];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Iftar offer'), findsOneWidget);
    expect(find.text('−৳50'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('ongoing accepted card keeps compact actions and a live age', (
    tester,
  ) async {
    final controller = _controller()
      ..menuItems = [_menuItem()]
      ..orders = [
        _order(
          status: OrderStatus.accepted,
          createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
          items: [_line('Chicken Burger')],
        ),
      ];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.pumpAndSettle();

    expect(find.text('#1'), findsOneWidget);
    expect(find.text('10 min'), findsOneWidget);
    expect(find.text('KOT'), findsWidgets);
    expect(find.text('Bill'), findsOneWidget);
    // Compact sm buttons — never the old full-width md pair.
    final billButton = tester.widget<TfButton>(
      find.widgetWithText(TfButton, 'Bill'),
    );
    expect(billButton.size, TfButtonSize.sm);
    expect(billButton.fullWidth, isFalse);

    controller.dispose();
  });

  testWidgets('search collapses to an icon and clears on close', (
    tester,
  ) async {
    final controller = _controller()..menuItems = [_menuItem()];

    await tester.pumpWidget(_scoped(controller, const OrdersScreen()));
    await tester.pumpAndSettle();

    // Collapsed by default.
    expect(find.byType(TfSearchField), findsNothing);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TfSearchField), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'burger');
    await tester.pumpAndSettle();
    expect(find.byType(TfSearchField), findsOneWidget);

    // The in-field ✕ clears the query and collapses the row.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TfSearchField), findsNothing);

    controller.dispose();
  });
}
