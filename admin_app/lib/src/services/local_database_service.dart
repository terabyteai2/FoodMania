import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../models/inventory_item.dart';
import '../models/menu_item.dart';
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
      version: 11,
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

    final orderRows = await db.query(
      'orders',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'sequenceNo DESC, createdAt DESC',
      limit: limit,
      offset: offset,
    );
    if (orderRows.isEmpty) return const <OrderModel>[];

    final orderIds = <String>[for (final row in orderRows) row['id'] as String];
    final itemsByOrderId = await _getOrderItemsForIds(db, orderIds);
    return [
      for (final row in orderRows)
        OrderModel.fromMap(
          row,
          items: itemsByOrderId[row['id'] as String] ?? const <OrderItem>[],
        ),
    ];
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

  Future<OrderModel> createOrder({
    required List<OrderRequestItem> requestedItems,
    String? id,
    String? customerName,
    String? tableNo,
    String? note,
    String? deliveryAddress,
    String? mobileNumber,
    OrderServiceType? serviceType,
    int? covers,
    OrderPaymentMethod? paymentMethod,
    OrderSource source = OrderSource.cloud,
    String? createdByAccountId,
    String? createdByRole,
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

        final lineTotal = menuItem.price * requestItem.qty;
        subtotal += lineTotal;
        orderItems.add(
          OrderItem(
            id: _uuid.v4(),
            orderId: orderId,
            menuItemId: menuItem.id,
            name: menuItem.name,
            nameEn: menuItem.nameEn,
            nameBn: menuItem.nameBn,
            qty: requestItem.qty,
            price: menuItem.price,
            lineTotal: lineTotal,
          ),
        );
      }

      final roundedSubtotal = _roundMoney(subtotal);
      const vatRatePercent = 0.0;
      const vatAmount = 0.0;
      final total = roundedSubtotal;

      final model = OrderModel(
        id: orderId,
        orderNo: _buildOrderNumber(now),
        sequenceNo: await _nextOrderSequence(txn),
        customerName: _cleanNullable(customerName),
        tableNo: _cleanNullable(tableNo),
        note: _cleanNullable(note),
        deliveryAddress: _cleanNullable(deliveryAddress),
        mobileNumber: _cleanNullable(mobileNumber),
        createdByAccountId: _cleanNullable(createdByAccountId),
        createdByRole: _cleanNullable(createdByRole),
        serviceType: serviceType,
        covers: covers?.clamp(1, 999).toInt(),
        paymentMethod: paymentMethod,
        source: source,
        status: initialStatus,
        subtotal: roundedSubtotal,
        vatRatePercent: vatRatePercent,
        vatAmount: vatAmount,
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
              : await _nextOrderSequence(txn),
        );
        await txn.insert('orders', next.toMap());
        for (final item in next.items) {
          await txn.insert('order_items', item.toMap());
        }
        applied = next;
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

      final currentItemsByMenuId = <String, OrderItem>{
        for (final item in currentItems) item.menuItemId: item,
      };

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
        final lineTotal = menuItem.price * request.qty;
        subtotal += lineTotal;
        final existing = currentItemsByMenuId[menuItem.id];
        newItems.add(
          OrderItem(
            id: existing?.id ?? _uuid.v4(),
            orderId: id,
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

      final roundedSubtotal = _roundMoney(subtotal);
      final total = roundedSubtotal;

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

  Future<void> queueServerConfigSync({
    required String serverId,
    required Map<String, Object?> payload,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await _insertSyncEvent(
        txn,
        entityType: 'server_config',
        entityId: serverId,
        action: 'update',
        payload: payload,
      );
    });
    _emitChange();
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
    });
    _emitChange();
  }

  Future<List<PosNotification>> getNotifications({int limit = 100}) async {
    final db = await _db;
    final rows = await db.query(
      'notifications',
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
        orderNo TEXT NOT NULL UNIQUE,
        source TEXT NOT NULL DEFAULT 'cloud',
        customerName TEXT,
        tableNo TEXT,
        note TEXT,
        deliveryAddress TEXT,
        mobileNumber TEXT,
        createdByAccountId TEXT,
        createdByRole TEXT,
        serviceType TEXT,
        covers INTEGER,
        paymentMethod TEXT,
        subtotal REAL,
        vatRatePercent REAL,
        vatAmount REAL,
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
        FOREIGN KEY(orderId) REFERENCES orders(id) ON DELETE CASCADE
      )
    ''');

    await _createSyncTable(db);
    await _createInventoryTables(db);
    await _createNotificationTable(db);
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
    await _migrateOrderItemsBilingualV9(db);
    await _createSyncTable(db);
    await _createInventoryTables(db);
    await _migrateInventoryV6(db);
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
        createdAt TEXT NOT NULL,
        FOREIGN KEY(inventoryItemId) REFERENCES inventory_items(id) ON DELETE CASCADE
      )
    ''');
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

  Future<int> _nextOrderSequence(DatabaseExecutor db) async {
    final rows = await db.rawQuery(
      'SELECT COALESCE(MAX(sequenceNo), 0) + 1 AS nextSequence FROM orders',
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

  // ── Inventory ─────────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getInventoryItems() async {
    final db = await _db;
    final rows = await db.query(
      'inventory_items',
      orderBy: 'category COLLATE NOCASE ASC, name COLLATE NOCASE ASC',
    );
    return rows.map(InventoryItem.fromMap).toList(growable: false);
  }

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
