import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/models/desktop_pos.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_service_type.dart';
import 'package:local_pos/src/models/order_status.dart';

import '../billing/settle_flow.dart';
import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';

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
  final _searchCtl = TextEditingController();

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
    _searchCtl.dispose();
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

  String _serviceLabel(OrderServiceType? st) {
    switch (st) {
      case OrderServiceType.dineIn:
        return 'Dine In';
      case OrderServiceType.takeaway:
        return 'Pick Up';
      case OrderServiceType.delivery:
        return 'Delivery';
      case null:
        return 'Order';
    }
  }

  Color _serviceColor(OrderServiceType? st) {
    switch (st) {
      case OrderServiceType.dineIn:
        return PosColors.warning;
      case OrderServiceType.takeaway:
        return PosColors.channelMessenger;
      case OrderServiceType.delivery:
        return PosColors.success;
      case null:
        return PosColors.ink2;
    }
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
        _tabStrip(ongoing.length, completed.length),
        _searchAndLegend(),
        Expanded(
          child: _tabs.index == 0
              ? _orderView(ongoing)
              : _completedView(completed),
        ),
      ],
    );
  }

  Widget _tabStrip(int ongoingCount, int completedCount) {
    final active = _tabs.index;
    return Container(
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      child: Row(
        children: [
          _pillTab('Ongoing', ongoingCount, active == 0, () => _tabs.animateTo(0)),
          const SizedBox(width: 12),
          _pillTab('Completed', completedCount, active == 1, () => _tabs.animateTo(1)),
        ],
      ),
    );
  }

  Widget _pillTab(String label, int count, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? PosColors.primary : PosColors.surfaceSunk,
          borderRadius: BorderRadius.circular(PosRadii.pill),
          border: active
              ? null
              : Border.all(color: PosColors.lineStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                  fontSize: DeskTypography.tab,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : PosColors.ink2,
                )),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.25)
                    : PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadii.pill),
              ),
              child: Text('$count',
                  style: TextStyle(
                    fontSize: DeskTypography.caption,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : PosColors.ink2,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchAndLegend() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 240,
            height: 42,
            child: TextField(
              controller: _searchCtl,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: PosColors.muted),
                hintText: 'Search orders',
                filled: true,
                fillColor: PosColors.surfaceSunk,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosRadii.sm),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Spacer(),
          _statusDot(PosColors.success, 'Delivery'),
          const SizedBox(width: 20),
          _statusDot(PosColors.warning, 'Dine In'),
          const SizedBox(width: 20),
          _statusDot(PosColors.channelMessenger, 'Pick Up'),
        ],
      ),
    );
  }

  Widget _statusDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 13,
          height: 13,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: DeskTypography.bodySmall, color: PosColors.ink2)),
      ],
    );
  }

  List<OrderModel> _filter(List<OrderModel> orders) {
    final q = _searchCtl.text.trim().toLowerCase();
    if (q.isEmpty) return orders;
    return orders.where((o) {
      return o.displaySequence.toLowerCase().contains(q) ||
          (o.tableNo ?? '').toLowerCase().contains(q) ||
          o.items.any((it) => it.name.toLowerCase().contains(q));
    }).toList();
  }

  Widget _orderView(List<OrderModel> orders) {
    final filtered = _filter(orders);
    if (filtered.isEmpty) {
      return Center(
        child: Text('No ongoing orders',
            style: TextStyle(
                fontSize: DeskTypography.title, color: PosColors.muted)),
      );
    }
    final lang = AppScope.of(context).language;
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _OrderRowCard(
        order: filtered[i],
        lang: lang,
        canBill: _shift != null,
        serviceLabel: _serviceLabel(filtered[i].serviceType),
        serviceColor: _serviceColor(filtered[i].serviceType),
        onAccept: () => _act(() async {
          final app = AppScope.read(context);
          await app.updateOrderStatus(
              filtered[i].id, OrderStatus.accepted);
        }),
        onReject: () => _act(() async {
          final app = AppScope.read(context);
          await app.updateOrderStatus(
              filtered[i].id, OrderStatus.rejected);
        }),
        onKot: () => _act(() async {
          final app = AppScope.read(context);
          final updated = await app.sendDesktopKot(filtered[i]);
          try {
            await app.printOrderTicket(updated);
          } catch (_) {}
          _toast('KOT sent ${filtered[i].displaySequence}');
        }),
        onBill: () => _bill(filtered[i]),
      ),
    );
  }

  Widget _completedView(List<OrderModel> orders) {
    final filtered = _filter(orders);
    if (filtered.isEmpty) {
      return Center(
        child: Text('No completed orders',
            style: TextStyle(
                fontSize: DeskTypography.title, color: PosColors.muted)),
      );
    }
    final lang = AppScope.of(context).language;
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (_, i) => _CompletedOrderCard(
        order: filtered[i],
        lang: lang,
        serviceLabel: _serviceLabel(filtered[i].serviceType),
        serviceColor: _serviceColor(filtered[i].serviceType),
        onReprint: () => _act(() async {
          final app = AppScope.read(context);
          try {
            await app.printOrderTicket(filtered[i]);
            _toast('Reprinting ${filtered[i].displaySequence}');
          } catch (e) {
            _toast('Print failed', error: true);
          }
        }),
      ),
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

class _OrderRowCard extends StatelessWidget {
  const _OrderRowCard({
    required this.order,
    required this.lang,
    required this.canBill,
    required this.serviceLabel,
    required this.serviceColor,
    required this.onAccept,
    required this.onReject,
    required this.onKot,
    required this.onBill,
  });

  final OrderModel order;
  final AppLanguage lang;
  final bool canBill;
  final String serviceLabel;
  final Color serviceColor;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onKot;
  final VoidCallback onBill;

  @override
  Widget build(BuildContext context) {
    final pending = order.status.adminStatus == OrderStatus.pending;
    final itemCount = order.items.fold<int>(0, (s, it) => s + it.qty);
    final time = order.createdAt;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(DeskMetrics.tileRadius),
        border: Border.all(
            color: pending ? PosColors.pendingBorder : PosColors.line),
        boxShadow: PosShadows.soft,
      ),
      child: Row(
        children: [
          Text(order.displaySequence,
              style: const TextStyle(
                  fontSize: DeskTypography.orderSerial,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(PosRadii.pill),
            ),
            child: Text(serviceLabel,
                style: TextStyle(
                    fontSize: DeskTypography.label,
                    fontWeight: FontWeight.w700,
                    color: serviceColor)),
          ),
          const SizedBox(width: 14),
          if (order.tableNo != null && order.tableNo!.isNotEmpty) ...[
            const Icon(Icons.table_restaurant_rounded,
                size: 16, color: PosColors.muted),
            const SizedBox(width: 4),
            Text('Table ${order.tableNo}',
                style: TextStyle(
                    fontSize: DeskTypography.bodySmall,
                    color: PosColors.ink2)),
            const SizedBox(width: 14),
          ],
          Text('$itemCount item${itemCount == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: DeskTypography.bodySmall,
                  color: PosColors.ink2)),
          const SizedBox(width: 14),
          Icon(Icons.access_time_rounded, size: 15, color: PosColors.muted),
          const SizedBox(width: 4),
          Text(timeStr,
              style: TextStyle(
                  fontSize: DeskTypography.bodySmall,
                  color: PosColors.muted)),
          const Spacer(),
          Text(money(context, order.total),
              style: const TextStyle(
                  fontSize: DeskTypography.moneyRow,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 16),
          if (pending) ...[
            SizedBox(
              height: 36,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: PosColors.danger,
                  side: const BorderSide(color: PosColors.lineStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PosRadii.sm)),
                ),
                onPressed: onReject,
                child: const Text('Reject',
                    style: TextStyle(
                        fontSize: DeskTypography.button,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PosColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PosRadii.sm)),
                ),
                onPressed: onAccept,
                child: const Text('Accept',
                    style: TextStyle(
                        fontSize: DeskTypography.button,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ] else ...[
            SizedBox(
              height: 36,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: PosColors.ink2,
                  side: const BorderSide(color: PosColors.lineStrong),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PosRadii.sm)),
                ),
                onPressed: onKot,
                child: const Text('KOT',
                    style: TextStyle(
                        fontSize: DeskTypography.button,
                        fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 36,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: PosColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(PosRadii.sm)),
                ),
                onPressed: canBill ? onBill : null,
                child: const Text('Bill',
                    style: TextStyle(
                        fontSize: DeskTypography.button,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Clean horizontal card for completed orders (web target2 style):
/// order# · service badge · table · item count · settled time · total · Reprint.
class _CompletedOrderCard extends StatelessWidget {
  const _CompletedOrderCard({
    required this.order,
    required this.lang,
    required this.serviceLabel,
    required this.serviceColor,
    required this.onReprint,
  });

  final OrderModel order;
  final AppLanguage lang;
  final String serviceLabel;
  final Color serviceColor;
  final VoidCallback onReprint;

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.fold<int>(0, (s, it) => s + it.qty);
    final time = order.createdAt;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(DeskMetrics.tileRadius),
        border: Border.all(color: PosColors.line),
        boxShadow: PosShadows.soft,
      ),
      child: Row(
        children: [
          Text(order.displaySequence,
              style: const TextStyle(
                  fontSize: DeskTypography.orderSerial,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 14),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(PosRadii.pill),
            ),
            child: Text(serviceLabel,
                style: TextStyle(
                    fontSize: DeskTypography.label,
                    fontWeight: FontWeight.w700,
                    color: serviceColor)),
          ),
          const SizedBox(width: 14),
          if (order.tableNo != null && order.tableNo!.isNotEmpty) ...[
            const Icon(Icons.table_restaurant_rounded,
                size: 16, color: PosColors.muted),
            const SizedBox(width: 4),
            Text('Table ${order.tableNo}',
                style: TextStyle(
                    fontSize: DeskTypography.bodySmall,
                    color: PosColors.ink2)),
            const SizedBox(width: 14),
          ],
          Text('$itemCount item${itemCount == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: DeskTypography.bodySmall,
                  color: PosColors.ink2)),
          const SizedBox(width: 14),
          Text('Settled $timeStr',
              style: TextStyle(
                  fontSize: DeskTypography.bodySmall,
                  color: PosColors.muted)),
          const Spacer(),
          Text(money(context, order.total),
              style: const TextStyle(
                  fontSize: DeskTypography.moneyRow,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 16),
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: PosColors.primary,
                side: const BorderSide(color: PosColors.primary, width: 1.5),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PosRadii.sm)),
              ),
              onPressed: onReprint,
              icon: const Icon(Icons.print_rounded, size: 16),
              label: const Text('Reprint',
                  style: TextStyle(
                      fontSize: DeskTypography.button,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
