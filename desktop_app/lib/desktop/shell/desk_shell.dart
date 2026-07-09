import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';

import '../analytics/analytics_screen.dart';
import '../billing/billing_screen.dart';
import '../dayend/day_end_screen.dart';
import '../inventory/inventory_screen.dart';
import '../menu/menu_screen.dart';
import '../orders/orders_screen.dart';
import '../settings/settings_screen.dart';
import '../tables/tables_screen.dart';
import '../theme/desk_theme.dart';
import '../theme/desk_widgets.dart';
import 'desk_nav.dart';

/// The desktop register chrome: slim top app bar + left navigation rail +
/// main region (petpooja13/16). Feature screens are slotted into [_body] as
/// each phase lands; Phase 0 ships the chrome and a live status overview that
/// proves login, cloud/DB reuse and data loading all work.
class DeskShell extends StatefulWidget {
  const DeskShell({super.key});

  @override
  State<DeskShell> createState() => _DeskShellState();
}

class _DeskShellState extends State<DeskShell> {
  int _index = 0;
  bool _navExpanded = true;
  BillingSeed? _billingSeed;

  static const _dests = <_Dest>[
    _Dest(Icons.dashboard_rounded, 'Overview', 0),
    _Dest(Icons.point_of_sale_rounded, 'Billing', 1),
    _Dest(Icons.table_restaurant_rounded, 'Tables', 2),
    _Dest(Icons.receipt_long_rounded, 'Orders', 3),
    _Dest(Icons.restaurant_menu_rounded, 'Menu', 4),
    _Dest(Icons.summarize_rounded, 'Day End', 5),
    _Dest(Icons.inventory_2_rounded, 'Inventory', 6),
    _Dest(Icons.insights_rounded, 'Analytics', 7),
    _Dest(Icons.settings_rounded, 'Settings', 8),
  ];

  void _select(int i) => setState(() {
        if (i == 1) _billingSeed = null; // rail → Billing starts fresh
        _index = i;
      });

  @override
  Widget build(BuildContext context) {
    return DeskNav(
      goToIndex: _select,
      startOrder: (seed) => setState(() {
        _billingSeed = seed;
        _index = 1;
      }),
      child: Scaffold(
        backgroundColor: PosColors.background,
        body: Column(
          children: [
            _TopBar(
              onNewOrder: () => setState(() {
                _billingSeed = null;
                _index = 1;
              }),
              onToggleNav: () =>
                  setState(() => _navExpanded = !_navExpanded),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rail(
                    dests: _dests,
                    selected: _index,
                    onSelect: _select,
                    expanded: _navExpanded,
                  ),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    switch (_index) {
      case 0:
        return const _Overview();
      case 1:
        return BillingScreen(seed: _billingSeed);
      case 2:
        return const TablesScreen();
      case 3:
        return const OrdersScreen();
      case 4:
        return const MenuScreen();
      case 5:
        return const DayEndScreen();
      case 6:
        return const InventoryScreen();
      case 7:
        return const AnalyticsScreen();
      case 8:
        return const SettingsScreen();
    }
    final dest = _dests[_index];
    return _ComingSoon(label: dest.label, phase: dest.phase);
  }
}

class _Dest {
  const _Dest(this.icon, this.label, this.phase);
  final IconData icon;
  final String label;
  final int phase; // the plan phase that fills this destination
}

// ─────────────────────────── Top bar ───────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onNewOrder, required this.onToggleNav});

  final VoidCallback onNewOrder;
  final VoidCallback onToggleNav;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Container(
      height: DeskMetrics.topBar,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 22),
            color: PosColors.ink2,
            splashRadius: 20,
            tooltip: 'Toggle navigation',
            onPressed: onToggleNav,
          ),
          const SizedBox(width: 4),
          const Icon(Icons.point_of_sale_rounded,
              color: PosColors.primary, size: 22),
          const SizedBox(width: 8),
          Text(
            'QuickBytes',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: PosColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          _NewOrderButton(onPressed: onNewOrder),
          const SizedBox(width: 12),
          const Expanded(child: _BillSearch()),
          const SizedBox(width: 12),
          _barIcon(Icons.notifications_none_rounded, () {}),
          _barIcon(Icons.help_outline_rounded, () {}),
          _barIcon(Icons.power_settings_new_rounded, () => app.logOut()),
        ],
      ),
    );
  }

  Widget _barIcon(IconData icon, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 20, color: PosColors.ink2),
      splashRadius: 20,
      onPressed: onTap,
    );
  }
}

class _NewOrderButton extends StatelessWidget {
  const _NewOrderButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: PosColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 18),
      label: const Text('New Order',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
    );
  }
}

class _BillSearch extends StatelessWidget {
  const _BillSearch();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextField(
        enabled: false,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 18, color: PosColors.muted),
          hintText: 'Bill No',
          filled: true,
          fillColor: PosColors.surfaceSunk,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.md),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Rail ───────────────────────────

class _Rail extends StatelessWidget {
  const _Rail({
    required this.dests,
    required this.selected,
    required this.onSelect,
    required this.expanded,
  });

  final List<_Dest> dests;
  final int selected;
  final ValueChanged<int> onSelect;
  final bool expanded;

  /// Icons-only width when the sidebar is collapsed.
  static const double collapsedWidth = 64;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: expanded ? DeskMetrics.railWidth : collapsedWidth,
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(right: BorderSide(color: PosColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: expanded
                ? const EdgeInsets.fromLTRB(14, 14, 14, 8)
                : const EdgeInsets.fromLTRB(0, 14, 0, 8),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                const Icon(Icons.storefront_rounded,
                    size: 18, color: PosColors.ink2),
                if (expanded) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      app.restaurantName.isEmpty
                          ? 'QuickBytes'
                          : app.restaurantName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PosColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1, color: PosColors.line),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (var i = 0; i < dests.length; i++)
                  _RailItem(
                    dest: dests[i],
                    active: i == selected,
                    expanded: expanded,
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: PosColors.line),
          if (expanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${app.accountDisplayName.isEmpty ? 'Signed in' : app.accountDisplayName} · ${app.accountRole.label}',
                style: TextStyle(fontSize: 11.5, color: PosColors.muted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Tooltip(
                message: app.accountDisplayName.isEmpty
                    ? app.accountRole.label
                    : '${app.accountDisplayName} · ${app.accountRole.label}',
                child: const Icon(Icons.account_circle_rounded,
                    size: 22, color: PosColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.dest,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  final _Dest dest;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      dest.icon,
      size: 19,
      color: active ? PosColors.primary : PosColors.ink2,
    );
    final content = expanded
        ? Row(
            children: [
              icon,
              const SizedBox(width: 12),
              Text(
                dest.label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? PosColors.primary : PosColors.primaryDark,
                ),
              ),
            ],
          )
        : Center(child: icon);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? PosColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(PosRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(PosRadii.md),
          onTap: onTap,
          child: Tooltip(
            message: expanded ? '' : dest.label,
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: expanded ? 12 : 8, vertical: 11),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Bodies ───────────────────────────

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final openOrders =
        app.orders.where((o) => o.status.adminStatus.isOpen).length;
    final sync = app.syncState;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: PosColors.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${app.restaurantName}${app.outletName.isEmpty ? '' : ' · ${app.outletName}'}',
            style: TextStyle(fontSize: 13.5, color: PosColors.muted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: DeskMetrics.panelGap,
            runSpacing: DeskMetrics.panelGap,
            children: [
              DeskStatTile(
                icon: Icons.restaurant_menu_rounded,
                label: 'Menu items',
                value: '${app.menuItems.length}',
              ),
              DeskStatTile(
                icon: Icons.receipt_long_rounded,
                label: 'Open orders',
                value: '$openOrders',
              ),
              DeskStatTile(
                icon: Icons.inventory_2_rounded,
                label: 'Stock items',
                value: '${app.inventoryItems.length}',
              ),
              DeskStatTile(
                icon: sync.cloudConnected
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_off_rounded,
                label: sync.cloudConnected ? 'Cloud connected' : 'Offline',
                value: sync.pendingCount > 0
                    ? '${sync.pendingCount} pending'
                    : 'Synced',
                accent: sync.cloudConnected
                    ? PosColors.success
                    : PosColors.warning,
                tint: sync.cloudConnected
                    ? PosColors.successSoft
                    : PosColors.warnSoft,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PosColors.primarySoft,
              borderRadius: BorderRadius.circular(PosRadii.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.build_circle_rounded,
                    size: 18, color: PosColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Phase 0 scaffold is live. Billing, Tables, Orders, Menu, '
                    'Inventory, Analytics and Day-End screens land in the '
                    'following phases.',
                    style: TextStyle(
                        fontSize: 12.5, color: PosColors.accentSoftInk),
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

class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.label, required this.phase});
  final String label;
  final int phase;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_rounded, size: 36, color: PosColors.muted),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: PosColors.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text('Arrives in Phase $phase',
              style: TextStyle(fontSize: 13, color: PosColors.muted)),
        ],
      ),
    );
  }
}
