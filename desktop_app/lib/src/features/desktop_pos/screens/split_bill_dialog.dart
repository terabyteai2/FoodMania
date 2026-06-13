import 'package:flutter/material.dart';

import '../../../models/order_payment_method.dart';
import '../widgets/pc_theme.dart';
import '../widgets/pc_widgets.dart';

/// One payer's share of a split bill.
class PcSplitShare {
  const PcSplitShare({
    required this.fraction,
    required this.paymentMethod,
    this.payerLabel,
  });
  final double fraction;
  final OrderPaymentMethod paymentMethod;
  final String? payerLabel;
}

class PcSplitPlan {
  const PcSplitPlan(this.shares);
  final List<PcSplitShare> shares;
}

/// A single line on the bill, used for the "by item" split tab.
class PcSplitItem {
  const PcSplitItem({required this.id, required this.label, required this.lineTotal});
  final String id;
  final String label;
  final double lineTotal;
}

enum _Mode { item, percentage, equal }

/// Bill-split modal rebuilt to the pc-split mockup: tabs (by item / % / equal),
/// payer cards, live balance check. Returns a [PcSplitPlan] of N shares whose
/// fractions sum to 1 — the caller turns these into N settlement lines.
class PcSplitBillDialog extends StatefulWidget {
  const PcSplitBillDialog({
    required this.total,
    required this.items,
    required this.isBn,
    super.key,
  });
  final double total;
  final List<PcSplitItem> items;
  final bool isBn;

  @override
  State<PcSplitBillDialog> createState() => _PcSplitBillDialogState();
}

class _PcSplitBillDialogState extends State<PcSplitBillDialog> {
  _Mode _mode = _Mode.equal;
  int _equalCount = 2;
  String? _error;
  final _pctA = TextEditingController(text: '50');
  final _pctB = TextEditingController(text: '50');
  final _methods = List<OrderPaymentMethod>.filled(4, OrderPaymentMethod.cash);
  late final Map<String, int> _itemPayers = {
    for (var i = 0; i < widget.items.length; i++) widget.items[i].id: i % 2,
  };

  String tr(String en, String bn) => widget.isBn ? bn : en;
  int get _payerCount => _mode == _Mode.equal ? _equalCount : 2;

  @override
  void dispose() {
    _pctA.dispose();
    _pctB.dispose();
    super.dispose();
  }

  String _money(double v) => '৳${v.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Pc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Pc.rMd),
        side: const BorderSide(color: Pc.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Pc.border)),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PcEyebrow(tr('Split bill', 'বিল ভাগ করুন')),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          'Total ${_money(widget.total)}',
                          'মোট ${_money(widget.total)}',
                        ),
                        style: Pc.num(18, letterSpacing: -0.3),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const PcIcon('close', size: 18),
                  ),
                ],
              ),
            ),
            // tabs
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              child: Row(
                children: [
                  _tab(tr('By item', 'আইটেম'), _Mode.item),
                  _tab(tr('By percentage', 'শতাংশ'), _Mode.percentage),
                  _tab(tr('Equal split', 'সমান ভাগ'), _Mode.equal),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_mode == _Mode.equal) _equalControls(),
                    if (_mode == _Mode.percentage) _pctControls(),
                    if (_mode == _Mode.item) _itemControls(),
                    const SizedBox(height: 14),
                    ..._payerMethodPickers(),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        style: const TextStyle(color: Pc.danger, fontSize: 12.5),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // actions
            Container(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
              decoration: const BoxDecoration(
                color: Pc.surfaceAlt,
                border: Border(top: BorderSide(color: Pc.border)),
              ),
              child: Row(
                children: [
                  const Spacer(),
                  PcBtn(
                    label: tr('Cancel', 'বাতিল'),
                    variant: PcVariant.ghost,
                    sk: 'Esc',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  PcBtn(
                    label: tr(
                      'Settle · print $_payerCount receipts',
                      'নিষ্পত্তি · $_payerCount রিসিট',
                    ),
                    variant: PcVariant.primary,
                    size: PcSize.lg,
                    icon: 'printer',
                    onTap: _confirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, _Mode mode) {
    final on = _mode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() {
            _mode = mode;
            _error = null;
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: on ? Pc.accentSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: on ? Pc.accent : Pc.textSec,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _equalControls() => Row(
    children: [
      for (final n in [2, 3, 4])
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: PcBtn(
            label: tr('$n payers', '$n জন'),
            variant: _equalCount == n ? PcVariant.dark : PcVariant.surface,
            onTap: () => setState(() => _equalCount = n),
          ),
        ),
    ],
  );

  Widget _pctControls() => Row(
    children: [
      Expanded(child: _pctField(_pctA, tr('Payer 1 %', 'পরিশোধকারী ১ %'))),
      const SizedBox(width: 10),
      Expanded(child: _pctField(_pctB, tr('Payer 2 %', 'পরিশোধকারী ২ %'))),
    ],
  );

  Widget _pctField(TextEditingController c, String label) => TextField(
    controller: c,
    keyboardType: TextInputType.number,
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(labelText: label),
  );

  Widget _itemControls() => Column(
    children: [
      for (final item in widget.items)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Pc.surfaceAlt,
            borderRadius: BorderRadius.circular(Pc.rSm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(fontSize: 13, color: Pc.text),
                ),
              ),
              Text(_money(item.lineTotal), style: Pc.num(13)),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _itemPayers[item.id],
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: 0, child: Text(tr('Payer 1', 'পরি. ১'))),
                  DropdownMenuItem(value: 1, child: Text(tr('Payer 2', 'পরি. ২'))),
                ],
                onChanged: (v) => setState(() => _itemPayers[item.id] = v!),
              ),
            ],
          ),
        ),
    ],
  );

  List<Widget> _payerMethodPickers() => [
    for (var i = 0; i < _payerCount; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DropdownButtonFormField<OrderPaymentMethod>(
          initialValue: _methods[i],
          decoration: InputDecoration(
            labelText: tr(
              'Payer ${i + 1} payment',
              'পরিশোধকারী ${i + 1}-এর পেমেন্ট',
            ),
          ),
          items: [
            for (final m in const [
              OrderPaymentMethod.cash,
              OrderPaymentMethod.card,
              OrderPaymentMethod.bkash,
              OrderPaymentMethod.nagad,
            ])
              DropdownMenuItem(
                value: m,
                child: Text(widget.isBn ? m.banglaLabel : m.label),
              ),
          ],
          onChanged: (v) => setState(() => _methods[i] = v!),
        ),
      ),
  ];

  void _confirm() {
    late List<double> fractions;
    if (_mode == _Mode.equal) {
      fractions = List.filled(_equalCount, 1 / _equalCount);
    } else if (_mode == _Mode.percentage) {
      final values = [
        double.tryParse(_pctA.text) ?? 0,
        double.tryParse(_pctB.text) ?? 0,
      ];
      if (values.any((v) => v <= 0) || (values[0] + values[1] - 100).abs() > 0.001) {
        setState(
          () => _error = tr(
            'Percentages must be positive and add up to 100%.',
            'শতাংশ ধনাত্মক হতে হবে এবং যোগফল ১০০% হতে হবে।',
          ),
        );
        return;
      }
      fractions = values.map((v) => v / 100).toList(growable: false);
    } else {
      final subtotals = [0.0, 0.0];
      for (final item in widget.items) {
        subtotals[_itemPayers[item.id] ?? 0] += item.lineTotal;
      }
      final total = subtotals[0] + subtotals[1];
      if (subtotals.any((v) => v <= 0) || total <= 0) {
        setState(
          () => _error = tr(
            'Assign at least one item to each payer.',
            'প্রত্যেক পরিশোধকারীকে অন্তত একটি আইটেম দিন।',
          ),
        );
        return;
      }
      fractions = subtotals.map((v) => v / total).toList(growable: false);
    }
    Navigator.pop(
      context,
      PcSplitPlan([
        for (var i = 0; i < fractions.length; i++)
          PcSplitShare(
            fraction: fractions[i],
            paymentMethod: _methods[i],
            payerLabel: tr('Payer ${i + 1}', 'পরিশোধকারী ${i + 1}'),
          ),
      ]),
    );
  }
}
