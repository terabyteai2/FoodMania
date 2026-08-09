import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../core/widgets/guided_tour.dart';
import '../../models/menu_item.dart';
import '../../models/pos_notification.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';
import '../desktop_pos/widgets/pc_theme.dart';
import '../desktop_pos/widgets/pc_widgets.dart';
import 'menu_scan_screen.dart';
import 'square_image_cropper.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    this.desktop = false,
    super.key,
  });

  /// Called when a pending-order notification is opened from the bell here.
  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final bool desktop;

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  final MenuImageService _scanImageService = MenuImageService();
  final Set<String> _selectedItemIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Menu management reads the menu (items/categories), account (manager gate),
    // and language — not orders/printer/sync.
    final app = AppScope.selectMany(context, const [
      AppAspect.menu,
      AppAspect.account,
      AppAspect.language,
    ]);
    final text = app.strings;
    final language = app.language;
    final categories = [text.allCategories, ...app.categories];
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = text.allCategories;
    }

    final query = _searchController.text.trim().toLowerCase();
    final items = app.menuItems
        .where((item) {
          final matchesCategory =
              _selectedCategory == text.allCategories ||
              item.localizedCategory(language) == _selectedCategory;
          final matchesSearch = query.isEmpty
              ? true
              : item.searchText(language).contains(query);
          return matchesCategory && matchesSearch;
        })
        .toList(growable: false);
    final paused = app.menuItems.where((item) => !item.isAvailable).length;
    _selectedItemIds.removeWhere(
      (id) => !app.menuItems.any((item) => item.id == id),
    );

    if (widget.desktop) {
      return _desktopBody(
        app: app,
        text: text,
        language: language,
        categories: categories,
        items: items,
        paused: paused,
      );
    }

    // Scrollable content area (empty state, no-results, or the item list).
    final Widget listArea;
    if (app.menuItems.isEmpty) {
      listArea = TfEmptyState(
        title: text.menuEmptyTitle,
        message: text.menuEmptyMessage,
        icon: Icons.restaurant_menu_rounded,
      );
    } else if (items.isEmpty) {
      listArea = TfEmptyState(
        title: text.menuNoResultsTitle,
        message: text.menuNoResultsMessage,
        icon: Icons.search_off_rounded,
      );
    } else {
      listArea = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_selectedItemIds.isNotEmpty) ...[
            _BulkMenuToolbar(
              count: _selectedItemIds.length,
              onDiscount: () => _applyBulkDiscount(context),
              onDelete: () => _bulkDeleteItems(context),
              onClear: () => setState(_selectedItemIds.clear),
            ),
            const SizedBox(height: 16),
          ],
          _MenuList(
            items: items,
            language: language,
            selectedIds: _selectedItemIds,
            onEdit: app.isManager
                ? (item) => _openMenuForm(context, item: item)
                : (_) {},
            onSelect: (item) {
              if (!app.isManager) return;
              setState(() {
                if (!_selectedItemIds.add(item.id)) {
                  _selectedItemIds.remove(item.id);
                }
              });
            },
            onSelectAll: (selectAll) {
              if (!app.isManager) return;
              setState(() {
                if (selectAll) {
                  _selectedItemIds.addAll(items.map((i) => i.id));
                } else {
                  _selectedItemIds.removeAll(items.map((i) => i.id));
                }
              });
            },
            onAvailabilityChanged: (item, value) async {
              if (!app.isManager) return;
              await app.toggleMenuAvailability(item.id, value);
            },
          ),
        ],
      );
    }

    return AppScaffold(
      title: text.menu,
      headerWidget: TfGlobalTopBar(
        title: text.menu,
        onNavigateToOrders: widget.onNavigateToOrders,
        onNavigateToTarget: widget.onNavigateToTarget,
        // Delivery charge & Discounts moved to the drawer's Menu group — the
        // top bar stays uniform across screens.
      ),
      pinHeader: true,
      fillBody: true,
      // Search row + scroll content self-pad 16px; the filter-chip row and the
      // sticky footer stay full-bleed (they must reach the screen edge).
      removeHorizontalPadding: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, PosDensity.sectionGap, 16, 0),
            child: TourSpot(
              name: 'menu.search',
              child: TfSearchField(
                controller: _searchController,
                hintText: text.menuSearchHint,
                prefixIcon: Icons.search_rounded,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          if (app.menuItems.isNotEmpty) ...[
            SizedBox(height: PosDensity.sectionGap),
            TourSpot(
              name: 'menu.categories',
              child: TfFilterChipRow(
              chips: categories
                  .map(
                    (cat) => TfFilterChipData(
                      label: cat,
                      count: cat == text.allCategories
                          ? app.menuItems.length
                          : app.menuItems
                                .where(
                                  (i) => i.localizedCategory(language) == cat,
                                )
                                .length,
                      active: cat == _selectedCategory,
                    ),
                  )
                  .toList(),
              onSelected: (index) =>
                  setState(() => _selectedCategory = categories[index]),
              ),
            ),
          ],
          SizedBox(height: PosDensity.sectionGap),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: listArea,
            ),
          ),
          if (app.isManager)
            TfStickyCTA(
              child: Row(
                children: [
                  Expanded(
                    child: TourSpot(
                      name: 'menu.scanCta',
                      child: TfButton(
                        label: text.menuScanCardButton,
                        icon: Icons.document_scanner_outlined,
                        variant: TfButtonVariant.dark,
                        size: TfButtonSize.lg,
                        onPressed: () => _scanMenu(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TourSpot(
                      name: 'menu.newItem',
                      child: TfButton(
                        label: text.menuNewButton,
                        icon: Icons.add_rounded,
                        size: TfButtonSize.lg,
                        onPressed: () => _openMenuForm(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _desktopBody({
    required PosAppController app,
    required AppStrings text,
    required AppLanguage language,
    required List<String> categories,
    required List<MenuItem> items,
    required int paused,
  }) {
    final total = app.menuItems.length;
    final available = app.menuItems.where((item) => item.isAvailable).length;
    return Container(
      color: Pc.bg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 850;
              final search = SizedBox(
                width: compact ? double.infinity : 340,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 18),
                    hintText: text.menuSearchHint,
                  ),
                ),
              );
              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  PcBtn(
                    label: text.menuNewButton,
                    icon: 'plus',
                    variant: PcVariant.surface,
                    onTap: () => _openMenuForm(context),
                  ),
                  TourSpot(
                    name: 'menu.scanCta',
                    child: PcBtn(
                      label: text.menuScan,
                      icon: 'upload',
                      variant: PcVariant.dark,
                      onTap: () => _scanMenu(context),
                    ),
                  ),
                  PcBtn(
                    label: text.isBn ? 'সেটিংস' : 'Settings',
                    icon: 'settings',
                    variant: PcVariant.ghost,
                    onTap: () => _openMenuSettings(context),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [search, const SizedBox(height: 10), actions],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: search),
                  const SizedBox(width: PosSpacing.sp3),
                  actions,
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _desktopStat(
                  text.isBn ? 'মোট আইটেম' : 'Total items',
                  '$total',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _desktopStat(
                  text.isBn ? 'চালু' : 'Available',
                  '$available',
                  tone: PcTone.good,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _desktopStat(
                  text.isBn ? 'বন্ধ' : 'Paused',
                  '$paused',
                  tone: paused > 0 ? PcTone.warn : PcTone.muted,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _desktopStat(
                  text.isBn ? 'ক্যাটাগরি' : 'Categories',
                  '${app.categories.length}',
                ),
              ),
            ],
          ),
          if (app.menuItems.isNotEmpty) ...[
            const SizedBox(height: 14),
            _desktopCategories(text, language, categories, app.menuItems),
          ],
          if (_selectedItemIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            _DesktopBulkToolbar(
              count: _selectedItemIds.length,
              onDiscount: () => _applyBulkDiscount(context),
              onDelete: () => _bulkDeleteItems(context),
              onClear: () => setState(_selectedItemIds.clear),
              isBn: text.isBn,
            ),
          ],
          SizedBox(height: PosDensity.sectionGap),
          Expanded(
            child: app.menuItems.isEmpty
                ? Center(
                    child: _DesktopEmptyMenu(
                      title: text.menuEmptyTitle,
                      message: text.menuEmptyMessage,
                    ),
                  )
                : items.isEmpty
                ? Center(
                    child: _DesktopEmptyMenu(
                      title: text.menuNoResultsTitle,
                      message: text.menuNoResultsMessage,
                    ),
                  )
                : _DesktopMenuGrid(
                    items: items,
                    language: language,
                    selectedIds: _selectedItemIds,
                    selectionMode: _selectedItemIds.isNotEmpty,
                    canEdit: app.isManager,
                    onEdit: (item) => _openMenuForm(context, item: item),
                    onSelect: (item) {
                      if (!app.isManager) return;
                      setState(() {
                        if (!_selectedItemIds.add(item.id)) {
                          _selectedItemIds.remove(item.id);
                        }
                      });
                    },
                    onDelete: (item) => _confirmDelete(context, item),
                    onAvailabilityChanged: (item, value) async {
                      if (!app.isManager) return;
                      await app.toggleMenuAvailability(item.id, value);
                    },
                    onAddImage: (item) => _addImageToItem(context, item),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _desktopStat(
    String label,
    String value, {
    PcTone tone = PcTone.muted,
  }) {
    final color = switch (tone) {
      PcTone.good => Pc.good,
      PcTone.warn => Pc.warn,
      PcTone.bad => Pc.danger,
      PcTone.accent => Pc.accent,
      PcTone.muted => Pc.text,
    };
    return PcCard(
      pad: 12,
      child: Row(
        children: [
          Expanded(child: PcEyebrow(label)),
          Text(value, style: Pc.num(20, color: color, letterSpacing: -0.3)),
        ],
      ),
    );
  }

  Widget _desktopCategories(
    AppStrings text,
    AppLanguage language,
    List<String> categories,
    List<MenuItem> allItems,
  ) {
    int countOf(String category) => category == text.allCategories
        ? allItems.length
        : allItems
              .where((i) => i.localizedCategory(language) == category)
              .length;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Pc.ink : Pc.surface,
                border: Border.all(color: selected ? Pc.ink : Pc.border),
                borderRadius: BorderRadius.circular(PosRadii.chip),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    category == text.allCategories
                        ? text.allCategories
                        : category,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Pc.onInk : Pc.text,
                    ),
                  ),
                  const SizedBox(width: PosSpacing.sp2),
                  Text(
                    '${countOf(category)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.78)
                          : Pc.textTer,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _scanMenu(BuildContext context) async {
    final uploads = await Navigator.push<List<MenuScanPageUpload>>(
      context,
      MaterialPageRoute(builder: (_) => const MenuScanScreen()),
    );
    if (!context.mounted || uploads == null || uploads.isEmpty) return;
    final app = AppScope.read(context);
    unawaited(app.scanAndImportMenu(uploads));
  }

  Future<void> _applyBulkDiscount(BuildContext context) async {
    final app = AppScope.read(context);
    final selected = app.menuItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
    await _applyDiscountToItems(context, selected, clearSelection: true);
  }

  void _bulkDeleteItems(BuildContext context) {
    final app = AppScope.read(context);
    final text = app.strings;
    final selected = app.menuItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
    if (selected.isEmpty) return;
    TfConfirmSheet.show(
      context,
      title: text.menuDeleteTitle,
      description: text.isBn
          ? '${tfToBnNumbers('${selected.length}')} টি আইটেম মুছে ফেলা হবে'
          : '${selected.length} items will be deleted',
      confirmLabel: text.deleteAction,
      isDanger: true,
      onConfirm: () async {
        for (final item in selected) {
          await app.deleteMenuItem(item.id);
        }
        if (!context.mounted) return;
        setState(_selectedItemIds.clear);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TfText(text.menuDeletedBulk(selected.length))),
        );
      },
    );
  }

  // Discounts action row entry: apply to the current selection, or to every
  // item when nothing is selected.
  Future<void> _openMenuSettings(BuildContext context) async {
    final app = AppScope.read(context);
    final action = await showModalBottomSheet<_MenuSettingsAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MenuSettingsSheet(
        allCount: app.menuItems.length,
        selectedCount: _selectedItemIds.length,
        deliveryCharge: app.serverConfig.deliveryCharge,
      ),
    );
    if (action == null || !context.mounted) return;
    if (action.editDeliveryCharge) {
      await _openDeliveryChargeEditor(context);
      return;
    }
    final selected = app.menuItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
    final targetItems = action.target == _MenuSettingsTarget.selected
        ? selected
        : app.menuItems;
    if (targetItems.isEmpty) return;
    if (action.clearOnly) {
      await _applyDiscountResultToItems(
        context,
        targetItems,
        const _BulkDiscountResult(mode: _DiscountMode.none, value: null),
        clearSelection: action.target == _MenuSettingsTarget.selected,
      );
    } else {
      await _applyDiscountToItems(
        context,
        targetItems,
        clearSelection: action.target == _MenuSettingsTarget.selected,
      );
    }
  }

  Future<void> _openDeliveryChargeEditor(BuildContext context) =>
      showMenuDeliveryChargeEditor(context);

  Future<void> _applyDiscountToItems(
    BuildContext context,
    List<MenuItem> items, {
    required bool clearSelection,
  }) async {
    final result = await showModalBottomSheet<_BulkDiscountResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BulkDiscountSheet(),
    );
    if (result == null) return;
    if (!context.mounted) return;
    await _applyDiscountResultToItems(
      context,
      items,
      result,
      clearSelection: clearSelection,
    );
  }

  Future<void> _applyDiscountResultToItems(
    BuildContext context,
    List<MenuItem> items,
    _BulkDiscountResult result, {
    required bool clearSelection,
  }) async {
    await _applyMenuDiscountResult(AppScope.read(context), items, result);
    if (mounted && clearSelection) setState(_selectedItemIds.clear);
  }



  Future<void> _openMenuForm(BuildContext context, {MenuItem? item}) async {
    final app = AppScope.read(context);
    final text = app.strings;
    final result = await showModalBottomSheet<_MenuFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: PosColors.background,
      builder: (context) =>
          _MenuItemForm(initialItem: item, existingCategories: app.categories),
    );
    if (result == null) return;
    if (result.deleteRequested) {
      if (item != null && context.mounted) {
        await _confirmDelete(context, item);
      }
      return;
    }
    await app.saveMenuItem(
      id: item?.id,
      name: result.name!,
      nameEn: result.name!,
      nameBn: item?.nameBn,
      description: result.description!,
      descriptionEn: result.description!,
      descriptionBn: item?.descriptionBn,
      category: result.category!,
      categoryEn: result.category!,
      categoryBn: item?.categoryBn,
      price: result.price!,
      shortCode: result.shortCode ?? item?.shortCode,
      imageUrl: result.imageUrl,
      isAvailable: result.isAvailable!,
      preparationTimeMinutes: result.preparationTimeMinutes,
      tags: result.tags!,
      createdAt: item?.createdAt,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TfText(
          item == null ? text.menuItemAdded : text.menuItemUpdated,
        ),
      ),
    );
  }

  Future<void> _addImageToItem(BuildContext context, MenuItem item) async {
    final app = AppScope.read(context);
    final text = app.strings;
    try {
      final picked = await _scanImageService.pickRawMenuImageBytes();
      if (picked == null || !context.mounted) return;
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SquareImageCropperPage(imageBytes: picked.bytes),
        ),
      );
      if (cropped == null || !context.mounted) return;
      final dataUrl = _scanImageService.encodeMenuPhotoDataUrl(cropped);
      var imageUrl = dataUrl;
      var uploadWarning = false;
      try {
        imageUrl = await app.uploadMenuImageDataUrl(dataUrl);
      } catch (_) {
        uploadWarning = true;
      }
      await app.saveMenuItem(
        id: item.id,
        name: item.name,
        nameEn: item.nameEn,
        nameBn: item.nameBn,
        description: item.description,
        descriptionEn: item.descriptionEn,
        descriptionBn: item.descriptionBn,
        category: item.category,
        categoryEn: item.categoryEn,
        categoryBn: item.categoryBn,
        price: item.price,
        imageUrl: imageUrl,
        isAvailable: item.isAvailable,
        preparationTimeMinutes: item.preparationTimeMinutes,
        tags: item.tags,
        createdAt: item.createdAt,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(
            uploadWarning
                ? text.menuImageUploadWarning
                : text.menuImageUploaded,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(
            error is MenuImageException ? text.menuPhotoTooLarge : '$error',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context, MenuItem item) async {
    final app = AppScope.read(context);
    final text = app.strings;
    TfConfirmSheet.show(
      context,
      title: text.menuDeleteTitle,
      description: text.menuDeleteDescription(item.localizedName(app.language)),
      confirmLabel: text.deleteAction,
      isDanger: true,
      onConfirm: () async {
        await app.deleteMenuItem(item.id);
        if (!context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: TfText(text.menuDeleted)));
      },
    );
  }
}

/// Opens the delivery-charge editor sheet and persists the result. Reusable from
/// both the Menu screen and the nav drawer's collapsible Menu group.
Future<void> showMenuDeliveryChargeEditor(BuildContext context) async {
  final app = AppScope.read(context);
  final text = app.strings;
  final value = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _DeliveryChargeSheet(initialValue: app.serverConfig.deliveryCharge),
  );
  if (value == null || !context.mounted) return;
  await app.updateDeliveryCharge(value);
  if (!context.mounted) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: TfText(text.menuDeliveryChargeSaved)));
}

/// Opens the bulk-discount sheet and applies the chosen discount to *every* menu
/// item. Reusable from the nav drawer's Menu group, where there is no in-screen
/// selection to scope to.
Future<void> showMenuDiscountsSheet(BuildContext context) async {
  final app = AppScope.read(context);
  final items = app.menuItems;
  if (items.isEmpty) return;
  final result = await showModalBottomSheet<_BulkDiscountResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _BulkDiscountSheet(),
  );
  if (result == null || !context.mounted) return;
  await _applyMenuDiscountResult(app, items, result);
}

/// Shared per-item discount writer used by both the Menu screen and the top-level
/// [showMenuDiscountsSheet]. Writes each item's discount tags then syncs once.
Future<void> _applyMenuDiscountResult(
  PosAppController app,
  List<MenuItem> items,
  _BulkDiscountResult result,
) async {
  for (final item in items) {
    final extras = item.extras.copyWith(
      discountPercent: result.mode == _DiscountMode.percent
          ? result.value
          : null,
      discountFlat: result.mode == _DiscountMode.flat ? result.value : null,
      clearDiscount: result.mode == _DiscountMode.none,
    );
    await app.saveMenuItem(
      id: item.id,
      name: item.name,
      nameEn: item.nameEn,
      nameBn: item.nameBn,
      description: item.description,
      descriptionEn: item.descriptionEn,
      descriptionBn: item.descriptionBn,
      category: item.category,
      categoryEn: item.categoryEn,
      categoryBn: item.categoryBn,
      price: item.price,
      imageUrl: item.imageUrl,
      isAvailable: item.isAvailable,
      preparationTimeMinutes: item.preparationTimeMinutes,
      tags: extras.toTags(),
      createdAt: item.createdAt,
      syncAfterSave: false,
    );
  }
  await app.syncNow();
}

class _DesktopBulkToolbar extends StatelessWidget {
  const _DesktopBulkToolbar({
    required this.count,
    required this.onDiscount,
    required this.onDelete,
    required this.onClear,
    required this.isBn,
  });

  final int count;
  final VoidCallback onDiscount;
  final VoidCallback onDelete;
  final VoidCallback onClear;
  final bool isBn;

  @override
  Widget build(BuildContext context) {
    return PcCard(
      pad: 10,
      child: Row(
        children: [
          Expanded(
            child: Text(
              isBn ? '$count আইটেম নির্বাচিত' : '$count items selected',
              style: const TextStyle(
                color: Pc.text,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          PcBtn(
            label: isBn ? 'ডিসকাউন্ট' : 'Discount',
            icon: 'menu',
            size: PcSize.sm,
            variant: PcVariant.surface,
            onTap: onDiscount,
          ),
          const SizedBox(width: PosSpacing.sp2),
          PcBtn(
            label: isBn ? 'মুছুন' : 'Delete',
            icon: 'close',
            size: PcSize.sm,
            variant: PcVariant.danger,
            onTap: onDelete,
          ),
          const SizedBox(width: PosSpacing.sp2),
          PcBtn(
            label: isBn ? 'ক্লিয়ার' : 'Clear',
            icon: 'close',
            size: PcSize.sm,
            variant: PcVariant.ghost,
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

class _DesktopEmptyMenu extends StatelessWidget {
  const _DesktopEmptyMenu({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PcCard(
      pad: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.restaurant_menu_outlined,
            color: Pc.textTer,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: Pc.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(message, style: const TextStyle(color: Pc.textSec)),
        ],
      ),
    );
  }
}

class _DesktopMenuGrid extends StatelessWidget {
  const _DesktopMenuGrid({
    required this.items,
    required this.language,
    required this.selectedIds,
    required this.selectionMode,
    required this.canEdit,
    required this.onEdit,
    required this.onSelect,
    required this.onDelete,
    required this.onAvailabilityChanged,
    required this.onAddImage,
  });

  final List<MenuItem> items;
  final AppLanguage language;
  final Set<String> selectedIds;
  final bool selectionMode;
  final bool canEdit;
  final ValueChanged<MenuItem> onEdit;
  final ValueChanged<MenuItem> onSelect;
  final ValueChanged<MenuItem> onDelete;
  final void Function(MenuItem item, bool value) onAvailabilityChanged;
  final ValueChanged<MenuItem> onAddImage;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 265,
        mainAxisExtent: 190,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _DesktopMenuCard(
          item: item,
          language: language,
          selected: selectedIds.contains(item.id),
          selectionMode: selectionMode,
          canEdit: canEdit,
          onEdit: () => selectionMode ? onSelect(item) : onEdit(item),
          onSelect: () => onSelect(item),
          onDelete: () => onDelete(item),
          onAvailabilityChanged: (value) => onAvailabilityChanged(item, value),
          onAddImage: () => onAddImage(item),
        );
      },
    );
  }
}

class _DesktopMenuCard extends StatelessWidget {
  const _DesktopMenuCard({
    required this.item,
    required this.language,
    required this.selected,
    required this.selectionMode,
    required this.canEdit,
    required this.onEdit,
    required this.onSelect,
    required this.onDelete,
    required this.onAvailabilityChanged,
    required this.onAddImage,
  });

  final MenuItem item;
  final AppLanguage language;
  final bool selected;
  final bool selectionMode;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAvailabilityChanged;
  final VoidCallback onAddImage;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final extras = item.extras;
    final hasImage = (item.imageUrl ?? '').trim().isNotEmpty;
    final iconKey = resolveMenuIconKey(
      iconKey: extras.iconKey,
      name: item.name,
      category: item.category,
    );
    final discounted = extras.discountedPrice(item.price);
    final showDiscount = extras.hasDiscount && discounted < item.price;
    final priceDecimals = item.price == item.price.roundToDouble() ? 0 : 2;
    final category = item.localizedCategory(language);
    final metaBadges = <String>[
      if (extras.addOns.isNotEmpty) text.isBn ? 'অ্যাড-অন' : 'Add-ons',
      if (extras.includes.isNotEmpty) text.isBn ? 'কম্বো' : 'Combo',
      if (showDiscount) extras.discountBadgeLabel(),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: canEdit ? onEdit : null,
        onLongPress: canEdit ? onSelect : null,
        borderRadius: BorderRadius.circular(Pc.rMd),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected ? Pc.accentWash : Pc.surface,
            border: Border.all(color: selected ? Pc.accent : Pc.border),
            borderRadius: BorderRadius.circular(Pc.rMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                height: 64,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GestureDetector(
                      onTap: canEdit ? onAddImage : null,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(PosRadii.tile),
                        child: SizedBox(
                          width: 58,
                          height: 58,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MenuImageView(
                                imageUrl: item.imageUrl,
                                iconKey: iconKey,
                              ),
                              if (!hasImage && canEdit)
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Pc.surface,
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(color: Pc.border),
                                    ),
                                    child: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 12,
                                      color: Pc.text,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (canEdit)
                      Positioned(
                        top: -7,
                        right: -8,
                        child: TfToggle(
                          value: item.isAvailable,
                          onChanged: onAvailabilityChanged,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: PosSpacing.sp2),
              Text(
                item.localizedName(language),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Pc.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                category.trim().isEmpty ? 'General' : category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Pc.textTer),
              ),
              const Spacer(),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final badge in metaBadges.take(3))
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            showDiscount && badge == extras.discountBadgeLabel()
                            ? Pc.dangerSoft
                            : Pc.surfaceAlt,
                        borderRadius: BorderRadius.circular(PosRadii.tag),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color:
                              showDiscount &&
                                  badge == extras.discountBadgeLabel()
                              ? Pc.danger
                              : Pc.textTer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: PosSpacing.sp2),
              Row(
                children: [
                  if (showDiscount) ...[
                    Text(
                      tfFormatCurrency(
                        context,
                        item.price,
                        decimalDigits: priceDecimals,
                      ),
                      style: const TextStyle(
                        color: Pc.textTer,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    tfFormatCurrency(
                      context,
                      showDiscount ? discounted : item.price,
                      decimalDigits: priceDecimals,
                    ),
                    style: Pc.num(
                      14,
                      color: showDiscount ? Pc.danger : Pc.text,
                    ),
                  ),
                  const Spacer(),
                  if (canEdit) ...[
                    _desktopIconAction(Icons.edit_outlined, onEdit),
                    _desktopIconAction(
                      Icons.photo_library_outlined,
                      onAddImage,
                    ),
                    _desktopIconAction(Icons.delete_outline, onDelete),
                  ] else
                    PcPill(
                      label: item.isAvailable
                          ? (text.isBn ? 'চালু' : 'Available')
                          : (text.isBn ? 'বন্ধ' : 'Paused'),
                      tone: item.isAvailable ? PcTone.good : PcTone.warn,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopIconAction(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: Pc.textTer, size: 16),
      ),
    );
  }
}

enum _MenuSettingsTarget { selected, all }

class _MenuSettingsAction {
  const _MenuSettingsAction({required this.target, required this.clearOnly})
    : editDeliveryCharge = false;

  const _MenuSettingsAction.deliveryCharge()
    : target = null,
      clearOnly = false,
      editDeliveryCharge = true;

  final _MenuSettingsTarget? target;
  final bool clearOnly;
  final bool editDeliveryCharge;
}

class _MenuSettingsSheet extends StatelessWidget {
  const _MenuSettingsSheet({
    required this.allCount,
    required this.selectedCount,
    required this.deliveryCharge,
  });

  final int allCount;
  final int selectedCount;
  final double deliveryCharge;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final hasSelected = selectedCount > 0;
    void close(_MenuSettingsTarget target, bool clearOnly) {
      Navigator.of(
        context,
      ).pop(_MenuSettingsAction(target: target, clearOnly: clearOnly));
    }

    return Container(
      decoration: const BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PosRadii.card),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TfText(
                text.isBn ? 'মেনু সেটিংস' : 'Menu settings',
                style: TfTextStyles.appBarTitle.copyWith(
                  fontFamily: tfFontFamily(context),
                  color: PosColors.slate,
                ),
              ),
              const SizedBox(height: 6),
              TfText(
                text.isBn
                    ? 'ডেলিভারি চার্জ এবং মেনু ডিসকাউন্ট পরিচালনা করুন।'
                    : 'Manage delivery pricing and menu discounts.',
                style: TfTextStyles.sectionStrip.copyWith(
                  fontWeight: FontWeight.w400,
                  color: PosColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              TfCard(
                padding: EdgeInsets.zero,
                child: InkWell(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const _MenuSettingsAction.deliveryCharge()),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.delivery_dining_outlined,
                          size: 20,
                          color: PosColors.muted,
                        ),
                        const SizedBox(width: PosSpacing.sp3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TfText(
                                text.menuDeliveryCharge,
                                style: TfTextStyles.sectionHeader.copyWith(
                                  color: PosColors.slate,
                                ),
                              ),
                              const SizedBox(height: 3),
                              TfText(
                                text.menuDeliveryChargeSubtitle,
                                style: TfTextStyles.sectionStrip.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: PosColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        TfMoney(
                          deliveryCharge,
                          style: TfTextStyles.price.copyWith(
                            color: PosColors.slate,
                          ),
                        ),
                        const SizedBox(width: PosSpacing.sp1),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: PosColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TfSectionHeader(
                label: text.isBn ? 'মেনু ডিসকাউন্ট' : 'Menu discounts',
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  TfButton(
                    label: text.isBn
                        ? 'নির্বাচিত আইটেমে ডিসকাউন্ট'
                        : 'Discount selected',
                    icon: Icons.local_offer_outlined,
                    onPressed: hasSelected
                        ? () => close(_MenuSettingsTarget.selected, false)
                        : null,
                    fullWidth: false,
                  ),
                  TfButton(
                    label: text.isBn ? 'সব আইটেমে ডিসকাউন্ট' : 'Discount all',
                    icon: Icons.sell_outlined,
                    onPressed: allCount > 0
                        ? () => close(_MenuSettingsTarget.all, false)
                        : null,
                    fullWidth: false,
                  ),
                  TfButton(
                    label: text.isBn
                        ? 'নির্বাচিত ডিসকাউন্ট মুছুন'
                        : 'Clear selected',
                    icon: Icons.clear_all_rounded,
                    onPressed: hasSelected
                        ? () => close(_MenuSettingsTarget.selected, true)
                        : null,
                    variant: TfButtonVariant.paper,
                    fullWidth: false,
                  ),
                  TfButton(
                    label: text.isBn ? 'সব ডিসকাউন্ট মুছুন' : 'Clear all',
                    icon: Icons.layers_clear_rounded,
                    onPressed: allCount > 0
                        ? () => close(_MenuSettingsTarget.all, true)
                        : null,
                    variant: TfButtonVariant.paper,
                    fullWidth: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PosColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PosRadii.card),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TfText(
                  text.menuDeliveryCharge,
                  style: TfTextStyles.appBarTitle.copyWith(
                    color: PosColors.slate,
                  ),
                ),
                const SizedBox(height: 6),
                TfText(
                  text.menuDeliveryChargeSubtitle,
                  style: TfTextStyles.sectionStrip.copyWith(
                    fontWeight: FontWeight.w400,
                    color: PosColors.muted,
                  ),
                ),
                const SizedBox(height: 16),
                TfField(
                  label: text.menuDeliveryCharge,
                  controller: _controller,
                  hint: text.menuDeliveryChargeHint,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  errorText: _error,
                  prefix: const Icon(
                    Icons.currency_exchange_rounded,
                    color: PosColors.muted,
                  ),
                ),
                TfButton(
                  label: text.isBn ? 'সেভ করুন' : 'Save charge',
                  icon: TfNavIcon.check,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value < 0 || value > 100000) {
      setState(
        () => _error = AppScope.of(context).strings.menuDeliveryChargeInvalid,
      );
      return;
    }
    Navigator.of(context).pop(value);
  }
}

class _BulkMenuToolbar extends StatelessWidget {
  const _BulkMenuToolbar({
    required this.count,
    required this.onDiscount,
    required this.onDelete,
    required this.onClear,
  });

  final int count;
  final VoidCallback onDiscount;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return TfCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TfText(
              text.isBn
                  ? '${tfToBnNumbers('$count')} আইটেম নির্বাচিত'
                  : '$count items selected',
              style: TfTextStyles.rowTitle.copyWith(color: PosColors.slate),
            ),
          ),
          TfButton(
            label: text.isBn ? 'ডিসকাউন্ট' : 'Discount',
            icon: Icons.local_offer_outlined,
            fullWidth: false,
            size: TfButtonSize.sm,
            onPressed: onDiscount,
          ),
          const SizedBox(width: PosSpacing.sp2),
          TfButton(
            label: text.deleteAction,
            icon: Icons.delete_outline,
            fullWidth: false,
            size: TfButtonSize.sm,
            variant: TfButtonVariant.paper,
            onPressed: onDelete,
          ),
          const SizedBox(width: PosSpacing.sp2),
          TfIconButton(
            icon: Icons.close_rounded,
            tooltip: text.isBn ? 'বন্ধ' : 'Clear',
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}

class _BulkDiscountResult {
  const _BulkDiscountResult({required this.mode, required this.value});

  final _DiscountMode mode;
  final double? value;
}

class _BulkDiscountSheet extends StatefulWidget {
  const _BulkDiscountSheet();

  @override
  State<_BulkDiscountSheet> createState() => _BulkDiscountSheetState();
}

class _BulkDiscountSheetState extends State<_BulkDiscountSheet> {
  final _valueCtrl = TextEditingController();
  _DiscountMode _mode = _DiscountMode.percent;

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PosColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PosRadii.card),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            children: [
              TfText(
                text.isBn ? 'একসাথে ডিসকাউন্ট' : 'Bulk discount',
                style: TfTextStyles.appBarTitle.copyWith(
                  fontFamily: tfFontFamily(context),
                  color: PosColors.slate,
                ),
              ),
              const SizedBox(height: 14),
              SegmentedButton<_DiscountMode>(
                segments: [
                  ButtonSegment(
                    value: _DiscountMode.percent,
                    label: TfText(text.isBn ? 'শতাংশ' : 'Percent'),
                  ),
                  ButtonSegment(
                    value: _DiscountMode.flat,
                    label: TfText(text.isBn ? 'টাকা' : 'Flat'),
                  ),
                  ButtonSegment(
                    value: _DiscountMode.none,
                    label: TfText(text.isBn ? 'মুছুন' : 'Clear'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (values) => setState(() {
                  _mode = values.first;
                  if (_mode == _DiscountMode.none) _valueCtrl.clear();
                }),
              ),
              const SizedBox(height: 16),
              if (_mode != _DiscountMode.none)
                TfField(
                  label: _mode == _DiscountMode.percent
                      ? 'Discount percent'
                      : 'Discount amount',
                  labelBn: _mode == _DiscountMode.percent
                      ? 'ডিসকাউন্ট শতাংশ'
                      : 'ডিসকাউন্ট টাকা',
                  controller: _valueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              TfButton(
                label: text.isBn ? 'প্রয়োগ করুন' : 'Apply',
                icon: TfNavIcon.check,
                onPressed: () {
                  final value = double.tryParse(_valueCtrl.text.trim());
                  if (_mode != _DiscountMode.none &&
                      (value == null || value <= 0)) {
                    return;
                  }
                  Navigator.of(
                    context,
                  ).pop(_BulkDiscountResult(mode: _mode, value: value));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petpooja "Management"-style item table: a column header (Status · Name ·
/// Mark as) over flat rows of [status dot · name · ON/OFF
/// toggle]. A selection-mode header adds the select-all checkbox.
/// Long-press a row to multi-select; the bulk toolbar appears.
class _MenuList extends StatelessWidget {
  const _MenuList({
    required this.items,
    required this.language,
    required this.selectedIds,
    required this.onEdit,
    required this.onSelect,
    required this.onSelectAll,
    required this.onAvailabilityChanged,
  });

  final List<MenuItem> items;
  final AppLanguage language;
  final Set<String> selectedIds;
  final ValueChanged<MenuItem> onEdit;
  final ValueChanged<MenuItem> onSelect;
  final ValueChanged<bool> onSelectAll;
  final void Function(MenuItem item, bool value) onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final selectionMode = selectedIds.isNotEmpty;
    final allSelected =
        items.isNotEmpty && items.every((i) => selectedIds.contains(i.id));
    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.lg),
        border: Border.all(color: PosColors.line),
        boxShadow: PosShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuListHeader(
            selectionMode: selectionMode,
            allSelected: allSelected,
            onToggleAll: () => onSelectAll(!allSelected),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: PosColors.line),
            _MenuManageRow(
              item: items[i],
              language: language,
              selectionMode: selectionMode,
              selected: selectedIds.contains(items[i].id),
              onToggleSelect: () => onSelect(items[i]),
              onEdit: () => onEdit(items[i]),
              onAvailabilityChanged: (value) =>
                  onAvailabilityChanged(items[i], value),
            ),
          ],
        ],
      ),
    );
  }
}

/// Column header row for [_MenuList] — select-all checkbox (only in selection
/// mode) + Name / Mark as labels. Fixed column widths keep it aligned with
/// [_MenuManageRow].
class _MenuListHeader extends StatelessWidget {
  const _MenuListHeader({
    required this.selectionMode,
    required this.allSelected,
    required this.onToggleAll,
  });

  final bool selectionMode;
  final bool allSelected;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final style = TfTextStyles.eyebrow.copyWith(color: PosColors.muted);
    return Container(
      color: PosColors.surfaceSunk,
      padding: const EdgeInsets.fromLTRB(PosSpacing.sp2, PosSpacing.sp1p5, PosSpacing.sp3, PosSpacing.sp1p5),
      child: Row(
        children: [
          if (selectionMode) ...[
            SizedBox(
              width: _kMenuColCheckbox,
              child: _MenuCheckbox(
                value: allSelected,
                onChanged: (_) => onToggleAll(),
              ),
            ),
            const SizedBox(width: PosSpacing.sp1),
          ],
          SizedBox(
            width: _kMenuColMarkAs,
            child: Center(
              child: Text(text.menuAvailable.toUpperCase(), style: style),
            ),
          ),
          const SizedBox(width: PosSpacing.sp2),
          Expanded(child: Text(text.menuColName.toUpperCase(), style: style)),
          const SizedBox(width: PosSpacing.sp2),
          SizedBox(
            width: _kMenuColPrice,
            child: Center(
              child: Text(text.menuPrice.toUpperCase(), style: style),
            ),
          ),
        ],
      ),
    );
  }
}

/// One menu item rendered as a flat row: checkbox (only in selection mode) ·
/// name · ON/OFF "Mark as" toggle. Tap to edit; long-press or tap-in-selection
/// to multi-select. When selection is active the bulk toolbar appears above.
class _MenuManageRow extends StatelessWidget {
  const _MenuManageRow({
    required this.item,
    required this.language,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onAvailabilityChanged,
  });

  final MenuItem item;
  final AppLanguage language;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final available = item.isAvailable;
    return Material(
      // primarySoft = multi-select state; the left accent bar makes the wash
      // read as selection, not decoration (v4 §5.4).
      color: selected ? PosColors.primarySoft : PosColors.surface,
      child: InkWell(
        onTap: selectionMode ? onToggleSelect : onEdit,
        onLongPress: onToggleSelect,
        child: Container(
          constraints: const BoxConstraints(minHeight: PosDensity.rowMin),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.fromLTRB(PosSpacing.sp2, PosSpacing.sp1p5, PosSpacing.sp3, PosSpacing.sp1p5),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? PosColors.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              if (selectionMode) ...[
                SizedBox(
                  width: _kMenuColCheckbox,
                  child: _MenuCheckbox(
                    value: selected,
                    onChanged: (_) => onToggleSelect(),
                  ),
                ),
                const SizedBox(width: PosSpacing.sp1),
              ],
              SizedBox(
                width: _kMenuColMarkAs,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _MarkAsToggle(
                    value: available,
                    onChanged: onAvailabilityChanged,
                  ),
                ),
              ),
              const SizedBox(width: PosSpacing.sp2),
              Expanded(
                child: TfText(
                  item.localizedName(language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TfTextStyles.rowTitle.copyWith(
                    color: PosColors.text,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: PosSpacing.sp2),
              SizedBox(
                width: _kMenuColPrice,
                child: Center(
                  child: TfText(
                    tfFormatCurrency(context, item.price),
                    style: TfTextStyles.rowMoney.copyWith(
                      color: PosColors.text,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const double _kMenuColCheckbox = 36;
const double _kMenuColPrice = 80;
const double _kMenuColMarkAs = 72;

/// Compact square checkbox used in the menu management table.
class _MenuCheckbox extends StatelessWidget {
  const _MenuCheckbox({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Checkbox(
      value: value,
      onChanged: onChanged,
      activeColor: PosColors.primary,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Petpooja-style labeled ON/OFF "Mark as" switch (availability). Green track +
/// "ON" when available, neutral track + "OFF" when paused — green=success token,
/// never red (paused is not destructive).
class _MarkAsToggle extends StatelessWidget {
  const _MarkAsToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final on = value;
    final label = Text(
      on ? text.menuMarkOn : text.menuMarkOff,
      style: TfTextStyles.label.copyWith(
        fontWeight: FontWeight.w700,
        color: on ? Colors.white : PosColors.muted,
      ),
    );
    const knob = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: PosShadows.e1,
      ),
      child: SizedBox(width: 16, height: 16),
    );
    return Semantics(
      label: text.menuColMarkAs,
      toggled: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(!on),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 56,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            color: on ? PosColors.primary : PosColors.surfaceSunk,
            borderRadius: BorderRadius.circular(PosRadii.pill),
            border: Border.all(color: on ? Colors.transparent : PosColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: on ? [label, knob] : [knob, label],
          ),
        ),
      ),
    );
  }
}

class _MenuItemForm extends StatefulWidget {
  const _MenuItemForm({this.initialItem, required this.existingCategories});

  final MenuItem? initialItem;
  final List<String> existingCategories;

  @override
  State<_MenuItemForm> createState() => _MenuItemFormState();
}

class _MenuItemFormState extends State<_MenuItemForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _shortCodeController;
  late final TextEditingController _imageController;
  late final TextEditingController _prepController;
  final MenuImageService _imageService = MenuImageService();
  late bool _isAvailable;
  late MenuItemExtras _initialExtras;
  bool _imageBusy = false;
  final List<_OptionRow> _options = [];
  final List<_IncludeRow> _includes = [];
  final List<_AddOnRow> _addOns = [];

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(
      text: item?.description ?? '',
    );
    _categoryController = TextEditingController(text: item?.category ?? '');
    _priceController = TextEditingController(
      text: item == null ? '' : item.price.toStringAsFixed(2),
    );
    _shortCodeController = TextEditingController(
      text: item?.shortCode?.toString() ?? '',
    );
    _imageController = TextEditingController(text: item?.imageUrl ?? '');
    _prepController = TextEditingController(
      text: item?.preparationTimeMinutes?.toString() ?? '',
    );
    _isAvailable = item?.isAvailable ?? true;
    _initialExtras = item == null ? const MenuItemExtras() : item.extras;
    _options.addAll(
      _initialExtras.options.map(
        (o) => _OptionRow(
          name: o.name,
          priceDelta: o.priceDelta,
          basePrice: item?.price ?? 0,
        ),
      ),
    );
    _includes.addAll(
      _initialExtras.includes.map((i) => _IncludeRow(i)),
    );
    _addOns.addAll(
      _initialExtras.addOns.map((a) => _AddOnRow(name: a.name, price: a.price)),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _shortCodeController.dispose();
    _imageController.dispose();
    _prepController.dispose();
    for (final o in _options) { o.dispose(); }
    for (final i in _includes) { i.dispose(); }
    for (final a in _addOns) { a.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final placeholderIconKey = _placeholderIconKey();
    final inputTheme = theme.inputDecorationTheme.copyWith(
      fillColor: PosColors.surface,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PosRadii.md),
        borderSide: BorderSide(color: PosColors.lineStrong),
      ),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: inputTheme,
        chipTheme: theme.chipTheme.copyWith(
          backgroundColor: PosColors.surface,
          selectedColor: PosColors.primarySoft,
        ),
      ),
      child: Material(
        color: PosColors.surface,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.92,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(PosSpacing.sp4, PosSpacing.sp3, PosSpacing.sp4, PosSpacing.sp5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TfText(
                                  widget.initialItem == null
                                      ? text.menuNewItemTitle
                                      : text.menuEditItemTitle,
                                  style: TfTextStyles.screenTitle,
                                ),
                              ),
                              if (widget.initialItem != null)
                                IconButton(
                                  tooltip: text.deleteAction,
                                  onPressed: () => Navigator.pop(
                                    context,
                                    _MenuFormResult.delete(),
                                  ),
                                  color: PosColors.danger,
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              IconButton(
                                tooltip: MaterialLocalizations.of(
                                  context,
                                ).closeButtonTooltip,
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: PosSpacing.sp3),
                          _EditorPhotoBlock(
                            busy: _imageBusy,
                            imageUrl: _imageController.text.trim(),
                            iconKey: placeholderIconKey,
                            addLabel: text.menuAddPhoto,
                            clearLabel: text.menuClearImage,
                            onPick: _pickImage,
                            onClear: () {
                              _imageController.clear();
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: PosSpacing.sp5),
                          _EditorField(
                            label: text.menuItemName,
                            child: TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: text.isBn
                                    ? 'যেমন চিকেন বিরিয়ানি'
                                    : 'e.g. Chicken Biryani',
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return text.menuItemNameRequired;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: PosSpacing.sp4),
                          _EditorField(
                            label: text.menuPrice,
                            child: TextFormField(
                              controller: _priceController,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(
                                  Icons.currency_exchange_rounded,
                                  size: 18,
                                ),
                                hintText: '0',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              validator: (value) {
                                final price = double.tryParse(value ?? '');
                                if (price == null || price <= 0) {
                                  return text.menuPriceInvalid;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: PosSpacing.sp4),
                          _EditorField(
                            label: text.shortCodeLabel,
                            child: TextFormField(
                              controller: _shortCodeController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(
                                  Icons.bolt_rounded,
                                  size: 18,
                                ),
                                hintText: text.shortCodeAutoHint,
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                            ),
                          ),
                          const SizedBox(height: PosSpacing.sp4),
                          _EditorField(
                            label: text.menuCategory,
                            child: _buildCategoryField(text),
                          ),
                          const SizedBox(height: PosSpacing.sp4),
                          _AdvancedMenuOptions(
                            text: text,
                            descriptionController: _descriptionController,
                            prepController: _prepController,
                            options: _options,
                            includes: _includes,
                            addOns: _addOns,
                            onAddOption: () =>
                                setState(() => _options.add(_OptionRow())),
                            onRemoveOption: (i) =>
                                setState(() => _options.removeAt(i).dispose()),
                            onAddInclude: () =>
                                setState(() => _includes.add(_IncludeRow(''))),
                            onRemoveInclude: (i) =>
                                setState(() => _includes.removeAt(i).dispose()),
                            onAddAddOn: () =>
                                setState(() => _addOns.add(_AddOnRow())),
                            onRemoveAddOn: (i) =>
                                setState(() => _addOns.removeAt(i).dispose()),
                            initiallyExpanded:
                                _descriptionController.text.trim().isNotEmpty ||
                                _prepController.text.trim().isNotEmpty ||
                                _initialExtras.options.isNotEmpty ||
                                _initialExtras.includes.isNotEmpty ||
                                _initialExtras.addOns.isNotEmpty,
                          ),
                        ],
                      ),
                    ),
                  ),
                  TfStickyCTA(
                    child: TfButton(
                      onPressed: _submit,
                      icon: Icons.check_rounded,
                      label: widget.initialItem == null
                          ? text.menuCreateItem
                          : text.menuSaveItem,
                      size: TfButtonSize.lg,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryField(AppStrings text) {
    final existing = widget.existingCategories;
    if (existing.isEmpty) {
      return TextFormField(
        controller: _categoryController,
        decoration: InputDecoration(labelText: text.menuCategory),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return text.menuCategoryRequired;
          }
          return null;
        },
      );
    }

    return Autocomplete<String>(
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return existing;
        return existing.where((c) => c.toLowerCase().contains(query));
      },
      onSelected: (selection) {
        setState(() => _categoryController.text = selection);
      },
      fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
        if (fieldController.text.isEmpty &&
            _categoryController.text.isNotEmpty) {
          fieldController.text = _categoryController.text;
        }
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          onChanged: (value) =>
              setState(() => _categoryController.text = value),
          decoration: InputDecoration(
            labelText: text.menuCategory,
            hintText: text.menuCategoryHint,
          ),
          validator: (value) {
            final resolved = (value ?? '').trim().isNotEmpty
                ? value!
                : _categoryController.text;
            if (resolved.trim().isEmpty) {
              return text.menuCategoryRequired;
            }
            return null;
          },
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final app = AppScope.of(context);
    final text = app.strings;
    setState(() => _imageBusy = true);
    try {
      final picked = await _imageService.pickRawMenuImageBytes();
      if (picked == null) return;
      if (!mounted) return;
      // After picking, force a 1:1 crop so customer-facing thumbnails stay
      // visually consistent. Cancelling the cropper aborts the upload.
      final cropped = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SquareImageCropperPage(imageBytes: picked.bytes),
        ),
      );
      if (cropped == null) return;
      final dataUrl = _imageService.encodeMenuPhotoDataUrl(cropped);
      var imageUrl = dataUrl;
      var uploadWarning = false;
      try {
        imageUrl = await app.uploadMenuImageDataUrl(dataUrl);
      } catch (_) {
        uploadWarning = true;
      }
      _imageController.text = imageUrl;
      if (mounted) setState(() {});
      if (!mounted) return;
      final uploaded = !imageUrl.startsWith('data:image/');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(
            uploadWarning
                ? text.menuImageUploadWarning
                : uploaded
                ? text.menuImageUploaded
                : text.menuImageSavedLocal,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(
            error is MenuImageException ? text.menuPhotoTooLarge : '$error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _imageBusy = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final extras = _buildExtras();
    Navigator.pop(
      context,
      _MenuFormResult(
        name: _nameController.text,
        description: _descriptionController.text,
        category: _categoryController.text,
        price: double.parse(_priceController.text),
        shortCode: int.tryParse(_shortCodeController.text.trim()),
        imageUrl: _imageController.text,
        isAvailable: _isAvailable,
        preparationTimeMinutes: int.tryParse(_prepController.text),
        tags: extras.toTags(),
      ),
    );
  }

  MenuItemExtras _buildExtras() {
    final includes = _includes
        .map((r) => r.nameCtrl.text.trim())
        .where((n) => n.isNotEmpty)
        .toList(growable: false);
    final basePrice = double.tryParse(_priceController.text.trim()) ?? 0;
    final options = _options
        .map((r) {
          final name = r.nameCtrl.text.trim();
          final total = double.tryParse(r.priceCtrl.text.trim());
          final priceDelta = total == null ? 0.0 : total - basePrice;
          return MenuOption(name: name, priceDelta: priceDelta);
        })
        .where((o) => o.name.isNotEmpty)
        .toList(growable: false);
    final addOns = _addOns
        .map((r) {
          final name = r.nameCtrl.text.trim();
          final price = double.tryParse(r.priceCtrl.text.trim()) ?? 0;
          return MenuAddOn(name: name, price: price);
        })
        .where((a) => a.name.isNotEmpty)
        .toList(growable: false);
    return _initialExtras.copyWith(
      iconKey: _imageController.text.trim().isEmpty
          ? _placeholderIconKey()
          : _initialExtras.iconKey,
      clearDiscount: true,
      discountPercent: null,
      discountFlat: null,
      includes: includes,
      options: options,
      addOns: addOns,
    );
  }

  String _placeholderIconKey() {
    final existing = _initialExtras.iconKey?.trim();
    if (existing != null && existing.isNotEmpty) return existing;
    return inferMenuIconKey(
      name: _nameController.text,
      category: _categoryController.text,
    );
  }
}

enum _DiscountMode { none, percent, flat }

class _EditorField extends StatelessWidget {
  const _EditorField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfMicroLabel(label.toUpperCase()),
        const SizedBox(height: PosSpacing.sp2),
        child,
      ],
    );
  }
}

class _EditorPhotoBlock extends StatelessWidget {
  const _EditorPhotoBlock({
    required this.busy,
    required this.imageUrl,
    required this.iconKey,
    required this.addLabel,
    required this.clearLabel,
    required this.onPick,
    required this.onClear,
  });

  final bool busy;
  final String imageUrl;
  final String iconKey;
  final String addLabel;
  final String clearLabel;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(PosRadii.lg),
          child: Container(
            width: PosDensity.editorPhoto,
            height: PosDensity.editorPhoto,
            decoration: BoxDecoration(
              color: PosColors.surfaceSunk,
              borderRadius: BorderRadius.circular(PosRadii.lg),
              border: Border.all(color: PosColors.lineStrong),
            ),
            child: MenuImageView(
              imageUrl: hasImage ? imageUrl : null,
              iconKey: iconKey,
            ),
          ),
        ),
        const SizedBox(width: PosSpacing.sp3),
        Expanded(
          child: SizedBox(
            height: PosDensity.editorPhoto,
            child: OutlinedButton(
              onPressed: busy ? null : onPick,
              style: OutlinedButton.styleFrom(
                backgroundColor: PosColors.surface,
                foregroundColor: PosColors.accentStrong,
                side: const BorderSide(color: PosColors.lineStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(Icons.photo_camera_outlined, size: 22),
                  const SizedBox(height: PosSpacing.sp1),
                  TfText(
                    addLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TfTextStyles.rowMoney,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(width: PosSpacing.sp2),
          TfIconButton(
            icon: Icons.clear_rounded,
            tooltip: clearLabel,
            onPressed: busy ? null : onClear,
          ),
        ],
      ],
    );
  }
}

class _AdvancedMenuOptions extends StatelessWidget {
  const _AdvancedMenuOptions({
    required this.text,
    required this.descriptionController,
    required this.prepController,
    required this.options,
    required this.includes,
    required this.addOns,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onAddInclude,
    required this.onRemoveInclude,
    required this.onAddAddOn,
    required this.onRemoveAddOn,
    required this.initiallyExpanded,
  });

  final AppStrings text;
  final TextEditingController descriptionController;
  final TextEditingController prepController;
  final List<_OptionRow> options;
  final List<_IncludeRow> includes;
  final List<_AddOnRow> addOns;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final VoidCallback onAddInclude;
  final ValueChanged<int> onRemoveInclude;
  final VoidCallback onAddAddOn;
  final ValueChanged<int> onRemoveAddOn;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: PosSpacing.sp3, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(PosSpacing.sp3, 0, PosSpacing.sp3, PosSpacing.sp3),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PosColors.surfaceSunk,
              borderRadius: BorderRadius.circular(PosRadii.md),
            ),
            child: const Icon(
              Icons.list_alt_outlined,
              size: 19,
              color: PosColors.inkSoft,
            ),
          ),
          title: TfText(
            text.menuVariationsAddOns,
            style: TfTextStyles.rowTitle.copyWith(color: PosColors.text),
          ),
          subtitle: TfText(
            text.menuOptionsSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TfTextStyles.sectionStrip.copyWith(
              fontWeight: FontWeight.w400,
              color: PosColors.muted,
            ),
          ),
          children: [
            TextFormField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: text.menuDescriptionOptional,
              ),
            ),
            const SizedBox(height: PosSpacing.sp2),
            TextFormField(
              controller: prepController,
              decoration: InputDecoration(
                labelText: text.menuPrepTime,
                hintText: text.menuPrepTimeHint,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: PosSpacing.sp3),
            _SectionLabel(text.menuSizeOptionsTitle),
            const SizedBox(height: PosSpacing.sp2),
            ...options.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _OptionRowWidget(
                  controller: e.value,
                  onRemove: () => onRemoveOption(e.key),
                ),
              ),
            ),
            _AddRowButton(
              label: text.addVariantLabel,
              onTap: onAddOption,
            ),
            const SizedBox(height: PosSpacing.sp3),
            _SectionLabel(text.menuIncludesTitle),
            const SizedBox(height: PosSpacing.sp2),
            ...includes.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _IncludeRowWidget(
                  controller: e.value,
                  onRemove: () => onRemoveInclude(e.key),
                ),
              ),
            ),
            _AddRowButton(
              label: text.addIncludeLabel,
              onTap: onAddInclude,
            ),
            const SizedBox(height: PosSpacing.sp3),
            _SectionLabel(text.menuAddOnsTitle),
            const SizedBox(height: PosSpacing.sp2),
            ...addOns.asMap().entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AddOnRowWidget(
                  controller: e.value,
                  onRemove: () => onRemoveAddOn(e.key),
                ),
              ),
            ),
            _AddRowButton(
              label: text.addAddOnLabel,
              onTap: onAddAddOn,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) {
    return TfText(
      label,
      style: TfTextStyles.sectionStrip.copyWith(color: PosColors.inkSoft),
    );
  }
}

class _AddRowButton extends StatelessWidget {
  const _AddRowButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add_rounded, size: 16),
        label: TfText(label, style: TfTextStyles.rowTitle),
        style: OutlinedButton.styleFrom(
          foregroundColor: PosColors.accentStrong,
          side: const BorderSide(color: PosColors.lineStrong),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(PosRadii.md)),
        ),
      ),
    );
  }
}

class _OptionRowWidget extends StatelessWidget {
  const _OptionRowWidget({required this.controller, required this.onRemove});
  final _OptionRow controller;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: controller.nameCtrl,
            decoration: InputDecoration(hintText: text.menuOptionNameHint),
          ),
        ),
        const SizedBox(width: PosSpacing.sp2),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: controller.priceCtrl,
            decoration: InputDecoration(
              hintText: text.menuOptionTotalPriceHint,
            ),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          ),
        ),
        const SizedBox(width: PosSpacing.sp1),
        TfIconButton(
          bare: true,
          icon: Icons.close_rounded,
          tooltip: text.remove,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

class _IncludeRowWidget extends StatelessWidget {
  const _IncludeRowWidget({required this.controller, required this.onRemove});
  final _IncludeRow controller;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: controller.nameCtrl,
            decoration: InputDecoration(hintText: text.menuIncludeNameHint),
          ),
        ),
        const SizedBox(width: PosSpacing.sp1),
        TfIconButton(
          bare: true,
          icon: Icons.close_rounded,
          tooltip: text.remove,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

class _AddOnRowWidget extends StatelessWidget {
  const _AddOnRowWidget({required this.controller, required this.onRemove});
  final _AddOnRow controller;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: controller.nameCtrl,
            decoration: InputDecoration(hintText: text.menuAddOnNameHint),
          ),
        ),
        const SizedBox(width: PosSpacing.sp2),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: controller.priceCtrl,
            decoration: InputDecoration(hintText: text.menuAddOnPriceHint),
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          ),
        ),
        const SizedBox(width: PosSpacing.sp1),
        TfIconButton(
          bare: true,
          icon: Icons.close_rounded,
          tooltip: text.remove,
          onPressed: onRemove,
        ),
      ],
    );
  }
}

class _OptionRow {
  _OptionRow({String name = '', double priceDelta = 0, double basePrice = 0})
    : nameCtrl = TextEditingController(text: name),
      priceCtrl = TextEditingController(text: _fmt(basePrice + priceDelta));
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  void dispose() { nameCtrl.dispose(); priceCtrl.dispose(); }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
}

class _IncludeRow {
  _IncludeRow(String name) : nameCtrl = TextEditingController(text: name);
  final TextEditingController nameCtrl;
  void dispose() { nameCtrl.dispose(); }
}

class _AddOnRow {
  _AddOnRow({String name = '', double price = 0})
    : nameCtrl = TextEditingController(text: name),
      priceCtrl = TextEditingController(
        text: price == price.roundToDouble()
            ? price.toInt().toString()
            : price.toStringAsFixed(2),
      );
  final TextEditingController nameCtrl;
  final TextEditingController priceCtrl;
  void dispose() { nameCtrl.dispose(); priceCtrl.dispose(); }
}

class _MenuFormResult {
  _MenuFormResult({
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isAvailable,
    required this.tags,
    this.shortCode,
    this.imageUrl,
    this.preparationTimeMinutes,
  }) : deleteRequested = false;

  const _MenuFormResult.delete()
    : name = null,
      description = null,
      category = null,
      price = null,
      shortCode = null,
      imageUrl = null,
      isAvailable = null,
      preparationTimeMinutes = null,
      tags = null,
      deleteRequested = true;

  final String? name;
  final String? description;
  final String? category;
  final double? price;
  final int? shortCode;
  final String? imageUrl;
  final bool? isAvailable;
  final int? preparationTimeMinutes;
  final List<String>? tags;
  final bool deleteRequested;
}
