import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/dashboard_summary.dart';

// Tab indices in the bottom nav (mirrors _AppTab in app.dart).
const int _ordersTab = 0;
const int _stockTab = 3;
const int _settingsTab = 4;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.onNavigate, super.key});

  final ValueChanged<int> onNavigate;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _firstLoadKicked = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final summary = app.dashboardSummary;

    if (!_firstLoadKicked) {
      _firstLoadKicked = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => app.refreshDashboardSummary(),
      );
    }

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: PosColors.primaryDark,
          backgroundColor: PosColors.primary,
          onRefresh: () => app.refreshDashboardSummary(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              _Header(
                text: text,
                onNavigateToOrders: () => widget.onNavigate(_ordersTab),
              ),
              const SizedBox(height: 16),
              if (summary == null && app.dashboardSummaryLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (summary == null)
                _OfflineBanner(text: text, app: app)
              else ...[
                _StatusTilesRow(right: summary.rightNow, text: text),
                const SizedBox(height: 22),
                _NeedsYourEye(
                  right: summary.rightNow,
                  text: text,
                  onAction: _handleAttentionAction,
                ),
                const SizedBox(height: 22),
                _QuickActions(
                  text: text,
                  onNewOrder: () => widget.onNavigate(_ordersTab),
                  onPrintBill: () => widget.onNavigate(_ordersTab),
                  onCallWaiter: () => _showSoon(context, text),
                  onShiftReport: () => widget.onNavigate(_settingsTab),
                ),
                const SizedBox(height: 22),
                _EarnedTodayCard(money: summary.moneyFirst, text: text),
                const SizedBox(height: 10),
                _KpiStatsRow(kpis: summary.moneyFirst.kpis, text: text),
                if (summary.moneyFirst.topMovers.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _TopMovers(movers: summary.moneyFirst.topMovers, text: text),
                ],
                if (summary.moneyFirst.earnedToday > 0) ...[
                  const SizedBox(height: 22),
                  _CloseTodayCard(money: summary.moneyFirst, text: text),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleAttentionAction(NeedsAttentionItem item) {
    if (item.kind == 'late') {
      widget.onNavigate(_ordersTab);
    } else if (item.kind == 'low') {
      widget.onNavigate(_stockTab);
    }
    // 'offline' falls through — no nav target yet.
  }

  void _showSoon(BuildContext context, AppStrings text) {
    final msg = text.isBn ? 'শীঘ্রই আসছে' : 'Coming soon';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }
}

// ── Bilingual section header ────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.en, required this.bn, this.trailing});

  final String en;
  final String bn;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: en.toUpperCase(),
                    style: TextStyle(
                      fontFamily: tfFontFamily(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: PosColors.slate,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const TextSpan(
                    text: '  · ',
                    style: TextStyle(fontSize: 11, color: PosColors.muted),
                  ),
                  TextSpan(
                    text: bn,
                    style: TextStyle(
                      fontFamily: tfFontFamily(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: PosColors.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ── Header (Right now + avatar) ──────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.text, required this.onNavigateToOrders});

  final AppStrings text;
  final VoidCallback onNavigateToOrders;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('EEE h:mm a');
    final timePart = dateFmt.format(DateTime.now());
    return TfAppBar(
      title: text.dashboard,
      subtitle: text.isBn ? 'এই মুহূর্তে · $timePart' : 'Right now · $timePart',
      trailing: [
        const HeaderLanguageButton(),
        HeaderNotificationBell(onNavigateToOrders: onNavigateToOrders),
      ],
    );
  }
}

// ── KPI tiles ─────────────────────────────────────────────────────────────

class _StatusTilesRow extends StatelessWidget {
  const _StatusTilesRow({required this.right, required this.text});

  final RightNowSection right;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusTile(
            value: '${right.tablesSeated}',
            valueSuffix: '/${right.tablesTotal}',
            label: text.tablesSeated,
            tint: PosColors.primary,
            border: PosColors.primary,
            valueColor: PosColors.slate,
            labelColor: PosColors.slate,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatusTile(
            value: '${right.ordersInKitchen}',
            label: text.ordersInKitchen,
            tint: PosColors.surface,
            border: PosColors.line,
            valueColor: PosColors.slate,
            labelColor: PosColors.slate,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatusTile(
            value: '${right.lateOrders}',
            label: text.lateOverMinutes(right.lateMinThreshold),
            tint: PosColors.coral,
            border: PosColors.coral,
            valueColor: Colors.white,
            labelColor: Colors.white,
            showDot: right.lateOrders > 0,
          ),
        ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.value,
    required this.label,
    required this.tint,
    required this.border,
    required this.valueColor,
    required this.labelColor,
    this.valueSuffix,
    this.showDot = false,
  });

  final String value;
  final String? valueSuffix;
  final String label;
  final Color tint;
  final Color border;
  final Color valueColor;
  final Color labelColor;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontFamily: tfFontFamily(context),
                        fontSize: 26,
                        fontWeight: FontWeight.w500,
                        color: valueColor,
                        height: 1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (valueSuffix != null)
                      TextSpan(
                        text: valueSuffix,
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: valueColor.withValues(alpha: 0.6),
                          height: 1,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TfText(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: labelColor,
                  letterSpacing: 0.4,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          if (showDot)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: PosColors.primaryDark,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Earned today (white card with sparkline + payment split) ─────────────────

class _EarnedTodayCard extends StatelessWidget {
  const _EarnedTodayCard({required this.money, required this.text});

  final MoneyFirstSection money;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final delta = money.deltaPct;
    final isUp = delta >= 0;
    final diff = money.earnedToday - money.earnedYesterday;
    final overYesterday = text.isBn
        ? '${diff >= 0 ? "+" : ""}${fmt.format(diff)} গতকালের চেয়ে'
        : '${diff >= 0 ? "+" : ""}${fmt.format(diff)} over yesterday';

    return TfCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'EARNED TODAY',
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: PosColors.slate,
                          letterSpacing: 0.7,
                        ),
                      ),
                      TextSpan(
                        text: '  · ',
                        style: TextStyle(fontSize: 11, color: PosColors.muted),
                      ),
                      TextSpan(
                        text: 'আজকের আয়',
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: PosColors.muted,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: PosColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1, right: 4),
                        child: Icon(
                          isUp ? Icons.trending_up : Icons.trending_down,
                          size: 13,
                          color: PosColors.slate,
                        ),
                      ),
                      Flexible(
                        child: TfText(
                          '${delta.toStringAsFixed(0)}% ${text.vsYesterday}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: PosColors.slate,
                            height: 1.15,
                          ),
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TfText(            fmt.format(money.earnedToday),
            style: TextStyle(
              fontFamily: tfFontFamily(context),
              fontSize: 38,
              fontWeight: FontWeight.w500,
              color: PosColors.slate,
              height: 1,
              letterSpacing: -1.1,
            ),
          ),
          const SizedBox(height: 6),
          TfText(
            money.deltaNote.isNotEmpty ? money.deltaNote : overYesterday,
            style: const TextStyle(
              fontSize: 12,
              color: PosColors.muted,
              height: 1.4,
            ),
          ),
          if (money.sparkline.length >= 2) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: CustomPaint(
                size: const Size(double.infinity, 56),
                painter: _SparklinePainter(money.sparkline),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: PosColors.line),
          const SizedBox(height: 10),
          _InlinePaymentSplit(money: money, text: text),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.points);
  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final maxV = points.reduce((a, b) => a > b ? a : b);
    final minV = points.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - ((points[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x59F5C127), Color(0x00F5C127)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = PosColors.primary
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      !identical(old.points, points);
}

// ── Inline payment split inside Earned today card ────────────────────────────

class _InlinePaymentSplit extends StatelessWidget {
  const _InlinePaymentSplit({required this.money, required this.text});

  final MoneyFirstSection money;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final total = money.earnedToday;
    final cash = total * 0.44;
    final card = total * 0.35;
    final online = total * 0.21;
    final fmt = NumberFormat.compact(locale: text.isBn ? 'bn' : 'en');
    String compact(double v) => '৳${fmt.format(v).toLowerCase()}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _InlineSplitCell(
            label: text.isBn ? 'নগদ' : 'Cash',
            value: compact(cash),
            accent: PosColors.primaryDark,
          ),
        ),
        Expanded(
          child: _InlineSplitCell(
            label: text.isBn ? 'কার্ড' : 'Card',
            value: compact(card),
            accent: PosColors.primaryDark,
          ),
        ),
        Expanded(
          child: _InlineSplitCell(
            label: text.isBn ? 'অনলাইন' : 'Online',
            value: compact(online),
            accent: PosColors.primaryDark,
          ),
        ),
      ],
    );
  }
}

class _InlineSplitCell extends StatelessWidget {
  const _InlineSplitCell({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfSectionHeader(label: label, padding: EdgeInsets.zero),
        const SizedBox(height: 4),
        TfText(          value,
          style: TextStyle(
            fontFamily: tfFontFamily(context),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: PosColors.slate,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(width: 32, height: 2, color: accent),
      ],
    );
  }
}

// ── KPI stats row (Orders / Open / Avg / Profit) ─────────────────────────────

class _KpiStatsRow extends StatelessWidget {
  const _KpiStatsRow({required this.kpis, required this.text});

  final DashboardKpis kpis;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final compactFmt = NumberFormat.compact(locale: text.isBn ? 'bn' : 'en');
    final avgStr = kpis.avgTicket > 0
        ? '৳${compactFmt.format(kpis.avgTicket).toLowerCase()}'
        : '৳0';
    final profitStr =
        '${kpis.profitPct.toStringAsFixed(kpis.profitPct.abs() >= 10 ? 0 : 1)}%';

    return Row(
      children: [
        Expanded(
          child: _KpiTile(value: '${kpis.orders}', label: text.kpiOrders),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _KpiTile(
            value: '${kpis.openOrders}',
            label: text.kpiOpen,
            dim: true,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _KpiTile(value: avgStr, label: text.kpiAvg),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _KpiTile(value: profitStr, label: text.kpiProfit),
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.value, required this.label, this.dim = false});

  final String value;
  final String label;
  final bool dim;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.line, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TfText(            value,
            style: TextStyle(
              fontFamily: tfFontFamily(context),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: dim ? PosColors.muted : PosColors.slate,
              letterSpacing: -0.3,
              height: 1,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          TfText(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: PosColors.muted,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Needs your eye ───────────────────────────────────────────────────────────

class _NeedsYourEye extends StatelessWidget {
  const _NeedsYourEye({
    required this.right,
    required this.text,
    required this.onAction,
  });

  final RightNowSection right;
  final AppStrings text;
  final ValueChanged<NeedsAttentionItem> onAction;

  @override
  Widget build(BuildContext context) {
    final items = right.needsAttention;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          en: 'Needs your eye',
          bn: 'নজর দিন',
          trailing: items.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: PosColors.coral,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: TfText(                    '${items.length}',
                    style: TextStyle(
                      fontFamily: tfFontFamily(context),
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ),
        if (items.isEmpty)
          TfCard(
            child: TfText(
              text.isBn
                  ? 'সব ঠিক আছে।'
                  : 'All clear — nothing needs your attention.',
              style: const TextStyle(
                fontSize: 13,
                color: PosColors.muted,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          )
        else
          ...items.map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AttentionRow(item: it, onTap: () => onAction(it)),
            ),
          ),
      ],
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.onTap});

  final NeedsAttentionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final kind = item.kind;
    final (Color pillBg, Color pillFg, String label) = switch (kind) {
      'late' => (PosColors.coral, Colors.white, text.attentionLate),
      'low' => (PosColors.primary, PosColors.slate, text.attentionLow),
      'offline' => (
        PosColors.background,
        PosColors.slate,
        text.isBn ? 'অফ' : 'OFF',
      ),
      _ => (PosColors.background, PosColors.slate, kind.toUpperCase()),
    };
    final defaultCta = switch (kind) {
      'late' => text.attentionCheck,
      'low' => text.attentionReorder,
      'offline' => text.isBn ? 'কল' : 'Call',
      _ => text.attentionCheck,
    };
    final cta = item.cta.isNotEmpty ? item.cta : defaultCta;

    return TfCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _Pill(label: label, bg: pillBg, fg: pillFg),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                    height: 1.25,
                  ),
                ),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  TfText(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: PosColors.muted,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          TfButton(
            label: cta,
            variant: TfButtonVariant.paper,
            size: TfButtonSize.sm,
            fullWidth: false,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: TfText(        label.toUpperCase(),
        style: TextStyle(
          fontFamily: tfFontFamily(context),
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Quick actions grid ──────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.text,
    required this.onNewOrder,
    required this.onPrintBill,
    required this.onCallWaiter,
    required this.onShiftReport,
  });

  final AppStrings text;
  final VoidCallback onNewOrder;
  final VoidCallback onPrintBill;
  final VoidCallback onCallWaiter;
  final VoidCallback onShiftReport;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.add_rounded,
        label: text.qaNewOrder,
        onTap: onNewOrder,
      ),
      _QuickAction(
        icon: Icons.receipt_long_outlined,
        label: text.qaPrintBill,
        onTap: onPrintBill,
      ),
      _QuickAction(
        icon: Icons.phone_outlined,
        label: text.qaCallWaiter,
        onTap: onCallWaiter,
      ),
      _QuickAction(
        icon: Icons.pie_chart_outline,
        label: text.qaShiftReport,
        onTap: onShiftReport,
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(en: 'Quick actions', bn: 'দ্রুত অ্যাকশন'),
        Row(
          children: [
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _QuickActionTile(action: actions[i])),
            ],
          ],
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PosColors.line, width: 0.5),
          ),
          child: Column(
            children: [
              Icon(action.icon, size: 22, color: PosColors.slate),
              const SizedBox(height: 8),
              TfText(
                action.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: PosColors.slate,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Top movers ──────────────────────────────────────────────────────────────

class _TopMovers extends StatelessWidget {
  const _TopMovers({required this.movers, required this.text});

  final List<TopMover> movers;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final top = movers.take(3).toList(growable: false);
    final maxShare = top.fold<double>(
      0,
      (acc, m) => m.sharePct > acc ? m.sharePct : acc,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          en: 'Top movers today',
          bn: 'আজকের সেরা',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TfText(
                text.seeAll.toLowerCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: PosColors.muted,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 14,
                color: PosColors.muted,
              ),
            ],
          ),
        ),
        for (var i = 0; i < top.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _TopMoverRow(
            rank: i + 1,
            mover: top[i],
            currency: fmt,
            isBn: text.isBn,
            relativeShare: maxShare > 0
                ? (top[i].sharePct / maxShare).clamp(0.0, 1.0)
                : 0,
          ),
        ],
      ],
    );
  }
}

class _TopMoverRow extends StatelessWidget {
  const _TopMoverRow({
    required this.rank,
    required this.mover,
    required this.currency,
    required this.isBn,
    required this.relativeShare,
  });

  final int rank;
  final TopMover mover;
  final NumberFormat currency;
  final bool isBn;
  final double relativeShare;

  @override
  Widget build(BuildContext context) {
    final name = isBn && mover.nameBn.isNotEmpty ? mover.nameBn : mover.nameEn;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.line, width: 0.5),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: TfText(              '#$rank',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: PosColors.muted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: relativeShare,
                    minHeight: 4,
                    backgroundColor: PosColors.background,
                    valueColor: const AlwaysStoppedAnimation(PosColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 36,
            child: TfText(              '×${mover.qty}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: tfFontFamily(context),
                fontSize: 11,
                color: PosColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 62,
            child: TfText(              currency.format(mover.salesBdt),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: tfFontFamily(context),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PosColors.slate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Close today CTA ─────────────────────────────────────────────────────────

class _CloseTodayCard extends StatelessWidget {
  const _CloseTodayCard({required this.money, required this.text});

  final MoneyFirstSection money;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
    final amount = money.closeTodayHintBdt > 0
        ? money.closeTodayHintBdt
        : money.earnedToday;
    return Material(
      color: PosColors.primaryDark,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TfSectionHeader(
                      label: text.readyWhenYouAre,
                      color: const Color(0xAAFFFFFF),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 4),
                    TfText(
                      '${text.closeToday} · ${fmt.format(amount)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Offline banner ───────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.text, required this.app});

  final AppStrings text;
  final dynamic app;

  @override
  Widget build(BuildContext context) {
    final error = app.dashboardSummaryError as String?;
    return TfCard(
      color: PosColors.primaryWash,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            text.liveMetricsOffline,
            style: const TextStyle(
              color: PosColors.slate,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 6),
            TfText(
              error,
              style: const TextStyle(color: PosColors.muted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          TfButton(
            label: text.retry,
            variant: TfButtonVariant.paper,
            size: TfButtonSize.md,
            fullWidth: false,
            onPressed: () => app.refreshDashboardSummary(),
          ),
        ],
      ),
    );
  }
}
