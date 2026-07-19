import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/category_tints.dart';
import '../../core/widgets/menu_image_view.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/menu_item.dart';
import '../desktop_pos/widgets/menu_line_customizer.dart';

/* ============================================================
   QuickBytes POS — Shared menu-order widgets (add-items step).
   Extracted from orders_screen.dart so Tables (counter mode)
   and the order wizard share the same menu-picker UI.
   ============================================================ */

// ── Menu add-items step (search, categories, content, cart footer) ──

class MenuStep extends StatefulWidget {
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
    required this.codeMode,
    required this.onSearchChanged,
    required this.onToggleCodeMode,
    required this.onCodeSubmit,
    required this.onCategorySelected,
    required this.onTap,
    required this.onDecrement,
    required this.onToggleFavorite,
    required this.onSetShortCode,
    this.categoryCounts,
    this.onSubmit,
    this.onResetFilters,
    this.title,
    this.onBack,
    this.leadingIsClose = false,
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

  /// When true the search bar becomes a numeric short-code entry and the body
  /// switches from the card grid to the short-code list (the ⚡ quick-pick mode).
  final bool codeMode;
  final Map<String, int>? categoryCounts;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleCodeMode;
  final ValueChanged<String> onCodeSubmit;
  final ValueChanged<String> onCategorySelected;
  final ValueChanged<MenuItem> onTap;
  final ValueChanged<String> onDecrement;
  final ValueChanged<MenuItem> onToggleFavorite;
  final ValueChanged<MenuItem> onSetShortCode;
  final VoidCallback? onSubmit;

  /// Clears the category + search filters — the empty state's "Show all"
  /// escape hatch so a stale filter can never dead-end the picker.
  final VoidCallback? onResetFilters;

  /// Optional Petpooja-style top bar (back/close + title). When null the host
  /// already supplies its own header (e.g. Tables counter mode under AppScaffold).
  final String? title;
  final VoidCallback? onBack;
  final bool leadingIsClose;

  @override
  State<MenuStep> createState() => _MenuStepState();
}

class _MenuStepState extends State<MenuStep> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopControls(
          title: widget.title,
          onLeading: widget.onBack,
          leadingIsClose: widget.leadingIsClose,
        ),
        _MenuSearchBar(
          searchCtrl: widget.searchCtrl,
          query: widget.query,
          codeMode: widget.codeMode,
          onSearchChanged: widget.onSearchChanged,
          onCodeSubmit: widget.onCodeSubmit,
          onToggleCode: widget.onToggleCodeMode,
        ),
        if (!widget.codeMode)
          CategoryChips(
            categories: widget.categories,
            selected: widget.selectedCategory,
            counts: widget.categoryCounts,
            onSelected: widget.onCategorySelected,
          ),
        Expanded(
          child: widget.codeMode
              ? _ShortCodeList(
                  items: widget.visibleItems,
                  cart: widget.cart,
                  onTap: widget.onTap,
                  onDecrement: widget.onDecrement,
                )
              : _MenuContent(
                  items: widget.visibleItems,
                  cart: widget.cart,
                  onTap: widget.onTap,
                  onDecrement: widget.onDecrement,
                  onToggleFavorite: widget.onToggleFavorite,
                  onSetShortCode: widget.onSetShortCode,
                  onResetFilters: widget.onResetFilters,
                ),
        ),
        CartFooter(onSubmit: widget.onSubmit),
      ],
    );
  }
}

// ── Top control bar (optional back/close + title) ──

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.title,
    required this.onLeading,
    required this.leadingIsClose,
  });

  final String? title;
  final VoidCallback? onLeading;
  final bool leadingIsClose;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null;
    return Container(
      color: PosColors.primary,
      padding: EdgeInsets.fromLTRB(16, hasTitle ? 12 : 6, 16, 4),
      child: Row(
        children: [
          if (onLeading != null) ...[
            GestureDetector(
              onTap: onLeading,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  leadingIsClose ? TfNavIcon.close : TfNavIcon.back,
                  size: 24,
                  color: PosColors.accentInk,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (hasTitle)
            Expanded(
              child: TfText(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TfTextStyles.pushedTitle.copyWith(
                  color: PosColors.accentInk,
                ),
              ),
            )
          else
            const Spacer(),
        ],
      ),
    );
  }
}

class _MenuSearchBar extends StatefulWidget {
  const _MenuSearchBar({
    required this.searchCtrl,
    required this.query,
    required this.codeMode,
    required this.onSearchChanged,
    required this.onCodeSubmit,
    required this.onToggleCode,
  });

  final TextEditingController searchCtrl;
  final String query;
  final bool codeMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCodeSubmit;
  final VoidCallback onToggleCode;

  @override
  State<_MenuSearchBar> createState() => _MenuSearchBarState();
}

class _MenuSearchBarState extends State<_MenuSearchBar> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  bool get _focused => _focusNode.hasFocus;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.selectMany(context, const [AppAspect.language]).strings;
    final borderColor = _focused ? PosColors.primary : PosColors.line;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: PosColors.surface,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(PosRadii.card),
          boxShadow: PosShadows.soft,
        ),
        child: Stack(
          children: [
            TextField(
              controller: widget.searchCtrl,
              onChanged: widget.onSearchChanged,
              autofocus: false,
              focusNode: _focusNode,
              keyboardType: widget.codeMode ? TextInputType.number : TextInputType.text,
              textInputAction: widget.codeMode ? TextInputAction.go : TextInputAction.search,
              onSubmitted: widget.codeMode ? widget.onCodeSubmit : null,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: widget.codeMode ? text.shortCodeSearchHint : text.searchByName,
                prefixIcon: Icon(
                  widget.codeMode ? Icons.tag_rounded : Icons.search_rounded,
                  color: PosColors.muted,
                ),
                suffixIcon: widget.query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          widget.searchCtrl.clear();
                          widget.onSearchChanged('');
                        },
                        icon: Icon(Icons.close_rounded, color: PosColors.muted),
                      ),
                contentPadding: const EdgeInsets.only(top: 10, bottom: 10, left: 12, right: 90),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onTap: widget.onToggleCode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: widget.codeMode ? PosColors.primary : PosColors.surface,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(PosRadii.card),
                        bottomRight: Radius.circular(PosRadii.card),
                      ),
                      border: const Border(
                        left: BorderSide(color: PosColors.lineStrong),
                        top: BorderSide(color: PosColors.lineStrong),
                        bottom: BorderSide(color: PosColors.lineStrong),
                      ),
                    ),
                  alignment: Alignment.center,
                  child: Text(
                    text.quickBill,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: widget.codeMode ? FontWeight.w600 : FontWeight.w500,
                      color: widget.codeMode ? PosColors.accentInk : PosColors.primaryDark,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category segmented bar ──

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
    final text = AppScope.selectMany(context, const [AppAspect.language]).strings;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: PosSpacing.sp4,
          vertical: 4,
        ),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final cat = categories[i];
          final sel = cat == selected;
          final label = cat == 'All' ? text.categoryAll : cat;
          final count = counts?[cat];
          return TfChip(
            label: label,
            count: count,
            active: sel,
            small: true,
            onTap: () => onSelected(cat),
          );
        },
      ),
    );
  }
}

// ── Menu content (Petpooja "Items": 2-col card grid grouped under sticky
//    category section headers — DESIGN.md §5 / Part 0) ──

class _MenuContent extends StatelessWidget {
  const _MenuContent({
    required this.items,
    required this.cart,
    required this.onTap,
    required this.onDecrement,
    required this.onToggleFavorite,
    required this.onSetShortCode,
    this.onResetFilters,
  });

  final List<MenuItem> items;
  final Map<String, int> cart;
  final ValueChanged<MenuItem> onTap;
  final ValueChanged<String> onDecrement;
  final ValueChanged<MenuItem> onToggleFavorite;
  final ValueChanged<MenuItem> onSetShortCode;
  final VoidCallback? onResetFilters;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      final text = AppScope.selectMany(context, const [AppAspect.language]).strings;
      return CustomScrollView(
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TfText(
                    text.noItemsInCategory,
                    style: TfTextStyles.body.copyWith(color: PosColors.muted),
                  ),
                  if (onResetFilters != null) ...[
                    const SizedBox(height: PosSpacing.sp3),
                    TfButton(
                      label: text.isBn ? 'সব দেখান' : 'Show all',
                      variant: TfButtonVariant.ghost,
                      size: TfButtonSize.sm,
                      fullWidth: false,
                      onPressed: onResetFilters,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            PosSpacing.sp4,
            PosDensity.gridGap,
            PosSpacing.sp4,
            PosDensity.sectionGap,
          ),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              mainAxisExtent: PosDensity.tileMenu,
            ),
            delegate: SliverChildBuilderDelegate((_, i) {
              final item = items[i];
              return _GridTile(
                item: item,
                qty: cart[item.id] ?? 0,
                onTap: () => onTap(item),
                onDecrement: () => onDecrement(item.id),
                onToggleFavorite: () => onToggleFavorite(item),
                onSetShortCode: () => onSetShortCode(item),
              );
            }, childCount: items.length),
          ),
        ),
      ],
    );
  }
}

// ── Qty stepper (item sheet) ──

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
              style: TfTextStyles.rowTitle.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
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

// ── Grid card tile (Petpooja "Items": price top-left · centered name ·
//    "customizable*" strip when modifiers exist · inline stepper + count badge
//    when in cart · long-press for favourite + short code) ──

class _GridTile extends StatelessWidget {
  const _GridTile({
    required this.item,
    required this.qty,
    required this.onTap,
    required this.onDecrement,
    required this.onToggleFavorite,
    required this.onSetShortCode,
  });

  final MenuItem item;
  final int qty;
  final VoidCallback onTap;
  final VoidCallback onDecrement;
  final VoidCallback onToggleFavorite;
  final VoidCallback onSetShortCode;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.selectMany(context, const [AppAspect.language]);
    debugPrint('[QB-WIZARD] _GridTile: building ${item.id} ${item.name} cat=${item.category}');
    final inCart = qty > 0;
    final off = !item.isAvailable;
    return GestureDetector(
      onTap: off ? null : onTap,
      onLongPress: () => _showItemActions(
        context,
        item: item,
        onToggleFavorite: onToggleFavorite,
        onSetShortCode: onSetShortCode,
      ),
      child: Opacity(
        opacity: off ? 0.5 : 1.0,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PosColors.surface,
            border: Border.all(color: PosColors.lineStrong),
            borderRadius: BorderRadius.circular(PosRadii.itemcard),
            boxShadow: PosShadows.soft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    PosSpacing.sp2,
                    PosSpacing.sp2,
                    PosSpacing.sp2,
                    (inCart && !off) ? 0 : PosSpacing.sp2,
                  ),
                  child: Stack(
                  children: [
                    Positioned.fill(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            PosSpacing.sp1,
                            PosSpacing.sp4,
                            PosSpacing.sp1,
                            2,
                          ),
                          child: TfText(
                            item.localizedName(app.language),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TfTextStyles.rowTitle.copyWith(
                              color: PosColors.primaryDark,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: inCart
                          ? _CountBadge(qty: qty)
                          : _PriceTag(price: item.price),
                    ),
                    if (off)
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        child: _OffBadge(),
                      ),
                  ],
                ),
              ),
              ),
              if (inCart && !off)
                _TileStepper(
                  qty: qty,
                  onDecrement: onDecrement,
                  onIncrement: onTap,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Full-width white qty stepper, flush with card edges.
class _TileStepper extends StatelessWidget {
  const _TileStepper({
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
      height: 34,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: PosColors.lineStrong),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDecrement,
              child: Container(
                decoration: const BoxDecoration(
                  color: PosColors.surface,
                  border: Border(
                    right: BorderSide(color: PosColors.lineStrong),
                  ),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.remove_rounded,
                  size: 18,
                  color: PosColors.secondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onIncrement,
              child: Container(
                color: PosColors.secondary,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add_rounded,
                  size: 18,
                  color: PosColors.onSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Running-count badge (top-right of an in-cart card).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.qty, this.compact = true});
  final int qty;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: compact ? 22 : 32),
      height: compact ? 22 : 32,
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: PosColors.secondary,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: TfText(
        tfFormatNumber(context, qty),
        style: TfTextStyles.label.copyWith(
          fontSize: compact ? null : 13,
          fontWeight: FontWeight.w800,
          color: PosColors.onSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// Price label (top-left of the card, Petpooja tile layout).
class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.price});
  final double price;

  @override
  Widget build(BuildContext context) {
    return TfText(
      tfFormatNumber(context, price),
      style: TfTextStyles.label.copyWith(
        fontSize: 9,
        fontWeight: FontWeight.w700,
        color: PosColors.ink2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _OffBadge extends StatelessWidget {
  const _OffBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      decoration: BoxDecoration(
        color: PosColors.danger,
        borderRadius: BorderRadius.circular(PosRadii.sm),
      ),
      child: Text(
        "86'd",
        style: TfTextStyles.eyebrow.copyWith(color: Colors.white),
      ),
    );
  }
}

// Long-press sheet: toggle favourite + set/clear short code.
Future<void> _showItemActions(
  BuildContext context, {
  required MenuItem item,
  required VoidCallback onToggleFavorite,
  required VoidCallback onSetShortCode,
}) {
  final text = AppScope.read(context).strings;
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                item.isFavorite
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: item.isFavorite ? PosColors.warning : PosColors.ink2,
              ),
              title: TfText(
                item.isFavorite ? text.removeFavourite : text.addFavourite,
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onToggleFavorite();
              },
            ),
            ListTile(
              leading: const Icon(Icons.tag_rounded, color: PosColors.ink2),
              title: TfText(
                item.shortCode == null
                    ? text.setShortCode
                    : '${text.setShortCode} (#${item.shortCode})',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onSetShortCode();
              },
            ),
          ],
        ),
      );
    },
  );
}

// ── Short-code list (⚡ mode): plain POS rows — bare code column + name; rows
//    already in the cart carry the standard blue selection wash + count ──

class _ShortCodeList extends StatelessWidget {
  const _ShortCodeList({
    required this.items,
    required this.cart,
    required this.onTap,
    required this.onDecrement,
  });

  final List<MenuItem> items;
  final Map<String, int> cart;
  final ValueChanged<MenuItem> onTap;
  final ValueChanged<String> onDecrement;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.selectMany(context, const [AppAspect.language]);
    if (items.isEmpty) {
      return Center(
        child: TfText(
          app.strings.noItemsInCategory,
          style: const TextStyle(color: PosColors.muted),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: PosColors.line),
      itemBuilder: (_, i) {
        final item = items[i];
        final off = !item.isAvailable;
        final qty = cart[item.id] ?? 0;
        final inCart = qty > 0;
        return InkWell(
          onTap: off ? null : () => onTap(item),
          child: Opacity(
            opacity: off ? 0.5 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(PosRadii.sm),
              ),
              child: Row(
                children: [
                  _CodeBadge(shortCode: item.shortCode),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TfText(
                      item.localizedName(app.language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TfTextStyles.rowTitle.copyWith(
                        color: PosColors.primaryDark,
                      ),
                    ),
                  ),
                  if (inCart) ...[
                    GestureDetector(
                      onTap: () => onDecrement(item.id),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: PosColors.surface,
                          border: Border.all(color: PosColors.lineStrong),
                          borderRadius: BorderRadius.circular(PosRadii.chip),
                        ),
                        child: Icon(
                          Icons.remove_rounded,
                          size: 16,
                          color: PosColors.primaryDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CountBadge(qty: qty, compact: false),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Short-code column (⚡ code mode): bare tabular digits, no chip, no '#' ──

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.shortCode});

  final int? shortCode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: TfText(
        shortCode == null ? '—' : '$shortCode',
        style: TfTextStyles.rowTitle.copyWith(
          fontWeight: FontWeight.w700,
          color: PosColors.ink2,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// ── Menu item image ──

class ItemImage extends StatelessWidget {
  const ItemImage({
    required this.url,
    required this.iconKey,
    this.category,
    super.key,
  });

  final String url;
  final String iconKey;
  final String? category;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Container(
      color: resolveCategoryBg(category ?? ''),
      child: LayoutBuilder(
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
      ),
    );
  }

  Widget _placeholder() => MenuImageView(imageUrl: null, iconKey: iconKey);
}

// ── Cart footer (white bar, single "Review order" primary button) ──

class CartFooter extends StatelessWidget {
  const CartFooter({this.onSubmit, super.key});

  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.selectMany(context, const [AppAspect.language]).strings;
    return TfStickyCTA(
      child: TfButton(
        label: text.reviewOrder,
        icon: TfNavIcon.check,
        size: TfButtonSize.lg,
        onPressed: onSubmit,
      ),
    );
  }
}

// ── Mobile item modifier sheet ──
// Bottom sheet (not dialog) matching the JSX ItemSheet design:
// header thumb+name+close, scrollable option/add-on sections with
// radio/checkbox buttons, expandable note, qty stepper + Add to order bar.

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
    final optDelta = _hasOptions
        ? _options[_selectedOptionIdx].priceDelta
        : 0.0;
    final addOnTotal = _selectedAddOnIdxs.fold<double>(
      0,
      (sum, i) => sum + _addOns[i].price,
    );
    return (base + optDelta + addOnTotal).clamp(0, double.infinity);
  }

  double get _lineTotal => _unitPrice * _qty;

  DesktopMenuLineSelection _buildSelection() {
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();
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
    final app = AppScope.selectMany(context, const [AppAspect.language]);
    final isBn = app.strings.isBn;
    final extras = widget.item.extras;
    final iconKey = resolveMenuIconKey(
      iconKey: extras.iconKey,
      name: widget.item.name,
      category: widget.item.category,
    );

    final eyebrowStyle = TfTextStyles.eyebrow.copyWith(color: PosColors.muted);

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
              borderRadius: BorderRadius.circular(PosRadii.pill),
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
                      category: widget.item.category,
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
                        style: TfTextStyles.pushedTitle.copyWith(
                          letterSpacing: -0.18,
                        ),
                      ),
                      if (widget.item.description.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          widget.item.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TfTextStyles.bodyMuted,
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
                        Text(isBn ? 'অপশন' : 'OPTIONS', style: eyebrowStyle),
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
                            style: TfTextStyles.eyebrow.copyWith(
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0,
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
                          style: TfTextStyles.label.copyWith(
                            fontWeight: FontWeight.w500,
                            color: PosColors.mutedSoft,
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
                              style: TfTextStyles.rowTitle.copyWith(
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
              autofocus: false,
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
                        onTap: () => Navigator.pop(context, _buildSelection()),
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
                                  isBn ? 'অর্ডারে যোগ করুন' : 'Add to order',
                                  style: TfTextStyles.price.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: PosColors.accentInk,
                                    fontFeatures: const [],
                                  ),
                                ),
                              ),
                              Text(
                                tfFormatCurrency(context, _lineTotal),
                                style: TfTextStyles.price.copyWith(
                                  color: PosColors.accentInk,
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
  final bool
  isRadio; // true = circular radio indicator, false = square checkbox
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
            // Indicator dot/box
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: isRadio ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isRadio
                    ? null
                    : BorderRadius.circular(PosRadii.sm),
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
                style: TfTextStyles.price.copyWith(
                  fontWeight: FontWeight.w500,
                  color: PosColors.primaryDark,
                  fontFeatures: const [],
                ),
              ),
            ),
            if (priceDelta > 0.005) ...[
              const SizedBox(width: 8),
              Text(
                '+${tfFormatCurrency(context, priceDelta)}',
                style: TfTextStyles.rowTitle.copyWith(
                  color: PosColors.accentStrong,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
