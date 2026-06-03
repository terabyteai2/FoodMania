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

// Horizontal priority-zone divider with center chip.
class _DividerBand extends StatelessWidget {
  const _DividerBand({required this.en, required this.bn});
  final String en;
  final String bn;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        const Expanded(
          child: Divider(color: PosColors.lineStrong, thickness: 1, height: 1),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: PosColors.surface,
            border: Border.all(color: PosColors.lineStrong, width: 0.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: PosColors.mutedSoft,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                tfPick(context, en: en, bn: bn).toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: PosColors.muted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Divider(color: PosColors.lineStrong, thickness: 1, height: 1),
        ),
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
    this.onAction,
  });
  final String en;
  final String? bn;
  final int? count;
  final String? action;
  final String? actionBn;
  final VoidCallback? onAction;

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
          GestureDetector(
            onTap: onAction,
            child: Row(
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
                const Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: PosColors.muted,
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

// The hero earned-today card (surface card, ink text, 48px numericHero).
class _EarnedCard extends StatelessWidget {
  const _EarnedCard({
    required this.amount,
    required this.label,
    this.bn,
    this.deltaText,
    this.deltaUp = true,
    this.note,
  });

  final String amount;
  final String label;
  final String? bn;
  final String? deltaText;
  final bool deltaUp;
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
            if (deltaText != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: deltaUp ? PosColors.successSoft : PosColors.dangerSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      deltaUp ? '↑' : '↓',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: deltaUp ? PosColors.success : PosColors.danger,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      deltaText!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: deltaUp ? PosColors.success : PosColors.danger,
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
        if (note != null) ...[
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

// Tower tiles — 3-col live snapshot for T3.
class _TowerTile extends StatelessWidget {
  const _TowerTile({
    required this.value,
    this.valueSuffix,
    required this.sub,
    this.bn,
    this.tone = _TileTone.paper,
  });

  final String value;
  final String? valueSuffix;
  final String sub;
  final String? bn;
  final _TileTone tone;

  @override
  Widget build(BuildContext context) {
    final bg = switch (tone) {
      _TileTone.accent => PosColors.primarySoft,
      _TileTone.urgent => PosColors.urgentSoft,
      _TileTone.paper => PosColors.surface,
    };
    final fg = switch (tone) {
      _TileTone.accent => PosColors.primaryDark,
      _TileTone.urgent => PosColors.urgent,
      _TileTone.paper => PosColors.primaryDark,
    };
    final rail = switch (tone) {
      _TileTone.accent => PosColors.primary,
      _TileTone.urgent => PosColors.urgent,
      _TileTone.paper => PosColors.mutedSoft,
    };

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PosRadii.sm),
        border: Border.all(color: rail.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 2, color: rail),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        letterSpacing: -0.6,
                        height: 1.0,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                    if (valueSuffix != null)
                      Text(
                        valueSuffix!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: fg.withValues(alpha: 0.6),
                          height: 1.0,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tfPick(context, en: sub, bn: bn).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: fg.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                    height: 1.2,
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

enum _TileTone { accent, urgent, paper }

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

// Top-movers row with revenue bar.
class _MoverRow extends StatelessWidget {
  const _MoverRow({
    required this.rank,
    required this.name,
    required this.qty,
    required this.rev,
    required this.pct,
  });

  final int rank;
  final String name;
  final int qty;
  final String rev;
  final double pct;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      border: Border.all(color: PosColors.line, width: 0.5),
    ),
    child: Row(
      children: [
        Text(
          rank.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: PosColors.mutedSoft,
            letterSpacing: 0.4,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PosColors.primaryDark,
                      ),
                    ),
                  ),
                  Text(
                    rev,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PosColors.primaryDark,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: PosColors.surfaceSunk,
                        color: PosColors.inkSoft,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '×$qty',
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
        ),
      ],
    ),
  );
}

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
                color: actions[i].accent
                    ? PosColors.primary
                    : PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadii.sm),
                border: Border.all(
                  color: actions[i].accent ? PosColors.primary : PosColors.line,
                  width: 0.5,
                ),
                boxShadow: actions[i].accent ? PosShadows.glow : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: actions[i].accent
                          ? Colors.white.withValues(alpha: 0.16)
                          : PosColors.surfaceSunk,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      actions[i].icon,
                      size: 18,
                      color: actions[i].accent
                          ? Colors.white
                          : PosColors.primaryDark,
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
                      color: actions[i].accent
                          ? Colors.white
                          : PosColors.primaryDark,
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
  const _QAction({
    required this.icon,
    required this.label,
    this.accent = false,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final bool accent;
  final VoidCallback? onTap;
}

// Common loading / offline states.
Widget _buildLoading() => const Padding(
  padding: EdgeInsets.symmetric(vertical: 60),
  child: Center(child: CircularProgressIndicator(color: PosColors.primary)),
);

Widget _buildNoData(AppStrings text) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 40),
  child: Center(
    child: Text(
      text.isBn ? 'ডেটা লোড হয়নি' : 'No data yet',
      style: const TextStyle(color: PosColors.muted, fontSize: 14),
    ),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// TIER 1 — Counter (juice bar / tea stall)
// ─────────────────────────────────────────────────────────────────────────────

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

class _DashT1CounterState extends State<_DashT1Counter> {
  final List<DesktopMenuLineSelection> _cartLines = [];
  bool _creatingOrder = false;

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

  void _decrement(String itemId) {
    setState(() {
      final index = _cartLines.lastIndexWhere((line) => line.item.id == itemId);
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

  Future<void> _createOrder() async {
    if (_cartLines.isEmpty || _creatingOrder) return;
    setState(() => _creatingOrder = true);
    try {
      final order = await widget.app.createManualOrder(
        requestedItems: [for (final line in _cartLines) line.toRequestItem()],
        serviceType: OrderServiceType.takeaway,
        paymentMethod: null,
      );
      final shouldPrint =
          widget.app.orderPrinterSideEffectsEnabled &&
          widget.app.isManager &&
          !widget.app.printerState.autoPrintEnabled &&
          widget.app.printerState.hasSelectedPrinter &&
          !widget.app.printerService.hasPrintedOrder(order.id);
      if (shouldPrint) await widget.app.printOrderTicket(order);
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

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final onNavigate = widget.onNavigate;
    final summary = app.dashboardSummary as DashboardSummary?;
    final earned = summary?.moneyFirst.earnedToday ?? 0.0;
    final ordersCount = summary?.moneyFirst.kpis.orders ?? 0;
    final topMovers = summary?.moneyFirst.topMovers ?? [];

    final moneyFmt = NumberFormat('#,##0', 'en');
    final earnedStr = '৳${moneyFmt.format(earned)}';
    final menuItems = (app.menuItems as List<MenuItem>)
        .where((item) => item.isAvailable)
        .take(8)
        .toList(growable: false);
    final cartQtyByItemId = <String, int>{};
    for (final line in _cartLines) {
      cartQtyByItemId[line.item.id] =
          (cartQtyByItemId[line.item.id] ?? 0) + line.qty;
    }
    final cartQty = _cartLines.fold(0, (sum, line) => sum + line.qty);
    final cartTotal = _cartLines.fold<double>(
      0,
      (sum, line) => sum + line.lineTotal,
    );

    return Scaffold(
      backgroundColor: PosColors.background,
      bottomNavigationBar: _cartLines.isEmpty
          ? null
          : _SimpleCartTray(
              lines: _cartLines,
              totalQty: cartQty,
              total: cartTotal,
              busy: _creatingOrder,
              onPressed: _createOrder,
            ),
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
                bizName: app.serverConfig?.restaurantName ?? 'My Counter',
                onNavigateToOrders: () => onNavigate(_ordersTab),
                onNavigateToTarget: widget.onNavigateToTarget,
                mode: widget.mode,
                onModeChanged: widget.onModeChanged,
              ),

              // Cash-today strip
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: PosColors.surface,
                    borderRadius: BorderRadius.circular(PosRadii.md),
                    border: Border.all(color: PosColors.line, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _MicroLabel('Cash drawer · today'),
                            const SizedBox(height: 5),
                            Text(
                              earnedStr,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w600,
                                color: PosColors.primaryDark,
                                letterSpacing: -0.8,
                                height: 1.0,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$ordersCount orders',
                              style: const TextStyle(
                                fontSize: 11,
                                color: PosColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: PosColors.surfaceSunk,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: PosColors.line, width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: PosColors.mutedSoft,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'ALL CASH',
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                color: PosColors.muted,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sell grid header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Ring it up',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: PosColors.primaryDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onNavigate(1),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Edit items',
                            style: TextStyle(
                              fontSize: 12,
                              color: PosColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            size: 14,
                            color: PosColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'Tap items to build an order, then create it.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: PosColors.muted,
                    height: 1.4,
                  ),
                ),
              ),

              // Menu grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Builder(
                  builder: (context) {
                    if (menuItems.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: PosColors.surface,
                          borderRadius: BorderRadius.circular(PosRadii.md),
                          border: Border.all(color: PosColors.line, width: 0.5),
                        ),
                        child: const Center(
                          child: Text(
                            'No items yet',
                            style: TextStyle(color: PosColors.muted),
                          ),
                        ),
                      );
                    }
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: 1.1,
                          ),
                      itemCount: menuItems.length,
                      itemBuilder: (ctx, i) {
                        final item = menuItems[i];
                        final price = '৳${moneyFmt.format(item.price)}';
                        return _SellTile(
                          item: item,
                          price: price,
                          qty: cartQtyByItemId[item.id] ?? 0,
                          onTap: () => unawaited(_increment(item)),
                          onDecrement: () => _decrement(item.id),
                        );
                      },
                    );
                  },
                ),
              ),

              // Divider
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: _DividerBand(en: 'Today so far', bn: 'আজকের হিসাব'),
              ),

              // Top items
              if (topMovers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SecHead(
                        en: 'Top items',
                        bn: 'টপ আইটেম',
                        action: 'See all',
                        onAction: () => onNavigate(_settingsTab),
                      ),
                      for (int i = 0; i < topMovers.take(3).length; i++)
                        _MoverRow(
                          rank: i + 1,
                          name: topMovers[i].nameEn,
                          qty: topMovers[i].qty,
                          rev: '৳${moneyFmt.format(topMovers[i].salesBdt)}',
                          pct: topMovers.isNotEmpty
                              ? (topMovers[i].salesBdt /
                                        (topMovers.first.salesBdt.abs() + 1))
                                    .clamp(0, 1)
                              : 0,
                        ),
                    ],
                  ),
                ),

              // Close card
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: _CloseCard(
                  title: tfPick(
                    context,
                    en: 'Close counter · $earnedStr',
                    bn: 'কাউন্টার বন্ধ করুন · $earnedStr',
                  ),
                  kicker: tfPick(context, en: 'End of day', bn: 'দিন শেষ'),
                  warn: (summary?.moneyFirst.kpis.openOrders ?? 0) > 0
                      ? tfPick(
                          context,
                          en: '${summary!.moneyFirst.kpis.openOrders} items in current order - clear before closing',
                          bn: 'বর্তমান অর্ডারে ${summary.moneyFirst.kpis.openOrders} টি আইটেম আছে - বন্ধ করার আগে পরিষ্কার করুন',
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Sell tile for T1 counter grid.
class _SellTile extends StatelessWidget {
  const _SellTile({
    required this.item,
    required this.price,
    required this.qty,
    required this.onTap,
    required this.onDecrement,
  });

  final MenuItem item;
  final String price;
  final int qty;
  final VoidCallback onTap;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final selected = qty > 0;
    final iconKey = resolveMenuIconKey(
      iconKey: item.extras.iconKey,
      name: item.name,
      category: item.category,
    );
    return Material(
      color: selected ? PosColors.primarySoft : PosColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.md),
        side: BorderSide(
          color: selected ? PosColors.primarySoft : PosColors.line,
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('ring-it-up-${item.name}'),
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 58,
                        height: 58,
                        child: MenuImageView(
                          imageUrl: item.imageUrl,
                          iconKey: iconKey,
                        ),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: PosColors.primaryDark,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PosColors.primaryDark,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: selected
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          key: ValueKey('ring-it-up-decrement-${item.name}'),
                          onTap: onDecrement,
                          child: const SizedBox(
                            width: 24,
                            height: 24,
                            child: Icon(
                              Icons.remove_circle_outline_rounded,
                              size: 21,
                              color: PosColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: PosColors.primaryDark,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$qty',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Icon(Icons.add, size: 22, color: PosColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimpleCartTray extends StatelessWidget {
  const _SimpleCartTray({
    required this.lines,
    required this.totalQty,
    required this.total,
    required this.busy,
    required this.onPressed,
  });

  final List<DesktopMenuLineSelection> lines;
  final int totalQty;
  final double total;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final language = AppScope.of(context).language;
    final summary = lines
        .take(2)
        .map((line) => '${line.localizedDisplayName(language)} ×${line.qty}')
        .join(' · ');
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: PosColors.background,
          boxShadow: PosShadows.raised,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.md),
            border: Border.all(color: PosColors.line, width: 0.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MicroLabel('$totalQty items · current order'),
                    const SizedBox(height: 3),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: PosColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              TfButton(
                key: const ValueKey('ring-it-up-cart'),
                label: tfPick(
                  context,
                  en: 'Create order',
                  bn: 'অর্ডার তৈরি করুন',
                ),
                icon: Icons.check_rounded,
                fullWidth: false,
                busy: busy,
                onPressed: busy ? null : onPressed,
              ),
              const SizedBox(width: 8),
              Text(
                '৳${NumberFormat('#,##0', 'en').format(total)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PosColors.primaryDark,
                  fontFeatures: [FontFeature.tabularFigures()],
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
// TIER 2 — Small dine-in (café)
// ─────────────────────────────────────────────────────────────────────────────

class _DashT2Standard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final text = app.strings as AppStrings;
    final summary = app.dashboardSummary as DashboardSummary?;
    final money = summary?.moneyFirst;
    final right = summary?.rightNow;
    final moneyFmt = NumberFormat('#,##0', 'en');
    final earned = money?.earnedToday ?? 0.0;
    final earnedStr = '৳${moneyFmt.format(earned)}';
    final topMovers = money?.topMovers ?? [];
    final alerts = right?.needsAttention ?? [];

    return Scaffold(
      backgroundColor: PosColors.background,
      floatingActionButton:
          app.isManager && (app.menuItems as List).any((i) => i.isAvailable)
          ? TfFab(
              tooltip: text.newOrder,
              onPressed: () =>
                  openNewOrderForm(context, onCreated: () => onNavigate(0)),
            )
          : null,
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
              ),

              if (summary == null && app.dashboardSummaryLoading)
                _buildLoading()
              else if (summary == null)
                _buildNoData(text)
              else ...[
                // 1 · Hero — earned today
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _EarnedCard(
                    amount: earnedStr,
                    label: 'Earned today',
                    bn: 'আজকের আয়',
                    deltaText: money?.deltaPct != null
                        ? tfPick(
                            context,
                            en: '${money!.deltaPct.abs().round()}% vs yest',
                            bn: '${money.deltaPct.abs().round()}% বনাম গতকাল',
                          )
                        : null,
                    deltaUp: (money?.deltaPct ?? 0) >= 0,
                    note:
                        money?.earnedToday != null && (money?.deltaPct ?? 0) > 0
                        ? tfPick(
                            context,
                            en: '৳${moneyFmt.format((money!.earnedToday * (money.deltaPct / 100)).abs().round())} over yesterday',
                            bn: 'গতকালের চেয়ে ৳${moneyFmt.format((money.earnedToday * (money.deltaPct / 100)).abs().round())} বেশি',
                          )
                        : null,
                  ),
                ),

                // 2 · KPI pair — Orders · Covers
                if (money != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _KpiStrip(
                      stats: [
                        _KpiStat(
                          tfPick(context, en: 'Orders', bn: 'অর্ডার'),
                          '${money.kpis.orders}',
                        ),
                        _KpiStat(
                          tfPick(context, en: 'Covers', bn: 'অতিথি'),
                          '${right?.tablesSeated ?? 0}',
                        ),
                      ],
                    ),
                  ),

                _FohCounter(
                  items: (app.menuItems as List<MenuItem>)
                      .where((item) => item.isAvailable)
                      .take(3)
                      .toList(),
                  onTap: () =>
                      openNewOrderForm(context, onCreated: () => onNavigate(0)),
                ),

                // 3 · Floor (if table data available)
                if ((right?.tablesTotal ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SecHead(
                          en: 'Floor',
                          bn: 'টেবিল',
                          action:
                              '${right!.tablesSeated} of ${right.tablesTotal} busy',
                        ),
                        _FloorGrid(
                          tables: right.floorTables.isNotEmpty
                              ? right.floorTables
                              : List.generate(
                                  right.tablesTotal,
                                  (index) => FloorTable(
                                    tableNo: '${index + 1}',
                                    state: index < right.tablesSeated
                                        ? 'seated'
                                        : 'idle',
                                    covers: 0,
                                    orderId: null,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                // 4 · Alerts
                if (alerts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SecHead(
                          en: 'Needs you',
                          bn: 'নজর দিন',
                          count: alerts.length,
                        ),
                        for (final a in alerts)
                          _AlertRow(
                            tag: a.kind.toUpperCase(),
                            tone: a.kind == 'late'
                                ? _AlertTone.late
                                : (a.kind == 'low'
                                      ? _AlertTone.low
                                      : _AlertTone.info),
                            title: a.title,
                            sub: a.body,
                            cta: 'Check',
                            onCta: () => onNavigate(
                              a.kind == 'late' ? _ordersTab : _stockTab,
                            ),
                          ),
                      ],
                    ),
                  ),

                // 5 · Quick actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _QuickActions(
                    actions: [
                      _QAction(
                        icon: Icons.add,
                        label: tfPick(
                          context,
                          en: 'New order',
                          bn: 'নতুন অর্ডার',
                        ),
                        accent: true,
                        onTap: () => openNewOrderForm(
                          context,
                          onCreated: () => onNavigate(0),
                        ),
                      ),
                      _QAction(
                        icon: Icons.print_outlined,
                        label: tfPick(
                          context,
                          en: 'Print bill',
                          bn: 'বিল প্রিন্ট',
                        ),
                        onTap: () => onNavigate(_ordersTab),
                      ),
                    ],
                  ),
                ),

                // Divider
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 22, 16, 0),
                  child: _DividerBand(en: 'Review', bn: 'পর্যালোচনা'),
                ),

                // 6 · Top items
                if (topMovers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SecHead(
                          en: 'Top items',
                          bn: 'টপ আইটেম',
                          action: 'See all',
                        ),
                        for (int i = 0; i < topMovers.take(3).length; i++)
                          _MoverRow(
                            rank: i + 1,
                            name: topMovers[i].nameEn,
                            qty: topMovers[i].qty,
                            rev: '৳${moneyFmt.format(topMovers[i].salesBdt)}',
                            pct:
                                (topMovers[i].salesBdt /
                                        (topMovers.first.salesBdt.abs() + 1))
                                    .clamp(0, 1),
                          ),
                      ],
                    ),
                  ),

                // 7 · Close card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: _CloseCard(
                    title: tfPick(
                      context,
                      en: 'Close day · $earnedStr',
                      bn: 'দিন শেষ করুন · $earnedStr',
                    ),
                    kicker: tfPick(context, en: 'End of day', bn: 'দিন শেষ'),
                    warn: summary.moneyFirst.kpis.openOrders > 0
                        ? tfPick(
                            context,
                            en: '${summary.moneyFirst.kpis.openOrders} orders still open - settle before closing',
                            bn: '${summary.moneyFirst.kpis.openOrders} টি অর্ডার খোলা আছে - বন্ধ করার আগে নিষ্পত্তি করুন',
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FloorGrid extends StatelessWidget {
  const _FloorGrid({required this.tables});
  final List<FloorTable> tables;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: tables.length,
      itemBuilder: (_, i) {
        final table = tables[i];
        final state = switch (table.state) {
          'bill' => _TableState.bill,
          'seated' => _TableState.seated,
          _ => _TableState.idle,
        };
        final bg = switch (state) {
          _TableState.seated => PosColors.primarySoft,
          _TableState.bill => PosColors.warningSoft,
          _TableState.idle => PosColors.surface,
        };
        final fg = switch (state) {
          _TableState.seated => PosColors.primaryDark,
          _TableState.bill => PosColors.warning,
          _TableState.idle => PosColors.muted,
        };
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(PosRadii.sm),
            border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'T${table.tableNo}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: fg,
                        fontFeatures: [const FontFeature.tabularFigures()],
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: fg,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Text(
                  state == _TableState.idle
                      ? 'IDLE'
                      : (state == _TableState.bill
                            ? 'BILL'
                            : '${table.covers} COVERS'),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: fg.withValues(alpha: 0.8),
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

enum _TableState { idle, seated, bill }

class _FohCounter extends StatelessWidget {
  const _FohCounter({required this.items, required this.onTap});
  final List<MenuItem> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SecHead(en: 'FOH counter', action: 'New order'),
          Row(
            children: [
              for (int index = 0; index < items.length; index++) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(
                  child: Material(
                    color: PosColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PosRadii.md),
                      side: const BorderSide(color: PosColors.line, width: 0.5),
                    ),
                    child: InkWell(
                      key: ValueKey('foh-counter-${items[index].name}'),
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(PosRadii.md),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[index].name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: PosColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _bdt(items[index].price),
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

// ─────────────────────────────────────────────────────────────────────────────
// TIER 3 — Full-service restaurant
// ─────────────────────────────────────────────────────────────────────────────

class _DashT3Full extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final text = app.strings as AppStrings;
    final summary = app.dashboardSummary as DashboardSummary?;
    final money = summary?.moneyFirst;
    final right = summary?.rightNow;
    final moneyFmt = NumberFormat('#,##0', 'en');
    final earned = money?.earnedToday ?? 0.0;
    final earnedStr = '৳${moneyFmt.format(earned)}';
    final topMovers = money?.topMovers ?? [];
    final alerts = right?.needsAttention ?? [];

    return Scaffold(
      backgroundColor: PosColors.background,
      floatingActionButton: app.isManager
          ? TfFab(
              tooltip: text.newOrder,
              onPressed: () =>
                  openNewOrderForm(context, onCreated: () => onNavigate(0)),
            )
          : null,
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
              ),

              if (summary == null && app.dashboardSummaryLoading)
                _buildLoading()
              else if (summary == null)
                _buildNoData(text)
              else ...[
                // 1 · Hero
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _EarnedCard(
                    amount: earnedStr,
                    label: 'Earned today',
                    bn: 'আজকের আয়',
                    deltaText: money?.deltaPct != null
                        ? tfPick(
                            context,
                            en: '${money!.deltaPct.abs().round()}% vs yest',
                            bn: '${money.deltaPct.abs().round()}% বনাম গতকাল',
                          )
                        : null,
                    deltaUp: (money?.deltaPct ?? 0) >= 0,
                    note:
                        money?.earnedToday != null && (money?.deltaPct ?? 0) > 0
                        ? tfPick(
                            context,
                            en: '৳${moneyFmt.format((money!.earnedToday * (money.deltaPct / 100)).abs().round())} over yesterday',
                            bn: 'গতকালের চেয়ে ৳${moneyFmt.format((money.earnedToday * (money.deltaPct / 100)).abs().round())} বেশি',
                          )
                        : null,
                  ),
                ),

                // 2 · Live snapshot tower
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SecHead(en: 'Right now', bn: 'এখন'),
                      Row(
                        children: [
                          Expanded(
                            child: _TowerTile(
                              value: '${right?.tablesSeated ?? 0}',
                              valueSuffix: '/${right?.tablesTotal ?? 0}',
                              sub: 'Tables seated',
                              bn: 'টেবিল',
                              tone: _TileTone.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TowerTile(
                              value: '${right?.ordersInKitchen ?? 0}',
                              sub: 'In kitchen',
                              bn: 'কিচেনে',
                              tone: _TileTone.paper,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TowerTile(
                              value: '${right?.lateOrders ?? 0}',
                              sub: 'Late >20m',
                              bn: 'দেরি',
                              tone: (right?.lateOrders ?? 0) > 0
                                  ? _TileTone.urgent
                                  : _TileTone.paper,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                _FohCounter(
                  items: (app.menuItems as List<MenuItem>)
                      .where((item) => item.isAvailable)
                      .take(3)
                      .toList(),
                  onTap: () =>
                      openNewOrderForm(context, onCreated: () => onNavigate(0)),
                ),

                // 3 · Alerts
                if (alerts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SecHead(
                          en: 'Needs you',
                          bn: 'আপনার নজর চাই',
                          count: alerts.length,
                        ),
                        for (final a in alerts)
                          _AlertRow(
                            tag: a.kind.toUpperCase(),
                            tone: a.kind == 'late'
                                ? _AlertTone.late
                                : (a.kind == 'low'
                                      ? _AlertTone.low
                                      : _AlertTone.info),
                            title: a.title,
                            sub: a.body,
                            cta: 'Check',
                            onCta: () => onNavigate(
                              a.kind == 'late' ? _ordersTab : _stockTab,
                            ),
                          ),
                      ],
                    ),
                  ),

                // 4 · Quick actions (4 tiles)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _QuickActions(
                    actions: [
                      _QAction(
                        icon: Icons.add,
                        label: tfPick(
                          context,
                          en: 'New order',
                          bn: 'নতুন অর্ডার',
                        ),
                        accent: true,
                        onTap: () => openNewOrderForm(
                          context,
                          onCreated: () => onNavigate(0),
                        ),
                      ),
                      _QAction(
                        icon: Icons.print_outlined,
                        label: tfPick(
                          context,
                          en: 'Print bill',
                          bn: 'বিল প্রিন্ট',
                        ),
                        onTap: () => onNavigate(_ordersTab),
                      ),
                      _QAction(
                        icon: Icons.notifications_outlined,
                        label: tfPick(
                          context,
                          en: 'Call waiter',
                          bn: 'ওয়েটার ডাকুন',
                        ),
                      ),
                      _QAction(
                        icon: Icons.bar_chart_outlined,
                        label: tfPick(context, en: 'Reports', bn: 'রিপোর্ট'),
                        onTap: () => onNavigate(_settingsTab),
                      ),
                    ],
                  ),
                ),

                // Divider
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 22, 16, 0),
                  child: _DividerBand(en: 'Review', bn: 'পর্যালোচনা'),
                ),

                if (money != null && money.serviceMix.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SecHead(
                          en: 'Order channels',
                          bn: 'অর্ডার চ্যানেল',
                        ),
                        _SourceChips(rows: money.serviceMix),
                      ],
                    ),
                  ),

                // 5 · KPI strip: Orders · Covers · Avg Ticket · FC%
                if (money != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: _KpiStrip(
                      stats: [
                        _KpiStat(
                          tfPick(context, en: 'Orders', bn: 'অর্ডার'),
                          '${money.kpis.orders}',
                        ),
                        _KpiStat(
                          tfPick(context, en: 'Covers', bn: 'অতিথি'),
                          '${right?.tablesSeated ?? 0}',
                        ),
                        _KpiStat(
                          tfPick(context, en: 'Avg ticket', bn: 'গড় বিল'),
                          '৳${money.kpis.avgTicket.round()}',
                        ),
                        _KpiStat(
                          tfPick(context, en: 'Food cost', bn: 'খাবারের খরচ'),
                          '${money.kpis.profitPct.toStringAsFixed(1)}%',
                        ),
                      ],
                    ),
                  ),

                // 6 · Top movers
                if (topMovers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SecHead(
                          en: 'Top movers',
                          bn: 'টপ আইটেম',
                          action: 'See all',
                          actionBn: 'সব দেখুন',
                        ),
                        for (int i = 0; i < topMovers.take(3).length; i++)
                          _MoverRow(
                            rank: i + 1,
                            name: topMovers[i].nameEn,
                            qty: topMovers[i].qty,
                            rev: '৳${moneyFmt.format(topMovers[i].salesBdt)}',
                            pct:
                                (topMovers[i].salesBdt /
                                        (topMovers.first.salesBdt.abs() + 1))
                                    .clamp(0, 1),
                          ),
                      ],
                    ),
                  ),

                // 7 · Close / shift handover
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: _CloseCard(
                    title: tfPick(
                      context,
                      en: 'Close shift · hand over',
                      bn: 'শিফট বন্ধ করে হস্তান্তর করুন',
                    ),
                    kicker: tfPick(
                      context,
                      en: 'Shift handover · $earnedStr',
                      bn: 'শিফট হস্তান্তর · $earnedStr',
                    ),
                    warn: summary.moneyFirst.kpis.openOrders > 0
                        ? tfPick(
                            context,
                            en: '${summary.moneyFirst.kpis.openOrders} open orders carry to next shift',
                            bn: '${summary.moneyFirst.kpis.openOrders} টি খোলা অর্ডার পরের শিফটে যাবে',
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIER 4 — Multi-unit fleet
// ─────────────────────────────────────────────────────────────────────────────

class _DashT4Fleet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final text = app.strings as AppStrings;
    final summary = app.dashboardSummary as DashboardSummary?;
    final money = summary?.moneyFirst;
    final moneyFmt = NumberFormat('#,##0', 'en');
    final earned = money?.earnedToday ?? 0.0;
    final earnedStr = '৳${moneyFmt.format(earned)}';
    final fleet = summary?.review?.fleet;
    final fleetKpis = fleet?.kpis;

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
                bizName: '${app.serverConfig?.restaurantName ?? "Fleet"} Group',
                onNavigateToOrders: () => onNavigate(_ordersTab),
                onNavigateToTarget: onNavigateToTarget,
                mode: mode,
                onModeChanged: onModeChanged,
              ),

              if (summary == null && app.dashboardSummaryLoading)
                _buildLoading()
              else if (summary == null)
                _buildNoData(text)
              else ...[
                // 1 · Fleet goal card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: _GoalCard(
                    amount: earnedStr,
                    label: 'Fleet revenue · today',
                    bn: 'আজকের সব আউটলেটের আয়',
                    sub: tfPick(
                      context,
                      en: 'Across all outlets',
                      bn: 'সব আউটলেট মিলিয়ে',
                    ),
                    pct: fleet?.goal.progressPct ?? 0,
                    goal: '৳${moneyFmt.format(fleet?.goal.targetBdt ?? 0)}',
                  ),
                ),

                // 2 · Fleet KPI strip
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: _KpiStrip(
                    stats: [
                      _KpiStat(
                        tfPick(context, en: 'Outlets', bn: 'আউটলেট'),
                        '${fleetKpis?.outletCount ?? 0}',
                      ),
                      _KpiStat(
                        tfPick(context, en: 'Covers', bn: 'অতিথি'),
                        '${fleetKpis?.covers ?? 0}',
                      ),
                      _KpiStat(
                        tfPick(context, en: 'Avg ticket', bn: 'গড় বিল'),
                        '৳${moneyFmt.format(fleetKpis?.avgTicketBdt ?? 0)}',
                      ),
                      _KpiStat(
                        tfPick(
                          context,
                          en: 'Fleet late',
                          bn: 'সব আউটলেটে দেরি',
                        ),
                        '${fleetKpis?.fleetLatePct ?? 0}%',
                        color: (fleetKpis?.fleetLatePct ?? 0) > 0
                            ? PosColors.urgent
                            : null,
                      ),
                    ],
                  ),
                ),

                // 3 · Fleet alerts
                if (fleet?.alerts.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SecHead(
                          en: 'Fleet alerts',
                          bn: 'সব আউটলেটের সতর্কতা',
                          count: fleet!.alerts.length,
                        ),
                        for (final a in fleet.alerts)
                          _AlertRow(
                            tag: a.kind.toUpperCase(),
                            tone: a.kind == 'stuck'
                                ? _AlertTone.late
                                : (a.kind == 'low'
                                      ? _AlertTone.low
                                      : _AlertTone.info),
                            title: a.title,
                            sub: a.body,
                            cta: tfPick(context, en: 'View', bn: 'দেখুন'),
                            onCta: () => onNavigate(_ordersTab),
                          ),
                      ],
                    ),
                  ),

                // 4 · Outlet leaderboard (uses topMovers as proxy data until fleet model available)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SecHead(
                        en: 'Outlets today',
                        bn: 'আউটলেট',
                        action: 'Ranked',
                        actionBn: 'ক্রম অনুযায়ী',
                      ),
                      for (final outlet
                          in fleet?.outlets ?? const <FleetOutlet>[])
                        _OutletCard(
                          name: outlet.name,
                          area: outlet.area,
                          rev: '৳${moneyFmt.format(outlet.revBdt)}',
                          deltaUp: outlet.deltaUp,
                          delta: '${outlet.deltaPct.round()}%',
                          occ: '${outlet.occupancyPct}%',
                          late: '${outlet.latePct}%',
                          isTop: outlet.rank == 1,
                        ),
                    ],
                  ),
                ),

                // Divider
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 22, 16, 0),
                  child: _DividerBand(en: 'Review', bn: 'পর্যালোচনা'),
                ),

                if (fleet != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SecHead(en: 'Benchmarks', bn: 'তুলনামূলক মান'),
                        _FleetNote(
                          title: fleet.benchmarks.bestAvgTicketOutlet.isEmpty
                              ? tfPick(
                                  context,
                                  en: 'No benchmark yet',
                                  bn: 'এখনো তুলনামূলক মান নেই',
                                )
                              : tfPick(
                                  context,
                                  en: '${fleet.benchmarks.bestAvgTicketOutlet} leads average ticket',
                                  bn: '${fleet.benchmarks.bestAvgTicketOutlet} গড় বিলে এগিয়ে',
                                ),
                          body: fleet.benchmarks.worstLateOutlet.isEmpty
                              ? tfPick(
                                  context,
                                  en: 'No late-order pressure right now',
                                  bn: 'এখন দেরি হওয়া অর্ডারের চাপ নেই',
                                )
                              : tfPick(
                                  context,
                                  en: '${fleet.benchmarks.worstLateOutlet} has the highest late-order rate',
                                  bn: '${fleet.benchmarks.worstLateOutlet}-এ দেরি হওয়া অর্ডারের হার সবচেয়ে বেশি',
                                ),
                        ),
                        if (fleet.staffingSuggestion.outletName.isNotEmpty)
                          _FleetNote(
                            title: tfPick(
                              context,
                              en: 'Staffing suggestion · ${fleet.staffingSuggestion.outletName}',
                              bn: 'স্টাফ পরামর্শ · ${fleet.staffingSuggestion.outletName}',
                            ),
                            body: fleet.staffingSuggestion.peakLabel.isEmpty
                                ? tfPick(
                                    context,
                                    en: 'Watch the next service peak',
                                    bn: 'পরবর্তী ব্যস্ত সময় নজরে রাখুন',
                                  )
                                : tfPick(
                                    context,
                                    en: 'Plan cover around ${fleet.staffingSuggestion.peakLabel}',
                                    bn: '${fleet.staffingSuggestion.peakLabel} সময়ের অতিথির জন্য পরিকল্পনা করুন',
                                  ),
                          ),
                      ],
                    ),
                  ),

                // 6 · Fleet day-end
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: _CloseCard(
                    title: tfPick(
                      context,
                      en: 'Fleet day-end · all outlets',
                      bn: 'সব আউটলেটের দিন শেষ',
                    ),
                    kicker: tfPick(
                      context,
                      en: 'Roll up the group',
                      bn: 'সমগ্র হিসাব প্রস্তুত করুন',
                    ),
                    warn: fleet?.openOutlets.isNotEmpty == true
                        ? tfPick(
                            context,
                            en: '${fleet!.openOutlets.length} outlets still have open orders',
                            bn: '${fleet.openOutlets.length} টি আউটলেটে এখনো খোলা অর্ডার আছে',
                          )
                        : null,
                  ),
                ),
              ],
            ],
          ),
        ),
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
