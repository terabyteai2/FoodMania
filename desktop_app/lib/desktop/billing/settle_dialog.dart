import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/order_payment_method.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';

/// Result of the settlement popover.
class SettleResult {
  const SettleResult({
    required this.method,
    required this.discountAmount,
    required this.tendered,
  });

  final OrderPaymentMethod method;
  final double discountAmount;
  final double tendered;
}

/// Payment-mode + discount settlement (petpooja13/14 right-panel radios +
/// "Settlement Amount"). Returns a [SettleResult], or null on cancel.
Future<SettleResult?> showSettleDialog(
  BuildContext context, {
  required double grossTotal,
}) {
  return showDialog<SettleResult>(
    context: context,
    builder: (_) => _SettleDialog(grossTotal: grossTotal),
  );
}

const _modes = <OrderPaymentMethod>[
  OrderPaymentMethod.cash,
  OrderPaymentMethod.card,
  OrderPaymentMethod.bkash,
  OrderPaymentMethod.nagad,
];

class _SettleDialog extends StatefulWidget {
  const _SettleDialog({required this.grossTotal});
  final double grossTotal;

  @override
  State<_SettleDialog> createState() => _SettleDialogState();
}

class _SettleDialogState extends State<_SettleDialog> {
  OrderPaymentMethod _method = OrderPaymentMethod.cash;
  final _discount = TextEditingController(text: '0');
  final _tendered = TextEditingController();

  double get _discountValue {
    final v = double.tryParse(_discount.text.trim()) ?? 0;
    return v.clamp(0, widget.grossTotal).toDouble();
  }

  double get _net => widget.grossTotal - _discountValue;

  double get _tenderedValue =>
      double.tryParse(_tendered.text.trim()) ?? _net;

  double get _change =>
      (_tenderedValue - _net).clamp(0, double.infinity).toDouble();

  @override
  void dispose() {
    _discount.dispose();
    _tendered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBn = AppScope.of(context).language.code == 'bn';
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.xl),
      ),
      title: const Text('Settle & save',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _amountRow('Total', widget.grossTotal),
            const SizedBox(height: 12),
            _label('Payment mode'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final m in _modes) _modeChip(m, isBn)],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _numField(_discount, 'Discount (৳)',
                      onChanged: () => setState(() {})),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numField(_tendered, 'Tendered (৳)',
                      onChanged: () => setState(() {})),
                ),
              ],
            ),
            const Divider(height: 26),
            _amountRow('Net payable', _net, strong: true),
            if (_change > 0) ...[
              const SizedBox(height: 6),
              _amountRow('Change', _change, tone: PosColors.success),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: PosColors.ink2)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PosColors.primary),
          onPressed: () => Navigator.pop(
            context,
            SettleResult(
              method: _method,
              discountAmount: _discountValue,
              tendered: _tenderedValue,
            ),
          ),
          child: const Text('Settle & save',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5));

  Widget _amountRow(String label, double value,
      {bool strong = false, Color? tone}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: strong ? 15 : 13.5,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                color: tone ?? PosColors.ink2)),
        const Spacer(),
        Text(money(context, value),
            style: TextStyle(
                fontSize: strong ? 18 : 14,
                fontWeight: FontWeight.w800,
                color: tone ?? PosColors.primaryDark)),
      ],
    );
  }

  Widget _modeChip(OrderPaymentMethod mode, bool isBn) {
    final active = mode == _method;
    return InkWell(
      borderRadius: BorderRadius.circular(PosRadii.md),
      onTap: () => setState(() => _method = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? PosColors.primary : PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.md),
          border: Border.all(
              color: active ? PosColors.primary : PosColors.lineStrong),
        ),
        child: Text(
          isBn ? mode.banglaLabel : mode.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : PosColors.primaryDark,
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController ctl, String label,
      {required VoidCallback onChanged}) {
    return TextField(
      controller: ctl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
        ),
      ),
    );
  }
}
