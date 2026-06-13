import 'package:flutter/material.dart';

import '../../../models/desktop_pos.dart';
import '../widgets/pc_denomination.dart';
import '../widgets/pc_shell.dart';
import '../widgets/pc_theme.dart';
import '../widgets/pc_widgets.dart';

/// 5 · Close day · Z report — receipt-style summary (left) + pre-close checklist
/// and actions (right). Reuses `closeDesktopShift` + `desktopPosReport`.
class ZReportScreen extends StatefulWidget {
  const ZReportScreen({
    required this.chrome,
    required this.report,
    required this.shift,
    required this.onClose,
    required this.onBack,
    this.onPrintZ,
    super.key,
  });

  final PcChrome chrome;
  final PosReportSnapshot report;
  final PosShift shift;
  final VoidCallback onBack;
  final VoidCallback? onPrintZ;
  final Future<void> Function(double counted, Map<String, int> denominations)
      onClose;

  @override
  State<ZReportScreen> createState() => _ZReportScreenState();
}

class _ZReportScreenState extends State<ZReportScreen> {
  double _counted = 0;
  Map<String, int> _denoms = const {};
  bool _busy = false;

  String tr(String en, String bn) => widget.chrome.isBn ? bn : en;

  double get _cashSales => widget.report.paymentSplit['cash'] ?? 0;
  double get _expected => widget.shift.openingCash + _cashSales;
  double get _variance => _counted - _expected;

  @override
  Widget build(BuildContext context) {
    return PcShell(
      chrome: widget.chrome,
      activeNav: PcNav.reports,
      title: tr('Close day · Z report', 'দিন শেষ · Z রিপোর্ট'),
      sub: tr('Count the drawer, then lock the till',
          'ড্রয়ার গণনা করে টিল লক করুন'),
      topActions: [
        PcBtn(
          label: tr('Back', 'ফিরুন'),
          variant: PcVariant.ghost,
          icon: 'back',
          sk: 'Esc',
          onTap: widget.onBack,
        ),
      ],
      footerHints: const [
        PcKey('Ctrl+P', 'Print Z'),
        PcKey('Ctrl+Enter', 'Lock & close'),
        PcKey('Esc', 'Cancel'),
      ],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 380, child: _receipt()),
            const SizedBox(width: 24),
            Expanded(child: _sidePanel()),
          ],
        ),
      ),
    );
  }

  // ---- receipt ------------------------------------------------------------
  Widget _receipt() {
    final r = widget.report;
    final total = r.paymentSplit.values.fold<double>(0, (s, v) => s + v);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFAF5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: Pc.shadowRaised,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Text(widget.chrome.outletName.toUpperCase(),
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4)),
            const SizedBox(height: 4),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black38, style: BorderStyle.solid),
                  bottom: BorderSide(color: Colors.black38),
                ),
              ),
              child: Text(tr('Z REPORT · END OF DAY', 'Z রিপোর্ট · দিন শেষ'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2)),
            ),
            Text(
              '${_fmtDate(widget.shift.openedAt)} · ${widget.chrome.counterLabel}',
              style: Pc.num(10.5, weight: FontWeight.w400, color: Pc.textSec),
            ),
            _section('SALES', [
              (tr('Net sales', 'নিট বিক্রি'), pcMoney(r.sales)),
              (tr('Orders', 'অর্ডার'), '${r.orders}'),
              (tr('Covers', 'কভার'), '${r.covers}'),
              (tr('Avg ticket', 'গড় টিকেট'),
                  r.orders == 0 ? pcMoney(0) : pcMoney(r.sales / r.orders)),
            ]),
            _total('NET SALES', pcMoney(r.sales)),
            _section('PAYMENTS', [
              for (final e in r.paymentSplit.entries)
                (
                  _payLabel(e.key),
                  '${pcMoney(e.value)} · ${total == 0 ? 0 : (e.value / total * 100).round()}%'
                ),
            ]),
            _section('DRAWER', [
              (tr('Opening cash', 'শুরুর ক্যাশ'), pcMoney(widget.shift.openingCash)),
              (tr('+ Cash sales', '+ ক্যাশ বিক্রি'), pcMoney(_cashSales)),
              (tr('Expected', 'প্রত্যাশিত'), pcMoney(_expected)),
              (tr('Counted', 'গণনাকৃত'), pcMoney(_counted)),
            ]),
            _total('VARIANCE', pcMoney(_variance),
                color: _variance == 0 ? Pc.ink : Pc.late),
            const SizedBox(height: 14),
            Text(
              '──── ${tr('END OF Z REPORT', 'Z রিপোর্ট শেষ')} ────',
              style: Pc.mono(10, weight: FontWeight.w400, color: Pc.textSec),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label, List<(String, String)> rows) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          children: [
            Text('──  $label  ──',
                style: Pc.mono(9.5, color: Pc.textSec, letterSpacing: 1)),
            const SizedBox(height: 6),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(row.$1,
                          style: const TextStyle(fontSize: 11.5, color: Pc.text)),
                    ),
                    Text(row.$2, style: Pc.num(11.5, weight: FontWeight.w600)),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _total(String label, String value, {Color? color}) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.black38),
            bottom: BorderSide(color: Colors.black38, width: 2),
          ),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1)),
            const Spacer(),
            Text(value, style: Pc.num(14, color: color ?? Pc.ink)),
          ],
        ),
      );

  // ---- side panel ---------------------------------------------------------
  Widget _sidePanel() {
    final r = widget.report;
    final topSellers = r.items.take(3).toList(growable: false);
    final withinTolerance = _variance.abs() <= 50;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PcCard(
            pad: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PcEyebrow(tr('Count the drawer', 'ড্রয়ার গণনা করুন')),
                const SizedBox(height: 12),
                PcDenominationGrid(
                  isBn: widget.chrome.isBn,
                  onChanged: (total, denoms) => setState(() {
                    _counted = total;
                    _denoms = denoms;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PcCard(
            pad: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PcEyebrow(tr('Before close', 'বন্ধের আগে'),
                    color: withinTolerance ? Pc.good : Pc.late),
                const SizedBox(height: 12),
                _check(tr('Variance', 'পার্থক্য'),
                    '${pcMoney(_variance)} · ${withinTolerance ? tr('within tolerance', 'সহনীয়') : tr('check drawer', 'ড্রয়ার দেখুন')}',
                    withinTolerance ? Pc.good : Pc.late),
                _check(tr('Cash sales', 'ক্যাশ বিক্রি'), pcMoney(_cashSales), Pc.good),
                if (!widget.chrome.online)
                  _check(tr('Unsynced', 'আনসিঙ্ক'),
                      '${widget.chrome.pendingCount} ${tr('queued', 'অপেক্ষমাণ')}', Pc.warn),
              ],
            ),
          ),
          if (topSellers.isNotEmpty) ...[
            const SizedBox(height: 14),
            PcCard(
              pad: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PcEyebrow(tr('Top sellers today', 'আজকের শীর্ষ বিক্রি')),
                  const SizedBox(height: 10),
                  for (var i = 0; i < topSellers.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Text('0${i + 1}',
                              style: Pc.mono(11, color: Pc.textTer)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('${topSellers[i]['name'] ?? 'Item'}',
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          Text('${topSellers[i]['qty'] ?? 0}×',
                              style: Pc.num(12.5, color: Pc.textSec)),
                          const SizedBox(width: 10),
                          Text(pcMoney((topSellers[i]['sales'] as num? ?? 0)),
                              style: Pc.num(13)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          PcBtn(
            label: tr('Send to owner · WhatsApp', 'মালিককে · WhatsApp'),
            variant: PcVariant.ghost,
            icon: 'wifi',
            full: true,
            onTap: null, // weekly WhatsApp digest is out of scope (Phase 2)
          ),
          const SizedBox(height: 8),
          PcBtn(
            label: tr('Print Z report', 'Z রিপোর্ট প্রিন্ট'),
            variant: PcVariant.surface,
            icon: 'printer',
            sk: 'Ctrl+P',
            full: true,
            onTap: widget.onPrintZ,
          ),
          const SizedBox(height: 8),
          PcBtn(
            label: _busy
                ? tr('Closing…', 'বন্ধ হচ্ছে…')
                : tr('Lock till · close day', 'টিল লক · দিন শেষ'),
            variant: PcVariant.dark,
            size: PcSize.xl,
            icon: 'check',
            sk: 'Ctrl+Enter',
            full: true,
            onTap: _busy ? null : _close,
          ),
        ],
      ),
    );
  }

  Widget _check(String label, String value, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Pc.surfaceAlt,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(value,
                      style: const TextStyle(fontSize: 11, color: Pc.textSec)),
                ],
              ),
            ),
          ],
        ),
      );

  String _payLabel(String key) => switch (key) {
        'cash' => tr('Cash', 'ক্যাশ'),
        'card' => tr('Card', 'কার্ড'),
        'bkash' => 'bKash',
        'nagad' => 'Nagad',
        'split' => tr('Split', 'ভাগ'),
        _ => key,
      };

  String _fmtDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final l = dt.toLocal();
    return '${l.day} ${months[l.month - 1]} ${l.year}';
  }

  Future<void> _close() async {
    setState(() => _busy = true);
    try {
      await widget.onClose(_counted, _denoms);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
