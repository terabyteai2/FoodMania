import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/menu_item.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
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
    final query = _searchCtl.text.trim().toLowerCase();
    final items = app.menuItems.where((i) {
      if (query.isEmpty) return true;
      return i.name.toLowerCase().contains(query) ||
          i.category.toLowerCase().contains(query) ||
          (i.shortCode?.toString().contains(query) ?? false);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _toolbar(app.menuItems.length),
        _headerRow(),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text('No menu items',
                      style: TextStyle(color: PosColors.muted)))
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: PosColors.line),
                  itemBuilder: (_, i) => _row(items[i]),
                ),
        ),
      ],
    );
  }

  Widget _toolbar(int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          const Text('Menu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Text('$total items',
              style: TextStyle(fontSize: 13, color: PosColors.muted)),
          const Spacer(),
          SizedBox(
            width: 260,
            height: 38,
            child: TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: PosColors.muted),
                hintText: 'Search',
                filled: true,
                fillColor: PosColors.surfaceSunk,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add item',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: PosColors.surfaceSunk,
      child: Row(
        children: [
          Expanded(flex: 4, child: _eyebrow('ITEM NAME')),
          Expanded(flex: 2, child: _eyebrow('SHORT CODE')),
          Expanded(flex: 3, child: _eyebrow('CATEGORY')),
          Expanded(flex: 2, child: _eyebrow('PRICE')),
          SizedBox(width: 90, child: _eyebrow('AVAILABLE')),
          const SizedBox(width: 84),
        ],
      ),
    );
  }

  Widget _row(MenuItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      color: PosColors.surface,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            flex: 2,
            child: Text(item.shortCode?.toString() ?? '—',
                style: TextStyle(fontSize: 13, color: PosColors.ink2)),
          ),
          Expanded(
            flex: 3,
            child: Text(item.category.isEmpty ? '—' : item.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: PosColors.ink2)),
          ),
          Expanded(
            flex: 2,
            child: Text(money(context, item.price),
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w700)),
          ),
          SizedBox(
            width: 90,
            child: Switch(
              value: item.isAvailable,
              activeThumbColor: PosColors.primary,
              onChanged: (v) => _act(
                  () => AppScope.read(context).toggleMenuAvailability(item.id, v)),
            ),
          ),
          SizedBox(
            width: 84,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  color: PosColors.ink2,
                  onPressed: () => _edit(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: PosColors.danger,
                  onPressed: () => _delete(item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eyebrow(String text) => Text(text,
      style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: PosColors.muted));
}
