import 'dart:async';

import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/desktop_pos.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_service_type.dart';
import 'package:local_pos/src/models/order_source.dart';
import 'package:local_pos/src/models/order_status.dart';

import '../shell/desk_nav.dart';
import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
import 'table_order_sheet.dart';

/// Front-of-house floor view (petpooja15): zoned table grid with vacant /
/// occupied state, plus an online-orders strip to accept/reject.
class TablesScreen extends StatefulWidget {
  const TablesScreen({super.key});

  @override
  State<TablesScreen> createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> {
  DesktopPosSettings? _settings;
  PosShift? _shift;
  bool _loading = true;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    // Live elapsed timers on occupied tiles.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    final settings = await app.loadDesktopPosSettings();
    final shift = await app.currentDesktopShift();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _shift = shift?.isOpen == true ? shift : null;
      _loading = false;
    });
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: PosColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  void _toast(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: PosColors.secondary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final app = AppScope.of(context);
    final orders = app.orders;
    final open = orders
        .where((o) => o.status.adminStatus.isOpen)
        .toList(growable: false);
    final online = orders
        .where((o) =>
            o.status.adminStatus == OrderStatus.pending &&
            (o.source == OrderSource.facebookMessenger ||
                o.source == OrderSource.cloud))
        .toList(growable: false);
    final occupied = <String, OrderModel>{};
    for (final o in open) {
      if (o.serviceType == OrderServiceType.dineIn) {
        final key = (o.tableNo ?? '').trim();
        if (key.isNotEmpty) occupied[key] = o;
      }
    }
    final zones = _settings?.floorLayout ?? const <PosFloorZone>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (online.isNotEmpty) _onlineStrip(online),
        Expanded(
          child: zones.isEmpty
              ? _emptyFloor()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _legend(),
                    const SizedBox(height: 8),
                    for (final zone in zones) _zone(zone, occupied),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _emptyFloor() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded,
                size: 34, color: PosColors.muted),
            const SizedBox(height: 10),
            Text('No tables configured',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PosColors.primaryDark)),
            const SizedBox(height: 4),
            Text('Counter outlet — sell from the Billing screen.',
                style: TextStyle(fontSize: 12.5, color: PosColors.muted)),
          ],
        ),
      );

  Widget _legend() {
    return Row(
      children: [
        _legendDot(PosColors.surface, 'Vacant', border: true),
        const SizedBox(width: 16),
        _legendDot(PosColors.stateOccupied, 'Occupied'),
      ],
    );
  }

  Widget _legendDot(Color color, String label, {bool border = false}) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: border ? Border.all(color: PosColors.lineStrong) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: PosColors.ink2)),
      ],
    );
  }

  Widget _zone(PosFloorZone zone, Map<String, OrderModel> occupied) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 12, 0, 8),
          child: Text(zone.name,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final table in zone.tables)
              _TableTile(
                label: table.label,
                order: occupied[table.label.trim()],
                onTap: () => _tapTable(table.label, occupied[table.label.trim()]),
              ),
          ],
        ),
      ],
    );
  }

  void _tapTable(String label, OrderModel? order) {
    if (order == null) {
      DeskNav.of(context).startOrder(BillingSeed(tableLabel: label));
    } else {
      showTableOrderSheet(context, order: order, shift: _shift)
          .then((message) => _toast(message ?? ''));
    }
  }

  Widget _onlineStrip(List<OrderModel> online) {
    return Container(
      height: 132,
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Text('Online orders · ${online.length}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              itemCount: online.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _onlineCard(online[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _onlineCard(OrderModel order) {
    final app = AppScope.read(context);
    final itemCount = order.items.fold<int>(0, (s, it) => s + it.qty);
    return Container(
      width: 240,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.pendingBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public_rounded, size: 15, color: PosColors.ink2),
              const SizedBox(width: 6),
              Text(order.displaySequence,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              Text(money(context, order.total),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PosColors.primary)),
            ],
          ),
          const SizedBox(height: 2),
          Text('$itemCount item${itemCount == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 12, color: PosColors.muted)),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PosColors.danger,
                    side: const BorderSide(color: PosColors.lineStrong),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: () => _act(() async {
                    await app.updateOrderStatus(
                        order.id, OrderStatus.rejected);
                  }),
                  child: const Text('Reject', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: PosColors.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 34),
                  ),
                  onPressed: () => _act(() async {
                    await app.updateOrderStatus(
                        order.id, OrderStatus.accepted);
                    _toast('Accepted ${order.displaySequence}');
                  }),
                  child: const Text('Accept',
                      style: TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableTile extends StatelessWidget {
  const _TableTile({
    required this.label,
    required this.order,
    required this.onTap,
  });

  final String label;
  final OrderModel? order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final occupied = order != null;
    final elapsed = occupied
        ? DateTime.now().difference(order!.createdAt).inMinutes
        : 0;
    return InkWell(
      borderRadius: BorderRadius.circular(PosRadii.md),
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: occupied ? PosColors.stateOccupied : PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.md),
          border: Border.all(
            color: occupied ? PosColors.stateOccupiedLine : PosColors.lineStrong,
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (occupied)
              Text('⏱ ${elapsed}m',
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: PosColors.stateOccupiedInk)),
            Expanded(
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: occupied
                        ? PosColors.stateOccupiedInk
                        : PosColors.primaryDark,
                  ),
                ),
              ),
            ),
            if (occupied)
              Text(money(context, order!.total),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PosColors.stateOccupiedInk)),
          ],
        ),
      ),
    );
  }
}
