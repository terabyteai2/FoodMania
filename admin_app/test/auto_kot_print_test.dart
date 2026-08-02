import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_item.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_source.dart';
import 'package:local_pos/src/models/order_status.dart';
import 'package:local_pos/src/services/local_database_service.dart';
import 'package:local_pos/src/services/printer_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// PrinterService stub that never touches platform channels. The auto-print
/// gate is [preflightBlockReason]; a successful print just records the id.
class _FakePrinterService extends PrinterService {
  final StreamController<PrinterRuntimeState> _stream =
      StreamController<PrinterRuntimeState>.broadcast();

  PrinterRuntimeState current = PrinterRuntimeState(
    autoPrintEnabled: true,
    connected: false,
    busy: false,
  );

  String? preflightReason;
  int preflightCalls = 0;
  final Set<String> printed = <String>{};

  @override
  Stream<PrinterRuntimeState> get stateStream => _stream.stream;

  @override
  PrinterRuntimeState get state => current;

  void emitConnected() {
    current = current.copyWith(connected: true);
    _stream.add(current);
  }

  @override
  Future<String?> preflightBlockReason() async {
    preflightCalls++;
    return preflightReason;
  }

  @override
  bool hasPrintedOrder(String orderId) => printed.contains(orderId);

  @override
  Future<void> setAutoPrintEnabled(bool value) async {
    current = current.copyWith(autoPrintEnabled: value, clearLastError: true);
  }

  @override
  Future<bool> printOrderTicket(
    OrderModel order, {
    required String restaurantName,
    required String outletName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    AppLanguage language = AppLanguage.en,
    bool markAsPrinted = true,
    String? orderDetailsUrl,
    String? serverName,
  }) async {
    printed.add(order.id);
    return true;
  }
}

class _Harness {
  _Harness(this.db, this.controller, this.printer);

  final LocalDatabaseService db;
  final PosAppController controller;
  final _FakePrinterService printer;

  static Future<_Harness> create() async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall call) async {
        switch (call.method) {
          case 'getApplicationDocumentsDirectory':
          case 'getApplicationSupportDirectory':
          case 'getTemporaryDirectory':
            final dir = await Directory.systemTemp.createTemp('local_pos_test');
            return dir.path;
        }
        return null;
      },
    );
    SharedPreferences.setMockInitialValues({});
    final db = LocalDatabaseService();
    await db.initialize(
      tenantKey: 'auto_kot_print_${DateTime.now().microsecondsSinceEpoch}',
    );
    final printer = _FakePrinterService();
    final controller = PosAppController(database: db, printerService: printer);
    await controller.initialize();
    await db.upsertMenuItem(
      MenuItem(
        id: 'm-1',
        name: 'Test Burger',
        description: '',
        category: '',
        price: 100,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
      createSyncEvent: false,
    );
    return _Harness(db, controller, printer);
  }

  Future<OrderModel> createAcceptedOrder() {
    return db.createOrder(
      requestedItems: [OrderRequestItem(menuItemId: 'm-1', qty: 1)],
      source: OrderSource.cloud,
      createdByRole: 'waiter',
      initialStatus: OrderStatus.accepted,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // The database-change listener debounces for 400ms before running the
  // alert/auto-print pipeline; give it comfortable real-time slack.
  Future<void> settlePipeline() =>
      Future<void>.delayed(const Duration(milliseconds: 900));

  test('auto-print fires on accept when the toggle is ON and printer ready',
      () async {
    final h = await _Harness.create();
    final order = await h.createAcceptedOrder();

    await settlePipeline();

    expect(h.printer.printed, contains(order.id));
    expect(h.printer.preflightCalls, greaterThanOrEqualTo(1));
  });

  test('toggle OFF suppresses auto-print entirely', () async {
    final h = await _Harness.create();
    await h.controller.setAutoPrintOrders(false);
    expect(h.controller.printerState.autoPrintEnabled, isFalse);

    final order = await h.createAcceptedOrder();
    await settlePipeline();

    expect(h.printer.printed, isEmpty);
    expect(h.controller.needsKotPrint(order), isTrue);
  });

  test(
      'blocked attempt queues the KOT; retry drains it once the printer is '
      'reachable', () async {
    final h = await _Harness.create();
    h.printer.preflightReason = 'Turn on Bluetooth first.';

    final order = await h.createAcceptedOrder();
    await settlePipeline();

    expect(h.printer.printed, isEmpty);
    expect(h.controller.needsKotPrint(order), isTrue);

    // Printer becomes reachable → connection emit triggers the retry.
    h.printer.preflightReason = null;
    h.printer.emitConnected();
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(h.printer.printed, contains(order.id));
    expect(h.controller.needsKotPrint(order), isFalse);
  });

  test('turning the toggle ON retries orders queued while it was blocked',
      () async {
    final h = await _Harness.create();
    h.printer.preflightReason = 'Turn on Bluetooth first.';

    final order = await h.createAcceptedOrder();
    await settlePipeline();
    expect(h.printer.printed, isEmpty);
    expect(h.controller.needsKotPrint(order), isTrue);

    h.printer.preflightReason = null;
    await h.controller.setAutoPrintOrders(true);
    await Future<void>.delayed(const Duration(milliseconds: 300));

    expect(h.printer.printed, contains(order.id));
    expect(h.controller.needsKotPrint(order), isFalse);
  });
}
