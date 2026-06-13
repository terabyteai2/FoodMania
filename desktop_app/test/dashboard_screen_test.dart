import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/enums/business_tier.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/dashboard/dashboard_screen.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/account_role.dart';
import 'package:local_pos/src/models/dashboard_summary.dart';
import 'package:local_pos/src/models/order_item.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_payment_method.dart';
import 'package:local_pos/src/models/order_service_type.dart';
import 'package:local_pos/src/models/order_source.dart';
import 'package:local_pos/src/models/order_status.dart';
import 'package:local_pos/src/services/printer_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _scoped(
  PosAppController controller,
  Widget child, {
  Locale locale = const Locale('en'),
}) {
  return AppScope(
    controller: controller,
    child: MaterialApp(locale: locale, theme: AppTheme.light(), home: child),
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

void main() {
  testWidgets('standard manage dashboard uses inline ring-up tray', (
    tester,
  ) async {
    final controller = _OrderFlowController()
      ..language = AppLanguage.en
      ..businessTier = BusinessTier.standard
      ..menuItems = [_menuItem()];

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    expect(find.byTooltip('New order'), findsOneWidget);
    expect(find.text('Quick sell · tap to ring up'), findsOneWidget);
    expect(find.byKey(const ValueKey('ring-it-up-Burger')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ring-it-up-Burger')));
    await tester.pump();

    expect(find.byKey(const ValueKey('ring-it-up-cart')), findsOneWidget);
    expect(find.text('Create order'), findsOneWidget);
    expect(find.text('1 ITEMS IN ORDER'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('quick sell editor saves local item selection', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fries = _menuItem().copyWith(id: 'menu-2', name: 'Fries', price: 140);
    final controller = _OrderFlowController()
      ..language = AppLanguage.en
      ..businessTier = BusinessTier.standard
      ..menuItems = [_menuItem(), fries];

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quick-sell-editor-page')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pump();
    await tester.tap(find.text('Save quick sell'));
    await tester.pumpAndSettle();

    expect(controller.quickSellMenuItemIds, ['menu-2']);
    controller.dispose();
  });

  testWidgets('inline create order keeps bill details visible', (tester) async {
    final item = _menuItem();
    final controller = _OrderFlowController()
      ..language = AppLanguage.en
      ..businessTier = BusinessTier.standard
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

    await tester.tap(find.byKey(const ValueKey('ring-it-up-Burger')));
    await tester.pump();
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

  testWidgets('manage ring-up grid is four-column and text first', (
    tester,
  ) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..businessTier = BusinessTier.standard
      ..menuItems = [_menuItem()];

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    final fourColumnGrids = find.byWidgetPredicate((widget) {
      if (widget is! GridView) return false;
      final delegate = widget.gridDelegate;
      return delegate is SliverGridDelegateWithFixedCrossAxisCount &&
          delegate.crossAxisCount == 4;
    }).evaluate();
    expect(fourColumnGrids, isNotEmpty);
    expect(find.byKey(const ValueKey('ring-it-up-Burger')), findsOneWidget);
    expect(find.byType(Image), findsWidgets);

    controller.dispose();
  });

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

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.textContaining('Helium'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('complexity-dial-dropdown')),
      findsOneWidget,
    );
    expect(find.text('EN'), findsNothing);
    expect(find.text('Quick sell · tap to ring up'), findsOneWidget);
    expect(find.text('TOTAL CASH'), findsOneWidget);
    expect(find.text('PEAK HOURS'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ring-it-up-Burger')));
    await tester.pump();

    expect(find.byKey(const ValueKey('ring-it-up-cart')), findsOneWidget);
    expect(find.text('Create order'), findsOneWidget);
    expect(find.text('1 ITEMS IN ORDER'), findsOneWidget);
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

  testWidgets('owner review relies on normal dashboard refresh', (
    tester,
  ) async {
    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    await tester.tap(find.byKey(const ValueKey('dashboard-view-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owner').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-auto-sync')), findsNothing);
    expect(find.byKey(const ValueKey('review-sync-now')), findsNothing);

    controller.dispose();
  });

  testWidgets('staff dashboard does not expose owner review switcher', (
    tester,
  ) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..accountRole = AccountRole.waiter;

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    expect(find.byKey(const ValueKey('dashboard-view-dropdown')), findsNothing);

    controller.dispose();
  });

  testWidgets(
    'standard dashboard renders cafe manage layout and floor states',
    (tester) async {
      final controller = PosAppController()
        ..language = AppLanguage.en
        ..businessTier = BusinessTier.standard
        ..menuItems = [_menuItem()]
        ..dashboardSummary = DashboardSummary.fromJson({
          'asOf': '2026-06-01T00:00:00Z',
          'moneyFirst': {},
          'rightNow': {
            'tablesSeated': 1,
            'tablesTotal': 2,
            'floorTables': [
              {'tableNo': '1', 'state': 'bill', 'covers': 3},
              {'tableNo': '2', 'state': 'idle', 'covers': 0},
            ],
          },
        });

      await tester.pumpWidget(
        _scoped(controller, DashboardScreen(onNavigate: (_) {})),
      );

      expect(find.text('Quick sell · tap to ring up'), findsOneWidget);
      expect(find.text('FOH counter'), findsNothing);
      expect(find.byKey(const ValueKey('ring-it-up-Burger')), findsOneWidget);
      expect(find.textContaining('open'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('BILL'),
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('BILL'), findsOneWidget);
      expect(find.text('IDLE'), findsWidgets);

      controller.dispose();
    },
  );

  testWidgets('restaurant mode renders the advanced dashboard', (tester) async {
    tester.view.physicalSize = const Size(360, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PosAppController()
      ..language = AppLanguage.en
      ..businessTier = BusinessTier.advanced
      ..menuItems = [_menuItem()]
      ..dashboardSummary = DashboardSummary.fromJson({
        'asOf': '2026-06-01T00:00:00Z',
        'moneyFirst': {},
        'rightNow': {},
      });

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    expect(controller.businessTier, BusinessTier.advanced);
    expect(find.textContaining('Restaurant'), findsWidgets);
    expect(find.text('Quick sell · tap to ring up'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('PENDING ORDERS'), findsOneWidget);
    expect(find.text('Floor'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });

  testWidgets(
    'restaurant dashboard renders with Bangla locale and no summary',
    (tester) async {
      tester.view.physicalSize = const Size(360, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final controller = PosAppController()
        ..language = AppLanguage.bn
        ..businessTier = BusinessTier.advanced;

      await tester.pumpWidget(
        _scoped(
          controller,
          DashboardScreen(onNavigate: (_) {}),
          locale: const Locale('bn'),
        ),
      );

      expect(find.textContaining('Restaurant'), findsWidgets);
      expect(tester.takeException(), isNull);

      controller.dispose();
    },
  );

  testWidgets('restaurant dashboard renders quick actions in the scroll view', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PosAppController()
      ..language = AppLanguage.en
      ..businessTier = BusinessTier.advanced
      ..menuItems = [_menuItem()]
      ..dashboardSummary = DashboardSummary.fromJson({
        'asOf': '2026-06-01T00:00:00Z',
        'moneyFirst': {},
        'rightNow': {},
      });

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );
    await tester.scrollUntilVisible(
      find.text('Print KOT'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Print KOT'), findsOneWidget);
    expect(find.text('Print bill'), findsOneWidget);
    expect(find.text('Call waiter'), findsOneWidget);
    expect(find.byTooltip('New order'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });

  testWidgets(
    'restaurant owner review tolerates missing low-margin food cost',
    (tester) async {
      final controller = PosAppController()
        ..language = AppLanguage.en
        ..businessTier = BusinessTier.advanced
        ..dashboardSummary = DashboardSummary.fromJson({
          'asOf': '2026-06-01T00:00:00Z',
          'moneyFirst': {},
          'rightNow': {},
          'review': {
            'itemsSold': [
              {
                'nameEn': 'Burger',
                'qty': 2,
                'salesBdt': 440,
                'lowMargin': true,
              },
            ],
          },
        });

      await tester.pumpWidget(
        _scoped(controller, DashboardScreen(onNavigate: (_) {})),
      );
      await tester.tap(find.byKey(const ValueKey('dashboard-view-dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Owner').last);
      await tester.pumpAndSettle();

      expect(find.text('MARGIN LOW'), findsOneWidget);
      expect(tester.takeException(), isNull);

      controller.dispose();
    },
  );

  testWidgets('enterprise dashboard renders derived fleet operations', (
    tester,
  ) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..businessTier = BusinessTier.enterprise
      ..dashboardSummary = DashboardSummary.fromJson({
        'asOf': '2026-06-01T00:00:00Z',
        'moneyFirst': {'earnedToday': 7500},
        'rightNow': {},
        'review': {
          'fleet': {
            'kpis': {
              'outletCount': 2,
              'covers': 18,
              'avgTicketBdt': 420,
              'fleetLatePct': 8,
            },
            'goal': {
              'targetBdt': 10000,
              'progressPct': 75,
              'remainingBdt': 2500,
            },
            'alerts': [
              {
                'kind': 'capacity',
                'title': 'Main is full',
                'body': '90% occupancy',
              },
            ],
            'outlets': [
              {'rank': 1, 'name': 'Main', 'occupancyPct': 90, 'latePct': 8},
            ],
            'benchmarks': {
              'bestAvgTicketOutlet': 'Main',
              'worstLateOutlet': 'Main',
            },
            'staffingSuggestion': {
              'outletName': 'Main',
              'peakLabel': '8:00 PM',
            },
            'openOutlets': ['Main'],
          },
        },
      });

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    expect(find.text('75% of goal'), findsOneWidget);
    expect(find.text('Needs you'), findsOneWidget);
    expect(find.text('Main is full'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Staffing'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Staffing'), findsOneWidget);
    expect(find.textContaining('Peak 8:00 PM'), findsOneWidget);
    expect(find.text('Top sellers · tap to add'), findsNothing);

    controller.dispose();
  });
}
