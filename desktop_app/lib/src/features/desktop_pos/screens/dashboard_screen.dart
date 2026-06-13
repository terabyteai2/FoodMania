// QuickBytes Desktop — role-aware dashboard. Owner = Analytics, manager =
// Control Tower (Live). Faithful to `desktop-floor.jsx` DashboardScreen: an
// accent-wash net-sales hero + KPIs, a manager attention row, weekly bars, a
// channel donut and a top-performers list. All figures are derived from the
// in-memory order/inventory data — empty windows hide their cards (never zero-
// fill), per the null-safe invariant.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app_controller.dart';
import '../../../app_scope.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/order_model.dart';
import '../../../models/order_service_type.dart';
import '../../../models/order_status.dart';
import '../desk_controller.dart';
import '../widgets/dk_icons.dart';
import '../widgets/dk_kit.dart';
import 'orders_screen.dart' show dkChannelKey, orderMins;

class _Metrics {
  _Metrics({
    required this.net,
    required this.prevNet,
    required this.orders,
    required this.aov,
    required this.margin,
    required this.dineShare,
    required this.weekly,
    required this.weekLabels,
    required this.channels,
    required this.topItems,
  });
  final double net, prevNet, aov, margin, dineShare;
  final int orders;
  final List<double> weekly;
  final List<String> weekLabels;
  final List<(String, double, Color)> channels; // label, pct, color
  final List<_TopItem> topItems;
  bool get hasData => orders > 0;
}

class _TopItem {
  _TopItem(this.name, this.qty, this.revenue, this.margin);
  final String name;
  final int qty;
  final double revenue;
  final double margin;
}

class DeskDashboardScreen extends StatefulWidget {
  const DeskDashboardScreen({super.key});

  @override
  State<DeskDashboardScreen> createState() => _DeskDashboardScreenState();
}

class _DeskDashboardScreenState extends State<DeskDashboardScreen> {
  String _range = 'today';

  bool get _isBn => AppScope.of(context).language == AppLanguage.bn;
  String _t(String en, String bn) => _isBn ? bn : en;

  DateTime _windowStart(DateTime now) => switch (_range) {
        '7d' => DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6)),
        '30d' => DateTime(now.year, now.month, now.day).subtract(const Duration(days: 29)),
        _ => DateTime(now.year, now.month, now.day),
      };

  _Metrics _compute(PosAppController app) {
    final now = DateTime.now();
    final lang = app.language;
    final completed = app.orders.where((o) => o.status.adminStatus == OrderStatus.completed).toList();
    DateTime when(OrderModel o) => o.settledAt ?? o.createdAt;

    final start = _windowStart(now);
    final winLen = now.difference(start);
    final prevStart = start.subtract(winLen);
    final inWin = completed.where((o) => when(o).isAfter(start) || when(o).isAtSameMomentAs(start)).toList();
    final inPrev = completed.where((o) {
      final w = when(o);
      return w.isAfter(prevStart) && w.isBefore(start);
    }).toList();

    final net = inWin.fold<double>(0, (s, o) => s + o.total);
    final prevNet = inPrev.fold<double>(0, (s, o) => s + o.total);
    final orders = inWin.length;
    final aov = orders > 0 ? net / orders : 0.0;

    double revenue = 0, cost = 0, dineRev = 0;
    for (final o in inWin) {
      for (final it in o.items) {
        revenue += it.lineTotal;
        cost += it.costPriceSnapshot * it.qty;
      }
      if (o.serviceType == OrderServiceType.dineIn) dineRev += o.total;
    }
    final margin = revenue > 0 ? (revenue - cost) / revenue : 0.0;
    final dineShare = net > 0 ? dineRev / net : 0.0;

    // Weekly bars — last 7 calendar days ending today.
    final weekly = <double>[];
    final weekLabels = <String>[];
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (var i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final next = day.add(const Duration(days: 1));
      final sum = completed.where((o) {
        final w = when(o);
        return !w.isBefore(day) && w.isBefore(next);
      }).fold<double>(0, (s, o) => s + o.total);
      weekly.add(sum);
      weekLabels.add(wd[(day.weekday - 1) % 7]);
    }

    // Channel mix by revenue (window).
    final byChannel = <String, double>{};
    for (final o in inWin) {
      final key = dkChannelKey(o.source);
      byChannel[key] = (byChannel[key] ?? 0) + o.total;
    }
    final channels = <(String, double, Color)>[];
    final chTotal = byChannel.values.fold<double>(0, (s, v) => s + v);
    if (chTotal > 0) {
      final sorted = byChannel.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      for (final e in sorted) {
        final meta = dkChannel(e.key);
        channels.add(((lang == AppLanguage.bn ? meta.bn : meta.en), (e.value / chTotal * 100), meta.color));
      }
    }

    // Top performers by revenue (window).
    final agg = <String, _TopItem>{};
    final rev = <String, double>{};
    final qmap = <String, int>{};
    final cmap = <String, double>{};
    final nmap = <String, String>{};
    for (final o in inWin) {
      for (final it in o.items) {
        final k = it.menuItemId.isNotEmpty ? it.menuItemId : it.name;
        rev[k] = (rev[k] ?? 0) + it.lineTotal;
        qmap[k] = (qmap[k] ?? 0) + it.qty;
        cmap[k] = (cmap[k] ?? 0) + it.costPriceSnapshot * it.qty;
        nmap[k] = (lang == AppLanguage.bn ? it.nameBn : it.nameEn).trim().isNotEmpty
            ? (lang == AppLanguage.bn ? it.nameBn : it.nameEn).trim()
            : it.name;
      }
    }
    for (final k in rev.keys) {
      final r = rev[k]!;
      agg[k] = _TopItem(nmap[k] ?? k, qmap[k] ?? 0, r, r > 0 ? (r - (cmap[k] ?? 0)) / r : 0);
    }
    final topItems = agg.values.toList()..sort((a, b) => b.revenue.compareTo(a.revenue));

    return _Metrics(
      net: net,
      prevNet: prevNet,
      orders: orders,
      aov: aov,
      margin: margin,
      dineShare: dineShare,
      weekly: weekly,
      weekLabels: weekLabels,
      channels: channels,
      topItems: topItems.take(5).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final desk = DeskScope.of(context);
    final owner = app.isOwner;
    final m = _compute(app);
    final delta = m.prevNet > 0 ? ((m.net - m.prevNet) / m.prevNet * 100).round() : null;

    return Container(
      color: Dk.bg,
      child: Column(
        children: [
          _header(owner),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                _heroRow(app, owner, m, delta),
                if (!owner) ...[const SizedBox(height: 16), _attentionRow(app, desk)],
                if (m.hasData) ...[
                  const SizedBox(height: 16),
                  _trendRow(m),
                  const SizedBox(height: 16),
                  _topItems(m),
                  if (owner) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        _t('Full drill-downs, forecast & unit economics live in mobile Analytics',
                            'বিস্তারিত ড্রিল-ডাউন ও ফোরকাস্ট মোবাইল অ্যানালিটিক্সে'),
                        style: dkText(12.5, color: Dk.muted),
                      ),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 40),
                  Center(child: Text(_t('No sales in this period yet.', 'এই সময়ে কোনো বিক্রি নেই'), style: dkText(14, color: Dk.muted))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(bool owner) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(color: Dk.surface, border: Border(bottom: BorderSide(color: Dk.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owner ? _t('Analytics', 'বিশ্লেষণ') : _t('Control Tower', 'কন্ট্রোল টাওয়ার'),
                    style: dkText(22, weight: FontWeight.w700, letterSpacing: -0.4)),
                Text(owner ? _t('Today', 'আজ') : _t('Live operations', 'লাইভ অপারেশন'),
                    style: dkText(13, weight: FontWeight.w500, color: Dk.muted)),
              ],
            ),
          ),
          DkSeg(
            selected: _range,
            onSelect: (id) => setState(() => _range = id),
            items: [
              DkSegItem('today', _t('Today', 'আজ')),
              DkSegItem('7d', '7d'),
              DkSegItem('30d', '30d'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroRow(PosAppController app, bool owner, _Metrics m, int? delta) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 320,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Dk.accentTint,
                borderRadius: BorderRadius.circular(Dk.rLg),
                border: Border.all(color: Dk.accentTint2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_t('Net sales', 'নেট সেলস'), style: dkText(13, weight: FontWeight.w700, color: Dk.accentStrong)),
                  const SizedBox(height: 4),
                  Text(dkMoney(m.net), style: dkNum(40, weight: FontWeight.w800, letterSpacing: -1)),
                  if (delta != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DkIcon(delta >= 0 ? 'trendup' : 'trenddn', size: 16, color: delta >= 0 ? Dk.success : Dk.danger),
                        const SizedBox(width: 5),
                        Text('$delta% ${_t('vs prev', 'পূর্বের তুলনায়')}',
                            style: dkText(13.5, weight: FontWeight.w700, color: delta >= 0 ? Dk.success : Dk.danger)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          _kpi(_t('Orders', 'অর্ডার'), '${m.orders}'),
          const SizedBox(width: 16),
          _kpi(_t('Avg order', 'গড় অর্ডার'), dkMoney(m.aov)),
          const SizedBox(width: 16),
          _kpi(_t('Margin', 'মার্জিন'), '${(m.margin * 100).round()}%'),
          const SizedBox(width: 16),
          owner
              ? _kpi(_t('Dine-in share', 'ডাইন-ইন'), '${(m.dineShare * 100).round()}%')
              : _kpi(_t('Open orders', 'খোলা অর্ডার'), '${app.orders.where((o) => o.status.isOpen).length}'),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(color: Dk.surface, borderRadius: BorderRadius.circular(Dk.rLg), border: Border.all(color: Dk.line)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: dkText(12.5, weight: FontWeight.w600, color: Dk.muted)),
            const SizedBox(height: 4),
            Text(value, style: dkNum(26, weight: FontWeight.w700, letterSpacing: -0.4)),
          ],
        ),
      ),
    );
  }

  Widget _attentionRow(PosAppController app, DeskController desk) {
    final late = app.orders.where((o) => o.status.isOpen && orderMins(o) > 15).length;
    final low = app.inventoryItems.where((i) => i.isLowStock || i.isOutOfStock).length;
    return Row(
      children: [
        Expanded(child: _attentionCard('clock', Dk.warning, Dk.warningSoft,
            _t('$late orders running late', '$late টি অর্ডার দেরিতে'), _t('Over 15 min', '১৫ মিনিটের বেশি'),
            _t('View', 'দেখুন'), () => desk.setTab(DeskTab.orders))),
        const SizedBox(width: 12),
        Expanded(child: _attentionCard('box', Dk.danger, Dk.dangerSoft,
            _t('$low items below par', '$low টি আইটেম পার-এর নিচে'), _t('Restock soon', 'শীঘ্রই রিস্টক'),
            _t('Stock', 'স্টক'), () => desk.setTab(DeskTab.inventory))),
      ],
    );
  }

  Widget _attentionCard(String icon, Color fg, Color bg, String title, String body, String action, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Dk.surface, borderRadius: BorderRadius.circular(Dk.rLg), border: Border.all(color: bg)),
      child: Row(
        children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)), child: Center(child: DkIcon(icon, size: 19, color: fg))),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: dkText(14, weight: FontWeight.w700)),
                Text(body, style: dkText(12.5, color: Dk.muted)),
              ],
            ),
          ),
          DkButton(label: action, variant: DkBtnVariant.ghost, size: DkBtnSize.sm, onTap: onTap),
        ],
      ),
    );
  }

  Widget _trendRow(_Metrics m) {
    final maxBar = m.weekly.fold<double>(1, (mx, v) => math.max(mx, v));
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: DkCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_t('Sales this week', 'সাপ্তাহিক সেলস'), style: dkText(15, weight: FontWeight.w700)),
                      Text(_t('last 7 days', 'গত ৭ দিন'), style: dkText(12.5, color: Dk.muted)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 150,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < m.weekly.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    height: math.max(3, m.weekly[i] / maxBar * 124),
                                    decoration: BoxDecoration(
                                      color: i == m.weekly.length - 1 ? Dk.accent : Dk.accentTint2,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(m.weekLabels[i], style: dkText(11.5, weight: FontWeight.w600, color: Dk.muted)),
                                ],
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
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: DkCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_t('Channel mix', 'চ্যানেল মিক্স'), style: dkText(15, weight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(width: 116, height: 116, child: CustomPaint(painter: _DonutPainter(m.channels))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            for (final c in m.channels)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 9),
                                child: Row(
                                  children: [
                                    Container(width: 11, height: 11, decoration: BoxDecoration(color: c.$3, borderRadius: BorderRadius.circular(3))),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(c.$1, style: dkText(13, color: Dk.ink2))),
                                    Text('${c.$2.round()}%', style: dkNum(13, weight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topItems(_Metrics m) {
    final maxRev = m.topItems.isEmpty ? 1.0 : m.topItems.first.revenue;
    return DkCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_t('Top performers', 'টপ আইটেম'), style: dkText(15, weight: FontWeight.w700)),
              Text(_t('by revenue', 'রাজস্ব অনুসারে'), style: dkText(12.5, color: Dk.muted)),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < m.topItems.length; i++)
            Container(
              decoration: BoxDecoration(border: i < m.topItems.length - 1 ? const Border(bottom: BorderSide(color: Dk.line)) : null),
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  SizedBox(width: 18, child: Text('${i + 1}', style: dkNum(13, weight: FontWeight.w700, color: Dk.muted))),
                  const SizedBox(width: 13),
                  SizedBox(
                    width: 200,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.topItems[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: dkText(14, weight: FontWeight.w600)),
                        Text('${m.topItems[i].qty} ${_t('sold', 'বিক্রি')} · ${(m.topItems[i].margin * 100).round()}% ${_t('margin', 'মার্জিন')}',
                            style: dkText(12, color: Dk.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (m.topItems[i].revenue / maxRev).clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: Dk.surface2,
                        valueColor: AlwaysStoppedAnimation(i == 0 ? Dk.accent : Dk.accentTint2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(width: 92, child: Text(dkMoney(m.topItems[i].revenue), textAlign: TextAlign.right, style: dkNum(17, weight: FontWeight.w700))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.data);
  final List<(String, double, Color)> data;
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 11;
    final center = Offset(size.width / 2, size.height / 2);
    var start = -math.pi / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    for (final seg in data) {
      final sweep = seg.$2 / 100 * 2 * math.pi;
      paint.color = seg.$3;
      canvas.drawArc(Rect.fromCircle(center: center, radius: r), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.data != data;
}
