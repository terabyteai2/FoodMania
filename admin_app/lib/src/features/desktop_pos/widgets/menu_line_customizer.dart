import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/widgets/menu_image_view.dart';
import '../../../models/menu_item.dart';
import '../../../models/order_item.dart';
import 'pc_theme.dart';

class DesktopMenuOption {
  const DesktopMenuOption({required this.label, this.priceDelta = 0});

  final String label;
  final double priceDelta;

  bool get hasPriceDelta => priceDelta.abs() >= 0.005;
}

class DesktopMenuLineSelection {
  const DesktopMenuLineSelection({
    required this.item,
    required this.option,
    required this.addOns,
    required this.qty,
    this.note,
  });

  final MenuItem item;
  final DesktopMenuOption option;
  final List<MenuAddOn> addOns;
  final int qty;
  final String? note;

  double get unitPrice {
    final addOnTotal = addOns.fold<double>(
      0,
      (sum, addOn) => sum + addOn.price,
    );
    final value = item.price + option.priceDelta + addOnTotal;
    return value < 0 ? 0 : double.parse(value.toStringAsFixed(2));
  }

  double get lineTotal => double.parse((unitPrice * qty).toStringAsFixed(2));

  String get modifierLabel {
    final labels = <String>[];
    final optionLabel = option.label.trim();
    if (optionLabel.isNotEmpty) labels.add(optionLabel);
    for (final addOn in addOns) {
      final name = addOn.name.trim();
      if (name.isNotEmpty) labels.add(name);
    }
    return labels.join(', ');
  }

  String get lineKey {
    return [
      item.id,
      option.label.trim().toLowerCase(),
      option.priceDelta.toStringAsFixed(2),
      for (final addOn in addOns) '${addOn.name}:${addOn.price}',
      note?.trim() ?? '',
    ].join('|');
  }

  String localizedDisplayName(AppLanguage language) {
    final base = item.localizedName(language);
    final mods = modifierLabel;
    return mods.isEmpty ? base : '$base ($mods)';
  }

  OrderRequestItem toRequestItem() {
    final mods = modifierLabel.trim();
    final cleanNote = note?.trim();
    return OrderRequestItem(
      menuItemId: item.id,
      qty: qty,
      note: cleanNote == null || cleanNote.isEmpty ? null : cleanNote,
      unitPrice: unitPrice,
      nameSuffix: mods.isEmpty ? null : mods,
    );
  }
}

Future<DesktopMenuLineSelection?> showDesktopMenuLineCustomizer(
  BuildContext context, {
  required MenuItem item,
  required bool isBn,
  int initialQty = 1,
}) {
  return showDialog<DesktopMenuLineSelection>(
    context: context,
    builder: (_) => _MenuLineCustomizerDialog(
      item: item,
      isBn: isBn,
      initialQty: initialQty,
    ),
  );
}

List<DesktopMenuOption> desktopMenuOptionsFor(MenuItem item) {
  final parsed = <DesktopMenuOption>[];
  for (final raw in item.tags) {
    final tag = raw.trim();
    if (tag.startsWith('size:')) {
      final option = _parseOptionTag(tag.substring(5));
      if (option != null) parsed.add(option);
    } else if (tag.startsWith('option:')) {
      final option = _parseOptionTag(tag.substring(7));
      if (option != null) parsed.add(option);
    }
  }
  if (parsed.isNotEmpty) return _dedupeOptions(parsed);
  return const [
    DesktopMenuOption(label: 'Small'),
    DesktopMenuOption(label: 'Medium'),
    DesktopMenuOption(label: 'Large'),
  ];
}

DesktopMenuOption? _parseOptionTag(String body) {
  final parts = body.split(':').map((part) => part.trim()).toList();
  parts.removeWhere((part) => part.isEmpty);
  if (parts.isEmpty) return null;
  if (parts.length == 1) return DesktopMenuOption(label: parts.first);
  final firstPrice = double.tryParse(parts.first);
  if (firstPrice != null) {
    return DesktopMenuOption(
      priceDelta: firstPrice,
      label: parts.skip(1).join(': ').trim(),
    );
  }
  final lastPrice = double.tryParse(parts.last);
  if (lastPrice != null) {
    return DesktopMenuOption(
      label: parts.take(parts.length - 1).join(': ').trim(),
      priceDelta: lastPrice,
    );
  }
  return DesktopMenuOption(label: parts.join(': '));
}

List<DesktopMenuOption> _dedupeOptions(List<DesktopMenuOption> options) {
  final seen = <String>{};
  final out = <DesktopMenuOption>[];
  for (final option in options) {
    final key =
        '${option.label.trim().toLowerCase()}|${option.priceDelta.toStringAsFixed(2)}';
    if (seen.add(key)) out.add(option);
  }
  return out;
}

class DesktopMenuThumb extends StatelessWidget {
  const DesktopMenuThumb({
    required this.item,
    this.size = 44,
    this.radius = 8,
    super.key,
  });

  final MenuItem item;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final extras = item.extras;
    final iconKey = resolveMenuIconKey(
      iconKey: extras.iconKey,
      name: item.name,
      category: item.category,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: MenuImageView(imageUrl: item.imageUrl, iconKey: iconKey),
      ),
    );
  }
}

class _MenuLineCustomizerDialog extends StatefulWidget {
  const _MenuLineCustomizerDialog({
    required this.item,
    required this.isBn,
    required this.initialQty,
  });

  final MenuItem item;
  final bool isBn;
  final int initialQty;

  @override
  State<_MenuLineCustomizerDialog> createState() =>
      _MenuLineCustomizerDialogState();
}

class _MenuLineCustomizerDialogState extends State<_MenuLineCustomizerDialog> {
  late final List<DesktopMenuOption> _options = desktopMenuOptionsFor(
    widget.item,
  );
  late DesktopMenuOption _option = _options.length > 1
      ? _options.firstWhere(
          (option) => option.label.toLowerCase() == 'medium',
          orElse: () => _options.first,
        )
      : _options.first;
  late int _qty = widget.initialQty < 1 ? 1 : widget.initialQty;
  final Set<int> _addOnIndexes = <int>{};
  final TextEditingController _note = TextEditingController();

  String tr(String en, String bn) => widget.isBn ? bn : en;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).language;
    final addOns = widget.item.extras.addOns;
    final selectedAddOns = [
      for (var i = 0; i < addOns.length; i++)
        if (_addOnIndexes.contains(i)) addOns[i],
    ];
    final selection = DesktopMenuLineSelection(
      item: widget.item,
      option: _option,
      addOns: selectedAddOns,
      qty: _qty,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    return AlertDialog(
      title: Text(tr('Customize item', 'আইটেম কাস্টমাইজ')),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DesktopMenuThumb(item: widget.item, size: 62, radius: 10),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.localizedName(lang),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Pc.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${pcMoney(widget.item.price)} base',
                          style: Pc.mono(12, color: Pc.textTer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                tr('Size / option', 'সাইজ / অপশন'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _options)
                    ChoiceChip(
                      selected: identical(option, _option),
                      label: Text(_optionLabel(option)),
                      onSelected: (_) => setState(() => _option = option),
                    ),
                ],
              ),
              if (addOns.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  tr('Add-ons', 'অ্যাড-অন'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < addOns.length; i++)
                  CheckboxListTile(
                    dense: true,
                    value: _addOnIndexes.contains(i),
                    contentPadding: EdgeInsets.zero,
                    title: Text(addOns[i].name),
                    secondary: addOns[i].price == 0
                        ? null
                        : Text('+${pcMoney(addOns[i].price)}'),
                    onChanged: (value) => setState(() {
                      if (value ?? false) {
                        _addOnIndexes.add(i);
                      } else {
                        _addOnIndexes.remove(i);
                      }
                    }),
                  ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                decoration: InputDecoration(
                  labelText: tr('Kitchen note', 'রান্নাঘরের নোট'),
                  hintText: tr(
                    'No chilli, extra sauce',
                    'ঝাল ছাড়া, এক্সট্রা সস',
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(tr('Quantity', 'পরিমাণ')),
                  const Spacer(),
                  IconButton(
                    onPressed: _qty <= 1
                        ? null
                        : () => setState(() => _qty -= 1),
                    icon: const Icon(Icons.remove),
                  ),
                  Text('$_qty', style: Pc.num(15)),
                  IconButton(
                    onPressed: () => setState(() => _qty += 1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Text(
                    tr('Line total', 'লাইন মোট'),
                    style: const TextStyle(color: Pc.textSec),
                  ),
                  const Spacer(),
                  Text(pcMoney(selection.lineTotal), style: Pc.num(18)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(tr('Cancel', 'বাতিল')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, selection),
          child: Text(tr('Add to ticket', 'টিকেটে যোগ করুন')),
        ),
      ],
    );
  }

  String _optionLabel(DesktopMenuOption option) {
    if (!option.hasPriceDelta) return option.label;
    final sign = option.priceDelta > 0 ? '+' : '';
    return '${option.label} $sign${pcMoney(option.priceDelta)}';
  }
}
