import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/account_role.dart';
import '../../models/dashboard_metrics.dart';
import '../../models/dashboard_summary.dart';
import '../../models/order_model.dart';
import '../../models/order_source.dart';
import '../../models/order_status.dart';
import '../../models/pos_notification.dart';
import '../orders/orders_screen.dart';

/// QuickBytes Control Tower ("Live") — manager live-ops (spec §4.9).
/// Always: attention alerts (late order / low stock → tap routes to source),
/// quick stats (open orders, tables seated, avg wait), channel-load bars.
/// A minimal **Advanced** toggle adds pace-to-target and per-staff metrics.
class ControlTowerScreen extends StatefulWidget {
  const ControlTowerScreen({
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    super.key,
  });

  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<ControlTowerScreen> createState() => _ControlTowerScreenState();
}

class _ControlTowerScreenState extends State<ControlTowerScreen> {
  // Fallback when no target is configured in Ordering settings (null-safe:
  // dailySalesTarget is nullable and NULL == "not configured").
  static const double _kDefaultDailyTarget = 30000;

  bool _settingsRequested = false;
  bool _summaryRequested = false;
  double? _configuredTarget;

  int _ageMins(OrderModel o) =>
      DateTime.now().difference(o.createdAt.toLocal()).inMinutes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settingsRequested) return;
    _settingsRequested = true;
    AppScope.read(context).loadDesktopPosSettings().then((settings) {
      if (!mounted) return;
      setState(() => _configuredTarget = settings.dailySalesTarget);
    });
    if (!_summaryRequested) {
      _summaryRequested = true;
      AppScope.read(context).refreshDashboardSummary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;

    final orders = app.ordersFor();
    final open = orders.where((o) => o.status.isOpen).toList(growable: false);
    final pending = open
        .where((o) => o.status.adminStatus == OrderStatus.pending)
        .toList(growable: false);

    // Slowest pending order (the one most in need of accepting).
    OrderModel? slowest;
    for (final o in pending) {
      if (slowest == null || _ageMins(o) > _ageMins(slowest)) slowest = o;
    }

    final liveRev = open.fold<double>(0, (s, o) => s + o.total);

    // Tables seated = distinct occupied tables among open orders.
    final occupiedTables = <String>{};
    for (final o in open) {
      final t = (o.tableNo ?? '').trim();
      if (t.isNotEmpty) occupiedTables.add(t);
    }
    final tableCount = app.serverConfig.tableCount;

    final avgWait = pending.isEmpty
        ? null
        : (pending.fold<int>(0, (s, o) => s + _ageMins(o)) / pending.length)
              .round();

    final showSlowest = slowest != null && _ageMins(slowest) >= 3;
    final hasAlerts = showSlowest;

    return AppScaffold(
      title: text.liveTab,
      floatingActionButton: app.menuItems.any((i) => i.isAvailable)
          ? TfFab(
              tooltip: text.newOrder,
              onPressed: () => openNewOrderForm(context),
            )
          : null,
      headerWidget: AppPageHeader(
        title: text.liveTab,
        subtitle: text.liveOperations,
        onNavigateToOrders: widget.onNavigateToOrders,
        onNavigateToTarget: widget.onNavigateToTarget,
        showAdvanced: false,
      ),
      showDatePill: false,
      pinHeader: true,
      fillBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TfText(
            '${text.rightNow} · ${_nowLabel()}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: PosColors.muted,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasAlerts) ...[
                    if (showSlowest)
                      _AlertCard(
                        icon: Icons.schedule_rounded,
                        tone: PosColors.danger,
                        toneSoft: PosColors.dangerSoft,
                        title: text.orderWaitingMinutes(
                          slowest.displaySequence,
                          _ageMins(slowest),
                        ),
                        body:
                            '${_typeLabel(text, slowest)} · ${text.needsAccepting}',
                        onTap:
                            widget.onNavigateToOrders ??
                            () => widget.onNavigateToTarget?.call(
                              PosNotificationTarget.orders,
                            ),
                      ),
                    const SizedBox(height: 14),
                  ] else ...[
                    _AllClearCard(text: text),
                    const SizedBox(height: 14),
                  ],

                  _DailySummaryCard(
                    text: text,
                    dashboardSummary: app.dashboardSummary,
                    isLoading: app.dashboardSummaryLoading,
                    error: app.dashboardSummaryError,
                    metrics: app.metrics,
                  ),
                  const SizedBox(height: 14),

                  // Quick stats — always visible.
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _Metric(
                            label: text.openOrdersStat,
                            value: tfFormatNumber(context, open.length),
                            sub: text.pendingCountLabel(pending.length),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Metric(
                            label: text.tablesSeated,
                            value:
                                '${tfFormatNumber(context, occupiedTables.length)}/${tfFormatNumber(context, tableCount)}',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Metric(
                            label: text.avgWaitStat,
                            value: avgWait == null
                                ? '—'
                                : '${tfFormatNumber(context, avgWait)}m',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Channel load — always visible.
                  _ChannelLoadCard(text: text, open: open),

                  const SizedBox(height: 12),
                  _PaceCard(
                    text: text,
                    liveRev: liveRev,
                    target: _configuredTarget ?? _kDefaultDailyTarget,
                  ),
                  const SizedBox(height: 12),
                  _StaffCard(text: text, open: open),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _nowLabel() {
    final now = DateTime.now();
    final h = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final m = now.minute.toString().padLeft(2, '0');
    final ap = now.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }

  String _typeLabel(AppStrings text, OrderModel o) {
    final t = (o.tableNo ?? '').trim();
    if (t.isNotEmpty) return text.isBn ? 'টেবিল $t' : 'Table $t';
    final st = o.serviceType;
    if (st != null) return st.localized(text.isBn);
    return o.source.label;
  }
}

// ── Alerts ───────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.tone,
    required this.toneSoft,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final Color tone;
  final Color toneSoft;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(PosRadii.card),
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 12, 11, 12),
        decoration: BoxDecoration(
          color: toneSoft,
          borderRadius: BorderRadius.circular(PosRadii.card),
          border: Border.all(color: tone.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tone,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 19, color: Colors.white),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TfText(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: tone,
                    ),
                  ),
                  const SizedBox(height: 1),
                  TfText(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: PosColors.textSec,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: tone),
          ],
        ),
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard({required this.text});

  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 20,
            color: PosColors.success,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TfText(
              text.allClearLiveOps,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: PosColors.textSec,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Daily summary card ────────────────────────────────────────────────────────

class _DailySummaryCard extends StatelessWidget {
  const _DailySummaryCard({
    required this.text,
    required this.dashboardSummary,
    required this.isLoading,
    required this.error,
    required this.metrics,
  });

  final AppStrings text;
  final DashboardSummary? dashboardSummary;
  final bool isLoading;
  final String? error;
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final ds = dashboardSummary;

    // Prefer cloud summary, fall back to local metrics.
    final revenue = ds?.moneyFirst.earnedToday ?? metrics.totalSales;
    final orders = ds?.moneyFirst.kpis.orders ?? metrics.todayOrders;
    final avgTicket = ds?.moneyFirst.kpis.avgTicket ??
        (orders > 0 ? revenue / orders : 0);
    final deltaPct = ds?.moneyFirst.deltaPct;
    final hasDelta = deltaPct != null && deltaPct != 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: TfText(
                  text.todaySoFar,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PosColors.text,
                  ),
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: PosColors.muted,
                  ),
                )
              else if (error != null)
                Icon(Icons.cloud_off_rounded,
                    size: 16, color: PosColors.muted)
              else if (hasDelta)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      deltaPct > 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,

                      size: 16,
                      color: deltaPct > 0
                          ? PosColors.success
                          : PosColors.danger,
                    ),
                    const SizedBox(width: 3),
                    TfText(
                      '${deltaPct > 0 ? '+' : ''}${deltaPct.round()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: deltaPct > 0
                            ? PosColors.success
                            : PosColors.danger,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          // Metric row
          Row(
            children: [
              Expanded(
                child: _DailyStat(
                  value: tfFormatCurrency(context, revenue),
                  label: text.earnedToday,
                ),
              ),
              _DotSep(),
              Expanded(
                child: _DailyStat(
                  value: tfFormatNumber(context, orders),
                  label: text.kpiOrders,
                ),
              ),
              _DotSep(),
              Expanded(
                child: _DailyStat(
                  value: tfFormatCurrency(context, avgTicket),
                  label: text.kpiAvg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DailyStat extends StatelessWidget {
  const _DailyStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfText(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: PosColors.text,
            letterSpacing: -0.3,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        TfText(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: PosColors.muted,
          ),
        ),
      ],
    );
  }
}

class _DotSep extends StatelessWidget {
  const _DotSep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 18,
          color: PosColors.lineStrong,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ── Quick stat metric ─────────────────────────────────────────────────────────

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.sub});

  final String label;
  final String value;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          TfText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PosColors.muted,
            ),
          ),
          const SizedBox(height: 3),
          TfText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: PosColors.text,
              letterSpacing: -0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 3),
            TfText(
              sub!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: PosColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Channel load ──────────────────────────────────────────────────────────────

class _ChannelLoadCard extends StatelessWidget {
  const _ChannelLoadCard({required this.text, required this.open});

  final AppStrings text;
  final List<OrderModel> open;

  @override
  Widget build(BuildContext context) {
    final counts = <OrderSource, int>{};
    for (final o in open) {
      counts[o.source] = (counts[o.source] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxN = entries.isEmpty
        ? 1
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            text.orderChannelsNow,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: PosColors.text,
            ),
          ),
          const SizedBox(height: 13),
          if (entries.isEmpty)
            TfText(
              text.isBn ? 'এখনো কোনো অর্ডার নেই।' : 'No live orders yet.',
              style: const TextStyle(fontSize: 13, color: PosColors.muted),
            )
          else
            for (var i = 0; i < entries.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 11),
                child: _ChannelRow(
                  icon: _channelIcon(entries[i].key),
                  label: entries[i].key.label,
                  count: entries[i].value,
                  fraction: entries[i].value / maxN,
                ),
              ),
        ],
      ),
    );
  }

  static IconData _channelIcon(OrderSource s) {
    switch (s) {
      case OrderSource.facebookMessenger:
        return Icons.chat_bubble_outline_rounded;
      case OrderSource.cloud:
        return Icons.public_rounded;
      case OrderSource.desktopPos:
        return Icons.point_of_sale_outlined;
      case OrderSource.manual:
        return Icons.edit_note_rounded;
      case OrderSource.localLan:
        return Icons.lan_outlined;
    }
  }
}

class _ChannelRow extends StatelessWidget {
  const _ChannelRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.fraction,
  });

  final IconData icon;
  final String label;
  final int count;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: PosColors.surfaceSunk,
            borderRadius: BorderRadius.circular(7),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: PosColors.text),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 88,
          child: TfText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: PosColors.text,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: PosColors.surfaceSunk,
              color: PosColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 20,
          child: TfText(
            tfFormatNumber(context, count),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: PosColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Advanced: pace to target ──────────────────────────────────────────────────

class _PaceCard extends StatelessWidget {
  const _PaceCard({
    required this.text,
    required this.liveRev,
    required this.target,
  });

  final AppStrings text;
  final double liveRev;
  final double target;

  @override
  Widget build(BuildContext context) {
    final pace = target <= 0 ? 0 : (liveRev / target * 100).round();
    // Expected-pace marker = fraction of the service window (11:00–23:00).
    final now = DateTime.now();
    final mins = now.hour * 60 + now.minute;
    const openMin = 11 * 60, closeMin = 23 * 60;
    final marker = ((mins - openMin) / (closeMin - openMin)).clamp(0.0, 1.0);
    final onTrack = pace >= (marker * 100);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TfText(
                  text.paceToTarget,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PosColors.text,
                  ),
                ),
              ),
              TfText(
                '${text.targetLabel} ${tfFormatCurrency(context, target)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: PosColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TfText(
                tfFormatCurrency(context, liveRev),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: PosColors.text,
                  letterSpacing: -0.4,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 8),
              TfText(
                '$pace%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: onTrack ? PosColors.success : PosColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: (pace / 100).clamp(0.0, 1.0),
                      minHeight: 10,
                      backgroundColor: PosColors.surfaceSunk,
                      color: PosColors.primary,
                    ),
                  ),
                  Positioned(
                    left: (w * marker).clamp(0.0, w - 2),
                    top: -2,
                    bottom: -2,
                    child: Container(width: 2, color: PosColors.primaryDark),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 7),
          TfText(
            text.expectedPaceNote,
            style: const TextStyle(fontSize: 11.5, color: PosColors.muted),
          ),
        ],
      ),
    );
  }
}

// ── Advanced: per-staff metrics ────────────────────────────────────────────────

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.text, required this.open});

  final AppStrings text;
  final List<OrderModel> open;

  @override
  Widget build(BuildContext context) {
    // Group open orders by the role that created them (real per-staff signal
    // until a full staff roster lands in Phase 4).
    final byRole = <String, _RoleAgg>{};
    for (final o in open) {
      final key = (o.createdByRole ?? '').trim().toLowerCase();
      final agg = byRole.putIfAbsent(key, () => _RoleAgg());
      agg.count += 1;
      agg.sales += o.total;
    }
    final rows = byRole.entries.toList()
      ..sort((a, b) => b.value.sales.compareTo(a.value.sales));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            text.ordersByStaff,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: PosColors.text,
            ),
          ),
          const SizedBox(height: 4),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TfText(
                text.noStaffActivity,
                style: const TextStyle(fontSize: 13, color: PosColors.muted),
              ),
            )
          else
            for (var i = 0; i < rows.length; i++)
              _StaffRow(
                text: text,
                roleKey: rows[i].key,
                count: rows[i].value.count,
                sales: rows[i].value.sales,
                first: i == 0,
              ),
        ],
      ),
    );
  }
}

class _RoleAgg {
  int count = 0;
  double sales = 0;
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.text,
    required this.roleKey,
    required this.count,
    required this.sales,
    required this.first,
  });

  final AppStrings text;
  final String roleKey;
  final int count;
  final double sales;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final role = AccountRole.parse(roleKey);
    final label = roleKey.isEmpty
        ? (text.isBn ? 'অনলাইন / স্বয়ংক্রিয়' : 'Online / auto')
        : (text.isBn ? role.labelBn : role.label);
    final initial = (label.isEmpty ? '?' : label.characters.first)
        .toUpperCase();
    return Container(
      margin: EdgeInsets.only(top: first ? 11 : 0),
      padding: EdgeInsets.only(top: first ? 0 : 11),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: first ? Colors.transparent : PosColors.line),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PosColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: TfText(
              initial,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: PosColors.accentStrong,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: PosColors.text,
                  ),
                ),
                const SizedBox(height: 1),
                TfText(
                  text.isBn
                      ? '$count টি অর্ডার'
                      : '$count ${count == 1 ? 'order' : 'orders'}',
                  style: const TextStyle(fontSize: 12, color: PosColors.muted),
                ),
              ],
            ),
          ),
          TfText(
            tfFormatCurrency(context, sales),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: PosColors.text,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
