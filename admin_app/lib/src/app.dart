import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'app_scope.dart';
import 'core/localization/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/notification_center.dart';
import 'models/app_update_info.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/inventory/inventory_screen.dart';
import 'features/menu/menu_management_screen.dart';
import 'features/orders/orders_screen.dart';
import 'features/onboarding/subscription_screen.dart';
import 'features/auth/staff_invite_screen.dart';
import 'features/setup/tenant_setup_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/mode_intro_screen.dart';
import 'features/splash/splash_screen.dart';

class LocalPosApp extends StatefulWidget {
  const LocalPosApp({super.key});

  @override
  State<LocalPosApp> createState() => _LocalPosAppState();
}

class _LocalPosAppState extends State<LocalPosApp> with WidgetsBindingObserver {
  late final PosAppController _controller;
  late final Future<void> _bootFuture;
  bool _showSplash = true;
  bool _showIntro = false;
  int _initialShellIndex = _dashboardTabIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = PosAppController();
    _bootFuture = _controller.initialize();
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
          return MaterialApp(
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
    if (_showSplash) {
      return SplashScreen(
        bootFuture: _bootFuture,
        onFinished: () {
          setState(() {
            _showSplash = false;
            _showIntro = !_controller.hasSeenIntro;
            _initialShellIndex = _defaultShellIndex();
          });
        },
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
    if (_controller.isManager &&
        (_controller.mustCompleteOnboardingPayment ||
            _controller.subscriptionState != 'paid')) {
      return SubscriptionScreen(
        onFinished: () {
          setState(() {
            _initialShellIndex = _defaultShellIndex();
          });
        },
      );
    }
    final pending = _controller.pendingOnboardingLanding;
    if (pending && _initialShellIndex != _dashboardTabIndex) {
      _initialShellIndex = _defaultShellIndex();
    }
    return MainShell(
      initialIndex: _initialShellIndex,
      onMounted: () {
        if (_controller.pendingOnboardingLanding) {
          _controller.consumeOnboardingLanding();
        }
      },
    );
  }

  int _defaultShellIndex() => _controller.isManager ? _dashboardTabIndex : 0;

  static const int _dashboardTabIndex = 2;
}

enum _AppTab { orders, menu, home, stock, settings }

const _managerTabOrder = <_AppTab>[
  _AppTab.orders,
  _AppTab.menu,
  _AppTab.home,
  _AppTab.stock,
  _AppTab.settings,
];
const _staffTabOrder = <_AppTab>[
  _AppTab.orders,
  _AppTab.menu,
  _AppTab.settings,
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
  List<_AppTab> _currentTabOrder = _managerTabOrder;
  String? _lastShownNotificationKey;
  int? _lastShownAppUpdateVersionCode;

  @override
  void initState() {
    super.initState();
    final vi = widget.initialIndex.clamp(0, _managerTabOrder.length - 1);
    _selected = _managerTabOrder[vi];
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

  _Destination _destinationFor(_AppTab tab, AppStrings _) {
    return switch (tab) {
      _AppTab.orders => _Destination(
        'Orders',
        'অর্ডার',
        Icons.receipt_long_outlined,
        Icons.receipt_long,
      ),
      _AppTab.menu => _Destination(
        'Menu',
        'মেনু',
        Icons.restaurant_menu_outlined,
        Icons.restaurant_menu,
      ),
      _AppTab.home => _Destination(
        'Home',
        'হোম',
        Icons.home_outlined,
        Icons.home_rounded,
      ),
      _AppTab.stock => _Destination(
        'Stock',
        'স্টক',
        Icons.grid_on_outlined,
        Icons.grid_on_rounded,
      ),
      _AppTab.settings => _Destination(
        'More',
        'আরও',
        Icons.settings_outlined,
        Icons.settings_rounded,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    _currentTabOrder = app.isManager ? _managerTabOrder : _staffTabOrder;
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

    // Fixed page order matching _AppTab.index ordinals.
    final ordersIndex = _AppTab.orders.index;
    void goToOrders() => _setIndex(ordersIndex);
    final allPages = [
      const OrdersScreen(),
      MenuManagementScreen(onNavigateToOrders: goToOrders),
      DashboardScreen(onNavigate: _setIndex),
      InventoryScreen(onNavigateToOrders: goToOrders),
      SettingsScreen(onNavigateToOrders: goToOrders),
    ];

    // Each page renders the notification bell as one of its own header
    // actions (via HeaderNotificationBell) — no global floating overlay,
    // so it never sits on top of the menu page's "+ New" button etc.
    _maybeShowAppUpdatePrompt(app);
    final body = IndexedStack(index: _selected.index, children: allPages);
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
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x55000000),
                      blurRadius: 22,
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
                          label: Text(destination.label),
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

  void _maybeShowNotification(PosAppController app) {
    if (app.notifications.isEmpty) return;
    final latest = app.notifications.first;
    if (latest.isRead) return;
    final alertKey = latest.orderId != null
        ? '${latest.orderId}:${latest.type.name}'
        : latest.id;
    if (alertKey == _lastShownNotificationKey) return;
    _lastShownNotificationKey = alertKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showTopNotificationToast(
        context,
        title: latest.title,
        body: latest.body,
        onOpen: () {
          app.markNotificationRead(latest.id);
          if (latest.actionTarget == 'pending_orders' ||
              latest.actionTarget == 'orders') {
            _setIndex(0);
          }
        },
      );
    });
  }

  void _maybeShowAppUpdatePrompt(PosAppController app) {
    final update = app.pendingAppUpdate;
    if (update == null || app.appUpdateBusy) return;
    if (_lastShownAppUpdateVersionCode == update.versionCode) return;
    _lastShownAppUpdateVersionCode = update.versionCode;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || app.pendingAppUpdate?.versionCode != update.versionCode) {
        return;
      }
      await showDialog<void>(
        context: context,
        barrierDismissible: !update.required,
        builder: (dialogContext) => _AppUpdateDialog(update: update),
      );
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
            child: Text(
              text.appUpdateAvailableTitle,
              style: TextStyle(
                color: PosColors.slate,
                fontSize: 18,
                fontWeight: FontWeight.w900,
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
          Text(
            text.appUpdateAvailableMessage(widget.update.versionName),
            style: TextStyle(
              color: PosColors.slate,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (widget.update.required) ...[
            SizedBox(height: 10),
            _UpdateBadge(text.appUpdateRequired),
          ],
          if (releaseNotes.isNotEmpty) ...[
            SizedBox(height: 14),
            Text(
              text.appUpdateReleaseNotes,
              style: TextStyle(
                color: PosColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 5),
            Text(
              releaseNotes,
              style: TextStyle(
                color: PosColors.slate,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          SizedBox(height: 14),
          Text(
            text.appUpdateAndroidNotice,
            style: TextStyle(
              color: PosColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (status.isNotEmpty) ...[
            SizedBox(height: 12),
            Text(
              status,
              style: TextStyle(
                color: PosColors.primaryDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (error != null && error.trim().isNotEmpty) ...[
            SizedBox(height: 10),
            Text(
              error,
              style: TextStyle(
                color: PosColors.danger,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
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
          fontWeight: FontWeight.w900,
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
        boxShadow: [
          BoxShadow(
            color: PosColors.primary.withValues(alpha: 0.36),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
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
                fontWeight: FontWeight.w900,
                fontSize: 16.5,
                letterSpacing: 0,
              ),
            ),
            SizedBox(height: 2),
            Text(
              text.cloudSuite,
              style: TextStyle(
                color: PosColors.muted,
                fontWeight: FontWeight.w700,
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
    return SafeArea(
      top: false,
      minimum: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          color: PosColors.surface,
          border: Border(top: BorderSide(color: PosColors.line, width: 0.5)),
        ),
        child: SizedBox(
          height: 70,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < destinations.length; i++)
                  Expanded(
                    child: _BottomNavItem(
                      destination: destinations[i],
                      selected: i == selectedIndex,
                      onTap: () => onChanged(i),
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

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected
        ? const Color(0xFF1C1A17)
        : const Color(0xFF888780);
    final icon = destination.icon; // outline icon — design uses outline only.

    return Tooltip(
      message: destination.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: destination.label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: foreground, size: 22),
                  const SizedBox(height: 4),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      fontSize: 11,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.bnLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontFamily: 'Hind Siliguri',
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                      fontSize: 10,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: selected ? 18 : 0,
                    height: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5C127),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
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
                    fontWeight: FontWeight.w900,
                    fontSize: 12.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  text.tokenVerified,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontWeight: FontWeight.w700,
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
