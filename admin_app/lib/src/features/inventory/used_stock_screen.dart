import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_unit.dart';

class UsedStockScreen extends StatefulWidget {
  const UsedStockScreen({super.key});

  @override
  State<UsedStockScreen> createState() => _UsedStockScreenState();
}

class _UsedStockScreenState extends State<UsedStockScreen> {
  final Map<String, TextEditingController> _controllers = {};
  String _reason = 'kitchen';
  bool _saving = false;

  static const _reasons = {
    'kitchen': 'Kitchen',
    'staff_meal': 'Staff meal',
    'spoiled': 'Spoiled',
    'sample': 'Sample',
    'other': 'Other',
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(InventoryItem item) =>
      _controllers.putIfAbsent(item.id, () => TextEditingController());

  Future<void> _save() async {
    final quantities = <String, double>{};
    for (final entry in _controllers.entries) {
      final qty = double.tryParse(entry.value.text.trim()) ?? 0;
      if (qty > 0) quantities[entry.key] = qty;
    }
    if (quantities.isEmpty) return;
    setState(() => _saving = true);
    try {
      await AppScope.of(
        context,
      ).recordInventoryUsageBatch(quantities, reason: _reason);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: TfText(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final items = app.inventoryItems;
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        backgroundColor: PosColors.background,
        title: const TfText(
          'Record used stock',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          const TfText(
            'USAGE REASON',
            style: TextStyle(
              color: PosColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reasons.entries
                .map(
                  (entry) => TfChip(
                    label: entry.value,
                    active: _reason == entry.key,
                    small: true,
                    onTap: () => setState(() => _reason = entry.key),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 24),
          const TfText(
            'ITEMS USED',
            style: TextStyle(
              color: PosColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            _UsedLine(item: item, controller: _controller(item)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: PosColors.surface,
            border: Border(top: BorderSide(color: PosColors.line, width: 0.5)),
          ),
          child: TfButton(
            label: 'Save used stock',
            icon: Icons.remove_circle_outline,
            busy: _saving,
            onPressed: _saving ? null : _save,
            size: TfButtonSize.lg,
          ),
        ),
      ),
    );
  }
}

class _UsedLine extends StatelessWidget {
  const _UsedLine({required this.item, required this.controller});

  final InventoryItem item;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final unit = InventoryUnits.displayLabel(item.unit, isBn: tfIsBn(context));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TfCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final max = item.quantity <= 0 ? 1.0 : item.quantity;
            final parsed = double.tryParse(value.text) ?? 0;
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TfText(
                            item.localizedName(AppScope.of(context).language),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          TfText(
                            '${item.quantity.toStringAsFixed(1)} $unit on hand',
                            style: const TextStyle(
                              color: PosColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 92,
                      child: TextField(
                        controller: controller,
                        textAlign: TextAlign.end,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        decoration: InputDecoration(
                          hintText: '0 $unit',
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: parsed.clamp(0, max),
                  max: max,
                  onChanged: item.quantity <= 0
                      ? null
                      : (next) => controller.text = next.toStringAsFixed(1),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
