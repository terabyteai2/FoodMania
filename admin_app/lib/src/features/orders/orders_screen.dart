import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scope.dart';
import '../../core/enums/business_tier.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/menu_item.dart';
import '../../models/order_item.dart';
import '../../models/order_model.dart';
import '../../models/order_service_type.dart';
import '../../models/order_source.dart';
import '../../models/order_status.dart';
import '../../models/pos_notification.dart';
import '../desktop_pos/widgets/menu_line_customizer.dart';
import 'menu_order_widgets.dart';
import 'order_list_filters.dart';

Future<void> openNewOrderForm(
  BuildContext context, {
  VoidCallback? onCreated,
  String? initialMenuItemId,
  Map<String, int>? initialMenuItemQuantities,
  List<DesktopMenuLineSelection>? initialCartLines,
  OrderServiceType? initialServiceType,
  String? initialTableNo,
  bool startAtMenu = false,
  bool startAtReview = false,
}) async {
  final app = AppScope.of(context);
  final menuItems = app.menuItems.where((i) => i.isAvailable).toList();
  final tableCount = app.serverConfig.tableCount;

  final dineInOpenOrders = app
      .ordersFor()
      .where((o) => o.status.isOpen && o.serviceType == OrderServiceType.dineIn)
      .toList();

  final tier = TierScope.of(context);
  final counterMode = tier == BusinessTier.simple;

  final created = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _NewOrderPage(
        menuItems: menuItems,
        itemPopularity: app.itemPopularity,
        tableCount: tableCount,
        dineInOpenOrders: dineInOpenOrders,
        counterMode: counterMode,
        initialMenuItemId: initialMenuItemId,
        initialMenuItemQuantities: initialMenuItemQuantities,
        initialCartLines: initialCartLines,
        initialServiceType: initialServiceType,
        initialTableNo: initialTableNo,
        startAtMenu: startAtMenu,
        startAtReview: startAtReview,
        onCreateOrder: (result) async {
          final order = await app.createManualOrder(
            requestedItems: result.items,
            tableNo: result.tableNo,
            note: result.note,
            serviceType: result.serviceType,
            customerName: result.customerName,
            paymentMethod: null,
          );
          // Delivery contact details aren't part of createManualOrder; persist
          // them right after so the KOT/bill and order card show recipient info.
          if (result.serviceType == OrderServiceType.delivery &&
              ((result.deliveryAddress ?? '').isNotEmpty ||
                  (result.mobileNumber ?? '').isNotEmpty ||
                  (result.customerName ?? '').isNotEmpty)) {
            await app.updateOrderDetails(
              order.id,
              serviceType: OrderServiceType.delivery,
              customerName: result.customerName,
              deliveryAddress: result.deliveryAddress,
              mobileNumber: result.mobileNumber,
            );
          }
          final shouldPrint =
              app.orderPrinterSideEffectsEnabled &&
              app.isManager &&
              !app.printerState.autoPrintEnabled &&
              app.printerState.hasSelectedPrinter &&
              !app.printerService.hasPrintedOrder(order.id);
          if (shouldPrint) {
            await app.printOrderTicket(order);
          }
          return order;
        },
      ),
    ),
  );
  if (created == true) onCreated?.call();
}

Future<void> openOrderCreatedPage(
  BuildContext context, {
  required OrderModel order,
  String serviceLabel = 'Parcel',
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          OrderCreatedPage(order: order, serviceLabel: serviceLabel),
    ),
  );
}

class OrderCreatedPage extends StatefulWidget {
  const OrderCreatedPage({
    required this.order,
    this.serviceLabel = 'Parcel',
    super.key,
  });

  final OrderModel order;
  final String serviceLabel;

  @override
  State<OrderCreatedPage> createState() => _OrderCreatedPageState();
}

class _OrderCreatedPageState extends State<OrderCreatedPage> {
  bool _printingKot = false;

  Future<void> _printKot() async {
    if (_printingKot) return;
    setState(() => _printingKot = true);
    final app = AppScope.of(context);
    final ok = await app.printOrderTicket(widget.order);
    if (!mounted) return;
    setState(() => _printingKot = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 72),
          content: TfText(
            app.strings.ticketPrinted(widget.order.displaySequence),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _WizardHeader(
              step: 3,
              totalSteps: 4,
              tableLabel: widget.serviceLabel,
              onClose: () => Navigator.pop(context),
              onBack: null,
              counterMode: true,
            ),
            const _StepIndicator(step: 3, total: 4),
            Expanded(
              child: _OrderCreatedStep(
                order: widget.order,
                serviceLabel: widget.serviceLabel,
                total: widget.order.total,
                printingKot: _printingKot,
                onPrintKot: () => unawaited(_printKot()),
                onDone: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({this.onNavigateToTarget, super.key});

  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _searchController = TextEditingController();
  int? _lastPendingCount;
  OrderListFilters _filters = OrderListFilters.none;
  _OrdersDerivation? _cachedDerivation;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final rawOrders = app.ordersFor();
    final language = app.language;
    final searchQuery = _searchController.text.trim();
    final derived = _deriveOrders(rawOrders, _filters, searchQuery, language);
    final ongoingOrders = derived.ongoingOrders;
    final completedOrders = derived.completedOrders;

    final text = app.strings;
    final canCreate = app.menuItems.any((i) => i.isAvailable);
    final pendingCount = _pendingOrders(ongoingOrders).length;
    final ongoingShortcut = _emptyShortcut(
      context: context,
      currentFiltered: ongoingOrders,
      currentSearchBase: derived.searchBaseOngoing,
      currentUnfiltered: derived.unfilteredOngoing,
      searchActive: searchQuery.isNotEmpty,
    );
    final completedShortcut = _emptyShortcut(
      context: context,
      currentFiltered: completedOrders,
      currentSearchBase: derived.searchBaseCompleted,
      currentUnfiltered: derived.unfilteredCompleted,
      searchActive: searchQuery.isNotEmpty,
    );
    _syncTabWithPendingOrders(pendingCount, ongoingOrders.length);
    final hasAnyOpenOrders = ongoingOrders.isNotEmpty;
    final floorTotal = ongoingOrders.fold<num>(0, (sum, o) => sum + o.total);

    return Scaffold(
      backgroundColor: PosColors.background,
      floatingActionButton: canCreate && hasAnyOpenOrders
          ? TfFab(
              tooltip: text.newOrder,
              onPressed: () => openNewOrderForm(
                context,
                onCreated: () => _tabs.index = 0,
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              onNavigateToOrders: () {},
              onNavigateToTarget: widget.onNavigateToTarget,
            ),
            if (hasAnyOpenOrders)
              _OrdersSummaryRow(
                floorTotal: floorTotal,
                pendingCount: pendingCount,
                ongoingCount: ongoingOrders.length,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TfSearchField(
                      controller: _searchController,
                      hintText: text.orderSearchHint,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TfIconButton(
                    icon: Icons.tune_rounded,
                    tooltip: text.filterOrders,
                    dark: _filters.isActive,
                    onPressed: () => _openOrderFilters(context),
                  ),
                ],
              ),
            ),
            _TabStrip(
              controller: _tabs,
              ongoingCount: ongoingOrders.length,
              completedCount: completedOrders.length,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _OrderList(
                    orders: ongoingOrders,
                    emptyTitle: text.quietForNow,
                    canCreate: canCreate,
                    onCreate: () => openNewOrderForm(
                      context,
                      onCreated: () => _tabs.index = 0,
                    ),
                    shortcut: ongoingShortcut,
                    searchQuery: searchQuery,
                    onPrintBill: (o) => _printBill(context, o),
                    onPrintKot: (o) => _printKot(context, o),
                    onOpen: (o) =>
                        o.status.adminStatus == OrderStatus.pending
                            ? _showPendingOrderDetails(context, o)
                            : _openEditOrderSheet(context, o),
                    onStatus: (o, s) => _changeStatus(context, o, s),
                    hasMore: app.hasMoreOrders,
                    loadingMore: app.loadingMoreOrders,
                    onLoadMore: app.loadMoreOrders,
                  ),
                  _OrderList(
                    orders: completedOrders,
                    emptyTitle: text.noCompletedOrders,
                    canCreate: canCreate,
                    onCreate: () => openNewOrderForm(
                      context,
                      onCreated: () => _tabs.index = 0,
                    ),
                    shortcut: completedShortcut,
                    searchQuery: searchQuery,
                    onPrintBill: (o) => _printBill(context, o),
                    onPrintKot: (o) => _printKot(context, o),
                    onOpen: null,
                    onStatus: (o, s) => _changeStatus(context, o, s),
                    onCompletedLongPress: (o) =>
                        _showCompletedOrderActions(context, o),
                    hasMore: app.hasMoreOrders,
                    loadingMore: app.loadingMoreOrders,
                    onLoadMore: app.loadMoreOrders,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _sortOrders(OrderModel a, OrderModel b) {
    final priority = a.status.priority.compareTo(b.status.priority);
    if (priority != 0) return priority;
    return b.createdAt.compareTo(a.createdAt);
  }

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

    final sorted = rows.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final sample = sorted
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

  List<OrderModel> _pendingOrders(List<OrderModel> orders) {
    return orders
        .where((o) => o.status.adminStatus == OrderStatus.pending)
        .toList(growable: false);
  }

  /// Ongoing = open orders (pending + accepted; preparing/ready map to accepted
  /// via [OrderStatus.adminStatus]). Served and cancelled are excluded.
  List<OrderModel> _ongoingOrders(List<OrderModel> orders) {
    return orders
        .where(
          (o) =>
              o.status.adminStatus == OrderStatus.pending ||
              o.status.adminStatus == OrderStatus.accepted,
        )
        .toList(growable: false);
  }

  /// Completed = terminal paid orders (legacy "served" maps to completed).
  List<OrderModel> _completedOrders(List<OrderModel> orders) {
    return orders
        .where((o) => o.status.adminStatus == OrderStatus.completed)
        .toList(growable: false);
  }

  /// Memoized derivation of the six filtered/sorted views needed by [build].
  /// Cache key is the identity of [raw] + [filters] plus the search/language
  /// strings, so unchanged inputs (the common case during sync churn or tab
  /// switches) skip ~8 list allocations per frame.
  _OrdersDerivation _deriveOrders(
    List<OrderModel> raw,
    OrderListFilters filters,
    String searchQuery,
    AppLanguage language,
  ) {
    final cached = _cachedDerivation;
    if (cached != null &&
        identical(cached.raw, raw) &&
        identical(cached.filters, filters) &&
        cached.searchQuery == searchQuery &&
        cached.language == language) {
      return cached;
    }
    final filterMatched = raw
        .where((o) => filters.matches(o))
        .toList(growable: false);
    final allOrders = filterMatched
        .where((o) => _matchesOrderSearch(o, searchQuery, language))
        .toList(growable: false);
    final ongoingOrders = _ongoingOrders(allOrders)..sort(_sortOrders);
    final completedOrders = _completedOrders(allOrders)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (kDebugMode) {
      debugPrint(
        '[QB-ORDERS-DIAG] derive raw=${raw.length} '
        'filterMatched=${filterMatched.length} '
        'afterSearch=${allOrders.length} '
        'ongoing=${ongoingOrders.length} completed=${completedOrders.length} '
        'unfilteredOngoing=${_ongoingOrders(raw).length} '
        'unfilteredCompleted=${_completedOrders(raw).length} '
        'searchBaseOngoing=${_ongoingOrders(filterMatched).length} '
        'searchBaseCompleted=${_completedOrders(filterMatched).length} '
        'query="$searchQuery" filtersActive=${filters.isActive} '
        'dateRange=${filters.dateRange.name} source=${filters.source?.name} '
        '${_ordersDiagSummary(raw)}',
      );
      // When filters/search hide everything but raw had orders, dump statuses
      // so we can see whether it's a status-mapping vs filter problem.
      if (allOrders.isEmpty && raw.isNotEmpty) {
        debugPrint(
          '[QB-ORDERS-DIAG] all hidden — raw statuses: '
          '${raw.map((o) => '${o.id}:${o.status.name}/${o.status.adminStatus.name}').join(', ')}',
        );
      }
      final rawOpen = raw.where((o) => o.status.isOpen).toList();
      if (rawOpen.isNotEmpty && ongoingOrders.isEmpty) {
        debugPrint(
          '[QB-ORDERS-DIAG] SUSPICIOUS_EMPTY_OPEN_UI '
          'rawOpen=${rawOpen.length} filtersActive=${filters.isActive} '
          'dateRange=${filters.dateRange.name} source=${filters.source?.name} '
          'query="$searchQuery" ${_ordersDiagSummary(rawOpen, sampleLimit: 10)}',
        );
      }
    }
    final derived = _OrdersDerivation(
      raw: raw,
      filters: filters,
      searchQuery: searchQuery,
      language: language,
      filterMatched: filterMatched,
      allOrders: allOrders,
      unfilteredOngoing: _ongoingOrders(raw),
      unfilteredCompleted: _completedOrders(raw),
      searchBaseOngoing: _ongoingOrders(filterMatched),
      searchBaseCompleted: _completedOrders(filterMatched),
      ongoingOrders: ongoingOrders,
      completedOrders: completedOrders,
    );
    _cachedDerivation = derived;
    return derived;
  }

  _EmptyShortcut? _emptyShortcut({
    required BuildContext context,
    required List<OrderModel> currentFiltered,
    required List<OrderModel> currentSearchBase,
    required List<OrderModel> currentUnfiltered,
    required bool searchActive,
  }) {
    if (currentFiltered.isNotEmpty) return null;
    final text = AppScope.of(context).strings;
    if (searchActive && currentSearchBase.isNotEmpty) {
      return _EmptyShortcut(
        label: text.clearSearch,
        onTap: () => setState(_searchController.clear),
      );
    }
    if (_filters.isActive && currentUnfiltered.isNotEmpty) {
      return _EmptyShortcut(
        label: text.clearFiltersShortcut,
        onTap: () => setState(() => _filters = OrderListFilters.none),
      );
    }
    return null;
  }

  bool _matchesOrderSearch(
    OrderModel order,
    String query,
    AppLanguage language,
  ) {
    final normalizedQuery = _normalizeOrderSearch(query);
    if (normalizedQuery.isEmpty) return true;
    final fields = <String>[
      order.id,
      order.orderNo,
      order.displaySequence,
      '${order.sequenceNo}',
      if ((order.customerName ?? '').trim().isNotEmpty) order.customerName!,
      if ((order.tableNo ?? '').trim().isNotEmpty) order.tableNo!,
      if ((order.note ?? '').trim().isNotEmpty) order.note!,
      for (final item in order.items) ...[
        item.name,
        item.nameEn,
        item.nameBn,
        item.localizedName(language),
      ],
    ];
    return _normalizeOrderSearch(fields.join(' ')).contains(normalizedQuery);
  }

  String _normalizeOrderSearch(String value) {
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    var normalized = value.toLowerCase().trim();
    for (var i = 0; i < bn.length; i++) {
      normalized = normalized.replaceAll(bn[i], '$i');
    }
    return normalized.replaceAll('#', '').replaceAll(RegExp(r'\s+'), ' ');
  }

  void _syncTabWithPendingOrders(int pendingCount, int ongoingCount) {
    final previousPendingCount = _lastPendingCount;
    _lastPendingCount = pendingCount;
    if (kDebugMode) {
      debugPrint(
        '[QB-ORDERS-DIAG] syncTab previousPending=$previousPendingCount '
        'pending=$pendingCount ongoing=$ongoingCount tab=${_tabs.index}',
      );
    }

    // Only auto-switch on a real arrival, not on every rebuild. When a new
    // pending order lands while the user is on Completed, jump to Ongoing so
    // they see it (pending + accepted now share the Ongoing list).
    if (previousPendingCount == null) return;
    final hasNewPendingOrder =
        pendingCount > previousPendingCount && _tabs.index != 0;
    if (!hasNewPendingOrder) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_tabs.index != 0) {
        if (kDebugMode) {
          debugPrint(
            '[QB-ORDERS-DIAG] syncTab animate from=${_tabs.index} to=0 '
            'hasNewPendingOrder=$hasNewPendingOrder',
          );
        }
        _tabs.index = 0;
      }
    });
  }

  Future<void> _openOrderFilters(BuildContext context) async {
    final app = AppScope.of(context);
    final result = await showModalBottomSheet<OrderListFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _OrdersFilterSheet(initial: _filters, strings: app.strings),
    );
    if (result != null && mounted) {
      setState(() => _filters = result);
    }
  }

  Future<void> _printKot(BuildContext context, OrderModel order) async {
    final app = AppScope.of(context);
    if (!app.isManager) return;
    final text = app.strings;
    final ok = await app.printOrderTicket(order);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TfText(text.kotPrinted(order.displaySequence))),
      );
    }
  }

  Future<void> _printBill(BuildContext context, OrderModel order) async {
    final app = AppScope.of(context);
    if (!app.isManager) return;
    final text = app.strings;
    // Spec: Print Bill marks the order completed so it moves to the Completed
    // tab. Mirrors the prototype's billAndComplete.
    if (order.status.adminStatus != OrderStatus.completed) {
      await app.updateOrderStatus(order.id, OrderStatus.completed);
    }
    if (!context.mounted) return;
    final ok = await app.printCustomerInvoice(order);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TfText(text.billPrinted(order.displaySequence))),
      );
    }
  }

  Future<void> _changeStatus(
    BuildContext context,
    OrderModel order,
    OrderStatus status,
  ) async {
    final app = AppScope.of(context);
    if (!app.isManager) return;
    await app.updateOrderStatus(order.id, status);
  }

  Future<void> _openEditOrderSheet(BuildContext context, OrderModel order) =>
      openEditOrderSheet(context, order);

  Future<void> _showCompletedOrderActions(
    BuildContext context,
    OrderModel order,
  ) async {
    final text = AppScope.of(context).strings;
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: PosColors.slate),
              title: TfText(text.isBn ? 'সম্পাদনা' : 'Edit'),
              onTap: () {
                Navigator.pop(context);
                _openEditOrderSheet(context, order);
              },
            ),
            Divider(height: 1, color: PosColors.line),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: PosColors.danger,
              ),
              title: TfText(
                text.isBn ? 'মুছে ফেলুন' : 'Delete',
                style: const TextStyle(color: PosColors.danger),
              ),
              onTap: () {
                Navigator.pop(context);
                _changeStatus(context, order, OrderStatus.rejected);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPendingOrderDetails(
    BuildContext context,
    OrderModel order,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PendingOrderDetailSheet(
        order: order,
        onAccept: () {
          Navigator.pop(context);
          _changeStatus(context, order, OrderStatus.accepted);
        },
        onReject: () {
          Navigator.pop(context);
          _changeStatus(context, order, OrderStatus.rejected);
        },
      ),
    );
  }
}

/// Opens the order edit sheet for [order] (manager+ only) and applies the
/// result. Reused by the Orders list and the Tables/FOH screen.
Future<void> openEditOrderSheet(BuildContext context, OrderModel order) async {
  final app = AppScope.of(context);
  if (!app.isManager) return;
  final result = await showModalBottomSheet<_OrderEditResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditOrderSheet(order: order),
  );
  if (result == null || !context.mounted) return;
  if (result.delete) {
    await app.deleteOrder(order.id);
    return;
  }
  await app.updateOrderDetails(
    order.id,
    serviceType: result.serviceType,
    tableNo: result.tableNo,
    note: result.note,
    customerName: result.customerName,
    deliveryAddress: result.deliveryAddress,
    mobileNumber: result.mobileNumber,
  );
  if (result.itemsChanged && result.items != null && result.items!.isNotEmpty) {
    try {
      await app.updateOrderItems(order.id, result.items!);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText('$error')));
    }
  }
  final reasons = <String>[];
  final hasEdit = result.serviceType != (order.serviceType ?? OrderServiceType.dineIn) ||
      result.tableNo != order.tableNo ||
      result.customerName != order.customerName ||
      result.deliveryAddress != order.deliveryAddress ||
      result.mobileNumber != order.mobileNumber;
  if (result.itemsChanged) reasons.add('items modified');
  if (hasEdit && !result.itemsChanged) reasons.add('order details updated');
  if (reasons.isNotEmpty) {
    try {
      await app.auditOrderAction(
        orderId: order.id,
        action: 'comp',
        reason: reasons.join('; '),
        shiftId: order.shiftId,
      );
    } catch (_) {}
  }
}

/// Cached output of [_OrdersScreenState._deriveOrders]. Stores the inputs
/// alongside the derived lists so the next build can verify the cache is
/// still valid via identity / value comparison.
class _OrdersDerivation {
  const _OrdersDerivation({
    required this.raw,
    required this.filters,
    required this.searchQuery,
    required this.language,
    required this.filterMatched,
    required this.allOrders,
    required this.unfilteredOngoing,
    required this.unfilteredCompleted,
    required this.searchBaseOngoing,
    required this.searchBaseCompleted,
    required this.ongoingOrders,
    required this.completedOrders,
  });

  final List<OrderModel> raw;
  final OrderListFilters filters;
  final String searchQuery;
  final AppLanguage language;
  final List<OrderModel> filterMatched;
  final List<OrderModel> allOrders;
  final List<OrderModel> unfilteredOngoing;
  final List<OrderModel> unfilteredCompleted;
  final List<OrderModel> searchBaseOngoing;
  final List<OrderModel> searchBaseCompleted;
  final List<OrderModel> ongoingOrders;
  final List<OrderModel> completedOrders;
}

// ─────────────────────────────────────────────────────────────────────────────
// FAB
// ─────────────────────────────────────────────────────────────────────────────

/// QuickBytes Orders-home header (spec §4.1): brand mark + product + location
/// on the left, TopActions (Messages w/ escalation badge for manager+, and the
/// notification bell) on the right. No page-navigation buttons here — the
/// filter lives next to the search field, primary actions in the bottom bar.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onNavigateToOrders,
    required this.onNavigateToTarget,
  });

  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return AppPageHeader(
      title: text.orders,
      brand: true,
      onNavigateToOrders: onNavigateToOrders,
      onNavigateToTarget: onNavigateToTarget,
    );
  }
}

/// Calm summary row: "On the floor ৳X" + "N to accept · M ongoing" (spec §4.1).
class _OrdersSummaryRow extends StatelessWidget {
  const _OrdersSummaryRow({
    required this.floorTotal,
    required this.pendingCount,
    required this.ongoingCount,
  });

  final num floorTotal;
  final int pendingCount;
  final int ongoingCount;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    if (kDebugMode) {
      debugPrint(
        '[QB-ORDERS-DIAG] summaryRow build '
        'pending=$pendingCount accepted=$ongoingCount floorTotal=$floorTotal',
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TfCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TfText(
                      text.onTheFloorNow,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PosColors.muted,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TfText(
                      tfFormatCurrency(context, floorTotal),
                      style: TextStyle(
                        fontFamily: tfFontFamily(context),
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: PosColors.text,
                        height: 1.05,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TfCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        TfText(
                          tfFormatNumber(context, pendingCount),
                          style: TextStyle(
                            fontFamily: tfFontFamily(context),
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: pendingCount > 0
                                ? PosColors.accentStrong
                                : PosColors.text,
                            height: 1.0,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: TfText(
                            text.toAcceptLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PosColors.muted,
                              height: 1.15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    TfText(
                      text.ongoingCount(ongoingCount),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: PosColors.muted,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order filters sheet
// ─────────────────────────────────────────────────────────────────────────────

class _OrdersFilterSheet extends StatefulWidget {
  const _OrdersFilterSheet({required this.initial, required this.strings});

  final OrderListFilters initial;
  final AppStrings strings;

  @override
  State<_OrdersFilterSheet> createState() => _OrdersFilterSheetState();
}

class _OrdersFilterSheetState extends State<_OrdersFilterSheet> {
  late OrderDateRange _dateRange;
  OrderSource? _source;

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initial.dateRange;
    _source = widget.initial.source;
  }

  String _dateLabel(OrderDateRange range) {
    final t = widget.strings;
    switch (range) {
      case OrderDateRange.all:
        return t.allTime;
      case OrderDateRange.today:
        return t.today;
      case OrderDateRange.yesterday:
        return t.yesterday;
      case OrderDateRange.last7Days:
        return t.last7Days;
      case OrderDateRange.last30Days:
        return t.last30Days;
      case OrderDateRange.last3Months:
        return t.last3Months;
      case OrderDateRange.last6Months:
        return t.last6Months;
      case OrderDateRange.last12Months:
        return t.last12Months;
    }
  }

  OrderListFilters get _draft =>
      OrderListFilters(dateRange: _dateRange, source: _source);

  @override
  Widget build(BuildContext context) {
    final t = widget.strings;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(PosRadii.card),
        ),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: PosColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            TfText(
              t.filterOrders,
              style: TextStyle(
                fontFamily: tfFontFamily(context),
                fontWeight: FontWeight.w700,
                fontSize: 22,
                color: PosColors.text,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 20),
            TfText(
              t.filterByDate,
              style: TextStyle(
                fontFamily: tfFontFamily(context),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: PosColors.textTer,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: OrderDateRange.values.map((range) {
                final selected = _dateRange == range;
                return TfChip(
                  label: _dateLabel(range),
                  active: selected,
                  small: true,
                  onTap: () => setState(() => _dateRange = range),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            TfText(
              t.filterBySource,
              style: TextStyle(
                fontFamily: tfFontFamily(context),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: PosColors.textTer,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                TfChip(
                  label: t.allChannels,
                  active: _source == null,
                  small: true,
                  onTap: () => setState(() => _source = null),
                ),
                ...OrderSource.values.map((source) {
                  final selected = _source == source;
                  return TfChip(
                    label: t.orderSourceLabel(source),
                    active: selected,
                    small: true,
                    onTap: () =>
                        setState(() => _source = selected ? null : source),
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TfButton(
                    label: t.resetFilters,
                    variant: TfButtonVariant.paper,
                    onPressed: () {
                      setState(() {
                        _dateRange = OrderDateRange.all;
                        _source = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TfButton(
                    label: t.applyFilters,
                    onPressed: () => Navigator.pop(context, _draft),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pill tab strip
// ─────────────────────────────────────────────────────────────────────────────

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.controller,
    required this.ongoingCount,
    required this.completedCount,
  });

  final TabController controller;
  final int ongoingCount;
  final int completedCount;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return TfTabs(
            activeIndex: controller.index,
            onChanged: (i) => controller.index = i,
            items: [
              TfTabItem(label: text.ongoingTab, count: ongoingCount),
              TfTabItem(label: text.completedTab, count: completedCount),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order list
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyShortcut {
  const _EmptyShortcut({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.emptyTitle,
    required this.canCreate,
    required this.onCreate,
    required this.shortcut,
    required this.searchQuery,
    required this.onPrintBill,
    required this.onPrintKot,
    required this.onOpen,
    required this.onStatus,
    this.onCompletedLongPress,
    this.hasMore = false,
    this.loadingMore = false,
    this.onLoadMore,
  });

  final List<OrderModel> orders;
  final String emptyTitle;
  final bool canCreate;
  final VoidCallback onCreate;
  final _EmptyShortcut? shortcut;
  final String searchQuery;
  final void Function(OrderModel) onPrintBill;
  final void Function(OrderModel) onPrintKot;
  final void Function(OrderModel)? onOpen;
  final void Function(OrderModel, OrderStatus) onStatus;
  final void Function(OrderModel)? onCompletedLongPress;

  /// Whether the underlying `orders` list has more pages available.
  final bool hasMore;

  /// Whether a load-more fetch is currently in flight.
  final bool loadingMore;

  /// Fired when scrolling near the bottom; harmless when `hasMore` is false.
  final Future<void> Function()? onLoadMore;

  bool get _showFooter => hasMore && onLoadMore != null;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          '[QB-ORDERS-DIAG] orderList empty rendered '
          'title="$emptyTitle" hasMore=$hasMore loadingMore=$loadingMore '
          'shortcut=${shortcut?.label ?? 'none'} '
          'searchActive=${searchQuery.trim().isNotEmpty} '
          'canCreate=$canCreate',
        );
      }
      return _SmartOrdersEmptyState(
        title: emptyTitle,
        canCreate: canCreate,
        onCreate: onCreate,
        shortcut: shortcut,
        searchQuery: searchQuery,
      );
    }

    final itemCount = orders.length + (_showFooter ? 1 : 0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final useGrid = constraints.maxWidth >= 700;
        final notification = NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (!_showFooter || loadingMore) return false;
            if (notification is ScrollUpdateNotification) {
              final metrics = notification.metrics;
              if (metrics.maxScrollExtent - metrics.pixels < 600) {
                onLoadMore?.call();
              }
            }
            return false;
          },
          child: useGrid
              ? GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 480,
                    mainAxisExtent: 304,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: itemCount,
                  itemBuilder: (_, i) {
                    if (_showFooter && i == orders.length) {
                      return _LoadMoreFooter(loading: loadingMore);
                    }
                    return _OrderCard(
                      order: orders[i],
                      onPrintBill: () => onPrintBill(orders[i]),
                      onPrintKot: () => onPrintKot(orders[i]),
                      onOpen: onOpen == null ? null : () => onOpen!(orders[i]),
                      onStatus: (s) => onStatus(orders[i], s),
                      onCompletedLongPress: onCompletedLongPress == null
                          ? null
                          : () => onCompletedLongPress!(orders[i]),
                    );
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                  itemCount: itemCount,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (_showFooter && i == orders.length) {
                      return _LoadMoreFooter(loading: loadingMore);
                    }
                    return _OrderCard(
                      order: orders[i],
                      onPrintBill: () => onPrintBill(orders[i]),
                      onPrintKot: () => onPrintKot(orders[i]),
                      onOpen: onOpen == null ? null : () => onOpen!(orders[i]),
                      onStatus: (s) => onStatus(orders[i], s),
                      onCompletedLongPress: onCompletedLongPress == null
                          ? null
                          : () => onCompletedLongPress!(orders[i]),
                    );
                  },
                ),
        );
        return notification;
      },
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({required this.loading});
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SmartOrdersEmptyState extends StatelessWidget {
  const _SmartOrdersEmptyState({
    required this.title,
    required this.canCreate,
    required this.onCreate,
    required this.shortcut,
    required this.searchQuery,
  });

  final String title;
  final bool canCreate;
  final VoidCallback onCreate;
  final _EmptyShortcut? shortcut;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;

    final isSearchEmpty = searchQuery.trim().isNotEmpty;
    final titleText = isSearchEmpty ? text.noOrderSearchResultsTitle : title;
    final messageText = isSearchEmpty
        ? text.noOrderSearchResultsMessage(searchQuery.trim())
        : text.quietOrdersMessage;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 96)
                  .clamp(260, 460)
                  .toDouble(),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: PosColors.primarySoft,
                    borderRadius: BorderRadius.circular(PosRadii.xl),
                    border: Border.all(color: PosColors.line, width: 1),
                  ),
                  child: const Icon(
                    TfNavIcon.orders,
                    color: PosColors.primaryDark,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 18),
                TfText(
                  titleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PosColors.slate,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                TfText(
                  messageText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: PosColors.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
                if (!canCreate) ...[
                  const SizedBox(height: 12),
                  TfText(
                    text.addMenuItemsBeforeOrders,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: PosColors.danger,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (shortcut != null) ...[
                  const SizedBox(height: 12),
                  TfButton(
                    label: shortcut!.label,
                    variant: TfButtonVariant.ghost,
                    fullWidth: false,
                    onPressed: shortcut!.onTap,
                  ),
                ],
                const SizedBox(height: 16),
                TfButton(
                  label: text.newOrder,
                  icon: TfNavIcon.plus,
                  size: TfButtonSize.lg,
                  fullWidth: false,
                  onPressed: canCreate ? onCreate : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order card with left accent bar
// ─────────────────────────────────────────────────────────────────────────────

/// Visual style for one of the 6 prototype channels (bytes-shared.jsx CHANNELS):
/// glyph + icon/soft hue + a [key] that maps to a localized [AppStrings.channelLabel].
class _ChannelStyle {
  const _ChannelStyle(this.key, this.icon, this.color, this.soft);
  final String key;
  final IconData icon;
  final Color color;
  final Color soft;
}

/// Best-effort map from the coarse [OrderSource] to the 6 prototype channels.
/// Storefront-vs-Table-QR can't be distinguished without a real per-order
/// channel field, so cloud is treated as the website storefront; `manual`
/// orders use [OrderModel.createdByRole] to tell a waiter from a manager.
_ChannelStyle _resolveChannel(OrderModel order) {
  switch (order.source) {
    case OrderSource.cloud:
      return const _ChannelStyle(
        'storefront',
        Icons.public,
        PosColors.channelWebsite,
        PosColors.infoSoft,
      );
    case OrderSource.facebookMessenger:
      return const _ChannelStyle(
        'chatbot',
        Icons.chat_bubble_outline_rounded,
        PosColors.channelMessenger,
        PosColors.infoSoft,
      );
    case OrderSource.desktopPos:
    case OrderSource.localLan:
      return const _ChannelStyle(
        'counter',
        Icons.storefront_outlined,
        PosColors.channelCounter,
        PosColors.successSoft,
      );
    case OrderSource.manual:
      final role = (order.createdByRole ?? '').toLowerCase();
      if (role == 'waiter' || role == 'staff') {
        return const _ChannelStyle(
          'waiter',
          Icons.groups_outlined,
          PosColors.channelWaiter,
          PosColors.channelNeutralSoft,
        );
      }
      return const _ChannelStyle(
        'manager',
        Icons.person_outline_rounded,
        PosColors.channelManager,
        PosColors.channelNeutralSoft,
      );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.onPrintBill,
    required this.onPrintKot,
    required this.onOpen,
    required this.onStatus,
    this.onCompletedLongPress,
  });

  final OrderModel order;
  final VoidCallback onPrintBill;
  final VoidCallback onPrintKot;
  final VoidCallback? onOpen;
  final ValueChanged<OrderStatus> onStatus;
  final VoidCallback? onCompletedLongPress;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final canPrint = app.isManager;
    final adminStatus = order.status.adminStatus;
    final isPending = adminStatus == OrderStatus.pending;
    final isAccepted = adminStatus == OrderStatus.accepted;
    final isCompleted = adminStatus == OrderStatus.completed;
    final elapsedMinutes = DateTime.now()
        .difference(order.createdAt.toLocal())
        .inMinutes;
    final lateMinutes = isPending && elapsedMinutes > 20
        ? elapsedMinutes - 20
        : 0;
    final isLate = lateMinutes > 0;

    // Card surfaces the CHANNEL (glyph + name) the order arrived through; the
    // order TYPE (Table 5 / Parcel / Delivery) sits beside the serial hero.
    final channel = _resolveChannel(order);
    final typeLabel = _sourceLabel(order, text);
    final subline =
        '${text.channelLabel(channel.key)} · ${text.orderAgeAgo(elapsedMinutes)}';
    final itemQty = order.items.fold<num>(0, (s, it) => s + it.qty).round();
    final itemsPreview = order.items
        .take(2)
        .map((item) {
          final qty = item.qty > 1
              ? '${tfFormatNumber(context, item.qty)}× '
              : '';
          return '$qty${item.localizedName(app.language)}';
        })
        .join(', ');
    final morePreview = order.items.length > 2 ? '…' : '';

    return TfCard(
      padded: false,
      clip: true,
      borderColor: isPending ? PosColors.pendingBorder : PosColors.line,
      child: Opacity(
        opacity: isCompleted ? 0.82 : 1,
        child: InkWell(
          onTap: onOpen,
          onLongPress: isCompleted
              ? onCompletedLongPress
              : (canPrint && isAccepted ? onPrintBill : null),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: channel.soft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(channel.icon, color: channel.color, size: 19),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TfText(
                                order.displaySequence,
                                style: TextStyle(
                                  fontFamily: tfFontFamily(context),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: PosColors.text,
                                  height: 1.1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              // Spec §4.1: order TYPE replaces the customer name,
                              // sitting beside the serial hero.
                              TfText(
                                typeLabel,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: PosColors.ink2,
                                  height: 1.1,
                                ),
                              ),
                              // Spec §4.1: no pending/accepted badge — pending is
                              // conveyed by the Accept action + card border. Only
                              // surface a LATE badge as an urgency signal.
                              if (isLate)
                                TfStatusBadge(
                                  label: text.orderStatusLate(lateMinutes),
                                  kind: TfStatusKind.late,
                                  upper: false,
                                ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          TfText(
                            subline,
                            style: const TextStyle(
                              fontSize: 12,
                              color: PosColors.muted,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TfText(
                      tfFormatCurrency(context, order.total),
                      style: TextStyle(
                        fontFamily: tfFontFamily(context),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: PosColors.text,
                        height: 1.15,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Spec §4.1: emphasized "N items · preview" line (count bold,
                // item preview muted) — replaces the boxed line list.
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: text.orderItemsCount(itemQty),
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: PosColors.text,
                          height: 1.45,
                        ),
                      ),
                      TextSpan(
                        text: ' · $itemsPreview$morePreview',
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w400,
                          color: PosColors.ink2,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // if ((order.note ?? '').trim().isNotEmpty) ...[
                //   const SizedBox(height: 10),
                //   Container(
                //     width: double.infinity,
                //     padding: const EdgeInsets.all(12),
                //     decoration: BoxDecoration(
                //       color: PosColors.surface,
                //       borderRadius: BorderRadius.circular(PosRadii.tile),
                //       border: Border.all(color: PosColors.line, width: 1),
                //     ),
                //     child: TfText(
                //       order.note!.trim(),
                //       style: const TextStyle(
                //         fontSize: 14,
                //         color: PosColors.textSec,
                //         fontStyle: FontStyle.italic,
                //         height: 1.4,
                //       ),
                //       maxLines: 2,
                //       overflow: TextOverflow.ellipsis,
                //     ),
                //   ),
                // ],
                if (isCompleted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(color: PosColors.line)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: PosColors.success,
                        ),
                        const SizedBox(width: 6),
                        TfText(
                          text.completedPaid,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: PosColors.success,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (canPrint && isPending) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: () => onStatus(OrderStatus.rejected),
                        borderRadius: BorderRadius.circular(PosRadii.md),
                        child: Container(
                          width: 44,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: PosColors.surface,
                            borderRadius: BorderRadius.circular(PosRadii.md),
                            border: Border.all(
                              color: PosColors.lineStrong,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: PosColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      TfButton(
                        label: text.acceptAndSendToKitchen,
                        icon: TfNavIcon.check,
                        variant: TfButtonVariant.accent,
                        size: TfButtonSize.md,
                        fullWidth: false,
                        onPressed: () => onStatus(OrderStatus.accepted),
                      ),
                    ],
                  ),
                ] else if (canPrint && isAccepted) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TfButton(
                          label: text.printKotAction,
                          icon: TfNavIcon.printer,
                          variant: TfButtonVariant.ghost,
                          size: TfButtonSize.md,
                          onPressed: onPrintKot,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TfButton(
                          label: text.printBillAction,
                          icon: Icons.receipt_long_outlined,
                          variant: TfButtonVariant.accent,
                          size: TfButtonSize.md,
                          onPressed: onPrintBill,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _sourceLabel(OrderModel order, AppStrings text) {
    final table = (order.tableNo ?? '').trim();
    if (table.isNotEmpty) {
      return text.isBn ? 'টেবিল ${tfToBnNumbers(table)}' : 'Table $table';
    }
    switch (order.serviceType) {
      case OrderServiceType.takeaway:
        return text.isBn ? 'পার্সেল' : 'Parcel';
      case OrderServiceType.delivery:
        return text.isBn ? 'ডেলিভারি' : 'Delivery';
      case OrderServiceType.dineIn:
      case null:
        return text.isBn ? 'ডাইন-ইন' : 'Dine-in';
    }
  }
}

class _OrderEditResult {
  const _OrderEditResult({
    required this.serviceType,
    this.tableNo,
    this.note,
    this.customerName,
    this.deliveryAddress,
    this.mobileNumber,
    this.items,
    this.itemsChanged = false,
    this.delete = false,
  });

  final OrderServiceType serviceType;
  final String? tableNo;
  final String? note;
  final String? customerName;
  final String? deliveryAddress;
  final String? mobileNumber;
  final List<OrderRequestItem>? items;
  final bool itemsChanged;
  final bool delete;
}

// ─────────────────────────────────────────────────────────────────────────────
// Pending order detail sheet — read-only, all roles; manager sees Accept/Reject.
// ─────────────────────────────────────────────────────────────────────────────

class _PendingOrderDetailSheet extends StatelessWidget {
  const _PendingOrderDetailSheet({
    required this.order,
    required this.onAccept,
    required this.onReject,
  });

  final OrderModel order;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final isBn = text.isBn;
    final channel = _resolveChannel(order);
    final elapsedMinutes = DateTime.now()
        .difference(order.createdAt.toLocal())
        .inMinutes;
    final typeLabel = _sourceLabel(order, text);
    final isDelivery = order.serviceType == OrderServiceType.delivery;
    final subtotal = order.items.fold<double>(
      0,
      (s, i) => s + i.lineTotal,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(PosRadii.xl),
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: PosColors.line,
                borderRadius: BorderRadius.circular(PosRadii.pill),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TfText(
                        order.displaySequence,
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: PosColors.text,
                          height: 1.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TfText(
                          typeLabel,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: PosColors.ink2,
                          ),
                        ),
                      ),
                      TfText(
                        text.orderAgeAgo(elapsedMinutes),
                        style: const TextStyle(
                          fontSize: 12,
                          color: PosColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TfText(
                    text.channelLabel(channel.key),
                    style: const TextStyle(
                      fontSize: 13,
                      color: PosColors.muted,
                    ),
                  ),
                  // ── Delivery info ────────────────────────────────────────
                  if (isDelivery &&
                      ((order.customerName ?? '').isNotEmpty ||
                          (order.mobileNumber ?? '').isNotEmpty ||
                          (order.deliveryAddress ?? '').isNotEmpty)) ...[
                    const SizedBox(height: 12),
                    TfCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((order.customerName ?? '').isNotEmpty)
                            _DetailRow(
                              icon: Icons.person_outline_rounded,
                              value: order.customerName!,
                            ),
                          if ((order.mobileNumber ?? '').isNotEmpty)
                            _DetailRow(
                              icon: Icons.phone_outlined,
                              value: order.mobileNumber!,
                            ),
                          if ((order.deliveryAddress ?? '').isNotEmpty)
                            _DetailRow(
                              icon: Icons.location_on_outlined,
                              value: order.deliveryAddress!,
                            ),
                        ],
                      ),
                    ),
                  ],
                  // ── Items ────────────────────────────────────────────────
                  const SizedBox(height: 12),
                  TfCard(
                    padded: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                          child: TfText(
                            isBn ? 'আইটেমসমূহ' : 'Items',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: PosColors.muted,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Divider(color: PosColors.line, height: 1),
                        for (final item in order.items)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 30,
                                  child: TfText(
                                    '${tfFormatNumber(context, item.qty)}×',
                                    style: TextStyle(
                                      fontFamily: tfFontFamily(context),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: PosColors.slate,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TfText(
                                    item.localizedName(app.language),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: PosColors.slate,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TfText(
                                  tfFormatCurrency(context, item.lineTotal),
                                  style: TextStyle(
                                    fontFamily: tfFontFamily(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: PosColors.slate,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  // ── Note ────────────────────────────────────────────────
                  if ((order.note ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    TfCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 16,
                            color: PosColors.muted,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TfText(
                              order.note!.trim(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: PosColors.ink2,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // ── Totals ───────────────────────────────────────────────
                  const SizedBox(height: 12),
                  TfCard(
                    child: Column(
                      children: [
                        _AmountLine(
                          label: isBn ? 'সাবটোটাল' : 'Subtotal',
                          value: tfFormatCurrency(context, subtotal),
                        ),
                        const SizedBox(height: 6),
                        _AmountLine(
                          label: isBn ? 'মোট' : 'Total',
                          value: tfFormatCurrency(context, order.total),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // ── Manager actions ──────────────────────────────────────────
            if (app.isManager)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: onReject,
                        borderRadius: BorderRadius.circular(PosRadii.md),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: PosColors.surface,
                            borderRadius: BorderRadius.circular(PosRadii.md),
                            border: Border.all(
                              color: PosColors.lineStrong,
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: PosColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TfButton(
                          label: text.acceptAndSendToKitchen,
                          icon: TfNavIcon.check,
                          variant: TfButtonVariant.accent,
                          size: TfButtonSize.lg,
                          onPressed: onAccept,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(OrderModel order, AppStrings text) {
    final table = (order.tableNo ?? '').trim();
    if (table.isNotEmpty) {
      return text.isBn ? 'টেবিল $table' : 'Table $table';
    }
    switch (order.serviceType) {
      case OrderServiceType.takeaway:
        return text.isBn ? 'পার্সেল' : 'Parcel';
      case OrderServiceType.delivery:
        return text.isBn ? 'ডেলিভারি' : 'Delivery';
      case OrderServiceType.dineIn:
      case null:
        return text.isBn ? 'ডাইন-ইন' : 'Dine-in';
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: PosColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TfText(
              value,
              style: const TextStyle(fontSize: 13, color: PosColors.slate),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditOrderSheet extends StatefulWidget {
  const _EditOrderSheet({required this.order});

  final OrderModel order;

  @override
  State<_EditOrderSheet> createState() => _EditOrderSheetState();
}

class _EditOrderSheetState extends State<_EditOrderSheet> {
  late OrderServiceType _serviceType;
  late final TextEditingController _tableCtrl;
  late final TextEditingController _noteCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;

  // Working copy of the order's items, keyed by menuItemId.
  final Map<String, int> _itemQty = <String, int>{};
  // Names + unit prices for currently-tracked items, used when the menu item
  // is no longer available (e.g. deleted) so we can still show the line.
  final Map<String, ({String name, double price})> _itemMeta =
      <String, ({String name, double price})>{};
  late final Map<String, int> _originalItemQty;
  bool _itemsDirty = false;

  @override
  void initState() {
    super.initState();
    final order = widget.order;
    _serviceType = order.serviceType ?? OrderServiceType.dineIn;
    _tableCtrl = TextEditingController(text: order.tableNo ?? '');
    _noteCtrl = TextEditingController(text: order.note ?? '');
    _nameCtrl = TextEditingController(text: order.customerName ?? '');
    _addressCtrl = TextEditingController(text: order.deliveryAddress ?? '');
    _phoneCtrl = TextEditingController(text: order.mobileNumber ?? '');
    for (final item in order.items) {
      _itemQty[item.menuItemId] = (_itemQty[item.menuItemId] ?? 0) + item.qty;
      _itemMeta[item.menuItemId] = (name: item.name, price: item.price);
    }
    _originalItemQty = Map<String, int>.from(_itemQty);
  }

  @override
  void dispose() {
    _tableCtrl.dispose();
    _noteCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String? _clean(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  bool _detectItemsDirty() {
    if (_itemQty.length != _originalItemQty.length) return true;
    for (final entry in _itemQty.entries) {
      if (_originalItemQty[entry.key] != entry.value) return true;
    }
    return false;
  }

  void _changeQty(String menuItemId, int delta) {
    final current = _itemQty[menuItemId] ?? 0;
    final next = current + delta;
    setState(() {
      if (next <= 0) {
        _itemQty.remove(menuItemId);
      } else {
        _itemQty[menuItemId] = next;
      }
      _itemsDirty = _detectItemsDirty();
    });
  }

  Future<void> _addItemFlow(BuildContext context) async {
    final app = AppScope.of(context);
    final available = app.menuItems
        .where((m) => m.isAvailable)
        .toList(growable: false);
    if (available.isEmpty) return;
    final picked = await showModalBottomSheet<MenuItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MenuItemPickerSheet(menuItems: available),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _itemQty[picked.id] = (_itemQty[picked.id] ?? 0) + 1;
      _itemMeta[picked.id] = (name: picked.name, price: picked.price);
      _itemsDirty = _detectItemsDirty();
    });
  }

  ({String name, double price}) _metaFor(
    BuildContext context,
    String menuItemId,
  ) {
    final cached = _itemMeta[menuItemId];
    if (cached != null) return cached;
    final app = AppScope.of(context);
    for (final menu in app.menuItems) {
      if (menu.id == menuItemId) {
        return (name: menu.name, price: menu.price);
      }
    }
    return (name: menuItemId, price: 0);
  }

  double get _runningTotal {
    var sum = 0.0;
    for (final entry in _itemQty.entries) {
      final meta = _itemMeta[entry.key];
      if (meta == null) continue;
      sum += meta.price * entry.value;
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isDelivery = _serviceType == OrderServiceType.delivery;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PosColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PosRadii.xl),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            children: [
              TfText(
                text.isBn ? 'অর্ডার এডিট' : 'Edit order',
                style: TextStyle(
                  fontFamily: tfFontFamily(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: PosColors.slate,
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<OrderServiceType>(
                segments: OrderServiceType.values
                    .map(
                      (type) => ButtonSegment<OrderServiceType>(
                        value: type,
                        label: TfText(
                          text.isBn ? type.banglaLabel : type.label,
                        ),
                      ),
                    )
                    .toList(growable: false),
                selected: {_serviceType},
                onSelectionChanged: (values) {
                  setState(() => _serviceType = values.first);
                },
              ),
              const SizedBox(height: 16),
              if (_serviceType == OrderServiceType.dineIn)
                TfField(
                  label: 'Table number',
                  labelBn: 'টেবিল নম্বর',
                  controller: _tableCtrl,
                  keyboardType: TextInputType.number,
                ),
              TfField(
                label: 'Order note',
                labelBn: 'অর্ডার নোট',
                controller: _noteCtrl,
                maxLines: 2,
              ),
              if (isDelivery) ...[
                TfField(
                  label: 'Customer name',
                  labelBn: 'কাস্টমারের নাম',
                  controller: _nameCtrl,
                ),
                TfField(
                  label: 'Mobile number',
                  labelBn: 'মোবাইল নম্বর',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                TfField(
                  label: 'Delivery address',
                  labelBn: 'ডেলিভারি ঠিকানা',
                  controller: _addressCtrl,
                  maxLines: 3,
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TfText(
                      text.isBn ? 'আইটেম' : 'Items',
                      style: TextStyle(
                        fontFamily: tfFontFamily(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: PosColors.slate,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _addItemFlow(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: TfText(text.isBn ? 'যোগ করুন' : 'Add item'),
                  ),
                ],
              ),
              if (_itemQty.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TfText(
                    text.isBn
                        ? 'কোনো আইটেম নেই — যোগ করুন'
                        : 'No items — add at least one',
                    style: const TextStyle(color: PosColors.muted),
                  ),
                ),
              for (final entry in _itemQty.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TfText(
                              _metaFor(context, entry.key).name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: PosColors.slate,
                              ),
                            ),
                            TfText(
                              _metaFor(
                                context,
                                entry.key,
                              ).price.toStringAsFixed(2),
                              style: TextStyle(
                                fontFamily: tfFontFamily(context),
                                fontSize: 12,
                                color: PosColors.muted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _changeQty(entry.key, -1),
                      ),
                      SizedBox(
                        width: 28,
                        child: TfText(
                          '${entry.value}',
                          style: TextStyle(
                            fontFamily: tfFontFamily(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: () => _changeQty(entry.key, 1),
                      ),
                    ],
                  ),
                ),
              if (_itemQty.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TfText(
                        text.isBn ? 'মোট' : 'Total',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TfText(
                        _runningTotal.toStringAsFixed(2),
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TfButton(
                      label: text.isBn ? 'ডিলিট' : 'Delete',
                      icon: Icons.delete_outline,
                      variant: TfButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).pop(
                        const _OrderEditResult(
                          serviceType: OrderServiceType.dineIn,
                          delete: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TfButton(
                      label: text.isBn ? 'সেভ' : 'Save',
                      icon: TfNavIcon.check,
                      onPressed: _itemQty.isEmpty
                          ? null
                          : () {
                              final items = _itemQty.entries
                                  .map(
                                    (e) => OrderRequestItem(
                                      menuItemId: e.key,
                                      qty: e.value,
                                    ),
                                  )
                                  .toList(growable: false);
                              Navigator.of(context).pop(
                                _OrderEditResult(
                                  serviceType: _serviceType,
                                  tableNo:
                                      _serviceType == OrderServiceType.dineIn
                                      ? _clean(_tableCtrl)
                                      : null,
                                  note: _clean(_noteCtrl),
                                  customerName: isDelivery
                                      ? _clean(_nameCtrl)
                                      : null,
                                  deliveryAddress: isDelivery
                                      ? _clean(_addressCtrl)
                                      : null,
                                  mobileNumber: isDelivery
                                      ? _clean(_phoneCtrl)
                                      : null,
                                  items: items,
                                  itemsChanged: _itemsDirty,
                                ),
                              );
                            },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Menu item picker (used by edit-order sheet to add new lines)
// ─────────────────────────────────────────────────────────────────────────────

class _MenuItemPickerSheet extends StatefulWidget {
  const _MenuItemPickerSheet({required this.menuItems});

  final List<MenuItem> menuItems;

  @override
  State<_MenuItemPickerSheet> createState() => _MenuItemPickerSheetState();
}

class _MenuItemPickerSheetState extends State<_MenuItemPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final query = _query.trim().toLowerCase();
    final filtered = widget.menuItems
        .where((item) {
          if (query.isEmpty) return true;
          final searchable = [
            item.name,
            item.nameEn,
            item.nameBn,
            item.category,
          ].whereType<String>().join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PosColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PosRadii.xl),
          ),
        ),
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TfText(
                        text.isBn ? 'আইটেম যোগ করুন' : 'Add item',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: PosColors.slate,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: text.isBn ? 'খুঁজুন' : 'Search',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return ListTile(
                      title: TfText(item.name),
                      subtitle: item.category.isEmpty
                          ? null
                          : TfText(
                              item.category,
                              style: const TextStyle(
                                fontSize: 12,
                                color: PosColors.muted,
                              ),
                            ),
                      trailing: TfText(
                        item.price.toStringAsFixed(2),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () => Navigator.of(context).pop(item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Order created sheet
// ─────────────────────────────────────────────────────────────────────────────

// ignore: unused_element
class _OrderCreatedSheet extends StatelessWidget {
  // ignore: unused_element_parameter
  const _OrderCreatedSheet({
    required this.order,
    required this.autoPrinted,
    required this.canPrint,
    required this.onPrint,
    // ignore: unused_element_parameter
    this.menuUrl,
  });

  final OrderModel order;
  final bool autoPrinted;
  final bool canPrint;
  final VoidCallback onPrint;
  final String? menuUrl;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Container(
      color: PosColors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header — Back to orders. Always reachable so a manager never
            // gets stuck on the receipt.
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: PosColors.slate,
                    tooltip: 'Back to orders',
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Expanded(
                    child: TfText(
                      'Receipt',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: PosColors.slate,
                      ),
                    ),
                  ),
                  if (autoPrinted)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PosColors.successSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.print_rounded,
                            size: 12,
                            color: PosColors.success,
                          ),
                          const SizedBox(width: 4),
                          TfText(
                            text.ticketSentToPrinter,
                            style: const TextStyle(
                              color: PosColors.success,
                              fontWeight: FontWeight.w500,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      borderRadius: BorderRadius.circular(PosRadii.card),
                      border: Border.all(color: PosColors.line, width: 1),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: PosColors.successSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: PosColors.success,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TfText(
                          'Order created',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: PosColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Big order # focus.
                        TfText(
                          order.displaySequence,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 56,
                            color: PosColors.slate,
                            height: 1,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if ((order.tableNo ?? '').isNotEmpty)
                          TfText(
                            'Table ${order.tableNo}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                              color: PosColors.muted,
                            ),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(PosRadii.tile),
                            border: Border.all(color: PosColors.line, width: 1),
                          ),
                          child: QrImageView(
                            data: menuUrl ?? order.id,
                            version: QrVersions.auto,
                            size: 130,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: PosColors.slate,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: PosColors.slate,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TfText(
                          menuUrl != null
                              ? 'Scan to view the menu'
                              : order.orderNo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: PosColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Items list
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      borderRadius: BorderRadius.circular(PosRadii.card),
                      border: Border.all(color: PosColors.line, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TfText(
                          'ITEMS',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: PosColors.muted,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final item in order.items)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  child: TfText(
                                    '${tfFormatNumber(context, item.qty)}×',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12.5,
                                      color: PosColors.muted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TfText(
                                    item.localizedName(
                                      AppScope.of(context).language,
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13,
                                      color: PosColors.slate,
                                    ),
                                  ),
                                ),
                                TfText(
                                  tfFormatCurrency(context, item.lineTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                    color: PosColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Divider(color: PosColors.line, height: 22),
                        Row(
                          children: [
                            TfText(
                              'TOTAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: PosColors.slate,
                                letterSpacing: 0.7,
                              ),
                            ),
                            const Spacer(),
                            TfText(
                              tfFormatCurrency(context, order.total),
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w500,
                                color: PosColors.slate,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Bottom action bar: Print bill + Back to orders.
            Container(
              decoration: BoxDecoration(
                color: PosColors.surface,
                border: Border(
                  top: BorderSide(color: PosColors.line, width: 0.5),
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 12,
              ),
              child: Row(
                children: [
                  if (canPrint)
                    Expanded(
                      child: TfButton(
                        label: 'Print bill',
                        icon: Icons.print_rounded,
                        variant: TfButtonVariant.paper,
                        size: TfButtonSize.lg,
                        onPressed: onPrint,
                      ),
                    ),
                  if (canPrint) const SizedBox(width: 10),
                  Expanded(
                    child: TfButton(
                      label: 'Back to orders',
                      size: TfButtonSize.lg,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// New order page — source, items, review, success
// ─────────────────────────────────────────────────────────────────────────────

class _OrderResult {
  _OrderResult({
    required this.items,
    required this.serviceType,
    this.tableNo,
    this.note,
    this.customerName,
    this.mobileNumber,
    this.deliveryAddress,
  });

  final List<OrderRequestItem> items;
  final OrderServiceType serviceType;
  final String? tableNo;
  final String? note;
  final String? customerName;
  final String? mobileNumber;
  final String? deliveryAddress;
}

class _NewOrderPage extends StatefulWidget {
  const _NewOrderPage({
    required this.menuItems,
    required this.tableCount,
    required this.dineInOpenOrders,
    required this.onCreateOrder,
    this.counterMode = false,
    this.initialMenuItemId,
    this.initialMenuItemQuantities,
    this.initialCartLines,
    this.initialServiceType,
    this.initialTableNo,
    this.startAtMenu = false,
    this.startAtReview = false,
    this.itemPopularity = const {},
  });

  final List<MenuItem> menuItems;
  final Map<String, int> itemPopularity;
  final int tableCount;
  final List<OrderModel> dineInOpenOrders;
  final Future<OrderModel> Function(_OrderResult result) onCreateOrder;
  // When true, skip table/source step and auto-select counter (takeaway) mode.
  final bool counterMode;
  final String? initialMenuItemId;
  final Map<String, int>? initialMenuItemQuantities;
  final List<DesktopMenuLineSelection>? initialCartLines;
  final OrderServiceType? initialServiceType;
  final String? initialTableNo;
  final bool startAtMenu;
  final bool startAtReview;

  @override
  State<_NewOrderPage> createState() => _NewOrderPageState();
}

class _NewOrderPageState extends State<_NewOrderPage> {
  final _pageCtrl = PageController();
  int _step = 0;
  static const int _totalSteps = 4;

  OrderServiceType? _source;
  String? _selectedTable;

  final List<DesktopMenuLineSelection> _cartLines = [];
  String _selectedCategory = 'All';
  final _searchCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  // Delivery (form-first) fields, used when _source == delivery.
  final _custNameCtrl = TextEditingController();
  final _custPhoneCtrl = TextEditingController();
  final _custAddrCtrl = TextEditingController();
  String _query = '';
  MenuLayoutMode _menuLayoutMode = MenuLayoutMode.grid;
  int _gridCols = 3;
  OrderModel? _createdOrder;
  bool _creating = false;
  bool _printingKot = false;

  @override
  void initState() {
    super.initState();
    _cartLines.addAll(widget.initialCartLines ?? const []);
    final validIds = widget.menuItems.map((item) => item.id).toSet();
    final initialQuantities = widget.initialMenuItemQuantities ?? const {};
    for (final entry in initialQuantities.entries) {
      if (validIds.contains(entry.key) && entry.value > 0) {
        final item = widget.menuItems.firstWhere(
          (item) => item.id == entry.key,
        );
        _cartLines.add(desktopRegularMenuLine(item, qty: entry.value));
      }
    }
    MenuItem? initialMenuItem;
    for (final item in widget.menuItems) {
      if (item.id == widget.initialMenuItemId) {
        initialMenuItem = item;
        break;
      }
    }
    if (initialMenuItem != null) {
      _cartLines.add(desktopRegularMenuLine(initialMenuItem));
    }
    if (widget.counterMode) {
      // Simple tier: skip source/table selection, start at items step.
      _step = widget.startAtReview && _cartLines.isNotEmpty ? 2 : 1;
      _source = OrderServiceType.takeaway;
      _selectedTable = '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageCtrl.jumpToPage(_step);
      });
    } else if (widget.initialServiceType != null) {
      _source = widget.initialServiceType;
      _selectedTable = widget.initialServiceType == OrderServiceType.dineIn
          ? widget.initialTableNo
          : '';
      if (widget.startAtMenu || widget.startAtReview) {
        _step = widget.startAtReview && _cartLines.isNotEmpty ? 2 : 1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pageCtrl.jumpToPage(_step);
        });
      }
    } else {
      _source = OrderServiceType.dineIn;
      _selectedTable = '';
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    _discountCtrl.dispose();
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    _custAddrCtrl.dispose();
    super.dispose();
  }

  /// Delivery requires name + phone + address before leaving step 1 (spec §4.3).
  bool get _deliveryValid =>
      _custNameCtrl.text.trim().isNotEmpty &&
      _custPhoneCtrl.text.trim().isNotEmpty &&
      _custAddrCtrl.text.trim().isNotEmpty;

  void _goToStep(int index) {
    if (index < 0 || index >= _totalSteps) return;
    setState(() => _step = index);
    _pageCtrl.jumpToPage(index);
  }

  void _selectTableAndAdvance(String table) {
    setState(() => _selectedTable = table);
    _goToStep(1);
  }

  void _selectSource(OrderServiceType src) {
    setState(() {
      _source = src;
      if (src != OrderServiceType.dineIn) {
        _selectedTable = '';
      } else {
        _selectedTable = null;
      }
    });
    if (src == OrderServiceType.takeaway) _goToStep(1);
  }

  void _continueFromSource() {
    if (_source == null) return;
    if (_source == OrderServiceType.dineIn && _selectedTable == null) return;
    if (_source == OrderServiceType.delivery && !_deliveryValid) return;
    _goToStep(1);
  }

  List<String> get _categories {
    final cats = widget.menuItems.map((i) => i.category).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...cats];
  }

  List<MenuItem> get _visibleItems {
    final items = widget.menuItems.where((i) {
      final matchesCategory =
          _selectedCategory == 'All' || i.category == _selectedCategory;
      if (!matchesCategory) return false;
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) return true;
      final searchable = [
        i.name,
        i.nameEn,
        i.nameBn,
        i.category,
        i.description,
      ].whereType<String>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList(growable: false);
    items.sort((a, b) {
      final aPop = widget.itemPopularity[a.id] ?? 0;
      final bPop = widget.itemPopularity[b.id] ?? 0;
      return bPop.compareTo(aPop);
    });
    return items;
  }

  Map<String, int> get _cartQtyByItemId {
    final out = <String, int>{};
    for (final line in _cartLines) {
      out[line.item.id] = (out[line.item.id] ?? 0) + line.qty;
    }
    return out;
  }

  int get _totalQty => _cartLines.fold(0, (s, line) => s + line.qty);

  double get _subtotal {
    return _cartLines.fold<double>(0, (sum, line) => sum + line.lineTotal);
  }

  double get _discount =>
      (double.tryParse(_discountCtrl.text.replaceAll(',', '')) ?? 0.0)
          .clamp(0.0, _subtotal);

  double get _total => _roundMoney(_subtotal - _discount);

  double _roundMoney(double value) => double.parse(value.toStringAsFixed(2));

  Future<void> _tap(MenuItem item) async {
    HapticFeedback.lightImpact();
    final List<DesktopMenuLineSelection>? selections;
    if (desktopMenuNeedsCustomization(item)) {
      final result = await showMobileItemSheet(context, item: item);
      if (result == null || !mounted) return;
      selections = [result];
    } else {
      selections = [desktopRegularMenuLine(item)];
    }
    if (!mounted) return;
    setState(() {
      for (final selection in selections!) {
        final index = _cartLines.indexWhere(
          (line) => line.lineKey == selection.lineKey,
        );
        if (index >= 0) {
          final current = _cartLines[index];
          _cartLines[index] = DesktopMenuLineSelection(
            item: current.item,
            option: current.option,
            addOns: current.addOns,
            qty: current.qty + selection.qty,
            note: current.note,
          );
        } else {
          _cartLines.add(selection);
        }
      }
    });
  }

  void _decrement(String id) {
    setState(() {
      final index = _cartLines.lastIndexWhere((line) => line.item.id == id);
      if (index < 0) return;
      final line = _cartLines[index];
      if (line.qty <= 1) {
        _cartLines.removeAt(index);
      } else {
        _cartLines[index] = DesktopMenuLineSelection(
          item: line.item,
          option: line.option,
          addOns: line.addOns,
          qty: line.qty - 1,
          note: line.note,
        );
      }
    });
  }

  void _selectMenuLayout(MenuLayoutMode mode) {
    if (_menuLayoutMode == mode) return;
    setState(() => _menuLayoutMode = mode);
  }

  void _selectGridCols(int cols) {
    if (_gridCols == cols) return;
    setState(() => _gridCols = cols);
  }

  Map<String, int> get _categoryCounts {
    final allItems = widget.menuItems;
    final counts = <String, int>{'All': allItems.length};
    for (final item in allItems) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    return counts;
  }

  void _goToReview() {
    if (_cartLines.isEmpty) return;
    _goToStep(2);
  }

  Future<void> _submit() async {
    if (_cartLines.isEmpty || _source == null || _creating) return;
    final items = _cartLines
        .map((line) => line.toRequestItem())
        .toList(growable: false);
    final isDineIn = _source == OrderServiceType.dineIn;
    final tableNo = isDineIn && (_selectedTable ?? '').isNotEmpty
        ? _selectedTable
        : null;
    setState(() => _creating = true);
    try {
      final isDelivery = _source == OrderServiceType.delivery;
      final order = await widget.onCreateOrder(
        _OrderResult(
          items: items,
          serviceType: _source!,
          tableNo: tableNo,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          customerName: isDelivery && _custNameCtrl.text.trim().isNotEmpty
              ? _custNameCtrl.text.trim()
              : null,
          mobileNumber: isDelivery && _custPhoneCtrl.text.trim().isNotEmpty
              ? _custPhoneCtrl.text.trim()
              : null,
          deliveryAddress: isDelivery && _custAddrCtrl.text.trim().isNotEmpty
              ? _custAddrCtrl.text.trim()
              : null,
        ),
      );
      if (!mounted) return;
      setState(() {
        _createdOrder = order;
        _creating = false;
      });
      _goToStep(3);
    } catch (error) {
      if (!mounted) return;
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(
            AppScope.of(context).strings.couldNotCreateOrder(error),
          ),
        ),
      );
    }
  }


  Future<void> _printCreatedKot() async {
    final order = _createdOrder;
    if (order == null || _printingKot) return;
    setState(() => _printingKot = true);
    final app = AppScope.of(context);
    final ok = await app.printOrderTicket(order);
    if (!mounted) return;
    setState(() => _printingKot = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 72),
          content: TfText(app.strings.ticketPrinted(order.displaySequence)),
        ),
      );
    }
  }

  String get _tableLabel {
    if (_source == OrderServiceType.takeaway) return 'Parcel';
    if (_source == OrderServiceType.delivery) return 'Delivery';
    if (_selectedTable == null) return '';
    if (_selectedTable!.isEmpty) return 'Parcel';
    return 'Table $_selectedTable';
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _step == 3;
    final skipsSourceStep =
        widget.startAtMenu && widget.initialServiceType != null;
    final firstReachableStep = widget.counterMode || skipsSourceStep ? 1 : 0;
    final displayStep = skipsSourceStep ? _step - 1 : _step;
    final displayTotalSteps = skipsSourceStep ? _totalSteps - 1 : _totalSteps;
    final cartQtyByItemId = _cartQtyByItemId;
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _WizardHeader(
              step: displayStep,
              totalSteps: displayTotalSteps,
              tableLabel: _tableLabel,
              onClose: () => Navigator.pop(context),
              onBack: _step > firstReachableStep && !isSuccess
                  ? () => _goToStep(_step - 1)
                  : null,
              counterMode: widget.counterMode,
              skipsSourceStep: skipsSourceStep,
            ),
            _StepIndicator(step: displayStep, total: displayTotalSteps),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SourceAndTableStep(
                    source: _source,
                    onSelectSource: _selectSource,
                    tableCount: widget.tableCount,
                    selectedTable: _selectedTable,
                    dineInOpenOrders: widget.dineInOpenOrders,
                    onSelectTable: _selectTableAndAdvance,
                    nameCtrl: _custNameCtrl,
                    phoneCtrl: _custPhoneCtrl,
                    addressCtrl: _custAddrCtrl,
                    onDeliveryChanged: () => setState(() {}),
                    onContinue: _deliveryValid ? _continueFromSource : null,
                  ),
                  MenuStep(
                    visibleItems: _visibleItems,
                    categories: _categories,
                    selectedCategory: _selectedCategory,
                    cart: cartQtyByItemId,
                    lineCount: _cartLines.length,
                    total: _total,
                    totalQty: _totalQty,
                    searchCtrl: _searchCtrl,
                    query: _query,
                    layoutMode: _menuLayoutMode,
                    gridCols: _gridCols,
                    categoryCounts: _categoryCounts,
                    onSearchChanged: (value) => setState(() => _query = value),
                    onLayoutChanged: _selectMenuLayout,
                    onGridColsChanged: _selectGridCols,
                    onCategorySelected: (c) =>
                        setState(() => _selectedCategory = c),
                    onTap: (item) => unawaited(_tap(item)),
                    onDecrement: _decrement,
                    onSubmit: _cartLines.isNotEmpty ? _goToReview : null,
                  ),
                  _ReviewStep(
                    lines: _cartLines,
                    totalQty: _totalQty,
                    subtotal: _subtotal,
                    discount: _discount,
                    total: _total,
                    noteCtrl: _noteCtrl,
                    discountCtrl: _discountCtrl,
                    onDiscountChanged: () => setState(() {}),
                    sourceLabel: _tableLabel.isEmpty ? '—' : _tableLabel,
                    onEdit: () => _goToStep(1),
                    onCreate: _submit,
                    creating: _creating,
                  ),
                  _OrderCreatedStep(
                    order: _createdOrder,
                    serviceLabel: _tableLabel,
                    total: _total,
                    printingKot: _printingKot,
                    onPrintKot: _createdOrder == null
                        ? null
                        : () => unawaited(_printCreatedKot()),
                    onDone: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.totalSteps,
    required this.tableLabel,
    required this.onClose,
    required this.onBack,
    this.counterMode = false,
    this.skipsSourceStep = false,
  });

  final int step;
  final int totalSteps;
  final String tableLabel;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final bool counterMode;
  final bool skipsSourceStep;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final isBn = text.isBn;
    final stepLabels = skipsSourceStep
        ? (isBn
              ? const ['আইটেম যোগ করুন', 'রিভিউ ও পাঠান', 'অর্ডার তৈরি হয়েছে']
              : const ['Add items', 'Review & send', 'Order created'])
        : (isBn
              ? const [
                  'অর্ডার কোথা থেকে?',
                  'আইটেম যোগ করুন',
                  'রিভিউ ও পাঠান',
                  'অর্ডার তৈরি হয়েছে',
                ]
              : const [
                  "Where's this order for?",
                  'Add items',
                  'Review & send',
                  'Order created',
                ]);
    final stepLabel = stepLabels[step.clamp(0, stepLabels.length - 1)];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfIconButton(
            icon: onBack != null ? TfNavIcon.back : TfNavIcon.close,
            tooltip: onBack != null
                ? (isBn ? 'পেছনে' : 'Back')
                : (isBn ? 'বাতিল' : 'Close'),
            onPressed: onBack ?? onClose,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  '${isBn ? 'ধাপ' : 'Step'} ${tfFormatNumber(context, step + 1)} ${isBn ? 'এর' : 'of'} ${tfFormatNumber(context, totalSteps)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PosColors.textTer,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                TfText(
                  stepLabel,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: PosColors.slate,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (counterMode) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: PosColors.surfaceSunk,
                  borderRadius: BorderRadius.circular(PosRadii.chip),
                  border: Border.all(color: PosColors.line, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: PosColors.primaryDark,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'COUNTER',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PosColors.primaryDark,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (tableLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TfText(
                tableLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PosColors.muted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step, this.total = 3});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: i <= step ? PosColors.primaryDark : PosColors.line,
                  borderRadius: BorderRadius.circular(PosRadii.pill),
                ),
              ),
            ),
            if (i < total - 1) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Source picker (Dine-in / Parcel) — wraps the existing
// table picker so dine-in shows tables directly underneath the source choice.
// ─────────────────────────────────────────────────────────────────────────────

class _SourceAndTableStep extends StatelessWidget {
  const _SourceAndTableStep({
    required this.source,
    required this.onSelectSource,
    required this.tableCount,
    required this.selectedTable,
    required this.dineInOpenOrders,
    required this.onSelectTable,
    required this.onContinue,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.onDeliveryChanged,
  });

  final OrderServiceType? source;
  final ValueChanged<OrderServiceType> onSelectSource;
  final int tableCount;
  final String? selectedTable;
  final List<OrderModel> dineInOpenOrders;
  final ValueChanged<String> onSelectTable;
  final VoidCallback? onContinue;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final VoidCallback onDeliveryChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isDineIn = source == OrderServiceType.dineIn;
    final isDelivery = source == OrderServiceType.delivery;

    final byTable = <String, OrderModel>{};
    final occupiedTableKeys = <String>{};
    for (final o in dineInOpenOrders) {
      final raw = (o.tableNo ?? '').trim();
      if (raw.isEmpty) continue;
      occupiedTableKeys.add(raw.startsWith('T') ? raw.substring(1) : raw);
      byTable[raw] = o;
      if (raw.startsWith('T')) {
        byTable[raw.substring(1)] = o;
      } else {
        byTable['T$raw'] = o;
      }
    }
    final occupiedCount = occupiedTableKeys.length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SourceTile(
                        icon: Icons.table_restaurant_outlined,
                        source: OrderServiceType.dineIn,
                        selected: source == OrderServiceType.dineIn,
                        onTap: () => onSelectSource(OrderServiceType.dineIn),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SourceTile(
                        icon: Icons.takeout_dining_outlined,
                        source: OrderServiceType.takeaway,
                        selected: source == OrderServiceType.takeaway,
                        onTap: () => onSelectSource(OrderServiceType.takeaway),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SourceTile(
                        icon: Icons.delivery_dining_outlined,
                        source: OrderServiceType.delivery,
                        selected: source == OrderServiceType.delivery,
                        onTap: () => onSelectSource(OrderServiceType.delivery),
                      ),
                    ),
                  ],
                ),
                if (isDelivery) ...[
                  const SizedBox(height: 20),
                  TfField(
                    label: text.isBn ? 'গ্রাহকের নাম' : 'Recipient name',
                    controller: nameCtrl,
                    prefix: const Icon(Icons.person_outline_rounded, size: 18),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => onDeliveryChanged(),
                  ),
                  const SizedBox(height: 12),
                  TfField(
                    label: text.isBn ? 'ফোন নম্বর' : 'Phone number',
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    prefix: const Icon(Icons.phone_outlined, size: 18),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => onDeliveryChanged(),
                  ),
                  const SizedBox(height: 12),
                  TfField(
                    label: text.isBn ? 'ঠিকানা' : 'Address',
                    controller: addressCtrl,
                    maxLines: 2,
                    prefix: const Icon(Icons.location_on_outlined, size: 18),
                    onChanged: (_) => onDeliveryChanged(),
                  ),
                ],
                if (isDineIn) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TfText(
                          text.pickATable,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: PosColors.slate,
                          ),
                        ),
                      ),
                      TfText(
                        '${tfFormatNumber(context, tableCount)} ${text.isBn ? "টেবিল" : "tables"}'
                        ' · ${tfFormatNumber(context, tableCount - occupiedCount)} ${text.isBn ? "খালি" : "free"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: PosColors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.92,
                        ),
                    itemCount: tableCount,
                    itemBuilder: (_, i) {
                      final label = 'T${i + 1}';
                      final order = byTable[label];
                      final sel = selectedTable == '${i + 1}';
                      return _WizardTableCell(
                        label: label,
                        isSelected: sel,
                        order: order,
                        onTap: () => onSelectTable('${i + 1}'),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isDelivery)
          TfStickyCTA(
            child: TfButton(
              label: text.continueAction,
              trailingIcon: TfNavIcon.arrow,
              size: TfButtonSize.lg,
              onPressed: onContinue,
            ),
          ),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.source,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final OrderServiceType source;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    final label = isBn ? source.banglaLabel : source.label;
    return Material(
      color: selected ? PosColors.primarySoft : PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.card),
            border: Border.all(
              color: selected ? Colors.transparent : PosColors.line,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 28, color: PosColors.primaryDark),
              const SizedBox(height: 10),
              TfText(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PosColors.slate,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review step with VAT, kitchen note, and create CTA.
// ─────────────────────────────────────────────────────────────────────────────

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.lines,
    required this.totalQty,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.noteCtrl,
    required this.discountCtrl,
    required this.onDiscountChanged,
    required this.sourceLabel,
    required this.onEdit,
    required this.onCreate,
    required this.creating,
  });

  final List<DesktopMenuLineSelection> lines;
  final int totalQty;
  final double subtotal;
  final double discount;
  final double total;
  final TextEditingController noteCtrl;
  final TextEditingController discountCtrl;
  final VoidCallback onDiscountChanged;
  final String sourceLabel;
  final VoidCallback onEdit;
  final Future<void> Function() onCreate;
  final bool creating;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              TfCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: PosColors.primarySoft,
                        borderRadius: BorderRadius.circular(PosRadii.tile),
                        border: Border.all(color: PosColors.line, width: 1),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: PosColors.primaryDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TfText(
                            text.isBn ? 'অর্ডার রিভিউ' : 'Review order',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: PosColors.slate,
                            ),
                          ),
                          const SizedBox(height: 2),
                          TfText(
                            text.isBn
                                ? '${tfFormatNumber(context, totalQty)} আইটেম · ${tfFormatCurrency(context, total)}'
                                : '${tfFormatNumber(context, totalQty)} items · ${tfFormatCurrency(context, total)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: PosColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TfCard(
                padded: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: TfSectionHeader(
                              label: text.sourceLabel,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 12),
                          TfText(
                            sourceLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: PosColors.slate,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                      color: PosColors.line,
                      height: 1,
                      thickness: 0.5,
                    ),
                    ...lines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: TfText(
                                '${tfFormatNumber(context, line.qty)}×',
                                style: TextStyle(
                                  fontFamily: tfFontFamily(context),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: PosColors.slate,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              child: TfText(
                                line.localizedDisplayName(app.language),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: PosColors.slate,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TfText(
                              tfFormatCurrency(context, line.lineTotal),
                              style: TextStyle(
                                fontFamily: tfFontFamily(context),
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: PosColors.slate,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                      child: TfButton(
                        label: text.editItemsAction,
                        icon: Icons.edit_outlined,
                        variant: TfButtonVariant.ghost,
                        size: TfButtonSize.sm,
                        fullWidth: false,
                        onPressed: onEdit,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: Row(
                  children: [
                    TfText(
                      text.kitchenNote,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: PosColors.slate,
                      ),
                    ),
                    const SizedBox(width: 6),
                    TfText(
                      text.kitchenNoteOptional,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PosColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              TfCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: TextField(
                  controller: noteCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 3,
                  style: TextStyle(
                    fontFamily: tfFontFamily(context),
                    fontSize: 14,
                    color: PosColors.slate,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isCollapsed: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    hintText: text.kitchenNoteHint,
                    hintStyle: TextStyle(
                      fontFamily: tfFontFamily(context),
                      color: PosColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 6),
                child: TfText(
                  text.isBn ? 'ডিসকাউন্ট (ফ্ল্যাট ৳)' : 'Discount (flat ৳)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                  ),
                ),
              ),
              TfCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_offer_outlined,
                      size: 16,
                      color: PosColors.muted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: discountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
                          fontSize: 14,
                          color: PosColors.slate,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isCollapsed: true,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                          hintText: '0',
                          hintStyle: TextStyle(
                            fontFamily: tfFontFamily(context),
                            color: PosColors.muted,
                            fontSize: 14,
                          ),
                        ),
                        onChanged: (_) => onDiscountChanged(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        TfStickyCTA(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hasDiscount = discount > 0;
              final action = TfButton(
                label: creating ? '...' : text.sendToKitchen,
                icon: creating ? null : TfNavIcon.check,
                size: TfButtonSize.lg,
                onPressed: creating ? null : () => onCreate(),
              );
              final summaryCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasDiscount) ...[
                    TfText(
                      '${text.isBn ? 'সাবটোটাল' : 'Subtotal'}: ${tfFormatCurrency(context, subtotal)}',
                      style: TextStyle(
                        fontFamily: tfFontFamily(context),
                        color: PosColors.muted,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    TfText(
                      '${text.isBn ? 'ডিসকাউন্ট' : 'Discount'}: -${tfFormatCurrency(context, discount)}',
                      style: TextStyle(
                        fontFamily: tfFontFamily(context),
                        color: PosColors.danger,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  TfText(
                    '${text.totalLabel}: ${tfFormatCurrency(context, total)}',
                    style: TextStyle(
                      fontFamily: tfFontFamily(context),
                      color: PosColors.slate,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );
              if (constraints.maxWidth < 360) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [summaryCol, const SizedBox(height: 8), action],
                );
              }
              return Row(
                children: [
                  Expanded(child: summaryCol),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: action),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TfText(
          label,
          style: TextStyle(
            fontSize: 13,
            color: PosColors.muted,
            fontWeight: FontWeight.w400,
          ),
        ),
        const Spacer(),
        TfText(
          value,
          style: TextStyle(
            fontSize: 13,
            color: PosColors.slate,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _OrderCreatedStep extends StatelessWidget {
  const _OrderCreatedStep({
    required this.order,
    required this.serviceLabel,
    required this.total,
    required this.printingKot,
    required this.onPrintKot,
    required this.onDone,
  });

  final OrderModel? order;
  final String serviceLabel;
  final double total;
  final bool printingKot;
  final VoidCallback? onPrintKot;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isBn = text.isBn;
    final source = serviceLabel.isEmpty
        ? (isBn ? 'পার্সেল' : 'Parcel')
        : serviceLabel;
    final orderNo = order?.displaySequence ?? '#order';
    final qrData = order == null
        ? orderNo
        : 'terafoods://order/${order!.id}?no=$orderNo';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: PosColors.successSoft,
                      borderRadius: BorderRadius.circular(PosRadii.pill),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 32,
                      color: PosColors.success,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TfText(
                    text.orderCreatedTitle,
                    style: const TextStyle(
                      color: PosColors.slate,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TfText(
                    orderNo,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: tfFontFamily(context),
                      color: PosColors.primaryDark,
                      fontSize: 54,
                      fontWeight: FontWeight.w700,
                      height: 0.95,
                      letterSpacing: 0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TfText(
                    '$source · ${tfFormatCurrency(context, order?.total ?? total)}',
                    style: TextStyle(
                      fontFamily: tfFontFamily(context),
                      color: PosColors.muted,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CreatedOrderBillCard(
                    order: order,
                    fallbackOrderNo: orderNo,
                    source: source,
                    fallbackTotal: total,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      borderRadius: BorderRadius.circular(PosRadii.lg),
                      border: Border.all(color: PosColors.line, width: 1),
                    ),
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: 156,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: PosColors.primaryDark,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: PosColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TfButton(
                  key: const ValueKey('created-order-kot'),
                  label: printingKot ? '...' : 'KOT',
                  icon: printingKot ? null : Icons.soup_kitchen_outlined,
                  variant: TfButtonVariant.paper,
                  size: TfButtonSize.lg,
                  onPressed: printingKot ? null : onPrintKot,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TfButton(
                  key: const ValueKey('created-order-home'),
                  label: 'Done',
                  labelBn: 'সম্পন্ন',
                  icon: Icons.home_outlined,
                  variant: TfButtonVariant.dark,
                  size: TfButtonSize.lg,
                  onPressed: onDone,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreatedOrderBillCard extends StatelessWidget {
  const _CreatedOrderBillCard({
    required this.order,
    required this.fallbackOrderNo,
    required this.source,
    required this.fallbackTotal,
  });

  final OrderModel? order;
  final String fallbackOrderNo;
  final String source;
  final double fallbackTotal;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final orderNo = order?.displaySequence ?? fallbackOrderNo;
    final items = order?.items ?? const <OrderItem>[];
    final total = order?.total ?? fallbackTotal;

    return TfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountLine(label: text.orderLabel, value: orderNo),
          const SizedBox(height: 8),
          _AmountLine(label: text.sourceLabel, value: source),
          if (items.isNotEmpty) ...[
            const Divider(height: 20, color: PosColors.line),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: TfText(
                        '${tfFormatNumber(context, item.qty)}×',
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PosColors.slate,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TfText(
                        item.localizedName(app.language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: PosColors.slate,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TfText(
                      tfFormatCurrency(context, item.lineTotal),
                      style: TextStyle(
                        fontSize: 13,
                        color: PosColors.slate,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const Divider(height: 20, color: PosColors.line),
          if (order != null && order!.subtotal > 0 && order!.vatAmount > 0) ...[
            _AmountLine(
              label: text.subtotalLabel,
              value: tfFormatCurrency(context, order!.subtotal),
            ),
            const SizedBox(height: 8),
            _AmountLine(
              label: text.vatLabelWithPercent(order!.vatRatePercent),
              value: tfFormatCurrency(context, order!.vatAmount),
            ),
            const SizedBox(height: 8),
          ],
          if (order != null && order!.deliveryCharge > 0) ...[
            _AmountLine(
              label: text.menuDeliveryCharge,
              value: tfFormatCurrency(context, order!.deliveryCharge),
            ),
            const SizedBox(height: 8),
          ],
          _AmountLine(
            label: text.totalLabel,
            value: tfFormatCurrency(context, total),
          ),
        ],
      ),
    );
  }
}

class _WizardTableCell extends StatelessWidget {
  const _WizardTableCell({
    required this.label,
    required this.isSelected,
    required this.order,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final OrderModel? order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final occupied = order != null && !isSelected;
    final mins = order != null
        ? DateTime.now().difference(order!.createdAt.toLocal()).inMinutes
        : 0;

    Color bg;
    Color borderColor;
    Color numberColor;
    String subtitle;

    if (isSelected) {
      bg = PosColors.primarySoft;
      borderColor = PosColors.primaryDark;
      numberColor = PosColors.primaryDark;
      subtitle = text.isBn ? 'নির্বাচিত' : 'Selected';
    } else if (occupied) {
      bg = PosColors.seatTint;
      borderColor = PosColors.seatLine;
      numberColor = PosColors.seatInk;
      subtitle = text.agoMinutes(mins);
    } else {
      bg = PosColors.surface;
      borderColor = PosColors.line;
      numberColor = PosColors.text;
      subtitle = text.tableVacant;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(PosRadii.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: occupied ? null : onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.tile),
            border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TfText(
                label,
                style: TextStyle(
                  fontFamily: tfFontFamily(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: numberColor,
                  height: 1.1,
                ),
              ),
              const Spacer(),
              if (isSelected)
                TfText(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: numberColor,
                  ),
                )
              else if (order != null) ...[
                TfText(
                  tfFormatCurrency(context, order!.total),
                  style: TextStyle(
                    fontFamily: tfFontFamily(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: PosColors.seatInk,
                    height: 1.1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 2),
                TfText(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PosColors.seatInk,
                  ),
                ),
              ] else
                TfText(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PosColors.muted,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


