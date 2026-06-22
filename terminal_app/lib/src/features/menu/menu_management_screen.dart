import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/menu_item.dart';
import '../../models/pos_notification.dart';
import '../settings/settings_screen.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    super.key,
  });

  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final query = _searchController.text.trim().toLowerCase();
    final items = app.menuItems;

    final categories = <String>{'All'};
    for (final item in items) {
      categories.add(item.category);
    }
    final sortedCategories = categories.toList()
      ..sort((a, b) => a == 'All' ? -1 : b == 'All' ? 1 : a.compareTo(b));

    final filtered = query.isEmpty
        ? items
        : items.where((item) =>
            item.name.toLowerCase().contains(query) ||
            item.category.toLowerCase().contains(query)).toList();

    final categoryFiltered = _selectedCategory == 'All'
        ? filtered
        : filtered.where((item) => item.category == _selectedCategory).toList();

    final deliveryOn = app.serverConfig.deliveryCharge > 0;

    return AppScaffold(
      title: text.menu,
      headerWidget: AppPageHeader(
        title: text.menu,
        subtitle: text.menuItemsSubtitle(
          items.length,
          items.where((i) => !i.isAvailable).length,
        ),
        onNavigateToOrders: widget.onNavigateToOrders,
        onNavigateToTarget: widget.onNavigateToTarget,
      ),
      showDatePill: false,
      pinHeader: true,
      fillBody: true,
      floatingActionButton: TfFab(
        onPressed: () => _openItemEditor(context, app, text, null),
      ),
      child: Column(
        children: [
          _MenuActionRow(
            text: text,
            deliveryOn: deliveryOn,
            onDelivery: () => _openDeliveryChargeEditor(context),
            onDiscounts: () => _openDiscountsAction(context),
            onSettings: () => _openMenuSettings(context),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TfField(
              label: '',
              hint: text.menuSearchHint,
              controller: _searchController,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                for (final cat in sortedCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TfChip(
                      label: cat,
                      active: cat == _selectedCategory,
                      onTap: () => setState(() => _selectedCategory = cat),
                      small: true,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: categoryFiltered.isEmpty
                ? _buildEmptyState(text)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                    itemCount: categoryFiltered.length,
                    itemBuilder: (context, index) {
                      final item = categoryFiltered[index];
                      return _MenuItemCard(
                        item: item,
                        text: text,
                        app: app,
                        onTap: () => _openItemEditor(context, app, text, item),
                        onToggle: () => _toggleAvailability(app, text, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppStrings text) {
    final icon = Icon(
      _searchController.text.trim().isNotEmpty
          ? Icons.search_off_rounded
          : Icons.restaurant_menu_outlined,
      size: 48,
      color: PosColors.muted,
    );
    final title = _searchController.text.trim().isNotEmpty
        ? text.menuNoResultsTitle
        : text.menuEmptyTitle;
    final message = _searchController.text.trim().isNotEmpty
        ? text.menuNoResultsMessage
        : text.menuEmptyMessage;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(height: 12),
            TfText(title, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: PosColors.slate,
            )),
            const SizedBox(height: 4),
            TfText(message, style: const TextStyle(fontSize: 13, color: PosColors.muted)),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleAvailability(PosAppController app, AppStrings text, MenuItem item) async {
    await app.saveMenuItem(
      id: item.id,
      name: item.name,
      description: item.description,
      category: item.category,
      price: item.price,
      isAvailable: !item.isAvailable,
      nameEn: item.nameEn,
      nameBn: item.nameBn,
      descriptionEn: item.descriptionEn,
      descriptionBn: item.descriptionBn,
      categoryEn: item.categoryEn,
      categoryBn: item.categoryBn,
      imageUrl: item.imageUrl,
      preparationTimeMinutes: item.preparationTimeMinutes,
      tags: item.tags,
      createdAt: item.createdAt,
    );
  }

  void _openItemEditor(
    BuildContext context, PosAppController app, AppStrings text, MenuItem? item,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PosColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.xl)),
      ),
      builder: (_) => _ItemEditorSheet(
        app: app,
        text: text,
        item: item,
        onSaved: () => setState(() {}),
      ),
    );
  }

  Future<void> _openDeliveryChargeEditor(BuildContext context) async {
    final app = AppScope.of(context);
    final text = app.strings;
    final value = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PosColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.xl)),
      ),
      builder: (_) => _DeliveryChargeSheet(initialValue: app.serverConfig.deliveryCharge),
    );
    if (value == null || !context.mounted) return;
    await app.updateDeliveryCharge(value);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: TfText(text.menuDeliveryChargeSaved)),
    );
  }

  Future<void> _openDiscountsAction(BuildContext context) async {
    final app = AppScope.of(context);
    final text = app.strings;
    final result = await showModalBottomSheet<_BulkDiscountResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PosColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.xl)),
      ),
      builder: (_) => const _BulkDiscountSheet(),
    );
    if (result == null || !context.mounted) return;
    final targetItems = result.target == _MenuSettingsTarget.all
        ? app.menuItems
        : app.menuItems.where((i) => i.isAvailable).toList();
    if (targetItems.isEmpty) return;
    for (final item in targetItems) {
      final discountPercent = result.mode == _DiscountMode.percent ? result.value : null;
      final discountFlat = result.mode == _DiscountMode.flat ? result.value : null;
      await app.saveMenuItem(
        id: item.id,
        name: item.name,
        description: item.description,
        category: item.category,
        price: item.price,
        isAvailable: item.isAvailable,
        tags: _encodeDiscountTags(item.tags, discountPercent, discountFlat),
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TfText('${targetItems.length} ${text.menuDiscountSummary}')),
      );
    }
  }

  List<String> _encodeDiscountTags(
    List<String> current, double? percent, double? flat,
  ) {
    final cleaned = current.where((t) =>
        !t.startsWith('discount_percent:') && !t.startsWith('discount_flat:')).toList();
    if (percent != null) cleaned.add('discount_percent:$percent');
    if (flat != null) cleaned.add('discount_flat:$flat');
    return cleaned;
  }

  void _openMenuSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          onNavigateToOrders: widget.onNavigateToOrders,
        ),
      ),
    );
  }
}

// ── Action row ──────────────────────────────────────────────────────────────

class _MenuActionRow extends StatelessWidget {
  const _MenuActionRow({
    required this.text,
    required this.deliveryOn,
    required this.onDelivery,
    required this.onDiscounts,
    required this.onSettings,
  });

  final AppStrings text;
  final bool deliveryOn;
  final VoidCallback onDelivery;
  final VoidCallback onDiscounts;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Row(
        children: [
          _MenuActionButton(
            icon: Icons.delivery_dining_outlined,
            label: deliveryOn ? (text.isBn ? 'ডেলিভারি চালু' : 'Delivery on') : (text.isBn ? 'ডেলিভারি বন্ধ' : 'Delivery off'),
            active: deliveryOn,
            onTap: onDelivery,
          ),
          const SizedBox(width: 8),
          _MenuActionButton(
            icon: Icons.percent_rounded,
            label: text.menuActionDiscounts,
            onTap: onDiscounts,
          ),
          const SizedBox(width: 8),
          _MenuActionButton(
            icon: Icons.tune_rounded,
            label: text.menuActionSettings,
            onTap: onSettings,
          ),
        ],
      ),
    );
  }
}

class _MenuActionButton extends StatelessWidget {
  const _MenuActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosRadii.card),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? PosColors.primarySoft : PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.card),
            border: Border.all(
              color: active ? PosColors.primaryWash : PosColors.lineStrong,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20,
                color: active ? PosColors.accentStrong : PosColors.inkSoft,
              ),
              const SizedBox(height: 5),
              TfText(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: active ? PosColors.accentStrong : PosColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Delivery charge sheet ───────────────────────────────────────────────────

class _DeliveryChargeSheet extends StatefulWidget {
  const _DeliveryChargeSheet({required this.initialValue});
  final double initialValue;

  @override
  State<_DeliveryChargeSheet> createState() => _DeliveryChargeSheetState();
}

class _DeliveryChargeSheetState extends State<_DeliveryChargeSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final value = widget.initialValue;
    _controller = TextEditingController(
      text: value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TfText(text.menuDeliveryCharge,
                      style: const TextStyle(
                        color: PosColors.slate, fontSize: 18, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              TfText(text.menuDeliveryChargeSubtitle,
                style: const TextStyle(color: PosColors.muted, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 16),
              TfField(
                label: text.menuDeliveryCharge,
                controller: _controller,
                hint: text.menuDeliveryChargeHint,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                errorText: _error,
                prefix: const Icon(Icons.currency_exchange_rounded, color: PosColors.muted, size: 18),
              ),
              const SizedBox(height: 16),
              TfButton(
                label: text.isBn ? 'সেভ করুন' : 'Save charge',
                onPressed: _save,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value < 0 || value > 100000) {
      setState(() => _error = AppScope.of(context).strings.menuDeliveryChargeInvalid);
      return;
    }
    Navigator.of(context).pop(value);
  }
}

// ── Discount sheet ──────────────────────────────────────────────────────────

enum _DiscountMode { percent, flat }
enum _MenuSettingsTarget { all, available }

class _BulkDiscountResult {
  const _BulkDiscountResult({required this.mode, required this.value, required this.target});
  final _DiscountMode mode;
  final double? value;
  final _MenuSettingsTarget target;
}

class _BulkDiscountSheet extends StatefulWidget {
  const _BulkDiscountSheet();
  @override
  State<_BulkDiscountSheet> createState() => _BulkDiscountSheetState();
}

class _BulkDiscountSheetState extends State<_BulkDiscountSheet> {
  _DiscountMode _mode = _DiscountMode.percent;
  _MenuSettingsTarget _target = _MenuSettingsTarget.all;
  late final TextEditingController _valueController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _valueController = TextEditingController();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TfText(text.menuActionDiscounts,
                      style: const TextStyle(
                        color: PosColors.slate, fontSize: 18, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Seg(
                    label: text.menuDiscountPercent,
                    selected: _mode == _DiscountMode.percent,
                    onTap: () => setState(() => _mode = _DiscountMode.percent),
                  ),
                  const SizedBox(width: 8),
                  _Seg(
                    label: text.menuDiscountFlat,
                    selected: _mode == _DiscountMode.flat,
                    onTap: () => setState(() => _mode = _DiscountMode.flat),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TfField(
                label: text.menuDiscountValue,
                controller: _valueController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                prefix: Icon(
                  _mode == _DiscountMode.percent ? Icons.percent_rounded : Icons.currency_exchange_rounded,
                  color: PosColors.muted, size: 18,
                ),
                errorText: _error,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Seg(
                    label: text.isBn ? 'সব আইটেম' : 'All items',
                    selected: _target == _MenuSettingsTarget.all,
                    onTap: () => setState(() => _target = _MenuSettingsTarget.all),
                  ),
                  const SizedBox(width: 8),
                  _Seg(
                    label: text.menuAvailable,
                    selected: _target == _MenuSettingsTarget.available,
                    onTap: () => setState(() => _target = _MenuSettingsTarget.available),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TfButton(
                label: text.isBn ? 'ডিসকাউন্ট প্রয়োগ করুন' : 'Apply discount',
                onPressed: _apply,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _apply() {
    final raw = _valueController.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = 'Enter a value');
      return;
    }
    final v = double.tryParse(raw);
    if (v == null || v <= 0 || (_mode == _DiscountMode.percent && v > 100)) {
      setState(() => _error = 'Invalid value');
      return;
    }
    Navigator.of(context).pop(_BulkDiscountResult(mode: _mode, value: v, target: _target));
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? PosColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(PosRadii.sm),
            border: Border.all(
              color: selected ? PosColors.primary : PosColors.lineStrong,
            ),
          ),
          child: TfText(label,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? PosColors.accentInk : PosColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Menu item card ──────────────────────────────────────────────────────────

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.text,
    required this.app,
    required this.onTap,
    required this.onToggle,
  });

  final MenuItem item;
  final AppStrings text;
  final PosAppController app;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: TfListCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(PosRadii.sm),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: MenuImageView(imageUrl: item.imageUrl),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TfText(item.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: PosColors.slate,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TfText(item.category,
                        style: const TextStyle(fontSize: 12, color: PosColors.muted),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TfText(
                    '\u09F3${item.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: PosColors.slate,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                TfToggle(
                  value: item.isAvailable,
                  onChanged: (_) => onToggle(),
                  semanticLabel: text.menuAvailable,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Item editor bottom sheet ────────────────────────────────────────────────

class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({
    required this.app,
    required this.text,
    this.item,
    this.onSaved,
  });

  final PosAppController app;
  final AppStrings text;
  final MenuItem? item;
  final VoidCallback? onSaved;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  late bool _isAvailable;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _priceController = TextEditingController(
      text: item != null ? item.price.toStringAsFixed(0) : '',
    );
    _categoryController = TextEditingController(text: item?.category ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _isAvailable = item?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final priceText = _priceController.text.trim();
    if (name.isEmpty || priceText.isEmpty) return;

    setState(() => _saving = true);
    try {
      await widget.app.saveMenuItem(
        id: widget.item?.id,
        name: name,
        description: _descriptionController.text.trim(),
        category: _categoryController.text.trim().isEmpty
            ? 'General'
            : _categoryController.text.trim(),
        price: double.tryParse(priceText) ?? 0,
        isAvailable: _isAvailable,
      );
      if (mounted) {
        widget.onSaved?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TfText(
              widget.item == null ? widget.text.menuItemAdded : widget.text.menuItemUpdated,
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: TfText(widget.text.menuDeleteTitle),
        content: TfText(widget.text.menuDeleteDescription(widget.item?.name ?? '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: TfText(widget.text.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: TfText(widget.text.deleteAction,
              style: const TextStyle(color: PosColors.danger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && widget.item != null) {
      await widget.app.deleteMenuItem(widget.item!.id);
      if (mounted) {
        widget.onSaved?.call();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TfText(widget.text.menuDeleted)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4,
            decoration: BoxDecoration(
              color: PosColors.lineStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TfText(
                    widget.item == null ? widget.text.menuCreateItem : widget.item!.name,
                    style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700, color: PosColors.slate,
                    ),
                  ),
                ),
                if (widget.item != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: PosColors.danger),
                    onPressed: _delete,
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                TfField(label: widget.text.menuItemName, controller: _nameController),
                const SizedBox(height: 12),
                TfField(
                  label: widget.text.menuPrice,
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: 12),
                TfField(label: widget.text.menuCategory, controller: _categoryController),
                const SizedBox(height: 12),
                TfField(label: widget.text.menuDescriptionOptional, controller: _descriptionController),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TfText(widget.text.menuAvailable,
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500, color: PosColors.slate,
                      ),
                    ),
                    const Spacer(),
                    TfToggle(
                      value: _isAvailable,
                      onChanged: (v) => setState(() => _isAvailable = v),
                      semanticLabel: widget.text.menuAvailable,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TfButton(
                  label: widget.item == null ? widget.text.menuCreateItem : widget.text.menuSaveItem,
                  onPressed: _saving ? null : _save,
                  fullWidth: true,
                  busy: _saving,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
