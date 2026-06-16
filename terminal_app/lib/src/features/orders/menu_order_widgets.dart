import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/menu_item.dart';
import 'widgets/menu_line_customizer.dart';

/* ============================================================
   QuickBytes POS — Shared menu-order widgets (add-items step).
   Extracted from orders_screen.dart so Tables (counter mode)
   and the order wizard share the same menu-picker UI.
   ============================================================ */

enum MenuLayoutMode { list, grid }

// ── Menu add-items step (search, categories, content, cart footer) ──

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
    required this.gridCols,
    required this.onSearchChanged,
    required this.onLayoutChanged,
    required this.onGridColsChanged,
    required this.onCategorySelected,
    required this.onTap,
    required this.onDecrement,
    this.categoryCounts,
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
  final int gridCols;
  final Map<String, int>? categoryCounts;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<MenuLayoutMode> onLayoutChanged;
  final ValueChanged<int> onGridColsChanged;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<MenuItem> onTap;
  final ValueChanged<String> onDecrement;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
              _ViewToggle(
                mode: layoutMode,
                cols: gridCols,
                onModeChanged: onLayoutChanged,
                onColsChanged: onGridColsChanged,
              ),
            ],
          ),
        ),
        CategoryChips(
          categories: categories,
          selected: selectedCategory,
          counts: categoryCounts,
          onSelected: onCategorySelected,
        ),
        Expanded(
          child: _MenuContent(
            items: visibleItems,
            categories: categories,
            selectedCategory: selectedCategory,
            cart: cart,
            mode: layoutMode,
            gridCols: gridCols,
            onTap: onTap,
            onDecrement: onDecrement,
          ),
        ),
        CartFooter(
          cart: cart,
          total: total,
          totalQty: totalQty,
          onSubmit: onSubmit,
        ),
      ],
    );
  }
}

// ── View toggle (segmented list|grid + column picker) ──

class _ViewToggle extends StatefulWidget {
  const _ViewToggle({
    required this.mode,
    required this.cols,
    required this.onModeChanged,
    required this.onColsChanged,
  });

  final MenuLayoutMode mode;
  final int cols;
  final ValueChanged<MenuLayoutMode> onModeChanged;
  final ValueChanged<int> onColsChanged;

  @override
  State<_ViewToggle> createState() => _ViewToggleState();
}

class _ViewToggleState extends State<_ViewToggle> {
  OverlayEntry? _overlay;
  final _colBtnKey = GlobalKey();

  void _openColMenu() {
    final box = _colBtnKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;

    _overlay = OverlayEntry(builder: (ctx) {
      return Stack(
        children: [
          // Dismiss scrim
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeColMenu,
            ),
          ),
          // Dropdown
          Positioned(
            top: pos.dy + size.height + 4,
            left: pos.dx + size.width - 122,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 122,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: PosColors.surface,
                  border: Border.all(color: PosColors.lineStrong),
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  boxShadow: PosShadows.raised,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [2, 3, 4].map((n) {
                    final sel = n == widget.cols;
                    return GestureDetector(
                      onTap: () {
                        widget.onColsChanged(n);
                        _closeColMenu();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 9,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: sel
                              ? PosColors.primarySoft
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(PosRadii.sm),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 15,
                              color: sel
                                  ? PosColors.accentStrong
                                  : PosColors.inkSoft,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$n columns',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: sel
                                      ? PosColors.accentStrong
                                      : PosColors.inkSoft,
                                ),
                              ),
                            ),
                            if (sel)
                              Icon(
                                Icons.check_rounded,
                                size: 15,
                                color: PosColors.accentStrong,
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      );
    });
    Overlay.of(context).insert(_overlay!);
    setState(() {});
  }

  void _closeColMenu() {
    _overlay?.remove();
    _overlay = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isGrid = widget.mode == MenuLayoutMode.grid;
    final colMenuOpen = _overlay != null;

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        border: Border.all(color: PosColors.line),
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegBtn(
            icon: Icons.list_rounded,
            active: widget.mode == MenuLayoutMode.list,
            width: 40,
            height: 38,
            onTap: () => widget.onModeChanged(MenuLayoutMode.list),
          ),
          const SizedBox(width: 2),
          _SegBtn(
            icon: Icons.grid_view_rounded,
            active: isGrid && !colMenuOpen,
            width: 40,
            height: 38,
            onTap: () {
              widget.onModeChanged(MenuLayoutMode.grid);
              _closeColMenu();
            },
          ),
          if (isGrid) ...[
            const SizedBox(width: 2),
            _SegBtn(
              key: _colBtnKey,
              label: '${widget.cols}',
              icon: Icons.keyboard_arrow_down_rounded,
              active: colMenuOpen,
              width: 46,
              height: 38,
              onTap: colMenuOpen ? _closeColMenu : _openColMenu,
            ),
          ],
        ],
      ),
    );
  }
}

class _SegBtn extends StatelessWidget {
  const _SegBtn({
    required this.width,
    required this.height,
    required this.active,
    required this.onTap,
    this.icon,
    this.label,
    super.key,
  });

  final double width;
  final double height;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: active ? PosColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(PosRadii.sm),
          boxShadow: active ? [BoxShadow(color: Color(0x0D14180E), blurRadius: 16, offset: Offset(0, 6))] : const [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (label != null)
              Text(
                label!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? PosColors.primaryDark : PosColors.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            if (icon != null)
              Icon(
                icon,
                size: label != null ? 14 : 18,
                color: active ? PosColors.primaryDark : PosColors.muted,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Category chips row ──

class CategoryChips extends StatelessWidget {
  const CategoryChips({
    required this.categories,
    required this.selected,
    required this.onSelected,
    this.counts,
    super.key,
  });

  final List<String> categories;
  final String selected;
  final Map<String, int>? counts;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final allLabel = AppScope.of(context).strings.categoryAll;
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, top: 4, right: 16),
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
            count: counts?[cat],
            onTap: () => onSelected(cat),
          );
        },
      ),
    );
  }
}

// ── Menu content (grouped list or grid) ──

class _MenuContent extends StatelessWidget {
  const _MenuContent({
    required this.items,
    required this.categories,
    required this.selectedCategory,
    required this.cart,
    required this.mode,
    required this.gridCols,
    required this.onTap,
    required this.onDecrement,
  });

  final List<MenuItem> items;
  final List<String> categories;
  final String selectedCategory;
  final Map<String, int> cart;
  final MenuLayoutMode mode;
  final int gridCols;
  final ValueChanged<MenuItem> onTap;
  final ValueChanged<String> onDecrement;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: TfText(
                AppScope.of(context).strings.noItemsInCategory,
                style: const TextStyle(color: PosColors.muted),
              ),
            ),
          ),
        ],
      );
    }

    const padding = EdgeInsets.fromLTRB(16, 12, 16, 16);

    if (mode == MenuLayoutMode.list) {
      // Build category groups: when 'All', group by each category in order;
      // when a specific category is selected, one group with that header.
      final groups = <(String, List<MenuItem>)>[];
      if (selectedCategory == 'All') {
        for (final cat in categories) {
          if (cat == 'All') continue;
          final group = items.where((i) => i.category == cat).toList();
          if (group.isNotEmpty) groups.add((cat, group));
        }
      } else {
        groups.add((selectedCategory, items));
      }

      const eyebrowStyle = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: PosColors.muted,
      );

      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: padding,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                for (final (cat, catItems) in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cat.toUpperCase(), style: eyebrowStyle),
                        Text(
                          '${catItems.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PosColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (int i = 0; i < catItems.length; i++) ...[
                    _MenuListRow(
                      item: catItems[i],
                      qty: cart[catItems[i].id] ?? 0,
                      onTap: () => onTap(catItems[i]),
                      onDecrement: () => onDecrement(catItems[i].id),
                    ),
                    SizedBox(height: i < catItems.length - 1 ? 10 : 18),
                  ],
                ],
              ]),
            ),
          ),
        ],
      );
    }

    // Fixed card height: 54 image + 8 gap + ~58 text + 16 padding (8 each side).
    const mainAxisExtent = 136.0;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: gridCols,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: mainAxisExtent,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _GridTile(
                item: items[i],
                qty: cart[items[i].id] ?? 0,
                cols: gridCols,
                onTap: () => onTap(items[i]),
                onDecrement: () => onDecrement(items[i].id),
              ),
              childCount: items.length,
            ),
          ),
        ),
      ],
    );
  }
}

// ── List-mode item row ──

class _MenuListRow extends StatelessWidget {
  const _MenuListRow({
    required this.item,
    required this.qty,
    required this.onTap,
    required this.onDecrement,
  });

  final MenuItem item;
  final int qty;
  final VoidCallback onTap;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final inCart = qty > 0;
    final off = !(item.isAvailable);
    final extras = item.extras;
    final iconKey = resolveMenuIconKey(
      iconKey: extras.iconKey,
      name: item.name,
      category: item.category,
    );

    return GestureDetector(
      onTap: off ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: inCart ? PosColors.primarySoft : PosColors.surface,
          border: Border.all(
            color: inCart ? PosColors.primaryDeep : PosColors.line,
          ),
          borderRadius: BorderRadius.circular(PosRadii.lg),
        ),
        child: Opacity(
          opacity: off ? 0.5 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Thumb
              ClipRRect(
                borderRadius: BorderRadius.circular(PosRadii.md),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: ItemImage(url: item.imageUrl ?? '', iconKey: iconKey),
                ),
              ),
              const SizedBox(width: 12),
              // Mid
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TfText(
                      item.localizedName(app.language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      TfText(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: PosColors.muted,
                        ),
                      ),
                    ],
                    // Low stock indicator omitted — isAvailable covers stock state
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trail
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TfText(
                    tfFormatCurrency(context, item.price),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (off)
                    Text(
                      "86'd",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: PosColors.danger,
                      ),
                    )
                  else if (inCart)
                    _QtyStepperInline(
                      qty: qty,
                      onDecrement: onDecrement,
                      onIncrement: onTap,
                    )
                  else
                    _AddBtn(onTap: onTap),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Qty stepper (list row trail) ──

class _QtyStepperInline extends StatelessWidget {
  const _QtyStepperInline({
    required this.qty,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int qty;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperBtn(icon: Icons.remove_rounded, onTap: onDecrement),
          const SizedBox(width: 2),
          SizedBox(
            width: 30,
            child: TfText(
              tfFormatNumber(context, qty),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 2),
          _StepperBtn(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: PosColors.surface,
          border: Border.all(color: PosColors.lineStrong),
          borderRadius: BorderRadius.circular(PosRadii.sm),
        ),
        child: Icon(icon, size: 16, color: PosColors.primaryDark),
      ),
    );
  }
}

// ── Add button (lime, 44×44) ──

class _AddBtn extends StatelessWidget {
  const _AddBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: PosColors.primary,
          borderRadius: BorderRadius.circular(PosRadii.md),
        ),
        child: const Icon(
          Icons.add_rounded,
          size: 20,
          color: PosColors.accentInk,
        ),
      ),
    );
  }
}

// ── Grid-mode tile ──

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.item,
    required this.qty,
    required this.cols,
    required this.onTap,
    required this.onDecrement,
  });

  final MenuItem item;
  final int qty;
  final int cols;
  final VoidCallback onTap;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final inCart = qty > 0;
    final off = !(item.isAvailable);
    final extras = item.extras;
    final iconKey = resolveMenuIconKey(
      iconKey: extras.iconKey,
      name: item.name,
      category: item.category,
    );

    return GestureDetector(
      onTap: off ? null : onTap,
      child: Opacity(
        opacity: off ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: inCart ? PosColors.primarySoft : PosColors.surface,
            border: Border.all(
              color: inCart ? PosColors.primaryDeep : PosColors.line,
            ),
            borderRadius: BorderRadius.circular(PosRadii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image section — category tint bg, centered
              Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(PosRadii.card),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: ItemImage(
                          url: item.imageUrl ?? '',
                          iconKey: iconKey,
                        ),
                      ),
                    ),
                    if (inCart) ...[
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          height: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: PosColors.primary,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: TfText(
                            tfFormatNumber(context, qty),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: PosColors.accentInk,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 6,
                        left: 6,
                        child: GestureDetector(
                          onTap: onDecrement,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: PosColors.surface,
                              borderRadius: BorderRadius.circular(PosRadii.md),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x2E14180E),
                                  blurRadius: 3,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.remove_rounded,
                              size: 16,
                              color: PosColors.danger,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (off)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 3,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: PosColors.danger,
                            borderRadius: BorderRadius.circular(PosRadii.sm),
                          ),
                          child: const Text(
                            "86'd",
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Name
              TfText(
                item.localizedName(app.language),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: cols == 4 ? 12.0 : 13.0,
                  fontWeight: FontWeight.w500,
                  color: PosColors.primaryDark,
                  height: 1.25,
                ),
              ),
              const Spacer(),
              // Price
              TfText(
                tfFormatCurrency(context, item.price),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: PosColors.primaryDark,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
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

// ── Cart footer (white bar, single "Review order" primary button) ──

class CartFooter extends StatelessWidget {
  const CartFooter({
    required this.cart,
    required this.total,
    required this.totalQty,
    this.onSubmit,
    super.key,
  });

  final Map<String, int> cart;
  final double total;
  final int totalQty;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final hasItems = cart.isNotEmpty;

    return TfStickyCTA(
      child: _ReviewButton(
        count: totalQty,
        subtotal: total,
        label: text.reviewOrder,
        enabled: hasItems && onSubmit != null,
        onPressed: onSubmit,
      ),
    );
  }
}

// ── Mobile item modifier sheet ──

Future<DesktopMenuLineSelection?> showMobileItemSheet(
  BuildContext context, {
  required MenuItem item,
}) {
  return showModalBottomSheet<DesktopMenuLineSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: _MobileItemSheet(item: item),
    ),
  );
}

class _MobileItemSheet extends StatefulWidget {
  const _MobileItemSheet({required this.item});
  final MenuItem item;

  @override
  State<_MobileItemSheet> createState() => _MobileItemSheetState();
}

class _MobileItemSheetState extends State<_MobileItemSheet> {
  int _qty = 1;
  int _selectedOptionIdx = 0;
  final Set<int> _selectedAddOnIdxs = {};
  bool _noteOpen = false;
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  List<MenuOption> get _options => widget.item.extras.options;
  List<MenuAddOn> get _addOns => widget.item.extras.addOns;
  bool get _hasOptions => _options.isNotEmpty;
  bool get _hasAddOns => _addOns.isNotEmpty;

  double get _unitPrice {
    final base = widget.item.price;
    final optDelta = _hasOptions ? _options[_selectedOptionIdx].priceDelta : 0.0;
    final addOnTotal = _selectedAddOnIdxs.fold<double>(
      0,
      (sum, i) => sum + _addOns[i].price,
    );
    return (base + optDelta + addOnTotal).clamp(0, double.infinity);
  }

  double get _lineTotal => _unitPrice * _qty;

  DesktopMenuLineSelection _buildSelection() {
    final note =
        _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
    final DesktopMenuOption opt;
    if (_hasOptions) {
      final o = _options[_selectedOptionIdx];
      opt = DesktopMenuOption(label: o.name, priceDelta: o.priceDelta);
    } else {
      opt = const DesktopMenuOption(label: '');
    }
    final addOns = [
      for (int i = 0; i < _addOns.length; i++)
        if (_selectedAddOnIdxs.contains(i)) _addOns[i],
    ];
    return DesktopMenuLineSelection(
      item: widget.item,
      option: opt,
      addOns: addOns,
      qty: _qty,
      note: note,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isBn = app.strings.isBn;
    final extras = widget.item.extras;
    final iconKey = resolveMenuIconKey(
      iconKey: extras.iconKey,
      name: widget.item.name,
      category: widget.item.category,
    );

    const eyebrowStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: PosColors.muted,
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.94,
      ),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.xl)),
        boxShadow: PosShadows.raised,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle
          Container(
            width: 38,
            height: 4,
            margin: const EdgeInsets.only(top: 9, bottom: 2),
            decoration: BoxDecoration(
              color: PosColors.lineStrong,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header: thumb + name/desc + close X
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: ItemImage(
                      url: widget.item.imageUrl ?? '',
                      iconKey: iconKey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.localizedName(app.language),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.18,
                        ),
                      ),
                      if (widget.item.description.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          widget.item.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: PosColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      border: Border.all(color: PosColors.lineStrong),
                      borderRadius: BorderRadius.circular(PosRadii.md),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: PosColors.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Scrollable body: options, add-ons, note
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Options section (single-select radio)
                  if (_hasOptions) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isBn ? 'অপশন' : 'OPTIONS',
                          style: eyebrowStyle,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          height: 18,
                          decoration: BoxDecoration(
                            color: PosColors.surfaceSunk,
                            borderRadius: BorderRadius.circular(PosRadii.xs),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isBn ? 'আবশ্যিক' : 'Required',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: PosColors.ink2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    for (int i = 0; i < _options.length; i++) ...[
                      _OptionBtn(
                        label: _options[i].name,
                        priceDelta: _options[i].priceDelta,
                        selected: _selectedOptionIdx == i,
                        isRadio: true,
                        onTap: () => setState(() => _selectedOptionIdx = i),
                      ),
                      if (i < _options.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                  // Add-ons section (multi-select checkbox)
                  if (_hasAddOns) ...[
                    if (_hasOptions) const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          isBn ? 'এক্সট্রা' : 'ADD-ONS',
                          style: eyebrowStyle,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isBn ? 'ঐচ্ছিক' : 'Optional',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: PosColors.mutedSoft,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    for (int i = 0; i < _addOns.length; i++) ...[
                      _OptionBtn(
                        label: _addOns[i].name,
                        priceDelta: _addOns[i].price,
                        selected: _selectedAddOnIdxs.contains(i),
                        isRadio: false,
                        onTap: () => setState(() {
                          if (_selectedAddOnIdxs.contains(i)) {
                            _selectedAddOnIdxs.remove(i);
                          } else {
                            _selectedAddOnIdxs.add(i);
                          }
                        }),
                      ),
                      if (i < _addOns.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                  // Note section: collapsed "Add a kitchen note" link or textarea
                  const SizedBox(height: 18),
                  if (!_noteOpen)
                    GestureDetector(
                      onTap: () => setState(() => _noteOpen = true),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notes_rounded,
                              size: 18,
                              color: PosColors.accentStrong,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isBn
                                  ? 'রান্নাঘরের নোট যোগ করুন'
                                  : 'Add a kitchen note',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: PosColors.accentStrong,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Text(
                      isBn ? 'রান্নাঘরের নোট' : 'KITCHEN NOTE',
                      style: eyebrowStyle,
                    ),
                    const SizedBox(height: 9),
                    TextField(
                      controller: _noteCtrl,
                      autofocus: true,
                      maxLines: null,
                      minLines: 2,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: isBn
                            ? 'যেমন: ঝাল ছাড়া, কম তেল'
                            : 'e.g. no onion, less spicy',
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          // Bottom action bar: qty stepper + "Add to order {price}" button
          DecoratedBox(
            decoration: const BoxDecoration(
              color: PosColors.surface,
              border: Border(top: BorderSide(color: PosColors.line)),
              boxShadow: PosShadows.bar,
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Row(
                  children: [
                    _QtyStepperInline(
                      qty: _qty,
                      onDecrement: () {
                        if (_qty > 1) setState(() => _qty--);
                      },
                      onIncrement: () => setState(() => _qty++),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: () =>
                            Navigator.pop(context, _buildSelection()),
                        child: Container(
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: PosColors.primary,
                            borderRadius: BorderRadius.circular(PosRadii.md),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isBn
                                      ? 'অর্ডারে যোগ করুন'
                                      : 'Add to order',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: PosColors.accentInk,
                                  ),
                                ),
                              ),
                              Text(
                                tfFormatCurrency(context, _lineTotal),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: PosColors.accentInk,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Option / add-on selection button (radio or checkbox style) ──

class _OptionBtn extends StatelessWidget {
  const _OptionBtn({
    required this.label,
    required this.priceDelta,
    required this.selected,
    required this.isRadio,
    required this.onTap,
  });

  final String label;
  final double priceDelta;
  final bool selected;
  final bool isRadio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? PosColors.primarySoft : PosColors.surface,
          border: Border.all(
            color: selected ? PosColors.primaryDeep : PosColors.lineStrong,
          ),
          borderRadius: BorderRadius.circular(PosRadii.md),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: isRadio ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isRadio ? null : BorderRadius.circular(PosRadii.sm),
                border: Border.all(
                  color: selected
                      ? PosColors.accentStrong
                      : PosColors.lineStrong,
                  width: 2,
                ),
                color: selected ? PosColors.primary : Colors.transparent,
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: PosColors.accentInk,
                    )
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: PosColors.primaryDark,
                ),
              ),
            ),
            if (priceDelta > 0.005) ...[
              const SizedBox(width: 8),
              Text(
                '+${tfFormatCurrency(context, priceDelta)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PosColors.accentStrong,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewButton extends StatelessWidget {
  const _ReviewButton({
    required this.count,
    required this.subtotal,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final int count;
  final double subtotal;
  final String label;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: enabled ? PosColors.primary : PosColors.line,
        borderRadius: BorderRadius.circular(PosRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PosRadii.md),
              border: Border.all(
                color: enabled ? Colors.transparent : PosColors.line,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: enabled
                        ? PosColors.accentInk.withValues(alpha: 0.18)
                        : PosColors.muted.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  alignment: Alignment.center,
                  child: TfText(
                    tfFormatNumber(context, count),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: enabled ? PosColors.accentInk : PosColors.muted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TfText(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: enabled ? PosColors.accentInk : PosColors.muted,
                  ),
                ),
                const Spacer(),
                TfText(
                  tfFormatCurrency(context, subtotal),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: enabled ? PosColors.accentInk : PosColors.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
