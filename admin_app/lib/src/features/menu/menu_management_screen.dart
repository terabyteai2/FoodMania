import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/pos_compact_ui.dart';
import '../../models/menu_item.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';
import 'square_image_cropper.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({this.onNavigateToOrders, super.key});

  /// Called when a pending-order notification is opened from the bell here.
  final VoidCallback? onNavigateToOrders;

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  final MenuImageService _scanImageService = MenuImageService();
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
    final categories = [text.allCategories, ...app.categories];
    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = text.allCategories;
    }

    final query = _searchController.text.trim().toLowerCase();
    final items = app.menuItems
        .where((item) {
          final matchesCategory =
              _selectedCategory == text.allCategories ||
              item.category == _selectedCategory;
          final matchesSearch =
              query.isEmpty ||
              item.name.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query) ||
              item.description.toLowerCase().contains(query);
          return matchesCategory && matchesSearch;
        })
        .toList(growable: false);
    final paused = app.menuItems.where((item) => !item.isAvailable).length;

    return Scaffold(
      backgroundColor: PosColors.background,
      floatingActionButton: app.isManager
          ? SizedBox(
              height: 58,
              child: FloatingActionButton.extended(
                onPressed: _scanBusy ? null : () => _scanMenu(context),
                backgroundColor: PosColors.primary,
                foregroundColor: PosColors.primaryDark,
                tooltip: text.menuScan,
                icon: _scanBusy
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          color: PosColors.primaryDark,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.document_scanner_rounded, size: 22),
                label: Text(
                  _scanBusy ? text.menuScanning : text.menuScan,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            )
          : null,
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
                    CompactHeader(
                      title: text.menu,
                      subtitle: text.menuItemsSubtitle(
                        app.menuItems.length,
                        paused,
                      ),
                      actions: [
                        HeaderLanguageButton(),
                        HeaderNotificationBell(
                          onNavigateToOrders:
                              widget.onNavigateToOrders ?? () {},
                        ),
                        if (app.isManager)
                          _NewMenuButton(onTap: () => _openMenuForm(context)),
                      ],
                    ),
                    SizedBox(height: 14),
                    CompactSearchField(
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
                                  .where((i) => i.category == cat)
                                  .length,
                        onSelected: (value) =>
                            setState(() => _selectedCategory = value),
                      ),
                    ],
                    SizedBox(height: 10),
                    if (app.menuItems.isEmpty)
                      EmptyCompactState(
                        title: text.menuEmptyTitle,
                        message: text.menuEmptyMessage,
                        icon: Icons.restaurant_menu_rounded,
                      )
                    else if (items.isEmpty)
                      EmptyCompactState(
                        title: text.menuNoResultsTitle,
                        message: text.menuNoResultsMessage,
                        icon: Icons.search_off_rounded,
                      )
                    else
                      _MenuList(
                        items: items,
                        onEdit: app.isManager
                            ? (item) => _openMenuForm(context, item: item)
                            : (_) {},
                        onDelete: app.isManager
                            ? (item) => _confirmDelete(context, item)
                            : (_) {},
                        onAvailabilityChanged: (item, value) async {
                          if (!app.isManager) return;
                          await app.toggleMenuAvailability(item.id, value);
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      final result = await app.scanAndImportMenu(
        pages
            .map(
              (page) => MenuScanPageUpload(
                bytes: page.bytes,
                fileName: page.fileName,
                mimeType: page.mimeType,
              ),
            )
            .toList(growable: false),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${text.menuScanFailed}: $error')));
    } finally {
      if (mounted) setState(() => _scanBusy = false);
    }
  }

  Future<List<PickedMenuScanPage>> _pickMenuScanPages(
    BuildContext context,
  ) async {
    final text = AppScope.of(context).strings;
    final source = await showModalBottomSheet<_MenuScanSource>(
      context: context,
      backgroundColor: PosColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: PosColors.lineStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              ListTile(
                leading: Icon(Icons.photo_camera_rounded),
                title: Text(text.menuScanTakePhotos),
                subtitle: Text(text.menuScanTakePhotosSubtitle),
                onTap: () => Navigator.pop(context, _MenuScanSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_rounded),
                title: Text(text.menuScanChooseGallery),
                subtitle: Text(text.menuScanChooseGallerySubtitle),
                onTap: () => Navigator.pop(context, _MenuScanSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return const <PickedMenuScanPage>[];
    if (source == null) return const <PickedMenuScanPage>[];
    if (source == _MenuScanSource.gallery) {
      return _scanImageService.pickMenuScanPages();
    }
    return _captureMenuScanPages(context);
  }

  Future<List<PickedMenuScanPage>> _captureMenuScanPages(
    BuildContext context,
  ) async {
    final pages = <PickedMenuScanPage>[];
    while (true) {
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
            title: Text(text.menuScanAddAnotherTitle),
            content: Text(text.menuScanAddAnotherMessage(pages.length)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(text.menuScanUsePhotos),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: Icon(Icons.add_a_photo_rounded),
                label: Text(text.menuScanAddPage),
              ),
            ],
          );
        },
      );
      if (addAnother != true) break;
    }
    return pages;
  }

  Future<void> _openMenuForm(BuildContext context, {MenuItem? item}) async {
    final app = AppScope.of(context);
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
      description: result.description,
      category: result.category,
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
        content: Text(item == null ? 'Menu item added' : 'Menu item updated'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, MenuItem item) async {
    final app = AppScope.of(context);
    final text = app.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(text.menuDeleteTitle),
        content: Text(
          '${item.name} will be removed from the admin app and future API responses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(text.deleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await app.deleteMenuItem(item.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text.menuDeleted)));
  }
}

enum _MenuScanSource { camera, gallery }

class _NewMenuButton extends StatelessWidget {
  const _NewMenuButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = AppScope.of(context).strings.menuNewButton;
    return SizedBox(
      height: 36,
      child: Material(
        color: PosColors.primary,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: PosColors.primaryDark, size: 14),
                SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: PosColors.primaryDark,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
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
                child: Text(
                  AppScope.of(context).strings.categoryCountLabel(
                    category == allLabel ? 'All' : category,
                    countOf(category),
                  ),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
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

class _MenuList extends StatelessWidget {
  const _MenuList({
    required this.items,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailabilityChanged,
  });

  final List<MenuItem> items;
  final ValueChanged<MenuItem> onEdit;
  final ValueChanged<MenuItem> onDelete;
  final void Function(MenuItem item, bool value) onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    return CompactSurface(
      padding: EdgeInsets.zero,
      radius: 10,
      child: ListView.separated(
        itemCount: items.length,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        separatorBuilder: (_, _) =>
            Divider(height: 1, color: PosColors.lineStrong),
        itemBuilder: (context, index) {
          final item = items[index];
          return _MenuRow(
            item: item,
            onEdit: () => onEdit(item),
            onDelete: () => onDelete(item),
            onAvailabilityChanged: (value) =>
                onAvailabilityChanged(item, value),
          );
        },
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailabilityChanged,
  });

  final MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      symbol: '৳',
      decimalDigits: item.price == item.price.roundToDouble() ? 0 : 2,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        onLongPress: onDelete,
        child: Padding(
          padding: EdgeInsets.fromLTRB(10, 9, 8, 9),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: MenuImageView(imageUrl: item.imageUrl),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PosColors.slate,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      item.description.trim().isEmpty
                          ? item.category
                          : '${item.category} · ${item.description}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PosColors.muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      item.isAvailable ? 'Available' : 'Paused',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.isAvailable
                            ? PosColors.success
                            : PosColors.danger,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currency.format(item.price),
                    style: TextStyle(
                      color: PosColors.slate,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
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
  final MenuImageService _imageService = MenuImageService();
  late bool _isAvailable;
  late Set<String> _tags;
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
    _tags = {...?item?.tags};
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _prepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = Theme.of(context);
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
                          child: Text(
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
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: MenuImageView(
                            imageUrl: _imageController.text.trim(),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      value: _isAvailable,
                      onChanged: (value) =>
                          setState(() => _isAvailable = value),
                      contentPadding: EdgeInsets.zero,
                      title: Text(text.menuAvailableForOrder),
                    ),
                    SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submit,
                        icon: Icon(Icons.save_outlined),
                        label: Text(
                          widget.initialItem == null
                              ? text.menuCreateItem
                              : text.menuSaveItem,
                        ),
                      ),
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
        _categoryController.text = selection;
      },
      fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
        if (fieldController.text.isEmpty &&
            _categoryController.text.isNotEmpty) {
          fieldController.text = _categoryController.text;
        }
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          onChanged: (value) => _categoryController.text = value,
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
      final dataUrl = _imageService.encodeDataUrl(
        cropped,
        mimeType: 'image/png',
      );
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
          content: Text(
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _imageBusy = false);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
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
        tags: _tags.toList(growable: false)..sort(),
      ),
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
        OutlinedButton.icon(
          onPressed: busy ? null : onPick,
          icon: busy
              ? SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.photo_library_outlined),
          label: Text(chooseLabel),
        ),
        OutlinedButton.icon(
          onPressed: hasImage && !busy ? onClear : null,
          icon: Icon(Icons.clear),
          label: Text(clearLabel),
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
