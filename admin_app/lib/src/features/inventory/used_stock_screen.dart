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
      await AppScope.read(
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
    final app = AppScope.selectMany(context, const [AppAspect.inventory]);
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const TfText(
            'Usage reason',
            style: TextStyle(
              color: PosColors.textTer,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.04,
              height: 1.3,
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
            'Items used',
            style: TextStyle(
              color: PosColors.textTer,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.04,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          for (final item in items)
            _UsedLine(item: item, controller: _controller(item)),
        ],
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
                            item.localizedName(AppScope.selectMany(context, const [AppAspect.language]).language),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TfText(
                            '${item.quantity.toStringAsFixed(1)} $unit on hand',
                            style: const TextStyle(
                              color: PosColors.textSec,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              height: 1.45,
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
