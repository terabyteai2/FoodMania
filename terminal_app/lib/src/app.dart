import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'app_scope.dart';
import 'core/localization/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/notification_center.dart';
import 'core/widgets/tf_design_system.dart';
import 'models/app_update_info.dart';
import 'models/pos_notification.dart';
import 'features/menu/menu_management_screen.dart';
import 'features/messaging/messages_screen.dart';
import 'features/more/more_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/auth/staff_invite_screen.dart';
import 'features/setup/tenant_setup_screen.dart';
import 'features/settings/settings_screen.dart';
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final uiScale = _controller.uiScale;
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
              theme: AppTheme.light(uiScale: uiScale),
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
              home: AnimatedSwitcher(
                duration: Duration(milliseconds: 320),
                child: _home(),
              ),
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
      );
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

    return MainShell(initialIndex: _initialShellIndex, onMounted: mounted);
  }

  /// Visual index of the Orders tab — the default landing tab.
  int _defaultShellIndex() {
    final i = _terminalTabOrder.indexOf(_AppTab.orders);
    return i < 0 ? 0 : i;
  }
}

// Lean terminal navigation — single manager role. Enum ordinals fix the
// page-build slots; the list below chooses which tabs show and in what order.
enum _AppTab { live, tables, orders, more, menu }

// Manager terminal: Live (Control Tower) · Menu · Orders · More
const _terminalTabOrder = <_AppTab>[
  _AppTab.live,
  _AppTab.menu,
  _AppTab.orders,
  _AppTab.more,
];

class MainShell extends StatefulWidget {
  const MainShell({required this.initialIndex, this.onMounted, super.key});

  final int initialIndex;
  final VoidCallback? onMounted;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late _AppTab _selected;
  List<_AppTab> _currentTabOrder = _terminalTabOrder;
  String? _lastShownNotificationKey;
  String? _pendingNotificationToastKey;
  Timer? _notificationToastDebounce;
  int? _lastShownAppUpdateVersionCode;
  bool _appUpdateDialogShowing = false;
  int _receiptPrinterOpenRequest = 0;

  @override
  void initState() {
    super.initState();
    final vi = widget.initialIndex.clamp(0, _terminalTabOrder.length - 1);
    _selected = _terminalTabOrder[vi];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).systemNotifications.requestNotificationAccess();
      widget.onMounted?.call();
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
    _notificationToastDebounce?.cancel();
    super.dispose();
  }

  _Destination _destinationFor(_AppTab tab, AppStrings text) {
    return switch (tab) {
      _AppTab.live => _Destination(
        text.liveTab,
        text.liveTab,
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
        text.orders,
        text.orders,
        Icons.receipt_long_outlined,
        Icons.receipt_long,
      ),
      _AppTab.menu => _Destination(
        text.menu,
        text.menu,
        Icons.restaurant_menu_outlined,
        Icons.restaurant_menu,
      ),
      _AppTab.more => _Destination(
        text.moreTab,
        text.moreTab,
        Icons.more_horiz_rounded,
        Icons.more_horiz_rounded,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    _currentTabOrder = _terminalTabOrder;
    if (!_currentTabOrder.contains(_selected)) {
      _selected = _currentTabOrder.first;
    }
    _maybeShowNotification(app);
    final tabOrder = _currentTabOrder;
    final visualIndex = tabOrder
        .indexOf(_selected)
        .clamp(0, tabOrder.length - 1);
    final destinations = tabOrder
        .map((t) => _destinationFor(t, text))
        .toList(growable: false);

    // Fixed page order matching _AppTab.index ordinals. Builders (not eager
    // instances) so unvisited tabs never mount — see [_LazyIndexedStack].
    void goToOrders() => _selectTab(_AppTab.orders);
    // Order MUST match _AppTab ordinals: live, tables, orders, more, menu.
    final pageBuilders = <WidgetBuilder>[
      (_) => ControlTowerScreen(
        onNavigateToOrders: goToOrders,
        onNavigateToTarget: _navigateNotificationTarget,
      ),
      (_) => TablesScreen(
        onNavigateToOrders: goToOrders,
        onNavigateToTarget: _navigateNotificationTarget,
      ),
      (_) => OrdersScreen(onNavigateToTarget: _navigateNotificationTarget),
      (_) => MoreScreen(
        onNavigateToOrders: goToOrders,
        onNavigateToTarget: _navigateNotificationTarget,
      ),
      (_) => MenuManagementScreen(
        onNavigateToOrders: goToOrders,
        onNavigateToTarget: _navigateNotificationTarget,
      ),
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
          return Scaffold(
            backgroundColor: PosColors.background,
            body: body,
            bottomNavigationBar: _FloatingBottomNav(
              destinations: destinations,
              selectedIndex: visualIndex,
              onChanged: _setIndex,
            ),
          );
        }

        final extended = constraints.maxWidth >= 1050;
        return Scaffold(
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
                    padding: EdgeInsets.fromLTRB(14, 22, 14, 28),
                    child: _RailLogo(extended: extended),
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
              Expanded(child: body),
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
    // Settings lives in the More hub, so its deep-links push the screen rather
    // than switching a tab. Inventory is removed on the terminal — its target
    // no longer has a screen to route to (no-op).
    switch (target) {
      case PosNotificationTarget.orders:
        _selectTab(_AppTab.orders);
        return;
      case PosNotificationTarget.inventory:
        return;
      case PosNotificationTarget.menu:
        _selectTab(_AppTab.menu);
        return;
      case PosNotificationTarget.receiptPrinter:
        _receiptPrinterOpenRequest++;
        _pushScreen(
          SettingsScreen(
            onNavigateToOrders: () => _selectTab(_AppTab.orders),
            onNavigateToTarget: _navigateNotificationTarget,
            receiptPrinterOpenRequest: _receiptPrinterOpenRequest,
          ),
        );
        return;
      case PosNotificationTarget.settings:
        _pushScreen(
          SettingsScreen(
            onNavigateToOrders: () => _selectTab(_AppTab.orders),
            onNavigateToTarget: _navigateNotificationTarget,
          ),
        );
        return;
      case PosNotificationTarget.messages:
        // Chatbot-escalation notifications route to the Messages inbox (mgr+).
        if (AppScope.of(context).canMessages) {
          _pushScreen(const MessagesScreen());
        }
        return;
      case PosNotificationTarget.none:
        return;
    }
  }

  Future<void> _deepLinkToChat(String conversationId) async {
    final app = AppScope.of(context);
    try {
      final chats = await app.fetchChats();
      final chat = chats.where((c) => c.id == conversationId).firstOrNull;
      if (!mounted) return;
      if (chat != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(chat: chat),
          ),
        );
        return;
      }
      _pushScreen(const MessagesScreen());
    } catch (_) {
      if (mounted) _pushScreen(const MessagesScreen());
    }
  }

  void _pushScreen(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  bool _isChatNotification(PosNotification n) =>
      n.type == PosNotificationType.system && n.actionTarget == 'messages';

  void _maybeShowNotification(PosAppController app) {
    final unread = app.notifications
        .where((notification) => !notification.isRead)
        .toList(growable: false);
    if (unread.isEmpty) return;
    final latest = unread.first;
    final isChatAlert = _isChatNotification(latest);
    final alertKey = isChatAlert
        ? latest.id
        : unread.length > 1
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
    final app = AppScope.of(context);
    final text = app.strings;
    final unread = app.notifications
        .where((notification) => !notification.isRead)
        .toList(growable: false);
    if (unread.isEmpty) {
      _pendingNotificationToastKey = null;
      return;
    }
    final latest = unread.first;
    final isChatAlert = _isChatNotification(latest);
    final alertKey = isChatAlert
        ? latest.id
        : unread.length > 1
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
      title: isChatAlert || unread.length == 1
          ? latest.title
          : text.notificationSummaryTitle(unread.length),
      body: isChatAlert || unread.length == 1
          ? latest.body
          : text.notificationSummaryBody,
      onOpen: () {
        if (unread.length > 1 && !isChatAlert) {
          showNotificationCenter(
            context,
            onNavigateToOrders: () => _selectTab(_AppTab.orders),
            onNavigateToTarget: _navigateNotificationTarget,
          );
        } else {
          app.markNotificationRead(latest.id);
          if (isChatAlert && latest.orderId != null) {
            _deepLinkToChat(latest.orderId!);
          } else {
            _navigateNotificationTarget(latest.target);
          }
        }
      },
    );
  }

  void _maybeShowAppUpdatePrompt(PosAppController app) {
    final update = app.pendingAppUpdate;
    if (update == null || app.appUpdateBusy) return;
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
              color: PosColors.primarySoft,
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
        color: PosColors.primarySoft,
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
    final text = AppScope.of(context).strings;
    final mark = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: PosGradients.brand,
        borderRadius: BorderRadius.circular(PosRadii.md),
        boxShadow: PosShadows.glow,
      ),
      child: Icon(Icons.whatshot_rounded, color: PosColors.slate, size: 24),
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

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.destinations,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<_Destination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return TfBottomNav(
      activeIndex: selectedIndex,
      onChanged: onChanged,
      items: destinations
          .map(
            (destination) => TfBottomNavItem(
              icon: destination.icon,
              selectedIcon: destination.selectedIcon,
              label: destination.label,
              labelBn: destination.bnLabel,
            ),
          )
          .toList(growable: false),
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
          color: PosColors.primarySoft,
          borderRadius: BorderRadius.circular(PosRadii.sm),
          border: Border.all(color: PosColors.line),
        ),
        child: Icon(
          Icons.verified_user_outlined,
          color: PosColors.primary,
          size: 20,
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PosColors.primarySoft,
            PosColors.primarySoft.withValues(alpha: 0.55),
          ],
        ),
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
