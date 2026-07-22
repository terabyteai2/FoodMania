import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/inventory_item.dart';
import '../models/inventory_supplier.dart';
import '../models/menu_item.dart';
import '../models/desktop_pos.dart';
import '../models/order_item.dart';
import '../models/order_model.dart';
import '../models/order_payment_method.dart';
import '../models/order_service_type.dart';
import '../models/order_source.dart';
import '../models/order_status.dart';
import '../models/pos_notification.dart';
import '../models/daily_stock_count.dart';
import '../models/stock_adjustment.dart';
import '../models/sync_event.dart';
import '../models/sync_status.dart';

/// Hard safety ceiling for [LocalDatabaseService.getOrders] when a caller
/// passes no `limit`. Well above the in-memory order cap (500) so paginated
/// reads are never truncated, but it prevents an accidental full-table load
/// from pulling thousands of orders (+ their items) into RAM at once.
const int kMaxOrdersQueryLimit = 1000;

class DatabaseValidationException implements Exception {
  DatabaseValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalDatabaseService {
  final Uuid _uuid = Uuid();
  final StreamController<void> _changeController =
      StreamController<void>.broadcast();

  Database? _database;
  // Identifies which tenant the currently-open database belongs to. Empty
  // means "no tenant scope yet" (fresh install / pre-login).
  String _activeTenantKey = '';

  Stream<void> get changes => _changeController.stream;

  String get activeTenantKey => _activeTenantKey;

  String _ordersDiagSummary(List<OrderModel> rows, {int sampleLimit = 5}) {
    final raw = <String, int>{};
    final admin = <String, int>{};
    for (final order in rows) {
      raw[order.status.name] = (raw[order.status.name] ?? 0) + 1;
      final adminStatus = order.status.adminStatus.name;
      admin[adminStatus] = (admin[adminStatus] ?? 0) + 1;
    }
    String format(Map<String, int> counts) {
      final keys = counts.keys.toList()..sort();
      return '{${keys.map((k) => '$k:${counts[k]}').join(', ')}}';
    }

    final sample = rows
        .take(sampleLimit)
        .map((order) {
          return '${order.id}#${order.sequenceNo}:'
              '${order.status.name}/${order.status.adminStatus.name} '
              '${order.source.name}/${order.serviceType?.name ?? 'none'} '
              '৳${order.total.toStringAsFixed(0)} '
              'c=${order.createdAt.toIso8601String()} '
              'u=${order.updatedAt.toIso8601String()}';
        })
        .join(' | ');
    return 'raw=${format(raw)} admin=${format(admin)} sample=$sample';
  }

  Future<void> initialize({String tenantKey = ''}) async {
    if (_database != null && _activeTenantKey == tenantKey) return;
    if (_database != null) {
      // Different tenant requested — close the current DB before opening the
      // tenant-specific one so SQLite doesn't keep stale handles around.
      await _database!.close();
      _database = null;
    }
    _activeTenantKey = tenantKey;
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final fileName = tenantKey.isEmpty
        ? 'local_pos.db'
        : 'local_pos_${_sanitizeKey(tenantKey)}.db';
    final databasePath = path.join(documentsDirectory.path, fileName);

    // Upgrade path: pre-multi-tenant builds wrote everything to local_pos.db.
    // Claim that file ONCE for the first tenant that logs in on this device.
    // Never copy it into a second restaurant's DB — that was causing another
    // outlet's menu/orders to appear in the admin app.
    if (tenantKey.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      const legacyClaimedKey = 'local_pos_legacy_db_claimed';
      final legacyAlreadyClaimed = prefs.getBool(legacyClaimedKey) ?? false;
      final tenantFile = File(databasePath);
      final legacyFile = File(
        path.join(documentsDirectory.path, 'local_pos.db'),
      );
      if (!legacyAlreadyClaimed &&
          !await tenantFile.exists() &&
          await legacyFile.exists()) {
        try {
          await legacyFile.rename(databasePath);
        } catch (_) {
          try {
            await legacyFile.copy(databasePath);
          } catch (_) {}
        }
        await prefs.setBool(legacyClaimedKey, true);
      }
    }

    _database = await openDatabase(
      databasePath,
      version: 17,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
      onOpen: _ensureSchema,
    );
  }

  /// Switch to a different tenant's database. Closes the currently-open
  /// connection and opens the file for the new tenant. Use this after a login
  /// or account switch so menu items, orders, etc. from a different tenant
  /// don't bleed into the current session.
  Future<void> switchTenant(String tenantKey) async {
    if (_database != null && _activeTenantKey == tenantKey) return;
    await initialize(tenantKey: tenantKey);
    _emitChange();
  }

  String _sanitizeKey(String key) {
    final trimmed = key.trim();
    // Keep only filename-safe characters; outletId is a UUID so this is
    // usually a no-op but defends against arbitrary inputs.
    return trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  Future<List<MenuItem>> getMenuItems({
    bool includeUnavailable = true,
    bool includeDeleted = false,
    int? limit,
    int? offset,
  }) async {
    final db = await _db;
    final where = <String>[];
    final whereArgs = <Object?>[];
    if (!includeUnavailable) {
      where.add('isAvailable = ?');
      whereArgs.add(1);
    }
    if (!includeDeleted) {
      where.add('deletedAt IS NULL');
    }
    final rows = await db.query(
      'menu_items',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'category COLLATE NOCASE ASC, name COLLATE NOCASE ASC',
      limit: limit,
      offset: offset,
    );
    return rows.map(MenuItem.fromMap).toList(growable: false);
  }

  Future<MenuItem?> getMenuItemById(
    String id, {
    bool includeDeleted = false,
  }) async {
    final db = await _db;
    final where = includeDeleted ? 'id = ?' : 'id = ? AND deletedAt IS NULL';
    final rows = await db.query(
      'menu_items',
      where: where,
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MenuItem.fromMap(rows.first);
  }

  Future<void> upsertMenuItem(
    MenuItem item, {
    bool createSyncEvent = true,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'menu_items',
        where: 'id = ?',
        whereArgs: [item.id],
        limit: 1,
      );
      final exists = existingRows.isNotEmpty;
      final model = item.copyWith(
        syncStatus: createSyncEvent ? SyncStatus.pending : item.syncStatus,
        version: exists
            ? (MenuItem.fromMap(existingRows.first).version + 1)
            : item.version,
      );
      await txn.insert(
        'menu_items',
        model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (createSyncEvent) {
        await _insertSyncEvent(
          txn,
          entityType: 'menu_item',
          entityId: model.id,
          action: exists ? 'update' : 'create',
          payload: model.toJson(),
        );
      }
    });
    _emitChange();
  }

  Future<MenuItem?> applyRemoteMenuItem(MenuItem item) async {
    final db = await _db;
    MenuItem? applied;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'menu_items',
        where: 'id = ?',
        whereArgs: [item.id],
        limit: 1,
      );
      final remote = item.copyWith(syncStatus: SyncStatus.synced);
      if (rows.isEmpty) {
        await txn.insert('menu_items', remote.toMap());
        applied = remote;
        return;
      }

      final current = MenuItem.fromMap(rows.first);
      if (_localVersionWins(current, remote.updatedAt)) return;

      await txn.insert(
        'menu_items',
        remote.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      applied = remote;
    });
    if (applied != null) _emitChange();
    return applied;
  }

  Future<void> deleteMenuItem(String id, {bool createSyncEvent = true}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'menu_items',
        where: 'id = ? AND deletedAt IS NULL',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final existing = MenuItem.fromMap(rows.first);
      final now = DateTime.now();
      final deleted = existing.copyWith(
        isAvailable: false,
        syncStatus: createSyncEvent ? SyncStatus.pending : existing.syncStatus,
        version: existing.version + 1,
        deletedAt: now,
        updatedAt: now,
      );
      await txn.update(
        'menu_items',
        deleted.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      if (createSyncEvent) {
        await _insertSyncEvent(
          txn,
          entityType: 'menu_item',
          entityId: id,
          action: 'delete',
          payload: deleted.toJson(),
        );
      }
    });
    _emitChange();
  }

  Future<MenuItem> toggleMenuAvailability(String id, bool isAvailable) async {
    final existing = await getMenuItemById(id);
    if (existing == null) {
      throw DatabaseValidationException('Menu item was not found.');
    }
    final updated = existing.copyWith(
      isAvailable: isAvailable,
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
    await upsertMenuItem(updated);
    return updated;
  }

  Future<MenuItem> toggleMenuFavorite(String id, bool isFavorite) async {
    final existing = await getMenuItemById(id);
    if (existing == null) {
      throw DatabaseValidationException('Menu item was not found.');
    }
    final updated = existing.copyWith(
      isFavorite: isFavorite,
      syncStatus: SyncStatus.pending,
      updatedAt: DateTime.now(),
    );
    await upsertMenuItem(updated);
    return updated;
  }

  Future<List<OrderModel>> getOrders({
    OrderStatus? status,
    OrderSource? source,
    int? limit,
    int? offset,
  }) async {
    final db = await _db;
    final where = <String>[];
    final whereArgs = <Object?>[];
    if (status != null) {
      where.add('status = ?');
      whereArgs.add(status.value);
    }
    if (source != null) {
      where.add('source = ?');
      whereArgs.add(source.value);
    }

    // Never run an unbounded query — a null limit falls back to a safe ceiling
    // so a caller can't accidentally load the entire orders table into memory.
    final effectiveLimit = limit ?? kMaxOrdersQueryLimit;
    final orderRows = await db.query(
      'orders',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'sequenceNo DESC, createdAt DESC',
      limit: effectiveLimit,
      offset: offset,
    );
    if (orderRows.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[QB-ORDERS-DIAG] sqlite getOrders returned=0 '
          'status=${status?.name} source=${source?.name} '
          'limit=$limit offset=$offset',
        );
      }
      return const <OrderModel>[];
    }

    final orderIds = <String>[for (final row in orderRows) row['id'] as String];
    final itemsByOrderId = await _getOrderItemsForIds(db, orderIds);
    final orders = [
      for (final row in orderRows)
        OrderModel.fromMap(
          row,
          items: itemsByOrderId[row['id'] as String] ?? const <OrderItem>[],
        ),
    ];
    if (kDebugMode) {
      debugPrint(
        '[QB-ORDERS-DIAG] sqlite getOrders returned=${orders.length} '
        'status=${status?.name} source=${source?.name} '
        'limit=$limit offset=$offset ${_ordersDiagSummary(orders)}',
      );
    }
    return orders;
  }

  Future<OrderModel?> getOrderById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final items = await _getOrderItems(id);
    return OrderModel.fromMap(rows.first, items: items);
  }

  Future<List<OrderModel>> getAcceptedOrdersOlderThan(
    DateTime cutoff, {
    int limit = 200,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'orders',
      where: 'status IN (?, ?, ?) AND updatedAt <= ?',
      whereArgs: [
        OrderStatus.accepted.value,
        OrderStatus.preparing.value,
        OrderStatus.ready.value,
        cutoff.toIso8601String(),
      ],
      orderBy: 'updatedAt ASC',
      limit: limit,
    );
    if (rows.isEmpty) return const <OrderModel>[];
    final orderIds = <String>[for (final row in rows) row['id'] as String];
    final itemsByOrderId = await _getOrderItemsForIds(db, orderIds);
    return [
      for (final row in rows)
        OrderModel.fromMap(
          row,
          items: itemsByOrderId[row['id'] as String] ?? const <OrderItem>[],
        ),
    ];
  }

  Future<OrderModel> createOrder({
    required List<OrderRequestItem> requestedItems,
    String? id,
    String? customerName,
    String? tableNo,
    String? note,
    String? deliveryAddress,
    String? mobileNumber,
    double deliveryCharge = 0,
    OrderServiceType? serviceType,
    int? covers,
    OrderPaymentMethod? paymentMethod,
    OrderSource source = OrderSource.cloud,
    String? createdByAccountId,
    String? createdByRole,
    String? shiftId,
    String? discountLabel,
    double discountAmount = 0,
    double serviceChargeRatePercent = 0,
    double serviceChargeAmount = 0,
    double vatRatePercent = 0,
    bool createSyncEvent = true,
    OrderStatus initialStatus = OrderStatus.pending,
  }) async {
    final requestedId = _cleanNullable(id);
    if (requestedId != null) {
      final existing = await getOrderById(requestedId);
      if (existing != null) return existing;
    }
    if (requestedItems.isEmpty) {
      throw DatabaseValidationException(
        'Order must contain at least one item.',
      );
    }

    final db = await _db;
    final order = await db.transaction<OrderModel>((txn) async {
      final now = DateTime.now();
      final orderId = requestedId ?? _uuid.v4();
      final orderItems = <OrderItem>[];
      var subtotal = 0.0;

      for (final requestItem in requestedItems) {
        if (requestItem.qty <= 0) {
          throw DatabaseValidationException(
            'Item quantity must be greater than zero.',
          );
        }

        final menuRows = await txn.query(
          'menu_items',
          where: 'id = ? AND deletedAt IS NULL',
          whereArgs: [requestItem.menuItemId],
          limit: 1,
        );
        if (menuRows.isEmpty) {
          throw DatabaseValidationException(
            'Menu item ${requestItem.menuItemId} was not found.',
          );
        }

        final menuItem = MenuItem.fromMap(menuRows.first);
        if (!menuItem.isAvailable) {
          throw DatabaseValidationException(
            '${menuItem.name} is currently unavailable.',
          );
        }

        final unitPrice = _requestUnitPrice(requestItem, menuItem);
        final lineTotal = _roundMoney(unitPrice * requestItem.qty);
        subtotal += lineTotal;
        orderItems.add(
          OrderItem(
            id: _uuid.v4(),
            orderId: orderId,
            menuItemId: menuItem.id,
            name: _requestName(
              base: menuItem.name,
              suffix: requestItem.nameSuffix,
              override: requestItem.nameOverride,
            ),
            nameEn: _requestName(
              base: menuItem.nameEn,
              suffix: requestItem.nameSuffix,
              override: requestItem.nameEnOverride,
              appendSuffixToEmptyBase: false,
            ),
            nameBn: _requestName(
              base: menuItem.nameBn,
              suffix: requestItem.nameSuffix,
              override: requestItem.nameBnOverride,
              appendSuffixToEmptyBase: false,
            ),
            qty: requestItem.qty,
            price: unitPrice,
            lineTotal: lineTotal,
            costPriceSnapshot: menuItem.costPrice ?? 0,
            note: _cleanNullable(requestItem.note),
          ),
        );
      }

      final roundedSubtotal = _roundMoney(subtotal);
      final cleanVatRate = vatRatePercent.clamp(0, 100).toDouble();
      final vatAmount = _roundMoney(roundedSubtotal * cleanVatRate / 100);
      final cleanDeliveryCharge = _roundMoney(
        deliveryCharge.clamp(0, 100000).toDouble(),
      );
      final total = _roundMoney(
        roundedSubtotal + vatAmount + cleanDeliveryCharge + serviceChargeAmount,
      );

      final model = OrderModel(
        id: orderId,
        orderNo: _buildOrderNumber(now),
        sequenceNo: await _nextOrderSequence(
          txn,
          source: source,
          createdByRole: createdByRole,
        ),
        orderDate: DateTime.now(),
        customerName: _cleanNullable(customerName),
        tableNo: _cleanNullable(tableNo),
        note: _cleanNullable(note),
        deliveryAddress: _cleanNullable(deliveryAddress),
        mobileNumber: _cleanNullable(mobileNumber),
        createdByAccountId: _cleanNullable(createdByAccountId),
        createdByRole: _cleanNullable(createdByRole),
        shiftId: _cleanNullable(shiftId),
        discountLabel: _cleanNullable(discountLabel),
        discountAmount: _roundMoney(discountAmount),
        serviceChargeRatePercent: _roundMoney(serviceChargeRatePercent),
        serviceChargeAmount: _roundMoney(serviceChargeAmount),
        serviceType: serviceType,
        covers: covers?.clamp(1, 999).toInt(),
        paymentMethod: paymentMethod,
        source: source,
        status: initialStatus,
        subtotal: roundedSubtotal,
        vatRatePercent: cleanVatRate,
        vatAmount: vatAmount,
        deliveryCharge: cleanDeliveryCharge,
        total: total,
        items: orderItems,
        syncStatus: createSyncEvent ? SyncStatus.pending : SyncStatus.synced,
        createdAt: now,
        updatedAt: now,
      );

      await txn.insert('orders', model.toMap());
      for (final item in orderItems) {
        await txn.insert('order_items', item.toMap());
      }
      if (createSyncEvent) {
        await _insertSyncEvent(
          txn,
          entityType: 'order',
          entityId: model.id,
          action: 'create',
          payload: model.toJson(),
        );
      }
      return model;
    });

    _emitChange();
    return order;
  }

  Future<OrderModel> upsertCloudOrder(OrderModel order) async {
    final applied = await applyRemoteOrder(order);
    return applied ?? await getOrderById(order.id) ?? order;
  }

  Future<OrderModel?> applyRemoteOrder(OrderModel order) async {
    final db = await _db;
    OrderModel? applied;
    await db.transaction((txn) async {
      final existingRows = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      final remote = order.copyWith(
        status: order.status.adminStatus,
        syncStatus: SyncStatus.synced,
      );
      if (existingRows.isEmpty) {
        final next = remote.copyWith(
          sequenceNo: remote.sequenceNo > 0
              ? remote.sequenceNo
              : await _nextOrderSequence(
                  txn,
                  source: remote.source,
                  createdByRole: remote.createdByRole,
                ),
        );
        await txn.insert('orders', next.toMap());
        for (final item in next.items) {
          await txn.insert('order_items', item.toMap());
        }
        applied = next;
        if (next.source.name == 'facebookMessenger') {
          debugPrint(
            '[QB-ALWAYS] DB INSERT fb_messenger id=${next.id} '
            'serial=${next.sequenceNo} status=${next.status.name} '
            'version=${next.version}',
          );
        }
        return;
      }

      final currentItems = await _getOrderItemsWithExecutor(txn, order.id);
      final current = OrderModel.fromMap(
        existingRows.first,
        items: currentItems,
      );
      final remoteNewer = remote.updatedAt.isAfter(current.updatedAt);
      final statusCanAdvance = current.status.canTransitionTo(remote.status);
      if (!remoteNewer &&
          (!statusCanAdvance || current.status == remote.status)) {
        // SKIP: remote looks stale and status can't advance — the in-memory
        // list keeps the old row. Prime suspect for "order not showing".
        if (order.source.name == 'facebookMessenger') {
          debugPrint(
            '[QB-ALWAYS] DB SKIP fb_messenger id=${order.id} '
            'remoteNewer=$remoteNewer statusCanAdvance=$statusCanAdvance '
            'current=${current.status.name}@${current.updatedAt.toIso8601String()} '
            'remote=${remote.status.name}@${remote.updatedAt.toIso8601String()}',
          );
        }
        return;
      }

      final nextStatus = statusCanAdvance ? remote.status : current.status;
      final nextVersion = remote.version > current.version
          ? remote.version
          : current.version;
      final next = remote.copyWith(
        source: current.source == OrderSource.localLan
            ? current.source
            : remote.source,
        status: nextStatus,
        syncStatus: current.syncStatus == SyncStatus.synced
            ? SyncStatus.synced
            : current.syncStatus,
        version: nextVersion,
        updatedAt: remoteNewer ? remote.updatedAt : current.updatedAt,
      );
      await txn.update(
        'orders',
        next.toMap(),
        where: 'id = ?',
        whereArgs: [order.id],
      );
      if (remoteNewer && current.syncStatus == SyncStatus.synced) {
        await txn.delete(
          'order_items',
          where: 'orderId = ?',
          whereArgs: [order.id],
        );
        for (final item in remote.items) {
          await txn.insert('order_items', item.toMap());
        }
      }
      applied = next.copyWith(
        items: remoteNewer && current.syncStatus == SyncStatus.synced
            ? remote.items
            : currentItems,
      );
      if (kDebugMode) {
        debugPrint(
          '[QB-ORDERS-DIAG] applyRemoteOrder APPLY id=${next.id} '
          'remoteNewer=$remoteNewer statusCanAdvance=$statusCanAdvance '
          'current=${current.status.name}/${current.status.adminStatus.name}'
          '@${current.updatedAt.toIso8601String()}v${current.version} '
          'next=${next.status.name}/${next.status.adminStatus.name}'
          '@${next.updatedAt.toIso8601String()}v${next.version} '
          'items=${applied?.items.length ?? 0}',
        );
      }
    });
    if (applied != null) _emitChange();
    return applied;
  }

  bool _localVersionWins(MenuItem current, DateTime remoteUpdatedAt) {
    if (current.syncStatus != SyncStatus.synced &&
        !remoteUpdatedAt.isAfter(current.updatedAt)) {
      return true;
    }
    return current.updatedAt.isAfter(remoteUpdatedAt);
  }

  Future<OrderModel> updateOrderStatus(
    String id,
    OrderStatus status, {
    bool createSyncEvent = true,
  }) async {
    final db = await _db;
    late OrderModel order;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw DatabaseValidationException('Order was not found.');
      }
      final currentItems = await _getOrderItemsWithExecutor(txn, id);
      final current = OrderModel.fromMap(rows.first, items: currentItems);
      if (!current.status.canTransitionTo(status)) {
        throw DatabaseValidationException(
          'Cannot change ${current.status.label} order to ${status.label}.',
        );
      }
      final updated = current.copyWith(
        status: status,
        syncStatus: createSyncEvent ? SyncStatus.pending : current.syncStatus,
        version: current.version + 1,
        updatedAt: DateTime.now(),
      );
      await txn.update(
        'orders',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      if (createSyncEvent) {
        await _insertSyncEvent(
          txn,
          entityType: 'order_status',
          entityId: id,
          action: 'status_update',
          payload: updated.toJson(),
        );
      }
      order = updated;
    });
    _emitChange();
    return order;
  }

  Future<OrderModel> updateOrderDetails(
    String id, {
    OrderServiceType? serviceType,
    String? tableNo,
    String? note,
    String? customerName,
    String? deliveryAddress,
    String? mobileNumber,
    bool createSyncEvent = true,
  }) async {
    final db = await _db;
    late OrderModel order;
    String? clean(String? value) {
      final text = value?.trim();
      return text == null || text.isEmpty ? null : text;
    }

    await db.transaction((txn) async {
      final rows = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw DatabaseValidationException('Order was not found.');
      }
      final currentItems = await _getOrderItemsWithExecutor(txn, id);
      final current = OrderModel.fromMap(rows.first, items: currentItems);
      final nextTable = clean(tableNo);
      final nextNote = clean(note);
      final nextCustomer = clean(customerName);
      final nextAddress = clean(deliveryAddress);
      final nextMobile = clean(mobileNumber);
      final updated = current.copyWith(
        serviceType: serviceType,
        tableNo: nextTable,
        note: nextNote,
        customerName: nextCustomer,
        deliveryAddress: nextAddress,
        mobileNumber: nextMobile,
        clearTableNo: nextTable == null,
        clearNote: nextNote == null,
        clearCustomerName: nextCustomer == null,
        clearDeliveryAddress: nextAddress == null,
        clearMobileNumber: nextMobile == null,
        syncStatus: createSyncEvent ? SyncStatus.pending : current.syncStatus,
        version: current.version + 1,
        updatedAt: DateTime.now(),
      );
      await txn.update(
        'orders',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      if (createSyncEvent) {
        await _insertSyncEvent(
          txn,
          entityType: 'order_details',
          entityId: id,
          action: 'details_update',
          payload: updated.toJson(),
        );
      }
      order = updated;
    });
    _emitChange();
    return order;
  }

  Future<OrderModel> updateOrderItems(
    String id,
    List<OrderRequestItem> requestedItems, {
    bool createSyncEvent = true,
  }) async {
    if (requestedItems.isEmpty) {
      throw DatabaseValidationException(
        'Order must contain at least one item.',
      );
    }
    final db = await _db;
    late OrderModel order;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw DatabaseValidationException('Order was not found.');
      }
      final currentItems = await _getOrderItemsWithExecutor(txn, id);
      final current = OrderModel.fromMap(rows.first, items: currentItems);

      final currentItemsById = <String, OrderItem>{
        for (final item in currentItems) item.id: item,
      };
      final currentItemsByMenuId = <String, List<OrderItem>>{};
      for (final item in currentItems) {
        currentItemsByMenuId.putIfAbsent(item.menuItemId, () => []).add(item);
      }

      OrderItem? takeExistingByMenuId(String menuItemId) {
        final matches = currentItemsByMenuId[menuItemId];
        if (matches == null || matches.isEmpty) return null;
        return matches.removeAt(0);
      }

      final newItems = <OrderItem>[];
      var subtotal = 0.0;
      for (final request in requestedItems) {
        if (request.qty <= 0) {
          throw DatabaseValidationException(
            'Item quantity must be greater than zero.',
          );
        }
        final menuRows = await txn.query(
          'menu_items',
          where: 'id = ? AND deletedAt IS NULL',
          whereArgs: [request.menuItemId],
          limit: 1,
        );
        if (menuRows.isEmpty) {
          throw DatabaseValidationException(
            'Menu item ${request.menuItemId} was not found.',
          );
        }
        final menuItem = MenuItem.fromMap(menuRows.first);
        final unitPrice = _requestUnitPrice(request, menuItem);
        final lineTotal = _roundMoney(unitPrice * request.qty);
        subtotal += lineTotal;
        final existingId = _cleanNullable(request.existingOrderItemId);
        final existingById = existingId == null
            ? null
            : currentItemsById.remove(existingId);
        if (existingById != null) {
          currentItemsByMenuId[existingById.menuItemId]?.removeWhere(
            (item) => item.id == existingById.id,
          );
        }
        final existing = existingById ?? takeExistingByMenuId(menuItem.id);
        newItems.add(
          OrderItem(
            id: existing?.id ?? _uuid.v4(),
            orderId: id,
            menuItemId: menuItem.id,
            name: _requestName(
              base: menuItem.name,
              suffix: request.nameSuffix,
              override: request.nameOverride,
            ),
            nameEn: _requestName(
              base: menuItem.nameEn,
              suffix: request.nameSuffix,
              override: request.nameEnOverride,
              appendSuffixToEmptyBase: false,
            ),
            nameBn: _requestName(
              base: menuItem.nameBn,
              suffix: request.nameSuffix,
              override: request.nameBnOverride,
              appendSuffixToEmptyBase: false,
            ),
            qty: request.qty,
            price: unitPrice,
            lineTotal: lineTotal,
            costPriceSnapshot:
                existing?.costPriceSnapshot ?? menuItem.costPrice ?? 0,
            note: _cleanNullable(request.note) ?? existing?.note,
            kotBatchId: existing?.kotBatchId,
            kotSentAt: existing?.kotSentAt,
          ),
        );
      }

      final roundedSubtotal = _roundMoney(subtotal);
      final total = _roundMoney(
        roundedSubtotal + current.vatAmount + current.deliveryCharge,
      );

      final updated = current.copyWith(
        items: newItems,
        subtotal: roundedSubtotal,
        total: total,
        syncStatus: createSyncEvent ? SyncStatus.pending : current.syncStatus,
        version: current.version + 1,
        updatedAt: DateTime.now(),
      );

      await txn.update(
        'orders',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete('order_items', where: 'orderId = ?', whereArgs: [id]);
      for (final item in newItems) {
        await txn.insert('order_items', item.toMap());
      }
      if (createSyncEvent) {
        await _insertSyncEvent(
          txn,
          entityType: 'order_items',
          entityId: id,
          action: 'items_update',
          payload: updated.toJson(),
        );
      }
      order = updated;
    });
    _emitChange();
    return order;
  }

  Future<List<SyncEvent>> getSyncEvents({
    Set<SyncStatus>? statuses,
    int limit = 80,
  }) async {
    final db = await _db;
    String? where;
    List<Object?>? whereArgs;
    if (statuses != null && statuses.isNotEmpty) {
      final placeholders = List.filled(statuses.length, '?').join(',');
      where = 'status IN ($placeholders)';
      whereArgs = statuses
          .map((status) => status.value)
          .toList(growable: false);
    }
    final rows = await db.query(
      'sync_events',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'createdAt ASC',
      limit: limit,
    );
    return rows.map(SyncEvent.fromMap).toList(growable: false);
  }

  Future<SyncSummary> getSyncSummary() async {
    final db = await _db;
    final pending =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_events WHERE status = ?',
            [SyncStatus.pending.value],
          ),
        ) ??
        0;
    final failed =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM sync_events WHERE status = ?',
            [SyncStatus.failed.value],
          ),
        ) ??
        0;
    final lastRows = await db.rawQuery(
      'SELECT MAX(updatedAt) AS lastSyncAt FROM sync_events WHERE status = ?',
      [SyncStatus.synced.value],
    );
    final lastRaw = lastRows.isEmpty
        ? null
        : lastRows.first['lastSyncAt'] as String?;
    return SyncSummary(
      pendingCount: pending,
      failedCount: failed,
      lastSyncAt: lastRaw == null ? null : DateTime.tryParse(lastRaw),
    );
  }

  Future<void> markSyncEventSynced(SyncEvent event) async {
    final db = await _db;
    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      await txn.update(
        'sync_events',
        {
          'status': SyncStatus.synced.value,
          'lastError': null,
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [event.id],
      );
      await _markEntitySyncStatus(txn, event, SyncStatus.synced);
    });
    _emitChange();
  }

  Future<void> markSyncEventFailed(SyncEvent event, Object error) async {
    final db = await _db;
    await db.update(
      'sync_events',
      {
        'status': SyncStatus.failed.value,
        'retryCount': event.retryCount + 1,
        'lastError': error.toString(),
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [event.id],
    );
    _emitChange();
  }

  /// Reclaim already-synced sync_events older than [olderThan]. Each row holds
  /// the full JSON payload of its change and was otherwise retained forever, so
  /// this bounds the table's disk/memory footprint over time. Only `synced`
  /// rows are removed (pending/failed stay in the queue), and the diagnostics
  /// view only shows recent rows, so this is invisible to the UI — hence no
  /// `_emitChange()` (avoids triggering a needless reload). Uses the
  /// (status, createdAt) index. Returns the number of rows removed.
  Future<int> pruneSyncedEvents({
    Duration olderThan = const Duration(days: 3),
  }) async {
    final db = await _db;
    final cutoff = DateTime.now().subtract(olderThan).toIso8601String();
    return db.delete(
      'sync_events',
      where: 'status = ? AND createdAt < ?',
      whereArgs: [SyncStatus.synced.value, cutoff],
    );
  }

  Future<void> retryFailedSyncEvents() async {
    final db = await _db;
    await db.update(
      'sync_events',
      {
        'status': SyncStatus.pending.value,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'status = ?',
      whereArgs: [SyncStatus.failed.value],
    );
    _emitChange();
  }

  Future<void> clearLocalData() async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('sync_events');
      await txn.delete('notifications');
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('menu_items');
      await txn.delete('stock_adjustments');
      await txn.delete('daily_stock_counts');
      await txn.delete('inventory_items');
      await txn.delete('inventory_suppliers');
    });
    _emitChange();
  }

  Future<List<PosNotification>> getNotifications({int limit = 100}) async {
    final db = await _db;
    final rows = await db.query(
      'notifications',
      where: 'type != ?',
      whereArgs: [PosNotificationType.printFailed.value],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map(PosNotification.fromMap).toList(growable: false);
  }

  Future<void> upsertNotification(PosNotification notification) async {
    final db = await _db;
    await db.insert(
      'notifications',
      notification.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _emitChange();
  }

  Future<void> markNotificationRead(String id) async {
    final db = await _db;
    await db.update(
      'notifications',
      {'readAt': DateTime.now().toIso8601String()},
      where: 'id = ? AND readAt IS NULL',
      whereArgs: [id],
    );
    _emitChange();
  }

  Future<void> markAllNotificationsRead() async {
    final db = await _db;
    await db.update('notifications', {
      'readAt': DateTime.now().toIso8601String(),
    }, where: 'readAt IS NULL');
    _emitChange();
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    await _changeController.close();
  }

  Future<Database> get _db async {
    if (_database == null) {
      await initialize();
    }
    return _database!;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE menu_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        nameEn TEXT NOT NULL DEFAULT '',
        nameBn TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL,
        descriptionEn TEXT NOT NULL DEFAULT '',
        descriptionBn TEXT NOT NULL DEFAULT '',
        category TEXT NOT NULL,
        categoryEn TEXT NOT NULL DEFAULT '',
        categoryBn TEXT NOT NULL DEFAULT '',
        price REAL NOT NULL,
        costPrice REAL,
        shortCode INTEGER,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        imageUrl TEXT,
        isAvailable INTEGER NOT NULL,
        preparationTimeMinutes INTEGER,
        tags TEXT,
        syncStatus TEXT NOT NULL DEFAULT 'synced',
        version INTEGER NOT NULL DEFAULT 1,
        deletedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        orderNo TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'cloud',
        customerName TEXT,
        tableNo TEXT,
        note TEXT,
        deliveryAddress TEXT,
        mobileNumber TEXT,
        createdByAccountId TEXT,
        createdByRole TEXT,
        shiftId TEXT,
        discountLabel TEXT,
        discountAmount REAL NOT NULL DEFAULT 0,
        serviceChargeRatePercent REAL NOT NULL DEFAULT 0,
        serviceChargeAmount REAL NOT NULL DEFAULT 0,
        billingSnapshot TEXT NOT NULL DEFAULT '{}',
        kotBatches TEXT NOT NULL DEFAULT '[]',
        settledAt TEXT,
        serviceType TEXT,
        covers INTEGER,
        paymentMethod TEXT,
        subtotal REAL,
        vatRatePercent REAL,
        vatAmount REAL,
        deliveryCharge REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        total REAL NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'synced',
        version INTEGER NOT NULL DEFAULT 1,
        sequenceNo INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        menuItemId TEXT NOT NULL,
        name TEXT NOT NULL,
        nameEn TEXT NOT NULL DEFAULT '',
        nameBn TEXT NOT NULL DEFAULT '',
        qty INTEGER NOT NULL,
        price REAL NOT NULL,
        lineTotal REAL NOT NULL,
        costPriceSnapshot REAL NOT NULL DEFAULT 0,
        note TEXT,
        kotBatchId TEXT,
        kotSentAt TEXT,
        FOREIGN KEY(orderId) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    await _createSyncTable(db);
    await _createInventoryTables(db);
    await _createNotificationTable(db);
    await _createDesktopPosTables(db);
    await _createIndexes(db);
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(
        db,
        'menu_items',
        'syncStatus',
        "syncStatus TEXT NOT NULL DEFAULT 'synced'",
      );
      await _addColumnIfMissing(
        db,
        'menu_items',
        'version',
        'version INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(
        db,
        'menu_items',
        'deletedAt',
        'deletedAt TEXT',
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'source',
        "source TEXT NOT NULL DEFAULT 'cloud'",
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'syncStatus',
        "syncStatus TEXT NOT NULL DEFAULT 'synced'",
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'version',
        'version INTEGER NOT NULL DEFAULT 1',
      );
      await _createSyncTable(db);
      await _createIndexes(db);
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(
        db,
        'orders',
        'sequenceNo',
        'sequenceNo INTEGER',
      );
      await _backfillOrderSequences(db);
      await _createIndexes(db);
    }
    if (oldVersion < 4) {
      await _createInventoryTables(db);
      await _createIndexes(db);
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(
        db,
        'orders',
        'createdByAccountId',
        'createdByAccountId TEXT',
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'createdByRole',
        'createdByRole TEXT',
      );
      await _createNotificationTable(db);
      await _createIndexes(db);
    }
    if (oldVersion < 6) {
      await _migrateInventoryV6(db);
    }
    if (oldVersion < 7) {
      await _migrateMenuBilingualV7(db);
    }
    if (oldVersion < 8) {
      await _migrateOrdersV8(db);
    }
    if (oldVersion < 9) {
      await _migrateOrderItemsBilingualV9(db);
    }
    if (oldVersion < 10) {
      await _migrateOrdersDeliveryV10(db);
    }
    if (oldVersion < 11) {
      await _migrateMenuCostPriceV11(db);
    }
    if (oldVersion < 12) {
      await _migrateOrdersDeliveryChargeV12(db);
    }
    if (oldVersion < 13) {
      await _migrateInventoryRedesignV13(db);
    }
    if (oldVersion < 14) {
      await _migrateDesktopPosV14(db);
    }
    if (oldVersion < 15) {
      await _migrateOrdersDropOrderNoUniqueV15(db);
    }
    if (oldVersion < 16) {
      await _addColumnIfMissing(
        db,
        'menu_items',
        'shortCode',
        'shortCode INTEGER',
      );
    }
    if (oldVersion < 17) {
      await _addColumnIfMissing(
        db,
        'menu_items',
        'isFavorite',
        'isFavorite INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  Future<void> _migrateInventoryRedesignV13(Database db) async {
    await _createInventorySupplierTable(db);
    await _addColumnIfMissing(
      db,
      'inventory_items',
      'defaultSupplierId',
      'defaultSupplierId TEXT',
    );
    await _addColumnIfMissing(
      db,
      'inventory_items',
      'defaultReorderQty',
      'defaultReorderQty REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'stock_adjustments',
      'supplierId',
      'supplierId TEXT',
    );
    await _addColumnIfMissing(
      db,
      'stock_adjustments',
      'supplierName',
      "supplierName TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'stock_adjustments',
      'reason',
      "reason TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'stock_adjustments',
      'billRef',
      "billRef TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'stock_adjustments',
      'createdByAccountId',
      'createdByAccountId TEXT',
    );
    await _addColumnIfMissing(
      db,
      'stock_adjustments',
      'createdByRole',
      'createdByRole TEXT',
    );
  }

  Future<void> _migrateDesktopPosV14(Database db) async {
    for (final entry in <(String, String)>[
      ('shiftId', 'shiftId TEXT'),
      ('discountLabel', 'discountLabel TEXT'),
      ('discountAmount', 'discountAmount REAL NOT NULL DEFAULT 0'),
      (
        'serviceChargeRatePercent',
        'serviceChargeRatePercent REAL NOT NULL DEFAULT 0',
      ),
      ('serviceChargeAmount', 'serviceChargeAmount REAL NOT NULL DEFAULT 0'),
      ('billingSnapshot', "billingSnapshot TEXT NOT NULL DEFAULT '{}'"),
      ('kotBatches', "kotBatches TEXT NOT NULL DEFAULT '[]'"),
      ('settledAt', 'settledAt TEXT'),
    ]) {
      await _addColumnIfMissing(db, 'orders', entry.$1, entry.$2);
    }
    for (final entry in <(String, String)>[
      ('costPriceSnapshot', 'costPriceSnapshot REAL NOT NULL DEFAULT 0'),
      ('note', 'note TEXT'),
      ('kotBatchId', 'kotBatchId TEXT'),
      ('kotSentAt', 'kotSentAt TEXT'),
    ]) {
      await _addColumnIfMissing(db, 'order_items', entry.$1, entry.$2);
    }
    await _createDesktopPosTables(db);
  }

  Future<void> _migrateOrdersDropOrderNoUniqueV15(Database db) async {
    await db.execute('PRAGMA defer_foreign_keys = ON');
    await db.execute('''
      CREATE TABLE orders_v15 (
        id TEXT PRIMARY KEY,
        orderNo TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'cloud',
        customerName TEXT,
        tableNo TEXT,
        note TEXT,
        deliveryAddress TEXT,
        mobileNumber TEXT,
        createdByAccountId TEXT,
        createdByRole TEXT,
        shiftId TEXT,
        discountLabel TEXT,
        discountAmount REAL NOT NULL DEFAULT 0,
        serviceChargeRatePercent REAL NOT NULL DEFAULT 0,
        serviceChargeAmount REAL NOT NULL DEFAULT 0,
        billingSnapshot TEXT NOT NULL DEFAULT '{}',
        kotBatches TEXT NOT NULL DEFAULT '[]',
        settledAt TEXT,
        serviceType TEXT,
        covers INTEGER,
        paymentMethod TEXT,
        subtotal REAL,
        vatRatePercent REAL,
        vatAmount REAL,
        deliveryCharge REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL,
        total REAL NOT NULL,
        syncStatus TEXT NOT NULL DEFAULT 'synced',
        version INTEGER NOT NULL DEFAULT 1,
        sequenceNo INTEGER NOT NULL,
        orderDate TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('INSERT INTO orders_v15 SELECT * FROM orders');
    await db.execute('DROP TABLE orders');
    await db.execute('ALTER TABLE orders_v15 RENAME TO orders');
    await _createIndexes(db);
  }

  Future<void> _migrateOrdersDeliveryChargeV12(Database db) async {
    await _addColumnIfMissing(
      db,
      'orders',
      'deliveryCharge',
      'deliveryCharge REAL NOT NULL DEFAULT 0',
    );
  }

  Future<void> _migrateMenuCostPriceV11(Database db) async {
    await _addColumnIfMissing(db, 'menu_items', 'costPrice', 'costPrice REAL');
  }

  Future<void> _migrateOrdersDeliveryV10(Database db) async {
    await _addColumnIfMissing(
      db,
      'orders',
      'deliveryAddress',
      'deliveryAddress TEXT',
    );
    await _addColumnIfMissing(
      db,
      'orders',
      'mobileNumber',
      'mobileNumber TEXT',
    );
  }

  Future<void> _migrateMenuBilingualV7(Database db) async {
    await _addColumnIfMissing(
      db,
      'menu_items',
      'nameEn',
      "nameEn TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'menu_items',
      'nameBn',
      "nameBn TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'menu_items',
      'descriptionEn',
      "descriptionEn TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'menu_items',
      'descriptionBn',
      "descriptionBn TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'menu_items',
      'categoryEn',
      "categoryEn TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'menu_items',
      'categoryBn',
      "categoryBn TEXT NOT NULL DEFAULT ''",
    );
  }

  Future<void> _migrateInventoryV6(Database db) async {
    await _addColumnIfMissing(
      db,
      'stock_adjustments',
      'totalCostBdt',
      'totalCostBdt REAL NOT NULL DEFAULT 0',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_stock_counts (
        id TEXT PRIMARY KEY,
        inventoryItemId TEXT NOT NULL,
        countDate TEXT NOT NULL,
        quantity REAL NOT NULL,
        createdAt TEXT NOT NULL,
        UNIQUE(inventoryItemId, countDate),
        FOREIGN KEY(inventoryItemId) REFERENCES inventory_items(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_daily_stock_counts_date ON daily_stock_counts(countDate)',
    );
  }

  Future<void> _migrateOrdersV8(Database db) async {
    await _addColumnIfMissing(db, 'orders', 'serviceType', 'serviceType TEXT');
    await _addColumnIfMissing(db, 'orders', 'covers', 'covers INTEGER');
    await _addColumnIfMissing(
      db,
      'orders',
      'paymentMethod',
      'paymentMethod TEXT',
    );
    await _addColumnIfMissing(db, 'orders', 'subtotal', 'subtotal REAL');
    await _addColumnIfMissing(
      db,
      'orders',
      'vatRatePercent',
      'vatRatePercent REAL',
    );
    await _addColumnIfMissing(db, 'orders', 'vatAmount', 'vatAmount REAL');
    await db.execute(
      'UPDATE orders SET subtotal = total WHERE subtotal IS NULL',
    );
    await db.execute(
      'UPDATE orders SET vatRatePercent = 0 WHERE vatRatePercent IS NULL',
    );
    await db.execute('UPDATE orders SET vatAmount = 0 WHERE vatAmount IS NULL');
  }

  Future<void> _migrateOrderItemsBilingualV9(Database db) async {
    await _addColumnIfMissing(
      db,
      'order_items',
      'nameEn',
      "nameEn TEXT NOT NULL DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'order_items',
      'nameBn',
      "nameBn TEXT NOT NULL DEFAULT ''",
    );
  }

  Future<void> _ensureSchema(Database db) async {
    await _addColumnIfMissing(
      db,
      'menu_items',
      'syncStatus',
      "syncStatus TEXT NOT NULL DEFAULT 'synced'",
    );
    await _addColumnIfMissing(
      db,
      'menu_items',
      'version',
      'version INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(db, 'menu_items', 'deletedAt', 'deletedAt TEXT');
    await _migrateMenuBilingualV7(db);
    await _migrateMenuCostPriceV11(db);
    await _addColumnIfMissing(
      db,
      'orders',
      'source',
      "source TEXT NOT NULL DEFAULT 'cloud'",
    );
    await _addColumnIfMissing(
      db,
      'orders',
      'syncStatus',
      "syncStatus TEXT NOT NULL DEFAULT 'synced'",
    );
    await _addColumnIfMissing(
      db,
      'orders',
      'version',
      'version INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(db, 'orders', 'sequenceNo', 'sequenceNo INTEGER');
    await _addColumnIfMissing(db, 'orders', 'orderDate', 'orderDate TEXT');
    await db.execute(
      "UPDATE orders SET orderDate = substr(orderDate, 1, 10) WHERE orderDate IS NOT NULL AND length(orderDate) > 10",
    );
    await _addColumnIfMissing(
      db,
      'orders',
      'createdByAccountId',
      'createdByAccountId TEXT',
    );
    await _addColumnIfMissing(
      db,
      'orders',
      'createdByRole',
      'createdByRole TEXT',
    );
    await _backfillOrderSequences(db);
    await _migrateOrdersV8(db);
    await _migrateOrdersDeliveryChargeV12(db);
    await _migrateOrderItemsBilingualV9(db);
    await _createSyncTable(db);
    await _createInventoryTables(db);
    await _migrateInventoryV6(db);
    await _migrateInventoryRedesignV13(db);
    await _migrateDesktopPosV14(db);
    await _createNotificationTable(db);
    await _createIndexes(db);
  }

  Future<void> _createSyncTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS sync_events (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        action TEXT NOT NULL,
        payloadJson TEXT NOT NULL,
        status TEXT NOT NULL,
        retryCount INTEGER NOT NULL DEFAULT 0,
        lastError TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createInventoryTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT 'pcs',
        quantity REAL NOT NULL DEFAULT 0,
        minThreshold REAL NOT NULL DEFAULT 0,
        costPerUnit REAL NOT NULL DEFAULT 0,
        notes TEXT NOT NULL DEFAULT '',
        defaultSupplierId TEXT,
        defaultReorderQty REAL NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_adjustments (
        id TEXT PRIMARY KEY,
        inventoryItemId TEXT NOT NULL,
        delta REAL NOT NULL,
        type TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        totalCostBdt REAL NOT NULL DEFAULT 0,
        supplierId TEXT,
        supplierName TEXT NOT NULL DEFAULT '',
        reason TEXT NOT NULL DEFAULT '',
        billRef TEXT NOT NULL DEFAULT '',
        createdByAccountId TEXT,
        createdByRole TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY(inventoryItemId) REFERENCES inventory_items(id) ON DELETE CASCADE
      )
    ''');
    await _createInventorySupplierTable(db);
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_stock_counts (
        id TEXT PRIMARY KEY,
        inventoryItemId TEXT NOT NULL,
        countDate TEXT NOT NULL,
        quantity REAL NOT NULL,
        createdAt TEXT NOT NULL,
        UNIQUE(inventoryItemId, countDate),
        FOREIGN KEY(inventoryItemId) REFERENCES inventory_items(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createInventorySupplierTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT NOT NULL DEFAULT '',
        notes TEXT NOT NULL DEFAULT '',
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createNotificationTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        orderId TEXT,
        actionTarget TEXT,
        createdAt TEXT NOT NULL,
        readAt TEXT
      )
    ''');
  }

  Future<void> _createDesktopPosTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS desktop_pos_settings (
        id TEXT PRIMARY KEY,
        payloadJson TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pos_shifts (
        id TEXT PRIMARY KEY,
        status TEXT NOT NULL,
        openingCash REAL NOT NULL DEFAULT 0,
        expectedCash REAL,
        countedCash REAL,
        varianceCash REAL,
        openingDenominations TEXT NOT NULL DEFAULT '{}',
        closingDenominations TEXT NOT NULL DEFAULT '{}',
        openedByAccountId TEXT,
        closedByAccountId TEXT,
        openedAt TEXT NOT NULL,
        closedAt TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pos_settlements (
        eventId TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        shiftId TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        amount REAL NOT NULL,
        payerLabel TEXT,
        createdAt TEXT NOT NULL,
        FOREIGN KEY(orderId) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pos_audit_events (
        eventId TEXT PRIMARY KEY,
        orderId TEXT,
        shiftId TEXT,
        action TEXT NOT NULL,
        reason TEXT,
        payloadJson TEXT NOT NULL DEFAULT '{}',
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pos_report_cache (
        id TEXT PRIMARY KEY,
        payloadJson TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_menu_items_category ON menu_items(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_orders_status_created ON orders(status, createdAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_orders_source ON orders(source)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_order_items_order ON order_items(orderId)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_sync_events_status ON sync_events(status, createdAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_inventory_items_category ON inventory_items(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_stock_adjustments_item ON stock_adjustments(inventoryItemId, createdAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_notifications_created ON notifications(createdAt DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_notifications_read ON notifications(readAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_pos_shifts_status ON pos_shifts(status, openedAt)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS index_pos_settlements_shift ON pos_settlements(shiftId, createdAt)',
    );
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $definition');
    }
  }

  Future<int> _nextOrderSequence(
    DatabaseExecutor db, {
    OrderSource source = OrderSource.manual,
    String? createdByRole,
  }) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    // Source-aware serial grouping: each group (W/M/S/default) keeps its own
    // per-day counter. Must match backend `serial_group_filter` logic.
    // Local DB stores source as the OrderSource enum value, so online sources
    // are 'cloud' (website) and 'facebook_messenger' (messenger).
    const onlineSources = "'cloud','facebook_messenger'";
    String groupFilter;
    switch (source) {
      case OrderSource.cloud:
        groupFilter = "AND source = 'cloud'";
      case OrderSource.facebookMessenger:
        groupFilter = "AND source = 'facebook_messenger'";
      case OrderSource.manual:
      case OrderSource.desktopPos:
      case OrderSource.localLan:
        final role = (createdByRole ?? '').trim().toLowerCase();
        if (role == 'waiter' || role == 'staff') {
          groupFilter =
              "AND source NOT IN ($onlineSources) AND (createdByRole = 'waiter' OR createdByRole = 'staff')";
        } else {
          groupFilter =
              "AND source NOT IN ($onlineSources) AND (createdByRole IS NULL OR (createdByRole != 'waiter' AND createdByRole != 'staff'))";
        }
    }
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(sequenceNo), 0) + 1 AS nextSequence '
      'FROM orders WHERE date(orderDate) = ? $groupFilter',
      [today],
    );
    final value = rows.first['nextSequence'];
    return value is num ? value.toInt() : 1;
  }

  Future<void> _backfillOrderSequences(Database db) async {
    final rows = await db.query(
      'orders',
      columns: ['id', 'sequenceNo'],
      orderBy: 'createdAt ASC, orderNo ASC',
    );
    var next = 1;
    for (final row in rows) {
      final rawCurrent = row['sequenceNo'];
      final current = rawCurrent is num ? rawCurrent.toInt() : null;
      if (current != null && current > 0) {
        if (current >= next) next = current + 1;
        continue;
      }
      await db.update(
        'orders',
        {'sequenceNo': next},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
      next++;
    }
  }

  Future<List<OrderItem>> _getOrderItems(String orderId) async {
    final db = await _db;
    return _getOrderItemsWithExecutor(db, orderId);
  }

  Future<List<OrderItem>> _getOrderItemsWithExecutor(
    DatabaseExecutor db,
    String orderId,
  ) async {
    final rows = await db.query(
      'order_items',
      where: 'orderId = ?',
      whereArgs: [orderId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(OrderItem.fromMap).toList(growable: false);
  }

  /// Batched lookup: one query for many orderIds; returns items grouped by
  /// orderId. Used by [getOrders] to avoid an N+1 fetch per order row.
  Future<Map<String, List<OrderItem>>> _getOrderItemsForIds(
    DatabaseExecutor db,
    List<String> orderIds,
  ) async {
    if (orderIds.isEmpty) return const <String, List<OrderItem>>{};
    final placeholders = List.filled(orderIds.length, '?').join(',');
    final rows = await db.query(
      'order_items',
      where: 'orderId IN ($placeholders)',
      whereArgs: orderIds,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    final grouped = <String, List<OrderItem>>{};
    for (final row in rows) {
      final id = row['orderId'] as String;
      (grouped[id] ??= <OrderItem>[]).add(OrderItem.fromMap(row));
    }
    return grouped;
  }

  Future<void> _insertSyncEvent(
    DatabaseExecutor db, {
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, Object?> payload,
  }) async {
    final now = DateTime.now();
    final event = SyncEvent(
      id: _uuid.v4(),
      entityType: entityType,
      entityId: entityId,
      action: action,
      payloadJson: jsonEncode(payload),
      status: SyncStatus.pending,
      retryCount: 0,
      createdAt: now,
      updatedAt: now,
    );
    await db.insert('sync_events', event.toMap());
  }

  Future<void> _markEntitySyncStatus(
    DatabaseExecutor db,
    SyncEvent event,
    SyncStatus status,
  ) async {
    if (event.entityType == 'menu_item') {
      await db.update(
        'menu_items',
        {'syncStatus': status.value},
        where: 'id = ?',
        whereArgs: [event.entityId],
      );
      return;
    }
    if (event.entityType == 'order' ||
        event.entityType == 'order_status' ||
        event.entityType == 'order_details') {
      await db.update(
        'orders',
        {'syncStatus': status.value},
        where: 'id = ?',
        whereArgs: [event.entityId],
      );
    }
  }

  String _buildOrderNumber(DateTime now) {
    final stamp = DateFormat('yyMMddHHmmss').format(now);
    final suffix = _uuid.v4().split('-').first.toUpperCase();
    return 'ORD-$stamp-$suffix';
  }

  String? _cleanNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  double _roundMoney(double value) => double.parse(value.toStringAsFixed(2));

  double _requestUnitPrice(OrderRequestItem request, MenuItem menuItem) {
    final price = request.unitPrice;
    if (price != null && price.isFinite && price >= 0) {
      return _roundMoney(price);
    }
    return menuItem.price;
  }

  String _requestName({
    required String base,
    String? suffix,
    String? override,
    bool appendSuffixToEmptyBase = true,
  }) {
    final cleanOverride = _cleanNullable(override);
    if (cleanOverride != null) return cleanOverride;
    final cleanBase = base.trim();
    final cleanSuffix = _cleanNullable(suffix);
    if (cleanSuffix == null) return cleanBase;
    if (cleanBase.isEmpty) {
      return appendSuffixToEmptyBase ? cleanSuffix : cleanBase;
    }
    return '$cleanBase ($cleanSuffix)';
  }

  // ── Desktop POS ──────────────────────────────────────────────────────────

  Future<DesktopPosSettings> getDesktopPosSettings({
    required int fallbackTableCount,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'desktop_pos_settings',
      where: 'id = ?',
      whereArgs: ['outlet'],
      limit: 1,
    );
    if (rows.isEmpty) {
      return DesktopPosSettings(
        floorLayout: DesktopPosSettings.fallbackFloor(fallbackTableCount),
      );
    }
    final raw = jsonDecode(rows.first['payloadJson'] as String);
    return DesktopPosSettings.fromJson(
      raw is Map ? Map<String, Object?>.from(raw) : const {},
      fallbackTableCount: fallbackTableCount,
    );
  }

  Future<void> saveDesktopPosSettings(DesktopPosSettings settings) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.insert('desktop_pos_settings', {
        'id': 'outlet',
        'payloadJson': jsonEncode(settings.toJson()),
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _insertSyncEvent(
        txn,
        entityType: 'pos_settings',
        entityId: 'outlet',
        action: 'update',
        payload: settings.toJson(),
      );
    });
    _emitChange();
  }

  Future<void> applyRemoteDesktopPosSettings(
    DesktopPosSettings settings,
  ) async {
    final db = await _db;
    await db.insert('desktop_pos_settings', {
      'id': 'outlet',
      'payloadJson': jsonEncode(settings.toJson()),
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _emitChange();
  }

  Future<PosShift?> getCurrentPosShift() async {
    final db = await _db;
    final rows = await db.query(
      'pos_shifts',
      where: 'status = ?',
      whereArgs: ['open'],
      orderBy: 'openedAt DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : PosShift.fromMap(rows.first);
  }

  Future<void> applyRemotePosShift(PosShift shift) async {
    final db = await _db;
    if (shift.isOpen) {
      await db.update(
        'pos_shifts',
        {'status': 'closed'},
        where: 'status = ? AND id != ?',
        whereArgs: ['open', shift.id],
      );
    }
    await db.insert(
      'pos_shifts',
      shift.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _emitChange();
  }

  Future<void> clearRemoteClosedPosShift() async {
    final db = await _db;
    final pending =
        Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM sync_events WHERE entityType = 'pos_shift' "
            "AND action = 'open' AND status != ?",
            [SyncStatus.synced.value],
          ),
        ) ??
        0;
    if (pending > 0) return;
    await db.update(
      'pos_shifts',
      {'status': 'closed', 'closedAt': DateTime.now().toIso8601String()},
      where: 'status = ?',
      whereArgs: ['open'],
    );
    _emitChange();
  }

  Future<PosShift> openPosShift({
    required double openingCash,
    required Map<String, int> denominations,
    String? openedByAccountId,
  }) async {
    final current = await getCurrentPosShift();
    if (current != null) return current;
    final db = await _db;
    final now = DateTime.now();
    final shift = PosShift(
      id: _uuid.v4(),
      status: 'open',
      openingCash: _roundMoney(openingCash),
      openingDenominations: denominations,
      openedByAccountId: _cleanNullable(openedByAccountId),
      openedAt: now,
    );
    await db.transaction((txn) async {
      await txn.insert('pos_shifts', shift.toMap());
      await _insertSyncEvent(
        txn,
        entityType: 'pos_shift',
        entityId: shift.id,
        action: 'open',
        payload: {
          'id': shift.id,
          'openingCash': shift.openingCash,
          'denominations': denominations,
        },
      );
    });
    _emitChange();
    return shift;
  }

  Future<PosShift> closePosShift({
    required String shiftId,
    required double countedCash,
    required Map<String, int> denominations,
    String? closedByAccountId,
  }) async {
    final db = await _db;
    late PosShift result;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'pos_shifts',
        where: 'id = ?',
        whereArgs: [shiftId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw DatabaseValidationException('Shift was not found.');
      }
      final current = PosShift.fromMap(rows.first);
      final cashRows = await txn.rawQuery(
        'SELECT COALESCE(SUM(amount), 0) total FROM pos_settlements '
        'WHERE shiftId = ? AND paymentMethod = ?',
        [shiftId, 'cash'],
      );
      final cashSales = (cashRows.first['total'] as num?)?.toDouble() ?? 0;
      final expected = _roundMoney(current.openingCash + cashSales);
      final counted = _roundMoney(countedCash);
      result = PosShift(
        id: current.id,
        status: 'closed',
        openingCash: current.openingCash,
        expectedCash: expected,
        countedCash: counted,
        varianceCash: _roundMoney(counted - expected),
        openingDenominations: current.openingDenominations,
        closingDenominations: denominations,
        openedByAccountId: current.openedByAccountId,
        closedByAccountId: _cleanNullable(closedByAccountId),
        openedAt: current.openedAt,
        closedAt: DateTime.now(),
      );
      await txn.update(
        'pos_shifts',
        result.toMap(),
        where: 'id = ?',
        whereArgs: [shiftId],
      );
      await _insertSyncEvent(
        txn,
        entityType: 'pos_shift',
        entityId: shiftId,
        action: 'close',
        payload: {'countedCash': counted, 'denominations': denominations},
      );
    });
    _emitChange();
    return result;
  }

  Future<OrderModel> markDesktopKotSent({
    required String orderId,
    required List<String> itemIds,
    String? note,
  }) async {
    final db = await _db;
    late OrderModel result;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw DatabaseValidationException('Order was not found.');
      }
      final now = DateTime.now();
      final batchId = _uuid.v4();
      final items = await _getOrderItemsWithExecutor(txn, orderId);
      final selected = itemIds.toSet();
      final nextItems = [
        for (final item in items)
          OrderItem(
            id: item.id,
            orderId: item.orderId,
            menuItemId: item.menuItemId,
            name: item.name,
            nameEn: item.nameEn,
            nameBn: item.nameBn,
            qty: item.qty,
            price: item.price,
            lineTotal: item.lineTotal,
            costPriceSnapshot: item.costPriceSnapshot,
            note: item.note,
            kotBatchId: selected.contains(item.id) ? batchId : item.kotBatchId,
            kotSentAt: selected.contains(item.id) ? now : item.kotSentAt,
          ),
      ];
      final current = OrderModel.fromMap(rows.first, items: items);
      final batches = [
        ...current.kotBatches,
        {
          'id': batchId,
          'itemIds': itemIds,
          'note': _cleanNullable(note),
          'sentAt': now.toIso8601String(),
        },
      ];
      result = current.copyWith(
        items: nextItems,
        kotBatches: batches,
        updatedAt: now,
      );
      await txn.update(
        'orders',
        result.toMap(),
        where: 'id = ?',
        whereArgs: [orderId],
      );
      await txn.delete(
        'order_items',
        where: 'orderId = ?',
        whereArgs: [orderId],
      );
      for (final item in nextItems) {
        await txn.insert('order_items', item.toMap());
      }
      await _insertSyncEvent(
        txn,
        entityType: 'pos_kot',
        entityId: orderId,
        action: 'send',
        payload: {'batchId': batchId, 'itemIds': itemIds, 'note': note},
      );
    });
    _emitChange();
    return result;
  }

  Future<OrderModel> settleDesktopOrder({
    required String orderId,
    required PosShift shift,
    required List<PosSettlementLine> settlements,
    required double discountAmount,
    required double serviceChargeRatePercent,
    required double serviceChargeAmount,
    String? discountPresetId,
    String? discountLabel,
  }) async {
    final db = await _db;
    late OrderModel result;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw DatabaseValidationException('Order was not found.');
      }
      final items = await _getOrderItemsWithExecutor(txn, orderId);
      final current = OrderModel.fromMap(rows.first, items: items);
      final total = _roundMoney(
        current.subtotal +
            current.vatAmount +
            current.deliveryCharge +
            serviceChargeAmount -
            discountAmount,
      );
      final paid = _roundMoney(
        settlements.fold(0, (sum, line) => sum + line.amount),
      );
      if ((paid - total).abs() > 0.01) {
        throw DatabaseValidationException(
          'Split payments must equal the bill total.',
        );
      }
      final now = DateTime.now();
      result = current.copyWith(
        shiftId: shift.id,
        discountLabel: _cleanNullable(discountLabel),
        discountAmount: _roundMoney(discountAmount),
        serviceChargeRatePercent: _roundMoney(serviceChargeRatePercent),
        serviceChargeAmount: _roundMoney(serviceChargeAmount),
        billingSnapshot: {
          'subtotal': current.subtotal,
          'vatRatePercent': current.vatRatePercent,
          'vatAmount': current.vatAmount,
          'deliveryCharge': current.deliveryCharge,
          'discountLabel': _cleanNullable(discountLabel),
          'discountAmount': _roundMoney(discountAmount),
          'serviceChargeRatePercent': _roundMoney(serviceChargeRatePercent),
          'serviceChargeAmount': _roundMoney(serviceChargeAmount),
          'totalAmount': total,
        },
        paymentMethod: settlements.length == 1
            ? OrderPaymentMethod.tryParse(settlements.first.paymentMethod)
            : current.paymentMethod,
        status: OrderStatus.served,
        settledAt: now,
        total: total,
        updatedAt: now,
      );
      await txn.update(
        'orders',
        result.toMap(),
        where: 'id = ?',
        whereArgs: [orderId],
      );
      for (final line in settlements) {
        await txn.insert('pos_settlements', {
          'eventId': line.eventId,
          'orderId': orderId,
          'shiftId': shift.id,
          'paymentMethod': line.paymentMethod,
          'amount': line.amount,
          'payerLabel': line.payerLabel,
          'createdAt': now.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await _insertSyncEvent(
        txn,
        entityType: 'pos_settlement',
        entityId: orderId,
        action: 'settle',
        payload: {
          'shiftId': shift.id,
          'discountPresetId': discountPresetId,
          'customDiscountLabel': discountPresetId == null
              ? discountLabel
              : null,
          'discountAmount': _roundMoney(discountAmount),
          'serviceChargeRatePercent': _roundMoney(serviceChargeRatePercent),
          'serviceChargeAmount': _roundMoney(serviceChargeAmount),
          'totalAmount': total,
          'settlements': settlements.map((line) => line.toJson()).toList(),
        },
      );
    });
    _emitChange();
    return result;
  }

  Future<void> queueDesktopAudit({
    required String orderId,
    required String action,
    required String reason,
    String? shiftId,
    double? amount,
    String? paymentMethod,
    Map<String, Object?>? metadata,
  }) async {
    final db = await _db;
    final eventId = _uuid.v4();
    final now = DateTime.now().toIso8601String();
    final payload = <String, Object?>{
      'eventId': eventId,
      'action': action,
      'reason': reason,
      'shiftId': shiftId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'metadata': metadata ?? const <String, Object?>{},
    };
    await db.transaction((txn) async {
      await txn.insert('pos_audit_events', {
        'eventId': eventId,
        'orderId': orderId,
        'shiftId': shiftId,
        'action': action,
        'reason': reason,
        'payloadJson': jsonEncode(payload),
        'createdAt': now,
      });
      if (action == 'refund' && amount != null && paymentMethod != null) {
        await txn.insert('pos_settlements', {
          'eventId': 'refund:$eventId',
          'orderId': orderId,
          'shiftId': shiftId ?? '',
          'paymentMethod': paymentMethod,
          'amount': -amount.abs(),
          'payerLabel': 'Refund',
          'createdAt': now,
        });
      }
      await _insertSyncEvent(
        txn,
        entityType: 'pos_audit',
        entityId: orderId,
        action: action,
        payload: payload,
      );
    });
    _emitChange();
  }

  Future<void> saveCachedDesktopPosReport(PosReportSnapshot report) async {
    final db = await _db;
    await db.insert('pos_report_cache', {
      'id': 'outlet',
      'payloadJson': jsonEncode(report.toJson()),
      'updatedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _emitChange();
  }

  Future<PosReportSnapshot?> getCachedDesktopPosReport() async {
    final db = await _db;
    final rows = await db.query(
      'pos_report_cache',
      where: 'id = ?',
      whereArgs: ['outlet'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final raw = jsonDecode(rows.first['payloadJson'] as String);
    return raw is Map
        ? PosReportSnapshot.fromJson(Map<String, Object?>.from(raw))
        : null;
  }

  Future<PosReportSnapshot> desktopPosReport({int days = 1}) async {
    final db = await _db;
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: days)).toIso8601String();
    final orders = await db.query(
      'orders',
      where: 'createdAt >= ? AND status IN (?, ?)',
      whereArgs: [
        cutoff,
        OrderStatus.served.value,
        OrderStatus.completed.value,
      ],
    );
    final payments = await db.rawQuery(
      'SELECT paymentMethod, COALESCE(SUM(amount), 0) total '
      'FROM pos_settlements WHERE createdAt >= ? GROUP BY paymentMethod',
      [cutoff],
    );
    final audits = await db.rawQuery(
      'SELECT action, COUNT(*) total FROM pos_audit_events '
      'WHERE createdAt >= ? GROUP BY action',
      [cutoff],
    );
    final history = await db.query(
      'orders',
      where: 'createdAt >= ? AND status IN (?, ?)',
      whereArgs: [
        now.subtract(const Duration(days: 35)).toIso8601String(),
        OrderStatus.served.value,
        OrderStatus.completed.value,
      ],
    );
    final hourly = <int, double>{};
    final coversByHour = <int, int>{};
    final priorSameWeekdayHourly = <int, double>{};
    final priorSameWeekdays = <String>{};
    final items = <String, Map<String, Object?>>{};
    final staff = <String, Map<String, Object?>>{};
    var sales = 0.0;
    var covers = 0;
    for (final row in orders) {
      final total = (row['total'] as num?)?.toDouble() ?? 0;
      sales += total;
      covers += (row['covers'] as num?)?.toInt() ?? 0;
      final created = DateTime.tryParse(row['createdAt']?.toString() ?? '');
      if (created != null) {
        hourly[created.hour] = (hourly[created.hour] ?? 0) + total;
        coversByHour[created.hour] =
            (coversByHour[created.hour] ?? 0) +
            ((row['covers'] as num?)?.toInt() ?? 0);
      }
      final actor = row['createdByAccountId']?.toString() ?? 'unknown';
      final actorRow = staff.putIfAbsent(
        actor,
        () => {'accountId': actor, 'orders': 0, 'sales': 0.0},
      );
      actorRow['orders'] = (actorRow['orders'] as int) + 1;
      actorRow['sales'] = _roundMoney((actorRow['sales'] as double) + total);
    }
    for (final row in history) {
      final created = DateTime.tryParse(row['createdAt']?.toString() ?? '');
      if (created == null ||
          created.weekday != now.weekday ||
          _sameCalendarDay(created, now)) {
        continue;
      }
      priorSameWeekdays.add('${created.year}-${created.month}-${created.day}');
      priorSameWeekdayHourly[created.hour] =
          (priorSameWeekdayHourly[created.hour] ?? 0) +
          ((row['total'] as num?)?.toDouble() ?? 0);
    }
    if (priorSameWeekdays.isNotEmpty) {
      for (final hour in priorSameWeekdayHourly.keys.toList()) {
        priorSameWeekdayHourly[hour] = _roundMoney(
          priorSameWeekdayHourly[hour]! / priorSameWeekdays.length,
        );
      }
    }
    final orderItems = await db.rawQuery(
      'SELECT item.name, item.menuItemId, SUM(item.qty) qty, '
      'SUM(item.lineTotal) sales, '
      'SUM(item.lineTotal - (item.costPriceSnapshot * item.qty)) margin '
      'FROM order_items item JOIN orders ticket ON ticket.id = item.orderId '
      'WHERE ticket.createdAt >= ? AND ticket.status IN (?, ?) '
      'GROUP BY item.menuItemId, item.name ORDER BY qty DESC',
      [cutoff, OrderStatus.served.value, OrderStatus.completed.value],
    );
    for (final row in orderItems) {
      items[row['menuItemId']?.toString() ?? row['name']!.toString()] =
          Map<String, Object?>.from(row);
    }
    return PosReportSnapshot(
      sales: _roundMoney(sales),
      orders: orders.length,
      covers: covers,
      paymentSplit: {
        for (final row in payments)
          row['paymentMethod']?.toString() ?? 'unknown':
              (row['total'] as num?)?.toDouble() ?? 0,
      },
      hourlySales: hourly,
      coversByHour: coversByHour,
      auditCounts: {
        for (final row in audits)
          row['action']?.toString() ?? 'unknown':
              (row['total'] as num?)?.toInt() ?? 0,
      },
      priorSameWeekdayHourlyAverage: priorSameWeekdayHourly,
      items: items.values.toList(growable: false),
      staff: staff.values.toList(growable: false),
    );
  }

  bool _sameCalendarDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  // ── Inventory ─────────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getInventoryItems() async {
    final db = await _db;
    final rows = await db.query(
      'inventory_items',
      orderBy: 'category COLLATE NOCASE ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(InventoryItem.fromMap).toList(growable: false);
  }

  Future<List<InventorySupplier>> getInventorySuppliers({
    bool includeArchived = false,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'inventory_suppliers',
      where: includeArchived ? null : 'isActive = 1',
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(InventorySupplier.fromMap).toList(growable: false);
  }

  Future<void> upsertInventorySupplier(InventorySupplier supplier) async {
    final db = await _db;
    await db.insert(
      'inventory_suppliers',
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _emitChange();
  }

  Future<void> applyRemoteInventorySupplier(InventorySupplier supplier) =>
      upsertInventorySupplier(supplier);

  Future<InventoryItem?> getInventoryItemById(String id) async {
    final db = await _db;
    final rows = await db.query(
      'inventory_items',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return InventoryItem.fromMap(rows.first);
  }

  Future<void> upsertInventoryItem(InventoryItem item) async {
    final db = await _db;
    await db.insert(
      'inventory_items',
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _emitChange();
  }

  Future<void> deleteInventoryItem(String id) async {
    final db = await _db;
    await db.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
    _emitChange();
  }

  bool _inventoryRemoteWins(InventoryItem current, DateTime remoteUpdatedAt) {
    return remoteUpdatedAt.isAfter(current.updatedAt);
  }

  Future<InventoryItem?> applyRemoteInventoryItem(InventoryItem item) async {
    final db = await _db;
    InventoryItem? applied;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'inventory_items',
        where: 'id = ?',
        whereArgs: [item.id],
        limit: 1,
      );
      if (rows.isEmpty) {
        await txn.insert('inventory_items', item.toMap());
        applied = item;
        return;
      }
      final current = InventoryItem.fromMap(rows.first);
      if (!_inventoryRemoteWins(current, item.updatedAt)) return;
      await txn.insert(
        'inventory_items',
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      applied = item;
    });
    if (applied != null) _emitChange();
    return applied;
  }

  Future<void> applyRemoteStockAdjustment(StockAdjustment adjustment) async {
    final db = await _db;
    await db.insert(
      'stock_adjustments',
      adjustment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    _emitChange();
  }

  Future<void> applyRemoteDailyStockCount(DailyStockCount count) async {
    final db = await _db;
    await db.insert(
      'daily_stock_counts',
      count.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _emitChange();
  }

  static String _dateKey(DateTime dt) =>
      DateFormat('yyyy-MM-dd').format(DateTime(dt.year, dt.month, dt.day));

  Future<double> getInventoryPurchaseTotalForDate(DateTime day) async {
    final db = await _db;
    final key = _dateKey(day);
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(totalCostBdt), 0) AS total
      FROM stock_adjustments
      WHERE type = ? AND substr(createdAt, 1, 10) = ?
      ''',
      [AdjustmentType.restock.value, key],
    );
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<InventoryItem> adjustStock({
    required String inventoryItemId,
    required double delta,
    required String type,
    String note = '',
    double totalCostBdt = 0,
    String? supplierId,
    String supplierName = '',
    String reason = '',
    String billRef = '',
    String? createdByAccountId,
    String? createdByRole,
  }) async {
    final db = await _db;
    late InventoryItem updated;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'inventory_items',
        where: 'id = ?',
        whereArgs: [inventoryItemId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw DatabaseValidationException('Inventory item not found.');
      }
      final current = InventoryItem.fromMap(rows.first);
      final newQty = (current.quantity + delta).clamp(0.0, double.infinity);
      var costPerUnit = current.costPerUnit;
      final parsedType = AdjustmentType.parse(type);
      if (parsedType == AdjustmentType.restock &&
          delta > 0 &&
          totalCostBdt > 0) {
        costPerUnit = totalCostBdt / delta;
      }
      updated = current.copyWith(
        quantity: newQty,
        costPerUnit: costPerUnit,
        updatedAt: DateTime.now(),
      );
      await txn.update(
        'inventory_items',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [inventoryItemId],
      );
      final adjustment = StockAdjustment(
        id: _uuid.v4(),
        inventoryItemId: inventoryItemId,
        delta: delta,
        type: parsedType,
        note: note,
        totalCostBdt: totalCostBdt,
        supplierId: supplierId,
        supplierName: supplierName,
        reason: reason,
        billRef: billRef,
        createdByAccountId: createdByAccountId,
        createdByRole: createdByRole,
        createdAt: DateTime.now(),
      );
      await txn.insert('stock_adjustments', adjustment.toMap());
    });
    _emitChange();
    return updated;
  }

  Future<InventoryItem> setDailyStockCount({
    required String inventoryItemId,
    required double quantity,
    DateTime? onDate,
    String? createdByAccountId,
    String? createdByRole,
  }) async {
    final db = await _db;
    final day = onDate ?? DateTime.now();
    final countDate = _dateKey(day);
    late InventoryItem updated;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'inventory_items',
        where: 'id = ?',
        whereArgs: [inventoryItemId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw DatabaseValidationException('Inventory item not found.');
      }
      final current = InventoryItem.fromMap(rows.first);
      final clamped = quantity.clamp(0.0, double.infinity);
      updated = current.copyWith(quantity: clamped, updatedAt: DateTime.now());
      await txn.update(
        'inventory_items',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [inventoryItemId],
      );
      final existing = await txn.query(
        'daily_stock_counts',
        where: 'inventoryItemId = ? AND countDate = ?',
        whereArgs: [inventoryItemId, countDate],
        limit: 1,
      );
      final row = DailyStockCount(
        id: existing.isEmpty ? _uuid.v4() : existing.first['id'] as String,
        inventoryItemId: inventoryItemId,
        countDate: countDate,
        quantity: clamped,
        createdAt: DateTime.now(),
      );
      await txn.insert(
        'daily_stock_counts',
        row.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final previousQty = current.quantity;
      final delta = clamped - previousQty;
      if (delta.abs() > 0.0001) {
        await txn.insert(
          'stock_adjustments',
          StockAdjustment(
            id: _uuid.v4(),
            inventoryItemId: inventoryItemId,
            delta: delta,
            type: AdjustmentType.correction,
            note: 'End of day count',
            createdByAccountId: createdByAccountId,
            createdByRole: createdByRole,
            createdAt: DateTime.now(),
          ).toMap(),
        );
      }
    });
    _emitChange();
    return updated;
  }

  Future<double?> getDailyStockQuantity({
    required String inventoryItemId,
    required DateTime day,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'daily_stock_counts',
      where: 'inventoryItemId = ? AND countDate = ?',
      whereArgs: [inventoryItemId, _dateKey(day)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return (rows.first['quantity'] as num?)?.toDouble();
  }

  Future<List<StockAdjustment>> getStockAdjustments(
    String inventoryItemId, {
    int limit = 50,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'stock_adjustments',
      where: 'inventoryItemId = ?',
      whereArgs: [inventoryItemId],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map(StockAdjustment.fromMap).toList(growable: false);
  }

  void _emitChange() {
    if (!_changeController.isClosed) {
      _changeController.add(null);
    }
  }
}
