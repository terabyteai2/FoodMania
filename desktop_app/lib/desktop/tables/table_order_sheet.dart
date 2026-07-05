import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/desktop_pos.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_status.dart';

import '../billing/settle_flow.dart';
import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';

/// Actions for a running (occupied-table) order: view the ticket, send KOT, or
/// settle & print. Returns an outcome message for the caller to toast.
Future<String?> showTableOrderSheet(
  BuildContext context, {
  required OrderModel order,
  required PosShift? shift,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TableOrderDialog(order: order, shift: shift),
  );
}

class _TableOrderDialog extends StatefulWidget {
  const _TableOrderDialog({required this.order, required this.shift});
  final OrderModel order;
  final PosShift? shift;

  @override
  State<_TableOrderDialog> createState() => _TableOrderDialogState();
}

class _TableOrderDialogState extends State<_TableOrderDialog> {
  late final OrderModel _order = widget.order;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).language;
    final title = [
      _order.displaySequence,
      if ((_order.tableNo ?? '').isNotEmpty) 'Table ${_order.tableNo}',
    ].join(' · ');

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.xl),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in _order.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text('${item.qty}×',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: PosColors.ink2)),
                          ),
                          Expanded(
                            child: Text(item.localizedName(lang),
                                style: const TextStyle(fontSize: 13.5)),
                          ),
                          Text(money(context, item.lineTotal),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                const Text('Total',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(money(context, _order.total),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: PosColors.primary)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => _void(),
          child: Text('Void', style: TextStyle(color: PosColors.danger)),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _kot,
          child: const Text('Send KOT'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PosColors.primary),
          onPressed: (_busy || widget.shift == null) ? null : _settle,
          child: const Text('Settle & Save',
              style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Future<void> _kot() async {
    final app = AppScope.read(context);
    setState(() => _busy = true);
    try {
      final updated = await app.sendDesktopKot(_order);
      try {
        await app.printOrderTicket(updated);
      } catch (_) {}
      if (mounted) Navigator.pop(context, 'KOT sent ${_order.displaySequence}');
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _settle() async {
    final app = AppScope.read(context);
    final shift = widget.shift;
    if (shift == null) return;
    setState(() => _busy = true);
    final message =
        await runSettlement(context, app, order: _order, shift: shift);
    if (!mounted) return;
    if (message == null) {
      setState(() => _busy = false);
      return;
    }
    Navigator.pop(context, message);
  }

  Future<void> _void() async {
    final app = AppScope.read(context);
    setState(() => _busy = true);
    try {
      await app.updateOrderStatus(_order.id, OrderStatus.rejected);
      if (mounted) Navigator.pop(context, 'Voided ${_order.displaySequence}');
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }
}
