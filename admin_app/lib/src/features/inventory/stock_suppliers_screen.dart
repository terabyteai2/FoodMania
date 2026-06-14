import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/inventory_supplier.dart';

/// Suppliers drill-down (spec §4.7 advanced). Contact list + add supplier.
class SuppliersScreen extends StatelessWidget {
  const SuppliersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final suppliers = app.inventorySuppliers
        .where((s) => s.isActive)
        .toList(growable: false);

    return AppScaffold(
      title: text.suppliers,
      subtitle: text.suppliersCount(suppliers.length),
      showDatePill: false,
      showBackButton: true,
      pinHeader: true,
      fillBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: suppliers.isEmpty
                ? Center(
                    child: TfEmptyState(
                      icon: Icons.local_shipping_outlined,
                      title: text.noSuppliers,
                      message: 'Add a supplier to track contacts & orders.',
                      messageBn:
                          'যোগাযোগ ও অর্ডার ট্র্যাক করতে সাপ্লায়ার যোগ করুন।',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: suppliers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _SupplierCard(supplier: suppliers[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
            child: TfButton(
              label: text.addSupplier,
              icon: Icons.add_rounded,
              variant: TfButtonVariant.primary,
              size: TfButtonSize.lg,
              onPressed: () => _showAddSupplier(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupplierCard extends StatelessWidget {
  const _SupplierCard({required this.supplier});

  final InventorySupplier supplier;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PosColors.surfaceSunk,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.local_shipping_outlined,
              size: 20,
              color: PosColors.text,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  supplier.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: PosColors.text,
                  ),
                ),
                if (supplier.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 1),
                  TfText(
                    supplier.notes,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: PosColors.muted,
                    ),
                  ),
                ],
                if (supplier.phone.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  TfText(
                    supplier.phone,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: PosColors.mutedSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _showAddSupplier(BuildContext context) async {
  final app = AppScope.of(context);
  // saveInventorySupplier refreshes the list + notifies listeners, so the
  // AppScope-subscribed SuppliersScreen rebuilds automatically.
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AddSupplierSheet(text: app.strings),
  );
}

class _AddSupplierSheet extends StatefulWidget {
  const _AddSupplierSheet({required this.text});

  final AppStrings text;

  @override
  State<_AddSupplierSheet> createState() => _AddSupplierSheetState();
}

class _AddSupplierSheetState extends State<_AddSupplierSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    final now = DateTime.now();
    try {
      await AppScope.of(context).saveInventorySupplier(
        InventorySupplier(
          id: const Uuid().v4(),
          name: name,
          phone: _phoneCtrl.text.trim(),
          notes: _notesCtrl.text.trim(),
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TfText(
                  text.addSupplier,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                TfField(
                  label: text.isBn ? 'নাম' : 'Name',
                  controller: _nameCtrl,
                  autofocus: true,
                ),
                TfField(
                  label: text.isBn ? 'ফোন' : 'Phone',
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                TfField(
                  label: text.isBn
                      ? 'নোট (যেমন: কী সরবরাহ করে)'
                      : 'Notes (what they supply)',
                  controller: _notesCtrl,
                ),
                const SizedBox(height: 8),
                TfButton(
                  label: text.save,
                  size: TfButtonSize.lg,
                  busy: _busy,
                  onPressed: _busy ? null : _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
