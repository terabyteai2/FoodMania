import 'package:flutter/material.dart';

import '../../../models/desktop_pos.dart';
import '../../../models/order_model.dart';
import '../../../models/order_status.dart';
import '../widgets/pc_shell.dart';
import '../widgets/pc_theme.dart';
import '../widgets/pc_widgets.dart';

/// 2 · Dine-in floor — zones of status-coloured table cards + a live service
/// snapshot rail. Tapping a free table starts a dine-in ticket; an occupied
/// table opens its order.
class FloorScreen extends StatefulWidget {
  const FloorScreen({
    required this.chrome,
    required this.settings,
    required this.orders,
    required this.onTable,
    this.onConfigure,
    super.key,
  });

  final PcChrome chrome;
  final DesktopPosSettings settings;
  final List<OrderModel> orders;
  final void Function(String tableNo, OrderModel? order) onTable;
  final VoidCallback? onConfigure;

  @override
  State<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends State<FloorScreen> {
  PcTableState? _filter; // null = all

  String tr(String en, String bn) => widget.chrome.isBn ? bn : en;

  @override
  Widget build(BuildContext context) {
    final openByTable = <String, OrderModel>{
      for (final o in widget.orders)
        if (o.status.isOpen && o.tableNo != null) o.tableNo!: o,
    };

    final counts = <PcTableState, int>{};
    var occupied = 0;
    var coversSeated = 0;
    var dwellSum = 0;
    var lateCount = 0;
    OrderModel? lateOrder;
    for (final zone in widget.settings.floorLayout) {
      for (final table in zone.tables) {
        final order = openByTable[table.label];
        final state = _stateOf(order);
        counts[state] = (counts[state] ?? 0) + 1;
        if (order != null) {
          occupied++;
          coversSeated += order.covers ?? 0;
          final dwell = DateTime.now().difference(order.createdAt).inMinutes;
          dwellSum += dwell;
          if (state == PcTableState.late) {
            lateCount++;
            lateOrder ??= order;
          }
        }
      }
    }
    final totalTables = widget.settings.tableCount;
    final avgDwell = occupied == 0 ? 0 : (dwellSum / occupied).round();

    return PcShell(
      chrome: widget.chrome,
      activeNav: PcNav.floor,
      title: tr('Dine-in · floor', 'ডাইন-ইন · ফ্লোর'),
      sub: tr(
        'Live table map · auto-refresh',
        'লাইভ টেবিল ম্যাপ · অটো-রিফ্রেশ',
      ),
      topActions: [
        if (widget.onConfigure != null)
          PcBtn(
            label: tr('Configure floor', 'ফ্লোর কনফিগার'),
            variant: PcVariant.ghost,
            icon: 'edit',
            onTap: widget.onConfigure,
          ),
      ],
      footerHints: const [
        PcKey('F4', 'New walk-in'),
        PcKey('F8', 'Find table'),
        PcKey('Esc', 'Back'),
      ],
      child: Row(
        children: [
          Expanded(child: _floor(openByTable, counts, totalTables)),
          _snapshotRail(
            occupied,
            totalTables,
            coversSeated,
            avgDwell,
            lateCount,
            lateOrder,
          ),
        ],
      ),
    );
  }

  Widget _floor(
    Map<String, OrderModel> openByTable,
    Map<PcTableState, int> counts,
    int totalTables,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // filter chips
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _filterChip(null, tr('All', 'সব'), totalTables),
                    _filterChip(
                      PcTableState.idle,
                      tr('Free', 'খালি'),
                      counts[PcTableState.idle] ?? 0,
                    ),
                    _filterChip(
                      PcTableState.seated,
                      tr('Seated', 'বসা'),
                      counts[PcTableState.seated] ?? 0,
                    ),
                    _filterChip(
                      PcTableState.kitchen,
                      tr('In kitchen', 'রান্নাঘরে'),
                      counts[PcTableState.kitchen] ?? 0,
                    ),
                    _filterChip(
                      PcTableState.bill,
                      tr('Bill ready', 'বিল প্রস্তুত'),
                      counts[PcTableState.bill] ?? 0,
                    ),
                    _filterChip(
                      PcTableState.late,
                      tr('Late', 'দেরি'),
                      counts[PcTableState.late] ?? 0,
                    ),
                  ],
                ),
              ),
              Text(
                tr('Auto-refresh · live', 'অটো-রিফ্রেশ · লাইভ'),
                style: Pc.mono(
                  11.5,
                  weight: FontWeight.w600,
                  color: Pc.textSec,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                for (final zone in widget.settings.floorLayout) ...[
                  Row(
                    children: [
                      Text(
                        zone.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(child: Divider(height: 1)),
                      const SizedBox(width: 10),
                      PcEyebrow(
                        '${zone.tables.length} ${tr('tables', 'টেবিল')}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 6,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.25,
                    children: [
                      for (final table in zone.tables)
                        _tableCard(table, openByTable[table.label]),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(PcTableState? state, String label, int count) {
    final on = _filter == state;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _filter = state),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: on ? Pc.ink : Pc.surface,
            border: Border.all(color: on ? Pc.ink : Pc.border),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state == PcTableState.late || state == PcTableState.bill) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: state == PcTableState.late ? Pc.late : Pc.ink,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: on ? Pc.onInk : Pc.text,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$count',
                style: Pc.mono(
                  10.5,
                  color: on ? Colors.white.withValues(alpha: 0.85) : Pc.textTer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tableCard(PosFloorTable table, OrderModel? order) {
    final state = _stateOf(order);
    final dimmed = _filter != null && _filter != state;
    final style = PcTableStyle.of(state);
    final dwell = order == null
        ? null
        : DateTime.now().difference(order.createdAt).inMinutes;
    return Opacity(
      opacity: dimmed ? 0.35 : 1,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => widget.onTable(table.label, order),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: style.bg,
              border: Border.all(
                color: state == PcTableState.idle
                    ? style.border
                    : style.border.withValues(alpha: 0.45),
              ),
              borderRadius: BorderRadius.circular(Pc.rMd),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (state == PcTableState.late || state == PcTableState.bill)
                  Positioned(
                    top: -6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: state == PcTableState.late ? Pc.late : Pc.ink,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        state == PcTableState.late ? 'LATE' : 'BILL',
                        style: Pc.mono(9.5, color: Colors.white),
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'T${table.label}',
                          style: Pc.num(
                            18,
                            color: style.fg,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: style.dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          style.label,
                          style: Pc.mono(
                            10,
                            color: style.fg.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              order == null
                                  ? '${table.seats}P'
                                  : '${order.covers ?? table.seats}P${dwell == null ? '' : ' · ${dwell}m'}',
                              style: Pc.num(
                                11,
                                weight: FontWeight.w600,
                                color: style.fg.withValues(alpha: 0.85),
                              ),
                            ),
                            const Spacer(),
                            if (order != null && order.total > 0)
                              Text(
                                pcMoney(order.total),
                                style: Pc.num(13, color: style.fg),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _snapshotRail(
    int occupied,
    int total,
    int covers,
    int avgDwell,
    int lateCount,
    OrderModel? lateOrder,
  ) {
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Pc.surface,
        border: Border(left: BorderSide(color: Pc.border)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PcEyebrow(tr('Service snapshot · live', 'লাইভ স্ন্যাপশট')),
          const SizedBox(height: 14),
          _stat(
            tr('Tables open', 'খোলা টেবিল'),
            '$occupied / $total',
            tr('${total - occupied} free', '${total - occupied} খালি'),
          ),
          _stat(
            tr('Covers seated', 'বসা কভার'),
            '$covers',
            tr('dine-in guests', 'ডাইন-ইন গেস্ট'),
          ),
          _stat(
            tr('Avg dwell', 'গড় সময়'),
            '${avgDwell}m',
            tr('per occupied table', 'প্রতি টেবিল'),
          ),
          _stat(
            tr('Late tables', 'দেরি টেবিল'),
            '$lateCount',
            lateOrder == null ? tr('none', 'নেই') : 'T${lateOrder.tableNo}',
            tone: lateCount > 0 ? Pc.late : null,
            last: true,
          ),
          const Spacer(),
          if (lateOrder != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Pc.lateSoft,
                border: Border.all(color: Pc.late.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(Pc.rMd),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PcEyebrow(tr('Needs you', 'আপনার দরকার'), color: Pc.late),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      'T${lateOrder.tableNo} seated ${DateTime.now().difference(lateOrder.createdAt).inMinutes}m',
                      'T${lateOrder.tableNo} বসেছে ${DateTime.now().difference(lateOrder.createdAt).inMinutes} মিনিট',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Pc.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr('Check on the guests.', 'গেস্টদের খোঁজ নিন।'),
                    style: const TextStyle(fontSize: 11.5, color: Pc.textSec),
                  ),
                  const SizedBox(height: 10),
                  PcBtn(
                    label: 'T${lateOrder.tableNo} →',
                    variant: PcVariant.dark,
                    size: PcSize.sm,
                    full: true,
                    onTap: () => widget.onTable(lateOrder.tableNo!, lateOrder),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(
    String label,
    String value,
    String sub, {
    Color? tone,
    bool last = false,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: Pc.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PcEyebrow(label, color: tone ?? Pc.textSec),
          const SizedBox(height: 6),
          Text(
            value,
            style: Pc.num(
              26,
              color: tone ?? Pc.ink,
              letterSpacing: -0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(fontSize: 11.5, color: Pc.textSec)),
        ],
      ),
    );
  }

  PcTableState _stateOf(OrderModel? order) {
    if (order == null) return PcTableState.idle;
    final dwell = DateTime.now().difference(order.createdAt).inMinutes;
    if (dwell >= 75) return PcTableState.late;
    if (order.status == OrderStatus.ready) return PcTableState.bill;
    final anySent = order.items.any((i) => i.kotSentAt != null);
    return anySent ? PcTableState.kitchen : PcTableState.seated;
  }
}
