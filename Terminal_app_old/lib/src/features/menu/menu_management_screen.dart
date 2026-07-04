import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/tf_design_system.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
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
          final matchesSearch =
              query.isEmpty || item.searchText(language).contains(query);
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

    return Scaffold(
      backgroundColor: PosColors.background,
      floatingActionButton: _MenuActionBar(
        scanBusy: _scanBusy,
        onAddItem: () => _openMenuForm(context),
        onScan: _scanBusy ? null : () => _scanMenu(context),
        text: text,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 14, 12, 18),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TfAppBar(
                      title: text.menu,
                      subtitle: text.menuItemsSubtitle(
                        app.menuItems.length,
                        paused,
                      ),
                      trailing: [
                        if (app.isManager)
                          TfIconButton(
                            icon: TfNavIcon.settings,
                            tooltip: text.isBn
                                ? 'মেনু সেটিংস'
                                : 'Menu settings',
                            onPressed: () => _openMenuSettings(context),
                          ),
                        HeaderModeButton(),
                        HeaderNotificationBell(
                          onNavigateToOrders:
                              widget.onNavigateToOrders ?? () {},
                          onNavigateToTarget: widget.onNavigateToTarget,
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    TfSearchField(
                      controller: _searchController,
                      hintText: text.menuSearchHint,
                      onChanged: (_) => setState(() {}),
                    ),
                    if (app.menuItems.isNotEmpty) ...[
                      SizedBox(height: 10),
                      _CategoryStrip(
                        categories: categories,
                        selectedCategory: _selectedCategory,
                        allLabel: text.allCategories,
                        countOf: (cat) => cat == text.allCategories
                            ? app.menuItems.length
                            : app.menuItems
                                  .where(
                                    (i) => i.localizedCategory(language) == cat,
                                  )
                                  .length,
                        onSelected: (value) =>
                            setState(() => _selectedCategory = value),
                      ),
                    ],
                    SizedBox(height: 10),
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
                        const SizedBox(height: 10),
                      ],
                      _MenuList(
                        items: items,
                        language: language,
                        selectedIds: _selectedItemIds,
                        selectionMode: _selectedItemIds.isNotEmpty,
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
                        onDelete: app.isManager
                            ? (item) => _confirmDelete(context, item)
                            : (_) {},
                        onAvailabilityChanged: (item, value) async {
                          if (!app.isManager) return;
                          await app.toggleMenuAvailability(item.id, value);
                        },
                        onAddImage: app.isManager
                            ? (item) => _addImageToItem(context, item)
                            : (_) {},
                      ),
                      // Reserve space so the floating action bar never covers
                      // the last menu row.
                      if (app.isManager) const SizedBox(height: 92),
                    ],
                  ],
                ),
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
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                borderRadius: BorderRadius.circular(8),
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
                    style: Pc.mono(
                      10.5,
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
    final app = AppScope.of(context);
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
    final app = AppScope.of(context);
    final selected = app.menuItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
    await _applyDiscountToItems(context, selected, clearSelection: true);
  }

  Future<void> _openMenuSettings(BuildContext context) async {
    final app = AppScope.of(context);
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

  Future<void> _openDeliveryChargeEditor(BuildContext context) async {
    final app = AppScope.of(context);
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
    final app = AppScope.of(context);
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
                    fontWeight: FontWeight.w500,
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
    final app = AppScope.of(context);
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
    await app.saveMenuItem(
      id: item?.id,
      name: result.name,
      nameEn: result.name,
      nameBn: item?.nameBn,
      description: result.description,
      descriptionEn: result.description,
      descriptionBn: item?.descriptionBn,
      category: result.category,
      categoryEn: result.category,
      categoryBn: item?.categoryBn,
      price: result.price,
      imageUrl: result.imageUrl,
      isAvailable: result.isAvailable,
      preparationTimeMinutes: result.preparationTimeMinutes,
      tags: result.tags,
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
    final app = AppScope.of(context);
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
    final app = AppScope.of(context);
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

class _MenuActionBar extends StatelessWidget {
  const _MenuActionBar({
    required this.scanBusy,
    required this.onAddItem,
    required this.onScan,
    required this.text,
  });

  final bool scanBusy;
  final VoidCallback onAddItem;
  final VoidCallback? onScan;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final shellWidth = (MediaQuery.sizeOf(context).width - 28)
        .clamp(0.0, 360.0)
        .toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: SizedBox(
        width: shellWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PosColors.line, width: 0.5),
            boxShadow: PosShadows.glow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: _MenuActionButton(
                    label: text.menuAddActionShort,
                    icon: Icons.add_rounded,
                    onPressed: onAddItem,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MenuActionButton(
                    label: scanBusy ? text.menuScanningShort : text.menuScan,
                    icon: Icons.upload_file_outlined,
                    primary: true,
                    busy: scanBusy,
                    onPressed: onScan,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuActionButton extends StatelessWidget {
  const _MenuActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.primary = false,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TfButton(
        onPressed: onPressed,
        icon: icon,
        label: label,
        busy: busy,
        variant: primary ? TfButtonVariant.primary : TfButtonVariant.dark,
        fullWidth: true,
      ),
    );
  }
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
                        borderRadius: BorderRadius.circular(10),
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
                        child: Transform.scale(
                          scale: 0.72,
                          alignment: Alignment.topRight,
                          child: Switch.adaptive(
                            value: item.isAvailable,
                            onChanged: onAvailabilityChanged,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
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
                  fontSize: 13.5,
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
                style: Pc.mono(10, color: Pc.textTer),
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
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        badge,
                        style: Pc.mono(
                          9,
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

class _CategoryStrip extends StatelessWidget {
  const _CategoryStrip({
    required this.categories,
    required this.selectedCategory,
    required this.allLabel,
    required this.countOf,
    required this.onSelected,
  });

  final List<String> categories;
  final String selectedCategory;
  final String allLabel;
  final int Function(String category) countOf;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => SizedBox(width: 7),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == selectedCategory;
          return Material(
            color: selected ? PosColors.primary : PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.pill),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onSelected(category),
              child: Container(
                height: 30,
                padding: EdgeInsets.symmetric(horizontal: 11),
                alignment: Alignment.center,
                child: TfText(
                  AppScope.of(context).strings.categoryCountLabel(
                    category == allLabel ? 'All' : category,
                    countOf(category),
                  ),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: selected ? PosColors.primaryDark : PosColors.muted,
                  ),
                ),
              ),
            ),
          );
        },
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                  fontWeight: FontWeight.w600,
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
                    padding: const EdgeInsets.all(14),
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
                                  fontWeight: FontWeight.w600,
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
                            fontWeight: FontWeight.w600,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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
                    fontWeight: FontWeight.w600,
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
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Expanded(
            child: TfText(
              text.isBn
                  ? '${tfToBnNumbers('$count')} আইটেম নির্বাচিত'
                  : '$count items selected',
              style: const TextStyle(
                color: PosColors.slate,
                fontSize: 13,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
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

class _MenuList extends StatelessWidget {
  const _MenuList({
    required this.items,
    required this.language,
    required this.selectedIds,
    required this.selectionMode,
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
  final ValueChanged<MenuItem> onEdit;
  final ValueChanged<MenuItem> onSelect;
  final ValueChanged<MenuItem> onDelete;
  final void Function(MenuItem item, bool value) onAvailabilityChanged;
  final ValueChanged<MenuItem> onAddImage;

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<MenuItem>>{};
    for (final item in items) {
      final category = item.localizedCategory(language).trim().isEmpty
          ? 'General'
          : item.localizedCategory(language).trim();
      grouped.putIfAbsent(category, () => <MenuItem>[]).add(item);
    }
    final categoryNames = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final category in categoryNames) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              2,
              category == categoryNames.first ? 0 : 14,
              2,
              7,
            ),
            child: TfText(
              category,
              style: TextStyle(
                color: PosColors.slate,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TfCard(
            padding: EdgeInsets.zero,
            child: ListView.separated(
              itemCount: grouped[category]!.length,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: PosColors.lineStrong),
              itemBuilder: (context, index) {
                final item = grouped[category]![index];
                return _MenuRow(
                  item: item,
                  language: language,
                  selected: selectedIds.contains(item.id),
                  selectionMode: selectionMode,
                  onEdit: () => selectionMode ? onSelect(item) : onEdit(item),
                  onSelect: () => onSelect(item),
                  onDelete: () => onDelete(item),
                  onAvailabilityChanged: (value) =>
                      onAvailabilityChanged(item, value),
                  onAddImage: () => onAddImage(item),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.language,
    required this.selected,
    required this.selectionMode,
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
  final VoidCallback onEdit;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAvailabilityChanged;
  final VoidCallback onAddImage;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final priceDecimals = item.price == item.price.roundToDouble() ? 0 : 2;
    final extras = item.extras;
    final discounted = extras.discountedPrice(item.price);
    final showDiscount = extras.hasDiscount && discounted < item.price;
    final hasImage = (item.imageUrl ?? '').trim().isNotEmpty;
    final iconKey = resolveMenuIconKey(
      iconKey: extras.iconKey,
      name: item.name,
      category: item.category,
    );
    final discountLabel = text.isBn
        ? tfToBnNumbers(extras.discountBadgeLabel())
        : extras.discountBadgeLabel();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        onLongPress: onSelect,
        onSecondaryTap: onDelete,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 9, 8, 9),
          child: Row(
            children: [
              Tooltip(
                message: hasImage ? text.editMenuItem : text.menuChooseGallery,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onAddImage,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MenuImageView(
                            imageUrl: item.imageUrl,
                            iconKey: iconKey,
                          ),
                          if (!hasImage)
                            Align(
                              alignment: Alignment.bottomRight,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: PosColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: PosColors.line,
                                    width: 0.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 11,
                                  color: PosColors.primaryDark,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              if (selectionMode) ...[
                Checkbox(value: selected, onChanged: (_) => onSelect()),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: TfText(
                            item.localizedName(language),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: PosColors.slate,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              height: 1.1,
                            ),
                          ),
                        ),
                        if (extras.includes.isNotEmpty ||
                            extras.addOns.isNotEmpty) ...[
                          SizedBox(width: 6),
                          Icon(
                            Icons.tune_rounded,
                            size: 12,
                            color: PosColors.muted,
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 3),
                    TfText(
                      item.localizedDescription(language).trim().isEmpty
                          ? item.localizedCategory(language)
                          : item.localizedDescription(language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PosColors.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 3),
                    Row(
                      children: [
                        TfText(
                          item.isAvailable
                              ? text.menuAvailable
                              : text.menuPaused,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.isAvailable
                                ? PosColors.success
                                : PosColors.danger,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (showDiscount) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: PosColors.danger.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TfText(
                              discountLabel,
                              style: TextStyle(
                                color: PosColors.danger,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showDiscount) ...[
                    TfText(
                      tfFormatCurrency(
                        context,
                        item.price,
                        decimalDigits: priceDecimals,
                      ),
                      style: TextStyle(
                        color: PosColors.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    TfText(
                      tfFormatCurrency(
                        context,
                        discounted,
                        decimalDigits: priceDecimals,
                      ),
                      style: TextStyle(
                        color: PosColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ] else
                    TfText(
                      tfFormatCurrency(
                        context,
                        item.price,
                        decimalDigits: priceDecimals,
                      ),
                      style: TextStyle(
                        color: PosColors.slate,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  SizedBox(height: 3),
                  Transform.scale(
                    scale: 0.76,
                    alignment: Alignment.centerRight,
                    child: Switch.adaptive(
                      value: item.isAvailable,
                      onChanged: onAvailabilityChanged,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
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
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 18),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TfText(
                            widget.initialItem == null
                                ? text.addMenuItem
                                : text.editMenuItem,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: text.menuItemName),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return text.menuItemNameRequired;
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: text.menuDescriptionOptional,
                      ),
                    ),
                    SizedBox(height: 10),
                    // Keep all alphanumeric entry fields grouped together
                    // (category → price → prep time) before the user is
                    // asked to upload an image. This avoids the previous
                    // ordering where prep time was awkwardly stranded below
                    // the image picker.
                    _buildCategoryField(text),
                    SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 420;
                        final price = TextFormField(
                          controller: _priceController,
                          decoration: InputDecoration(
                            labelText: text.menuPrice,
                          ),
                          keyboardType: TextInputType.numberWithOptions(
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
                        );
                        final prep = TextFormField(
                          controller: _prepController,
                          decoration: InputDecoration(
                            labelText: text.menuPrepTime,
                            hintText: text.menuPrepTimeHint,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        );
                        if (compact) {
                          return Column(
                            children: [price, SizedBox(height: 10), prep],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: price),
                            SizedBox(width: 12),
                            Expanded(child: prep),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: 10),
                    _ImagePickerField(
                      busy: _imageBusy,
                      hasImage: _imageController.text.trim().isNotEmpty,
                      chooseLabel: text.menuChooseGallery,
                      clearLabel: text.menuClearImage,
                      onPick: _pickImage,
                      onClear: () {
                        _imageController.clear();
                        setState(() {});
                      },
                    ),
                    if (_imageController.text.trim().isNotEmpty) ...[
                      SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: MenuImageView(
                            imageUrl: _imageController.text.trim(),
                            iconKey: placeholderIconKey,
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(height: 10),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PosColors.line),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: MenuImageView(
                          imageUrl: null,
                          iconKey: placeholderIconKey,
                        ),
                      ),
                    ],
                    SizedBox(height: 14),
                    _OptionalMenuOptions(
                      text: text,
                      discountMode: _discountMode,
                      discountController: _discountController,
                      includesController: _includesController,
                      optionsController: _optionsController,
                      addOnsController: _addOnsController,
                      initiallyExpanded:
                          _discountMode != _DiscountMode.none ||
                          _initialExtras.includes.isNotEmpty ||
                          _initialExtras.options.isNotEmpty,
                      onDiscountModeChanged: (m) => setState(() {
                        _discountMode = m;
                        if (m == _DiscountMode.none) {
                          _discountController.clear();
                        }
                      }),
                    ),
                    SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      value: _isAvailable,
                      onChanged: (value) =>
                          setState(() => _isAvailable = value),
                      contentPadding: EdgeInsets.zero,
                      title: TfText(text.menuAvailableForOrder),
                    ),
                    SizedBox(height: 14),
                    TfButton(
                      onPressed: _submit,
                      icon: Icons.save_outlined,
                      label: widget.initialItem == null
                          ? text.menuCreateItem
                          : text.menuSaveItem,
                      size: TfButtonSize.lg,
                    ),
                  ],
                ),
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

class _OptionalMenuOptions extends StatelessWidget {
  const _OptionalMenuOptions({
    required this.text,
    required this.discountMode,
    required this.discountController,
    required this.includesController,
    required this.optionsController,
    required this.addOnsController,
    required this.initiallyExpanded,
    required this.onDiscountModeChanged,
  });

  final AppStrings text;
  final _DiscountMode discountMode;
  final TextEditingController discountController;
  final TextEditingController includesController;
  final TextEditingController optionsController;
  final TextEditingController addOnsController;
  final bool initiallyExpanded;
  final ValueChanged<_DiscountMode> onDiscountModeChanged;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Icon(Icons.tune_rounded, color: PosColors.muted),
          title: TfText(
            text.menuOptionsTitle,
            style: const TextStyle(
              color: PosColors.slate,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: TfText(
            text.menuOptionsSubtitle,
            style: const TextStyle(
              color: PosColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          children: [
            _DiscountSection(
              text: text,
              mode: discountMode,
              controller: discountController,
              onModeChanged: onDiscountModeChanged,
            ),
            const SizedBox(height: 12),
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

class _DiscountSection extends StatelessWidget {
  const _DiscountSection({
    required this.text,
    required this.mode,
    required this.controller,
    required this.onModeChanged,
  });

  final AppStrings text;
  final _DiscountMode mode;
  final TextEditingController controller;
  final ValueChanged<_DiscountMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfText(
          text.menuDiscountTitle,
          style: TextStyle(
            fontSize: 13,
            color: PosColors.slate,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in <(_DiscountMode, String)>[
              (_DiscountMode.none, text.menuDiscountNone),
              (_DiscountMode.percent, text.menuDiscountPercent),
              (_DiscountMode.flat, text.menuDiscountFlat),
            ])
              TfChip(
                label: entry.$2,
                active: mode == entry.$1,
                small: true,
                onTap: () => onModeChanged(entry.$1),
              ),
          ],
        ),
        if (mode != _DiscountMode.none) ...[
          SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
            ],
            decoration: InputDecoration(
              labelText: text.menuDiscountValue,
              suffixText: mode == _DiscountMode.percent ? '%' : '৳',
            ),
          ),
        ],
      ],
    );
  }
}

class _ImagePickerField extends StatelessWidget {
  const _ImagePickerField({
    required this.busy,
    required this.hasImage,
    required this.chooseLabel,
    required this.clearLabel,
    required this.onPick,
    required this.onClear,
  });

  final bool busy;
  final bool hasImage;
  final String chooseLabel;
  final String clearLabel;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        TfButton(
          label: chooseLabel,
          icon: Icons.photo_library_outlined,
          variant: TfButtonVariant.paper,
          size: TfButtonSize.sm,
          fullWidth: false,
          busy: busy,
          onPressed: busy ? null : onPick,
        ),
        TfButton(
          label: clearLabel,
          icon: Icons.clear,
          variant: TfButtonVariant.paper,
          size: TfButtonSize.sm,
          fullWidth: false,
          onPressed: hasImage && !busy ? onClear : null,
        ),
      ],
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
    this.imageUrl,
    this.preparationTimeMinutes,
  });

  final String name;
  final String description;
  final String category;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final int? preparationTimeMinutes;
  final List<String> tags;
}
