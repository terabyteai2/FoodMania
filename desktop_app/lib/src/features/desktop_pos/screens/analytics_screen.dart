import 'package:flutter/material.dart';

import '../../../models/desktop_pos.dart';
import '../widgets/pc_charts.dart';
import '../widgets/pc_shell.dart';
import '../widgets/pc_theme.dart';
import '../widgets/pc_widgets.dart';

/// Phase 2 analytics — Today (hourly vs prior) · Items (top/slow/margin) ·
/// Staff & footfall. All backed by the existing [PosReportSnapshot].
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    required this.chrome,
    required this.report,
    required this.canCloseDay,
    required this.onCloseDay,
    super.key,
  });

  final PcChrome chrome;
  final PosReportSnapshot report;
  final bool canCloseDay;
  final VoidCallback onCloseDay;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum _Tab { today, items, staff }

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _Tab _tab = _Tab.today;

  PosReportSnapshot get r => widget.report;
  String tr(String en, String bn) => widget.chrome.isBn ? bn : en;

  @override
  Widget build(BuildContext context) {
    return PcShell(
      chrome: widget.chrome,
      activeNav: PcNav.reports,
      title: tr('Reports', 'রিপোর্ট'),
      sub: tr('Live · refreshes as orders settle',
          'লাইভ · নিষ্পত্তির সাথে আপডেট'),
      topActions: [
        _tabs(),
        if (widget.canCloseDay)
          PcBtn(
            label: tr('Close day', 'দিন শেষ'),
            variant: PcVariant.dark,
            icon: 'check',
            onTap: widget.onCloseDay,
          ),
      ],
      child: switch (_tab) {
        _Tab.today => _today(),
        _Tab.items => _items(),
        _Tab.staff => _staff(),
      },
    );
  }

  Widget _tabs() => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Pc.surfaceAlt,
          border: Border.all(color: Pc.border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tabSeg(tr('Today', 'আজ'), _Tab.today),
            _tabSeg(tr('Items', 'আইটেম'), _Tab.items),
            _tabSeg(tr('Staff', 'স্টাফ'), _Tab.staff),
          ],
        ),
      );

  Widget _tabSeg(String label, _Tab tab) {
    final on = _tab == tab;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: on ? Pc.surface : Colors.transparent,
            border: Border.all(color: on ? Pc.borderStrong : Colors.transparent),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: on ? Pc.text : Pc.textSec)),
        ),
      ),
    );
  }

  // ===== TODAY ==============================================================
  Widget _today() {
    final hours = _hourAxis([r.hourlySales.keys, r.priorSameWeekdayHourlyAverage.keys]);
    final bars = [
      for (final h in hours)
        PcBar(_hourLabel(h), r.hourlySales[h] ?? 0,
            vs: r.priorSameWeekdayHourlyAverage[h]),
    ];
    final peak = _peakIndex(bars);
    final priorTotal =
        r.priorSameWeekdayHourlyAverage.values.fold<double>(0, (s, v) => s + v);
    final delta = priorTotal <= 0 ? null : (r.sales - priorTotal) / priorTotal * 100;
    final grossMargin = r.items.fold<double>(
        0, (s, it) => s + ((it['margin'] as num?)?.toDouble() ?? 0));
    final marginPct = r.sales <= 0 ? 0.0 : grossMargin / r.sales * 100;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.0,
          children: [
            PcKpi(
              label: tr("Today's sales", 'আজকের বিক্রি'),
              value: pcMoney(r.sales),
              sub: priorTotal <= 0
                  ? null
                  : tr('vs prior ${pcMoney(priorTotal)}',
                      'আগের ${pcMoney(priorTotal)}'),
              delta: delta == null ? null : '${delta.abs().toStringAsFixed(1)}%',
              deltaUp: (delta ?? 0) >= 0,
            ),
            PcKpi(label: tr('Orders', 'অর্ডার'), value: '${r.orders}'),
            PcKpi(
              label: tr('Avg ticket', 'গড় টিকেট'),
              value: r.orders == 0 ? pcMoney(0) : pcMoney(r.sales / r.orders),
            ),
            PcKpi(
              label: tr('Gross margin', 'গ্রস মার্জিন'),
              value: '${marginPct.toStringAsFixed(1)}%',
              sub: tr('${pcMoney(grossMargin)} profit', '${pcMoney(grossMargin)} মুনাফা'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 900;
          final chart = _hourlyCard(bars, peak);
          final donut = _paymentCard();
          if (!wide) {
            return Column(children: [chart, const SizedBox(height: 12), donut]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: chart),
                const SizedBox(width: 12),
                SizedBox(width: 360, child: donut),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _hourlyCard(List<PcBar> bars, int peak) => PcCard(
        pad: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PcSectionHead(
              title: tr('Hourly sales · today vs prior weekday',
                  'ঘণ্টাভিত্তিক বিক্রি · আজ বনাম আগের'),
              sub: tr('Bars: today · faint band: prior average',
                  'বার: আজ · হালকা: আগের গড়'),
              right: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendDot(Pc.accent, tr('Today', 'আজ')),
                  const SizedBox(width: 12),
                  _legendDot(Pc.borderStrong, tr('Prior avg', 'আগের গড়')),
                ],
              ),
            ),
            PcBarChart(
              bars: bars,
              height: 240,
              peakIndex: peak >= 0 ? peak : null,
              peakLabel: peak >= 0
                  ? 'PEAK ${pcMoney(bars[peak].value)}'
                  : null,
              yAxis: (v) => v >= 1000
                  ? '৳${(v / 1000).toStringAsFixed(0)}k'
                  : '৳${v.toStringAsFixed(0)}',
            ),
          ],
        ),
      );

  Widget _paymentCard() {
    final slices = _paymentSlices();
    return PcCard(
      pad: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PcSectionHead(title: tr('Payment method split', 'পেমেন্ট বিভাজন')),
          if (slices.isEmpty)
            Text(tr('No settlements yet.', 'এখনো নিষ্পত্তি নেই।'),
                style: const TextStyle(color: Pc.textSec))
          else
            PcDonut(slices: slices),
        ],
      ),
    );
  }

  // ===== ITEMS =============================================================
  Widget _items() {
    final rows = [...r.items]..sort(
        (a, b) => ((b['sales'] as num?) ?? 0).compareTo((a['sales'] as num?) ?? 0));
    final maxQty = rows.fold<int>(
        1, (m, it) => ((it['qty'] as num?)?.toInt() ?? 0) > m
            ? (it['qty'] as num).toInt()
            : m);
    final grossProfit = rows.fold<double>(
        0, (s, it) => s + ((it['margin'] as num?)?.toDouble() ?? 0));
    final slow = [...rows]..sort((a, b) =>
        ((a['qty'] as num?) ?? 0).compareTo((b['qty'] as num?) ?? 0));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: PcCard(
              pad: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                    child: PcSectionHead(
                      title: tr('Items · ranked by revenue', 'আইটেম · বিক্রি অনুসারে'),
                      sub: tr('${rows.length} SKUs sold', '${rows.length} আইটেম বিক্রি'),
                    ),
                  ),
                  _itemHeader(),
                  Expanded(
                    child: rows.isEmpty
                        ? Center(
                            child: Text(tr('No items sold yet.', 'এখনো বিক্রি নেই।'),
                                style: const TextStyle(color: Pc.textSec)))
                        : ListView.builder(
                            itemCount: rows.length,
                            itemBuilder: (_, i) => _itemRow(rows[i], i, maxQty),
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 280,
            child: Column(
              children: [
                PcCard(
                  pad: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PcEyebrow(tr('Slow movers', 'কম বিক্রি')),
                      const SizedBox(height: 8),
                      if (slow.isEmpty)
                        Text(tr('—', '—'), style: const TextStyle(color: Pc.textSec))
                      else
                        Text(
                          tr(
                            '${slow.take(2).map((e) => e['name']).join(', ')} sold the least. Consider a promo or removal.',
                            '${slow.take(2).map((e) => e['name']).join(', ')} সবচেয়ে কম বিক্রি হয়েছে।',
                          ),
                          style: const TextStyle(fontSize: 13, color: Pc.text, height: 1.5),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                PcCard(
                  pad: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PcEyebrow(tr('Gross profit', 'গ্রস মুনাফা')),
                      const SizedBox(height: 8),
                      Text(pcMoney(grossProfit), style: Pc.num(28, letterSpacing: -0.6)),
                      const SizedBox(height: 4),
                      Text(
                        tr('${pcMoney(r.sales)} revenue', '${pcMoney(r.sales)} বিক্রি'),
                        style: const TextStyle(fontSize: 12, color: Pc.textSec),
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

  Widget _itemHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        margin: const EdgeInsets.only(top: 12),
        decoration: const BoxDecoration(
          color: Pc.surfaceAlt,
          border: Border(
            top: BorderSide(color: Pc.border),
            bottom: BorderSide(color: Pc.border),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 28, child: Text('#', style: Pc.mono(9.5, color: Pc.textSec))),
            Expanded(flex: 4, child: Text('ITEM', style: Pc.mono(9.5, color: Pc.textSec))),
            Expanded(flex: 2, child: Text('QTY', textAlign: TextAlign.right, style: Pc.mono(9.5, color: Pc.textSec))),
            Expanded(flex: 3, child: Text('GROSS', textAlign: TextAlign.right, style: Pc.mono(9.5, color: Pc.textSec))),
            Expanded(flex: 3, child: Text('MARGIN', textAlign: TextAlign.right, style: Pc.mono(9.5, color: Pc.textSec))),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: Text('VOLUME', style: Pc.mono(9.5, color: Pc.textSec))),
          ],
        ),
      );

  Widget _itemRow(Map<String, Object?> it, int i, int maxQty) {
    final qty = (it['qty'] as num?)?.toInt() ?? 0;
    final sales = (it['sales'] as num?)?.toDouble() ?? 0;
    final margin = (it['margin'] as num?)?.toDouble() ?? 0;
    final marginPct = sales <= 0 ? 0.0 : margin / sales * 100;
    final tone = marginPct >= 60 ? Pc.good : (marginPct >= 50 ? Pc.text : Pc.late);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: i == 0 ? Pc.accentWash : Pc.surface,
        border: const Border(bottom: BorderSide(color: Pc.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(_rank(i), style: Pc.mono(11, color: Pc.textTer)),
          ),
          Expanded(
            flex: 4,
            child: Text('${it['name'] ?? 'Item'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(flex: 2, child: Text('$qty', textAlign: TextAlign.right, style: Pc.num(13.5))),
          Expanded(flex: 3, child: Text(pcMoney(sales), textAlign: TextAlign.right, style: Pc.num(13.5))),
          Expanded(
            flex: 3,
            child: Text('${marginPct.toStringAsFixed(0)}%',
                textAlign: TextAlign.right, style: Pc.num(13.5, color: tone)),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: maxQty == 0 ? 0 : qty / maxQty,
                minHeight: 6,
                backgroundColor: Pc.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(i == 0 ? Pc.accent : Pc.accentMid),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===== STAFF & FOOTFALL ==================================================
  Widget _staff() {
    final staff = [...r.staff]..sort((a, b) =>
        ((b['sales'] as num?) ?? 0).compareTo((a['sales'] as num?) ?? 0));
    final maxSales = staff.fold<double>(
        1, (m, s) => ((s['sales'] as num?)?.toDouble() ?? 0) > m
            ? (s['sales'] as num).toDouble()
            : m);
    final hours = _hourAxis([r.coversByHour.keys]);
    final covBars = [
      for (final h in hours)
        PcBar(_hourLabel(h), (r.coversByHour[h] ?? 0).toDouble()),
    ];
    final peak = _peakIndex(covBars);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        PcCard(
          pad: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: PcSectionHead(
                  title: tr('Staff performance', 'স্টাফ পারফরম্যান্স'),
                  sub: tr('Sorted by revenue', 'বিক্রি অনুসারে'),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: const BoxDecoration(
                  color: Pc.surfaceAlt,
                  border: Border(
                    top: BorderSide(color: Pc.border),
                    bottom: BorderSide(color: Pc.border),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(width: 28, child: Text('#', style: Pc.mono(9.5, color: Pc.textSec))),
                    Expanded(flex: 4, child: Text('STAFF', style: Pc.mono(9.5, color: Pc.textSec))),
                    Expanded(flex: 2, child: Text('ORDERS', textAlign: TextAlign.right, style: Pc.mono(9.5, color: Pc.textSec))),
                    Expanded(flex: 3, child: Text('REVENUE', textAlign: TextAlign.right, style: Pc.mono(9.5, color: Pc.textSec))),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: Text('SHARE', style: Pc.mono(9.5, color: Pc.textSec))),
                  ],
                ),
              ),
              if (staff.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                      child: Text(tr('No staff activity yet.', 'এখনো কার্যকলাপ নেই।'),
                          style: const TextStyle(color: Pc.textSec))),
                )
              else
                for (var i = 0; i < staff.length; i++)
                  _staffRow(staff[i], i, maxSales),
            ],
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth > 900;
          final footfall = _footfallCard(covBars, peak);
          final digest = _digestCard();
          if (!wide) {
            return Column(children: [footfall, const SizedBox(height: 12), digest]);
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: footfall),
                const SizedBox(width: 12),
                SizedBox(width: 360, child: digest),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _staffRow(Map<String, Object?> s, int i, double maxSales) {
    final orders = (s['orders'] as num?)?.toInt() ?? 0;
    final sales = (s['sales'] as num?)?.toDouble() ?? 0;
    final top = i == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: top ? Pc.accentWash : Pc.surface,
        border: const Border(bottom: BorderSide(color: Pc.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: 28, child: Text(_rank(i), style: Pc.mono(11, color: Pc.textTer))),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: top ? Pc.accent : Pc.surfaceAlt,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Text(_staffLabel(s).characters.first.toUpperCase(),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: top ? Pc.accentInk : Pc.text)),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(_staffLabel(s),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          Expanded(flex: 2, child: Text('$orders', textAlign: TextAlign.right, style: Pc.num(13))),
          Expanded(flex: 3, child: Text(pcMoney(sales), textAlign: TextAlign.right, style: Pc.num(13.5))),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: maxSales == 0 ? 0 : sales / maxSales,
                minHeight: 6,
                backgroundColor: Pc.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(top ? Pc.accent : Pc.accentMid),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footfallCard(List<PcBar> bars, int peak) => PcCard(
        pad: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PcSectionHead(
              title: tr('Hourly footfall', 'ঘণ্টাভিত্তিক ভিড়'),
              sub: tr('Covers per hour · peak helps you schedule',
                  'প্রতি ঘণ্টায় কভার · শিডিউলে সাহায্য করে'),
            ),
            PcBarChart(
              bars: bars,
              height: 200,
              accent: Pc.accentMid,
              peakIndex: peak >= 0 ? peak : null,
              peakLabel: peak >= 0 ? 'PEAK ${bars[peak].value.toStringAsFixed(0)}P' : null,
              yAxis: (v) => v.toStringAsFixed(0),
            ),
            const SizedBox(height: 8),
            Text(
              tr('Total covers ${r.covers}', 'মোট কভার ${r.covers}'),
              style: Pc.num(13, weight: FontWeight.w600, color: Pc.textSec),
            ),
          ],
        ),
      );

  Widget _digestCard() => PcCard(
        pad: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PcEyebrow(tr('Weekly summary · WhatsApp', 'সাপ্তাহিক · WhatsApp')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Pc.bg,
                border: Border.all(color: Pc.borderStrong, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(Pc.rMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chrome.outletName,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'Sales ${pcMoney(r.sales)} · ${r.orders} orders · ${r.covers} covers today.',
                      'বিক্রি ${pcMoney(r.sales)} · ${r.orders} অর্ডার · ${r.covers} কভার আজ।',
                    ),
                    style: const TextStyle(fontSize: 12.5, color: Pc.textSec, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const PcPill(label: 'AUTO-SEND OFF', tone: PcTone.muted, dot: true),
                const Spacer(),
                Text(tr('Phase 2', 'ফেজ ২'),
                    style: Pc.mono(10.5, color: Pc.textTer)),
              ],
            ),
          ],
        ),
      );

  // ===== helpers ===========================================================
  Widget _legendDot(Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 5),
          Text(label, style: Pc.mono(11, weight: FontWeight.w600, color: Pc.textSec)),
        ],
      );

  List<PcSlice> _paymentSlices() {
    const palette = [Pc.accent, Pc.accentMid, Pc.inkRaised, Pc.borderStrong, Pc.textTer];
    final entries = r.paymentSplit.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (var i = 0; i < entries.length; i++)
        PcSlice(_payLabel(entries[i].key), entries[i].value,
            palette[i % palette.length]),
    ];
  }

  String _payLabel(String key) => switch (key) {
        'cash' => tr('Cash', 'ক্যাশ'),
        'card' => tr('Card', 'কার্ড'),
        'bkash' => 'bKash',
        'nagad' => 'Nagad',
        'split' => tr('Split', 'ভাগ'),
        _ => key,
      };

  List<int> _hourAxis(List<Iterable<int>> sources) {
    final set = <int>{};
    for (final s in sources) {
      set.addAll(s);
    }
    if (set.isEmpty) return [for (var h = 11; h <= 22; h++) h];
    final list = set.toList()..sort();
    return list;
  }

  String _hourLabel(int h) => h.toString();

  int _peakIndex(List<PcBar> bars) {
    if (bars.isEmpty) return -1;
    var best = 0;
    for (var i = 1; i < bars.length; i++) {
      if (bars[i].value > bars[best].value) best = i;
    }
    return bars[best].value <= 0 ? -1 : best;
  }

  String _rank(int i) => (i + 1).toString().padLeft(2, '0');

  String _staffLabel(Map<String, Object?> s) {
    final id = '${s['accountId'] ?? ''}';
    if (id.isEmpty || id == 'unknown') return tr('Unknown', 'অজানা');
    if (id == 'manager') return tr('Manager', 'ম্যানেজার');
    if (id == 'staff') return tr('Staff', 'স্টাফ');
    return id.length <= 8 ? id : '#${id.substring(0, 6)}';
  }
}
