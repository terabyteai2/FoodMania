import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/menu_item.dart';
import '../desktop_pos/widgets/menu_line_customizer.dart';

/* ============================================================
   QuickBytes POS — Shared menu-order widgets (add-items step).
   Extracted from orders_screen.dart so Tables (counter mode)
   and the order wizard share the same menu-picker UI.
   ============================================================ */

enum MenuLayoutMode { compactGrid, largeTiles }

// ── Menu add-items step (search, categories, grid, cart footer) ──

class MenuStep extends StatelessWidget {
  const MenuStep({
    required this.visibleItems,
    required this.categories,
    required this.selectedCategory,
    required this.cart,
    required this.lineCount,
    required this.total,
    required this.totalQty,
    required this.searchCtrl,
    required this.query,
    required this.layoutMode,
    required this.onSearchChanged,
    required this.onLayoutChanged,
    required this.onCategorySelected,
    required this.onTap,
    required this.onDecrement,
    this.onSubmit,
    super.key,
  });

  final List<MenuItem> visibleItems;
  final List<String> categories;
  final String selectedCategory;
  final Map<String, int> cart;
  final int lineCount;
  final double total;
  final int totalQty;
  final TextEditingController searchCtrl;
  final String query;
  final MenuLayoutMode layoutMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<MenuLayoutMode> onLayoutChanged;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<MenuItem> onTap;
  final ValueChanged<String> onDecrement;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isBn = text.isBn;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: text.searchMenuItems,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: PosColors.muted,
                    ),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              searchCtrl.clear();
                              onSearchChanged('');
                            },
                            icon: Icon(
                              Icons.close_rounded,
                              color: PosColors.muted,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TfIconButton(
                icon: Icons.grid_view_rounded,
                tooltip: isBn ? 'কম্প্যাক্ট গ্রিড' : 'Compact grid',
                dark: layoutMode == MenuLayoutMode.compactGrid,
                onPressed: () => onLayoutChanged(MenuLayoutMode.compactGrid),
              ),
              const SizedBox(width: 6),
              TfIconButton(
                icon: Icons.view_agenda_outlined,
                tooltip: isBn ? 'বড় টাইল' : 'Large tiles',
                dark: layoutMode == MenuLayoutMode.largeTiles,
                onPressed: () => onLayoutChanged(MenuLayoutMode.largeTiles),
              ),
            ],
          ),
        ),
        CategoryChips(
          categories: categories,
          selected: selectedCategory,
          onSelected: onCategorySelected,
        ),
        Expanded(
          child: MenuGrid(
            items: visibleItems,
            cart: cart,
            layoutMode: layoutMode,
            onTap: onTap,
            onDecrement: onDecrement,
          ),
        ),
        CartFooter(
          cart: cart,
          lineCount: lineCount,
          total: total,
          totalQty: totalQty,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

// ── Category chips row ──

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final allLabel = AppScope.of(context).strings.categoryAll;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final sel = cat == selected;
          final label = cat == 'All' ? allLabel : cat;
          return TfChip(
            label: label,
            active: sel,
            small: true,
            onTap: () => onSelected(cat),
          );
        },
      ),
    );
  }
}

// ── Menu items grid ──

class MenuGrid extends StatelessWidget {
  const MenuGrid({
    required this.items,
    required this.cart,
    required this.layoutMode,
    required this.onTap,
    required this.onDecrement,
    super.key,
  });

  final List<MenuItem> items;
  final Map<String, int> cart;
  final MenuLayoutMode layoutMode;
  final ValueChanged<MenuItem> onTap;
  final ValueChanged<String> onDecrement;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: TfText(
          AppScope.of(context).strings.noItemsInCategory,
          style: TextStyle(color: PosColors.muted),
        ),
      );
    }

    if (layoutMode == MenuLayoutMode.compactGrid) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisExtent: 108,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => CompactMenuTile(
          item: items[i],
          qty: cart[items[i].id] ?? 0,
          onTap: () => onTap(items[i]),
          onDecrement: () => onDecrement(items[i].id),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisExtent: 112,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) => MenuTile(
        item: items[i],
        qty: cart[items[i].id] ?? 0,
        onTap: () => onTap(items[i]),
        onDecrement: () => onDecrement(items[i].id),
      ),
    );
  }
}

// ── Compact menu tile (4-column grid) ──

class CompactMenuTile extends StatelessWidget {
  const CompactMenuTile({
    required this.item,
    required this.qty,
    required this.onTap,
    required this.onDecrement,
    super.key,
  });

  final MenuItem item;
  final int qty;
  final VoidCallback onTap;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final inCart = qty > 0;
    final extras = item.extras;
    final hasChoices = desktopMenuNeedsCustomization(item);
    final iconKey = resolveMenuIconKey(
      iconKey: extras.iconKey,
      name: item.name,
      category: item.category,
    );
    final fg = inCart ? PosColors.onInk : PosColors.slate;
    final muted = inCart ? PosColors.onInkSec : PosColors.muted;

    return Material(
      color: inCart ? PosColors.slate : PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.card),
            border: Border.all(
              color: inCart ? PosColors.primaryDark : PosColors.line,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(PosRadii.tile),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: ItemImage(
                          url: item.imageUrl ?? '',
                          iconKey: iconKey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: TfText(
                        item.localizedName(app.language),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: fg,
                          height: 1.1,
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(right: inCart ? 27 : 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TfText(
                              tfFormatCurrency(context, item.price),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: muted,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          if (hasChoices && !inCart) ...[
                            const SizedBox(width: 3),
                            Icon(
                              Icons.tune_rounded,
                              size: 10,
                              color: PosColors.muted,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (inCart) ...[
                Positioned(
                  top: 5,
                  right: 5,
                  child: GestureDetector(
                    onTap: onDecrement,
                    child: Container(
                      width: 21,
                      height: 21,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(PosRadii.tag),
                      ),
                      child: const Icon(
                        Icons.remove_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: PosColors.primarySoft,
                      borderRadius: BorderRadius.circular(PosRadii.tag),
                    ),
                    child: TfText(
                      tfFormatNumber(context, qty),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: PosColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Large menu tile (image-background grid) ──

class MenuTile extends StatelessWidget {
  const MenuTile({
    required this.item,
    required this.qty,
    required this.onTap,
    required this.onDecrement,
    super.key,
  });

  final MenuItem item;
  final int qty;
  final VoidCallback onTap;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final inCart = qty > 0;
    final extras = item.extras;
    final hasChoices = desktopMenuNeedsCustomization(item);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.card),
          border: Border.all(
            color: inCart ? PosColors.primaryDark : PosColors.line,
            width: inCart ? 2 : 1,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ItemImage(
              url: item.imageUrl ?? '',
              iconKey: resolveMenuIconKey(
                iconKey: extras.iconKey,
                name: item.name,
                category: item.category,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.0),
                    Colors.black.withValues(alpha: 0.72),
                  ],
                  stops: const [0.3, 1.0],
                ),
              ),
            ),
            if (inCart)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: PosColors.primaryDark.withValues(alpha: 0.22),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TfText(
                    item.localizedName(app.language),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 11.5,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TfText(
                          tfFormatCurrency(context, item.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      if (hasChoices) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.tune_rounded,
                          size: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (inCart)
              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: onDecrement,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(PosRadii.tag),
                        ),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: PosColors.primarySoft,
                        borderRadius: BorderRadius.circular(PosRadii.tag),
                      ),
                      child: TfText(
                        tfFormatNumber(context, qty),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                          color: PosColors.primaryDark,
                        ),
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
}

// ── Menu item image ──

class ItemImage extends StatelessWidget {
  const ItemImage({required this.url, required this.iconKey, super.key});

  final String url;
  final String iconKey;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxSide = [
          constraints.maxWidth.isFinite ? constraints.maxWidth : 96.0,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 96.0,
        ].reduce((a, b) => a > b ? a : b);
        final cachePx = (maxSide * dpr).round().clamp(64, 512);

        if (url.startsWith('data:image/')) {
          try {
            final bytes = base64Decode(url.split(',').last);
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              cacheWidth: cachePx,
              cacheHeight: cachePx,
            );
          } catch (_) {
            return _placeholder();
          }
        }
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          memCacheWidth: cachePx,
          memCacheHeight: cachePx,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => _placeholder(),
          errorWidget: (context, url, err) => _placeholder(),
        );
      },
    );
  }

  Widget _placeholder() => MenuImageView(imageUrl: null, iconKey: iconKey);
}

// ── Cart footer (sticky bar with qty badge, total, review button) ──

class CartFooter extends StatelessWidget {
  const CartFooter({
    required this.cart,
    required this.lineCount,
    required this.total,
    required this.totalQty,
    this.onSubmit,
    super.key,
  });

  final Map<String, int> cart;
  final int lineCount;
  final double total;
  final int totalQty;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final hasItems = cart.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: const BoxDecoration(color: PosColors.primaryDark),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: Row(
          children: [
            if (hasItems) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: PosColors.primarySoft,
                  borderRadius: BorderRadius.circular(PosRadii.tag),
                ),
                alignment: Alignment.center,
                child: TfText(
                  tfFormatNumber(context, totalQty),
                  style: TextStyle(
                    fontFamily: tfFontFamily(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PosColors.primaryDark,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TfText(
                      text.orderItemsLine(totalQty, lineCount),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.68),
                      ),
                    ),
                    const SizedBox(height: 2),
                    TfText(
                      tfFormatCurrency(context, total),
                      style: TextStyle(
                        fontFamily: tfFontFamily(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 30,
                        color: Colors.white,
                        letterSpacing: -0.3,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              Expanded(
                child: TfText(
                  text.tapItemsToAdd,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 13,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            TfButton(
              label: text.reviewAction,
              trailingIcon: TfNavIcon.arrow,
              size: TfButtonSize.md,
              fullWidth: false,
              onPressed: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
