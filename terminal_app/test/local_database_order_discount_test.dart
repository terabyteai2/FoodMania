import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_item.dart';
import 'package:local_pos/src/services/local_database_service.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.path);

  final String path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;
}

MenuItem _menuItem({double price = 100}) {
  final now = DateTime(2026, 6, 13, 12);
  return MenuItem(
    id: 'menu-1',
    name: 'Rice bowl',
    description: 'Test item',
    category: 'Mains',
    price: price,
    isAvailable: true,
    createdAt: now,
    updatedAt: now,
  );
}

OrderRequestItem _request({int qty = 1}) {
  return OrderRequestItem(menuItemId: 'menu-1', qty: qty);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('local-pos-test-');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<LocalDatabaseService> seededDb({double price = 100}) async {
    final db = LocalDatabaseService();
    await db.initialize(tenantKey: 'discount-test');
    await db.upsertMenuItem(_menuItem(price: price), createSyncEvent: false);
    return db;
  }

  test('flat discount reduces created order total', () async {
    final db = await seededDb();
    addTearDown(db.close);

    final order = await db.createOrder(
      requestedItems: [_request()],
      discountLabel: 'Staff 10',
      discountAmount: 10,
      createSyncEvent: false,
    );

    expect(order.subtotal, 100);
    expect(order.discountLabel, 'Staff 10');
    expect(order.discountAmount, 10);
    expect(order.total, 90);
  });

  test('discount is clamped so total never goes below zero', () async {
    final db = await seededDb();
    addTearDown(db.close);

    final order = await db.createOrder(
      requestedItems: [_request()],
      discountLabel: 'Comp',
      discountAmount: 500,
      createSyncEvent: false,
    );

    expect(order.discountAmount, 100);
    expect(order.total, 0);
  });

  test('zero discount behaves as a normal order', () async {
    final db = await seededDb();
    addTearDown(db.close);

    final order = await db.createOrder(
      requestedItems: [_request(qty: 2)],
      discountLabel: 'Ignored',
      discountAmount: 0,
      createSyncEvent: false,
    );

    expect(order.subtotal, 200);
    expect(order.discountLabel, isNull);
    expect(order.discountAmount, 0);
    expect(order.total, 200);
  });

  test('delivery charge and discount calculate together', () async {
    final db = await seededDb();
    addTearDown(db.close);

    final order = await db.createOrder(
      requestedItems: [_request()],
      deliveryCharge: 30,
      discountLabel: 'Delivery promo',
      discountAmount: 20,
      createSyncEvent: false,
    );

    expect(order.subtotal, 100);
    expect(order.deliveryCharge, 30);
    expect(order.discountAmount, 20);
    expect(order.total, 110);
  });
}
