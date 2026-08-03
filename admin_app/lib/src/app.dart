import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'app_scope.dart';
import 'core/localization/app_strings.dart';
import 'core/platform/desktop_platform.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/notification_center.dart';
import 'core/widgets/screen_blocker.dart';
import 'core/widgets/shell_nav_scope.dart';
import 'core/widgets/tf_design_system.dart';
import 'models/app_update_info.dart';
import 'models/pos_notification.dart';
import 'models/account_role.dart';
import 'services/cloud_api_service.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/desktop_pos/desktop_pos_shell.dart';
import 'features/inventory/end_of_day_count_screen.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/inventory/stock_in_screen.dart';
import 'features/inventory/stock_scan_flow.dart';
import 'features/menu/menu_management_screen.dart';
import 'features/menu/menu_scan_screen.dart';
import 'features/more/more_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/reports/reports_hub_screen.dart';
import 'features/auth/staff_invite_screen.dart';
import 'features/setup/tenant_setup_screen.dart';
import 'features/splash/mode_intro_screen.dart';
import 'features/system/admin_blocking_notice_screen.dart';
import 'features/tables/tables_screen.dart';
import 'features/tower/control_tower_screen.dart';

class LocalPosApp extends StatefulWidget {
  const LocalPosApp({super.key});

  @override
  State<LocalPosApp> createState() => _LocalPosAppState();
}

class _LocalPosAppState extends State<LocalPosApp> with WidgetsBindingObserver {
  late final PosAppController _controller;
  bool _bootDone = false;
  bool _showIntro = false;
  int _initialShellIndex = 0;
  bool _refreshingOffline = false;
  StreamSubscription<bool>? _offlineConnectivitySub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = PosAppController();
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _bootDone = true;
          _showIntro = !_controller.hasSeenIntro;
          _initialShellIndex = _defaultShellIndex();
        });
      }
    });
    _offlineConnectivitySub =
        _controller.connectivityService.onlineStream.listen((online) {
      if (online && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _offlineConnectivitySub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _controller.onResumed();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      // `inactive` is transient (system dialogs / app switcher transitions)
      // so we don't flip the foreground flag for it — otherwise a brief
      // system overlay would cause every new notification to also fire an OS
      // alert while the user is still effectively in the app.
      _controller.onPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final text = _controller.strings;
          final tone = _resolveTone(_controller.themePreference);
          PosColors.setTone(tone);
          return AppModel(
            controller: _controller,
            child: MaterialApp(
              title: text.appTitle,
              debugShowCheckedModeBanner: false,
              locale: _controller.language.locale,
              supportedLocales: AppLanguage.values
                  .map((language) => language.locale)
                  .toList(growable: false),
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: AppTheme.light(),
              themeMode: ThemeMode.light,
              builder: (context, child) {
                final mediaQuery = MediaQuery.of(context);
                return MediaQuery(
                  data: mediaQuery.copyWith(
                    textScaler: mediaQuery.textScaler.clamp(
                      minScaleFactor: 1.0,
                      maxScaleFactor: 1.18,
                    ),
                  ),
                  child: child ?? SizedBox.shrink(),
                );
              },
              home: _home(),
            ),
          );
        },
      ),
    );
  }

  PosThemeTone _resolveTone(AppThemePreference _) {
    return PosThemeTone.light;
  }

  void _onIntroFinished(String? nextStep) {
    setState(() {
      _showIntro = false;
      _initialShellIndex = _defaultShellIndex();
    });
  }

  Widget _home() {
    if (!_bootDone) return const SizedBox.shrink();
    final blockingNotice = _controller.adminBlockingNotice;
    if (blockingNotice?.isBlocking == true) {
      return AdminBlockingNoticeScreen(
        key: const ValueKey('admin-blocking-notice-screen'),
        notice: blockingNotice!,
        refreshing: _controller.adminBlockingNoticeRefreshing,
        error: _controller.adminBlockingNoticeError,
        onRetry: _controller.refreshAdminBlockingNotice,
        onRespond: _controller.respondToBlockingNotice,
        onDismiss: _controller.dismissAdminBlockingNotice,
      );
    }
    if (_controller.isOffline && _controller.isSubscriptionExpiredLocally) {
      debugPrint('[SUB] _home — offline + locally expired, showing offline expiry blocker');
      return _buildOfflineExpiryBlocker();
    }
    if (_controller.pendingStaffInvite != null) {
      return StaffInviteScreen(
        onFinished: () => setState(() => _initialShellIndex = 0),
      );
    }
    if (_showIntro) {
      return ModeIntroScreen(onFinished: _onIntroFinished);
    }
    if (!_controller.isLoggedIn) {
      final signupToken = _controller.phoneSignupToken?.trim() ?? '';
      if (signupToken.isNotEmpty) {
        return TenantSetupScreen(
          onProvisioned: () {
            setState(() => _initialShellIndex = _defaultShellIndex());
          },
        );
      }
      return ModeIntroScreen(onFinished: _onIntroFinished);
    }
    if (!_controller.isTenantReady) {
      return TenantSetupScreen(
        onProvisioned: () {
          setState(() {
            _initialShellIndex = _defaultShellIndex();
          });
        },
      );
    }
    final pending = _controller.pendingOnboardingLanding;
    final ordersIndex = _defaultShellIndex();
    if (pending && _initialShellIndex != ordersIndex) {
      _initialShellIndex = ordersIndex;
    }
    void mounted() {
      if (_controller.pendingOnboardingLanding) {
        _controller.consumeOnboardingLanding();
      }
    }

    if (isNativeDesktop) {
      return DesktopPosShell(onMounted: mounted);
    }
    return MainShell(initialIndex: _initialShellIndex, onMounted: mounted);
  }

  /// Default landing tab: Analytics for owner, Orders for manager/waiter.
  Widget _buildOfflineExpiryBlocker() {
    final text = _controller.strings;
    return ScreenBlocker(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: PosColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(PosRadii.sm),
        ),
        child: const Icon(Icons.wifi_off_rounded, color: PosColors.warning, size: 24),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TfText(
            text.adminBlockingNoticeEyebrow,
            style: const TextStyle(
              color: PosColors.warning,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.77,
            ),
          ),
          const SizedBox(height: PosSpacing.sp3),
          TfText(
            text.offlineExpiryTitle,
            style: const TextStyle(
              color: PosColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: PosSpacing.sp3),
          TfText(
            text.offlineExpiryMessage,
            style: const TextStyle(
              color: PosColors.inkSoft,
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.55,
            ),
          ),
          const SizedBox(height: PosSpacing.sp2),
          TfText(
            text.adminBlockingNoticeHelper,
            style: const TextStyle(
              color: PosColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
        ],
      ),
      actions: [
        ScreenBlockerAction(
          label: text.offlineExpiryCheckConnection,
          icon: Icons.wifi_find_rounded,
          busy: _refreshingOffline,
          onPressed: _refreshingOffline ? null : _retryOfflineExpiry,
        ),
      ],
    );
  }

  Future<void> _retryOfflineExpiry() async {
    debugPrint('[SUB] _retryOfflineExpiry');
    setState(() => _refreshingOffline = true);
    try {
      final hasInternet =
          await _controller.connectivityService.hasInternetAccess();
      debugPrint('[SUB] _retryOfflineExpiry — hasInternet=$hasInternet');
      if (!mounted) return;
      if (hasInternet) {
        await _controller.syncSubscriptionAccessFromCloud(quiet: false);
        debugPrint('[SUB] _retryOfflineExpiry — after sync, subState=${_controller.subscriptionState} isExpired=${_controller.isSubscriptionExpiredLocally}');
        if (mounted) setState(() {});
      }
    } finally {
      if (mounted) setState(() => _refreshingOffline = false);
    }
  }

  int _defaultShellIndex() {
    final tabs = _tabOrderForRole(_controller.accountRole);
    final target = _controller.accountRole.isOwner
        ? _AppTab.analytics
        : _AppTab.orders;
    final i = tabs.indexOf(target);
    return i < 0 ? 0 : i;
  }
}

// QuickBytes role-aware navigation (spec §1). Enum ordinals fix the page-build
// slots; the per-role lists below choose which tabs show and in what order.
enum _AppTab {
  analytics,
  live,
  tables,
  orders,
  stock,
  more,
  menu,
  salesSummary,
  reports,
}

// Owner: Analytics · Orders · Stock · Menu · Reports · More.
// Menu is a first-class destination (matches the DESIGN.md desktop-rail order
// … Stock · Menu · Reports …), not a pushed screen under More. Tables is
// waiter-only — owners/managers work from Orders.
const _ownerTabOrder = <_AppTab>[
  _AppTab.analytics,
  _AppTab.orders,
  _AppTab.stock,
  _AppTab.menu,
  _AppTab.reports,
  _AppTab.more,
];
// Manager: Orders · Menu · Stock · Live (Control Tower) · Sales Summary · More
const _managerTabOrder = <_AppTab>[
  _AppTab.orders,
  _AppTab.menu,
  _AppTab.stock,
  _AppTab.live,
  _AppTab.salesSummary,
  _AppTab.more,
];
// Waiter: Tables · Orders · More
const _waiterTabOrder = <_AppTab>[_AppTab.tables, _AppTab.orders, _AppTab.more];

List<_AppTab> _tabOrderForRole(AccountRole role) {
  if (role.isOwner) return _ownerTabOrder;
  if (role.isWaiter) return _waiterTabOrder;
  return _managerTabOrder;
}

// Maps a nav tab to its label/icon pair. Shared by the bottom-less phone drawer,
// the wide NavigationRail, and (historically) the bottom nav.
// [isBackoffice] renames Orders → Order History.
_Destination _destinationFor(_AppTab tab, AppStrings text, {bool isBackoffice = false}) {
  return switch (tab) {
    _AppTab.analytics => _Destination(
      text.analyticsTab,
      text.analyticsTab,
      Icons.insights_outlined,
      Icons.insights,
    ),
    _AppTab.live => _Destination(
      text.restaurantLive,
      text.restaurantLive,
      Icons.monitor_heart_outlined,
      Icons.monitor_heart_rounded,
    ),
    _AppTab.tables => _Destination(
      text.tables,
      text.tables,
      Icons.table_restaurant_outlined,
      Icons.table_restaurant,
    ),
    _AppTab.orders => _Destination(
      isBackoffice ? text.orderHistory : text.orders,
      isBackoffice ? text.orderHistory : text.orders,
      Icons.receipt_long_outlined,
      Icons.receipt_long,
    ),
    _AppTab.stock => _Destination(
      text.stockTab,
      text.stockTab,
      Icons.grid_on_outlined,
      Icons.grid_on_rounded,
    ),
    _AppTab.menu => _Destination(
      text.menu,
      text.menu,
      Icons.restaurant_menu_outlined,
      Icons.restaurant_menu,
    ),
    _AppTab.salesSummary => _Destination(
      text.salesSummary,
      text.salesSummary,
      Icons.summarize_outlined,
      Icons.summarize_rounded,
    ),
    _AppTab.reports => _Destination(
      text.reports,
      text.reports,
      Icons.assessment_outlined,
      Icons.assessment_rounded,
    ),
    _AppTab.more => _Destination(
      text.settingsTab,
      text.settingsTab,
      Icons.settings_outlined,
      Icons.settings_rounded,
    ),
  };
}

class MainShell extends StatefulWidget {
  const MainShell({required this.initialIndex, this.onMounted, super.key});

  final int initialIndex;
  final VoidCallback? onMounted;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late _AppTab _selected;
  List<_AppTab> _currentTabOrder = _ownerTabOrder;
  String? _lastShownNotificationKey;
  String? _pendingNotificationToastKey;
  Timer? _notificationToastDebounce;
  int? _lastShownAppUpdateVersionCode;
  bool _appUpdateDialogShowing = false;
  int _receiptPrinterOpenRequest = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  OverlayEntry? _scanOverlay;

  void _showScanOverlay(String message) {
    _hideScanOverlay();
    _scanOverlay = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
        right: 8,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          color: PosColors.surface,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: PosColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PosColors.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: PosColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                TfText(
                  message,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_scanOverlay!);
  }

  void _hideScanOverlay() {
    _scanOverlay?.remove();
    _scanOverlay = null;
  }

  Future<void> _navigateOnboardingMenuScan(
    BuildContext context,
    PosAppController app,
  ) async {
    final uploads = await Navigator.of(context).push<List<MenuScanPageUpload>>(
      MaterialPageRoute(builder: (_) => const MenuScanScreen()),
    );
    if (!mounted || uploads == null || uploads.isEmpty) return;
    unawaited(app.scanAndImportMenu(uploads));
  }

  @override
  void initState() {
    super.initState();
    final vi = widget.initialIndex.clamp(0, _ownerTabOrder.length - 1);
    _selected = _ownerTabOrder[vi];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.read(context);
      app.systemNotifications.requestNotificationAccess();
      widget.onMounted?.call();
      // Handle FCM notification that launched the app (killed state).
      final pending = app.pendingFcmNavigation;
      if (pending != null) {
        app.pendingFcmNavigation = null;
        _handleFcmNavigationTap(pending);
      }
      // Onboarding menu scan: provisioned tenant, now navigate to scan screen.
      if (app.pendingOnboardingMenuScan) {
        app.pendingOnboardingMenuScan = false;
        _navigateOnboardingMenuScan(context, app);
      }
    });
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      final vi = widget.initialIndex.clamp(0, _currentTabOrder.length - 1);
      _selected = _currentTabOrder[vi];
    }
  }

  @override
  void dispose() {
    _hideScanOverlay();
    _notificationToastDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The shell only reads these slices; subscribing narrowly keeps printer
    // and sync ticks from rebuilding the whole shell (and the active page).
    final app = AppScope.selectMany(context, const [
      AppAspect.language,
      AppAspect.account,
      AppAspect.notifications,
      AppAspect.appUpdate,
    ]);
    final text = app.strings;
    _currentTabOrder = _tabOrderForRole(app.accountRole);
    if (!_currentTabOrder.contains(_selected)) {
      _selected = _currentTabOrder.first;
    }
    _maybeShowNotification(app);
    _consumeFcmNavigation(app);
    final tabOrder = _currentTabOrder;
    final visualIndex = tabOrder
        .indexOf(_selected)
        .clamp(0, tabOrder.length - 1);
    final backoffice = tabOrder.contains(_AppTab.reports);
    final destinations = tabOrder
        .map((t) => _destinationFor(t, text, isBackoffice: backoffice))
        .toList(growable: false);

    // Fixed page order matching _AppTab.index ordinals. Builders (not eager
    // instances) so unvisited tabs never mount — see [_LazyIndexedStack].
    void goToOrders() => _selectTab(_AppTab.orders);
    // Order MUST match _AppTab ordinals: analytics(0), live(1), tables(2),
    // orders(3), stock(4), more(5), menu(6), salesSummary(7), reports(8).
    final pageBuilders = <WidgetBuilder>[
      (_) => AnalyticsScreen(onNavigateToTarget: _navigateNotificationTarget),
      (_) => ControlTowerScreen(
        onNavigateToOrders: goToOrders,
        onNavigateToTarget: _navigateNotificationTarget,
      ),
      (_) => TablesScreen(
        onNavigateToOrders: goToOrders,
        onNavigateToTarget: _navigateNotificationTarget,
      ),
      (_) => OrdersScreen(onNavigateToTarget: _navigateNotificationTarget),
      (_) => InventoryScreen(
        onNavigateToOrders: goToOrders,
        onNavigateToTarget: _navigateNotificationTarget,
      ),
      (_) => MoreScreen(
        onNavigateToOrders: goToOrders,
        onNavigateToTarget: _navigateNotificationTarget,
        receiptPrinterOpenRequest: _receiptPrinterOpenRequest,
      ),
      (_) => MenuManagementScreen(
        onNavigateToOrders: goToOrders,
        onNavigateToTarget: _navigateNotificationTarget,
      ),
      (_) => AnalyticsScreen(
        reduced: true,
        onNavigateToOrders: goToOrders,
        onNavigateToTarget: _navigateNotificationTarget,
      ),
      (_) => ReportsHubScreen(onNavigateToTarget: _navigateNotificationTarget),
    ];

    // Each page renders the notification bell as one of its own header
    // actions (via HeaderNotificationBell) — no global floating overlay,
    // so it never sits on top of the menu page's "+ New" button etc.
    _maybeShowAppUpdatePrompt(app);
    final body = _LazyIndexedStack(
      index: _selected.index,
      builders: pageBuilders,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final useRail = constraints.maxWidth >= 760;
        if (!useRail) {
          // Phone surface: Petpooja-style left drawer opened by a hamburger in
          // the shared header (the bottom nav has been retired). The drawer
          // lives on this outer Scaffold so it overlays every inner screen
          // Scaffold without per-screen plumbing; [ShellNavScope] lets the
          // shared header reach it.
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: PosColors.background,
            drawer: _AppNavDrawer(
              tabOrder: tabOrder,
              selected: _selected,
              onSelectTab: _selectTab,
              onNavigateTarget: _navigateNotificationTarget,
              onAction: _handleDrawerAction,
            ),
            body: ShellNavScope(
              openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              showScanOverlay: _showScanOverlay,
              hideScanOverlay: _hideScanOverlay,
              child: body,
            ),
          );
        }

        final extended = constraints.maxWidth >= 1050;
        // Wide surface keeps the flat rail for one-tap tab switching; the
        // grouped child entries (Stock in/Count/Scan, Delivery/Discounts,
        // Reports) stay reachable through the same drawer via the hamburger.
        return Scaffold(
          key: _scaffoldKey,
          drawer: _AppNavDrawer(
            tabOrder: tabOrder,
            selected: _selected,
            onSelectTab: _selectTab,
            onNavigateTarget: _navigateNotificationTarget,
            onAction: _handleDrawerAction,
          ),
          body: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: PosColors.surface,
                  border: Border(right: BorderSide(color: PosColors.line)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(2, 0),
                    ),
                  ],
                ),
                child: NavigationRail(
                  selectedIndex: visualIndex,
                  onDestinationSelected: _setIndex,
                  extended: extended,
                  minExtendedWidth: 232,
                  groupAlignment: -0.86,
                  leading: Padding(
                    padding: EdgeInsets.fromLTRB(14, 22, 14, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: _RailLogo(extended: extended),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  trailing: Padding(
                    padding: EdgeInsets.fromLTRB(12, 18, 12, 22),
                    child: _RailFooter(extended: extended),
                  ),
                  destinations: destinations
                      .map((destination) {
                        return NavigationRailDestination(
                          icon: Icon(destination.icon),
                          selectedIcon: Icon(destination.selectedIcon),
                          label: Text(
                            text.isBn ? destination.bnLabel : destination.label,
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ),
              Expanded(
                child: ShellNavScope(
                  openDrawer: () => _scaffoldKey.currentState?.openDrawer(),
                  showScanOverlay: _showScanOverlay,
                  hideScanOverlay: _hideScanOverlay,
                  child: body,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setIndex(int vi) {
    if (vi >= 0 && vi < _currentTabOrder.length) {
      setState(() => _selected = _currentTabOrder[vi]);
    }
  }

  void _selectTab(_AppTab tab) {
    final vi = _currentTabOrder.indexOf(tab);
    if (vi >= 0) _setIndex(vi);
  }

  void _navigateNotificationTarget(PosNotificationTarget target) {
    // Menu & Settings moved out of the bottom nav into the More hub, so their
    // notification deep-links push the screen rather than switching a tab.
    switch (target) {
      case PosNotificationTarget.orders:
        _selectTab(_AppTab.orders);
        return;
      case PosNotificationTarget.inventory:
        _selectTab(_AppTab.stock);
        return;
      case PosNotificationTarget.menu:
        // Menu is a first-class nav destination — deep-link selects the tab
        // rather than pushing a screen (manager+ only).
        if (AppScope.read(context).accountRole.isManager) {
          _selectTab(_AppTab.menu);
        }
        return;
      case PosNotificationTarget.receiptPrinter:
        // Settings (incl. receipt printer) is now embedded in the Settings
        // tab (formerly "More") rather than a pushed page — select the tab
        // and bump the request counter to auto-open the printer sub-page.
        // _selectTab's own setState picks up the incremented value below.
        _receiptPrinterOpenRequest++;
        _selectTab(_AppTab.more);
        return;
      case PosNotificationTarget.settings:
        _selectTab(_AppTab.more);
        return;
      case PosNotificationTarget.none:
        return;
    }
  }

  /// Drawer group-child actions: quick screens/sheets that don't map to a tab.
  void _handleDrawerAction(_DrawerAction action) {
    switch (action) {
      case _DrawerAction.stockScan:
        unawaited(runStockScanFlow(
          context,
          showScanOverlay: _showScanOverlay,
          hideScanOverlay: _hideScanOverlay,
        ));
      case _DrawerAction.stockIn:
        unawaited(_pushThenRefreshInventory(const StockInScreen()));
      case _DrawerAction.stockCount:
        unawaited(_pushThenRefreshInventory(const EndOfDayCountScreen()));
      case _DrawerAction.menuScan:
        _selectTab(_AppTab.menu);
      case _DrawerAction.menuDeliveryCharge:
        unawaited(showMenuDeliveryChargeEditor(context));
      case _DrawerAction.menuDiscounts:
        unawaited(showMenuDiscountsSheet(context));
    }
  }

  Future<void> _pushThenRefreshInventory(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) await AppScope.read(context).refreshInventorySummary();
  }

  void _consumeFcmNavigation(PosAppController app) {
    final data = app.pendingFcmNavigation;
    if (data == null) return;
    app.pendingFcmNavigation = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleFcmNavigationTap(data);
    });
  }

  void _handleFcmNavigationTap(Map<String, String> data) {
    final actionTarget = data['actionTarget'] ?? 'orders';
    if (actionTarget == 'orders' || actionTarget == 'order') {
      _selectTab(_AppTab.orders);
      // Optionally focus the specific order if needed — the orders screen
      // picks up orderId from a shared state if we add it there.
      return;
    }
    final target = PosNotificationTarget.parse(actionTarget);
    _navigateNotificationTarget(target);
  }

  void _maybeShowNotification(PosAppController app) {
    final unread = app.notifications
        .where((notification) => !notification.isRead)
        .toList(growable: false);
    if (unread.isEmpty) return;
    final latest = unread.first;
    final alertKey = unread.length > 1
        ? 'bulk:${unread.length}:${latest.id}'
        : latest.orderId != null
        ? '${latest.orderId}:${latest.type.name}'
        : latest.id;
    if (alertKey == _lastShownNotificationKey ||
        alertKey == _pendingNotificationToastKey) {
      return;
    }

    _pendingNotificationToastKey = alertKey;
    _notificationToastDebounce?.cancel();
    _notificationToastDebounce = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _showPendingNotificationToast();
    });
  }

  void _showPendingNotificationToast() {
    final app = AppScope.read(context);
    final text = app.strings;
    final unread = app.notifications
        .where((notification) => !notification.isRead)
        .toList(growable: false);
    if (unread.isEmpty) {
      _pendingNotificationToastKey = null;
      return;
    }
    final latest = unread.first;
    final singleAlertOnly = unread.length == 1;
    final alertKey = unread.length > 1
        ? 'bulk:${unread.length}:${latest.id}'
        : latest.orderId != null
        ? '${latest.orderId}:${latest.type.name}'
        : latest.id;
    if (alertKey == _lastShownNotificationKey) {
      _pendingNotificationToastKey = null;
      return;
    }

    _lastShownNotificationKey = alertKey;
    _pendingNotificationToastKey = null;
    showTopNotificationToast(
      context,
      title: singleAlertOnly
          ? latest.title
          : text.notificationSummaryTitle(unread.length),
      body: singleAlertOnly
          ? latest.body
          : text.notificationSummaryBody,
      onOpen: () {
        if (unread.length > 1 && !singleAlertOnly) {
          showNotificationCenter(
            context,
            onNavigateToOrders: () => _selectTab(_AppTab.orders),
            onNavigateToTarget: _navigateNotificationTarget,
          );
        } else {
          app.markNotificationRead(latest.id);
          _navigateNotificationTarget(latest.target);
        }
      },
    );
  }

  void _maybeShowAppUpdatePrompt(PosAppController app) {
    final update = app.pendingAppUpdate;
    if (update == null || app.appUpdateBusy) return;
    if (app.appUpdatePhase != AppUpdatePhase.ready) return;
    if (_appUpdateDialogShowing) return;
    if (!update.required &&
        _lastShownAppUpdateVersionCode == update.versionCode) {
      return;
    }
    if (!update.required) {
      _lastShownAppUpdateVersionCode = update.versionCode;
    }
    _appUpdateDialogShowing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || app.pendingAppUpdate?.versionCode != update.versionCode) {
        _appUpdateDialogShowing = false;
        return;
      }
      try {
        await showDialog<void>(
          context: context,
          barrierDismissible: !update.required,
          builder: (dialogContext) => PopScope(
            canPop: !update.required,
            child: _AppUpdateDialog(update: update),
          ),
        );
      } finally {
        if (mounted) {
          _appUpdateDialogShowing = false;
        }
      }
    });
  }
}

class _AppUpdateDialog extends StatefulWidget {
  const _AppUpdateDialog({required this.update});

  final AppUpdateInfo update;

  @override
  State<_AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<_AppUpdateDialog> {
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final releaseNotes = widget.update.releaseNotes.trim();
    final status = app.appUpdateStatus.trim();
    final error = _error ?? app.appUpdateError;

    return AlertDialog(
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.md),
        side: BorderSide(color: PosColors.line),
      ),
      titlePadding: EdgeInsets.fromLTRB(22, 20, 22, 8),
      contentPadding: EdgeInsets.fromLTRB(22, 8, 22, 4),
      actionsPadding: EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PosColors.neutralSoft,
              borderRadius: BorderRadius.circular(PosRadii.sm),
              border: Border.all(color: PosColors.line),
            ),
            child: Icon(
              Icons.system_update_alt_rounded,
              color: PosColors.primaryDark,
              size: 22,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: TfText(
              text.appUpdateAvailableTitle,
              style: TextStyle(
                color: PosColors.slate,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            text.appUpdateAvailableMessage(widget.update.versionName),
            style: TextStyle(
              color: PosColors.slate,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          if (widget.update.required) ...[
            SizedBox(height: 10),
            _UpdateBadge(text.appUpdateRequired),
          ],
          if (releaseNotes.isNotEmpty) ...[
            SizedBox(height: 14),
            TfText(
              text.appUpdateReleaseNotes,
              style: TextStyle(
                color: PosColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 5),
            TfText(
              releaseNotes,
              style: TextStyle(
                color: PosColors.slate,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          SizedBox(height: 14),
          TfText(
            text.appUpdateAndroidNotice,
            style: TextStyle(
              color: PosColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          if (status.isNotEmpty) ...[
            SizedBox(height: 12),
            TfText(
              status,
              style: TextStyle(
                color: PosColors.primaryDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (error != null && error.trim().isNotEmpty) ...[
            SizedBox(height: 10),
            TfText(
              error,
              style: TextStyle(
                color: PosColors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (!widget.update.required)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    await app.dismissAppUpdate(widget.update);
                    if (context.mounted) Navigator.of(context).pop();
                  },
            child: Text(text.later),
          ),
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  await app.startAppUpdate(widget.update);
                  if (!context.mounted) return;
                  if (app.appUpdateError != null) {
                    setState(() {
                      _busy = false;
                      _error = app.appUpdateError;
                    });
                    return;
                  }
                  Navigator.of(context).pop();
                },
          icon: _busy
              ? SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.download_for_offline_outlined, size: 18),
          label: Text(text.updateNow),
        ),
      ],
    );
  }
}

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PosColors.neutralSoft,
        borderRadius: BorderRadius.circular(PosRadii.xs),
        border: Border.all(color: PosColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: PosColors.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _Destination {
  _Destination(this.label, this.bnLabel, this.icon, this.selectedIcon);

  final String label;
  final String bnLabel;
  final IconData icon;
  final IconData selectedIcon;
}

class _RailLogo extends StatelessWidget {
  const _RailLogo({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.select(context, AppAspect.language).strings;
    final mark = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: PosGradients.brand,
        borderRadius: BorderRadius.circular(PosRadii.md),
        boxShadow: PosShadows.glow,
      ),
      child: Icon(Icons.bolt_rounded, color: PosColors.accentInk, size: 24),
    );
    if (!extended) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text.appTitle,
              style: TextStyle(
                color: PosColors.slate,
                fontWeight: FontWeight.w500,
                fontSize: 16.5,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 2),
            Text(
              text.cloudSuite,
              style: TextStyle(
                color: PosColors.muted,
                fontWeight: FontWeight.w500,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Quick actions reachable from drawer group children — screens/sheets that
/// don't map to a nav tab. Handled by [_MainShellState._handleDrawerAction].
enum _DrawerAction {
  stockScan,
  stockIn,
  stockCount,
  menuScan,
  menuDeliveryCharge,
  menuDiscounts,
}

/// Petpooja-style left navigation drawer for the phone surface. Header =
/// brand + outlet; body = the role's primary destinations with expandable
/// groups (Analytics ▸ Reports, Stock ▸ Scan/Stock in/Count, Menu ▸ Scan
/// menu card/Delivery charge/Discounts), then Messages (permission-gated)
/// and a Settings entry into the More hub. Owner-only Backoffice/Counter
/// view switch at the bottom. Selecting an item closes the drawer first.
class _AppNavDrawer extends StatelessWidget {
  const _AppNavDrawer({
    required this.tabOrder,
    required this.selected,
    required this.onSelectTab,
    required this.onNavigateTarget,
    required this.onAction,
  });

  final List<_AppTab> tabOrder;
  final _AppTab selected;
  final ValueChanged<_AppTab> onSelectTab;
  final ValueChanged<PosNotificationTarget> onNavigateTarget;
  final ValueChanged<_DrawerAction> onAction;

  @override
  Widget build(BuildContext context) {
    // Drawer reads language (labels), account (role-gated rows), and settings
    // (outlet name) — not orders/printer/sync.
    final app = AppScope.selectMany(context, const [
      AppAspect.language,
      AppAspect.account,
      AppAspect.settings,
    ]);
    final text = app.strings;
    final isBn = text.isBn;
    final bool isBackoffice = tabOrder.contains(_AppTab.reports);
    // In backoffice, Reports is a flat row; in manage it is absent.
    final primary = tabOrder
        .where((t) => t != _AppTab.more && (isBackoffice || t != _AppTab.reports))
        .toList(growable: false);

    void close() => Navigator.of(context).pop();
    void goTab(_AppTab tab) {
      close();
      onSelectTab(tab);
    }

    void goTarget(PosNotificationTarget target) {
      close();
      onNavigateTarget(target);
    }

    void goAction(_DrawerAction action) {
      close();
      onAction(action);
    }

    Widget rowFor(_AppTab tab) {
      switch (tab) {
        case _AppTab.stock:
          return _DrawerNavGroup(
            destination: _destinationFor(tab, text),
            selected: tab == selected,
            isBn: isBn,
            onHeaderTap: () => goTab(tab),
            initiallyExpanded: tab == selected,
            children: [
              _DrawerNavRow.icon(
                icon: Icons.document_scanner_outlined,
                label: text.scanStock,
                selected: false,
                indented: true,
                onTap: () => goAction(_DrawerAction.stockScan),
              ),
              _DrawerNavRow.icon(
                icon: Icons.add_box_outlined,
                label: text.stockIn,
                selected: false,
                indented: true,
                onTap: () => goAction(_DrawerAction.stockIn),
              ),
              _DrawerNavRow.icon(
                icon: Icons.fact_check_outlined,
                label: text.countAction,
                selected: false,
                indented: true,
                onTap: () => goAction(_DrawerAction.stockCount),
              ),
            ],
          );
        case _AppTab.menu when app.accountRole.isManager:
          return _DrawerNavGroup(
            destination: _destinationFor(tab, text),
            selected: tab == selected,
            isBn: isBn,
            onHeaderTap: () => goTab(tab),
            initiallyExpanded: tab == selected,
            children: [
              _DrawerNavRow.icon(
                icon: Icons.document_scanner_outlined,
                label: text.menuScanCardButton,
                selected: false,
                indented: true,
                onTap: () => goAction(_DrawerAction.menuScan),
              ),
              _DrawerNavRow.icon(
                icon: Icons.delivery_dining_outlined,
                label: text.deliveryCharge,
                selected: false,
                indented: true,
                onTap: () => goAction(_DrawerAction.menuDeliveryCharge),
              ),
              _DrawerNavRow.icon(
                icon: Icons.percent_rounded,
                label: text.menuActionDiscounts,
                selected: false,
                indented: true,
                onTap: () => goAction(_DrawerAction.menuDiscounts),
              ),
            ],
          );
        default:
          return _DrawerNavRow.destination(
            destination: _destinationFor(tab, text, isBackoffice: isBackoffice),
            selected: tab == selected,
            isBn: isBn,
            onTap: () => goTab(tab),
          );
      }
    }

    return Drawer(
      backgroundColor: PosColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DrawerHeader(
              outletName: app.outletName.trim(),
            ),
            Divider(height: 1, thickness: 1, color: PosColors.line),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: PosSpacing.sp2),
                children: [
                   for (final tab in primary)
                    rowFor(tab),
                  const _DrawerDivider(),
                  _DrawerNavRow.destination(
                    destination: _destinationFor(_AppTab.more, text, isBackoffice: isBackoffice),
                    selected: selected == _AppTab.more,
                    isBn: isBn,
                    onTap: () => goTab(_AppTab.more),
                  ),
                ],
              ),
            ),
            // Owner-only Backoffice/Counter view switch at the bottom.
            if (app.demoOwnerAccess)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  PosSpacing.sp4,
                  PosSpacing.sp2,
                  PosSpacing.sp4,
                  PosSpacing.sp4,
                ),
                child: TfCompactRoleToggle(
                  expand: true,
                  role: app.accountRole.isOwner ? 'owner' : 'manager',
                  options: [
                    (text.managerRole, 'manager'),
                    (text.backofficeLabel, 'owner'),
                  ],
                  onChanged: (value) => app.setAccountRoleDemo(
                    value == 'owner'
                        ? AccountRole.owner
                        : AccountRole.manager,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Expandable drawer group: a normal destination row with a trailing chevron.
/// Tapping the row selects the group's tab (and closes the drawer); tapping
/// the chevron only toggles the children — the drawer stays open.
class _DrawerNavGroup extends StatefulWidget {
  const _DrawerNavGroup({
    required this.destination,
    required this.selected,
    required this.isBn,
    required this.onHeaderTap,
    required this.children,
    this.initiallyExpanded = false,
  });

  final _Destination destination;
  final bool selected;
  final bool isBn;
  final VoidCallback onHeaderTap;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  State<_DrawerNavGroup> createState() => _DrawerNavGroupState();
}

class _DrawerNavGroupState extends State<_DrawerNavGroup> {
  late bool _open = widget.initiallyExpanded;

  @override
  void didUpdateWidget(covariant _DrawerNavGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded && !oldWidget.initiallyExpanded) {
      _open = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            _DrawerNavRow.destination(
              destination: widget.destination,
              selected: widget.selected,
              isBn: widget.isBn,
              onTap: widget.onHeaderTap,
            ),
            Positioned(
              right: PosSpacing.sp2,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _open = !_open),
                child: SizedBox(
                  width: 44,
                  child: Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 22,
                    color: PosColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.children,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.outletName,
  });

  final String outletName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosSpacing.sp4,
        PosSpacing.sp4,
        PosSpacing.sp4,
        PosSpacing.sp4,
      ),
      child: TfBrandHeader(
        title: 'QuickBytes',
        subtitle: outletName.isEmpty ? null : outletName,
      ),
    );
  }
}

class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PosSpacing.sp4,
        vertical: PosSpacing.sp2,
      ),
      child: Divider(height: 1, thickness: 1, color: PosColors.line),
    );
  }
}

class _DrawerNavRow extends StatelessWidget {
  const _DrawerNavRow({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.indented = false,
  });

  _DrawerNavRow.destination({
    required _Destination destination,
    required bool selected,
    required bool isBn,
    required VoidCallback onTap,
  }) : this(
         icon: destination.icon,
         selectedIcon: destination.selectedIcon,
         label: isBn ? destination.bnLabel : destination.label,
         selected: selected,
         onTap: onTap,
       );

  const _DrawerNavRow.icon({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool indented = false,
  }) : this(
         icon: icon,
         selectedIcon: icon,
         label: label,
         selected: selected,
         onTap: onTap,
         indented: indented,
       );

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// When true the row is inset (used for indented sub-rows in the drawer).
  final bool indented;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: PosSpacing.sp2,
        vertical: PosSpacing.sp1,
      ),
      child: Material(
        color: selected ? PosColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(PosRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PosRadii.md),
              border: Border.all(
                color: selected ? PosColors.primaryWash : Colors.transparent,
                width: 1,
              ),
            ),
            child: Stack(
              children: [
                if (selected)
                  const Positioned(
                    left: 0,
                    top: PosSpacing.sp2,
                    bottom: PosSpacing.sp2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: PosColors.primary,
                        borderRadius: BorderRadius.horizontal(
                          right: Radius.circular(PosRadii.pill),
                        ),
                      ),
                      child: SizedBox(width: 3),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    indented
                        ? PosSpacing.sp3 + PosSpacing.sp5
                        : PosSpacing.sp3 + (selected ? PosSpacing.sp1 : 0),
                    PosSpacing.sp3,
                    PosSpacing.sp3,
                    PosSpacing.sp3,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected ? selectedIcon : icon,
                        size: indented ? 20 : 22,
                        color: selected ? PosColors.primary : PosColors.muted,
                      ),
                      const SizedBox(width: PosSpacing.sp3),
                      Expanded(
                        child: TfText(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: tfFontFamily(context),
                            fontSize: 15,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected
                                ? PosColors.primary
                                : PosColors.primaryDark,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailFooter extends StatelessWidget {
  const _RailFooter({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    if (!extended) {
      return Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: PosColors.neutralSoft,
          borderRadius: BorderRadius.circular(PosRadii.sm),
          border: Border.all(color: PosColors.line),
        ),
        child: Icon(
          Icons.verified_user_outlined,
          color: PosColors.neutralInk,
          size: 20,
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosColors.neutralSoft,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_user_outlined,
            color: PosColors.primary,
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text.secureTenant,
                  style: TextStyle(
                    color: PosColors.primaryDark,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  text.tokenVerified,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontWeight: FontWeight.w500,
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// IndexedStack variant that only builds children for tabs that have actually
/// been visited. Unvisited slots render a [SizedBox.shrink], so their screens
/// (and the controllers/streams those screens initState) never come up until
/// the user opens the tab. Once visited, the slot stays mounted so state and
/// scroll position survive subsequent tab switches.
class _LazyIndexedStack extends StatefulWidget {
  const _LazyIndexedStack({required this.index, required this.builders});

  final int index;
  final List<WidgetBuilder> builders;

  @override
  State<_LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<_LazyIndexedStack> {
  final Set<int> _visited = <int>{};

  @override
  void initState() {
    super.initState();
    _visited.add(widget.index);
  }

  @override
  void didUpdateWidget(covariant _LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _visited.add(widget.index);
    if (widget.builders.length != oldWidget.builders.length) {
      _visited.removeWhere((i) => i >= widget.builders.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      sizing: StackFit.expand,
      children: [
        for (var i = 0; i < widget.builders.length; i++)
          _visited.contains(i)
              ? widget.builders[i](context)
              : const SizedBox.shrink(),
      ],
    );
  }
}
