// QuickBytes Desktop — Tables (floor). Faithful to `desktop-floor.jsx`
// TablesScreen: a 4-column grid; occupied tables wear the calm slate wash
// (never lime), vacant tables are plain white and start a dine-in order.

import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/desktop_pos.dart';
import '../../../models/order_model.dart';
import '../../../models/order_service_type.dart';
import '../../../models/order_status.dart';
import '../desk_controller.dart';
import '../widgets/dk_icons.dart';
import '../widgets/dk_kit.dart';
import 'orders_screen.dart' show orderMins;

class DeskTablesScreen extends StatelessWidget {
  const DeskTablesScreen({required this.settings, super.key});

  final DesktopPosSettings settings;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final desk = DeskScope.of(context);
    final isBn = app.language == AppLanguage.bn;
    String t(String en, String bn) => isBn ? bn : en;

    final tables = [for (final z in settings.floorLayout) ...z.tables];
    final occupied = <String, OrderModel>{};
    for (final o in app.orders) {
      if (o.serviceType == OrderServiceType.dineIn && o.status.isOpen && (o.tableNo ?? '').isNotEmpty) {
        occupied[o.tableNo!] = o;
      }
    }
    final occCount = occupied.length;
    final free = tables.length - occCount;

    return Container(
      color: Dk.bg,
      child: Column(
        children: [
          Container(
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
                      Text(t('Tables', 'টেবিল'), style: dkText(22, weight: FontWeight.w700, letterSpacing: -0.4)),
                      Text(t('$occCount seated · $free free', '$occCount টেবিল চলছে · $free খালি'),
                          style: dkText(13, weight: FontWeight.w500, color: Dk.muted)),
                    ],
                  ),
                ),
                DkButton(label: t('New parcel', 'নতুন পার্সেল'), icon: 'bag', variant: DkBtnVariant.ghost, onTap: () => desk.startType(OrderServiceType.takeaway)),
                const SizedBox(width: 8),
                DkButton(label: t('New delivery', 'নতুন ডেলিভারি'), icon: 'truck', variant: DkBtnVariant.ghost, onTap: () => desk.startType(OrderServiceType.delivery)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                Row(
                  children: [
                    _legend(Dk.seatTint, Dk.seatLine, '${t('Occupied', 'চলছে')} $occCount'),
                    const SizedBox(width: 16),
                    _legend(Dk.surface, Dk.line2, '${t('Free', 'খালি')} $free'),
                  ],
                ),
                const SizedBox(height: 18),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: tables.length,
                  itemBuilder: (_, i) {
                    final tb = tables[i];
                    final o = occupied[tb.label];
                    return o != null
                        ? _OccupiedTile(label: tb.label, order: o, isBn: isBn, onTap: () => desk.openOrder(o.id))
                        : _VacantTile(label: tb.label, seats: tb.seats, isBn: isBn, onTap: () => desk.startDineIn(tb.label));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color bg, Color border, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3), border: Border.all(color: border)),
        ),
        const SizedBox(width: 8),
        Text(label, style: dkText(13.5, weight: FontWeight.w600, color: Dk.ink2)),
      ],
    );
  }
}

class _OccupiedTile extends StatelessWidget {
  const _OccupiedTile({required this.label, required this.order, required this.isBn, required this.onTap});
  final String label;
  final OrderModel order;
  final bool isBn;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final items = order.items.fold<int>(0, (s, it) => s + it.qty);
    final pending = order.status.adminStatus == OrderStatus.pending;
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Dk.seatTint,
            borderRadius: BorderRadius.circular(Dk.rLg),
            border: Border.all(color: Dk.seatLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: dkText(24, weight: FontWeight.w800, color: Dk.seatInk)),
                  const Spacer(),
                  const DkIcon('clock', size: 13, color: Dk.seatInk),
                  const SizedBox(width: 4),
                  Text('${orderMins(order)}m', style: dkText(12, weight: FontWeight.w700, color: Dk.seatInk)),
                ],
              ),
              const Spacer(),
              Text('$items ${isBn ? 'আইটেম' : 'items'}', style: dkText(12, weight: FontWeight.w600, color: Dk.seatInk)),
              Text(dkMoney(order.total), style: dkNum(18, weight: FontWeight.w800, color: Dk.ink)),
              const SizedBox(height: 8),
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: Dk.seatLine, borderRadius: BorderRadius.circular(Dk.rXs)),
                alignment: Alignment.center,
                child: Text(pending ? (isBn ? 'নতুন' : 'New') : (isBn ? 'চলছে' : 'Running'),
                    style: dkText(12, weight: FontWeight.w600, color: Dk.seatInk)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VacantTile extends StatefulWidget {
  const _VacantTile({required this.label, required this.seats, required this.isBn, required this.onTap});
  final String label;
  final int seats;
  final bool isBn;
  final VoidCallback onTap;
  @override
  State<_VacantTile> createState() => _VacantTileState();
}

class _VacantTileState extends State<_VacantTile> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Dk.surface,
            borderRadius: BorderRadius.circular(Dk.rLg),
            border: Border.all(color: _hover ? Dk.line2 : Dk.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.label, style: dkText(24, weight: FontWeight.w800)),
                  const Spacer(),
                  const DkIcon('user', size: 13, color: Dk.muted),
                  const SizedBox(width: 4),
                  Text('${widget.seats}', style: dkText(12, color: Dk.muted)),
                ],
              ),
              const Spacer(),
              Text(widget.isBn ? 'খালি' : 'Free', style: dkText(13.5, weight: FontWeight.w600, color: Dk.muted)),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const DkIcon('plus', size: 14, color: Dk.accentStrong, strokeWidth: 2.2),
                  const SizedBox(width: 5),
                  Text(widget.isBn ? 'অর্ডার শুরু' : 'Start order', style: dkText(12.5, weight: FontWeight.w700, color: Dk.accentStrong)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
