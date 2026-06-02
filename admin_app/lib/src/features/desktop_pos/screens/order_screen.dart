import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../app_controller.dart';
import '../../../app_scope.dart';
import '../../../models/desktop_pos.dart';
import '../../../models/menu_item.dart';
import '../../../models/order_item.dart';
import '../../../models/order_model.dart';
import '../../../models/order_payment_method.dart';
import '../../../models/order_service_type.dart';
import '../widgets/menu_line_customizer.dart';
import '../widgets/pc_shell.dart';
import '../widgets/pc_theme.dart';
import '../widgets/pc_widgets.dart';
import 'split_bill_dialog.dart';

/// 3 · Order detail + KOT — left rail (table + kitchen timeline + customer),
/// centre item list with SENT/UNSENT markers + add tile, right bill panel.
class OrderScreen extends StatefulWidget {
  const OrderScreen({
    required this.chrome,
    required this.order,
    required this.settings,
    required this.shift,
    required this.onChanged,
    required this.onBack,
    required this.onPrint,
    required this.onPrintPrebill,
    super.key,
  });

  final PcChrome chrome;
  final OrderModel order;
  final DesktopPosSettings settings;
  final PosShift? shift;
  final ValueChanged<OrderModel> onChanged;
  final VoidCallback onBack;
  final ValueChanged<OrderModel> onPrint;
  final ValueChanged<OrderModel> onPrintPrebill;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  bool _busy = false;
  OrderPaymentMethod _method = OrderPaymentMethod.cash;
  late double _discount = widget.order.discountAmount;

  String tr(String en, String bn) => widget.chrome.isBn ? bn : en;
  OrderModel get order => widget.order;

  double get _serviceAmount =>
      order.subtotal * widget.settings.serviceChargePercent / 100;
  double get _total =>
      order.subtotal +
      order.vatAmount +
      order.deliveryCharge +
      _serviceAmount -
      _discount;

  int get _unsent => order.items.where((i) => i.kotSentAt == null).length;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final settled = order.settledAt != null;
    final canEditOrders = app.isManager && !settled;
    return PcShell(
      chrome: widget.chrome,
      activeNav: PcNav.floor,
      title: order.tableNo == null
          ? '${order.displaySequence} · ${_serviceLabel()}'
          : tr('Table ${order.tableNo}', 'টেবিল ${order.tableNo}'),
      sub: tr(
        '${order.items.length} items · ${_statusLabel()}',
        '${order.items.length} আইটেম · ${_statusLabel()}',
      ),
      topActions: [
        PcBtn(
          label: tr('Back to floor', 'ফ্লোরে ফিরুন'),
          variant: PcVariant.ghost,
          icon: 'back',
          sk: 'Esc',
          onTap: widget.onBack,
        ),
        PcBtn(
          label: tr('Reprint KOT', 'KOT পুনরায়'),
          variant: PcVariant.ghost,
          icon: 'printer',
          onTap: () => widget.onPrintPrebill(order),
        ),
      ],
      footerHints: const [
        PcKey('Ctrl+Enter', 'Send KOT'),
        PcKey('Ctrl+P', 'Print bill'),
        PcKey('Ctrl+B', 'Split'),
        PcKey('Esc', 'Back'),
      ],
      child: Row(
        children: [
          _leftRail(),
          Expanded(child: _center(app, canEditOrders: canEditOrders)),
          _billPanel(settled, canEditOrders: canEditOrders),
        ],
      ),
    );
  }

  // ---- left rail ----------------------------------------------------------
  Widget _leftRail() {
    final dwell = DateTime.now().difference(order.createdAt).inMinutes;
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Pc.surface,
        border: Border(right: BorderSide(color: Pc.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: ListView(
        children: [
          PcEyebrow(
            order.tableNo == null
                ? tr('Service', 'সার্ভিস')
                : tr('Table', 'টেবিল'),
          ),
          const SizedBox(height: 6),
          Text(
            order.tableNo == null ? _serviceLabel() : 'T${order.tableNo}',
            style: Pc.num(32, letterSpacing: -1, height: 1),
          ),
          const SizedBox(height: 16),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: 58,
            ),
            children: [
              _miniStat(tr('Covers', 'কভার'), '${order.covers ?? '-'}'),
              _miniStat(
                tr('Waiter', 'ওয়েটার'),
                order.createdByRole ?? tr('Staff', 'স্টাফ'),
              ),
              _miniStat(tr('Seated', 'বসা'), _fmtTime(order.createdAt)),
              _miniStat(tr('Dwell', 'সময়'), '${dwell}m'),
            ],
          ),
          const SizedBox(height: 18),
          PcEyebrow(tr('Kitchen timeline', 'রান্নাঘর টাইমলাইন')),
          const SizedBox(height: 10),
          _timeline(),
          if ((order.customerName ?? '').isNotEmpty ||
              (order.mobileNumber ?? '').isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Pc.surfaceAlt,
                borderRadius: BorderRadius.circular(Pc.rMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PcEyebrow(tr('Customer', 'কাস্টমার')),
                  const SizedBox(height: 4),
                  Text(
                    order.customerName ?? tr('Guest', 'গেস্ট'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if ((order.mobileNumber ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        order.mobileNumber!,
                        style: Pc.num(
                          11.5,
                          weight: FontWeight.w400,
                          color: Pc.textSec,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Pc.surfaceAlt,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PcEyebrow(label),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Pc.num(13, weight: FontWeight.w700),
        ),
      ],
    ),
  );

  Widget _timeline() {
    final events = <(String, String, Color)>[
      (_fmtTime(order.createdAt), tr('Order opened', 'অর্ডার খোলা'), Pc.good),
    ];
    for (final batch in order.kotBatches) {
      final sentAt = DateTime.tryParse('${batch['sentAt']}');
      final ids = (batch['itemIds'] as List?)?.length ?? 0;
      events.add((
        sentAt == null ? '—' : _fmtTime(sentAt),
        tr('KOT sent · $ids items', 'KOT পাঠানো · $ids আইটেম'),
        Pc.good,
      ));
    }
    if (_unsent > 0) {
      events.add((
        tr('now', 'এখন'),
        tr('$_unsent item(s) — UNSENT', '$_unsent আইটেম — পাঠানো হয়নি'),
        Pc.accent,
      ));
    }
    return Column(
      children: [
        for (final e in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: e.$3,
                    shape: BoxShape.circle,
                    border: Border.all(color: Pc.surface, width: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.$1,
                        style: Pc.mono(
                          10.5,
                          weight: FontWeight.w700,
                          color: Pc.textSec,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        e.$2,
                        style: const TextStyle(fontSize: 12, color: Pc.text),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---- centre -------------------------------------------------------------
  Widget _center(PosAppController app, {required bool canEditOrders}) {
    return Column(
      children: [
        if ((order.note ?? '').isNotEmpty)
          Container(
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Pc.surface,
              border: Border.all(color: Pc.border),
              borderRadius: BorderRadius.circular(Pc.rMd),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Pc.surfaceAlt,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    'KITCHEN NOTE',
                    style: Pc.mono(10, color: Pc.textSec),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '"${order.note}"',
                    style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: Pc.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            margin: EdgeInsets.fromLTRB(
              18,
              (order.note ?? '').isEmpty ? 18 : 0,
              18,
              0,
            ),
            decoration: BoxDecoration(
              color: Pc.surface,
              border: Border.all(color: Pc.border),
              borderRadius: BorderRadius.circular(Pc.rMd),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // header row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Pc.surfaceAlt,
                    border: Border(bottom: BorderSide(color: Pc.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'ITEM',
                          style: Pc.mono(9.5, color: Pc.textSec),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'QTY',
                          style: Pc.mono(9.5, color: Pc.textSec),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'LINE TOTAL',
                          textAlign: TextAlign.right,
                          style: Pc.mono(9.5, color: Pc.textSec),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (var i = 0; i < order.items.length; i++)
                        _itemRow(order.items[i], i),
                      if (canEditOrders) _addRow(app),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // footer actions
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              if (canEditOrders)
                PcBtn(
                  label: tr('Move table', 'টেবিল সরান'),
                  variant: PcVariant.ghost,
                  size: PcSize.lg,
                  icon: 'swap',
                  onTap: _busy ? null : _moveTable,
                ),
              const Spacer(),
              PcBtn(
                label: tr('Print bill (pre-bill)', 'প্রি-বিল'),
                variant: PcVariant.surface,
                size: PcSize.lg,
                icon: 'printer',
                onTap: () => widget.onPrintPrebill(order),
              ),
              const SizedBox(width: 10),
              PcBtn(
                label: _unsent > 0
                    ? tr('Send $_unsent to kitchen', '$_unsent টি পাঠান')
                    : tr('All sent', 'সব পাঠানো'),
                variant: PcVariant.primary,
                size: PcSize.lg,
                icon: 'check',
                sk: 'Ctrl+Enter',
                onTap: (_busy || _unsent == 0) ? null : _sendKot,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _itemRow(OrderItem item, int i) {
    final pending = item.kotSentAt == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: pending ? Pc.accentWash : Pc.surface,
        border: const Border(bottom: BorderSide(color: Pc.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: pending ? Pc.accentSoft : Pc.goodSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        pending
                            ? 'NEW · UNSENT'
                            : 'SENT ${_fmtTime(item.kotSentAt!)}',
                        style: Pc.mono(
                          9.5,
                          color: pending ? Pc.accent : Pc.good,
                        ),
                      ),
                    ),
                  ],
                ),
                if ((item.note ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '"${item.note}"',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: Pc.textSec,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${item.qty} × ${pcMoney(item.price)}',
              style: Pc.num(12.5, weight: FontWeight.w400, color: Pc.textSec),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              pcMoney(item.lineTotal),
              textAlign: TextAlign.right,
              style: Pc.num(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addRow(PosAppController app) => InkWell(
    onTap: _busy ? null : () => _addItem(app),
    child: Container(
      padding: const EdgeInsets.all(14),
      color: Pc.surfaceAlt,
      child: Row(
        children: [
          const PcIcon('plus', size: 18, color: Pc.textTer),
          const SizedBox(width: 10),
          Text(
            tr('Add item · pick from menu', 'আইটেম যোগ · মেনু থেকে'),
            style: const TextStyle(fontSize: 13, color: Pc.textSec),
          ),
          const Spacer(),
          const PcBtn(
            label: 'Open menu',
            variant: PcVariant.surface,
            size: PcSize.sm,
            sk: 'F4',
          ),
        ],
      ),
    ),
  );

  // ---- bill panel ---------------------------------------------------------
  Widget _billPanel(bool settled, {required bool canEditOrders}) {
    return Container(
      width: 340,
      decoration: const BoxDecoration(
        color: Pc.surface,
        border: Border(left: BorderSide(color: Pc.border)),
      ),
      child: ListView(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Pc.border)),
            ),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PcEyebrow(
                  tr('Bill', 'বিল') +
                      (order.tableNo == null ? '' : ' · T${order.tableNo}'),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(
                    'Running total · ${order.covers ?? 1} covers',
                    'চলমান মোট · ${order.covers ?? 1} কভার',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: Column(
              children: [
                _row(
                  tr('Subtotal · ${order.items.length} items', 'সাবটোটাল'),
                  order.subtotal,
                ),
                if (_discount > 0)
                  _row(tr('Discount', 'ডিসকাউন্ট'), -_discount, color: Pc.late),
                if (_serviceAmount > 0)
                  _row(
                    '${tr('Service', 'সার্ভিস')} ${widget.settings.serviceChargePercent}%',
                    _serviceAmount,
                  ),
                if (order.vatAmount > 0)
                  _row('VAT ${order.vatRatePercent}%', order.vatAmount),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      tr('Total due', 'মোট প্রদেয়'),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      pcMoney(_total),
                      style: Pc.num(30, letterSpacing: -0.7),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canEditOrders)
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Pc.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PcEyebrow(tr('Adjustments · owner', 'সমন্বয় · মালিক')),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 3.2,
                    children: [
                      PcBtn(
                        label: tr('Discount %', 'ডিসকাউন্ট %'),
                        variant: PcVariant.surface,
                        size: PcSize.sm,
                        onTap: () => _discountDialog(true),
                      ),
                      PcBtn(
                        label: tr('Discount ৳', 'ডিসকাউন্ট ৳'),
                        variant: PcVariant.surface,
                        size: PcSize.sm,
                        onTap: () => _discountDialog(false),
                      ),
                      PcBtn(
                        label: tr('Void', 'বাতিল'),
                        variant: PcVariant.surface,
                        size: PcSize.sm,
                        onTap: () => _audit('void'),
                      ),
                      PcBtn(
                        label: tr('Comp', 'কম্প'),
                        variant: PcVariant.surface,
                        size: PcSize.sm,
                        onTap: () => _audit('comp'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Pc.border)),
            ),
            child: settled
                ? Column(
                    children: [
                      const PcPill(
                        label: 'SETTLED',
                        tone: PcTone.good,
                        dot: true,
                      ),
                      const SizedBox(height: 10),
                      PcBtn(
                        label: tr('Print receipt', 'রিসিট প্রিন্ট'),
                        variant: PcVariant.dark,
                        size: PcSize.xl,
                        icon: 'printer',
                        full: true,
                        onTap: () => widget.onPrint(order),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      PcEyebrow(tr('Settle bill', 'বিল নিষ্পত্তি')),
                      const SizedBox(height: 8),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 2.8,
                        children: [
                          _methodBtn(
                            tr('Cash', 'ক্যাশ'),
                            OrderPaymentMethod.cash,
                            'F9',
                          ),
                          _methodBtn('bKash', OrderPaymentMethod.bkash, 'F10'),
                          _methodBtn('Nagad', OrderPaymentMethod.nagad, 'F11'),
                          _methodBtn(
                            tr('Card', 'কার্ড'),
                            OrderPaymentMethod.card,
                            'F12',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      PcBtn(
                        label: tr(
                          'Split bill · item · % · equal',
                          'ভাগ · আইটেম · % · সমান',
                        ),
                        variant: PcVariant.ghost,
                        icon: 'split',
                        sk: 'Ctrl+B',
                        full: true,
                        onTap: _busy ? null : _split,
                      ),
                      const SizedBox(height: 8),
                      PcBtn(
                        label: tr(
                          'Settle · ${pcMoney(_total)}',
                          'নিষ্পত্তি · ${pcMoney(_total)}',
                        ),
                        variant: PcVariant.dark,
                        size: PcSize.xl,
                        icon: 'printer',
                        sk: 'Ctrl+Enter',
                        full: true,
                        onTap: _busy
                            ? null
                            : () => _settle([
                                PcSplitShare(
                                  fraction: 1,
                                  paymentMethod: _method,
                                ),
                              ]),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _methodBtn(String label, OrderPaymentMethod method, String sk) {
    final on = _method == method;
    return PcBtn(
      label: label,
      variant: on ? PcVariant.primary : PcVariant.surface,
      sk: sk,
      onTap: () => setState(() => _method = method),
    );
  }

  Widget _row(String label, double value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Pc.textSec)),
        const Spacer(),
        Text(
          pcMoney(value),
          style: Pc.num(13, weight: FontWeight.w600, color: color ?? Pc.text),
        ),
      ],
    ),
  );

  // ---- actions ------------------------------------------------------------
  String _serviceLabel() {
    final t = order.serviceType;
    if (t == null) return tr('Counter', 'কাউন্টার');
    return widget.chrome.isBn ? t.banglaLabel : t.label;
  }

  String _statusLabel() => widget.chrome.isBn
      ? switch (order.status.adminStatus.name) {
          'pending' => 'পেন্ডিং',
          'accepted' => 'রান্নাঘরে',
          'served' => 'পরিবেশিত',
          _ => 'বাতিল',
        }
      : order.status.label;

  String _fmtTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m ${local.hour < 12 ? 'AM' : 'PM'}';
  }

  Future<void> _sendKot() async {
    setState(() => _busy = true);
    try {
      widget.onChanged(await AppScope.of(context).sendDesktopKot(order));
    } catch (e) {
      _msg('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addItem(PosAppController app) async {
    final available = app.menuItems
        .where((MenuItem m) => m.isAvailable)
        .toList(growable: false);
    final picked = await showDialog<MenuItem>(
      context: context,
      builder: (_) =>
          _MenuPickerDialog(items: available, isBn: widget.chrome.isBn),
    );
    if (picked == null) return;
    if (!mounted) return;
    final selection = await showDesktopMenuLineCustomizer(
      context,
      item: picked,
      isBn: widget.chrome.isBn,
    );
    if (selection == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final requests = <OrderRequestItem>[
        for (final item in order.items)
          OrderRequestItem(
            menuItemId: item.menuItemId,
            qty: item.qty,
            note: item.note,
            existingOrderItemId: item.id,
            unitPrice: item.price,
            nameOverride: item.name,
            nameEnOverride: item.nameEn,
            nameBnOverride: item.nameBn,
          ),
      ];
      requests.add(selection.toRequestItem());
      await app.updateOrderItems(order.id, requests);
      final updated = await app.database.getOrderById(order.id);
      if (updated != null) widget.onChanged(updated);
    } catch (e) {
      _msg('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _discountDialog(bool percent) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          percent
              ? tr('Discount %', 'ডিসকাউন্ট %')
              : tr('Discount ৳', 'ডিসকাউন্ট ৳'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: percent ? '%' : '৳'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel', 'বাতিল')),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text) ?? 0),
            child: Text(tr('Apply', 'প্রয়োগ')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value <= 0) return;
    setState(() {
      _discount = percent
          ? double.parse((order.subtotal * value / 100).toStringAsFixed(2))
          : value;
    });
  }

  Future<void> _audit(String action) async {
    final app = AppScope.of(context);
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          action == 'void'
              ? tr('Void order', 'অর্ডার বাতিল')
              : tr('Record comp', 'কম্প রেকর্ড'),
        ),
        content: TextField(
          controller: reason,
          autofocus: true,
          decoration: InputDecoration(labelText: tr('Reason', 'কারণ')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel', 'বাতিল')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Confirm', 'নিশ্চিত')),
          ),
        ],
      ),
    );
    if (ok != true || reason.text.trim().isEmpty) {
      reason.dispose();
      return;
    }
    setState(() => _busy = true);
    try {
      await app.auditDesktopOrder(
        order: order,
        action: action,
        reason: reason.text.trim(),
      );
      if (action == 'void') widget.onBack();
    } catch (e) {
      _msg('$e');
    } finally {
      reason.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moveTable() async {
    final app = AppScope.of(context);
    final controller = TextEditingController(text: order.tableNo ?? '');
    final table = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Move table', 'টেবিল সরান')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: tr('New table label', 'নতুন টেবিল'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel', 'বাতিল')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(tr('Move', 'সরান')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (table == null || table.isEmpty) return;
    setState(() => _busy = true);
    try {
      await app.updateOrderDetails(
        order.id,
        serviceType: OrderServiceType.dineIn,
        tableNo: table,
        note: order.note,
        customerName: order.customerName,
        deliveryAddress: order.deliveryAddress,
        mobileNumber: order.mobileNumber,
      );
      final updated = await app.database.getOrderById(order.id);
      if (updated != null) widget.onChanged(updated);
    } catch (e) {
      _msg('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _split() async {
    final lang = AppScope.of(context).language;
    final plan = await showDialog<PcSplitPlan>(
      context: context,
      builder: (_) => PcSplitBillDialog(
        total: _total,
        isBn: widget.chrome.isBn,
        items: [
          for (final item in order.items)
            PcSplitItem(
              id: item.id,
              label: '${item.localizedName(lang)} × ${item.qty}',
              lineTotal: item.lineTotal,
            ),
        ],
      ),
    );
    if (plan == null) return;
    await _settle(plan.shares);
  }

  Future<void> _settle(List<PcSplitShare> shares) async {
    if (widget.shift == null) {
      _msg(
        tr(
          'Open the outlet shift before settling.',
          'নিষ্পত্তির আগে শিফট খুলুন।',
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final app = AppScope.of(context);
    try {
      final total = _total;
      final lines = <PosSettlementLine>[];
      var allocated = 0.0;
      for (var i = 0; i < shares.length; i++) {
        final amount = i == shares.length - 1
            ? double.parse((total - allocated).toStringAsFixed(2))
            : double.parse((total * shares[i].fraction).toStringAsFixed(2));
        allocated += amount;
        lines.add(
          PosSettlementLine(
            eventId: const Uuid().v4(),
            paymentMethod: shares[i].paymentMethod.value,
            amount: amount,
            payerLabel: shares.length > 1 ? shares[i].payerLabel : null,
          ),
        );
      }
      final settled = await app.settleDesktopOrder(
        order: order,
        shift: widget.shift!,
        settlements: lines,
        discountAmount: _discount,
        serviceChargeRatePercent: widget.settings.serviceChargePercent,
        serviceChargeAmount: _serviceAmount,
      );
      widget.onChanged(settled);
      widget.onPrint(settled);
    } catch (e) {
      _msg('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _msg(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

/// Lightweight searchable menu picker for adding a line to an open order.
class _MenuPickerDialog extends StatefulWidget {
  const _MenuPickerDialog({required this.items, required this.isBn});
  final List<MenuItem> items;
  final bool isBn;

  @override
  State<_MenuPickerDialog> createState() => _MenuPickerDialogState();
}

class _MenuPickerDialogState extends State<_MenuPickerDialog> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).language;
    final q = _search.text.trim().toLowerCase();
    final items = widget.items
        .where((m) => q.isEmpty || m.searchText(lang).contains(q))
        .toList(growable: false);
    return AlertDialog(
      title: Text(widget.isBn ? 'আইটেম যোগ করুন' : 'Add item'),
      content: SizedBox(
        width: 420,
        height: 460,
        child: Column(
          children: [
            TextField(
              controller: _search,
              autofocus: true,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.isBn ? 'খুঁজুন' : 'Search',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) => ListTile(
                  dense: true,
                  leading: DesktopMenuThumb(
                    item: items[i],
                    size: 36,
                    radius: 8,
                  ),
                  title: Text(items[i].localizedName(lang)),
                  trailing: Text(pcMoney(items[i].price), style: Pc.num(13)),
                  onTap: () => Navigator.pop(context, items[i]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.isBn ? 'বাতিল' : 'Cancel'),
        ),
      ],
    );
  }
}
