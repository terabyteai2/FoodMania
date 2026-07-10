import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart'
    show AppLanguage;

import '../analytics/analytics_screen.dart';
import '../billing/billing_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../dayend/day_end_screen.dart';
import '../inventory/inventory_screen.dart';
import '../menu/menu_screen.dart';
import '../orders/orders_screen.dart';
import '../settings/settings_screen.dart';
import '../tables/tables_screen.dart';
import '../theme/desk_theme.dart';
import 'desk_nav.dart';

/// Desktop register chrome aligned to the pos_web design system.
  /// 9-section collapsible rail + top bar aligned to Petpooja reference.
  /// Nav order: Dashboard, Billing, Tables, Orders, Menu, Inventory, Day End, Analytics, Settings.
class DeskShell extends StatefulWidget {
  const DeskShell({super.key});

  @override
  State<DeskShell> createState() => _DeskShellState();
}

class _DeskShellState extends State<DeskShell> {
  int _index = 0;
  BillingSeed? _billingSeed;

  static const _dests = <_Dest>[
    _Dest(Icons.dashboard_rounded, 'Dashboard'),
    _Dest(Icons.point_of_sale_rounded, 'Billing'),
    _Dest(Icons.table_restaurant_rounded, 'Tables'),
    _Dest(Icons.receipt_long_rounded, 'Orders'),
    _Dest(Icons.restaurant_menu_rounded, 'Menu'),
    _Dest(Icons.inventory_2_rounded, 'Inventory'),
    _Dest(Icons.summarize_rounded, 'Day End'),
    _Dest(Icons.insights_rounded, 'Analytics'),
    _Dest(Icons.settings_rounded, 'Settings'),
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
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Rail(
                    dests: _dests,
                    selected: _index,
                    onSelect: _select,
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
    if (_index < 0 || _index >= _dests.length) {
      return const _ComingSoon(label: 'Unknown', phase: 0);
    }
    return switch (_index) {
      0 => const DashboardScreen(),
      1 => BillingScreen(seed: _billingSeed),
      2 => const TablesScreen(),
      3 => const OrdersScreen(),
      4 => const MenuScreen(),
      5 => const InventoryScreen(),
      6 => const DayEndScreen(),
      7 => const AnalyticsScreen(),
      8 => const SettingsScreen(),
      _ => _ComingSoon(label: _dests[_index].label, phase: 0),
    };
  }
}

class _Dest {
  const _Dest(this.icon, this.label);
  final IconData icon;
  final String label;
}

// ─────────────────────────── Top bar ───────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onNewOrder});

  final VoidCallback onNewOrder;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sync = app.syncState;
    final lang = app.language;
    final isBn = lang.code == 'bn';

    return Container(
      height: DeskMetrics.topBar,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 4),
          // New Order
          _NewOrderButton(onPressed: onNewOrder),
          const SizedBox(width: 14),
          // Bill No search
          const SizedBox(width: 150, child: _BillSearch()),
          const Spacer(),
          // Petpooja-style utility icons (UI only)
          _barIcon(Icons.print_rounded, 'Printer', () {}),
          _barIcon(Icons.receipt_rounded, 'KOT', () {}),
          _barIcon(Icons.storefront_rounded, 'Shop', () {}),
          _barIcon(Icons.grid_view_rounded, 'Tables', () => DeskNav.of(context).goToIndex(2)),
          _barIcon(Icons.bar_chart_rounded, 'Reports', () => DeskNav.of(context).goToIndex(7)),
          const SizedBox(width: 8),
          // Sync badge
          if (sync.pendingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: PosColors.stateOccupiedLine,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '⇅ ${sync.pendingCount}',
              style: const TextStyle(
                fontSize: DeskTypography.caption,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3A2E00),
              ),
            ),
          ),
          if (sync.pendingCount > 0) const SizedBox(width: 10),
          // Connection dot
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: sync.cloudConnected
                  ? PosColors.success
                  : PosColors.stateOccupiedLine,
            ),
          ),
          const SizedBox(width: 10),
          _barIcon(Icons.notifications_none_rounded, 'Notifications', () {}),
          const SizedBox(width: 8),
          // User + Logout
          Text(
            app.accountDisplayName.isEmpty
                ? app.accountRole.label
                : app.accountDisplayName,
            style: TextStyle(
              fontSize: DeskTypography.bodySmall,
              fontWeight: FontWeight.w600,
              color: PosColors.ink2,
            ),
          ),
          const SizedBox(width: 4),
          _barIcon(Icons.power_settings_new_rounded, 'Logout', () => app.logOut()),
          const SizedBox(width: 4),
          // Language toggle
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              side: const BorderSide(color: PosColors.lineStrong),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PosRadii.sm),
              ),
            ),
            onPressed: () {
              final next = isBn ? AppLanguage.en : AppLanguage.bn;
              AppScope.read(context).updateLanguage(next);
            },
            child: Text(
              isBn ? 'EN' : 'বাংলা',
              style: const TextStyle(
                fontSize: DeskTypography.caption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barIcon(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      icon: Icon(icon, size: 22, color: PosColors.ink2),
      splashRadius: 22,
      tooltip: tooltip,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.sm),
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.add_rounded, size: 20),
      label: const Text('New Order',
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: DeskTypography.nav)),
    );
  }
}

class _BillSearch extends StatelessWidget {
  const _BillSearch();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        enabled: false,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: PosColors.muted),
          hintText: 'Bill No',
          filled: true,
          fillColor: PosColors.surfaceSunk,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm),
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
  });

  final List<_Dest> dests;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Container(
      width: DeskMetrics.railWidth,
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(right: BorderSide(color: PosColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header — hamburger + brand + outlet dropdown
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu_rounded, size: 22),
                      color: PosColors.ink2,
                      splashRadius: 20,
                      onPressed: () {},
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.point_of_sale_rounded,
                        size: 22, color: PosColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'QuickBytes',
                      style: TextStyle(
                        fontSize: DeskTypography.h1,
                        fontWeight: FontWeight.w800,
                        color: PosColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        app.restaurantName.isEmpty
                            ? 'POS Register'
                            : app.restaurantName,
                        overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: DeskTypography.bodySmall,
                        fontWeight: FontWeight.w600,
                        color: PosColors.ink2,
                      ),
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: PosColors.ink2),
                  ],
                ),
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
                    onTap: () => onSelect(i),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: PosColors.line),
          // User profile mini-card (light)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: PosColors.primary,
                    borderRadius: BorderRadius.circular(PosRadii.sm),
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 20, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.accountDisplayName.isEmpty
                            ? 'Signed in'
                            : app.accountDisplayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: DeskTypography.bodySmall,
                          fontWeight: FontWeight.w700,
                          color: PosColors.ink,
                        ),
                      ),
                      Text(
                        app.accountRole.label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: DeskTypography.eyebrow,
                          color: PosColors.muted,
                        ),
                      ),
                    ],
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

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.dest,
    required this.active,
    required this.onTap,
  });

  final _Dest dest;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = active ? PosColors.primary : PosColors.muted;
    final textColor = active ? PosColors.primary : PosColors.ink2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: active ? PosColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(PosRadii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(PosRadii.sm),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(dest.icon, size: 22, color: iconColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dest.label,
                    style: TextStyle(
                      fontSize: DeskTypography.nav,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 18,
                    color: active ? PosColors.primary : PosColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Bodies ───────────────────────────

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
              fontSize: DeskTypography.h3,
              fontWeight: FontWeight.w700,
              color: PosColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text('Arrives in Phase $phase',
              style: TextStyle(
                  fontSize: DeskTypography.bodySmall,
                  color: PosColors.muted)),
        ],
      ),
    );
  }
}
