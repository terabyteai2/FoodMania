import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';

/// Bangladeshi Taka notes + coins, high → low.
const _denominations = <int>[1000, 500, 100, 50, 20, 10, 5, 2, 1];

/// A cash denomination counter. Reports the running total and a
/// `{denominationValue: count}` map (string keys) as the cashier enters counts —
/// the shape [PosAppController.openDesktopShift] / `closeDesktopShift` expect.
class DenominationGrid extends StatefulWidget {
  const DenominationGrid({required this.onChanged, super.key});

  final void Function(double total, Map<String, int> counts) onChanged;

  @override
  State<DenominationGrid> createState() => _DenominationGridState();
}

class _DenominationGridState extends State<DenominationGrid> {
  final Map<int, int> _counts = {for (final d in _denominations) d: 0};

  void _set(int denom, String raw) {
    final count = int.tryParse(raw.trim()) ?? 0;
    _counts[denom] = count < 0 ? 0 : count;
    final total = _counts.entries
        .fold<double>(0, (sum, e) => sum + e.key * e.value);
    widget.onChanged(
      total,
      {
        for (final e in _counts.entries)
          if (e.value > 0) '${e.key}': e.value,
      },
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final denom in _denominations) _row(denom),
      ],
    );
  }

  Widget _row(int denom) {
    final subtotal = denom * _counts[denom]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text('৳$denom',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
          const Text('×', style: TextStyle(color: PosColors.muted)),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextField(
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosRadii.sm),
                ),
              ),
              onChanged: (v) => _set(denom, v),
            ),
          ),
          const Spacer(),
          Text(money(context, subtotal),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: subtotal == 0 ? PosColors.muted : PosColors.primaryDark)),
        ],
      ),
    );
  }
}
