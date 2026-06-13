import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/menu_item.dart';

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
                  borderRadius: BorderRadius.circular(PosRadii.card),
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
                          borderRadius: BorderRadius.circular(PosRadii.chip),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 15,
                              color: sel
                                  ? PosColors.accentStrong
                                  : PosColors.ink2,
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
                                      : PosColors.ink2,
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
        borderRadius: BorderRadius.circular(PosRadii.card),
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
          borderRadius: BorderRadius.circular(PosRadii.chip),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: PosColors.primaryDark.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : [],
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
            count: counts?[cat],
            onTap: () => onSelected(cat),
          );
        },
      ),
    );
  }
}

// ── Menu content (flat list or grid, no category headers) ──

class _MenuContent extends StatelessWidget {
  const _MenuContent({
    required this.items,
    required this.cart,
    required this.mode,
    required this.gridCols,
    required this.onTap,
    required this.onDecrement,
  });

  final List<MenuItem> items;
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
                style: TextStyle(color: PosColors.muted),
              ),
            ),
          ),
        ],
      );
    }

    const padding = EdgeInsets.fromLTRB(16, 8, 16, 16);

    if (mode == MenuLayoutMode.list) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: padding,
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => Padding(
                  padding: EdgeInsets.only(bottom: i < items.length - 1 ? 10 : 0),
                  child: _MenuListRow(
                    item: items[i],
                    qty: cart[items[i].id] ?? 0,
                    onTap: () => onTap(items[i]),
                    onDecrement: () => onDecrement(items[i].id),
                  ),
                ),
                childCount: items.length,
              ),
            ),
          ),
        ],
      );
    }

    // Grid mode — mainAxisExtent calculated from fixed content heights
    final thumbH = gridCols == 2 ? 130.0 : gridCols == 3 ? 88.0 : 64.0;
    final mainAxisExtent = gridCols == 2 ? 214.0 : gridCols == 3 ? 172.0 : 144.0;
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
                thumbH: thumbH,
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
                borderRadius: BorderRadius.circular(PosRadii.card),
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
                      const SizedBox(height: 1),
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
        borderRadius: BorderRadius.circular(PosRadii.card),
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
          borderRadius: BorderRadius.circular(PosRadii.chip),
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
          borderRadius: BorderRadius.circular(PosRadii.card),
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
    required this.thumbH,
    required this.onTap,
    required this.onDecrement,
  });

  final MenuItem item;
  final int qty;
  final int cols;
  final double thumbH;
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
    final textSize = cols == 4 ? 12.5 : 14.0;

    return GestureDetector(
      onTap: off ? null : onTap,
      child: Opacity(
        opacity: off ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
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
              // Image section
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(PosRadii.card),
                    child: SizedBox(
                      width: double.infinity,
                      height: thumbH,
                      child: ItemImage(
                        url: item.imageUrl ?? '',
                        iconKey: iconKey,
                      ),
                    ),
                  ),
                  if (inCart) ...[
                    // Minus button — top-LEFT
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
                            borderRadius: BorderRadius.circular(7),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x2E14180E),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 16,
                            color: PosColors.danger,
                          ),
                        ),
                      ),
                    ),
                    // Count badge — top-RIGHT
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
                          borderRadius: BorderRadius.circular(5),
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
              const SizedBox(height: 8),
              // Text section
              TfText(
                item.localizedName(app.language),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: textSize,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 3),
              TfText(
                tfFormatCurrency(context, item.price),
                style: TextStyle(
                  fontSize: textSize,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosColors.surface,
        border: const Border(top: BorderSide(color: PosColors.line)),
        boxShadow: PosShadows.bar,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _ReviewButton(
            count: totalQty,
            subtotal: total,
            label: text.reviewOrder,
            enabled: hasItems && onSubmit != null,
            onPressed: onSubmit,
          ),
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
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: 44,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: PosColors.primary,
            borderRadius: BorderRadius.circular(PosRadii.card),
          ),
          child: Row(
            children: [
              // Count badge
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: const Color(0xFF14180E).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: TfText(
                  tfFormatNumber(context, count),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: PosColors.accentInk,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TfText(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PosColors.accentInk,
                ),
              ),
              const Spacer(),
              TfText(
                tfFormatCurrency(context, subtotal),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PosColors.accentInk,
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
