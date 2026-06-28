import 'package:flutter/material.dart';

import '../../../models/order_model.dart';
import '../widgets/pc_shell.dart';
import '../widgets/pc_theme.dart';
import '../widgets/pc_widgets.dart';

/// Orders list — recent tickets, newest first. Tap to open the order detail.
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({
    required this.chrome,
    required this.orders,
    required this.onOpen,
    super.key,
  });

  final PcChrome chrome;
  final List<OrderModel> orders;
  final ValueChanged<OrderModel> onOpen;

  String tr(String en, String bn) => chrome.isBn ? bn : en;

  @override
  Widget build(BuildContext context) {
    final sorted = [...orders]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return PcShell(
      chrome: chrome,
      activeNav: PcNav.orders,
      title: tr('Orders', 'অর্ডার'),
      sub: tr(
        '${orders.length} tickets · newest first',
        '${orders.length} টিকেট · নতুন প্রথমে',
      ),
      child: sorted.isEmpty
          ? Center(
              child: Text(
                tr('No orders yet today.', 'আজ এখনো অর্ডার নেই।'),
                style: const TextStyle(color: Pc.textSec),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [for (final o in sorted) _row(context, o)],
            ),
    );
  }

  Widget _row(BuildContext context, OrderModel o) {
    final open = o.status.isOpen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onOpen(o),
          child: PcCard(
            pad: 14,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: open ? Pc.accentSoft : Pc.surfaceAlt,
                    borderRadius: BorderRadius.circular(Pc.rSm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    o.displaySequence,
                    style: Pc.num(13, color: open ? Pc.accent : Pc.textSec),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o.tableNo == null
                            ? _serviceLabel(o)
                            : tr('Table ${o.tableNo}', 'টেবিল ${o.tableNo}'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${o.items.length} ${tr('items', 'আইটেম')} · ${o.status.label}',
                        style: const TextStyle(fontSize: 12, color: Pc.textSec),
                      ),
                    ],
                  ),
                ),
                if (o.settledAt != null)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: PcPill(
                      label: 'SETTLED',
                      tone: PcTone.good,
                      dot: true,
                    ),
                  ),
                Text(pcMoney(o.total), style: Pc.num(16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _serviceLabel(OrderModel o) {
    final t = o.serviceType;
    if (t == null) return tr('Counter', 'কাউন্টার');
    return chrome.isBn ? t.banglaLabel : t.label;
  }
}
