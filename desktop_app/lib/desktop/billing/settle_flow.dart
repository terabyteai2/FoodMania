import 'package:flutter/material.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/models/desktop_pos.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:uuid/uuid.dart';

import '../theme/desk_format.dart';
import 'settle_dialog.dart';

const _uuid = Uuid();

/// Shared settlement flow used by both the billing screen and the Tables
/// occupied-order sheet: shows the payment popover for [order], settles it
/// against [shift], and prints the customer invoice (best-effort).
///
/// Returns a human-readable outcome message, or null if the user cancelled.
Future<String?> runSettlement(
  BuildContext context,
  PosAppController app, {
  required OrderModel order,
  required PosShift shift,
}) async {
  final result = await showSettleDialog(context, grossTotal: order.total);
  if (result == null) return null;
  final net = order.total - result.discountAmount;
  final settled = await app.settleDesktopOrder(
    order: order,
    shift: shift,
    settlements: [
      PosSettlementLine(
        eventId: _uuid.v4(),
        paymentMethod: result.method.value,
        amount: net < 0 ? 0 : net,
      ),
    ],
    discountAmount: result.discountAmount,
    serviceChargeRatePercent: 0,
    serviceChargeAmount: 0,
  );
  try {
    await app.printCustomerInvoice(settled);
  } catch (_) {
    // Printer issues must never block completing the sale.
  }
  if (!context.mounted) return 'Settled ${order.displaySequence}';
  return 'Settled ${order.displaySequence} · ${money(context, net < 0 ? 0 : net)}';
}
