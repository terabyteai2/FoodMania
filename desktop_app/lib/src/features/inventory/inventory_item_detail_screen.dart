import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_unit.dart';
import '../../models/stock_adjustment.dart';
import 'stock_in_screen.dart';

class InventoryItemDetailScreen extends StatefulWidget {
  const InventoryItemDetailScreen({required this.item, this.onEdit, super.key});

  final InventoryItem item;
  final VoidCallback? onEdit;

  @override
  State<InventoryItemDetailScreen> createState() =>
      _InventoryItemDetailScreenState();
}

class _InventoryItemDetailScreenState extends State<InventoryItemDetailScreen> {
  late Future<List<StockAdjustment>> _history;

  @override
  void initState() {
    super.initState();
    _history = Future.value(const []);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(
        () =>
            _history = AppScope.of(context).getStockAdjustments(widget.item.id),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final item =
        app.inventoryItems
            .where((row) => row.id == widget.item.id)
            .firstOrNull ??
        widget.item;
    final unit = InventoryUnits.displayLabel(item.unit, isBn: app.strings.isBn);
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        backgroundColor: PosColors.background,
        title: TfText(
          item.localizedName(app.language),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (app.isManager && widget.onEdit != null)
            IconButton(
              onPressed: widget.onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: FutureBuilder<List<StockAdjustment>>(
        future: _history,
        builder: (context, snapshot) {
          final rows = snapshot.data ?? const <StockAdjustment>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              TfCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TfText(
                      'On hand',
                      style: TextStyle(
                        color: PosColors.textTer,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.04,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TfText(
                      '${item.quantity.toStringAsFixed(1)} $unit',
                      style: const TextStyle(
                        color: PosColors.primaryDark,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                        letterSpacing: -0.02,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _Metric(
                          label: 'Low alert',
                          value:
                              '${item.minThreshold.toStringAsFixed(1)} $unit',
                        ),
                        _Metric(
                          label: 'Unit cost',
                          value: '৳${item.costPerUnit.toStringAsFixed(0)}',
                        ),
                        _Metric(
                          label: 'Stock value',
                          value:
                              '৳${(item.quantity * item.costPerUnit).toStringAsFixed(0)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const TfText(
                '30-day movement',
                style: TextStyle(
                  color: PosColors.textTer,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.04,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              _MovementChart(rows: rows),
              const SizedBox(height: 20),
              const TfText(
                'Recent movement',
                style: TextStyle(
                  color: PosColors.textTer,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.04,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              TfCard(
                padding: EdgeInsets.zero,
                child: rows.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: TfText(
                          'No movements recorded yet.',
                          style: TextStyle(color: PosColors.muted),
                        ),
                      )
                    : Column(
                        children: rows
                            .take(20)
                            .map((row) => _MovementRow(row: row, unit: unit))
                            .toList(),
                      ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        decoration: const BoxDecoration(
          color: PosColors.surface,
          boxShadow: PosShadows.bar,
        ),
        child: SafeArea(
          top: false,
          child: TfButton(
            label: 'Stock in',
            icon: Icons.add,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StockInScreen(preseedItemId: item.id),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfText(
          label,
          style: const TextStyle(
            color: PosColors.textTer,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.04,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 6),
        TfText(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

class _MovementChart extends StatelessWidget {
  const _MovementChart({required this.rows});
  final List<StockAdjustment> rows;
  @override
  Widget build(BuildContext context) {
    final recent = rows.take(14).toList().reversed.toList();
    final maxValue = recent.fold<double>(
      1,
      (max, row) => row.delta.abs() > max ? row.delta.abs() : max,
    );
    return TfCard(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      child: SizedBox(
        height: 104,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: recent.isEmpty
              ? [
                  const Expanded(
                    child: Center(
                      child: TfText(
                        'Movement chart appears after stock changes.',
                        style: TextStyle(color: PosColors.muted, fontSize: 12),
                      ),
                    ),
                  ),
                ]
              : recent
                    .map(
                      (row) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            height: 12 + 76 * (row.delta.abs() / maxValue),
                            decoration: BoxDecoration(
                              color: row.delta < 0
                                  ? PosColors.warningSoft
                                  : PosColors.successSoft,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
        ),
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.row, required this.unit});
  final StockAdjustment row;
  final String unit;
  @override
  Widget build(BuildContext context) {
    final positive = row.delta >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PosColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          Icon(
            positive ? Icons.add_circle_outline : Icons.remove_circle_outline,
            size: 18,
            color: positive ? PosColors.success : PosColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TfText(
              row.reason.isNotEmpty ? row.reason : row.type.label(),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TfText(
                '${positive ? '+' : ''}${row.delta.toStringAsFixed(1)} $unit',
                style: TextStyle(
                  color: positive ? PosColors.success : PosColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TfText(
                DateFormat('MMM d, h:mm a').format(row.createdAt),
                style: const TextStyle(color: PosColors.muted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
