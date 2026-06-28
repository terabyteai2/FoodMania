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

// Card chrome tuned to the Petpooja "Items" source of truth — rounder than the
// global PosRadii.card (7) with a soft drop shadow (PosShadows.card is empty).
const double _kCardRadius = 14;
const List<BoxShadow> _kCardShadow = [
  BoxShadow(color: Color(0x0A14180E), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x0D14180E), blurRadius: 8, offset: Offset(0, 2)),
];

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

  /// Optional Petpooja-style top bar (back/close + title). When null the host
  /// already supplies its own header (e.g. Tables counter mode under AppScaffold).
  final String? title;
  final VoidCallback? onBack;
  final bool leadingIsClose;

  @override
  State<MenuStep> createState() => _MenuStepState();
}

class _MenuStepState extends State<MenuStep> {
  bool _searchExpanded = false;

  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (!_searchExpanded && !widget.codeMode) {
        widget.searchCtrl.clear();
        widget.onSearchChanged('');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Code mode forces the (numeric) entry bar open; otherwise the search field
    // is revealed only when the top-right search icon is tapped.
    final searchVisible = _searchExpanded || widget.codeMode;
    return Column(
      children: [
        _TopControls(
          title: widget.title,
          onLeading: widget.onBack,
          leadingIsClose: widget.leadingIsClose,
          codeActive: widget.codeMode,
          onToggleCode: widget.onToggleCodeMode,
          searchActive: searchVisible,
          onToggleSearch: _toggleSearch,
        ),
        if (searchVisible)
          _MenuSearchBar(
            searchCtrl: widget.searchCtrl,
            query: widget.query,
            codeMode: widget.codeMode,
            onSearchChanged: widget.onSearchChanged,
            onCodeSubmit: widget.onCodeSubmit,
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
              ? _ShortCodeList(items: widget.visibleItems, onTap: widget.onTap)
              : _MenuContent(
                  items: widget.visibleItems,
                  cart: widget.cart,
                  onTap: widget.onTap,
                  onDecrement: widget.onDecrement,
                  onToggleFavorite: widget.onToggleFavorite,
                  onSetShortCode: widget.onSetShortCode,
                ),
        ),
        CartFooter(onSubmit: widget.onSubmit),
      ],
    );
  }
}

// ── Top control bar (optional back/close + title · ⚡ short-code · 🔍 search) ──

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.title,
    required this.onLeading,
    required this.leadingIsClose,
    required this.codeActive,
    required this.onToggleCode,
    required this.searchActive,
    required this.onToggleSearch,
  });

  final String? title;
  final VoidCallback? onLeading;
  final bool leadingIsClose;
  final bool codeActive;
  final VoidCallback onToggleCode;
  final bool searchActive;
  final VoidCallback onToggleSearch;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final hasTitle = title != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, hasTitle ? 12 : 6, 16, 8),
      child: Row(
        children: [
          if (onLeading != null) ...[
            TfIconButton(
              icon: leadingIsClose ? TfNavIcon.close : TfNavIcon.back,
              tooltip: leadingIsClose
                  ? (text.isBn ? 'বাতিল' : 'Close')
                  : (text.isBn ? 'পেছনে' : 'Back'),
              onPressed: onLeading,
            ),
            const SizedBox(width: 12),
          ],
          if (hasTitle)
            Expanded(
              child: TfText(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: PosColors.slate,
                  height: 1.15,
                ),
              ),
            )
          else
            const Spacer(),
          _SquareToggle(
            icon: Icons.bolt_rounded,
            active: codeActive,
            onTap: onToggleCode,
          ),
          const SizedBox(width: 8),
          _SquareToggle(
            icon: Icons.search_rounded,
            active: searchActive,
            onTap: onToggleSearch,
          ),
        ],
      ),
    );
  }
}

class _SquareToggle extends StatelessWidget {
  const _SquareToggle({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active ? PosColors.primary : PosColors.surfaceSunk,
          border: Border.all(
            color: active ? PosColors.primary : PosColors.line,
          ),
          borderRadius: BorderRadius.circular(PosRadii.card),
        ),
        child: Icon(
          icon,
          size: 20,
          color: active ? PosColors.accentInk : PosColors.ink2,
        ),
      ),
    );
  }
}

class _MenuSearchBar extends StatelessWidget {
  const _MenuSearchBar({
    required this.searchCtrl,
    required this.query,
    required this.codeMode,
    required this.onSearchChanged,
    required this.onCodeSubmit,
  });

  final TextEditingController searchCtrl;
  final String query;
  final bool codeMode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCodeSubmit;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: TextField(
        controller: searchCtrl,
        onChanged: onSearchChanged,
        autofocus: true,
        keyboardType: codeMode ? TextInputType.number : TextInputType.text,
        textInputAction: codeMode ? TextInputAction.go : TextInputAction.search,
        onSubmitted: codeMode ? onCodeSubmit : null,
        decoration: InputDecoration(
          hintText: codeMode ? text.shortCodeSearchHint : text.searchByName,
          prefixIcon: Icon(
            codeMode ? Icons.tag_rounded : Icons.search_rounded,
            color: PosColors.muted,
          ),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    searchCtrl.clear();
                    onSearchChanged('');
                  },
                  icon: Icon(Icons.close_rounded, color: PosColors.muted),
                ),
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

// ── Menu content (Petpooja "Items" card grid, 2-col) ──

class _MenuContent extends StatelessWidget {
  const _MenuContent({
    required this.items,
    required this.cart,
    required this.onTap,
    required this.onDecrement,
    required this.onToggleFavorite,
    required this.onSetShortCode,
  });

  final List<MenuItem> items;
  final Map<String, int> cart;
  final ValueChanged<MenuItem> onTap;
  final ValueChanged<String> onDecrement;
  final ValueChanged<MenuItem> onToggleFavorite;
  final ValueChanged<MenuItem> onSetShortCode;

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

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 112,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _GridTile(
                item: items[i],
                qty: cart[items[i].id] ?? 0,
                onTap: () => onTap(items[i]),
                onDecrement: () => onDecrement(items[i].id),
                onToggleFavorite: () => onToggleFavorite(items[i]),
                onSetShortCode: () => onSetShortCode(items[i]),
              ),
              childCount: items.length,
            ),
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

// ── Grid card tile (Petpooja "Items": centered name · price/qty top-right ·
//    inline stepper when in cart · long-press for favourite + short code) ──

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
    final app = AppScope.of(context);
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
          padding: EdgeInsets.fromLTRB(10, 10, 10, inCart ? 8 : 10),
          decoration: BoxDecoration(
            color: inCart ? PosColors.primarySoft : PosColors.surface,
            border: Border.all(
              color: inCart ? PosColors.primary : PosColors.line,
            ),
            borderRadius: BorderRadius.circular(_kCardRadius),
            boxShadow: _kCardShadow,
          ),
          child: Stack(
            children: [
              // Centered name, with the inline stepper pinned to the bottom
              // once the item is in the cart.
              Positioned.fill(
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 14, 4, 2),
                          child: TfText(
                            item.localizedName(app.language),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: PosColors.primaryDark,
                              height: 1.2,
                            ),
                          ),
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
              // Top-right: price when idle, running count when in cart.
              Positioned(
                top: 0,
                right: 0,
                child: inCart
                    ? _CountBadge(qty: qty)
                    : _PriceTag(price: item.price),
              ),
              if (off) const Positioned(bottom: 0, left: 0, child: _OffBadge()),
            ],
          ),
        ),
      ),
    );
  }
}

// Full-width navy qty stepper, shown on cards that are in the cart.
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
      decoration: BoxDecoration(
        color: PosColors.secondary,
        borderRadius: BorderRadius.circular(PosRadii.lg),
      ),
      child: Row(
        children: [
          _TileStepBtn(icon: Icons.remove_rounded, onTap: onDecrement),
          Expanded(
            child: Center(
              child: TfText(
                tfFormatNumber(context, qty),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: PosColors.onSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          _TileStepBtn(icon: Icons.add_rounded, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _TileStepBtn extends StatelessWidget {
  const _TileStepBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 34,
        child: Icon(icon, size: 18, color: PosColors.onSecondary),
      ),
    );
  }
}

// Running-count badge (top-right of an in-cart card).
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.qty});
  final int qty;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: PosColors.secondary,
        borderRadius: BorderRadius.all(Radius.circular(999)),
      ),
      child: TfText(
        tfFormatNumber(context, qty),
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: PosColors.onSecondary,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

// Price label (top-right of an idle card).
class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.price});
  final double price;

  @override
  Widget build(BuildContext context) {
    return TfText(
      tfFormatCurrency(context, price),
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: PosColors.ink2,
        fontFeatures: [FontFeature.tabularFigures()],
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
      child: const Text(
        "86'd",
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
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
  final text = AppScope.of(context).strings;
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

// ── Short-code list (⚡ mode): short code + name, no price, no thumbnail ──

class _ShortCodeList extends StatelessWidget {
  const _ShortCodeList({required this.items, required this.onTap});

  final List<MenuItem> items;
  final ValueChanged<MenuItem> onTap;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
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
        return InkWell(
          onTap: off ? null : () => onTap(item),
          child: Opacity(
            opacity: off ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              child: Row(
                children: [
                  _CodeBadge(shortCode: item.shortCode),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TfText(
                      item.localizedName(app.language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PosColors.primaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Short-code badge (shown on cards in ⚡ code mode) ──

class _CodeBadge extends StatelessWidget {
  const _CodeBadge({required this.shortCode});

  final int? shortCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: PosColors.primarySoft,
        borderRadius: BorderRadius.circular(PosRadii.sm),
      ),
      child: TfText(
        shortCode == null ? '#—' : '#$shortCode',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: PosColors.accentStrong,
          fontFeatures: [FontFeature.tabularFigures()],
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
    final text = AppScope.of(context).strings;
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
                                  fontFeatures: [FontFeature.tabularFigures()],
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
