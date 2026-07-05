import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/models/desktop_pos.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_service_type.dart';
import 'package:local_pos/src/models/order_status.dart';

import '../billing/settle_flow.dart';
import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';

/// Orders list — Ongoing (pending + accepted) and Completed tabs, with the
/// pending→accepted→completed lifecycle actions (accept / reject / KOT / bill).
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  PosShift? _shift;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _loadShift();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadShift() async {
    final app = AppScope.read(context);
    final shift = await app.currentDesktopShift();
    if (mounted) setState(() => _shift = shift?.isOpen == true ? shift : null);
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? PosColors.danger : PosColors.secondary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ongoing = app.orders.where((o) => o.status.adminStatus.isOpen).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final completed =
        app.orders.where((o) => o.status.adminStatus.isCompleted).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(ongoing.length, completed.length),
        Expanded(
          child: _tabs.index == 0
              ? _list(ongoing, ongoing: true)
              : _list(completed, ongoing: false),
        ),
      ],
    );
  }

  Widget _header(int ongoingCount, int completedCount) {
    return Container(
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Orders',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: PosColors.primary,
            unselectedLabelColor: PosColors.muted,
            indicatorColor: PosColors.primary,
            indicatorWeight: 2.5,
            labelStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            tabs: [
              Tab(text: 'Ongoing ($ongoingCount)'),
              Tab(text: 'Completed ($completedCount)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _list(List<OrderModel> orders, {required bool ongoing}) {
    if (orders.isEmpty) {
      return Center(
        child: Text(ongoing ? 'No ongoing orders' : 'No completed orders',
            style: TextStyle(color: PosColors.muted)),
      );
    }
    final lang = AppScope.of(context).language;
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (_, i) => ongoing
          ? _OngoingCard(
              order: orders[i],
              lang: lang,
              canBill: _shift != null,
              onAccept: () => _act(() async {
                final app = AppScope.read(context);
                await app.updateOrderStatus(
                    orders[i].id, OrderStatus.accepted);
              }),
              onReject: () => _act(() async {
                final app = AppScope.read(context);
                await app.updateOrderStatus(
                    orders[i].id, OrderStatus.rejected);
              }),
              onKot: () => _act(() async {
                final app = AppScope.read(context);
                final updated = await app.sendDesktopKot(orders[i]);
                try {
                  await app.printOrderTicket(updated);
                } catch (_) {}
                _toast('KOT sent ${orders[i].displaySequence}');
              }),
              onBill: () => _bill(orders[i]),
            )
          : _CompletedCard(order: orders[i], lang: lang),
    );
  }

  Future<void> _bill(OrderModel order) async {
    final shift = _shift;
    if (shift == null) {
      _toast('Open the register to settle', error: true);
      return;
    }
    final app = AppScope.read(context);
    final message =
        await runSettlement(context, app, order: order, shift: shift);
    if (message != null) _toast(message);
  }
}

// ─────────────────────────── cards ───────────────────────────

String _itemsSummary(OrderModel order, AppLanguage lang) {
  final count = order.items.fold<int>(0, (s, it) => s + it.qty);
  final names = order.items.take(2).map((it) => it.localizedName(lang)).toList();
  final extra = order.items.length > 2 ? ' +${order.items.length - 2}' : '';
  return '$count item${count == 1 ? '' : 's'} · ${names.join(', ')}$extra';
}

String _typeLabel(OrderModel order) {
  switch (order.serviceType) {
    case OrderServiceType.dineIn:
      return (order.tableNo ?? '').isEmpty
          ? 'Dine-in'
          : 'Table ${order.tableNo}';
    case OrderServiceType.takeaway:
      return 'Parcel';
    case OrderServiceType.delivery:
      return 'Delivery';
    case null:
      return 'Order';
  }
}

class _OngoingCard extends StatelessWidget {
  const _OngoingCard({
    required this.order,
    required this.lang,
    required this.canBill,
    required this.onAccept,
    required this.onReject,
    required this.onKot,
    required this.onBill,
  });

  final OrderModel order;
  final AppLanguage lang;
  final bool canBill;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onKot;
  final VoidCallback onBill;

  @override
  Widget build(BuildContext context) {
    final pending = order.status.adminStatus == OrderStatus.pending;
    final age = DateTime.now().difference(order.createdAt).inMinutes;
    final kotSent = order.items.any((it) => it.kotSentAt != null);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(
            color: pending ? PosColors.pendingBorder : PosColors.line),
        boxShadow: PosShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(order.displaySequence,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Text(_typeLabel(order),
                  style: TextStyle(fontSize: 13, color: PosColors.ink2)),
              const Spacer(),
              Text(money(context, order.total),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text('${age}m ago',
                  style: TextStyle(fontSize: 11.5, color: PosColors.muted)),
              if (kotSent) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded,
                    size: 13, color: PosColors.success),
                const SizedBox(width: 2),
                Text('KOT',
                    style: TextStyle(
                        fontSize: 11, color: PosColors.statePrintedInk)),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(_itemsSummary(order, lang),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: pending
                ? [
                    _btn('Reject', onReject, danger: true),
                    const SizedBox(width: 8),
                    _btn('Accept', onAccept, primary: true),
                  ]
                : [
                    _btn('KOT', onKot),
                    const SizedBox(width: 8),
                    _btn('Bill', canBill ? onBill : null, primary: true),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback? onTap,
      {bool primary = false, bool danger = false}) {
    if (primary) {
      return SizedBox(
        height: 36,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: PosColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 20),
          ),
          onPressed: onTap,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      );
    }
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: danger ? PosColors.danger : PosColors.primaryDark,
          side: const BorderSide(color: PosColors.lineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({required this.order, required this.lang});
  final OrderModel order;
  final AppLanguage lang;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('h:mm a').format(order.createdAt.toLocal());
    final payment = order.paymentMethod?.label ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
        boxShadow: PosShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(order.displaySequence,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: PosColors.successSoft,
                  borderRadius: BorderRadius.circular(PosRadii.pill),
                ),
                child: Text('Completed',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PosColors.statePrintedInk)),
              ),
              const Spacer(),
              Text(time,
                  style: TextStyle(fontSize: 12, color: PosColors.muted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_itemsSummary(order, lang),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_typeLabel(order),
                  style: TextStyle(fontSize: 12, color: PosColors.muted)),
              if (payment.isNotEmpty) ...[
                Text('  ·  ',
                    style: TextStyle(fontSize: 12, color: PosColors.muted)),
                Text(payment,
                    style: TextStyle(fontSize: 12, color: PosColors.muted)),
              ],
              const Spacer(),
              Text(money(context, order.total),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}
