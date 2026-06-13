// QuickBytes Desktop — Orders: two-pane queue (list + detail). Faithful to
// `desktop-orders.jsx`. Pending → Accept (accent-wash, not solid lime).
// Accepted → Print KOT / Print Bill (Bill → completed). Serial is the hero,
// type replaces the customer name, channel is a quiet glyph.

import 'package:flutter/material.dart';

import '../../../app_controller.dart';
import '../../../app_scope.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/order_item.dart';
import '../../../models/order_model.dart';
import '../../../models/order_service_type.dart';
import '../../../models/order_source.dart';
import '../../../models/order_status.dart';
import '../desk_controller.dart';
import '../widgets/dk_icons.dart';
import '../widgets/dk_kit.dart';

String dkChannelKey(OrderSource source) => switch (source) {
      OrderSource.facebookMessenger => 'chatbot',
      OrderSource.cloud => 'storefront',
      OrderSource.desktopPos => 'counter',
      OrderSource.manual => 'manager',
      OrderSource.localLan => 'waiter',
    };

int orderMins(OrderModel o) {
  final m = DateTime.now().difference(o.createdAt).inMinutes;
  return m < 0 ? 0 : m;
}

String orderTypeLabel(OrderModel o, bool isBn) {
  switch (o.serviceType) {
    case OrderServiceType.delivery:
      return isBn ? 'ডেলিভারি' : 'Delivery';
    case OrderServiceType.takeaway:
      return isBn ? 'পার্সেল' : 'Parcel';
    case OrderServiceType.dineIn:
    case null:
      return o.tableNo != null && o.tableNo!.isNotEmpty
          ? (isBn ? 'টেবিল ${o.tableNo}' : 'Table ${o.tableNo}')
          : (isBn ? 'ডাইন-ইন' : 'Dine-in');
  }
}

String orderItemName(OrderItem it, AppLanguage lang) {
  final v = lang == AppLanguage.bn ? it.nameBn : it.nameEn;
  return v.trim().isNotEmpty ? v.trim() : it.name;
}

class DeskOrdersScreen extends StatefulWidget {
  const DeskOrdersScreen({super.key});

  @override
  State<DeskOrdersScreen> createState() => _DeskOrdersScreenState();
}

class _DeskOrdersScreenState extends State<DeskOrdersScreen> {
  String _seg = 'ongoing';
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _isBn => AppScope.of(context).language == AppLanguage.bn;
  String _t(String en, String bn) => _isBn ? bn : en;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final desk = DeskScope.of(context);
    final all = app.orders.where((o) => o.status.adminStatus != OrderStatus.rejected).toList();
    final q = _query.trim().toLowerCase();
    final list = all.where((o) {
      final st = o.status.adminStatus;
      final inSeg = _seg == 'ongoing' ? (st == OrderStatus.pending || st == OrderStatus.accepted) : st == OrderStatus.completed;
      if (!inSeg) return false;
      if (q.isEmpty) return true;
      return '${o.sequenceNo}'.contains(q) ||
          (o.customerName ?? '').toLowerCase().contains(q) ||
          orderTypeLabel(o, false).toLowerCase().contains(q);
    }).toList();

    final pend = all.where((o) => o.status.adminStatus == OrderStatus.pending).length;
    final ong = all.where((o) {
      final st = o.status.adminStatus;
      return st == OrderStatus.pending || st == OrderStatus.accepted;
    }).length;
    final comp = all.where((o) => o.status.adminStatus == OrderStatus.completed).length;

    OrderModel? sel;
    if (desk.selOrderId != null) {
      for (final o in all) {
        if (o.id == desk.selOrderId) {
          sel = o;
          break;
        }
      }
    }
    sel ??= list.isNotEmpty ? list.first : null;

    return Container(
      color: Dk.bg,
      child: Column(
        children: [
          _header(app, desk, pend, ong),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _listColumn(app, desk, list, sel, ong, comp),
                Expanded(
                  child: Container(
                    color: Dk.bg,
                    child: sel == null
                        ? Center(child: Text(_t('Select an order', 'একটি অর্ডার নির্বাচন করুন'), style: dkText(14, color: Dk.muted)))
                        : _OrderDetail(key: ValueKey(sel.id), order: sel, isBn: _isBn),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(PosAppController app, DeskController desk, int pend, int ong) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(color: Dk.surface, border: Border(bottom: BorderSide(color: Dk.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('Orders', 'অর্ডার'), style: dkText(22, weight: FontWeight.w700, letterSpacing: -0.4)),
                Text(_t('$pend to accept · $ong ongoing', '$pend অপেক্ষমাণ · $ong চলমান'),
                    style: dkText(13, weight: FontWeight.w500, color: Dk.muted)),
              ],
            ),
          ),
          DkButton(
            label: _t('New order', 'নতুন অর্ডার'),
            icon: 'plus',
            variant: DkBtnVariant.primary,
            onTap: () => desk.setTab(DeskTab.register),
          ),
        ],
      ),
    );
  }

  Widget _listColumn(PosAppController app, DeskController desk, List<OrderModel> list, OrderModel? sel, int ong, int comp) {
    return Container(
      width: 420,
      decoration: const BoxDecoration(color: Dk.surface, border: Border(right: BorderSide(color: Dk.line))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Dk.line))),
            child: Column(
              children: [
                DkField(
                  controller: _search,
                  placeholder: _t('Search orders…', 'অর্ডার খুঁজুন…'),
                  showClear: true,
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: 11),
                DkSeg(
                  selected: _seg,
                  onSelect: (id) => setState(() => _seg = id),
                  items: [
                    DkSegItem('ongoing', '${_t('Ongoing', 'চলমান')}  $ong'),
                    DkSegItem('completed', '${_t('Completed', 'সম্পন্ন')}  $comp'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text(_t('No orders here.', 'কোনো অর্ডার নেই'), style: dkText(14, color: Dk.muted)))
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: list.length,
                    itemBuilder: (_, i) => _OrderRow(
                      order: list[i],
                      isBn: _isBn,
                      selected: sel != null && sel.id == list[i].id,
                      onTap: () => desk.setSelOrder(list[i].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _OrderRow extends StatefulWidget {
  const _OrderRow({required this.order, required this.isBn, required this.selected, required this.onTap});
  final OrderModel order;
  final bool isBn;
  final bool selected;
  final VoidCallback onTap;
  @override
  State<_OrderRow> createState() => _OrderRowState();
}

class _OrderRowState extends State<_OrderRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final pending = o.status.adminStatus == OrderStatus.pending;
    final ch = dkChannel(dkChannelKey(o.source));
    final items = o.items.fold<int>(0, (s, it) => s + it.qty);
    final bg = widget.selected ? Dk.accentTint : (_hover ? Dk.surface2 : Dk.surface);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              bottom: const BorderSide(color: Dk.line),
              left: pending ? const BorderSide(color: Dk.accent, width: 3) : BorderSide.none,
            ),
          ),
          padding: EdgeInsets.fromLTRB(pending ? 15 : 18, 14, 18, 14),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Text('${o.sequenceNo}', textAlign: TextAlign.center, style: dkNum(20, weight: FontWeight.w800, letterSpacing: -0.4)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(orderTypeLabel(o, widget.isBn), style: dkText(14.5, weight: FontWeight.w700)),
                        if (pending) ...[
                          const SizedBox(width: 7),
                          DkBadge(label: widget.isBn ? 'নতুন' : 'New', variant: DkBadgeVariant.tint),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        DkIcon(ch.icon, size: 13, color: ch.color),
                        const SizedBox(width: 5),
                        Text('${widget.isBn ? ch.bn : ch.en} · ${orderMins(o)}m', style: dkText(12.5, color: Dk.muted)),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(dkMoney(o.total), style: dkNum(17, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('$items ${widget.isBn ? 'আইটেম' : 'items'}', style: dkText(12, color: Dk.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetail extends StatefulWidget {
  const _OrderDetail({required this.order, required this.isBn, super.key});
  final OrderModel order;
  final bool isBn;
  @override
  State<_OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<_OrderDetail> {
  bool _busy = false;
  String _t(String en, String bn) => widget.isBn ? bn : en;

  Future<void> _run(Future<void> Function() action, String toast) async {
    if (_busy) return;
    setState(() => _busy = true);
    final desk = DeskScope.read(context);
    try {
      await action();
      desk.showToast(toast);
    } catch (e) {
      desk.showToast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final app = AppScope.of(context);
    final lang = app.language;
    final ch = dkChannel(dkChannelKey(o.source));
    final st = o.status.adminStatus;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('#${o.sequenceNo}', style: dkNum(34, weight: FontWeight.w800, letterSpacing: -1)),
                            const SizedBox(width: 10),
                            Text(orderTypeLabel(o, widget.isBn), style: dkText(18, weight: FontWeight.w600, color: Dk.ink2)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            DkIcon(ch.icon, size: 15, color: ch.color),
                            const SizedBox(width: 6),
                            Text('${widget.isBn ? ch.bn : ch.en} · ${_t('placed', 'প্লেস করা হয়েছে')} ${orderMins(o)}m ${_t('ago', 'আগে')}',
                                style: dkText(13.5, color: Dk.muted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _statusBadge(st),
                ],
              ),
              if ((o.customerName ?? '').isNotEmpty || (o.mobileNumber ?? '').isNotEmpty || (o.deliveryAddress ?? '').isNotEmpty) ...[
                const SizedBox(height: 18),
                DkCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ((o.customerName ?? '').isNotEmpty) _infoCol(_t('Customer', 'কাস্টমার'), o.customerName!),
                      if ((o.mobileNumber ?? '').isNotEmpty) _infoCol(_t('Phone', 'ফোন'), o.mobileNumber!, mono: true),
                      if ((o.deliveryAddress ?? '').isNotEmpty) Expanded(child: _infoCol(_t('Address', 'ঠিকানা'), o.deliveryAddress!)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DkCard(
                child: Column(
                  children: [
                    for (var i = 0; i < o.items.length; i++)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        decoration: BoxDecoration(border: i < o.items.length - 1 ? const Border(bottom: BorderSide(color: Dk.line)) : null),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(width: 26, child: Text('${o.items[i].qty}×', style: dkNum(15, weight: FontWeight.w700, color: Dk.ink2))),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(orderItemName(o.items[i], lang), style: dkText(14.5, weight: FontWeight.w600)),
                                  if ((o.items[i].note ?? '').trim().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(o.items[i].note!.trim(), style: dkText(12.5, color: Dk.muted)),
                                    ),
                                ],
                              ),
                            ),
                            Text(dkMoney(o.items[i].lineTotal), style: dkNum(17, weight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DkCard(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                child: Column(
                  children: [
                    _sumRow(_t('Subtotal', 'সাবটোটাল'), dkMoney(o.subtotal)),
                    if (o.discountAmount > 0) _sumRow(_t('Discount', 'ছাড়'), '−${dkMoney(o.discountAmount)}', color: Dk.accentStrong),
                    _sumRow('${_t('VAT', 'ভ্যাট')} (${o.vatRatePercent.round()}%)', dkMoney(o.vatAmount)),
                    if (o.serviceChargeAmount > 0) _sumRow(_t('Service', 'সার্ভিস'), dkMoney(o.serviceChargeAmount)),
                    if (o.deliveryCharge > 0) _sumRow(_t('Delivery', 'ডেলিভারি'), dkMoney(o.deliveryCharge)),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Dk.line2))),
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_t('Total', 'মোট'), style: dkText(18, weight: FontWeight.w700)),
                            Text(dkMoney(o.total), style: dkNum(30, weight: FontWeight.w700, letterSpacing: -0.4)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _actionBar(app, o, st),
      ],
    );
  }

  Widget _actionBar(PosAppController app, OrderModel o, OrderStatus st) {
    final children = <Widget>[];
    if (st == OrderStatus.pending) {
      children.addAll([
        DkButton(
          label: _t('Reject', 'বাতিল'),
          icon: 'x',
          variant: DkBtnVariant.ghost,
          size: DkBtnSize.lg,
          dangerText: true,
          onTap: _busy ? null : () => _run(() => app.updateOrderStatus(o.id, OrderStatus.rejected), _t('Order rejected', 'অর্ডার বাতিল')),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DkButton(
            label: _t('Accept & print KOT', 'গ্রহণ করুন ও KOT প্রিন্ট'),
            icon: 'check',
            variant: DkBtnVariant.soft,
            size: DkBtnSize.lg,
            expand: true,
            onTap: _busy
                ? null
                : () => _run(() async {
                      await app.updateOrderStatus(o.id, OrderStatus.accepted);
                      await app.printOrderTicket(o);
                    }, _t('Accepted · KOT printed', 'গ্রহণ করা হয়েছে · KOT প্রিন্ট')),
          ),
        ),
      ]);
    } else if (st == OrderStatus.accepted) {
      children.addAll([
        Expanded(
          child: DkButton(
            label: _t('Print KOT', 'KOT প্রিন্ট'),
            icon: 'printer',
            variant: DkBtnVariant.ghost,
            size: DkBtnSize.lg,
            expand: true,
            onTap: _busy ? null : () => _run(() async { await app.printOrderTicket(o); }, _t('Printing KOT', 'KOT প্রিন্ট হচ্ছে')),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DkButton(
            label: _t('Print bill & complete', 'বিল প্রিন্ট ও সম্পন্ন'),
            icon: 'taka',
            variant: DkBtnVariant.primary,
            size: DkBtnSize.lg,
            expand: true,
            onTap: _busy
                ? null
                : () => _run(() async {
                      await app.updateOrderStatus(o.id, OrderStatus.completed);
                      await app.printCustomerInvoice(o);
                    }, _t('Bill printed · completed', 'বিল প্রিন্ট · সম্পন্ন')),
          ),
        ),
      ]);
    } else {
      children.add(
        Expanded(
          child: DkButton(
            label: _t('Reprint receipt', 'রসিদ রিপ্রিন্ট'),
            icon: 'printer',
            variant: DkBtnVariant.ghost,
            size: DkBtnSize.lg,
            expand: true,
            onTap: _busy ? null : () => _run(() async { await app.printCustomerInvoice(o); }, _t('Reprinting receipt', 'রসিদ রিপ্রিন্ট')),
          ),
        ),
      );
    }
    return Container(
      decoration: const BoxDecoration(color: Dk.surface, border: Border(top: BorderSide(color: Dk.line))),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(children: children),
    );
  }

  Widget _statusBadge(OrderStatus st) {
    if (st == OrderStatus.pending) {
      return DkBadge(label: _t('Awaiting accept', 'গ্রহণের অপেক্ষায়'), variant: DkBadgeVariant.tint, height: 26);
    }
    if (st == OrderStatus.accepted) {
      return DkBadge(label: _t('Ongoing', 'চলমান'), variant: DkBadgeVariant.info, height: 26);
    }
    return DkBadge(label: _t('Completed', 'সম্পন্ন'), variant: DkBadgeVariant.success, height: 26);
  }

  Widget _infoCol(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          dkEyebrow(label),
          const SizedBox(height: 3),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono ? dkNum(14.5, weight: FontWeight.w600) : dkText(14.5, weight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sumRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: dkText(14, color: color ?? Dk.ink2)),
          Text(value, style: dkNum(14, weight: FontWeight.w600, color: color ?? Dk.ink)),
        ],
      ),
    );
  }
}
