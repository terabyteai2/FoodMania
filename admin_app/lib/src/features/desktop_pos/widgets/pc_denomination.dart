import 'package:flutter/material.dart';

import 'pc_theme.dart';
import 'pc_widgets.dart';

/// Bangladeshi note/coin denominations, high → low.
const List<int> kPcDenominations = [1000, 500, 200, 100, 50, 20, 10, 5, 2, 1];

/// A denomination count grid (denom · count stepper · per-unit · line total).
/// Reports the running total and a `{ '1000': 5, ... }` map on every change.
class PcDenominationGrid extends StatefulWidget {
  const PcDenominationGrid({
    required this.onChanged,
    this.isBn = false,
    super.key,
  });

  final void Function(double total, Map<String, int> denominations) onChanged;
  final bool isBn;

  @override
  State<PcDenominationGrid> createState() => _PcDenominationGridState();
}

class _PcDenominationGridState extends State<PcDenominationGrid> {
  final Map<int, int> _counts = {for (final d in kPcDenominations) d: 0};

  double get _total => _counts.entries.fold(0, (s, e) => s + e.key * e.value);

  Map<String, int> get _denoms => {
    for (final e in _counts.entries)
      if (e.value > 0) '${e.key}': e.value,
  };

  void _bump(int denom, int delta) {
    setState(() {
      _counts[denom] = (_counts[denom]! + delta).clamp(0, 9999);
    });
    widget.onChanged(_total, _denoms);
  }

  String tr(String en, String bn) => widget.isBn ? bn : en;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Pc.border),
        borderRadius: BorderRadius.circular(Pc.rSm),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Pc.surfaceAlt,
              border: Border(bottom: BorderSide(color: Pc.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('DENOM', style: Pc.mono(9.5, color: Pc.textSec)),
                ),
                Expanded(
                  flex: 4,
                  child: Text('COUNT', style: Pc.mono(9.5, color: Pc.textSec)),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'TOTAL',
                    textAlign: TextAlign.right,
                    style: Pc.mono(9.5, color: Pc.textSec),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < kPcDenominations.length; i++)
            _denomRow(kPcDenominations[i], i < kPcDenominations.length - 1),
        ],
      ),
    );
  }

  Widget _denomRow(int denom, bool divider) {
    final count = _counts[denom]!;
    final lineTotal = denom * count;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: count > 0 ? Pc.surface : Pc.bg,
        border: divider
            ? const Border(bottom: BorderSide(color: Pc.border))
            : null,
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(pcMoney(denom), style: Pc.num(14))),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: PcQtyStep(
                qty: count,
                onMinus: () => _bump(denom, -1),
                onPlus: () => _bump(denom, 1),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              pcMoney(lineTotal),
              textAlign: TextAlign.right,
              style: Pc.num(14, color: count > 0 ? Pc.text : Pc.textTer),
            ),
          ),
        ],
      ),
    );
  }
}
