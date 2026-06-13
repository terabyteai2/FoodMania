// QuickBytes Desktop — counter-station shell. Faithful to the design source of
// truth (`taget_app/desktop_design/desktop-*.jsx`): a 1280×800 scaling stage
// with a 92px role-aware nav rail, screen header, rail popovers (notifications /
// account-role), a Messenger slide-over and a toast. All data flows through the
// existing [PosAppController]; ephemeral view state lives in [DeskController].

import 'dart:async';

import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../models/desktop_pos.dart';
import 'desk_controller.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/register_screen.dart';
import 'screens/stock_screen.dart';
import 'screens/tables_screen.dart';
import 'widgets/dk_chrome.dart';
import 'widgets/messages_overlay.dart';

class DesktopPosShell extends StatefulWidget {
  const DesktopPosShell({this.onMounted, super.key});

  final VoidCallback? onMounted;

  @override
  State<DesktopPosShell> createState() => _DesktopPosShellState();
}

class _DesktopPosShellState extends State<DesktopPosShell> {
  final DeskController _desk = DeskController();
  StreamSubscription<void>? _dbSub;
  bool _bootstrapped = false;
  DesktopPosSettings? _settings;
  PosShift? _shift;
  int _escalations = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMounted?.call();
      final app = AppScope.read(context);
      _dbSub = app.database.changes.listen((_) {
        if (mounted) unawaited(_reload());
      });
      if (!_bootstrapped) {
        _bootstrapped = true;
        unawaited(app.refreshDesktopPosFromCloud().then((_) => _reload()));
        unawaited(_loadEscalations());
      }
      unawaited(_reload());
    });
  }

  Future<void> _loadEscalations() async {
    try {
      final chats = await AppScope.read(context).fetchChats();
      if (!mounted) return;
      setState(() => _escalations = chats.where((c) => c.needsAttention).length);
    } catch (_) {/* best-effort badge */}
  }

  @override
  void dispose() {
    unawaited(_dbSub?.cancel());
    _desk.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final app = AppScope.read(context);
    final settings = await app.loadDesktopPosSettings();
    final shift = await app.currentDesktopShift();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _shift = shift;
    });
  }

  /// Open the register shift on demand (the QuickBytes Desktop design has no
  /// separate day-open screen; counter stations open implicitly on first sale).
  Future<PosShift?> _ensureShift() async {
    if (_shift != null) return _shift;
    final app = AppScope.read(context);
    try {
      final shift = await app.openDesktopShift(openingCash: 0, denominations: const {});
      if (mounted) setState(() => _shift = shift);
      return shift;
    } catch (error) {
      _desk.showToast('$error');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context); // subscribe to role/lang/data changes
    return Scaffold(
      body: DeskScope(
        controller: _desk,
        child: AnimatedBuilder(
          animation: _desk,
          builder: (context, _) {
            final desk = _desk;
            final allowed = deskNavForRole(app.accountRole).map((e) => e.tab).toSet();
            final activeTab = allowed.contains(desk.tab) ? desk.tab : DeskTab.register;
            return DkStage(
              child: Stack(
                children: [
                  Row(
                    children: [
                      DkNavRail(app: app, desk: desk, escalations: _escalations),
                      Expanded(
                        child: _DeskBody(
                          tab: activeTab,
                          settings: _settings,
                          shift: _shift,
                          ensureShift: _ensureShift,
                        ),
                      ),
                    ],
                  ),
                  if (desk.pop != DeskPop.none) ...[
                    Positioned.fill(
                      child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: desk.closePop),
                    ),
                    if (desk.pop == DeskPop.notif)
                      Positioned(left: 80, bottom: 64, child: DkNotifPanel(app: app, desk: desk)),
                    if (desk.pop == DeskPop.account)
                      Positioned(left: 80, bottom: 14, child: DkAccountPanel(app: app, desk: desk)),
                  ],
                  if (desk.msgOpen)
                    MessagesOverlay(
                      desk: desk,
                      onNeedsChanged: (n) => setState(() => _escalations = n),
                    ),
                  if (desk.toastMessage != null)
                    Positioned(
                      bottom: 22,
                      left: 0,
                      right: 0,
                      child: Center(child: DkToast(message: desk.toastMessage!)),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Routes the active desktop tab to its screen. Register is live; the remaining
/// screens land in their milestones (Orders M3, Tables/Stock M4, Dashboard M5).
class _DeskBody extends StatelessWidget {
  const _DeskBody({required this.tab, required this.settings, required this.shift, required this.ensureShift});

  final DeskTab tab;
  final DesktopPosSettings? settings;
  final PosShift? shift;
  final Future<PosShift?> Function() ensureShift;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);

    if (tab == DeskTab.register) {
      final s = settings ?? DesktopPosSettings(floorLayout: DesktopPosSettings.fallbackFloor(app.serverConfig.tableCount));
      return RegisterScreen(settings: s, shift: shift, ensureShift: ensureShift);
    }
    if (tab == DeskTab.orders) return const DeskOrdersScreen();
    if (tab == DeskTab.tables) {
      final s = settings ?? DesktopPosSettings(floorLayout: DesktopPosSettings.fallbackFloor(app.serverConfig.tableCount));
      return DeskTablesScreen(settings: s);
    }
    if (tab == DeskTab.inventory) return const DeskStockScreen();
    return const DeskDashboardScreen();
  }
}
