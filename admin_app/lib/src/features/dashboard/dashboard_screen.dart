import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/enums/business_tier.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/hourly_bars_chart.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/dashboard_summary.dart';
import '../../models/menu_item.dart';
import '../../models/order_service_type.dart';
import '../../models/pos_notification.dart';
import '../desktop_pos/widgets/menu_line_customizer.dart';
import '../orders/orders_screen.dart';

// Tab indices mirroring _AppTab in app.dart.
const int _ordersTab = 0;
const int _stockTab = 3;
const int _settingsTab = 4;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.onNavigate,
    this.onNavigateToTarget,
    super.key,
  });

  final ValueChanged<int> onNavigate;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _firstLoadKicked = false;
  _DashMode _mode = _DashMode.manage;

  void _setMode(_DashMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final tier = app.businessTier;

    if (!_firstLoadKicked) {
      _firstLoadKicked = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => app.refreshDashboardSummary(),
      );
    }

    final mode = app.isManager ? _mode : _DashMode.manage;
    if (mode == _DashMode.review) {
      // Review has three variants; Simple falls back to the Standard screen.
      return switch (tier) {
        BusinessTier.simple || BusinessTier.standard => _ReviewStandard(
          app: app,
          onNavigate: widget.onNavigate,
          onNavigateToTarget: widget.onNavigateToTarget,
          mode: mode,
          onModeChanged: _setMode,
        ),
        BusinessTier.advanced => _ReviewAdvanced(
          app: app,
          onNavigate: widget.onNavigate,
          onNavigateToTarget: widget.onNavigateToTarget,
          mode: mode,
          onModeChanged: _setMode,
        ),
        BusinessTier.enterprise => _ReviewEnterprise(
          app: app,
          onNavigate: widget.onNavigate,
          onNavigateToTarget: widget.onNavigateToTarget,
          mode: mode,
          onModeChanged: _setMode,
        ),
      };
    }

    return switch (tier) {
      BusinessTier.simple => _DashT1Counter(
        app: app,
        onNavigate: widget.onNavigate,
        onNavigateToTarget: widget.onNavigateToTarget,
        mode: mode,
        onModeChanged: _setMode,
      ),
      BusinessTier.standard => _DashT2Standard(
        app: app,
        onNavigate: widget.onNavigate,
        onNavigateToTarget: widget.onNavigateToTarget,
        mode: mode,
        onModeChanged: _setMode,
      ),
      BusinessTier.advanced => _DashT3Full(
        app: app,
        onNavigate: widget.onNavigate,
        onNavigateToTarget: widget.onNavigateToTarget,
        mode: mode,
        onModeChanged: _setMode,
      ),
      BusinessTier.enterprise => _DashT4Fleet(
        app: app,
        onNavigate: widget.onNavigate,
        onNavigateToTarget: widget.onNavigateToTarget,
        mode: mode,
        onModeChanged: _setMode,
      ),
    };
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

// Uppercase micro-label in tabular mono spacing.
class _MicroLabel extends StatelessWidget {
  const _MicroLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: PosColors.mutedSoft,
      letterSpacing: 0.6,
      fontFeatures: [const FontFeature.tabularFigures()],
    ),
  );
}

// Dashboard app-bar with greeting, biz name, mode dropdown, and bells.
class _DashHeader extends StatelessWidget {
  const _DashHeader({
    required this.bizName,
    required this.onNavigateToOrders,
    required this.onNavigateToTarget,
    required this.mode,
    required this.onModeChanged,
    this.period,
  });

  final String bizName;
  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final _DashMode mode;
  final ValueChanged<_DashMode> onModeChanged;

  /// Optional period chip shown on the right of the Manage/Review switcher
  /// (e.g. "Today", "Today · Fleet"). Used by the Review screens.
  final String? period;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;
    final text = AppScope.of(context).strings;
    final greet = hour < 12
        ? text.goodMorning
        : (hour < 17 ? text.goodAfternoon : text.goodEvening);
    final dateFmt = DateFormat('EEE · h:mm a');
    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MicroLabel(dateFmt.format(now)),
        const SizedBox(height: 4),
        Text(
          bizName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: PosColors.primaryDark,
            letterSpacing: -0.3,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          greet,
          style: const TextStyle(fontSize: 12, color: PosColors.muted),
        ),
      ],
    );
    final actions = <Widget>[
      const HeaderModeButton(),
      if (AppScope.of(context).isManager)
        _ReviewTabs(mode: mode, onChanged: onModeChanged),
      HeaderNotificationBell(
        onNavigateToOrders: onNavigateToOrders,
        onNavigateToTarget: onNavigateToTarget,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final actionBar = _HeaderActionBar(actions: actions);
              if (constraints.maxWidth < 480) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [actionBar, const SizedBox(height: 10), identity],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 8),
                  Flexible(child: actionBar),
                ],
              );
            },
          ),
          if (period != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: _PeriodChip(period: period!),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderActionBar extends StatelessWidget {
  const _HeaderActionBar({required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.end,
    runAlignment: WrapAlignment.end,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 6,
    runSpacing: 6,
    children: actions,
  );
}

// Top-level dashboard view — the Manager/Owner dropdown under the header.
enum _DashMode { manage, review }

// Compact Manager | Owner dropdown + optional period chip.
class _ReviewTabs extends StatelessWidget {
  const _ReviewTabs({required this.mode, required this.onChanged});

  final _DashMode mode;
  final ValueChanged<_DashMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = mode == _DashMode.manage ? 'Manager' : 'Owner';
    return PopupMenuButton<_DashMode>(
      key: const ValueKey('dashboard-view-dropdown'),
      initialValue: mode,
      tooltip: 'Dashboard view',
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: PosColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.sm),
        side: const BorderSide(color: PosColors.line, width: 0.5),
      ),
      itemBuilder: (_) => [
        _viewItem('Manager', _DashMode.manage),
        _viewItem('Owner', _DashMode.review),
      ],
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 112),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.sm),
            border: Border.all(color: PosColors.line, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: PosColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: PosColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_DashMode> _viewItem(String label, _DashMode value) {
    final selected = mode == value;
    return PopupMenuItem<_DashMode>(
      value: value,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: PosColors.primaryDark,
              ),
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_rounded,
              size: 18,
              color: PosColors.primaryDark,
            ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.period});

  final String period;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.sm),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: PosColors.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          period,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: PosColors.primaryDark,
          ),
        ),
        const Icon(Icons.keyboard_arrow_down, size: 14, color: PosColors.muted),
      ],
    ),
  );
}

// Section label + optional count badge + optional action.
class _SecHead extends StatelessWidget {
  const _SecHead({
    required this.en,
    this.bn,
    this.count,
    this.action,
    this.actionBn,
  });
  final String en;
  final String? bn;
  final int? count;
  final String? action;
  final String? actionBn;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
    child: Row(
      children: [
        Text(
          tfPick(context, en: en, bn: bn),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PosColors.primaryDark,
            letterSpacing: -0.1,
          ),
        ),
        const Spacer(),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: PosColors.urgent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        if (action != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tfPick(context, en: action!, bn: actionBn),
                style: const TextStyle(
                  fontSize: 12,
                  color: PosColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.chevron_right, size: 14, color: PosColors.muted),
            ],
          ),
      ],
    ),
  );
}

// Compact KPI strip — N cells in a row, divided by hairlines.
class _KpiStrip extends StatelessWidget {
  const _KpiStrip({required this.stats});
  final List<_KpiStat> stats;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (int i = 0; i < stats.length; i++) ...[
            if (i > 0) Container(width: 0.5, color: PosColors.line),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MicroLabel(stats[i].label),
                    const SizedBox(height: 8),
                    Text(
                      stats[i].value,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: stats[i].color ?? PosColors.primaryDark,
                        letterSpacing: -0.4,
                        height: 1.0,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _KpiStat {
  const _KpiStat(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;
}

// Alert / "Needs you" row card.
class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.tag,
    required this.tone,
    required this.title,
    this.sub,
    this.cta,
    this.onCta,
  });

  final String tag;
  final _AlertTone tone;
  final String title;
  final String? sub;
  final String? cta;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      _AlertTone.late => PosColors.urgentSoft,
      _AlertTone.low => PosColors.warningSoft,
      _AlertTone.danger => PosColors.dangerSoft,
      _AlertTone.info => PosColors.surfaceSunk,
    };
    final fg = switch (tone) {
      _AlertTone.late => PosColors.urgent,
      _AlertTone.low => PosColors.warning,
      _AlertTone.danger => PosColors.danger,
      _AlertTone.info => PosColors.muted,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(PosRadii.xs),
              ),
              child: Text(
                tag,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: fg,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PosColors.primaryDark,
                      height: 1.3,
                    ),
                  ),
                  if (sub != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      sub!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: PosColors.muted,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (cta != null) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onCta,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: PosColors.primaryDark,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    cta!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _AlertTone { late, low, danger, info }

// Close-day card.
class _CloseCard extends StatelessWidget {
  const _CloseCard({required this.title, this.kicker, this.warn});
  final String title;
  final String? kicker;
  final String? warn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
      boxShadow: PosShadows.soft,
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kicker != null) _MicroLabel(kicker!),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PosColors.primaryDark,
                  letterSpacing: -0.2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (warn != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: PosColors.mutedSoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        warn!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PosColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: PosColors.surfaceSunk,
            borderRadius: BorderRadius.circular(PosRadii.sm),
            border: Border.all(color: PosColors.line, width: 0.5),
          ),
          child: const Icon(
            Icons.arrow_forward,
            size: 18,
            color: PosColors.primaryDark,
          ),
        ),
      ],
    ),
  );
}

// Quick-action tile grid.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});
  final List<_QAction> actions;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (int i = 0; i < actions.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: actions[i].onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadii.sm),
                border: Border.all(color: PosColors.line, width: 0.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: PosColors.surfaceSunk,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      actions[i].icon,
                      size: 18,
                      color: PosColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    actions[i].label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PosColors.primaryDark,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class _QAction {
  const _QAction({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
}

// ─────────────────────────────────────────────────────────────────────────────
// MANAGE MODE — JSX reference implementation translated to Flutter.
// ─────────────────────────────────────────────────────────────────────────────

class _ManageChrome {
  const _ManageChrome({
    required this.summary,
    required this.modeLabel,
    required this.drawerLabel,
    required this.drawerValue,
    required this.openCount,
    required this.inFlightValue,
    required this.lateCount,
  });

  final DashboardSummary? summary;
  final String modeLabel;
  final String drawerLabel;
  final String drawerValue;
  final int openCount;
  final String inFlightValue;
  final int lateCount;
}

mixin _ManageCartState<T extends StatefulWidget> on State<T> {
  final List<DesktopMenuLineSelection> _cartLines = [];
  bool _creatingOrder = false;

  dynamic get app;

  Future<void> _increment(MenuItem item) async {
    final selections = desktopMenuNeedsCustomization(item)
        ? await showDesktopMenuLineCustomizerLines(
            context,
            item: item,
            isBn: AppScope.of(context).strings.isBn,
          )
        : [desktopRegularMenuLine(item)];
    if (selections == null || selections.isEmpty || !mounted) return;
    setState(() {
      for (final selection in selections) {
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

  Future<void> _incrementByName(String itemName) async {
    final match = (app.menuItems as List<MenuItem>).where((item) {
      return item.isAvailable && item.name == itemName;
    }).toList();
    if (match.isEmpty) return;
    await _increment(match.first);
  }

  Future<void> _createOrder() async {
    if (_cartLines.isEmpty || _creatingOrder) return;
    setState(() => _creatingOrder = true);
    try {
      final order = await app.createManualOrder(
        requestedItems: [for (final line in _cartLines) line.toRequestItem()],
        serviceType: OrderServiceType.takeaway,
        paymentMethod: null,
      );
      final shouldPrint =
          app.orderPrinterSideEffectsEnabled &&
          app.isManager &&
          !app.printerState.autoPrintEnabled &&
          app.printerState.hasSelectedPrinter &&
          !app.printerService.hasPrintedOrder(order.id);
      if (shouldPrint) await app.printOrderTicket(order);
      if (!mounted) return;
      setState(_cartLines.clear);
      await openOrderCreatedPage(context, order: order);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tfPick(
              context,
              en: 'Could not create order: $error',
              bn: 'অর্ডার তৈরি করা যায়নি: $error',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _creatingOrder = false);
    }
  }

  Widget? _cartTray() {
    if (_cartLines.isEmpty) return null;
    final cartQty = _cartLines.fold<int>(0, (sum, line) => sum + line.qty);
    final cartTotal = _cartLines.fold<double>(
      0,
      (sum, line) => sum + line.lineTotal,
    );
    return SafeArea(
      top: false,
      child: TfCreateOrderTray(
        key: const ValueKey('ring-it-up-cart'),
        count: cartQty,
        total: _bdt(cartTotal),
        busy: _creatingOrder,
        onTap: _createOrder,
      ),
    );
  }

  Map<String, int> get _cartQtyByItemId {
    final qtyByItemId = <String, int>{};
    for (final line in _cartLines) {
      qtyByItemId[line.item.id] = (qtyByItemId[line.item.id] ?? 0) + line.qty;
    }
    return qtyByItemId;
  }
}

class _DashT1Counter extends StatefulWidget {
  const _DashT1Counter({
    required this.app,
    required this.onNavigate,
    this.onNavigateToTarget,
    required this.mode,
    required this.onModeChanged,
  });

  final dynamic app;
  final ValueChanged<int> onNavigate;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final _DashMode mode;
  final ValueChanged<_DashMode> onModeChanged;

  @override
  State<_DashT1Counter> createState() => _DashT1CounterState();
}

class _DashT1CounterState extends State<_DashT1Counter>
    with _ManageCartState<_DashT1Counter> {
  @override
  dynamic get app => widget.app;

  @override
  Widget build(BuildContext context) {
    final chrome = _manageChrome(context, app, BusinessTier.simple);
    return _manageScaffold(
      app: app,
      bottomNavigationBar: _cartTray(),
      onCreateOrder: () => openNewOrderForm(context),
      onRefresh: () => app.refreshDashboardSummary(),
      children: [
        _manageTopBar(
          context,
          app: app,
          tier: BusinessTier.simple,
          chrome: chrome,
          mode: widget.mode,
          onModeChanged: widget.onModeChanged,
          onNavigateToOrders: () => widget.onNavigate(_ordersTab),
          onNavigateToTarget: widget.onNavigateToTarget,
        ),
        ..._ringupSections(
          onEdit: () =>
              unawaited(_openQuickSellEditor(context, app, chrome.summary)),
        ),
        _totalsAndPeak(
          summary: chrome.summary,
          amount: chrome.drawerValue,
          orders: chrome.summary?.moneyFirst.kpis.orders ?? 0,
          top: _topMoverLabel(chrome.summary),
        ),
        _section(
          top: 22,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SecHead(
                en: 'Open takeaway',
                bn: 'খোলা টেকঅ্যাওয়ে',
                count: chrome.openCount,
              ),
              _OpenTicketList(
                count: chrome.openCount,
                total: chrome.inFlightValue,
              ),
            ],
          ),
        ),
        _closeSection(
          title: 'Close counter',
          kicker: 'End of day',
          warn: chrome.openCount > 0
              ? '$chrome.openCount tickets still open - settle before close'
              : null,
        ),
      ],
    );
  }

  List<Widget> _ringupSections({required VoidCallback onEdit}) {
    final topItems = _topSellerItems(
      app,
      app.dashboardSummary as DashboardSummary?,
    );
    return [
      _section(
        top: 12,
        child: _TopSellerGrid(
          items: topItems,
          qtyByItemId: _cartQtyByItemId,
          onTap: (item) => unawaited(_increment(item)),
          onEdit: onEdit,
        ),
      ),
    ];
  }
}

class _DashT2Standard extends StatefulWidget {
  const _DashT2Standard({
    required this.app,
    required this.onNavigate,
    this.onNavigateToTarget,
    required this.mode,
    required this.onModeChanged,
  });

  final dynamic app;
  final ValueChanged<int> onNavigate;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final _DashMode mode;
  final ValueChanged<_DashMode> onModeChanged;

  @override
  State<_DashT2Standard> createState() => _DashT2StandardState();
}

class _DashT2StandardState extends State<_DashT2Standard>
    with _ManageCartState<_DashT2Standard> {
  @override
  dynamic get app => widget.app;

  @override
  Widget build(BuildContext context) {
    final chrome = _manageChrome(context, app, BusinessTier.standard);
    final summary = chrome.summary;
    final alerts = summary?.rightNow.needsAttention ?? const [];
    return _manageScaffold(
      app: app,
      bottomNavigationBar: _cartTray(),
      onCreateOrder: () => openNewOrderForm(context),
      onRefresh: () => app.refreshDashboardSummary(),
      children: [
        _manageTopBar(
          context,
          app: app,
          tier: BusinessTier.standard,
          chrome: chrome,
          mode: widget.mode,
          onModeChanged: widget.onModeChanged,
          onNavigateToOrders: () => widget.onNavigate(_ordersTab),
          onNavigateToTarget: widget.onNavigateToTarget,
        ),
        ..._ringupBlocks(
          app: app,
          summary: summary,
          qtyByItemId: _cartQtyByItemId,
          onItemTap: (item) => unawaited(_increment(item)),
          onRecentTap: (name) => unawaited(_incrementByName(name)),
          onEdit: () => unawaited(_openQuickSellEditor(context, app, summary)),
        ),
        _totalsAndPeak(
          summary: summary,
          amount: chrome.drawerValue,
          orders: summary?.moneyFirst.kpis.orders ?? 0,
          top: _topMoverLabel(summary),
        ),
        _floorSection(summary, targetTables: 6, cols: 3),
        if (alerts.isNotEmpty)
          _needsYouSection(alerts, widget.onNavigate, count: alerts.length),
        _closeSection(
          title: 'Close day',
          kicker: 'End of day',
          warn: chrome.openCount > 0
              ? '$chrome.openCount orders still open - settle before closing'
              : null,
        ),
      ],
    );
  }
}

class _DashT3Full extends StatefulWidget {
  const _DashT3Full({
    required this.app,
    required this.onNavigate,
    this.onNavigateToTarget,
    required this.mode,
    required this.onModeChanged,
  });

  final dynamic app;
  final ValueChanged<int> onNavigate;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final _DashMode mode;
  final ValueChanged<_DashMode> onModeChanged;

  @override
  State<_DashT3Full> createState() => _DashT3FullState();
}

class _DashT3FullState extends State<_DashT3Full>
    with _ManageCartState<_DashT3Full> {
  @override
  dynamic get app => widget.app;

  @override
  Widget build(BuildContext context) {
    final chrome = _manageChrome(context, app, BusinessTier.advanced);
    final summary = chrome.summary;
    final alerts = summary?.rightNow.needsAttention ?? const [];
    return _manageScaffold(
      app: app,
      bottomNavigationBar: _cartTray(),
      onCreateOrder: () => openNewOrderForm(context),
      onRefresh: () => app.refreshDashboardSummary(),
      children: [
        _manageTopBar(
          context,
          app: app,
          tier: BusinessTier.advanced,
          chrome: chrome,
          mode: widget.mode,
          onModeChanged: widget.onModeChanged,
          onNavigateToOrders: () => widget.onNavigate(_ordersTab),
          onNavigateToTarget: widget.onNavigateToTarget,
        ),
        ..._ringupBlocks(
          app: app,
          summary: summary,
          qtyByItemId: _cartQtyByItemId,
          onItemTap: (item) => unawaited(_increment(item)),
          onRecentTap: (name) => unawaited(_incrementByName(name)),
          onEdit: () => unawaited(_openQuickSellEditor(context, app, summary)),
        ),
        _totalsAndPeak(
          summary: summary,
          amount: chrome.drawerValue,
          orders: summary?.moneyFirst.kpis.orders ?? 0,
          top: _topMoverLabel(summary),
        ),
        _section(
          top: 14,
          child: _KpiStrip(
            stats: [
              _KpiStat(
                'Pending orders',
                '${summary?.moneyFirst.kpis.openOrders ?? 0}',
              ),
              _KpiStat(
                'Booked tables',
                '${summary?.rightNow.tablesSeated ?? 0}',
              ),
              _KpiStat(
                'Late orders',
                '${summary?.rightNow.lateOrders ?? 0}',
                color: (summary?.rightNow.lateOrders ?? 0) > 0
                    ? PosColors.urgent
                    : null,
              ),
            ],
          ),
        ),
        _floorSection(summary, targetTables: 12, cols: 4),
        if (alerts.isNotEmpty)
          _needsYouSection(alerts, widget.onNavigate, count: alerts.length),
        _section(
          top: 14,
          child: _QuickActions(
            actions: [
              _QAction(
                icon: Icons.print_outlined,
                label: tfPick(context, en: 'Print KOT', bn: 'KOT প্রিন্ট'),
                onTap: () => widget.onNavigate(_ordersTab),
              ),
              _QAction(
                icon: Icons.receipt_long_outlined,
                label: tfPick(context, en: 'Print bill', bn: 'বিল প্রিন্ট'),
                onTap: () => widget.onNavigate(_ordersTab),
              ),
              _QAction(
                icon: Icons.notifications_outlined,
                label: tfPick(context, en: 'Call waiter', bn: 'ওয়েটার ডাকুন'),
              ),
              _QAction(
                icon: Icons.bar_chart_outlined,
                label: tfPick(context, en: 'Reports', bn: 'রিপোর্ট'),
                onTap: () => widget.onNavigate(_settingsTab),
              ),
            ],
          ),
        ),
        _closeSection(
          title: 'Hand over to night shift',
          kicker: 'Shift handover',
          warn: chrome.openCount > 0
              ? '$chrome.openCount open orders will carry over'
              : null,
        ),
      ],
    );
  }
}

class _DashT4Fleet extends StatefulWidget {
  const _DashT4Fleet({
    required this.app,
    required this.onNavigate,
    this.onNavigateToTarget,
    required this.mode,
    required this.onModeChanged,
  });

  final dynamic app;
  final ValueChanged<int> onNavigate;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final _DashMode mode;
  final ValueChanged<_DashMode> onModeChanged;

  @override
  State<_DashT4Fleet> createState() => _DashT4FleetState();
}

class _DashT4FleetState extends State<_DashT4Fleet> {
  String _period = 'Today';

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final text = app.strings as AppStrings;
    final summary = app.dashboardSummary as DashboardSummary?;
    final chrome = _manageChrome(context, app, BusinessTier.enterprise);
    final fleet = summary?.review?.fleet;
    final fleetKpis = fleet?.kpis;
    final moneyFmt = NumberFormat('#,##0', 'en');
    final fleetRevenue = fleetKpis?.revBdt ?? 0;
    final earned = fleetRevenue > 0
        ? fleetRevenue
        : (summary?.moneyFirst.earnedToday ?? 0.0);
    final earnedStr = _bdt(earned);
    final goal = fleet?.goal;
    final goalTarget = goal?.targetBdt ?? 0;
    final goalRemaining = goal?.remainingBdt ?? 0;
    final goalPct = goal?.progressPct ?? 0;
    final deltaValue = _bdt(
      (fleetKpis?.revBdt ?? earned) * ((fleetKpis?.deltaPct ?? 0) / 100),
    );
    final now = DateTime.now();

    return _manageScaffold(
      app: app,
      onCreateOrder:
          (app.menuItems as List<MenuItem>).any((item) => item.isAvailable)
          ? () => openNewOrderForm(context)
          : null,
      onRefresh: () => app.refreshDashboardSummary(),
      children: [
        _manageTopBar(
          context,
          app: app,
          tier: BusinessTier.enterprise,
          chrome: chrome,
          mode: widget.mode,
          onModeChanged: widget.onModeChanged,
          onNavigateToOrders: () => widget.onNavigate(_ordersTab),
          onNavigateToTarget: widget.onNavigateToTarget,
        ),
        _section(
          top: 10,
          child: Column(
            children: [
              TfPeriodSelector(
                value: _period,
                onChanged: (value) => setState(() => _period = value),
              ),
              TfPeriodSubtitle(
                range:
                    '${DateFormat('EEE · d MMM').format(now)} · 9 AM - ${DateFormat('h:mm a').format(now)}',
                compare: 'prev ${DateFormat('EEE').format(now)}',
              ),
            ],
          ),
        ),
        _section(
          top: 14,
          child: _GoalCard(
            amount: earnedStr,
            label: 'Fleet revenue · today',
            bn: 'আজকের সব আউটলেটের আয়',
            sub: goalRemaining > 0
                ? '${_bdt(goalRemaining)} to goal · pace +${(fleetKpis?.deltaPct ?? 0).round()}%'
                : tfPick(
                    context,
                    en: 'Across all outlets',
                    bn: 'সব আউটলেট মিলিয়ে',
                  ),
            pct: goalPct,
            goal: _bdt(goalTarget),
          ),
        ),
        _section(
          top: 10,
          child: _DeltaCard(
            value: deltaValue,
            pct: '${(fleetKpis?.deltaPct ?? 0).round()}%',
            down: fleetKpis?.deltaUp == false,
            note:
                '${fleetKpis?.onGoalCount ?? 0} of ${fleetKpis?.outletCount ?? 0} outlets ahead of pace',
          ),
        ),
        _section(
          top: 14,
          child: _KpiStrip(
            stats: [
              _KpiStat(
                text.isBn ? 'অতিথি' : 'Covers',
                '${fleetKpis?.covers ?? 0}',
              ),
              _KpiStat(
                text.isBn ? 'গড় বিল' : 'Avg ticket',
                '৳${moneyFmt.format(fleetKpis?.avgTicketBdt ?? 0)}',
              ),
              _KpiStat(
                text.isBn ? 'সব আউটলেটে দেরি' : 'Fleet late',
                '${fleetKpis?.fleetLatePct ?? 0}%',
                color: (fleetKpis?.fleetLatePct ?? 0) > 0
                    ? PosColors.urgent
                    : null,
              ),
            ],
          ),
        ),
        if (fleet?.alerts.isNotEmpty == true)
          _section(
            top: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SecHead(
                  en: 'Needs you',
                  bn: 'নজর দিন',
                  count: fleet!.alerts.length,
                ),
                for (final a in fleet.alerts)
                  _AlertRow(
                    tag: a.kind.toUpperCase(),
                    tone: a.kind == 'low'
                        ? _AlertTone.low
                        : (a.kind == 'danger'
                              ? _AlertTone.danger
                              : _AlertTone.late),
                    title: a.title,
                    sub: a.body,
                    cta: tfPick(context, en: 'View', bn: 'দেখুন'),
                    onCta: () => widget.onNavigate(_ordersTab),
                  ),
              ],
            ),
          ),
        _section(
          top: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SecHead(
                en: 'Outlets · today',
                bn: 'আউটলেট',
                action: 'Ranked',
              ),
              for (final outlet in fleet?.outlets ?? const <FleetOutlet>[])
                _OutletCard(
                  name: outlet.name.isEmpty
                      ? 'Outlet ${outlet.rank}'
                      : outlet.name,
                  area: outlet.area,
                  rev: _bdt(outlet.revBdt),
                  deltaUp: outlet.deltaUp,
                  delta: '${outlet.deltaPct.round()}%',
                  occ: '${outlet.occupancyPct}%',
                  late: outlet.latePct == 0 ? '—' : '${outlet.latePct}%',
                  isTop: outlet.rank == 1,
                ),
              if ((fleet?.outlets ?? const <FleetOutlet>[]).isEmpty)
                _FleetNote(
                  title: 'No outlet sales yet',
                  body: 'Fleet rows will appear once outlet sales sync.',
                ),
            ],
          ),
        ),
        if (fleet?.staffingSuggestion.outletName.isNotEmpty == true)
          _section(
            top: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SecHead(en: 'Staffing', bn: 'স্টাফ', action: 'Schedule'),
                _FleetNote(
                  title:
                      'Peak ${fleet!.staffingSuggestion.peakLabel} · add cover at ${fleet.staffingSuggestion.outletName}',
                  body:
                      'Revenue-by-hour suggests watching the next service peak.',
                ),
              ],
            ),
          ),
        _section(
          top: 14,
          child: _CloseCard(
            title: tfPick(
              context,
              en: 'Fleet day-end · ${fleetKpis?.outletCount ?? 0} outlets',
              bn: 'ফ্লিট দিন শেষ',
            ),
            kicker: tfPick(
              context,
              en: 'Roll up the group',
              bn: 'সমগ্র হিসাব প্রস্তুত করুন',
            ),
            warn: fleet?.openOutlets.isNotEmpty == true
                ? '${fleet!.openOutlets.length} outlets still open'
                : null,
          ),
        ),
      ],
    );
  }
}

_ManageChrome _manageChrome(
  BuildContext context,
  dynamic app,
  BusinessTier tier,
) {
  final summary = app.dashboardSummary as DashboardSummary?;
  final money = summary?.moneyFirst;
  final right = summary?.rightNow;
  final fleet = summary?.review?.fleet;
  final drawerAmount = tier == BusinessTier.enterprise
      ? ((fleet?.kpis.revBdt ?? 0) > 0
            ? fleet!.kpis.revBdt
            : (money?.earnedToday ?? 0))
      : (money?.earnedToday ?? 0);
  final openCount = tier == BusinessTier.enterprise
      ? (money?.kpis.openOrders ?? 0)
      : (money?.kpis.openOrders ?? 0);
  final avgTicket = money?.kpis.avgTicket ?? 0;
  final inFlight = avgTicket > 0 ? openCount * avgTicket : 0;
  final lateCount = tier == BusinessTier.enterprise
      ? (fleet?.alerts.where((alert) => alert.kind != 'low').length ?? 0)
      : (right?.lateOrders ?? 0);
  return _ManageChrome(
    summary: summary,
    modeLabel: switch (tier) {
      BusinessTier.simple => 'Food cart',
      BusinessTier.standard => 'Cafe',
      BusinessTier.advanced => 'Restaurant',
      BusinessTier.enterprise =>
        'Fleet · ${fleet?.kpis.outletCount == 0 ? 5 : fleet?.kpis.outletCount ?? 5} outlets',
    },
    drawerLabel: tier == BusinessTier.enterprise ? 'Fleet drawer' : 'Drawer',
    drawerValue: _bdt(drawerAmount),
    openCount: openCount,
    inFlightValue: _bdt(inFlight),
    lateCount: lateCount,
  );
}

Widget _manageScaffold({
  required dynamic app,
  required Future<void> Function() onRefresh,
  required List<Widget> children,
  Widget? bottomNavigationBar,
  VoidCallback? onCreateOrder,
}) {
  final canCreateOrder =
      onCreateOrder != null &&
      (app.menuItems as List<MenuItem>).any((item) => item.isAvailable);
  return Scaffold(
    backgroundColor: PosColors.background,
    bottomNavigationBar: bottomNavigationBar,
    floatingActionButton: canCreateOrder
        ? TfFab(tooltip: 'New order', onPressed: onCreateOrder)
        : null,
    body: SafeArea(
      child: RefreshIndicator(
        color: PosColors.primaryDark,
        backgroundColor: PosColors.primary,
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 112),
          children: children,
        ),
      ),
    ),
  );
}

Widget _manageTopBar(
  BuildContext context, {
  required dynamic app,
  required BusinessTier tier,
  required _ManageChrome chrome,
  required _DashMode mode,
  required ValueChanged<_DashMode> onModeChanged,
  required VoidCallback onNavigateToOrders,
  required ValueChanged<PosNotificationTarget>? onNavigateToTarget,
}) {
  final subtitle = _outletTitle(
    app,
    enterprise: tier == BusinessTier.enterprise,
  );
  final actions = <Widget>[
    const HeaderModeButton(),
    HeaderNotificationBell(
      onNavigateToOrders: onNavigateToOrders,
      onNavigateToTarget: onNavigateToTarget,
    ),
  ];
  final roleToggle = app.isManager && tier != BusinessTier.simple
      ? TfCompactRoleToggle(
          key: const ValueKey('dashboard-view-dropdown'),
          role: mode == _DashMode.manage ? 'manager' : 'owner',
          onChanged: (role) => onModeChanged(
            role == 'owner' ? _DashMode.review : _DashMode.manage,
          ),
        )
      : null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TfUnifiedTopNav(
        title: tfPick(context, en: 'Dashboard', bn: 'ড্যাশবোর্ড'),
        subtitle: subtitle,
        trailing: actions,
        below: roleToggle,
      ),
      TfOpenTicketsBar(
        count: chrome.openCount,
        total: chrome.inFlightValue,
        late: chrome.lateCount,
      ),
    ],
  );
}

String _outletTitle(dynamic app, {bool enterprise = false}) {
  final restaurant =
      (app.serverConfig?.restaurantName as String?)?.trim() ?? '';
  final outlet = (app.serverConfig?.outletName as String?)?.trim() ?? '';
  if (enterprise) {
    if (restaurant.isEmpty) return 'Fleet';
    return restaurant.endsWith('Group') ? restaurant : '$restaurant Group';
  }
  if (restaurant.isEmpty && outlet.isEmpty) return 'My Restaurant';
  if (outlet.isEmpty) return restaurant;
  if (restaurant.isEmpty) return outlet;
  return '$restaurant · $outlet';
}

Widget _section({required double top, required Widget child}) {
  return Padding(padding: EdgeInsets.fromLTRB(16, top, 16, 0), child: child);
}

List<Widget> _ringupBlocks({
  required dynamic app,
  required DashboardSummary? summary,
  required Map<String, int> qtyByItemId,
  required ValueChanged<MenuItem> onItemTap,
  required ValueChanged<String> onRecentTap,
  required VoidCallback onEdit,
}) {
  return [
    _section(
      top: 12,
      child: _TopSellerGrid(
        items: _topSellerItems(app, summary),
        qtyByItemId: qtyByItemId,
        onTap: onItemTap,
        onEdit: onEdit,
      ),
    ),
  ];
}

List<MenuItem> _topSellerItems(dynamic app, DashboardSummary? summary) {
  final available = (app.menuItems as List<MenuItem>)
      .where((item) => item.isAvailable)
      .toList(growable: false);
  if (available.isEmpty) return const [];
  final byId = {for (final item in available) item.id: item};
  final ordered = <MenuItem>[];
  for (final id
      in (app.quickSellMenuItemIds as List<String>?) ?? const <String>[]) {
    final item = byId[id];
    if (item != null && !ordered.contains(item)) ordered.add(item);
  }
  for (final mover in summary?.moneyFirst.topMovers ?? const <TopMover>[]) {
    final item = byId[mover.menuItemId];
    if (item != null && !ordered.contains(item)) ordered.add(item);
  }
  for (final item in available) {
    if (ordered.length >= 12) break;
    if (!ordered.contains(item)) ordered.add(item);
  }
  return ordered.take(12).toList(growable: false);
}

class _TopSellerGrid extends StatelessWidget {
  const _TopSellerGrid({
    required this.items,
    required this.qtyByItemId,
    required this.onTap,
    required this.onEdit,
  });

  final List<MenuItem> items;
  final Map<String, int> qtyByItemId;
  final ValueChanged<MenuItem> onTap;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.md),
          border: Border.all(color: PosColors.line, width: 0.5),
        ),
        child: const Center(
          child: Text('No items yet', style: TextStyle(color: PosColors.muted)),
        ),
      );
    }
    return TfFohCounter(
      title: 'Quick sell · tap to ring up',
      action: 'Edit',
      onAction: onEdit,
      cols: 4,
      tiles: [
        for (final item in items)
          TfFohTile(
            key: ValueKey('ring-it-up-${item.name}'),
            name: item.name,
            price: _bdt(item.price),
            category: _tileCategory(item),
            glyph: _tileGlyph(item),
            imageUrl: item.imageUrl,
            iconKey: resolveMenuIconKey(
              iconKey: item.extras.iconKey,
              name: item.name,
              category: item.category,
            ),
            tint: _tileTint(item),
            qty: qtyByItemId[item.id] ?? 0,
            onTap: () => onTap(item),
          ),
      ],
    );
  }
}

Future<void> _openQuickSellEditor(
  BuildContext context,
  dynamic app,
  DashboardSummary? summary,
) async {
  final stored =
      (app.quickSellMenuItemIds as List<String>?) ?? const <String>[];
  final initialIds = stored.isNotEmpty
      ? stored
      : _topSellerItems(app, summary).map((item) => item.id).toList();
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _QuickSellEditorPage(initialIds: initialIds),
    ),
  );
}

class _QuickSellEditorPage extends StatefulWidget {
  const _QuickSellEditorPage({required this.initialIds});

  final List<String> initialIds;

  @override
  State<_QuickSellEditorPage> createState() => _QuickSellEditorPageState();
}

class _QuickSellEditorPageState extends State<_QuickSellEditorPage> {
  late final List<String> _ids;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ids = [...widget.initialIds.take(12)];
  }

  void _toggle(MenuItem item) {
    setState(() {
      if (_ids.contains(item.id)) {
        _ids.remove(item.id);
      } else if (_ids.length < 12) {
        _ids.add(item.id);
      }
    });
  }

  void _move(String id, int delta) {
    final index = _ids.indexOf(id);
    if (index < 0) return;
    final next = (index + delta).clamp(0, _ids.length - 1);
    if (next == index) return;
    setState(() {
      final moved = _ids.removeAt(index);
      _ids.insert(next, moved);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await AppScope.of(context).updateQuickSellMenuItemIds(_ids);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.menuItems
        .where((item) => item.isAvailable)
        .toList(growable: false);
    final byId = {for (final item in items) item.id: item};
    final selected = [
      for (final id in _ids)
        if (byId[id] != null) byId[id]!,
    ];
    final remaining = [
      for (final item in items)
        if (!_ids.contains(item.id)) item,
    ];
    final canAddMore = _ids.length < 12;

    return Scaffold(
      key: const ValueKey('quick-sell-editor-page'),
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          children: [
            TfAppBar(
              title: 'Edit quick sell',
              subtitle: '${_ids.length}/12 local counter tiles',
              leading: TfIconButton(
                icon: TfNavIcon.back,
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                children: [
                  _QuickSellEditorHeading(
                    title: 'Selected tiles',
                    trailing: selected.isEmpty
                        ? 'Pick items below'
                        : 'Drag by taps',
                  ),
                  const SizedBox(height: 8),
                  if (selected.isEmpty)
                    const _QuickSellEmpty()
                  else
                    for (final item in selected)
                      _QuickSellSelectedRow(
                        item: item,
                        index: _ids.indexOf(item.id),
                        total: selected.length,
                        onMoveUp: () => _move(item.id, -1),
                        onMoveDown: () => _move(item.id, 1),
                        onRemove: () => _toggle(item),
                      ),
                  const SizedBox(height: 18),
                  _QuickSellEditorHeading(
                    title: 'Menu items',
                    trailing: canAddMore ? 'Tap to add' : 'Limit reached',
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisExtent: 76,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: remaining.length,
                    itemBuilder: (_, i) {
                      final item = remaining[i];
                      return _QuickSellChoiceTile(
                        item: item,
                        enabled: canAddMore,
                        onTap: () => _toggle(item),
                      );
                    },
                  ),
                ],
              ),
            ),
            TfStickyCTA(
              child: TfButton(
                label: 'Save quick sell',
                icon: Icons.check_rounded,
                busy: _saving,
                size: TfButtonSize.lg,
                onPressed: _saving ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSellEditorHeading extends StatelessWidget {
  const _QuickSellEditorHeading({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            color: PosColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      Text(
        trailing,
        style: const TextStyle(
          color: PosColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _QuickSellEmpty extends StatelessWidget {
  const _QuickSellEmpty();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: const Text(
      'No quick-sell items selected yet.',
      style: TextStyle(color: PosColors.muted, fontWeight: FontWeight.w600),
    ),
  );
}

class _QuickSellSelectedRow extends StatelessWidget {
  const _QuickSellSelectedRow({
    required this.item,
    required this.index,
    required this.total,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
  });

  final MenuItem item;
  final int index;
  final int total;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: Row(
      children: [
        _QuickSellMenuImage(item: item, size: 42),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PosColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _bdt(item.price),
                style: const TextStyle(
                  color: PosColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        TfIconButton(
          icon: Icons.keyboard_arrow_up_rounded,
          tooltip: 'Move up',
          onPressed: index <= 0 ? null : onMoveUp,
        ),
        TfIconButton(
          icon: Icons.keyboard_arrow_down_rounded,
          tooltip: 'Move down',
          onPressed: index >= total - 1 ? null : onMoveDown,
        ),
        TfIconButton(
          icon: Icons.close_rounded,
          tooltip: 'Remove',
          onPressed: onRemove,
        ),
      ],
    ),
  );
}

class _QuickSellChoiceTile extends StatelessWidget {
  const _QuickSellChoiceTile({
    required this.item,
    required this.enabled,
    required this.onTap,
  });

  final MenuItem item;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1 : 0.45,
    child: Material(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PosColors.line, width: 0.5),
          ),
          child: Row(
            children: [
              _QuickSellMenuImage(item: item, size: 42),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PosColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _bdt(item.price),
                      style: const TextStyle(
                        color: PosColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: PosColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _QuickSellMenuImage extends StatelessWidget {
  const _QuickSellMenuImage({required this.item, required this.size});

  final MenuItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final key = resolveMenuIconKey(
      iconKey: item.extras.iconKey,
      name: item.name,
      category: item.category,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(9),
      child: SizedBox(
        width: size,
        height: size,
        child: MenuImageView(
          imageUrl: item.imageUrl,
          iconKey: key,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

String _tileCategory(MenuItem item) {
  final category = item.categoryEn.trim().isNotEmpty
      ? item.categoryEn.trim()
      : item.category.trim();
  if (category.isEmpty) return 'Item';
  final words = category.split(RegExp(r'\s+'));
  return words.length > 2 ? words.take(2).join(' ') : category;
}

IconData _tileGlyph(MenuItem item) {
  final text = '${item.name} ${item.category}'.toLowerCase();
  if (text.contains('coffee') || text.contains('tea')) {
    return Icons.local_cafe_outlined;
  }
  if (text.contains('drink') ||
      text.contains('juice') ||
      text.contains('lassi') ||
      text.contains('borhani') ||
      text.contains('water')) {
    return Icons.local_drink_outlined;
  }
  if (text.contains('bread') ||
      text.contains('naan') ||
      text.contains('toast') ||
      text.contains('paratha')) {
    return Icons.bakery_dining_outlined;
  }
  if (text.contains('dessert') || text.contains('sweet')) {
    return Icons.cake_outlined;
  }
  if (text.contains('rice') ||
      text.contains('biryani') ||
      text.contains('tehari')) {
    return Icons.rice_bowl_outlined;
  }
  if (text.contains('side') || text.contains('salad')) {
    return Icons.eco_outlined;
  }
  return Icons.restaurant_outlined;
}

Color _tileTint(MenuItem item) {
  final text = '${item.name} ${item.category}'.toLowerCase();
  if (text.contains('drink') ||
      text.contains('juice') ||
      text.contains('salad')) {
    return PosColors.success;
  }
  if (text.contains('bread') ||
      text.contains('toast') ||
      text.contains('naan') ||
      text.contains('lassi')) {
    return PosColors.warning;
  }
  if (text.contains('grill') ||
      text.contains('curry') ||
      text.contains('biryani') ||
      text.contains('tehari')) {
    return PosColors.urgent;
  }
  return PosColors.inkSoft;
}

Widget _floorSection(
  DashboardSummary? summary, {
  required int targetTables,
  required int cols,
}) {
  final tables = _floorTables(summary, targetTables);
  if (tables.isEmpty) return const SizedBox.shrink();
  final busy = tables.where((table) => table.state != 'idle').length;
  return _section(
    top: 22,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SecHead(
          en: 'Floor',
          bn: 'টেবিল',
          action: '$busy of ${tables.length} busy',
        ),
        _FloorMap(tables: tables, cols: cols),
      ],
    ),
  );
}

List<FloorTable> _floorTables(DashboardSummary? summary, int targetTables) {
  final right = summary?.rightNow;
  final existing = right?.floorTables ?? const <FloorTable>[];
  final count = [
    targetTables,
    right?.tablesTotal ?? 0,
    existing.length,
  ].reduce((a, b) => a > b ? a : b);
  final byNo = {for (final table in existing) table.tableNo: table};
  return List.generate(count, (index) {
    final no = '${index + 1}';
    final table = byNo[no];
    if (table != null) return table;
    return FloorTable(
      tableNo: no,
      state: index < (right?.tablesSeated ?? 0) ? 'seated' : 'idle',
      covers: index < (right?.tablesSeated ?? 0) ? 2 : 0,
      orderId: null,
    );
  });
}

class _FloorMap extends StatelessWidget {
  const _FloorMap({required this.tables, required this.cols});

  final List<FloorTable> tables;
  final int cols;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: 76,
      ),
      itemCount: tables.length,
      itemBuilder: (_, i) => _FloorTile(table: tables[i]),
    );
  }
}

class _FloorTile extends StatelessWidget {
  const _FloorTile({required this.table});

  final FloorTable table;

  @override
  Widget build(BuildContext context) {
    final state = _normalizedTableState(table.state);
    final bg = switch (state) {
      'idle' => PosColors.surface,
      'bill' => PosColors.warningSoft,
      'late' => PosColors.urgentSoft,
      'kitchen' => PosColors.surfaceSunk,
      _ => PosColors.primarySoft,
    };
    final fg = switch (state) {
      'bill' => PosColors.warning,
      'late' => PosColors.urgent,
      'idle' => PosColors.muted,
      _ => PosColors.primaryDark,
    };
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PosRadii.sm),
        border: Border.all(
          color: state == 'idle' ? PosColors.line : fg.withValues(alpha: 0.28),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                table.tableNo.startsWith('T')
                    ? table.tableNo
                    : 'T${table.tableNo}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
            ],
          ),
          Text(
            state == 'idle'
                ? 'IDLE'
                : (state == 'seated'
                      ? '${table.covers} COVERS'
                      : state.toUpperCase()),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

String _normalizedTableState(String state) {
  final value = state.trim().toLowerCase();
  if (value == 'bill' || value == 'late' || value == 'kitchen') return value;
  if (value == 'served' || value == 'seated') return 'seated';
  return 'idle';
}

Widget _needsYouSection(
  List<NeedsAttentionItem> alerts,
  ValueChanged<int> onNavigate, {
  required int count,
}) {
  return _section(
    top: 18,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SecHead(en: 'Needs you', bn: 'নজর দিন', count: count),
        for (final alert in alerts.take(3))
          _AlertRow(
            tag: alert.kind.toUpperCase(),
            tone: alert.kind == 'low'
                ? _AlertTone.low
                : (alert.kind == 'danger'
                      ? _AlertTone.danger
                      : _AlertTone.late),
            title: alert.title,
            sub: alert.body,
            cta: alert.cta.isEmpty ? 'Check' : alert.cta,
            onCta: () =>
                onNavigate(alert.kind == 'low' ? _stockTab : _ordersTab),
          ),
      ],
    ),
  );
}

Widget _totalsAndPeak({
  required DashboardSummary? summary,
  required String amount,
  required int orders,
  required String? top,
}) {
  final hourly = summary?.review?.revenueByHour;
  return Column(
    children: [
      _section(
        top: 18,
        child: _TotalsHeader(cash: amount, orders: orders, sub: top),
      ),
      _section(
        top: 14,
        child: hourly?.hasData == true
            ? _HourlyCard(
                data: hourly!,
                title: 'Peak hours',
                titleBn: 'ব্যস্ত সময়',
              )
            : const _StaticPeakHoursCard(),
      ),
    ],
  );
}

Widget _closeSection({
  required String title,
  required String kicker,
  String? warn,
}) {
  return _section(
    top: 14,
    child: _CloseCard(title: title, kicker: kicker, warn: warn),
  );
}

class _TotalsHeader extends StatelessWidget {
  const _TotalsHeader({required this.cash, required this.orders, this.sub});

  final String cash;
  final int orders;
  final String? sub;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
      boxShadow: PosShadows.soft,
    ),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 115,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _MicroLabel('Total cash'),
                  const SizedBox(height: 8),
                  Text(
                    cash,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: PosColors.primaryDark,
                      height: 1,
                      letterSpacing: -0.9,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (sub != null && sub!.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      sub!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: PosColors.muted,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Container(width: 0.5, color: PosColors.line),
          Expanded(
            flex: 100,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _MicroLabel('Total orders'),
                  const SizedBox(height: 8),
                  Text(
                    '$orders',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: PosColors.primaryDark,
                      height: 1,
                      letterSpacing: -0.9,
                      fontFeatures: [FontFeature.tabularFigures()],
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

class _StaticPeakHoursCard extends StatelessWidget {
  const _StaticPeakHoursCard();

  @override
  Widget build(BuildContext context) {
    const values = [0.18, 0.32, 0.46, 0.78, 0.95, 0.58];
    const labels = ['11A', '1P', '3P', '5P', '7P', '9P'];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Expanded(child: _MicroLabel('Peak hours')),
              Text(
                'Busiest 5-7 PM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: PosColors.muted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: values[i],
                              widthFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: i == 4
                                      ? PosColors.primaryDark
                                      : PosColors.surfaceSunk,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[i],
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: PosColors.mutedSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String? _topMoverLabel(DashboardSummary? summary) {
  final movers = summary?.moneyFirst.topMovers ?? const <TopMover>[];
  if (movers.isEmpty) return null;
  final first = movers.first;
  return '${first.nameEn} · ×${first.qty}';
}

class _OpenTicketList extends StatelessWidget {
  const _OpenTicketList({required this.count, required this.total});

  final int count;
  final String total;

  @override
  Widget build(BuildContext context) {
    final rows = count.clamp(1, 3);
    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            _OpenTicketRow(
              tag: '#${42 - i}',
              who: i == 0 ? 'Cash · counter' : 'Counter order',
              total: i == 0 ? total : '৳0',
              age: '${2 + (i * 5)} min',
              divider: i < rows - 1,
            ),
        ],
      ),
    );
  }
}

class _OpenTicketRow extends StatelessWidget {
  const _OpenTicketRow({
    required this.tag,
    required this.who,
    required this.total,
    required this.age,
    required this.divider,
  });

  final String tag;
  final String who;
  final String total;
  final String age;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        border: divider
            ? const Border(
                bottom: BorderSide(color: PosColors.line, width: 0.5),
              )
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: PosColors.surfaceSunk,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: PosColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              who,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: PosColors.primaryDark,
              ),
            ),
          ),
          Text(
            '$total · $age',
            style: const TextStyle(
              fontSize: 12,
              color: PosColors.muted,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeltaCard extends StatelessWidget {
  const _DeltaCard({
    required this.value,
    required this.pct,
    required this.down,
    required this.note,
  });

  final String value;
  final String pct;
  final bool down;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfDelta(
            value: value,
            pct: pct,
            down: down,
            baselineLabel: 'prev ${DateFormat('EEE').format(DateTime.now())}',
            size: 15,
          ),
          const SizedBox(height: 5),
          Text(
            note,
            style: const TextStyle(
              fontSize: 12,
              color: PosColors.muted,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

// Fleet goal card with progress bar (T4 hero).
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.amount,
    required this.label,
    required this.bn,
    required this.sub,
    required this.pct,
    required this.goal,
  });

  final String amount;
  final String label;
  final String bn;
  final String sub;
  final int pct;
  final String goal;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
      boxShadow: PosShadows.soft,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _MicroLabel(tfPick(context, en: label, bn: bn)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: PosColors.primarySoft,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: PosColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    tfPick(context, en: '$pct% of goal', bn: 'লক্ষ্যের $pct%'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PosColors.primaryDark,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: PosColors.primaryDark,
            letterSpacing: -1.5,
            height: 1.0,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (pct / 100.0).clamp(0, 1),
            backgroundColor: PosColors.surfaceSunk,
            color: PosColors.primary,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              sub,
              style: const TextStyle(
                fontSize: 12,
                color: PosColors.muted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              tfPick(context, en: 'Goal $goal', bn: 'লক্ষ্য $goal'),
              style: const TextStyle(
                fontSize: 12,
                color: PosColors.mutedSoft,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// Outlet card for T4 leaderboard.
class _OutletCard extends StatelessWidget {
  const _OutletCard({
    required this.name,
    required this.area,
    required this.rev,
    required this.deltaUp,
    required this.delta,
    required this.occ,
    required this.late,
    this.isTop = false,
  });

  final String name;
  final String area;
  final String rev;
  final bool deltaUp;
  final String delta;
  final String occ;
  final String late;
  final bool isTop;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: PosColors.primaryDark,
                          letterSpacing: -0.1,
                        ),
                      ),
                      if (isTop) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: PosColors.primarySoft,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tfPick(context, en: 'TOP', bn: 'শীর্ষ'),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: PosColors.primaryDark,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    area,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PosColors.mutedSoft,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  rev,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: PosColors.primaryDark,
                    letterSpacing: -0.4,
                    height: 1.0,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tfPick(
                    context,
                    en: '${deltaUp ? "▲" : "▼"} $delta vs avg',
                    bn: '${deltaUp ? "▲" : "▼"} গড়ের তুলনায় $delta',
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: deltaUp ? PosColors.primary : PosColors.urgent,
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(height: 0.5, color: PosColors.line),
        const SizedBox(height: 12),
        Row(
          children: [
            _OutletMetric(
              label: tfPick(context, en: 'Occupancy', bn: 'ব্যবহার'),
              value: occ,
            ),
            Container(
              width: 0.5,
              height: 24,
              color: PosColors.line,
              margin: const EdgeInsets.symmetric(horizontal: 18),
            ),
            _OutletMetric(
              label: tfPick(context, en: 'Late', bn: 'দেরি'),
              value: late,
              warn: late != '0%' && late != '—',
            ),
          ],
        ),
      ],
    ),
  );
}

class _OutletMetric extends StatelessWidget {
  const _OutletMetric({
    required this.label,
    required this.value,
    this.warn = false,
  });
  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: warn ? PosColors.urgent : PosColors.primaryDark,
          height: 1.0,
          fontFeatures: [const FontFeature.tabularFigures()],
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: PosColors.mutedSoft,
          letterSpacing: 0.5,
        ),
      ),
    ],
  );
}

class _FleetNote extends StatelessWidget {
  const _FleetNote({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: PosColors.primaryDark,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: const TextStyle(
            fontSize: 11.5,
            color: PosColors.muted,
            height: 1.35,
          ),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// REVIEW TAB — Standard / Advanced / Enterprise screens + shared primitives.
// Consumes app.dashboardSummary?.review (see ReviewSection in
// models/dashboard_summary.dart). Renders neutral states when data is absent.
// ════════════════════════════════════════════════════════════════════════════

String _bdt(num value) => '৳${NumberFormat('#,##0', 'en').format(value)}';

String _fcLabel(double? pct) => pct == null ? '—' : '${pct.round()}%';

// Common Review scaffold: header (with Manage/Review switcher + period chip)
// followed by the screen's sections.
Widget _reviewScaffold({
  required dynamic app,
  required String period,
  required _DashMode mode,
  required ValueChanged<_DashMode> onModeChanged,
  required ValueChanged<int> onNavigate,
  required ValueChanged<PosNotificationTarget>? onNavigateToTarget,
  required List<Widget> sections,
}) {
  return Scaffold(
    backgroundColor: PosColors.background,
    body: SafeArea(
      child: RefreshIndicator(
        color: PosColors.primaryDark,
        backgroundColor: PosColors.primary,
        onRefresh: () => app.refreshDashboardSummary(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            _DashHeader(
              bizName: app.serverConfig?.restaurantName ?? 'My Restaurant',
              onNavigateToOrders: () => onNavigate(_ordersTab),
              onNavigateToTarget: onNavigateToTarget,
              mode: mode,
              onModeChanged: onModeChanged,
              period: period,
            ),
            ...sections,
          ],
        ),
      ),
    ),
  );
}

// Section wrapper — horizontal screen padding + configurable top gap.
class _RSection extends StatelessWidget {
  const _RSection({required this.child, this.top = 14});
  final Widget child;
  final double top;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: EdgeInsets.fromLTRB(16, top, 16, 0), child: child);
}

// Short neutral placeholder for an empty Review section.
class _ReviewEmptyNote extends StatelessWidget {
  const _ReviewEmptyNote(this.text, {this.bn});
  final String text;
  final String? bn;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: Text(
      tfPick(context, en: text, bn: bn),
      style: const TextStyle(fontSize: 12.5, color: PosColors.muted),
    ),
  );
}

// Card wrapping a list of rows with hairline dividers between them.
class _RowsCard extends StatelessWidget {
  const _RowsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: Column(
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0)
            const Divider(height: 0.5, thickness: 0.5, color: PosColors.line),
          children[i],
        ],
      ],
    ),
  );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontSize: 10.5,
      fontWeight: FontWeight.w600,
      color: PosColors.muted,
      letterSpacing: 0.5,
    ),
  );
}

// Vs-yesterday / vs-7-day hero card for the Review tab.
class _ReviewHero extends StatelessWidget {
  const _ReviewHero({
    required this.amount,
    required this.label,
    this.bn,
    this.deltaText,
    this.deltaUp = true,
    this.baseLabel,
    this.note,
  });

  final String amount;
  final String label;
  final String? bn;
  final String? deltaText;
  final bool deltaUp;
  final String? baseLabel;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
      boxShadow: PosShadows.soft,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_MicroLabel(tfPick(context, en: label, bn: bn))],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (deltaText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: deltaUp
                          ? PosColors.successSoft
                          : PosColors.dangerSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          deltaUp ? '▲' : '▼',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: deltaUp
                                ? PosColors.success
                                : PosColors.danger,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          deltaText!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: deltaUp
                                ? PosColors.success
                                : PosColors.danger,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (baseLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    baseLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PosColors.mutedSoft,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          amount,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: PosColors.primaryDark,
            letterSpacing: -1.5,
            height: 1.0,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        if (note != null && note!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            note!,
            style: const TextStyle(
              fontSize: 13,
              color: PosColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ],
    ),
  );
}

// Revenue-by-hour card — chart + peak label + legend.
class _HourlyCard extends StatelessWidget {
  const _HourlyCard({
    required this.data,
    this.title = 'Today vs 7-day average',
    this.titleBn = 'আজ বনাম ৭ দিনের গড়',
  });
  final RevenueByHour data;
  final String title;
  final String titleBn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Expanded(
                child: _Eyebrow(tfPick(context, en: title, bn: titleBn)),
              ),
              if (data.peakLabel.isNotEmpty)
                Text(
                  '${tfPick(context, en: 'PEAK', bn: 'সর্বোচ্চ')} · ${data.peakLabel}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: PosColors.primary,
                    letterSpacing: 0.3,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        HourlyBarsChart(
          today: data.today,
          avg7: data.avg7,
          startHour: data.startHour,
          peakIndex: data.peakIndex,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _legendDot(
              PosColors.primaryDark,
              tfPick(context, en: 'Today', bn: 'আজ'),
            ),
            const SizedBox(width: 14),
            _legendDot(
              PosColors.surfaceSunk,
              tfPick(context, en: '7-day avg', bn: '৭ দিনের গড়'),
              bordered: true,
            ),
          ],
        ),
      ],
    ),
  );

  Widget _legendDot(Color color, String label, {bool bordered = false}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
          border: bordered
              ? Border.all(color: PosColors.lineStrong, width: 0.5)
              : null,
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: PosColors.muted)),
    ],
  );
}

// Per-item row for "Top items" / "What sold" / fleet "Top movers".
class _ReviewItemRow extends StatelessWidget {
  const _ReviewItemRow({required this.rank, required this.item});
  final int rank;
  final ReviewItem item;

  @override
  Widget build(BuildContext context) {
    final top = rank == 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: top ? PosColors.primaryDark : PosColors.surfaceSunk,
              borderRadius: BorderRadius.circular(PosRadii.xs),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: top ? Colors.white : PosColors.mutedSoft,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nameEn,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PosColors.primaryDark,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '×${item.qty}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: PosColors.mutedSoft,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (item.foodCostPct != null)
                      Text(
                        'FC ${item.foodCostPct!.round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: item.lowMargin
                              ? PosColors.urgent
                              : PosColors.mutedSoft,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (item.lowMargin)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PosColors.warningSoft,
                          borderRadius: BorderRadius.circular(PosRadii.xs),
                        ),
                        child: const Text(
                          'MARGIN LOW',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: PosColors.warning,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _bdt(item.salesBdt),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: PosColors.primaryDark,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (item.marginBdt != null) ...[
                const SizedBox(height: 3),
                Text(
                  '+${_bdt(item.marginBdt!)} margin',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: PosColors.success,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// Plain-language low-margin callout (warning-soft surface + ink text).
class _MarginCallout extends StatelessWidget {
  const _MarginCallout(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
    decoration: BoxDecoration(
      color: PosColors.warningSoft,
      borderRadius: BorderRadius.circular(PosRadii.sm),
      border: Border.all(
        color: PosColors.warning.withValues(alpha: 0.16),
        width: 1,
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            color: PosColors.warning,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: PosColors.primaryDark,
              height: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

// Today's-issues row — urgent-soft surface, tag pill + title/body.
class _IssueRow extends StatelessWidget {
  const _IssueRow(this.issue);
  final ReviewIssue issue;

  @override
  Widget build(BuildContext context) => Container(
    color: PosColors.urgentSoft,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.xs),
          ),
          child: Text(
            issue.tag,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: PosColors.urgent,
              letterSpacing: 0.7,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                issue.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PosColors.primaryDark,
                  height: 1.3,
                ),
              ),
              if (issue.body.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  issue.body,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: PosColors.inkSoft,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

// Payment-source breakdown — 3 cells (Cash / Card / Online).
class _CollapsedSourceCard extends StatelessWidget {
  const _CollapsedSourceCard({required this.rows});
  final List<SourceSlice> rows;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: ExpansionTile(
      key: const ValueKey('review-source-breakdown'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 14),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: const Border(),
      collapsedShape: const Border(),
      title: const Text(
        'Payment breakdown',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: PosColors.primaryDark,
        ),
      ),
      children: [_SourceChips(rows: rows)],
    ),
  );
}

class _SourceChips extends StatelessWidget {
  const _SourceChips({required this.rows});
  final List<SourceSlice> rows;

  Color _dotColor(String key) => switch (key) {
    'cash' => PosColors.primary,
    'card' => PosColors.primaryDark,
    _ => PosColors.mutedSoft,
  };

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (int i = 0; i < rows.length; i++) ...[
        if (i > 0) const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            decoration: BoxDecoration(
              color: PosColors.surface,
              borderRadius: BorderRadius.circular(PosRadii.md),
              border: Border.all(color: PosColors.line, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _dotColor(rows[i].key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        rows[i].label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: PosColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _bdt(rows[i].valueBdt),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PosColors.primaryDark,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${rows[i].pct}%',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: PosColors.mutedSoft,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

// Staff scoreboard row — initial avatar, name/role·covers, avg ticket.
class _StaffScoreRow extends StatelessWidget {
  const _StaffScoreRow({required this.rank, required this.staff});
  final int rank;
  final StaffScore staff;

  @override
  Widget build(BuildContext context) {
    final top = rank == 1;
    final initial = staff.name.isNotEmpty ? staff.name.characters.first : '?';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: top ? PosColors.primaryDark : PosColors.surfaceSunk,
              shape: BoxShape.circle,
              border: Border.all(
                color: top ? PosColors.primaryDark : PosColors.line,
                width: 0.5,
              ),
            ),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: top ? Colors.white : PosColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      staff.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PosColors.primaryDark,
                      ),
                    ),
                    if (top) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PosColors.primarySoft,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'TOP',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: PosColors.primaryDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${staff.role} · ${staff.covers} covers',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PosColors.mutedSoft,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _bdt(staff.avgTicketBdt),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PosColors.primaryDark,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${staff.ordersToday} orders',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: PosColors.mutedSoft,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Fleet outlet ranking row with inline health chips.
class _OutletRankRowInline extends StatelessWidget {
  const _OutletRankRowInline({required this.outlet});
  final FleetOutlet outlet;

  @override
  Widget build(BuildContext context) {
    final rank = outlet.rank;
    final (Color rankBg, Color rankFg) = switch (rank) {
      1 => (PosColors.primaryDark, Colors.white),
      2 => (PosColors.primarySoft, PosColors.primaryDark),
      _ => (PosColors.surfaceSunk, PosColors.muted),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: rankBg,
              borderRadius: BorderRadius.circular(PosRadii.sm),
            ),
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: rankFg,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        outlet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: PosColors.primaryDark,
                        ),
                      ),
                    ),
                    if (rank == 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PosColors.primarySoft,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'TOP',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: PosColors.primaryDark,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${outlet.area.isEmpty ? '' : '${outlet.area} · '}${outlet.covers} covers · FC ${_fcLabel(outlet.foodCostPct)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: PosColors.mutedSoft,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (outlet.health.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [for (final c in outlet.health) _HealthChip(c)],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _bdt(outlet.revBdt),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PosColors.primaryDark,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${outlet.deltaUp ? '▲' : '▼'} ${outlet.deltaPct.round()}%',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: outlet.deltaUp ? PosColors.success : PosColors.urgent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip(this.chip);
  final HealthChip chip;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (chip.tone) {
      'warn' => (PosColors.warningSoft, PosColors.warning),
      'danger' => (PosColors.dangerSoft, PosColors.danger),
      _ => (PosColors.urgentSoft, PosColors.urgent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            chip.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            chip.value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _CapacityRow extends StatelessWidget {
  const _CapacityRow(this.row);
  final CapacityRow row;

  @override
  Widget build(BuildContext context) {
    final tone = row.pct >= 85
        ? PosColors.urgent
        : (row.pct >= 60 ? PosColors.primary : PosColors.success);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PosColors.primaryDark,
                  ),
                ),
              ),
              Text(
                '${row.pct}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PosColors.primaryDark,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                row.status.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: PosColors.muted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: (row.pct / 100).clamp(0, 1).toDouble(),
              backgroundColor: PosColors.surfaceSunk,
              color: tone,
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Review · Standard (Simple + Standard tiers) ──────────────────────────────
class _ReviewStandard extends StatelessWidget {
  const _ReviewStandard({
    required this.app,
    required this.onNavigate,
    this.onNavigateToTarget,
    required this.mode,
    required this.onModeChanged,
  });

  final dynamic app;
  final ValueChanged<int> onNavigate;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final _DashMode mode;
  final ValueChanged<_DashMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final review = (app.dashboardSummary as DashboardSummary?)?.review;
    final sections = <Widget>[];

    if (review == null) {
      sections.add(
        const _RSection(
          top: 12,
          child: _ReviewEmptyNote(
            'Review data will appear once today\'s sales sync.',
            bn: 'আজকের বিক্রি সিঙ্ক হলে পর্যালোচনার তথ্য দেখা যাবে।',
          ),
        ),
      );
    } else {
      final hero = review.hero;
      final diff = hero.earnedTodayBdt - hero.earnedYesterdayBdt;
      sections.addAll([
        _RSection(
          top: 12,
          child: _ReviewHero(
            amount: _bdt(hero.earnedTodayBdt),
            label: 'Earned today',
            bn: 'আজকের আয়',
            deltaText: '${diff >= 0 ? '+' : '-'}${_bdt(diff.abs())}',
            deltaUp: hero.deltaUp,
            baseLabel: tfPick(
              context,
              en: 'vs yest ${_bdt(hero.earnedYesterdayBdt)}',
              bn: 'গতকাল ${_bdt(hero.earnedYesterdayBdt)}',
            ),
            note: hero.periodNote,
          ),
        ),
        _RSection(
          child: _KpiStrip(
            stats: [
              _KpiStat(
                tfPick(context, en: 'Orders', bn: 'অর্ডার'),
                '${review.kpis.orders}',
              ),
              _KpiStat(
                tfPick(context, en: 'Covers', bn: 'অতিথি'),
                '${review.kpis.covers}',
              ),
            ],
          ),
        ),
        _RSection(
          top: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SecHead(en: 'Top items today', bn: 'টপ আইটেম'),
              review.itemsSold.isEmpty
                  ? const _ReviewEmptyNote(
                      'No sales recorded yet today.',
                      bn: 'আজ এখনো কোনো বিক্রি রেকর্ড হয়নি।',
                    )
                  : _RowsCard(
                      children: [
                        for (int i = 0; i < review.itemsSold.length; i++)
                          _ReviewItemRow(
                            rank: i + 1,
                            item: review.itemsSold[i],
                          ),
                      ],
                    ),
            ],
          ),
        ),
        if (review.issues.isNotEmpty)
          _RSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SecHead(
                  en: "Today's issues",
                  bn: 'সমস্যা',
                  count: review.issues.length,
                ),
                _RowsCard(
                  children: [
                    for (final issue in review.issues) _IssueRow(issue),
                  ],
                ),
              ],
            ),
          ),
        _RSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SecHead(en: 'By source', bn: 'সোর্স অনুযায়ী'),
              _CollapsedSourceCard(rows: review.bySource),
            ],
          ),
        ),
      ]);
    }

    return _reviewScaffold(
      app: app,
      period: tfPick(context, en: 'Today', bn: 'আজ'),
      mode: mode,
      onModeChanged: onModeChanged,
      onNavigate: onNavigate,
      onNavigateToTarget: onNavigateToTarget,
      sections: sections,
    );
  }
}

// ── Review · Advanced (Advanced tier) ────────────────────────────────────────
class _ReviewAdvanced extends StatelessWidget {
  const _ReviewAdvanced({
    required this.app,
    required this.onNavigate,
    this.onNavigateToTarget,
    required this.mode,
    required this.onModeChanged,
  });

  final dynamic app;
  final ValueChanged<int> onNavigate;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final _DashMode mode;
  final ValueChanged<_DashMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final review = (app.dashboardSummary as DashboardSummary?)?.review;
    final sections = <Widget>[];

    if (review == null) {
      sections.add(
        const _RSection(
          top: 12,
          child: _ReviewEmptyNote(
            'Review data will appear once today\'s sales sync.',
            bn: 'আজকের বিক্রি সিঙ্ক হলে পর্যালোচনার তথ্য দেখা যাবে।',
          ),
        ),
      );
    } else {
      final hero = review.hero;
      final lowItem = review.itemsSold
          .where((it) => it.lowMargin)
          .cast<ReviewItem?>()
          .firstWhere((_) => true, orElse: () => null);
      final lowFoodCostPct = lowItem?.foodCostPct;
      sections.addAll([
        _RSection(
          top: 12,
          child: _ReviewHero(
            amount: _bdt(hero.earnedTodayBdt),
            label: 'Earned today',
            bn: 'আজকের আয়',
            deltaText: '${hero.deltaPct.round()}%',
            deltaUp: hero.deltaUp,
            baseLabel: tfPick(
              context,
              en: 'vs 7-day avg ${_bdt(hero.avg7Bdt)}',
              bn: '৭ দিনের গড় ${_bdt(hero.avg7Bdt)}',
            ),
            note: hero.periodNote,
          ),
        ),
        _RSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SecHead(
                en: 'Staff today',
                bn: 'স্টাফ',
                action: '${review.staff.length} on shift',
                actionBn: 'শিফটে ${review.staff.length} জন',
              ),
              review.staff.isEmpty
                  ? const _ReviewEmptyNote(
                      'No staff-attributed orders yet today.',
                      bn: 'আজ এখনো স্টাফের নামে কোনো অর্ডার নেই।',
                    )
                  : _RowsCard(
                      children: [
                        for (int i = 0; i < review.staff.length; i++)
                          _StaffScoreRow(rank: i + 1, staff: review.staff[i]),
                      ],
                    ),
            ],
          ),
        ),
        _RSection(
          child: _KpiStrip(
            stats: [
              _KpiStat(
                tfPick(context, en: 'Orders', bn: 'অর্ডার'),
                '${review.kpis.orders}',
              ),
              _KpiStat(
                tfPick(context, en: 'Covers', bn: 'অতিথি'),
                '${review.kpis.covers}',
              ),
              _KpiStat(
                tfPick(context, en: 'Avg ticket', bn: 'গড় বিল'),
                _bdt(review.kpis.avgTicketBdt),
              ),
              _KpiStat(
                tfPick(context, en: 'Food cost', bn: 'খাবারের খরচ'),
                _fcLabel(review.kpis.foodCostPct),
              ),
            ],
          ),
        ),
        _RSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SecHead(
                en: 'Revenue by hour',
                bn: 'ঘণ্টাভিত্তিক আয়',
                action: '7-day',
                actionBn: '৭ দিন',
              ),
              review.revenueByHour.hasData
                  ? _HourlyCard(data: review.revenueByHour)
                  : const _ReviewEmptyNote(
                      'Not enough sales yet to chart today.',
                      bn: 'আজ চার্ট দেখানোর মতো যথেষ্ট বিক্রি নেই।',
                    ),
            ],
          ),
        ),
        _RSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SecHead(en: 'Hot selling', bn: 'বেশি বিক্রি'),
              review.itemsSold.isEmpty
                  ? const _ReviewEmptyNote(
                      'No sales recorded yet today.',
                      bn: 'আজ এখনো কোনো বিক্রি রেকর্ড হয়নি।',
                    )
                  : _RowsCard(
                      children: [
                        for (int i = 0; i < review.itemsSold.length; i++)
                          _ReviewItemRow(
                            rank: i + 1,
                            item: review.itemsSold[i],
                          ),
                      ],
                    ),
              if (lowItem != null && lowFoodCostPct != null)
                _MarginCallout(
                  tfPick(
                    context,
                    en: '${lowItem.nameEn} - selling well but margin is low (FC ${lowFoodCostPct.round()}%). Worth a check.',
                    bn: '${lowItem.nameEn} ভালো বিক্রি হচ্ছে, কিন্তু মার্জিন কম (FC ${lowFoodCostPct.round()}%)। দেখে নিন।',
                  ),
                ),
            ],
          ),
        ),
        _RSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SecHead(en: 'By source', bn: 'সোর্স'),
              _SourceChips(rows: review.bySource),
            ],
          ),
        ),
      ]);
    }

    return _reviewScaffold(
      app: app,
      period: tfPick(context, en: 'Today', bn: 'আজ'),
      mode: mode,
      onModeChanged: onModeChanged,
      onNavigate: onNavigate,
      onNavigateToTarget: onNavigateToTarget,
      sections: sections,
    );
  }
}

// ── Review · Enterprise (Fleet) ──────────────────────────────────────────────
class _ReviewEnterprise extends StatelessWidget {
  const _ReviewEnterprise({
    required this.app,
    required this.onNavigate,
    this.onNavigateToTarget,
    required this.mode,
    required this.onModeChanged,
  });

  final dynamic app;
  final ValueChanged<int> onNavigate;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final _DashMode mode;
  final ValueChanged<_DashMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    final review = (app.dashboardSummary as DashboardSummary?)?.review;
    final sections = <Widget>[];

    if (review == null) {
      sections.add(
        const _RSection(
          top: 12,
          child: _ReviewEmptyNote(
            'Fleet review will appear once outlet sales sync.',
            bn: 'আউটলেটের বিক্রি সিঙ্ক হলে ফ্লিট পর্যালোচনা দেখা যাবে।',
          ),
        ),
      );
    } else {
      final fleet = review.fleet;
      final k = fleet.kpis;
      sections.addAll([
        _RSection(
          top: 12,
          child: _ReviewHero(
            amount: _bdt(k.revBdt),
            label: 'Fleet revenue · today',
            bn: 'আজকের সব আউটলেটের আয়',
            deltaText: '${k.deltaPct.round()}%',
            deltaUp: k.deltaUp,
            baseLabel: tfPick(
              context,
              en: 'vs 7-day avg ${_bdt(k.avg7Bdt)}',
              bn: '৭ দিনের গড় ${_bdt(k.avg7Bdt)}',
            ),
            note: tfPick(
              context,
              en: '${k.onGoalCount} of ${k.outletCount} outlets on goal',
              bn: '${k.outletCount}টির মধ্যে ${k.onGoalCount} টি আউটলেট লক্ষ্যে আছে',
            ),
          ),
        ),
        _RSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SecHead(
                en: 'Outlets · today',
                bn: 'আউটলেট',
                action: 'Compare',
                actionBn: 'তুলনা',
              ),
              fleet.outlets.isEmpty
                  ? const _ReviewEmptyNote(
                      'No outlet sales yet today.',
                      bn: 'আজ এখনো কোনো আউটলেটে বিক্রি নেই।',
                    )
                  : _RowsCard(
                      children: [
                        for (final o in fleet.outlets)
                          _OutletRankRowInline(outlet: o),
                      ],
                    ),
            ],
          ),
        ),
        _RSection(
          child: _KpiStrip(
            stats: [
              _KpiStat(
                tfPick(context, en: 'Covers', bn: 'অতিথি'),
                '${k.covers}',
              ),
              _KpiStat(
                tfPick(context, en: 'Avg ticket', bn: 'গড় বিল'),
                _bdt(k.avgTicketBdt),
              ),
              _KpiStat(
                tfPick(context, en: 'Fleet FC', bn: 'ফ্লিট FC'),
                _fcLabel(k.foodCostPct),
              ),
              _KpiStat(
                tfPick(context, en: 'On goal', bn: 'লক্ষ্যে'),
                '${k.onGoalCount}/${k.outletCount}',
              ),
            ],
          ),
        ),
        _RSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SecHead(
                en: 'Revenue by hour · fleet',
                bn: 'ফ্লিটের ঘণ্টাভিত্তিক আয়',
                action: '7-day',
                actionBn: '৭ দিন',
              ),
              fleet.revenueByHour.hasData
                  ? _HourlyCard(
                      data: fleet.revenueByHour,
                      title: 'Today vs 7-day average · all outlets',
                      titleBn: 'আজ বনাম ৭ দিনের গড় · সব আউটলেট',
                    )
                  : const _ReviewEmptyNote(
                      'Not enough sales yet to chart today.',
                      bn: 'আজ চার্ট দেখানোর মতো যথেষ্ট বিক্রি নেই।',
                    ),
            ],
          ),
        ),
        if (fleet.capacity.isNotEmpty)
          _RSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SecHead(
                  en: 'Capacity right now',
                  bn: 'ক্যাপাসিটি',
                  action: 'Tonight',
                  actionBn: 'আজ রাত',
                ),
                _RowsCard(
                  children: [for (final c in fleet.capacity) _CapacityRow(c)],
                ),
              ],
            ),
          ),
        if (fleet.topMovers.isNotEmpty)
          _RSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SecHead(
                  en: 'Top movers · fleet',
                  bn: 'টপ আইটেম',
                  action: 'Aggregate',
                  actionBn: 'মোট হিসাব',
                ),
                _RowsCard(
                  children: [
                    for (int i = 0; i < fleet.topMovers.length; i++)
                      _ReviewItemRow(rank: i + 1, item: fleet.topMovers[i]),
                  ],
                ),
              ],
            ),
          ),
      ]);
    }

    return _reviewScaffold(
      app: app,
      period: tfPick(context, en: 'Today · Fleet', bn: 'আজ · ফ্লিট'),
      mode: mode,
      onModeChanged: onModeChanged,
      onNavigate: onNavigate,
      onNavigateToTarget: onNavigateToTarget,
      sections: sections,
    );
  }
}
