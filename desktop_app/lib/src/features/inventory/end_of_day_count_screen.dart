import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/inventory_item.dart';
import '../../models/inventory_unit.dart';

class EndOfDayCountScreen extends StatefulWidget {
  const EndOfDayCountScreen({super.key});

  @override
  State<EndOfDayCountScreen> createState() => _EndOfDayCountScreenState();
}

class _EndOfDayCountScreenState extends State<EndOfDayCountScreen> {
  final Map<String, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controller(InventoryItem item) =>
      _controllers.putIfAbsent(
        item.id,
        () => TextEditingController(text: item.quantity.toStringAsFixed(1)),
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    final app = AppScope.of(context);
    try {
      for (final item in app.inventoryItems) {
        final value = double.tryParse(_controller(item).text.trim());
        if (value != null) {
          await app.setInventoryEndOfDayCount(
            inventoryItemId: item.id,
            quantity: value,
          );
        }
      }
      await app.refreshInventorySummary();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        backgroundColor: PosColors.background,
        title: const TfText(
          'End-of-day count',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PosColors.primaryWash,
              borderRadius: BorderRadius.circular(PosRadii.card),
            ),
            child: const TfText(
              'Count what is physically on hand. Differences are recorded as count corrections.',
              style: TextStyle(color: PosColors.primaryDark, fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
            ),
          ),
          const SizedBox(height: 16),
          for (final item in app.inventoryItems)
            _CountLine(item: item, controller: _controller(item)),
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
            label: 'Save count',
            busy: _saving,
            onPressed: _saving ? null : _save,
          ),
        ),
      ),
    );
  }
}

class _CountLine extends StatelessWidget {
  const _CountLine({required this.item, required this.controller});
  final InventoryItem item;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final unit = InventoryUnits.displayLabel(item.unit, isBn: tfIsBn(context));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TfCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: TfText(
                item.localizedName(AppScope.of(context).language),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
            SizedBox(
              width: 104,
              child: TextField(
                controller: controller,
                textAlign: TextAlign.end,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                ],
                decoration: InputDecoration(suffixText: unit, isDense: true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
