import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/enums/business_tier.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/core/widgets/menu_image_view.dart';
import 'package:local_pos/src/features/dashboard/dashboard_screen.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_item.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_payment_method.dart';
import 'package:local_pos/src/models/order_service_type.dart';
import 'package:local_pos/src/models/order_source.dart';
import 'package:local_pos/src/models/order_status.dart';
import 'package:local_pos/src/services/printer_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  int createManualOrderCalls = 0;
  int printTicketCalls = 0;
  int printInvoiceCalls = 0;

  @override
  bool get orderPrinterSideEffectsEnabled => false;

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
    createManualOrderCalls++;
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

  @override
  Future<bool> printOrderTicket(OrderModel order) async {
    printTicketCalls++;
    return true;
  }

  @override
  Future<bool> printCustomerInvoice(OrderModel order) async {
    printInvoiceCalls++;
    return true;
  }
}

class _ReviewSyncController extends PosAppController {
  int syncNowCalls = 0;
  int refreshDashboardSummaryCalls = 0;

  @override
  Future<bool> syncNow() async {
    syncNowCalls++;
    return true;
  }

  @override
  Future<void> refreshDashboardSummary() async {
    refreshDashboardSummaryCalls++;
  }
}

void main() {
  testWidgets('dashboard manager FAB opens the new order flow', (tester) async {
    final controller = _OrderFlowController()
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
      ..menuItems = [item]
      ..printerState = PrinterRuntimeState(
        autoPrintEnabled: false,
        connected: true,
        busy: false,
        selectedPrinterName: 'Kitchen printer',
        selectedPrinterAddress: '00:11:22:33',
      );

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
    expect(find.text('KOT'), findsOneWidget);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Burger'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(controller.orderPrinterSideEffectsEnabled, isFalse);
    expect(controller.printTicketCalls, 0);

    controller.dispose();
  });

  testWidgets(
    'new order add items defaults to compact grid and toggles layout',
    (tester) async {
      final controller = PosAppController()
        ..language = AppLanguage.en
        ..menuItems = [_menuItem()];

      await tester.pumpWidget(
        _scoped(controller, DashboardScreen(onNavigate: (_) {})),
      );

      await tester.tap(find.byTooltip('New order'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Parcel').first);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      final compact = tester.widget<GridView>(find.byType(GridView));
      final compactDelegate = compact.gridDelegate;
      expect(compactDelegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
      expect(
        (compactDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        4,
      );

      await tester.tap(find.byTooltip('Large tiles'));
      await tester.pumpAndSettle();

      final large = tester.widget<GridView>(find.byType(GridView));
      expect(
        large.gridDelegate,
        isA<SliverGridDelegateWithMaxCrossAxisExtent>(),
      );

      await tester.tap(find.byTooltip('Compact grid'));
      await tester.pumpAndSettle();

      final compactAgain = tester.widget<GridView>(find.byType(GridView));
      expect(
        compactAgain.gridDelegate,
        isA<SliverGridDelegateWithFixedCrossAxisCount>(),
      );

      controller.dispose();
    },
  );

  testWidgets('simple dashboard ring tile builds an inline cart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _OrderFlowController()
      ..language = AppLanguage.en
      ..businessTier = BusinessTier.simple
      ..menuItems = [_menuItem()];
    controller.serverConfig = controller.serverConfig.copyWith(
      restaurantName: 'Helium',
    );

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    expect(find.text('Helium'), findsOneWidget);
    expect(find.text('FoodCart'), findsOneWidget);
    expect(find.text('FOODCART'), findsNothing);
    expect(find.text('EN'), findsNothing);
    expect(find.byType(MenuImageView), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ring-it-up-Burger')));
    await tester.pump();

    expect(find.byKey(const ValueKey('ring-it-up-cart')), findsOneWidget);
    expect(find.text('Create order'), findsOneWidget);
    expect(find.text('1 ITEMS · CURRENT ORDER'), findsOneWidget);
    expect(find.text('Burger ×1'), findsOneWidget);
    expect(find.text('Review order'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('ring-it-up-cart')));
    await tester.pumpAndSettle();

    expect(controller.createManualOrderCalls, 1);
    expect(find.text('Order created'), findsWidgets);
    expect(find.text('KOT'), findsOneWidget);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.byKey(const ValueKey('ring-it-up-cart')), findsNothing);
    expect(find.text('Review order'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('created-order-kot')));
    await tester.pumpAndSettle();
    expect(controller.printTicketCalls, 1);

    await tester.tap(find.byKey(const ValueKey('created-order-receipt')));
    await tester.pumpAndSettle();
    expect(controller.printInvoiceCalls, 1);

    controller.dispose();
  });

  testWidgets('review sync defaults on and syncs again when re-enabled', (
    tester,
  ) async {
    final controller = _ReviewSyncController()..language = AppLanguage.en;

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    await tester.tap(find.byKey(const ValueKey('dashboard-view-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owner').last);
    await tester.pumpAndSettle();

    expect(controller.syncNowCalls, 1);
    expect(
      tester.widget<Switch>(find.byKey(const ValueKey('review-auto-sync'))).value,
      isTrue,
    );

    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(controller.syncNowCalls, 2);

    await tester.tap(find.byKey(const ValueKey('review-auto-sync')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 1));
    await tester.pumpAndSettle();
    expect(controller.syncNowCalls, 2);

    await tester.tap(find.byKey(const ValueKey('review-auto-sync')));
    await tester.pumpAndSettle();

    expect(controller.syncNowCalls, 3);

    await tester.tap(find.byKey(const ValueKey('review-sync-now')));
    await tester.pumpAndSettle();
    expect(controller.syncNowCalls, 4);

    controller.dispose();
  });
}
