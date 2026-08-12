import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../core/widgets/guided_tour.dart';
import '../../models/account_role.dart';
import '../../models/menu_item.dart';
import '../../models/order_item.dart';
import '../../models/order_model.dart';
import '../../models/order_payment_method.dart';
import '../../models/order_service_type.dart';
import '../../models/order_source.dart';
import '../../models/order_status.dart';
import '../../models/pos_notification.dart';
import '../desktop_pos/widgets/menu_line_customizer.dart';
import '../tables/pos_table_cell.dart';
import 'delivery_details_sheet.dart';
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
  bool startWithCodeMode = false,
}) async {
  final app = AppScope.of(context);
  // Full menu, including 86'd items — the grid/code list render them dimmed
  // and untappable instead of silently vanishing (an all-unavailable menu used
  // to show an empty picker with no explanation).
  final menuItems = app.menuItems;
  final tableCount = app.serverConfig.tableCount;

  final dineInOpenOrders = app
      .ordersFor()
      .where((o) => o.status.isOpen && o.serviceType == OrderServiceType.dineIn)
      .toList();

  // Counter-only outlet (no tables configured): skip the source/table step
  // and go straight to add-items; service type is chosen on review.
  final counterMode = tableCount == 0;

  String? result;
  do {
    result = await Navigator.of(context).push<String?>(
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => _NewOrderPage(
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
          startWithCodeMode: startWithCodeMode,
          onCreateOrder: (result) async {
            final order = await app.createManualOrder(
              requestedItems: result.items,
              tableNo: result.tableNo,
              note: result.note,
              serviceType: result.serviceType,
              customerName: result.customerName,
              paymentMethod: null,
              discountLabel: result.discountLabel,
              discountAmount: result.discountAmount,
            );
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
            return order;
          },
        ),
      ),
    );
  } while (result == 'newOrder');
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(AppScope.of(context).playWizardSuccessSound());
    });
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
              tableLabel: widget.serviceLabel,
              onClose: () => Navigator.pop(context),
              onBack: null,
              counterMode: true,
            ),
            Expanded(
              child: _OrderCreatedStep(
                order: widget.order,
                serviceLabel: widget.serviceLabel,
                total: widget.order.totalAfterDiscount,
                onNewOrder: () => Navigator.pop(context),
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
  // Completed tab defaults to the optional "shift" scope (completed orders
  // since the configured shift start). Lifting it shows every completed order.
  bool _seeAllCompleted = false;
  // Completed-tab search/filter (owner-only backoffice). The search bar is
  // persistent inside the Completed tab; filters open from its trailing icon.
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }
  // Ongoing cards show a live age with escalation; one screen-level tick
  // keeps every card fresh without per-card timers (tables_screen pattern).
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(_onTabChanged);
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {
        // Leaving the Completed tab returns it to the shift scope next visit.
        if (_tabs.index != 1) _seeAllCompleted = false;
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _searchController.dispose();
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Orders home reads orders (+ hasMore/loadingMore, both in the orders
    // aspect), language, and menu availability — not printer/sync/inventory.
    final app = AppScope.selectMany(context, const [
      // `settings` because the completed-tab shift scope reads serverConfig.
      AppAspect.orders,
      AppAspect.language,
      AppAspect.menu,
      AppAspect.settings,
      AppAspect.account,
    ]);
    final rawOrders = app.ordersFor();
    final language = app.language;
    // Search/filter (top-bar icons) are owner-only in backoffice mode — hidden
    // for managers and when an owner switches to the manager ("manage") view.
    final canSearch = app.isOwner && app.accountRole == AccountRole.owner;
    final searchQuery =
        canSearch ? _searchController.text.trim() : '';
    final completedBounds = _seeAllCompleted
        ? null
        : OrderListFilters.shiftBoundsFor(
            DateTime.now(),
            startMinute: app.shiftModeActive
                ? app.serverConfig.shiftStartMinute
                : null,
            endMinute: app.shiftModeActive
                ? app.serverConfig.shiftEndMinute
                : null,
          );
    final derived = _deriveOrders(
      rawOrders,
      _filters,
      searchQuery,
      language,
      completedBounds,
    );
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
      seeAllShortcut: _seeAllCompleted || _completedOrders(rawOrders).isEmpty
          ? null
          : _EmptyShortcut(
              label: text.seeAll,
              onTap: () => setState(() => _seeAllCompleted = true),
            ),
    );
    _syncTabWithPendingOrders(pendingCount, ongoingOrders.length);

    return Scaffold(
      backgroundColor: PosColors.background,
      floatingActionButton: canCreate
          ? TourSpot(
              name: 'orders.newOrderFab',
              child: TfFab(
                tooltip: text.newOrder,
                onPressed: () =>
                    openNewOrderForm(context, onCreated: () => _tabs.index = 0),
              ),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            TfGlobalTopBar(
              title: text.orders,
              onNavigateToTarget: widget.onNavigateToTarget,
            ),
            const SizedBox(height: PosSpacing.sp1),
            TourSpot(
              name: 'orders.tabs',
              child: _TabStrip(
                controller: _tabs,
                ongoingCount: ongoingOrders.length,
                completedCount: completedOrders.length,
              ),
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
                    showDateHeaders: false,
                    onPrintBill: (o) => _printBill(context, o),
                    onPrintKot: (o) => _printKot(context, o),
                    onOpen: (o) => o.status.adminStatus == OrderStatus.pending
                        ? _showPendingOrderDetails(context, o)
                        : _openEditOrderSheet(context, o),
                    onStatus: (o, s) => _changeStatus(context, o, s),
                    hasMore: app.hasMoreOrders,
                    loadingMore: app.loadingMoreOrders,
                    onLoadMore: app.loadMoreOrders,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (canSearch)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: TourSpot(
                            name: 'orders.search',
                            child: TfSearchField(
                              controller: _searchController,
                              hintText: text.orderSearchHint,
                              onChanged: (_) => setState(() {}),
                              // Filter icon while idle; ✕ while typing.
                              onClear: _searchController.text.trim().isEmpty
                                  ? null
                                  : _clearSearch,
                              trailingIcon: Icons.tune_rounded,
                              onTrailingPressed: () =>
                                  _openOrderFilters(context),
                              trailingIconActive: _filters.isActive,
                            ),
                          ),
                        ),
                      Expanded(
                        child: _OrderList(
                          orders: completedOrders,
                          emptyTitle: app.shiftModeActive && !_seeAllCompleted
                              ? text.noCompletedThisShift
                              : text.noCompletedOrders,
                          completedTab: true,
                          shiftStartMinute: app.shiftModeActive
                              ? app.serverConfig.shiftStartMinute
                              : null,
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
                          seeAllCompleted: _seeAllCompleted,
                          onToggleShiftScope: () => setState(
                            () => _seeAllCompleted = !_seeAllCompleted,
                          ),
                          hasMore: app.hasMoreOrders,
                          loadingMore: app.loadingMoreOrders,
                          onLoadMore: app.loadMoreOrders,
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
              '৳${order.totalAfterDiscount.toStringAsFixed(0)} '
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

  /// Completed orders whose local [OrderModel.createdAt] falls inside the
  /// optional shift window; a null window keeps every completed order.
  List<OrderModel> _completedOrdersInScope(
    List<OrderModel> orders,
    ({DateTime? startInclusive, DateTime? endExclusive})? bounds,
  ) {
    if (bounds == null) return _completedOrders(orders);
    return orders
        .where((o) {
          if (o.status.adminStatus != OrderStatus.completed) return false;
          final at = o.createdAt.toLocal();
          if (bounds.startInclusive != null &&
              at.isBefore(bounds.startInclusive!)) {
            return false;
          }
          if (bounds.endExclusive != null &&
              !at.isBefore(bounds.endExclusive!)) {
            return false;
          }
          return true;
        })
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
    ({DateTime? startInclusive, DateTime? endExclusive})? completedBounds,
  ) {
    final cached = _cachedDerivation;
    if (cached != null &&
        identical(cached.raw, raw) &&
        identical(cached.filters, filters) &&
        cached.searchQuery == searchQuery &&
        cached.language == language &&
        cached.completedBounds == completedBounds) {
      return cached;
    }
    final filterMatched = raw
        .where((o) => filters.matches(o))
        .toList(growable: false);
    final allOrders = filterMatched
        .where((o) => _matchesOrderSearch(o, searchQuery, language))
        .toList(growable: false);
    final ongoingOrders = _ongoingOrders(allOrders)..sort(_sortOrders);
    final completedOrders =
        _completedOrdersInScope(allOrders, completedBounds)
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final unfilteredCompleted = _completedOrdersInScope(raw, completedBounds);
    final searchBaseCompleted =
        _completedOrdersInScope(filterMatched, completedBounds);
    if (kDebugMode) {
      debugPrint(
        '[QB-ORDERS-DIAG] derive raw=${raw.length} '
        'filterMatched=${filterMatched.length} '
        'afterSearch=${allOrders.length} '
        'ongoing=${ongoingOrders.length} completed=${completedOrders.length} '
        'unfilteredOngoing=${_ongoingOrders(raw).length} '
        'unfilteredCompleted=${unfilteredCompleted.length} '
        'searchBaseOngoing=${_ongoingOrders(filterMatched).length} '
        'searchBaseCompleted=${searchBaseCompleted.length} '
        'query="$searchQuery" filtersActive=${filters.isActive} '
        'dateRange=${filters.dateRange.name} source=${filters.source?.name} '
        'shift=${completedBounds == null ? "all" : "scope"} '
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
      completedBounds: completedBounds,
      filterMatched: filterMatched,
      allOrders: allOrders,
      unfilteredOngoing: _ongoingOrders(raw),
      unfilteredCompleted: unfilteredCompleted,
      searchBaseOngoing: _ongoingOrders(filterMatched),
      searchBaseCompleted: searchBaseCompleted,
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
    _EmptyShortcut? seeAllShortcut,
  }) {
    if (currentFiltered.isNotEmpty) return null;
    final text = AppScope.of(context).strings;
    if (searchActive && currentSearchBase.isNotEmpty) {
      return _EmptyShortcut(
        label: text.clearSearch,
        onTap: () => setState(() {
          _searchController.clear();
        }),
      );
    }
    if (seeAllShortcut != null) return seeAllShortcut;
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
    final app = AppScope.read(context);
    final result = await showModalBottomSheet<OrderListFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _OrdersFilterSheet(initial: _filters, strings: app.strings),
    );
    if (result != null && mounted) {
      setState(() {
        _filters = result;
        // A picked date range takes over the completed tab from the shift
        // scope; choosing "all" hands control back to the shift.
        _seeAllCompleted = result.dateRange != OrderDateRange.all;
      });
    }
  }

  Future<void> _printKot(BuildContext context, OrderModel order) async {
    final app = AppScope.read(context);
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
    final app = AppScope.read(context);
    if (!app.isManager) return;
    final text = app.strings;
    // When settle-and-save is enabled (Settings > Ordering > bKash/Nagad
    // payments), show the payment method modal before completing. Otherwise
    // go straight to print. Re-prints on already-completed orders always skip
    // the modal.
    if (order.status.adminStatus != OrderStatus.completed) {
      if (app.settleAndSaveEnabled) {
        final settled = await showSettleAndSaveDialog(context, order: order);
        if (settled == null || !context.mounted) return;
        // Persist the chosen payment mode so the printed bill (and its cloud
        // copy) show the real method instead of the Cash fallback.
        await app.updateOrderDetails(
          order.id,
          serviceType: order.serviceType,
          paymentMethod: settled,
        );
        final fresh = await app.database.getOrderById(order.id);
        if (fresh != null && mounted) {
          order = fresh;
        }
      }
      await app.updateOrderStatus(order.id, OrderStatus.completed);
    }
    if (!context.mounted) return;
    final ok = await app.printCustomerInvoice(order);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TfText(text.billPrinted(order.displaySequence))),
      );
    } else if (_isPrinterNotConnected(app.printerState.lastError)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TfText(text.noPrinterOrderCompleted)),
      );
    }
  }

  static bool _isPrinterNotConnected(String? error) {
    if (error == null || error.trim().isEmpty) return false;
    const messages = <String>{
      'Printer is not connected.',
      'Connect a USB printer or select a Bluetooth printer first.',
      'Select a Bluetooth printer first.',
      'Turn on Bluetooth first.',
      'USB printer is not ready.',
      'Bluetooth is not ready.',
    };
    return messages.contains(error.trim());
  }

  Future<void> _changeStatus(
    BuildContext context,
    OrderModel order,
    OrderStatus status,
  ) async {
    final app = AppScope.read(context);
    if (!app.isManager) return;
    if (status.isRejected) {
      await app.deleteOrder(order.id);
    } else {
      await app.updateOrderStatus(order.id, status);
    }
  }

  Future<void> _openEditOrderSheet(BuildContext context, OrderModel order) =>
      openEditOrderSheet(context, order);

  Future<void> _showCompletedOrderActions(
    BuildContext context,
    OrderModel order,
  ) async {
    final text = AppScope.read(context).strings;
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
              leading: const Icon(Icons.print_outlined, color: PosColors.slate),
              title: TfText(text.reprintAction),
              onTap: () {
                Navigator.pop(context);
                _printBill(context, order);
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
                style: TfTextStyles.body.copyWith(color: PosColors.danger),
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
    discountLabel: result.discountChanged ? result.discountLabel : null,
    discountAmount: result.discountChanged ? result.discountAmount : null,
    clearDiscount: result.discountChanged && result.discountAmount <= 0,
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
  if (result.addedItems != null && result.addedItems!.isNotEmpty) {
    reasons.add('Added: ${result.addedItems!.join(', ')}');
  }
  if (result.removedItems != null && result.removedItems!.isNotEmpty) {
    reasons.add('Removed: ${result.removedItems!.join(', ')}');
  }
  if (result.changedItems != null && result.changedItems!.isNotEmpty) {
    reasons.add('Changed: ${result.changedItems!.join(', ')}');
  }
  if (result.discountChanged) {
    reasons.add(
      result.discountAmount > 0
          ? 'Discount: ${result.discountLabel ?? ''} '
                '−৳${result.discountAmount.toStringAsFixed(2)}'
          : 'Discount removed',
    );
  }
  final hasDetailEdit =
      result.serviceType != (order.serviceType ?? OrderServiceType.dineIn) ||
      result.tableNo != order.tableNo ||
      result.customerName != order.customerName ||
      result.deliveryAddress != order.deliveryAddress ||
      result.mobileNumber != order.mobileNumber;
  if (hasDetailEdit && !result.itemsChanged) {
    reasons.add('Order details updated');
  }
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
    required this.completedBounds,
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
  final ({DateTime? startInclusive, DateTime? endExclusive})? completedBounds;
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
                  borderRadius: BorderRadius.circular(PosRadii.pill),
                ),
              ),
            ),
            TfText(
              t.filterOrders,
              style: TfTextStyles.appBarTitle.copyWith(
                fontFamily: tfFontFamily(context),
                color: PosColors.text,
              ),
            ),
            const SizedBox(height: 20),
            TfText(
              t.filterByDate,
              style: TfTextStyles.eyebrow.copyWith(
                fontFamily: tfFontFamily(context),
                color: PosColors.textTer,
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
              style: TfTextStyles.eyebrow.copyWith(
                fontFamily: tfFontFamily(context),
                color: PosColors.textTer,
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

sealed class _ListEntry {
  const _ListEntry();
}

class _DateHeaderEntry extends _ListEntry {
  final String label;
  const _DateHeaderEntry(this.label);
}

class _OrderCardEntry extends _ListEntry {
  final OrderModel order;
  const _OrderCardEntry(this.order);
}

class _FooterEntry extends _ListEntry {
  const _FooterEntry();
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
    this.showDateHeaders = true,
    this.completedTab = false,
    this.shiftStartMinute,
    this.seeAllCompleted = false,
    this.onToggleShiftScope,
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

  /// Whether to group cards under day headers. Off for Ongoing (no dates there).
  final bool showDateHeaders;

  /// Completed-tab record cards are taller than ongoing tickets; the fixed
  /// grid extent (width ≥ 700) follows this.
  final bool completedTab;

  /// When the completed tab follows shift mode, date headers group by the
  /// shift's opening day (an order at 1:30 AM headers under yesterday).
  final int? shiftStartMinute;

  /// Completed tab: true while the shift scope is lifted (all completed).
  final bool seeAllCompleted;

  /// Flips the completed tab between the shift scope and "all completed".
  /// Only meaningful on the completed tab.
  final VoidCallback? onToggleShiftScope;

  /// Whether the underlying `orders` list has more pages available.
  final bool hasMore;

  /// Whether a load-more fetch is currently in flight.
  final bool loadingMore;

  /// Fired when scrolling near the bottom; harmless when `hasMore` is false.
  final Future<void> Function()? onLoadMore;

  bool get _showFooter => hasMore && onLoadMore != null;

  static List<_ListEntry> _buildEntries(
    List<OrderModel> orders,
    bool showFooter,
    bool showDateHeaders,
    int? shiftStartMinute,
    AppStrings text,
  ) {
    final entries = <_ListEntry>[];
    DateTime? lastDate;
    for (final order in orders) {
      if (showDateHeaders) {
        final local = order.createdAt.toLocal();
        final orderDate = shiftStartMinute == null
            ? DateTime(local.year, local.month, local.day)
            : OrderListFilters.shiftDayFor(local, shiftStartMinute);
        if (lastDate == null || orderDate != lastDate) {
          entries.add(_DateHeaderEntry(text.formatDateHeader(orderDate)));
          lastDate = orderDate;
        }
      }
      entries.add(_OrderCardEntry(order));
    }
    if (showFooter) entries.add(const _FooterEntry());
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final toggle = completedTab ? onToggleShiftScope : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (toggle != null && seeAllCompleted)
          _CompletedScopeBar(onToggleShiftScope: toggle),
        Expanded(
          child: _buildBody(context),
        ),
        if (toggle != null && !seeAllCompleted && orders.isNotEmpty)
          _SeeAllCompletedBar(onToggleShiftScope: toggle),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
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
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 480,
                    mainAxisExtent: completedTab
                        ? kGridExtentCompleted
                        : kGridExtentOngoing,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: itemCount,
                  itemBuilder: (_, i) {
                    if (_showFooter && i == orders.length) {
                      return _LoadMoreFooter(loading: loadingMore);
                    }
                    return _OrderCard(
                      key: ValueKey(orders[i].id),
                      order: orders[i],
                      dense: true,
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
              : () {
                  final app = AppScope.of(context);
                  final entries = _buildEntries(
                    orders,
                    _showFooter,
                    showDateHeaders,
                    shiftStartMinute,
                    app.strings,
                  );
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 104),
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      return switch (entries[i]) {
                        _DateHeaderEntry(label: final l) => Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 2),
                          child: TfText(
                            l,
                            style: TfTextStyles.eyebrow.copyWith(
                              color: PosColors.muted,
                            ),
                          ),
                        ),
                        _OrderCardEntry(order: final o) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _OrderCard(
                            key: ValueKey(o.id),
                            order: o,
                            onPrintBill: () => onPrintBill(o),
                            onPrintKot: () => onPrintKot(o),
                            onOpen: onOpen == null ? null : () => onOpen!(o),
                            onStatus: (s) => onStatus(o, s),
                            onCompletedLongPress: onCompletedLongPress == null
                                ? null
                                : () => onCompletedLongPress!(o),
                          ),
                        ),
                        _FooterEntry() => _LoadMoreFooter(loading: loadingMore),
                      };
                    },
                  );
                }(),
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

/// Pinned bottom CTA on the Completed tab while the shift scope is on:
/// lifts to "all completed orders".
class _SeeAllCompletedBar extends StatelessWidget {
  const _SeeAllCompletedBar({required this.onToggleShiftScope});

  final VoidCallback onToggleShiftScope;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: TfButton(
        label: text.seeAll,
        icon: Icons.unfold_more_rounded,
        variant: TfButtonVariant.ghost,
        fullWidth: true,
        onPressed: onToggleShiftScope,
      ),
    );
  }
}

/// Top scope bar on the Completed tab while "all completed" is showing:
/// makes it obvious the shift is lifted and offers a way back.
class _CompletedScopeBar extends StatelessWidget {
  const _CompletedScopeBar({required this.onToggleShiftScope});

  final VoidCallback onToggleShiftScope;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          const Icon(Icons.history_rounded, size: 18, color: PosColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TfText(
              text.allCompletedOrdersLabel,
              style: TfTextStyles.bodyMuted,
            ),
          ),
          TfChip(
            label: text.currentShiftLabel,
            active: true,
            small: true,
            onTap: onToggleShiftScope,
          ),
        ],
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
                    color: PosColors.neutralSoft,
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
                  style: TfTextStyles.appBarTitle.copyWith(
                    color: PosColors.slate,
                  ),
                ),
                const SizedBox(height: 8),
                TfText(
                  messageText,
                  textAlign: TextAlign.center,
                  style: TfTextStyles.bodyMuted,
                ),
                if (!canCreate) ...[
                  const SizedBox(height: 12),
                  TfText(
                    text.addMenuItemsBeforeOrders,
                    textAlign: TextAlign.center,
                    style: TfTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: PosColors.danger,
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

/// Pending orders unaccepted beyond this show the LATE badge.
const Duration kPendingLateAfter = Duration(minutes: 20);

/// Accepted-but-unbilled age escalation on ongoing cards:
/// neutral → amber ([PosColors.late]) → red ([PosColors.danger]).
const Duration kAcceptedAmberAfter = Duration(minutes: 45);
const Duration kAcceptedDangerAfter = Duration(minutes: 120);

/// Grid-card extents (width ≥ 700). Ongoing: header + summary + sm footer.
/// Completed: header + capped item rows + money block + meta line.
const double kGridExtentOngoing = 168;
const double kGridExtentCompleted = 236;

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
    // Icon boxes wash neutral (POS-utilitarian) — the glyph color alone
    // carries the channel hue.
    case OrderSource.cloud:
      return const _ChannelStyle(
        'storefront',
        TfNavIcon.storefront,
        PosColors.channelWebsite,
        PosColors.channelNeutralSoft,
      );
    case OrderSource.facebookMessenger:
      return const _ChannelStyle(
        'chatbot',
        TfNavIcon.chat,
        PosColors.channelMessenger,
        PosColors.channelNeutralSoft,
      );
    case OrderSource.desktopPos:
    case OrderSource.localLan:
      return const _ChannelStyle(
        'counter',
        TfNavIcon.counter,
        PosColors.channelCounter,
        PosColors.channelNeutralSoft,
      );
    case OrderSource.manual:
      final role = (order.createdByRole ?? '').toLowerCase();
      if (role == 'waiter' || role == 'staff') {
        return const _ChannelStyle(
          'waiter',
          TfNavIcon.waiter,
          PosColors.channelWaiter,
          PosColors.channelNeutralSoft,
        );
      }
      return const _ChannelStyle(
        'manager',
        TfNavIcon.manager,
        PosColors.channelManager,
        PosColors.channelNeutralSoft,
      );
  }
}

class _OrderCard extends StatefulWidget {
  const _OrderCard({
    required this.order,
    required this.onPrintBill,
    required this.onPrintKot,
    required this.onOpen,
    required this.onStatus,
    this.onCompletedLongPress,
    this.dense = false,
    super.key,
  });

  final OrderModel order;
  final VoidCallback onPrintBill;
  final VoidCallback onPrintKot;
  final VoidCallback? onOpen;
  final ValueChanged<OrderStatus> onStatus;
  final VoidCallback? onCompletedLongPress;

  /// Fixed-extent grid tile (width ≥ 700): completed cards cap their item
  /// rows statically because the tile cannot grow.
  final bool dense;

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  // Completed cards cap their item rows; this toggles the "+N more" reveal.
  bool _expanded = false;

  // Phone completed cards show up to this many rows collapsed; dense (grid)
  // tiles are fixed-extent and cap lower, statically.
  static const int _completedRowCap = 8;
  static const int _denseRowCap = 3;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final app = AppScope.of(context);
    final canPrint = app.isManager;
    final adminStatus = order.status.adminStatus;
    final isPending = adminStatus == OrderStatus.pending;
    final isAccepted = adminStatus == OrderStatus.accepted;
    final isCompleted = adminStatus == OrderStatus.completed;

    return TfCard(
      padded: false,
      clip: true,
      borderColor: isPending ? PosColors.pendingBorder : PosColors.line,
      child: TourSpot(
        name: 'orders.cardOpen',
        child: InkWell(
          onTap: widget.onOpen,
          onLongPress: isCompleted
              ? widget.onCompletedLongPress
              : (canPrint && isAccepted ? widget.onPrintBill : null),
          child: Padding(
            padding: const EdgeInsets.all(PosDensity.cardPad),
            child: isCompleted
                ? _completedBody(context, canPrint: canPrint)
                : _ongoingBody(
                    context,
                    isPending: isPending,
                    isAccepted: isAccepted,
                    canPrint: canPrint,
                  ),
          ),
        ),
      ),
    );
  }

  /// Truncated operational card: serial + type + total, live escalating age,
  /// one-line item summary, compact right-aligned actions.
  Widget _ongoingBody(
    BuildContext context, {
    required bool isPending,
    required bool isAccepted,
    required bool canPrint,
  }) {
    final order = widget.order;
    final app = AppScope.of(context);
    final text = app.strings;
    final createdAt = order.createdAt.toLocal();
    // Live age: the screen-level 30s tick rebuilds cards, so this stays fresh.
    final age = DateTime.now().difference(createdAt);
    final lateMinutes = isPending && age > kPendingLateAfter
        ? age.inMinutes - kPendingLateAfter.inMinutes
        : 0;
    final isLate = lateMinutes > 0;
    // Accepted orders lingering unbilled escalate amber, then red; pending
    // urgency is carried by the LATE badge instead.
    final Color ageColor = isAccepted && age >= kAcceptedDangerAfter
        ? PosColors.danger
        : isAccepted && age >= kAcceptedAmberAfter
        ? PosColors.late
        : PosColors.muted;
    final escalated = !identical(ageColor, PosColors.muted);

    final typeLabel = _sourceLabel(order, text);
    // KOT went to the kitchen: recorded batches (server) or this device's
    // print history. Shown as a quiet check on the subline.
    final kotDone =
        !isPending &&
        (order.kotBatches.isNotEmpty ||
            app.printerService.hasPrintedOrder(order.id));
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TfText(
              order.displaySequence,
              style: TfTextStyles.price.copyWith(
                fontFamily: tfFontFamily(context),
                color: PosColors.text,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: PosColors.addBg,
                borderRadius: BorderRadius.circular(PosRadii.sm),
              ),
              child: TfText(
                typeLabel,
                style: TfTextStyles.label.copyWith(
                  color: PosColors.addBlue,
                ),
              ),
            ),
            const Spacer(),
            // No pending/accepted badge — pending is conveyed by the Accept
            // action + card border. Only surface LATE as an urgency signal.
            if (isLate) ...[
              const SizedBox(width: 8),
              Flexible(
                child: TfStatusBadge(
                  label: text.orderStatusLate(lateMinutes),
                  kind: TfStatusKind.late,
                  upper: false,
                ),
              ),
            ],
            const SizedBox(width: 12),
            TfText(
              tfFormatCurrency(context, order.totalAfterDiscount),
              style: TfTextStyles.rowTitle.copyWith(
                fontFamily: tfFontFamily(context),
                color: PosColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: TfText(
                text.agoMinutes(age.inMinutes),
                style: TfTextStyles.bodyMuted.copyWith(
                  color: ageColor,
                  fontWeight: escalated ? FontWeight.w700 : FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Quiet KOT-sent marker: a small check beside the age once this
            // order's KOT went to the kitchen.
            if (kotDone) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_rounded,
                size: 13,
                color: PosColors.success,
              ),
              const SizedBox(width: 2),
              TfText(
                text.kotAction,
                style: TfTextStyles.bodyMuted.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: text.orderItemsCount(itemQty),
                style: TfTextStyles.bodyMuted.copyWith(
                  fontFamily: tfFontFamily(context),
                  fontWeight: FontWeight.w700,
                  color: PosColors.text,
                ),
              ),
              TextSpan(
                text: ' · $itemsPreview$morePreview',
                style: TfTextStyles.bodyMuted.copyWith(
                  fontFamily: tfFontFamily(context),
                  color: PosColors.ink2,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (canPrint && isPending) ...[
          const SizedBox(height: PosDensity.sectionGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TourSpot(
                name: 'orders.cardReject',
                child: InkWell(
                  onTap: () => widget.onStatus(OrderStatus.rejected),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 40,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: PosColors.lineStrong, width: 1),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: PosColors.danger,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: PosSpacing.sp2),
              TourSpot(
                name: 'orders.cardAccept',
                child: TfButton(
                  label: text.acceptAndSendToKitchen,
                  icon: TfNavIcon.check,
                  variant: TfButtonVariant.success,
                  size: TfButtonSize.sm,
                  fullWidth: false,
                  onPressed: () => widget.onStatus(OrderStatus.accepted),
                ),
              ),
            ],
          ),
        ] else if (canPrint && isAccepted) ...[
          const SizedBox(height: PosDensity.sectionGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  TourSpot(
                    name: 'orders.cardKot',
                    child: TfButton(
                      label: text.kotAction,
                      icon: TfNavIcon.printer,
                      variant: TfButtonVariant.ghost,
                      size: TfButtonSize.sm,
                      fullWidth: false,
                      onPressed: widget.onPrintKot,
                    ),
                  ),
                  // Small green dot = this order's KOT is already printed
                  // (replaces the old "KOT not printed" badge).
                  if (!app.needsKotPrint(order))
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          color: PosColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PosColors.surface,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: PosSpacing.sp2),
              TourSpot(
                name: 'orders.cardBill',
                child: TfButton(
                  label: text.printBillAction,
                  icon: Icons.receipt_long_outlined,
                  variant: TfButtonVariant.primary,
                  size: TfButtonSize.sm,
                  fullWidth: false,
                  onPressed: widget.onPrintBill,
                ),
              ),
            ],
          ),
        ],
      ],
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

  /// Owner-facing record card (QuicklyServices reference): serial + Completed
  /// pill + time-of-day, item rows with per-line amounts, Total block, and a
  /// muted meta line (payment · type · by role).
  Widget _completedBody(BuildContext context, {required bool canPrint}) {
    final order = widget.order;
    final app = AppScope.of(context);
    final text = app.strings;
    final items = order.items;
    final rowCap = widget.dense ? _denseRowCap : _completedRowCap;
    final showAll = _expanded && !widget.dense;
    final visibleCount = showAll
        ? items.length
        : (items.length > rowCap ? rowCap : items.length);
    final hiddenCount = items.length - visibleCount;

    // Meta segments hide when the data is absent (null-safe: never fabricate).
    // Gate on the raw role string — AccountRole.parse defaults unknown/null to
    // manager and would invent a byline for legacy rows.
    final role = (order.createdByRole ?? '').trim();
    final metaSegments = <String>[
      if (order.paymentMethod != null)
        text.isBn
            ? order.paymentMethod!.banglaLabel
            : order.paymentMethod!.label,
      _sourceLabel(order, text),
      if (role.isNotEmpty)
        text.orderTakenBy(
          text.isBn
              ? AccountRole.parse(role).labelBn
              : AccountRole.parse(role).label,
        ),
    ];
    final discountLabel = (order.discountLabel ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TfText(
              order.displaySequence,
              style: TfTextStyles.price.copyWith(
                fontFamily: tfFontFamily(context),
                color: PosColors.text,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: PosColors.addBg,
                borderRadius: BorderRadius.circular(PosRadii.sm),
              ),
              child: TfText(
                _sourceLabel(order, text),
                style: TfTextStyles.label.copyWith(
                  color: PosColors.addBlue,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            // createdAt (not settledAt) so the time always agrees with the
            // createdAt-keyed date group headers above the card.
            TfText(
              text.formatTimeOfDay(order.createdAt),
              style: TfTextStyles.bodyMuted.copyWith(
                fontFamily: tfFontFamily(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < visibleCount; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
            child: _completedItemRow(context, items[i]),
          ),
        if (widget.dense && hiddenCount > 0) ...[
          const SizedBox(height: 4),
          TfText(
            text.showMoreItems(hiddenCount),
            style: TfTextStyles.body.copyWith(
              fontFamily: tfFontFamily(context),
              fontWeight: FontWeight.w600,
              color: PosColors.ink2,
            ),
          ),
        ] else if (!widget.dense && items.length > rowCap) ...[
          const SizedBox(height: 4),
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(PosRadii.xs),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TfText(
                    _expanded
                        ? text.showLess
                        : text.showMoreItems(hiddenCount),
                    style: TfTextStyles.body.copyWith(
                      fontFamily: tfFontFamily(context),
                      fontWeight: FontWeight.w600,
                      color: PosColors.ink2,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: PosColors.ink2,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Container(height: 1, color: PosColors.line),
        const SizedBox(height: 8),
        if (order.discountAmount > 0) ...[
          Row(
            children: [
              Expanded(
                child: TfText(
                  discountLabel.isNotEmpty
                      ? discountLabel
                      : text.menuDiscountSummary,
                  style: TfTextStyles.bodyMuted.copyWith(
                    fontFamily: tfFontFamily(context),
                    color: PosColors.ink2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TfText(
                '−${tfFormatCurrency(context, order.discountAmount)}',
                style: TfTextStyles.rowTitle.copyWith(
                  fontFamily: tfFontFamily(context),
                  color: PosColors.ink2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Expanded(
              child: TfText(
                text.totalLabel,
                style: TfTextStyles.rowTitle.copyWith(
                  fontFamily: tfFontFamily(context),
                  color: PosColors.text,
                ),
              ),
            ),
            TfText(
              tfFormatCurrency(context, order.totalAfterDiscount),
              style: TfTextStyles.rowTitle.copyWith(
                fontFamily: tfFontFamily(context),
                color: PosColors.text,
              ),
            ),
          ],
        ),
        if (metaSegments.isNotEmpty) ...[
          const SizedBox(height: 8),
          TfText(
            metaSegments.join(' · '),
            style: TfTextStyles.bodyMuted.copyWith(
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (canPrint) ...[
          const SizedBox(height: PosDensity.sectionGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TfButton(
                label: text.reprintAction,
                icon: Icons.receipt_long_outlined,
                variant: TfButtonVariant.ghost,
                size: TfButtonSize.sm,
                fullWidth: false,
                onPressed: widget.onPrintBill,
              ),
            ],
          ),
        ],
      ],
    );
  }

  // Fixed 30px qty gutter (order-detail-sheet precedent) + per-line amount:
  // the completed card reads like a receipt, not a preview.
  Widget _completedItemRow(BuildContext context, OrderItem item) {
    final app = AppScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 30,
          child: TfText(
            '${tfFormatNumber(context, item.qty)}×',
            style: TfTextStyles.rowTitle.copyWith(
              fontFamily: tfFontFamily(context),
              color: PosColors.ink2,
            ),
          ),
        ),
        Expanded(
          child: TfText(
            item.localizedName(app.language),
            style: TfTextStyles.body.copyWith(
              fontFamily: tfFontFamily(context),
              fontWeight: FontWeight.w500,
              color: PosColors.text,
              height: 1.35,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        TfText(
          tfFormatCurrency(context, item.lineTotal),
          style: TfTextStyles.body.copyWith(
            fontFamily: tfFontFamily(context),
            fontWeight: FontWeight.w500,
            color: PosColors.text,
            height: 1.35,
          ),
        ),
      ],
    );
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
    this.addedItems,
    this.removedItems,
    this.changedItems,
    this.discountLabel,
    this.discountAmount = 0,
    this.discountChanged = false,
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
  final List<String>? addedItems;
  final List<String>? removedItems;
  final List<String>? changedItems;
  final String? discountLabel;
  final double discountAmount;
  final bool discountChanged;
}

enum _EditDiscountKind { none, flat, percent }

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
    final createdAt = order.createdAt.toLocal();
    final typeLabel = _sourceLabel(order, text);
    final isDelivery = order.serviceType == OrderServiceType.delivery;
    final subtotal = order.items.fold<double>(0, (s, i) => s + i.lineTotal);

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
                        style: TfTextStyles.tileNumber.copyWith(
                          fontFamily: tfFontFamily(context),
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          color: PosColors.text,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TfText(
                          typeLabel,
                          style: TfTextStyles.rowTitle.copyWith(
                            color: PosColors.ink2,
                          ),
                        ),
                      ),
                      TfText(
                        text.orderAgeAgo(createdAt),
                        style: TfTextStyles.bodyMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TfText(
                    text.channelLabel(channel.key),
                    style: TfTextStyles.bodyMuted,
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
                            style: TfTextStyles.eyebrow.copyWith(
                              color: PosColors.muted,
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
                                  style: TfTextStyles.rowTitle.copyWith(
                                    fontFamily: tfFontFamily(context),
                                    color: PosColors.slate,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TfText(
                                  item.localizedName(app.language),
                                  style: TfTextStyles.body.copyWith(
                                      color: PosColors.slate,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TfText(
                                  tfFormatCurrency(context, item.lineTotal),
                                  style: TfTextStyles.rowTitle.copyWith(
                                    fontFamily: tfFontFamily(context),
                                    color: PosColors.slate,
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
                              style: TfTextStyles.body.copyWith(
                                color: PosColors.ink2,
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
                        if (order.discountAmount > 0) ...[
                          const SizedBox(height: 6),
                          _AmountLine(
                            label: isBn ? 'ডিসকাউন্ট' : 'Discount',
                            value:
                                '−${tfFormatCurrency(context, order.discountAmount)}',
                          ),
                        ],
                        const SizedBox(height: 6),
                        _AmountLine(
                          label: isBn ? 'মোট' : 'Total',
                          value: tfFormatCurrency(
                            context,
                            order.totalAfterDiscount,
                          ),
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
                variant: TfButtonVariant.primary,
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
              style: TfTextStyles.body.copyWith(color: PosColors.slate),
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
  late final TextEditingController _discountCtrl;
  _EditDiscountKind _discountKind = _EditDiscountKind.none;
  bool _discountRevealed = false;
  bool _discountAutofocus = false;

  // Working copy of the order's items, keyed by menuItemId.
  final Map<String, int> _itemQty = <String, int>{};
  // Names + unit prices for currently-tracked items, used when the menu item
  // is no longer available (e.g. deleted) so we can still show the line.
  final Map<String, ({String name, double price})> _itemMeta =
      <String, ({String name, double price})>{};
  // Per-line parcel (packed to go) flag, keyed by menuItemId.
  final Map<String, bool> _itemParcel = <String, bool>{};
  late final Map<String, int> _originalItemQty;
  late final Map<String, bool> _originalItemParcel;
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
    final discountLabel = (order.discountLabel ?? '').trim();
    if (order.discountAmount > 0) {
      _discountRevealed = true;
      _discountKind = discountLabel.endsWith('%')
          ? _EditDiscountKind.percent
          : _EditDiscountKind.flat;
      _discountCtrl = TextEditingController(
        text: _discountKind == _EditDiscountKind.percent
            ? discountLabel.replaceFirst(RegExp(r'%$'), '')
            : _moneyText(order.discountAmount),
      );
    } else {
      _discountCtrl = TextEditingController();
    }
    for (final item in order.items) {
      _itemQty[item.menuItemId] = (_itemQty[item.menuItemId] ?? 0) + item.qty;
      _itemMeta[item.menuItemId] = (name: item.name, price: item.price);
      if (item.parcel) _itemParcel[item.menuItemId] = true;
    }
    _originalItemQty = Map<String, int>.from(_itemQty);
    _originalItemParcel = Map<String, bool>.from(_itemParcel);
  }

  @override
  void dispose() {
    _tableCtrl.dispose();
    _noteCtrl.dispose();
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _discountCtrl.dispose();
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
    for (final entry in _itemParcel.entries) {
      if ((_originalItemParcel[entry.key] ?? false) != entry.value) {
        return true;
      }
    }
    for (final key in _originalItemParcel.keys) {
      if (!_itemParcel.containsKey(key) && _originalItemParcel[key] == true) {
        return true;
      }
    }
    return false;
  }

  void _toggleParcel(String menuItemId) {
    setState(() {
      final current = _itemParcel[menuItemId] ?? false;
      if (current) {
        _itemParcel.remove(menuItemId);
      } else {
        _itemParcel[menuItemId] = true;
      }
      _itemsDirty = _detectItemsDirty();
    });
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

  static String _moneyText(double value) {
    final text = value.toStringAsFixed(2);
    return text.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  double get _discountValue =>
      double.tryParse(_discountCtrl.text.replaceAll(',', '')) ?? 0;

  double get _computedDiscount {
    if (_discountKind == _EditDiscountKind.none || _discountValue <= 0) {
      return 0;
    }
    final subtotal = _runningTotal;
    final value = _discountKind == _EditDiscountKind.percent
        ? subtotal * _discountValue / 100
        : _discountValue;
    return double.parse(value.clamp(0, subtotal).toStringAsFixed(2));
  }

  String? _discountError(AppStrings text) {
    if (_discountKind == _EditDiscountKind.none) return null;
    if (_discountValue < 0) {
      return text.isBn ? 'ঋণাত্মক নয়' : "Can't be negative";
    }
    if (_discountKind == _EditDiscountKind.percent && _discountValue > 100) {
      return text.isBn ? 'সর্বোচ্চ ১০০%' : 'Maximum 100%';
    }
    if (_discountKind == _EditDiscountKind.flat &&
        _runningTotal > 0 &&
        _discountValue > _runningTotal) {
      return text.isBn ? 'মোটের বেশি নয়' : "Can't exceed the total";
    }
    return null;
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
                style: TfTextStyles.pushedTitle.copyWith(
                  color: PosColors.slate,
                ),
              ),
              const SizedBox(height: PosDensity.sectionGap),
              // Underline tabs for the service type — DESIGN.md §7c
              // nav-primitive rule (no pill segments for in-content nav).
              TourSpot(
                name: 'orders.editType',
                child: TfTabs(
                  activeIndex: OrderServiceType.values.indexOf(_serviceType),
                  onChanged: (i) =>
                      setState(() => _serviceType = OrderServiceType.values[i]),
                  items: [
                    for (final type in OrderServiceType.values)
                      TfTabItem(label: type.label, labelBn: type.banglaLabel),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_serviceType == OrderServiceType.dineIn)
                TfField(
                  label: 'Table number',
                  labelBn: 'টেবিল নম্বর',
                  controller: _tableCtrl,
                  keyboardType: TextInputType.number,
                ),
              TourSpot(
                name: 'orders.editNote',
                child: TfField(
                  label: 'Order note',
                  labelBn: 'অর্ডার নোট',
                  controller: _noteCtrl,
                  maxLines: 2,
                ),
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
              const SizedBox(height: PosSpacing.sp4),
              Row(
                children: [
                  Expanded(
                    child: TfText(
                      text.isBn ? 'ডিসকাউন্ট' : 'Discount',
                      style: TfTextStyles.sectionHeader.copyWith(
                        fontFamily: tfFontFamily(context),
                        color: PosColors.slate,
                      ),
                    ),
                  ),
                  if (!_discountRevealed)
                    TourSpot(
                      name: 'orders.editDiscountAdd',
                      child: TextButton.icon(
                        onPressed: () => setState(() {
                          _discountRevealed = true;
                          _discountKind = _EditDiscountKind.flat;
                          _discountAutofocus = true;
                        }),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: TfText(
                          text.isBn ? 'ছাড় যোগ করুন' : 'Add discount',
                        ),
                      ),
                    ),
                ],
              ),
              if (_discountRevealed) ...[
                const SizedBox(height: PosDensity.gridGap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TourSpot(
                        name: 'orders.editDiscountField',
                        child: TfField(
                          label: text.isBn ? 'ছাড়ের পরিমাণ' : 'Discount value',
                          controller: _discountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          autofocus: _discountAutofocus,
                          onChanged: (_) => setState(() {}),
                          hint: _discountKind == _EditDiscountKind.percent
                              ? '10'
                              : '50',
                          hintBn: _discountKind == _EditDiscountKind.percent
                              ? '১০'
                              : '৫০',
                          errorText: _discountError(text),
                          hintHelper: _computedDiscount > 0
                              ? '−${tfFormatCurrency(context, _computedDiscount, decimalDigits: 2)}'
                              : null,
                          suffix: TourSpot(
                            name: 'orders.editDiscountKind',
                            child: _DiscountKindMenu(
                              kind: _discountKind,
                              onSelected: (kind) =>
                                  setState(() => _discountKind = kind),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: PosSpacing.sp1),
                    Padding(
                      padding: const EdgeInsets.only(top: 26),
                      child: IconButton(
                        onPressed: () => setState(() {
                          _discountRevealed = false;
                          _discountAutofocus = false;
                          _discountKind = _EditDiscountKind.none;
                          _discountCtrl.clear();
                        }),
                        icon: const Icon(Icons.close_rounded),
                        color: PosColors.muted,
                        tooltip: text.isBn
                            ? 'ডিসকাউন্ট সরান'
                            : 'Remove discount',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: PosSpacing.sp4),
              Row(
                children: [
                  Expanded(
                    child: TfText(
                      text.isBn ? 'আইটেম' : 'Items',
                      style: TfTextStyles.sectionHeader.copyWith(
                        fontFamily: tfFontFamily(context),
                        color: PosColors.slate,
                      ),
                    ),
                  ),
                  TourSpot(
                    name: 'orders.editAddItem',
                    child: TextButton.icon(
                      onPressed: () => _addItemFlow(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: TfText(text.isBn ? 'যোগ করুন' : 'Add item'),
                    ),
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
                    style: TfTextStyles.bodyMuted,
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
                              style: TfTextStyles.rowTitle.copyWith(
                                fontWeight: FontWeight.w500,
                                color: PosColors.slate,
                              ),
                            ),
                            TfText(
                              tfFormatCurrency(
                                context,
                                _metaFor(context, entry.key).price,
                                decimalDigits: 2,
                              ),
                              style: TfTextStyles.rowMoney.copyWith(
                                fontFamily: tfFontFamily(context),
                                fontWeight: FontWeight.w400,
                                color: PosColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: PosSpacing.sp2),
                      TourSpot(
                        name: 'orders.editParcel',
                        child: TfChip(
                          label: text.takeaway,
                          small: true,
                          active: _itemParcel[entry.key] ?? false,
                          leading: const Icon(Icons.shopping_bag_outlined),
                          onTap: () => _toggleParcel(entry.key),
                        ),
                      ),
                      const SizedBox(width: PosSpacing.sp1),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => _changeQty(entry.key, -1),
                      ),
                      SizedBox(
                        width: 28,
                        child: TfText(
                          '${entry.value}',
                          style: TfTextStyles.price.copyWith(
                            fontFamily: tfFontFamily(context),
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
                  child: _computedDiscount > 0
                      ? Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                TfText(
                                  text.isBn ? 'সাবটোটাল' : 'Subtotal',
                                  style: TfTextStyles.bodyMuted,
                                ),
                                TfText(
                                  tfFormatCurrency(
                                    context,
                                    _runningTotal,
                                    decimalDigits: 2,
                                  ),
                                  style: TfTextStyles.rowMoney.copyWith(
                                    fontFamily: tfFontFamily(context),
                                    fontWeight: FontWeight.w400,
                                    color: PosColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: PosDensity.gridGap),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                TfText(
                                  text.isBn ? 'ডিসকাউন্ট' : 'Discount',
                                  style: TfTextStyles.bodyMuted,
                                ),
                                TfText(
                                  '−${tfFormatCurrency(context, _computedDiscount, decimalDigits: 2)}',
                                  style: TfTextStyles.rowMoney.copyWith(
                                    fontFamily: tfFontFamily(context),
                                    color: PosColors.muted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: PosDensity.gridGap),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                TfText(
                                  text.isBn ? 'মোট' : 'Total',
                                  style: TfTextStyles.rowTitle,
                                ),
                                TfText(
                                  tfFormatCurrency(
                                    context,
                                    _runningTotal - _computedDiscount,
                                    decimalDigits: 2,
                                  ),
                                  style: TfTextStyles.price.copyWith(
                                    fontFamily: tfFontFamily(context),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TfText(
                              text.isBn ? 'মোট' : 'Total',
                              style: TfTextStyles.rowTitle,
                            ),
                            TfText(
                              tfFormatCurrency(
                                context,
                                _runningTotal,
                                decimalDigits: 2,
                              ),
                              style: TfTextStyles.price.copyWith(
                                fontFamily: tfFontFamily(context),
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
                    child: TourSpot(
                      name: 'orders.editSave',
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
                                      parcel: _itemParcel[e.key] ?? false,
                                    ),
                                  )
                                  .toList(growable: false);
                              final discount = _computedDiscount;
                              final discountLabel = discount > 0
                                  ? (_discountKind == _EditDiscountKind.percent
                                        ? '${_moneyText(_discountValue)}%'
                                        : '৳${_moneyText(_discountValue)}')
                                  : null;
                              final discountChanged =
                                  discount != widget.order.discountAmount ||
                                      discountLabel !=
                                          widget.order.discountLabel;

                              final added = <String>[];
                              final removed = <String>[];
                              final changed = <String>[];
                              for (final entry in _itemQty.entries) {
                                final meta = _metaFor(context, entry.key);
                                final orig = _originalItemQty[entry.key];
                                if (orig == null) {
                                  added.add('${meta.name} (${entry.value})');
                                } else if (orig != entry.value) {
                                  changed.add(
                                    '${meta.name} ($orig\u2192${entry.value})',
                                  );
                                } else if ((_originalItemParcel[entry.key] ??
                                        false) !=
                                    (_itemParcel[entry.key] ?? false)) {
                                  changed.add('${meta.name} (parcel)');
                                }
                              }
                              for (final entry in _originalItemQty.entries) {
                                if (!_itemQty.containsKey(entry.key)) {
                                  final meta = _metaFor(context, entry.key);
                                  removed.add('${meta.name} (${entry.value})');
                                }
                              }

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
                                  discountLabel: discountLabel,
                                  discountAmount: discount,
                                  discountChanged: discountChanged,
                                  addedItems: added.isEmpty ? null : added,
                                  removedItems: removed.isEmpty
                                      ? null
                                      : removed,
                                  changedItems: changed.isEmpty
                                      ? null
                                      : changed,
                                ),
                              );
                            },
                      ),
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
// Discount kind dropdown (inline suffix of the edit-order discount field)
// ─────────────────────────────────────────────────────────────────────────────

class _DiscountKindMenu extends StatelessWidget {
  const _DiscountKindMenu({required this.kind, required this.onSelected});

  final _EditDiscountKind kind;
  final ValueChanged<_EditDiscountKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isPercent = kind == _EditDiscountKind.percent;
    return PopupMenuButton<_EditDiscountKind>(
      tooltip: text.isBn ? 'ছাড়ের ধরন' : 'Discount type',
      onSelected: onSelected,
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _EditDiscountKind.flat,
          child: TfText(text.isBn ? '৳ ফ্ল্যাট (টাকা)' : '৳ Flat (BDT)'),
        ),
        PopupMenuItem(
          value: _EditDiscountKind.percent,
          child: TfText(text.isBn ? '% শতাংশ' : '% Percent off'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TfText(
              isPercent ? '%' : '৳',
              style: TfTextStyles.label.copyWith(
                fontFamily: tfFontFamily(context),
                color: PosColors.primary,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down_rounded,
              color: PosColors.primary,
            ),
          ],
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
                        style: TfTextStyles.appBarTitle.copyWith(
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
                              style: TfTextStyles.bodyMuted,
                            ),
                      trailing: TfText(
                        tfFormatCurrency(context, item.price, decimalDigits: 2),
                        style: TfTextStyles.rowMoney,
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
                  Expanded(
                    child: TfText(
                      'Receipt',
                      style: TfTextStyles.appBarTitle.copyWith(
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
                        borderRadius: BorderRadius.circular(PosRadii.pill),
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
                            style: TfTextStyles.label.copyWith(
                              color: PosColors.success,
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
                          style: TfTextStyles.bodyMuted.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Big order # focus.
                        TfText(
                          order.displaySequence,
                          style: TfTextStyles.heroSerial.copyWith(
                            color: PosColors.slate,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if ((order.tableNo ?? '').isNotEmpty)
                          TfText(
                            'Table ${order.tableNo}',
                            style: TfTextStyles.bodyMuted.copyWith(
                              fontWeight: FontWeight.w500,
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
                          style: TfTextStyles.label.copyWith(
                            fontWeight: FontWeight.w500,
                            color: PosColors.muted,
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
                          style: TfTextStyles.eyebrow.copyWith(
                            color: PosColors.muted,
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
                                    style: TfTextStyles.rowMoney.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: PosColors.muted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TfText(
                                    item.localizedName(
                                      AppScope.of(context).language,
                                    ),
                                    style: TfTextStyles.body.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: PosColors.slate,
                                    ),
                                  ),
                                ),
                                TfText(
                                  tfFormatCurrency(context, item.lineTotal),
                                  style: TfTextStyles.rowMoney.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: PosColors.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Divider(color: PosColors.line, height: 22),
                        if (order.discountAmount > 0) ...[
                          Row(
                            children: [
                              TfText(
                                'DISCOUNT',
                                style: TfTextStyles.eyebrow.copyWith(
                                  color: PosColors.slate,
                                ),
                              ),
                              const Spacer(),
                              TfText(
                                '−${tfFormatCurrency(context, order.discountAmount)}',
                                style: TfTextStyles.rowMoney.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: PosColors.slate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            TfText(
                              'TOTAL',
                              style: TfTextStyles.eyebrow.copyWith(
                                color: PosColors.slate,
                              ),
                            ),
                            const Spacer(),
                            TfText(
                              tfFormatCurrency(
                                context,
                                order.totalAfterDiscount,
                              ),
                              style: TfTextStyles.statNumber.copyWith(
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
    this.discountAmount = 0,
    this.discountLabel,
  });

  final List<OrderRequestItem> items;
  final OrderServiceType serviceType;
  final String? tableNo;
  final String? note;
  final String? customerName;
  final String? mobileNumber;
  final String? deliveryAddress;
  final double discountAmount;
  final String? discountLabel;
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
    this.startWithCodeMode = false,
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
  final bool startWithCodeMode;

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
  late bool _codeMode;
  OrderModel? _createdOrder;
  bool _creating = false;
  Timer? _closeTimer;

  @override
  void initState() {
    super.initState();
    _codeMode = widget.startWithCodeMode;
    debugPrint('[QB-WIZARD] initState: menuItems=${widget.menuItems.length} cats=${widget.menuItems.map((i) => i.category).toSet()}');
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
    _closeTimer?.cancel();
    _pageCtrl.dispose();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    _discountCtrl.dispose();
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    _custAddrCtrl.dispose();
    super.dispose();
  }

  void _goToStep(int index) {
    _closeTimer?.cancel();
    if (index < 0 || index >= _totalSteps) return;
    setState(() => _step = index);
    _pageCtrl.jumpToPage(index);
    if (index == 3) {
      _closeTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context, 'done');
      });
    }
  }

  void _onNewOrder() {
    _closeTimer?.cancel();
    Navigator.pop(context, 'newOrder');
  }

  void _selectTableAndAdvance(String table) {
    setState(() => _selectedTable = table);
    _goToStep(1);
  }

  void _selectSource(OrderServiceType src) {
    if (src == OrderServiceType.delivery) {
      // Delivery is form-first: the bottom sheet collects recipient details
      // and only a confirmed sheet advances (spec §4.3).
      unawaited(_pickDeliveryDetails());
      return;
    }
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

  /// Opens the delivery-details sheet; on confirm stores the details and
  /// switches the order to delivery. [advance] moves on to add-items (used
  /// from the source step; the review step stays put).
  Future<void> _pickDeliveryDetails({bool advance = true}) async {
    final details = await showDeliveryDetailsSheet(
      context,
      initialName: _custNameCtrl.text,
      initialPhone: _custPhoneCtrl.text,
      initialAddress: _custAddrCtrl.text,
    );
    if (!mounted || details == null) return;
    setState(() {
      _custNameCtrl.text = details.name;
      _custPhoneCtrl.text = details.phone;
      _custAddrCtrl.text = details.address;
      _source = OrderServiceType.delivery;
      _selectedTable = '';
    });
    if (advance && _step == 0) _goToStep(1);
  }

  /// Review-step service change (counter-only outlets, spec item 12).
  void _changeServiceFromReview(OrderServiceType src) {
    if (src == OrderServiceType.delivery) {
      unawaited(_pickDeliveryDetails(advance: false));
      return;
    }
    setState(() {
      _source = src;
      _selectedTable = '';
    });
  }

  // ── Menu memo ──────────────────────────────────────────────────────────
  // The menu only changes when the controller replaces the list wholesale
  // (same identity signal the AppModel uses), so the grid popularity/category
  // sort, the category list, and the per-item lowercased search blob are
  // computed once per menu identity instead of on every build/keystroke.
  List<MenuItem>? _menuMemoKey;
  Map<String, int>? _popularityMemoKey;
  List<MenuItem> _sortedMenu = const [];
  List<String> _categoriesMemo = const ['All'];
  Map<String, ({String en, String bn})> _categoryLabelsMemo = const {};
  Map<String, String> _searchBlobs = const {};

  void _ensureMenuMemo() {
    if (identical(_menuMemoKey, widget.menuItems) &&
        identical(_popularityMemoKey, widget.itemPopularity)) {
      return;
    }
    _menuMemoKey = widget.menuItems;
    _popularityMemoKey = widget.itemPopularity;
    // Grid order: favourites first, then the 10 most popular items (by
    // all-time score), then everything else grouped by category (alphabetical,
    // popularity within each category). Filtering below preserves this order,
    // so we never re-sort per keystroke.
    final popularitySorted = [...widget.menuItems]
      ..sort((a, b) {
        final byPop =
            (widget.itemPopularity[b.id] ?? 0)
                .compareTo(widget.itemPopularity[a.id] ?? 0);
        if (byPop != 0) return byPop;
        return a.name.compareTo(b.name);
      });
    final nonFavorites = popularitySorted
        .where((i) => !i.isFavorite)
        .toList(growable: false);
    final top10 = nonFavorites.take(10).map((i) => i.id).toSet();
    final rest = [...nonFavorites]
      ..sort((a, b) {
        final byCategory = a.category.compareTo(b.category);
        if (byCategory != 0) return byCategory;
        final aPop = widget.itemPopularity[a.id] ?? 0;
        final bPop = widget.itemPopularity[b.id] ?? 0;
        if (aPop != bPop) return bPop.compareTo(aPop);
        return a.name.compareTo(b.name);
      });
    _sortedMenu = [
      ...popularitySorted.where((i) => i.isFavorite),
      ...popularitySorted.where((i) => top10.contains(i.id)),
      ...rest.where((i) => !top10.contains(i.id)),
    ];
    final cats = widget.menuItems.map((i) => i.category).toSet().toList()
      ..sort((a, b) => a.compareTo(b));
    _categoriesMemo = ['All', ...cats];
    _categoryLabelsMemo = categoryLabelsFor(widget.menuItems);
    // A stale category selection (menu edited/synced since) would filter
    // EVERYTHING out and leave an inexplicably empty grid — fall back to All.
    if (_selectedCategory != '' &&
        !_categoriesMemo.contains(_selectedCategory)) {
      _selectedCategory = 'All';
    }
    _searchBlobs = {
      for (final i in widget.menuItems)
        i.id: [
          i.name,
          i.nameEn,
          i.nameBn,
          i.category,
          i.description,
        ].whereType<String>().join(' ').toLowerCase(),
    };
    debugPrint('[QB-WIZARD] memo: categories=$_categoriesMemo sortedMenu=${_sortedMenu.length} selectedCategory=$_selectedCategory');
  }

  List<String> get _categories {
    _ensureMenuMemo();
    return _categoriesMemo;
  }

  List<MenuItem> get _visibleItems {
    _ensureMenuMemo();
    final rawQuery = _query.trim();
    final lowerQuery = rawQuery.toLowerCase();
    final selectedCategory = _selectedCategory;
    final codeMode = _codeMode;
    final result = _sortedMenu
        .where((i) {
          if (selectedCategory != '' && selectedCategory != 'All' && i.category != selectedCategory) {
            return false;
          }
          if (rawQuery.isEmpty) return true;
          if (codeMode) {
            // Code mode: match the short code by prefix.
            return (i.shortCode?.toString() ?? '').startsWith(rawQuery);
          }
          return (_searchBlobs[i.id] ?? '').contains(lowerQuery);
        })
        .toList(growable: false);
    debugPrint('[QB-WIZARD] _visibleItems: cat=$selectedCategory query=\'$rawQuery\' code=$codeMode count=${result.length}');
    if (result.isNotEmpty && result.length <= 5) {
      debugPrint('[QB-WIZARD] _visibleItems sample: ${result.map((i) => "${i.id}:${i.name}:cat=${i.category}").join(" | ")}');
    }
    return result;
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
      (double.tryParse(_discountCtrl.text.replaceAll(',', '')) ?? 0.0).clamp(
        0.0,
        _subtotal,
      );

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

  void _toggleCodeMode() {
    setState(() {
      _codeMode = !_codeMode;
      _query = '';
      _searchCtrl.clear();
    });
  }

  /// Quick-pick by short code: add the exact match, then clear for the next.
  void _onCodeSubmit(String raw) {
    final code = int.tryParse(raw.trim());
    if (code == null) return;
    MenuItem? match;
    for (final item in widget.menuItems) {
      if (item.shortCode == code && item.isAvailable) {
        match = item;
        break;
      }
    }
    if (match == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(AppScope.of(context).strings.noItemForCode(raw)),
        ),
      );
      return;
    }
    unawaited(_tap(match));
    setState(() => _query = '');
    _searchCtrl.clear();
  }

  Future<void> _toggleFavorite(MenuItem item) async {
    HapticFeedback.selectionClick();
    await AppScope.of(context).setMenuItemFavorite(item.id, !item.isFavorite);
  }

  static const String _kClearShortCode = '__clear__';

  Future<void> _setShortCode(MenuItem item) async {
    final scope = AppScope.of(context);
    final text = scope.strings;
    final controller = TextEditingController(
      text: item.shortCode?.toString() ?? '',
    );
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: TfText(text.setShortCode),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: text.shortCodeFieldHint),
          onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, _kClearShortCode),
            child: TfText(text.clearShortCode),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: TfText(text.cancel),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: TfText(text.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return; // dismissed
    // Clearing (explicit button or an empty value) removes the code.
    final code = result == _kClearShortCode ? null : int.tryParse(result);
    if (result != _kClearShortCode && result.isNotEmpty && code == null) {
      return; // non-numeric input — ignore
    }
    await scope.setMenuItemShortCode(item.id, code);
  }

  Map<String, int> get _categoryCounts {
    final counts = <String, int>{};
    for (final item in widget.menuItems) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
    }
    counts['All'] = widget.menuItems.length;
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
          discountAmount: _discount,
          discountLabel: _discount > 0
              ? (AppScope.of(context).strings.isBn
                    ? 'ম্যানুয়াল ডিসকাউন্ট'
                    : 'Manual discount')
              : null,
        ),
      );
      if (!mounted) return;
      setState(() {
        _createdOrder = order;
        _creating = false;
      });
      _goToStep(3);
      unawaited(AppScope.of(context).playWizardSuccessSound());
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

  String get _tableLabel {
    if (_source == OrderServiceType.takeaway) return 'Parcel';
    if (_source == OrderServiceType.delivery) return 'Delivery';
    if (_selectedTable == null) return '';
    // Counter-only outlets take dine-in orders without a table map.
    if (_selectedTable!.isEmpty) return 'Dine-in';
    return 'Table $_selectedTable';
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = _step == 3;
    final skipsSourceStep =
        widget.startAtMenu && widget.initialServiceType != null;
    final firstReachableStep = widget.counterMode || skipsSourceStep ? 1 : 0;
    final displayStep = skipsSourceStep ? _step - 1 : _step;
    final cartQtyByItemId = _cartQtyByItemId;
    final text = AppScope.of(context).strings;
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // The Add-items screen (1) renders its own Petpooja-style top bar
            // inside MenuStep; the plain header shows on the other screens.
            if (_step != 1)
              _WizardHeader(
                step: displayStep,
                tableLabel: _tableLabel,
                onClose: () => Navigator.pop(context),
                onBack: _step > firstReachableStep && !isSuccess
                    ? () => _goToStep(_step - 1)
                    : null,
                counterMode: widget.counterMode,
                skipsSourceStep: skipsSourceStep,
                color: (_step == 0 || _step == 2) ? PosColors.primary : null,
              ),
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
                  ),
                  MenuStep(
                    visibleItems: _visibleItems,
                    categories: _categories,
                    categoryLabels: _categoryLabelsMemo,
                    selectedCategory: _selectedCategory,
                    cart: cartQtyByItemId,
                    lineCount: _cartLines.length,
                    total: _total,
                    totalQty: _totalQty,
                    searchCtrl: _searchCtrl,
                    query: _query,
                    codeMode: _codeMode,
                    quickBillMode: _codeMode,
                    categoryCounts: _categoryCounts,
                    title: _tableLabel.isEmpty
                        ? (text.isBn ? 'মেনু' : 'Menu')
                        : _tableLabel,
                    onBack: _step > firstReachableStep
                        ? () => _goToStep(_step - 1)
                        : () => Navigator.pop(context),
                    leadingIsClose: _step <= firstReachableStep,
                    onSearchChanged: (value) => setState(() => _query = value),
                    onToggleCodeMode: _toggleCodeMode,
                    onToggleQuickBill: _toggleCodeMode,
                    onCodeSubmit: _onCodeSubmit,
                    onCategorySelected: (c) =>
                        setState(() => _selectedCategory = c),
                    onTap: (item) => unawaited(_tap(item)),
                    onDecrement: _decrement,
                    onToggleFavorite: (item) =>
                        unawaited(_toggleFavorite(item)),
                    onSetShortCode: (item) => unawaited(_setShortCode(item)),
                    onSubmit: _goToReview,
                    onResetFilters: () => setState(() {
                      _selectedCategory = 'All';
                      _query = '';
                      _searchCtrl.clear();
                    }),
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
                    // Counter-only outlets pick the service type here (the
                    // source/table step is skipped when there are no tables).
                    serviceType: widget.counterMode ? _source : null,
                    onServiceChanged: widget.counterMode
                        ? _changeServiceFromReview
                        : null,
                  ),
                  _OrderCreatedStep(
                    order: _createdOrder,
                    serviceLabel: _tableLabel,
                    total: _total,
                    onNewOrder: _onNewOrder,
                    onDone: () => Navigator.pop(context, 'done'),
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

// Plain header for the create-order flow — back/close + screen title + context
// chip. Petpooja's flow is continuous; no "Step N of N" chrome, no progress bar
// (DESIGN.md Part 0.4).
class _WizardHeader extends StatelessWidget {
  const _WizardHeader({
    required this.step,
    required this.tableLabel,
    required this.onClose,
    required this.onBack,
    this.counterMode = false,
    this.skipsSourceStep = false,
    this.color,
  });

  final int step;
  final String tableLabel;
  final VoidCallback onClose;
  final VoidCallback? onBack;
  final bool counterMode;
  final bool skipsSourceStep;
  final Color? color;

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
    final isBlue = color != null;

    return Container(
      color: color,
      padding: const EdgeInsets.fromLTRB(PosSpacing.sp4, PosSpacing.sp2, PosSpacing.sp4, PosSpacing.sp2),
      child: Row(
        children: [
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  TfNavIcon.back,
                  size: 24,
                  color: isBlue ? PosColors.accentInk : PosColors.slate,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ] else ...[
            GestureDetector(
              onTap: onClose,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  TfNavIcon.close,
                  size: 24,
                  color: isBlue ? PosColors.accentInk : PosColors.slate,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TfText(
              stepLabel,
              style: TfTextStyles.pushedTitle.copyWith(
                color: isBlue ? PosColors.accentInk : PosColors.slate,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (counterMode) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: isBlue
                    ? PosColors.accentInk.withValues(alpha: 0.15)
                    : PosColors.surfaceSunk,
                borderRadius: BorderRadius.circular(PosRadii.chip),
                border: Border.all(
                  color: isBlue
                      ? PosColors.accentInk.withValues(alpha: 0.3)
                      : PosColors.line,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isBlue
                          ? PosColors.accentInk
                          : PosColors.primaryDark,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'COUNTER',
                    style: TfTextStyles.label.copyWith(
                      color: isBlue
                          ? PosColors.accentInk
                          : PosColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (tableLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            TfText(
              tableLabel,
              style: TfTextStyles.label.copyWith(
                color: isBlue ? PosColors.accentInk : PosColors.muted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
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
  });

  final OrderServiceType? source;
  final ValueChanged<OrderServiceType> onSelectSource;
  final int tableCount;
  final String? selectedTable;
  final List<OrderModel> dineInOpenOrders;
  final ValueChanged<String> onSelectTable;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isDineIn = source == OrderServiceType.dineIn;

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
            padding: const EdgeInsets.fromLTRB(PosSpacing.sp4, PosSpacing.sp3, PosSpacing.sp4, PosSpacing.sp6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TourSpot(
                  name: 'orders.newOrderSource',
                  child: Row(
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
                ),
                // Delivery details are collected by the bottom sheet opened
                // from the Delivery tile (delivery_details_sheet.dart).
                if (isDineIn) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TfText(
                          text.pickATable,
                          style: TfTextStyles.rowTitle.copyWith(
                            fontWeight: FontWeight.w500,
                            color: PosColors.slate,
                          ),
                        ),
                      ),
                      TfText(
                        '${tfFormatNumber(context, tableCount)} ${text.isBn ? "টেবিল" : "tables"}'
                        ' · ${tfFormatNumber(context, tableCount - occupiedCount)} ${text.isBn ? "খালি" : "free"}',
                        style: TfTextStyles.bodyMuted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Same tile + grid anatomy as the Tables page (PosTableCell).
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: PosDensity.gridGap,
                          crossAxisSpacing: PosDensity.gridGap,
                          childAspectRatio: PosDensity.tileTableAspect,
                        ),
                    itemCount: tableCount,
                    itemBuilder: (_, i) {
                      final label = 'T${i + 1}';
                      final order = byTable[label];
                      final sel = selectedTable == '${i + 1}';
                      return PosTableCell(
                        label: label,
                        order: order,
                        selected: sel,
                        showOverflow: false,
                        // Occupied tables aren't selectable for a new order —
                        // running orders are edited from the Tables page.
                        onTap: order != null && !sel
                            ? null
                            : () => onSelectTable('${i + 1}'),
                      );
                    },
                  ),
                ],
              ],
            ),
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
          padding: const EdgeInsets.symmetric(vertical: PosDensity.cardPad, horizontal: PosSpacing.sp3),
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
                style: TfTextStyles.sectionHeader.copyWith(
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
    this.serviceType,
    this.onServiceChanged,
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

  /// Counter-only outlets (no table map): the service type is chosen right
  /// here on review. Delivery re-opens the details sheet via the host.
  final OrderServiceType? serviceType;
  final ValueChanged<OrderServiceType>? onServiceChanged;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            children: [
              if (onServiceChanged != null) ...[
                TfPeriodSelector(
                  options: [
                    (
                      OrderServiceType.dineIn.value,
                      OrderServiceType.dineIn.localized(text.isBn),
                    ),
                    (
                      OrderServiceType.takeaway.value,
                      OrderServiceType.takeaway.localized(text.isBn),
                    ),
                    (
                      OrderServiceType.delivery.value,
                      OrderServiceType.delivery.localized(text.isBn),
                    ),
                  ],
                  value: (serviceType ?? OrderServiceType.takeaway).value,
                  onChanged: (value) {
                    final parsed = OrderServiceType.tryParse(value);
                    if (parsed != null) onServiceChanged!(parsed);
                  },
                ),
                const SizedBox(height: 10),
              ],
              // Quiet source + item-count line (no card chrome).
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TfText(
                        sourceLabel,
                        style: TfTextStyles.cardTitle.copyWith(
                          color: PosColors.slate,
                        ),
                      ),
                    ),
                    TfText(
                      text.isBn
                          ? '${tfFormatNumber(context, totalQty)} আইটেম'
                          : '${tfFormatNumber(context, totalQty)} items',
                      style: TfTextStyles.bodyMuted,
                    ),
                  ],
                ),
              ),
              TfCard(
                padded: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...lines.map((line) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: TfText(
                                '${tfFormatNumber(context, line.qty)}×',
                                style: TfTextStyles.rowTitle.copyWith(
                                  fontFamily: tfFontFamily(context),
                                  color: PosColors.slate,
                                ),
                              ),
                            ),
                            Expanded(
                              child: TfText(
                                line.localizedDisplayName(app.language),
                                style: TfTextStyles.body.copyWith(
                                  color: PosColors.slate,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TfText(
                              tfFormatCurrency(context, line.lineTotal),
                              style: TfTextStyles.rowTitle.copyWith(
                                fontFamily: tfFontFamily(context),
                                color: PosColors.slate,
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
            ],
          ),
        ),
        // Bottom action buttons: kitchen note + discount
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: const BoxDecoration(
            color: PosColors.surface,
            border: Border(
              top: BorderSide(color: PosColors.line),
            ),
            boxShadow: PosShadows.bar,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TourSpot(
                    name: 'orders.newOrderKitchenNote',
                    child: TfButton(
                      label: noteCtrl.text.isEmpty
                          ? text.kitchenNote
                          : noteCtrl.text,
                      icon: Icons.notes_outlined,
                      variant: TfButtonVariant.ghost,
                      size: TfButtonSize.sm,
                      fullWidth: true,
                      onPressed: () => _showKitchenNoteSheet(context, noteCtrl),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TourSpot(
                    name: 'orders.newOrderDiscount',
                    child: TfButton(
                      label: discount > 0.005
                          ? '-${tfFormatCurrency(context, discount)}'
                          : (text.isBn ? 'ডিসকাউন্ট' : 'Discount'),
                      icon: Icons.local_offer_outlined,
                      variant: TfButtonVariant.ghost,
                      size: TfButtonSize.sm,
                      fullWidth: true,
                      onPressed: () => _showDiscountSheet(
                        context,
                        discountCtrl,
                        onDiscountChanged,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        TfStickyCTA(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hasDiscount = discount > 0.005;
              final action = TourSpot(
                name: 'orders.newOrderSubmit',
                child: TfButton(
                  label: creating ? '...' : text.sendToKitchen,
                  size: TfButtonSize.lg,
                  onPressed: creating ? null : () => onCreate(),
                ),
              );
              final summaryCol = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasDiscount) ...[
                    TfText(
                      '${text.isBn ? 'সাবটোটাল' : 'Subtotal'}: ${tfFormatCurrency(context, subtotal)}',
                      style: TfTextStyles.label.copyWith(
                        fontFamily: tfFontFamily(context),
                        fontWeight: FontWeight.w400,
                        color: PosColors.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    TfText(
                      '${text.isBn ? 'ডিসকাউন্ট' : 'Discount'}: -${tfFormatCurrency(context, discount)}',
                      style: TfTextStyles.label.copyWith(
                        fontFamily: tfFontFamily(context),
                        fontWeight: FontWeight.w400,
                        color: PosColors.danger,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  TfText(
                    '${text.totalLabel}: ${tfFormatCurrency(context, total)}',
                    style: TfTextStyles.rowMoney.copyWith(
                      fontFamily: tfFontFamily(context),
                      color: PosColors.slate,
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

  void _showKitchenNoteSheet(
    BuildContext context,
    TextEditingController controller,
  ) {
    final text = AppScope.of(context).strings;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.5,
            ),
            decoration: const BoxDecoration(
              color: PosColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.xl)),
              boxShadow: PosShadows.raised,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 9, bottom: 12),
                  decoration: BoxDecoration(
                    color: PosColors.lineStrong,
                    borderRadius: BorderRadius.circular(PosRadii.pill),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Row(
                    children: [
                      TfText(
                        text.kitchenNote,
                        style: TfTextStyles.appBarTitle,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: PosColors.surface,
                            border: Border.all(color: PosColors.lineStrong),
                            borderRadius: BorderRadius.circular(PosRadii.md),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: PosColors.ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: TextField(
                      controller: controller,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 4,
                      autofocus: true,
                      style: TfTextStyles.rowTitle.copyWith(
                        fontFamily: tfFontFamily(context),
                        fontWeight: FontWeight.w400,
                        color: PosColors.slate,
                      ),
                      decoration: InputDecoration(
                        hintText: text.kitchenNoteHint,
                        hintStyle: TfTextStyles.body.copyWith(
                          fontFamily: tfFontFamily(context),
                          color: PosColors.muted,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PosRadii.md),
                          borderSide: const BorderSide(color: PosColors.lineStrong),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(PosRadii.md),
                          borderSide: const BorderSide(color: PosColors.primary),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: TfButton(
                    label: text.isBn ? 'সেভ করুন' : 'Save',
                    variant: TfButtonVariant.primary,
                    size: TfButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDiscountSheet(
    BuildContext context,
    TextEditingController controller,
    VoidCallback onChanged,
  ) {
    final text = AppScope.of(context).strings;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: PosColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.xl)),
              boxShadow: PosShadows.raised,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 9, bottom: 12),
                  decoration: BoxDecoration(
                    color: PosColors.lineStrong,
                    borderRadius: BorderRadius.circular(PosRadii.pill),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                  child: Row(
                    children: [
                      TfText(
                        text.isBn ? 'ডিসকাউন্ট (ফ্ল্যাট ৳)' : 'Discount (flat ৳)',
                        style: TfTextStyles.appBarTitle,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: PosColors.surface,
                            border: Border.all(color: PosColors.lineStrong),
                            borderRadius: BorderRadius.circular(PosRadii.md),
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: PosColors.ink2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    autofocus: true,
                    style: TfTextStyles.rowTitle.copyWith(
                      fontFamily: tfFontFamily(context),
                      fontWeight: FontWeight.w400,
                      color: PosColors.slate,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: TfTextStyles.rowTitle.copyWith(
                        fontFamily: tfFontFamily(context),
                        fontWeight: FontWeight.w400,
                        color: PosColors.muted,
                      ),
                      prefixIcon: const Icon(
                        Icons.local_offer_outlined,
                        size: 18,
                        color: PosColors.muted,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PosRadii.md),
                        borderSide: const BorderSide(color: PosColors.lineStrong),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(PosRadii.md),
                        borderSide: const BorderSide(color: PosColors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 12,
                      ),
                    ),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: TfButton(
                    label: text.isBn ? 'সেভ করুন' : 'Save',
                    variant: TfButtonVariant.primary,
                    size: TfButtonSize.lg,
                    fullWidth: true,
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
          style: TfTextStyles.bodyMuted,
        ),
        const Spacer(),
        TfText(
          value,
          style: TfTextStyles.rowTitle.copyWith(color: PosColors.slate),
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
    this.onNewOrder,
    required this.onDone,
  });

  final OrderModel? order;
  final String serviceLabel;
  final double total;
  final VoidCallback? onNewOrder;
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
                    style: TfTextStyles.appBarTitle.copyWith(
                      color: PosColors.slate,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TfText(
                    orderNo,
                    textAlign: TextAlign.center,
                    style: TfTextStyles.heroSerial.copyWith(
                      fontFamily: tfFontFamily(context),
                      color: PosColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TfText(
                    '$source · ${tfFormatCurrency(context, order?.total ?? total)}',
                    style: TfTextStyles.rowTitle.copyWith(
                      fontFamily: tfFontFamily(context),
                      fontWeight: FontWeight.w400,
                      color: PosColors.muted,
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
                  key: const ValueKey('created-order-home'),
                  label: 'Home',
                  labelBn: 'হোম',
                  icon: Icons.home_outlined,
                  variant: TfButtonVariant.paper,
                  size: TfButtonSize.lg,
                  onPressed: onDone,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TfButton(
                  key: const ValueKey('created-order-new'),
                  label: 'New order',
                  labelBn: 'নতুন অর্ডার',
                  icon: Icons.add_rounded,
                  variant: TfButtonVariant.dark,
                  size: TfButtonSize.lg,
                  onPressed: onNewOrder,
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
                        style: TfTextStyles.rowTitle.copyWith(
                          fontFamily: tfFontFamily(context),
                          color: PosColors.slate,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TfText(
                        item.localizedName(app.language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TfTextStyles.body.copyWith(
                          color: PosColors.slate,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TfText(
                      tfFormatCurrency(context, item.lineTotal),
                      style: TfTextStyles.rowTitle.copyWith(
                        fontWeight: FontWeight.w500,
                        color: PosColors.slate,
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

// ─────────────────────────────────────────────────────────────────────────────
// Settle & Save (DESIGN.md §5 — Petpooja settlement modal, blue).
// Collects the payment mode + customer-paid amount and shows the computed
// return before the order is completed + printed. Returns the chosen
// [OrderPaymentMethod], or null when cancelled. Note: the mobile admin flow
// has no API yet to persist the mode on an existing order — the modal is the
// operator-facing settle surface; persistence is a follow-up data change.
// ─────────────────────────────────────────────────────────────────────────────

Future<OrderPaymentMethod?> showSettleAndSaveDialog(
  BuildContext context, {
  required OrderModel order,
}) {
  return showDialog<OrderPaymentMethod>(
    context: context,
    builder: (_) => _SettleSaveDialog(order: order),
  );
}

class _SettleSaveDialog extends StatefulWidget {
  const _SettleSaveDialog({required this.order});

  final OrderModel order;

  @override
  State<_SettleSaveDialog> createState() => _SettleSaveDialogState();
}

class _SettleSaveDialogState extends State<_SettleSaveDialog> {
  OrderPaymentMethod _method = OrderPaymentMethod.cash;
  final TextEditingController _paidCtrl = TextEditingController();

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  double get _paid => double.tryParse(_paidCtrl.text.trim()) ?? 0;

  double get _returnAmount {
    final change = _paid - widget.order.totalAfterDiscount;
    return change > 0 ? change : 0;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isBn = text.isBn;
    return Dialog(
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.xl),
        side: const BorderSide(color: PosColors.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(PosSpacing.sp4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: TfText(
                isBn ? 'সেটেল ও সেভ' : 'Settle & Save',
                style: TfTextStyles.appBarTitle.copyWith(
                  color: PosColors.slate,
                ),
              ),
            ),
            const SizedBox(height: PosDensity.sectionGap),
            // Payment-mode radio cards, two per row (Petpooja target).
            GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: PosDensity.gridGap,
                crossAxisSpacing: PosDensity.gridGap,
                childAspectRatio: 3.1,
                children: [
                  for (final method in OrderPaymentMethod.values)
                    if (method != OrderPaymentMethod.split)
                      _ModeTile(
                        method: method,
                        selected: method == _method,
                        isBn: isBn,
                        onTap: () => setState(() => _method = method),
                      ),
                ],
              ),
            const SizedBox(height: PosDensity.sectionGap),
            TextField(
              controller: _paidCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: isBn ? 'কাস্টমার দিয়েছে' : 'Customer Paid',
              ),
            ),
            const SizedBox(height: PosDensity.sectionGap),
            Row(
              children: [
                Expanded(
                  child: TfText(
                    isBn ? 'কাস্টমারকে ফেরত' : 'Return to Customer',
                    style: TfTextStyles.body.copyWith(color: PosColors.ink2),
                  ),
                ),
                TfText(
                  tfFormatCurrency(context, _returnAmount),
                  style: TfTextStyles.rowTitle.copyWith(color: PosColors.slate),
                ),
              ],
            ),
            const SizedBox(height: PosSpacing.sp2),
            Row(
              children: [
                Expanded(
                  child: TfText(
                    isBn ? 'সেটেলমেন্ট পরিমাণ' : 'Settlement Amount',
                    style: TfTextStyles.body.copyWith(color: PosColors.ink2),
                  ),
                ),
                TfText(
                  tfFormatCurrency(context, widget.order.totalAfterDiscount),
                  style: TfTextStyles.rowTitle.copyWith(
                    fontWeight: FontWeight.w800,
                    color: PosColors.slate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: PosSpacing.sp4),
            Row(
              children: [
                Expanded(
                  child: TfButton(
                    label: isBn ? 'বাতিল' : 'Cancel',
                    variant: TfButtonVariant.ghost,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: PosDensity.gridGap),
                Expanded(
                  child: TfButton(
                    label: isBn ? 'সেটেল ও সেভ' : 'Settle & Save',
                    onPressed: () => Navigator.pop(context, _method),
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

// Outlined payment-mode card with a circular radio indicator.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.method,
    required this.selected,
    required this.isBn,
    required this.onTap,
  });

  final OrderPaymentMethod method;
  final bool selected;
  final bool isBn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PosRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: PosSpacing.sp3),
        decoration: BoxDecoration(
          color: selected ? PosColors.primarySoft : PosColors.surface,
          border: Border.all(
            color: selected ? PosColors.primary : PosColors.lineStrong,
          ),
          borderRadius: BorderRadius.circular(PosRadii.md),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? PosColors.primary : PosColors.lineStrong,
                  width: 2,
                ),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: PosColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: PosSpacing.sp2),
            Expanded(
              child: TfText(
                isBn
                    ? (method == OrderPaymentMethod.cash
                        ? 'ক্যাশ'
                        : method.banglaLabel)
                    : method.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TfTextStyles.rowTitle.copyWith(
                  color: selected
                      ? PosColors.accentStrong
                      : PosColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
