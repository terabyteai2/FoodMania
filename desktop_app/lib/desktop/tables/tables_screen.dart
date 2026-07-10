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
    final totalTables = zones.fold<int>(0, (s, z) => s + z.tables.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topBar(occupied.length, totalTables),
        _legendRow(),
        if (online.isNotEmpty) _onlineStrip(online),
        Expanded(
          child: zones.isEmpty
              ? _emptyFloor()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                  children: [
                    for (final zone in zones) _zone(zone, occupied),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _topBar(int occupied, int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          const Text('Table View',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          InkWell(
            onTap: _load,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadii.sm),
                border: Border.all(color: PosColors.line),
              ),
              child: const Icon(Icons.refresh_rounded,
                  size: 18, color: PosColors.ink2),
            ),
          ),
          const Spacer(),
          _outlinedActionButton('Delivery', Icons.local_shipping_rounded),
          const SizedBox(width: 8),
          _outlinedActionButton('Pick Up', Icons.shopping_bag_rounded),
          const SizedBox(width: 8),
          _filledActionButton('+ Add Table', Icons.add_rounded),
        ],
      ),
    );
  }

  Widget _filledActionButton(String label, IconData icon) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: PosColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm)),
      ),
      onPressed: () {},
      icon: Icon(icon, size: 16),
      label: Text(label,
          style: const TextStyle(
              fontSize: DeskTypography.button, fontWeight: FontWeight.w700)),
    );
  }

  Widget _outlinedActionButton(String label, IconData icon) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: PosColors.ink2,
        side: const BorderSide(color: PosColors.lineStrong),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm)),
      ),
      onPressed: () {},
      icon: Icon(icon, size: 16),
      label: Text(label,
          style: const TextStyle(
              fontSize: DeskTypography.button, fontWeight: FontWeight.w700)),
    );
  }

  Widget _legendRow() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          _legendDot(Colors.transparent, 'Vacant',
              border: true, borderColor: PosColors.muted),
          const SizedBox(width: 18),
          _legendDot(PosColors.primary, 'Running'),
          const SizedBox(width: 18),
          _legendDot(PosColors.warning, 'Running KOT'),
          const SizedBox(width: 18),
          _legendDot(PosColors.success, 'Paid'),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label,
      {bool border = false, Color? borderColor}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: border ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(4),
            border: border
                ? Border.all(
                    color: borderColor ?? PosColors.lineStrong,
                    width: 1,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: DeskTypography.caption,
                fontWeight: FontWeight.w600,
                color: PosColors.ink2)),
      ],
    );
  }

  Widget _emptyFloor() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storefront_rounded,
                size: 40, color: PosColors.muted),
            const SizedBox(height: 12),
            Text('No tables configured',
                style: TextStyle(
                    fontSize: DeskTypography.h3,
                    fontWeight: FontWeight.w700,
                    color: PosColors.primaryDark)),
            const SizedBox(height: 6),
            Text('Counter outlet — sell from the Billing screen.',
                style: TextStyle(
                    fontSize: DeskTypography.body, color: PosColors.muted)),
          ],
        ),
      );

  String _tableStateOf(OrderModel? order) {
    if (order == null) return 'vacant';
    if (order.settledAt != null) return 'paid';
    final hasKot = order.kotBatches.isNotEmpty ||
        order.items.any((it) => it.kotSentAt != null);
    return hasKot ? 'kot' : 'running';
  }

  Widget _zone(PosFloorZone zone, Map<String, OrderModel> occupied) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          Padding(
          padding: const EdgeInsets.fromLTRB(2, 14, 0, 8),
          child: Text(zone.name.toUpperCase(),
              style: const TextStyle(
                  fontSize: DeskTypography.body,
                  fontWeight: FontWeight.w800,
                  color: PosColors.ink2,
                  letterSpacing: 0.4)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 120,
            mainAxisExtent: DeskMetrics.tableTileHeight,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: zone.tables.length,
          itemBuilder: (_, i) {
            final table = zone.tables[i];
            final order = occupied[table.label.trim()];
            return _TableTile(
              label: table.label,
              seats: table.seats,
              order: order,
              state: _tableStateOf(order),
              onTap: () => _tapTable(table.label, order),
            );
          },
        ),
        const SizedBox(height: 8),
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
                    fontSize: DeskTypography.bodySmall,
                    fontWeight: FontWeight.w700)),
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
        borderRadius: BorderRadius.circular(DeskMetrics.tileRadius),
        border: Border.all(color: PosColors.pendingBorder),
        boxShadow: PosShadows.soft,
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
                      fontWeight: FontWeight.w800,
                      fontSize: DeskTypography.body)),
              const Spacer(),
              Text(money(context, order.total),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: PosColors.primary)),
            ],
          ),
          const SizedBox(height: 2),
          Text('$itemCount item${itemCount == 1 ? '' : 's'}',
              style: TextStyle(
                  fontSize: DeskTypography.caption, color: PosColors.muted)),
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
                  child: const Text('Reject',
                    style: TextStyle(fontSize: DeskTypography.caption)),
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
                        fontSize: DeskTypography.caption,
                        fontWeight: FontWeight.w700)),
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
    required this.seats,
    required this.order,
    required this.state,
    required this.onTap,
  });

  final String label;
  final int seats;
  final OrderModel? order;
  final String state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final elapsed = order != null
        ? DateTime.now().difference(order!.createdAt).inMinutes
        : 0;

    Color bgColor;
    Color borderColor;
    Color fgColor;
    Color subColor;
    switch (state) {
      case 'running':
        bgColor = PosColors.primarySoft;
        borderColor = PosColors.primary;
        fgColor = PosColors.primary;
        subColor = PosColors.ink2;
        break;
      case 'kot':
        bgColor = PosColors.warningSoft;
        borderColor = PosColors.warning;
        fgColor = PosColors.warning;
        subColor = PosColors.ink2;
        break;
      case 'paid':
        bgColor = PosColors.successSoft;
        borderColor = PosColors.success;
        fgColor = PosColors.success;
        subColor = PosColors.ink2;
        break;
      default:
        bgColor = Colors.transparent;
        borderColor = PosColors.muted;
        fgColor = PosColors.ink2;
        subColor = PosColors.muted;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(DeskMetrics.tableTileRadius),
      onTap: onTap,
      child: Container(
        height: DeskMetrics.tableTileHeight,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(DeskMetrics.tableTileRadius),
          border: Border.all(
            color: borderColor,
            width: state == 'vacant' ? 1 : 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: DeskTypography.tableNumber,
                fontWeight: FontWeight.w800,
                color: fgColor,
              ),
            ),
            const SizedBox(height: 3),
            if (order != null) ...[
              Text(money(context, order!.total),
                  style: TextStyle(
                      fontSize: DeskTypography.tableMeta,
                      fontWeight: FontWeight.w800,
                      color: fgColor)),
              Text(
                elapsed < 60 ? '${elapsed}m' : '${elapsed ~/ 60}h ${(elapsed % 60).toString().padLeft(2, '0')}m',
                style: TextStyle(
                    fontSize: DeskTypography.eyebrow, color: subColor),
              ),
            ] else
              Text('$seats seats',
                  style: TextStyle(
                      fontSize: DeskTypography.eyebrow, color: subColor)),
          ],
        ),
      ),
    );
  }
}
