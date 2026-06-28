import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../models/menu_item.dart';
import '../../models/pos_notification.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';
import '../desktop_pos/widgets/pc_theme.dart';
import '../desktop_pos/widgets/pc_widgets.dart';
import 'square_image_cropper.dart';

enum _MenuScanSource { camera, gallery }

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
  bool _scanBusy = false;

  /// ⚡ short-code mode — shows the code badge on item cards and makes the
  /// search field numeric so a code lookup is a couple of taps.
  bool _codeMode = false;

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
              : _codeMode
              ? (item.shortCode?.toString().startsWith(query) ?? false)
              : item.searchText(language).contains(query);
          return matchesCategory && matchesSearch;
        })
        .toList(growable: false);
    final paused = app.menuItems.where((item) => !item.isAvailable).length;
    final realCategoryCount = app.categories.length;
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

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                physics: BouncingScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TfGlobalTopBar(
                            title: text.menu,
                            subtitle: text.menuItemsCategorySubtitle(
                              app.menuItems.length,
                              realCategoryCount,
                            ),
                            onNavigateToOrders: widget.onNavigateToOrders,
                            onNavigateToTarget: widget.onNavigateToTarget,
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TfSearchField(
                                  controller: _searchController,
                                  hintText: _codeMode
                                      ? text.shortCodeSearchHint
                                      : text.menuSearchHint,
                                  keyboardType: _codeMode
                                      ? TextInputType.number
                                      : null,
                                  prefixIcon: _codeMode
                                      ? Icons.bolt_rounded
                                      : Icons.search_rounded,
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 10),
                              _CodeModeButton(
                                active: _codeMode,
                                onTap: () => setState(() {
                                  _codeMode = !_codeMode;
                                  _searchController.clear();
                                }),
                              ),
                            ],
                          ),
                          if (app.menuItems.isNotEmpty) ...[
                            SizedBox(height: 12),
                            TfFilterChipRow(
                              chips: categories
                                  .map(
                                    (cat) => TfFilterChipData(
                                      label: cat,
                                      count: cat == text.allCategories
                                          ? app.menuItems.length
                                          : app.menuItems
                                                .where(
                                                  (i) =>
                                                      i.localizedCategory(
                                                        language,
                                                      ) ==
                                                      cat,
                                                )
                                                .length,
                                      active: cat == _selectedCategory,
                                    ),
                                  )
                                  .toList(),
                              onSelected: (index) => setState(
                                () => _selectedCategory = categories[index],
                              ),
                            ),
                          ],
                          SizedBox(height: 16),
                          if (app.menuItems.isEmpty)
                            TfEmptyState(
                              title: text.menuEmptyTitle,
                              message: text.menuEmptyMessage,
                              icon: Icons.restaurant_menu_rounded,
                            )
                          else if (items.isEmpty)
                            TfEmptyState(
                              title: text.menuNoResultsTitle,
                              message: text.menuNoResultsMessage,
                              icon: Icons.search_off_rounded,
                            )
                          else ...[
                            if (_selectedItemIds.isNotEmpty) ...[
                              _BulkMenuToolbar(
                                count: _selectedItemIds.length,
                                onDiscount: () => _applyBulkDiscount(context),
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
                                    _selectedItemIds.addAll(
                                      items.map((i) => i.id),
                                    );
                                  } else {
                                    _selectedItemIds.removeAll(
                                      items.map((i) => i.id),
                                    );
                                  }
                                });
                              },
                              onAvailabilityChanged: (item, value) async {
                                if (!app.isManager) return;
                                await app.toggleMenuAvailability(
                                  item.id,
                                  value,
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (app.isManager)
              TfStickyCTA(
                child: Row(
                  children: [
                    Expanded(
                      child: TfButton(
                        label: text.menuScanCardButton,
                        icon: Icons.document_scanner_outlined,
                        variant: TfButtonVariant.dark,
                        size: TfButtonSize.lg,
                        onPressed: _scanBusy ? null : () => _scanMenu(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TfButton(
                        label: text.menuNewButton,
                        icon: Icons.add_rounded,
                        size: TfButtonSize.lg,
                        onPressed: () => _openMenuForm(context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
                  PcBtn(
                    label: _scanBusy ? text.menuScanningShort : text.menuScan,
                    icon: 'upload',
                    variant: PcVariant.dark,
                    onTap: _scanBusy ? null : () => _scanMenu(context),
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
                  const SizedBox(width: 12),
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
              onClear: () => setState(_selectedItemIds.clear),
              isBn: text.isBn,
            ),
          ],
          const SizedBox(height: 12),
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
                  const SizedBox(width: 8),
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
    final app = AppScope.read(context);
    final text = app.strings;
    try {
      final pages = await _pickMenuScanPages(context);
      if (pages.isEmpty) return;
      if (!context.mounted) return;
      if (kDebugMode) {
        final pageSummary = pages
            .map(
              (page) =>
                  '${page.fileName}(${page.mimeType}, ${page.bytes.length} bytes)',
            )
            .join('; ');
        debugPrint(
          '[MENU_SCAN] pages selected count=${pages.length}: $pageSummary',
        );
      }
      setState(() => _scanBusy = true);
      if (kDebugMode) {
        debugPrint('[MENU_SCAN] scan start');
      }
      final uploads = pages
          .map(
            (page) => MenuScanPageUpload(
              bytes: page.bytes,
              fileName: page.fileName,
              mimeType: page.mimeType,
            ),
          )
          .toList(growable: false);
      pages.clear();
      final result = await app.scanAndImportMenu(uploads);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(
            text.menuScanImported(
              result.createdCount,
              result.skippedDuplicateCount,
            ),
          ),
        ),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[MENU_SCAN] scan failed error=$error');
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TfText('${text.menuScanFailed}: $error')),
      );
    } finally {
      if (mounted) setState(() => _scanBusy = false);
    }
  }

  Future<void> _applyBulkDiscount(BuildContext context) async {
    final app = AppScope.read(context);
    final selected = app.menuItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
    await _applyDiscountToItems(context, selected, clearSelection: true);
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

  Future<List<PickedMenuScanPage>> _pickMenuScanPages(
    BuildContext context,
  ) async {
    final text = AppScope.of(context).strings;
    final source = await showModalBottomSheet<_MenuScanSource>(
      context: context,
      backgroundColor: PosColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.lg)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TfText(
                  text.isBn ? 'মেনু স্ক্যান' : 'Scan menu',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PosColors.slate,
                  ),
                ),
                const SizedBox(height: 12),
                TfButton(
                  label: text.isBn ? 'ক্যামেরা' : 'Camera',
                  icon: Icons.photo_camera_rounded,
                  variant: TfButtonVariant.primary,
                  onPressed: () =>
                      Navigator.pop(sheetContext, _MenuScanSource.camera),
                ),
                const SizedBox(height: 8),
                TfButton(
                  label: text.isBn ? 'গ্যালারি' : 'Gallery',
                  icon: Icons.photo_library_outlined,
                  variant: TfButtonVariant.dark,
                  onPressed: () =>
                      Navigator.pop(sheetContext, _MenuScanSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (source == null || !context.mounted) return const [];
    if (source == _MenuScanSource.gallery) {
      return _scanImageService.pickMenuScanPages();
    }
    return _captureMenuScanPages(context);
  }

  Future<List<PickedMenuScanPage>> _captureMenuScanPages(
    BuildContext context,
  ) async {
    final pages = <PickedMenuScanPage>[];
    while (pages.length < MenuImageService.maxScanPages) {
      final page = await _scanImageService.captureMenuScanPage(
        pageNumber: pages.length + 1,
      );
      if (page == null) break;
      pages.add(page);
      if (kDebugMode) {
        debugPrint(
          '[MENU_SCAN] captured ${page.fileName} '
          '${page.bytes.length} bytes ${page.mimeType}',
        );
      }
      if (!context.mounted) break;
      final addAnother = await showDialog<bool>(
        context: context,
        builder: (context) {
          final text = AppScope.of(context).strings;
          return AlertDialog(
            title: TfText(text.menuScanAddAnotherTitle),
            content: TfText(text.menuScanAddAnotherMessage(pages.length)),
            actions: [
              TfButton(
                label: text.menuScanUsePhotos,
                variant: TfButtonVariant.paper,
                fullWidth: false,
                onPressed: () => Navigator.pop(context, false),
              ),
              TfButton(
                label: text.menuScanAddPage,
                icon: Icons.add_a_photo_rounded,
                fullWidth: false,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          );
        },
      );
      if (addAnother != true) break;
    }
    if (pages.length >= MenuImageService.maxScanPages && context.mounted) {
      final text = AppScope.of(context).strings;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(
            text.isBn
                ? 'একবারে ${MenuImageService.maxScanPages}টি মেনু ছবি স্ক্যান করা যাবে।'
                : 'You can scan up to ${MenuImageService.maxScanPages} menu photos at a time.',
          ),
        ),
      );
    }
    return pages;
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
    required this.onClear,
    required this.isBn,
  });

  final int count;
  final VoidCallback onDiscount;
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
          const SizedBox(width: 8),
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
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
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
                style: TextStyle(
                  fontFamily: tfFontFamily(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: PosColors.slate,
                ),
              ),
              const SizedBox(height: 6),
              TfText(
                text.isBn
                    ? 'ডেলিভারি চার্জ এবং মেনু ডিসকাউন্ট পরিচালনা করুন।'
                    : 'Manage delivery pricing and menu discounts.',
                style: TextStyle(
                  color: PosColors.muted,
                  fontSize: 12,
                  height: 1.35,
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TfText(
                                text.menuDeliveryCharge,
                                style: const TextStyle(
                                  color: PosColors.slate,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              TfText(
                                text.menuDeliveryChargeSubtitle,
                                style: const TextStyle(
                                  color: PosColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        TfMoney(
                          deliveryCharge,
                          style: const TextStyle(
                            color: PosColors.slate,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
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
                  style: const TextStyle(
                    color: PosColors.slate,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TfText(
                  text.menuDeliveryChargeSubtitle,
                  style: const TextStyle(
                    color: PosColors.muted,
                    fontSize: 12,
                    height: 1.35,
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
    required this.onClear,
  });

  final int count;
  final VoidCallback onDiscount;
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
              style: const TextStyle(
                color: PosColors.slate,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TfButton(
            label: text.isBn ? 'ডিসকাউন্ট' : 'Discount',
            icon: Icons.local_offer_outlined,
            fullWidth: false,
            size: TfButtonSize.sm,
            onPressed: onDiscount,
          ),
          const SizedBox(width: 8),
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
                style: TextStyle(
                  fontFamily: tfFontFamily(context),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
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

/// Petpooja "Management"-style item table: a column header (select-all · Status ·
/// Name · Mark as) over flat rows of [checkbox · status dot · name · ON/OFF
/// toggle]. Thumbnail/price/code intentionally dropped — tap a row to edit for
/// the rest. The category filter chips above still scope which items show.
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
    final allSelected =
        items.isNotEmpty && items.every((i) => selectedIds.contains(i.id));
    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.lg),
        border: Border.all(color: PosColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _MenuListHeader(
            allSelected: allSelected,
            onToggleAll: () => onSelectAll(!allSelected),
          ),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: PosColors.line),
            _MenuManageRow(
              item: items[i],
              language: language,
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

/// Column header row for [_MenuList] — select-all checkbox + Status/Name/Mark as
/// labels. Fixed column widths keep it aligned with [_MenuManageRow].
class _MenuListHeader extends StatelessWidget {
  const _MenuListHeader({required this.allSelected, required this.onToggleAll});

  final bool allSelected;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    const style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: PosColors.muted,
      letterSpacing: 0.3,
    );
    return Container(
      color: PosColors.surfaceSunk,
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      child: Row(
        children: [
          SizedBox(
            width: _kMenuColCheckbox,
            child: _MenuCheckbox(
              value: allSelected,
              onChanged: (_) => onToggleAll(),
            ),
          ),
          SizedBox(
            width: _kMenuColStatus,
            child: Center(
              child: Text(text.menuColStatus.toUpperCase(), style: style),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(child: Text(text.menuColName.toUpperCase(), style: style)),
          const SizedBox(width: 8),
          SizedBox(
            width: _kMenuColMarkAs,
            child: Center(
              child: Text(text.menuColMarkAs.toUpperCase(), style: style),
            ),
          ),
        ],
      ),
    );
  }
}

/// One menu item rendered as a Petpooja Management row: checkbox · status dot ·
/// name · ON/OFF "Mark as" toggle. Tapping the row opens the editor; the
/// checkbox toggles multi-select.
class _MenuManageRow extends StatelessWidget {
  const _MenuManageRow({
    required this.item,
    required this.language,
    required this.selected,
    required this.onToggleSelect,
    required this.onEdit,
    required this.onAvailabilityChanged,
  });

  final MenuItem item;
  final AppLanguage language;
  final bool selected;
  final VoidCallback onToggleSelect;
  final VoidCallback onEdit;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final available = item.isAvailable;
    return Material(
      color: selected ? PosColors.primarySoft : PosColors.surface,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          child: Row(
            children: [
              SizedBox(
                width: _kMenuColCheckbox,
                child: _MenuCheckbox(
                  value: selected,
                  onChanged: (_) => onToggleSelect(),
                ),
              ),
              SizedBox(
                width: _kMenuColStatus,
                child: Center(
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: available ? PosColors.success : PosColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TfText(
                  item.localizedName(language),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PosColors.text,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: _kMenuColMarkAs,
                child: Center(
                  child: _MarkAsToggle(
                    value: available,
                    onChanged: onAvailabilityChanged,
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
const double _kMenuColStatus = 44;
const double _kMenuColMarkAs = 58;

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
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: on ? Colors.white : PosColors.muted,
        letterSpacing: 0.3,
      ),
    );
    const knob = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 2)],
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
            color: on ? PosColors.success : PosColors.surfaceSunk,
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

/// ⚡ Short-code mode toggle — square button beside the search field. Active =
/// blue fill + white bolt; inactive = ghost outline. Mirrors Petpooja's
/// "Short Code" quick-entry next to item search.
class _CodeModeButton extends StatelessWidget {
  const _CodeModeButton({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? PosColors.primary : PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.md),
            border: Border.all(
              color: active ? PosColors.primary : PosColors.lineStrong,
            ),
          ),
          child: Icon(
            Icons.bolt_rounded,
            size: 22,
            color: active ? PosColors.accentInk : PosColors.muted,
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
  late final TextEditingController _discountController;
  late final TextEditingController _includesController;
  late final TextEditingController _optionsController;
  late final TextEditingController _addOnsController;
  final MenuImageService _imageService = MenuImageService();
  late bool _isAvailable;
  late MenuItemExtras _initialExtras;
  late _DiscountMode _discountMode;
  bool _imageBusy = false;

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
    _discountMode =
        _initialExtras.discountPercent != null &&
            _initialExtras.discountPercent! > 0
        ? _DiscountMode.percent
        : (_initialExtras.discountFlat != null &&
                  _initialExtras.discountFlat! > 0
              ? _DiscountMode.flat
              : _DiscountMode.none);
    final initialDiscount =
        _initialExtras.discountPercent ?? _initialExtras.discountFlat;
    _discountController = TextEditingController(
      text: initialDiscount == null || initialDiscount == 0
          ? ''
          : _formatNumber(initialDiscount),
    );
    _includesController = TextEditingController(
      text: _initialExtras.includes.join('\n'),
    );
    _optionsController = TextEditingController(
      text: _initialExtras.options
          .map(
            (o) =>
                '${o.name} : ${o.priceDelta == o.priceDelta.roundToDouble() ? o.priceDelta.toInt() : o.priceDelta}',
          )
          .join('\n'),
    );
    _addOnsController = TextEditingController(
      text: _initialExtras.addOns
          .map(
            (a) =>
                '${a.name} : ${a.price == a.price.roundToDouble() ? a.price.toInt() : a.price}',
          )
          .join('\n'),
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
    _discountController.dispose();
    _includesController.dispose();
    _optionsController.dispose();
    _addOnsController.dispose();
    super.dispose();
  }

  static String _formatNumber(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
    final placeholderIconKey = _placeholderIconKey();
    final inputTheme = theme.inputDecorationTheme.copyWith(
      fillColor: PosColors.background,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PosRadii.md),
        borderSide: BorderSide(color: PosColors.lineStrong),
      ),
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: inputTheme,
        chipTheme: theme.chipTheme.copyWith(
          backgroundColor: PosColors.background,
          selectedColor: PosColors.primarySoft,
        ),
      ),
      child: Material(
        color: PosColors.background,
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
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
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
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(
                                        fontFamily: tfFontFamily(context),
                                        fontWeight: FontWeight.w700,
                                      ),
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
                          const SizedBox(height: 12),
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
                          const SizedBox(height: 18),
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
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 16),
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
                          const SizedBox(height: 16),
                          _EditorField(
                            label: text.menuCategory,
                            child: _buildCategoryField(text),
                          ),
                          const SizedBox(height: 16),
                          _EditorToggleCard(
                            text: text,
                            available: _isAvailable,
                            discountOn: _discountMode != _DiscountMode.none,
                            discountMode: _discountMode,
                            discountController: _discountController,
                            onAvailableChanged: (value) =>
                                setState(() => _isAvailable = value),
                            onDiscountEnabledChanged: (value) => setState(() {
                              if (value) {
                                _discountMode = _DiscountMode.percent;
                                if (_discountController.text.trim().isEmpty) {
                                  _discountController.text = '10';
                                }
                              } else {
                                _discountMode = _DiscountMode.none;
                                _discountController.clear();
                              }
                            }),
                            onDiscountModeChanged: (mode) =>
                                setState(() => _discountMode = mode),
                          ),
                          const SizedBox(height: 14),
                          _AdvancedMenuOptions(
                            text: text,
                            descriptionController: _descriptionController,
                            prepController: _prepController,
                            includesController: _includesController,
                            optionsController: _optionsController,
                            addOnsController: _addOnsController,
                            initiallyExpanded:
                                _descriptionController.text.trim().isNotEmpty ||
                                _prepController.text.trim().isNotEmpty ||
                                _initialExtras.includes.isNotEmpty ||
                                _initialExtras.options.isNotEmpty ||
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
    final raw = _discountController.text.trim();
    final discountValue = double.tryParse(raw);
    double? percent;
    double? flat;
    if (_discountMode == _DiscountMode.percent &&
        discountValue != null &&
        discountValue > 0) {
      percent = discountValue.clamp(0, 100).toDouble();
    } else if (_discountMode == _DiscountMode.flat &&
        discountValue != null &&
        discountValue > 0) {
      flat = discountValue;
    }
    final includes = _includesController.text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final options = <MenuOption>[];
    for (final line in _optionsController.text.split(RegExp(r'\r?\n'))) {
      final option = MenuOption.parse(line.trim());
      if (option != null) options.add(option);
    }
    final addOns = <MenuAddOn>[];
    for (final line in _addOnsController.text.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final i = trimmed.lastIndexOf(':');
      if (i <= 0 || i >= trimmed.length - 1) {
        addOns.add(MenuAddOn(name: trimmed, price: 0));
        continue;
      }
      final name = trimmed.substring(0, i).trim();
      final price = double.tryParse(trimmed.substring(i + 1).trim()) ?? 0;
      if (name.isNotEmpty) addOns.add(MenuAddOn(name: name, price: price));
    }
    return _initialExtras.copyWith(
      iconKey: _imageController.text.trim().isEmpty
          ? _placeholderIconKey()
          : _initialExtras.iconKey,
      clearDiscount: percent == null && flat == null,
      discountPercent: percent,
      discountFlat: flat,
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
        const SizedBox(height: 8),
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
            width: 80,
            height: 80,
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
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 80,
            child: OutlinedButton(
              onPressed: busy ? null : onPick,
              style: OutlinedButton.styleFrom(
                backgroundColor: PosColors.surface,
                foregroundColor: PosColors.accentStrong,
                side: const BorderSide(color: PosColors.lineStrong),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosRadii.lg),
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
                  const SizedBox(height: 6),
                  TfText(
                    addLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasImage) ...[
          const SizedBox(width: 8),
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

class _EditorToggleCard extends StatelessWidget {
  const _EditorToggleCard({
    required this.text,
    required this.available,
    required this.discountOn,
    required this.discountMode,
    required this.discountController,
    required this.onAvailableChanged,
    required this.onDiscountEnabledChanged,
    required this.onDiscountModeChanged,
  });

  final AppStrings text;
  final bool available;
  final bool discountOn;
  final _DiscountMode discountMode;
  final TextEditingController discountController;
  final ValueChanged<bool> onAvailableChanged;
  final ValueChanged<bool> onDiscountEnabledChanged;
  final ValueChanged<_DiscountMode> onDiscountModeChanged;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _EditorToggleRow(
            icon: Icons.check_rounded,
            label: text.menuAvailable,
            hint: text.menuAvailableForOrder,
            value: available,
            onChanged: onAvailableChanged,
            first: true,
          ),
          _EditorToggleRow(
            icon: Icons.local_offer_outlined,
            label: text.isBn ? 'ডিসকাউন্ট সেট করুন' : 'Set discount',
            hint: discountOn
                ? '${discountController.text.trim().isEmpty ? '10' : discountController.text.trim()}${discountMode == _DiscountMode.percent ? '%' : '৳'} ${text.menuDiscountSummary}'
                : text.menuDiscountNone,
            value: discountOn,
            onChanged: onDiscountEnabledChanged,
          ),
          if (discountOn)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in const [5, 10, 15, 20, 25])
                        TfChip(
                          label: '$v%',
                          active:
                              discountMode == _DiscountMode.percent &&
                              discountController.text.trim() == '$v',
                          small: true,
                          tint: true,
                          onTap: () {
                            discountController.text = '$v';
                            onDiscountModeChanged(_DiscountMode.percent);
                          },
                        ),
                      TfChip(
                        label: text.isBn ? 'টাকা' : 'Flat',
                        active: discountMode == _DiscountMode.flat,
                        small: true,
                        tint: true,
                        onTap: () => onDiscountModeChanged(_DiscountMode.flat),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: discountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}'),
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: text.menuDiscountValue,
                      suffixText: discountMode == _DiscountMode.percent
                          ? '%'
                          : '৳',
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _EditorToggleRow extends StatelessWidget {
  const _EditorToggleRow({
    required this.icon,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    this.first = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: first
              ? null
              : const Border(top: BorderSide(color: PosColors.line)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: PosColors.surfaceSunk,
                borderRadius: BorderRadius.circular(PosRadii.md),
              ),
              child: Icon(icon, size: 18, color: PosColors.inkSoft),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TfText(
                    label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: PosColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  TfText(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: PosColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            TfToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _AdvancedMenuOptions extends StatelessWidget {
  const _AdvancedMenuOptions({
    required this.text,
    required this.descriptionController,
    required this.prepController,
    required this.includesController,
    required this.optionsController,
    required this.addOnsController,
    required this.initiallyExpanded,
  });

  final AppStrings text;
  final TextEditingController descriptionController;
  final TextEditingController prepController;
  final TextEditingController includesController;
  final TextEditingController optionsController;
  final TextEditingController addOnsController;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
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
            style: const TextStyle(
              color: PosColors.text,
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: TfText(
            text.menuOptionsSubtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: PosColors.muted, fontSize: 12.5),
          ),
          children: [
            TextFormField(
              controller: descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: text.menuDescriptionOptional,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: prepController,
              decoration: InputDecoration(
                labelText: text.menuPrepTime,
                hintText: text.menuPrepTimeHint,
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: optionsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: text.menuSizeOptionsTitle,
                hintText: text.menuSizeOptionsHint,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: includesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: text.menuIncludesTitle,
                hintText: text.menuIncludesHint,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: addOnsController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: text.menuAddOnsTitle,
                hintText: text.menuAddOnsHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
