import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/menu_item.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
import '../theme/desk_widgets.dart';
import 'menu_item_form.dart';

/// Menu management (petpooja12): a dense table of items with inline
/// availability toggle, plus add / edit / delete. Camera menu-scan is
/// intentionally excluded.
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final _searchCtl = TextEditingController();
  String _selectedCategory = 'All items';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          backgroundColor: PosColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  List<String> _categories(List<MenuItem> items) {
    final set = <String>{};
    for (final i in items) {
      final c = i.category.trim();
      if (c.isNotEmpty) set.add(c);
    }
    return set.toList()..sort();
  }

  int _countFor(String category, List<MenuItem> items) {
    if (category == 'All items') return items.length;
    return items.where((i) => i.category.trim() == category).length;
  }

  Future<void> _add() async {
    final items = AppScope.read(context).menuItems;
    await showMenuItemForm(context, categories: _categories(items));
  }

  Future<void> _edit(MenuItem item) async {
    final items = AppScope.read(context).menuItems;
    await showMenuItemForm(context, item: item, categories: _categories(items));
  }

  Future<void> _delete(MenuItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('“${item.name}” will be removed from the menu.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: PosColors.ink2)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: PosColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _act(() => AppScope.read(context).deleteMenuItem(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final allItems = app.menuItems;
    final cats = ['All items', ..._categories(allItems)];
    final query = _searchCtl.text.trim().toLowerCase();
    final items = allItems.where((i) {
      if (_selectedCategory != 'All items' && i.category.trim() != _selectedCategory) {
        return false;
      }
      if (query.isEmpty) return true;
      return i.name.toLowerCase().contains(query) ||
          i.category.toLowerCase().contains(query) ||
          (i.shortCode?.toString().contains(query) ?? false);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(allItems.length),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _categorySidebar(cats, allItems),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: deskCardDecoration(),
                    child: Column(
                      children: [
                        _headerRow(),
                        Expanded(
                          child: items.isEmpty
                              ? Center(
                                  child: Text('No menu items',
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: PosColors.muted)))
                              : ListView.separated(
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) => const Divider(
                                      height: 1, color: PosColors.line),
                                  itemBuilder: (_, i) => _row(items[i]),
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
      ],
    );
  }

  Widget _categorySidebar(List<String> cats, List<MenuItem> allItems) {
    return Container(
      width: 200,
      margin: const EdgeInsets.fromLTRB(20, 16, 0, 20),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: deskCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Text('Categories',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PosColors.muted)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: cats.length,
              itemBuilder: (_, i) {
                final c = cats[i];
                final active = c == _selectedCategory;
                final count = _countFor(c, allItems);
                return InkWell(
                  borderRadius: BorderRadius.circular(PosRadii.sm),
                  onTap: () => setState(() => _selectedCategory = c),
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: active ? PosColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(PosRadii.sm),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(c,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: active
                                      ? Colors.white
                                      : PosColors.ink)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.white.withValues(alpha: 0.25)
                                : PosColors.surfaceSunk,
                            borderRadius:
                                BorderRadius.circular(PosRadii.pill),
                          ),
                          child: Text('$count',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: active
                                      ? Colors.white
                                      : PosColors.muted)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 14),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: PosColors.ink2,
              side: const BorderSide(color: PosColors.lineStrong),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosRadii.sm)),
            ),
            onPressed: () {},
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Operations',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 18),
          const Text('Menu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Text('$total items',
              style: TextStyle(fontSize: 14, color: PosColors.muted)),
          const Spacer(),
          SizedBox(
            width: 280,
            height: 42,
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 20, color: PosColors.muted),
                hintText: 'Search items',
                filled: true,
                fillColor: PosColors.surfaceSunk,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add item',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      color: PosColors.surfaceSunk,
      child: Row(
        children: [
          SizedBox(width: 36, child: _eyebrow('')),
          Expanded(flex: 4, child: _eyebrow('ITEM NAME')),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _eyebrow('SHORT CODE'),
                const SizedBox(width: 4),
                Icon(Icons.unfold_more_rounded,
                    size: 14, color: PosColors.muted),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                _eyebrow('CATEGORY'),
                const SizedBox(width: 4),
                Icon(Icons.unfold_more_rounded,
                    size: 14, color: PosColors.muted),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _eyebrow('PRICE (৳)'),
                const SizedBox(width: 4),
                Icon(Icons.unfold_more_rounded,
                    size: 14, color: PosColors.muted),
              ],
            ),
          ),
          SizedBox(width: 110, child: _eyebrow('AVAILABLE')),
          const SizedBox(width: 92),
        ],
      ),
    );
  }

  Widget _row(MenuItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      color: PosColors.surface,
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Checkbox(
              value: false,
              onChanged: (_) {},
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Text(item.shortCode?.toString() ?? '—',
                style: TextStyle(fontSize: 14, color: PosColors.ink2)),
          ),
          Expanded(
            flex: 3,
            child: Text(item.category.isEmpty ? '—' : item.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: PosColors.ink2)),
          ),
          Expanded(
            flex: 2,
            child: Text(money(context, item.price),
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            width: 110,
            child: GestureDetector(
              onTap: () => _act(() => AppScope.read(context)
                  .toggleMenuAvailability(item.id, !item.isAvailable)),
              child: Tooltip(
                message: 'Tap to toggle availability',
                child: item.isAvailable
                    ? _availableOutlinePill()
                    : _unavailablePill(),
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: PosColors.ink2,
                  tooltip: 'Edit',
                  onPressed: () => _edit(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: PosColors.danger,
                  tooltip: 'Delete',
                  onPressed: () => _delete(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _availableOutlinePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: PosColors.success),
        borderRadius: BorderRadius.circular(PosRadii.pill),
      ),
      child: Text('Available',
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: PosColors.success)),
    );
  }

  Widget _unavailablePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: PosColors.dangerSoft,
        borderRadius: BorderRadius.circular(PosRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PosColors.danger,
            ),
          ),
          const SizedBox(width: 6),
          Text('Unavailable',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: PosColors.danger)),
        ],
      ),
    );
  }

  Widget _eyebrow(String text) => Text(text,
      style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: PosColors.muted));
}
