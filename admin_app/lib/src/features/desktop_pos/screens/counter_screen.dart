import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../app_scope.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/desktop_pos.dart';
import '../../../models/menu_item.dart';
import '../../../models/order_model.dart';
import '../../../models/order_payment_method.dart';
import '../../../models/order_service_type.dart';
import '../widgets/menu_line_customizer.dart';
import '../widgets/pc_shell.dart';
import '../widgets/pc_theme.dart';
import '../widgets/pc_widgets.dart';
import 'split_bill_dialog.dart';

/// 1 · Counter · Quick sell — the daily driver. Menu grid (left) + ticket panel
/// (right). Reuses [PosAppController.createDesktopOrder] / `settleDesktopOrder`.
class CounterScreen extends StatefulWidget {
  const CounterScreen({
    required this.chrome,
    required this.settings,
    required this.shift,
    required this.onRequireShift,
    required this.onOrderSaved,
    this.initialTableNo,
    super.key,
  });

  final PcChrome chrome;
  final DesktopPosSettings settings;
  final PosShift? shift;
  final String? initialTableNo;
  final VoidCallback onRequireShift;
  final ValueChanged<OrderModel> onOrderSaved;

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

enum _Mode {
  dineIn(OrderServiceType.dineIn),
  takeaway(OrderServiceType.takeaway),
  delivery(OrderServiceType.delivery);

  const _Mode(this.serviceType);
  final OrderServiceType? serviceType;
}

class _CounterScreenState extends State<CounterScreen> {
  final List<DesktopMenuLineSelection> _cartLines = [];
  final TextEditingController _search = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String _cat = 'all';
  _Mode _mode = _Mode.dineIn;
  int _covers = 2;
  PosDiscountPreset? _discount;
  OrderPaymentMethod _method = OrderPaymentMethod.cash;
  bool _busy = false;

  String tr(String en, String bn) => widget.chrome.isBn ? bn : en;

  @override
  void initState() {
    super.initState();
    if (widget.initialTableNo != null) _mode = _Mode.dineIn;
  }

  @override
  void dispose() {
    _search.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final lang = app.language;
    final available = app.menuItems
        .where((item) => item.isAvailable)
        .toList(growable: false);

    // category tabs
    final cats = <String, int>{};
    for (final item in available) {
      final c = item.localizedCategory(lang);
      cats[c] = (cats[c] ?? 0) + 1;
    }
    final query = _search.text.trim().toLowerCase();
    final menu = available
        .where((item) {
          final matchesCat =
              _cat == 'all' || item.localizedCategory(lang) == _cat;
          final matchesQuery =
              query.isEmpty || item.searchText(lang).contains(query);
          return matchesCat && matchesQuery;
        })
        .toList(growable: false);

    final selected = List<DesktopMenuLineSelection>.unmodifiable(_cartLines);
    final subtotal = selected.fold<double>(0, (s, line) => s + line.lineTotal);
    final discount = _discountValue(subtotal);
    final vat = subtotal * widget.settings.vatRatePercent / 100;
    final service = subtotal * widget.settings.serviceChargePercent / 100;
    final total = subtotal + vat + service - discount;

    return PcShell(
      chrome: widget.chrome,
      activeNav: PcNav.counter,
      title: tr('Counter · Quick sell', 'কাউন্টার · দ্রুত বিক্রি'),
      sub: tr(
        'Walk-in customer · no table · auto-print on settle',
        'ওয়াক-ইন · টেবিল ছাড়া · নিষ্পত্তিতে অটো-প্রিন্ট',
      ),
      topActions: [
        PcBtn(
          label: tr('Switch to dine-in', 'ডাইন-ইনে যান'),
          variant: PcVariant.ghost,
          icon: 'people',
          sk: 'F2',
          onTap: () => widget.chrome.onNav(PcNav.floor),
        ),
      ],
      footerHints: const [
        PcKey('F8', 'Search'),
        PcKey('Ctrl+P', 'Settle'),
        PcKey('Esc', 'Clear'),
      ],
      child: Row(
        children: [
          Expanded(child: _menuPane(lang, cats, menu)),
          _ticketPanel(lang, selected, subtotal, vat, service, discount, total),
        ],
      ),
    );
  }

  // ---- menu pane ----------------------------------------------------------
  Widget _menuPane(
    AppLanguage lang,
    Map<String, int> cats,
    List<MenuItem> menu,
  ) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final tabs = Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _catTab(
                    'all',
                    tr('All', 'সব'),
                    cats.values.fold(0, (a, b) => a + b),
                  ),
                  for (final entry in cats.entries)
                    _catTab(entry.key, entry.key, entry.value),
                ],
              );
              final search = TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText: tr('Find menu item', 'মেনু আইটেম খুঁজুন'),
                ),
              );
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    tabs,
                    const SizedBox(height: 10),
                    SizedBox(width: double.infinity, child: search),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: tabs),
                  const SizedBox(width: 12),
                  SizedBox(width: 240, child: search),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Expanded(
            child: menu.isEmpty
                ? Center(
                    child: Text(
                      tr('No matching items.', 'মিল পাওয়া যায়নি।'),
                      style: const TextStyle(color: Pc.textSec),
                    ),
                  )
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          mainAxisExtent: 122,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: menu.length,
                    itemBuilder: (_, i) => _menuTile(menu[i], lang),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _catTab(String id, String label, int count) {
    final on = _cat == id;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _cat = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: on ? Pc.ink : Colors.transparent,
            border: Border.all(color: on ? Pc.ink : Pc.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: on ? Pc.onInk : Pc.text,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: on
                      ? Colors.white.withValues(alpha: 0.14)
                      : Pc.surfaceAlt,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  '$count',
                  style: Pc.mono(
                    10.5,
                    color: on
                        ? Colors.white.withValues(alpha: 0.8)
                        : Pc.textTer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(MenuItem item, AppLanguage lang) {
    final qty = _cartLines
        .where((line) => line.item.id == item.id)
        .fold<int>(0, (sum, line) => sum + line.qty);
    final on = qty > 0;
    final hasAddOns = item.extras.addOns.isNotEmpty;
    final hasOptions = desktopConfiguredMenuOptionsFor(item).isNotEmpty;
    final hasChoices = hasAddOns || hasOptions;
    final tag = hasAddOns ? tr('ADD-ON', 'অ্যাড-অন') : tr('OPTION', 'অপশন');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _addMenuItem(item),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: on ? Pc.accentSoft : Pc.surface,
            border: Border.all(color: on ? Pc.accentSoft : Pc.border),
            borderRadius: BorderRadius.circular(Pc.rSm),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DesktopMenuThumb(item: item, size: 54, radius: Pc.rSm),
                      const Spacer(),
                      if (hasChoices)
                        Container(
                          constraints: const BoxConstraints(maxWidth: 86),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: hasAddOns ? Pc.goodSoft : Pc.surfaceAlt,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            tag.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Pc.mono(
                              9.5,
                              color: hasAddOns ? Pc.good : Pc.textTer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.localizedName(lang),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Pc.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(pcMoney(item.price), style: Pc.num(12.5)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '· ${item.localizedCategory(lang).toUpperCase()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Pc.mono(
                                9,
                                weight: FontWeight.w600,
                                color: Pc.textTer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (on)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 26),
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: Pc.ink,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Pc.bg, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text('$qty', style: Pc.num(12, color: Pc.onInk)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- ticket panel -------------------------------------------------------
  Widget _ticketPanel(
    AppLanguage lang,
    List<DesktopMenuLineSelection> selected,
    double subtotal,
    double vat,
    double service,
    double discount,
    double total,
  ) {
    return Container(
      width: 400,
      decoration: const BoxDecoration(
        color: Pc.surface,
        border: Border(left: BorderSide(color: Pc.border)),
      ),
      child: Column(
        children: [
          // header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Pc.border)),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PcEyebrow(
                      widget.initialTableNo == null
                          ? tr('Current ticket', 'বর্তমান টিকেট')
                          : tr(
                              'Table ${widget.initialTableNo}',
                              'টেবিল ${widget.initialTableNo}',
                            ),
                    ),
                    const SizedBox(height: 4),
                    Text(_modeLabel(), style: Pc.num(14, letterSpacing: -0.2)),
                  ],
                ),
                const Spacer(),
                if (selected.isNotEmpty)
                  PcBtn(
                    label: tr('Clear', 'পরিষ্কার'),
                    variant: PcVariant.ghost,
                    size: PcSize.sm,
                    icon: 'close',
                    onTap: () => setState(() {
                      _cartLines.clear();
                    }),
                  ),
              ],
            ),
          ),
          // mode + covers selector
          _serviceSelector(),
          // lines
          Expanded(
            child: selected.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        tr(
                          'Tap menu items to build a ticket.',
                          'টিকেট তৈরি করতে মেনু আইটেমে চাপুন।',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Pc.textSec),
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    children: [
                      for (var i = 0; i < selected.length; i++)
                        _ticketLine(selected[i], i == 0, lang),
                    ],
                  ),
          ),
          // totals + payment
          _totalsAndPayment(selected, subtotal, vat, service, discount, total),
        ],
      ),
    );
  }

  Widget _serviceSelector() {
    final modes = widget.initialTableNo != null
        ? [_Mode.dineIn]
        : [_Mode.dineIn, _Mode.takeaway, _Mode.delivery];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Pc.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            children: [
              for (final mode in modes)
                ChoiceChip(
                  selected: _mode == mode,
                  label: Text(_modeName(mode)),
                  onSelected: (_) => setState(() => _mode = mode),
                ),
            ],
          ),
          if (_mode == _Mode.dineIn) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                PcEyebrow(tr('Covers', 'কভার')),
                const SizedBox(width: 10),
                for (final n in [1, 2, 3, 4, 5, 6])
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _coverChip('$n', n),
                  ),
                _coverChip('7+', 7),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _coverChip(String label, int value) {
    final on = _covers == value;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => setState(() => _covers = value),
        child: Container(
          width: 28,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? Pc.accentSoft : Pc.surface,
            border: Border.all(color: on ? Pc.accent : Pc.border),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: Pc.num(11.5, color: on ? Pc.accent : Pc.textSec),
          ),
        ),
      ),
    );
  }

  Widget _ticketLine(
    DesktopMenuLineSelection line,
    bool first,
    AppLanguage lang,
  ) {
    final note = line.note ?? '';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: first ? Pc.accentWash : Colors.transparent,
        borderRadius: BorderRadius.circular(Pc.rSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DesktopMenuThumb(item: line.item, size: 32, radius: Pc.rXs),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.localizedDisplayName(lang),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(pcMoney(line.lineTotal), style: Pc.num(13.5)),
                  ],
                ),
                if (note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      '· $note',
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: Pc.warn,
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    PcQtyStep(
                      qty: line.qty,
                      onMinus: () => _change(line.lineKey, -1),
                      onPlus: () => _change(line.lineKey, 1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '@ ${pcMoney(line.unitPrice)}',
                      style: Pc.mono(
                        11,
                        weight: FontWeight.w600,
                        color: Pc.textTer,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () => _editLineNote(line),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: PcIcon('edit', size: 15, color: Pc.textTer),
                      ),
                    ),
                    InkWell(
                      onTap: () => _change(line.lineKey, -line.qty),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: PcIcon('close', size: 15, color: Pc.textTer),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalsAndPayment(
    List<DesktopMenuLineSelection> selected,
    double subtotal,
    double vat,
    double service,
    double discount,
    double total,
  ) {
    final disabled = selected.isEmpty || _busy;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Pc.border)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      child: Column(
        children: [
          if (widget.settings.discountPresets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DropdownButtonFormField<PosDiscountPreset?>(
                initialValue: _discount,
                isDense: true,
                decoration: InputDecoration(
                  isDense: true,
                  labelText: tr('Quick discount', 'দ্রুত ডিসকাউন্ট'),
                ),
                items: [
                  DropdownMenuItem(
                    value: null,
                    child: Text(tr('No discount', 'ডিসকাউন্ট নেই')),
                  ),
                  for (final p in widget.settings.discountPresets)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) => setState(() => _discount = v),
              ),
            ),
          _row(tr('Subtotal', 'সাবটোটাল'), subtotal),
          if (discount > 0)
            _row(tr('Discount', 'ডিসকাউন্ট'), -discount, color: Pc.late),
          if (service > 0)
            _row(
              '${tr('Service', 'সার্ভিস')} ${widget.settings.serviceChargePercent}%',
              service,
            ),
          if (vat > 0) _row('VAT ${widget.settings.vatRatePercent}%', vat),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                tr('Total due', 'মোট প্রদেয়'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(pcMoney(total), style: Pc.num(28, letterSpacing: -0.6)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _methodBtn(
                  tr('Cash', 'ক্যাশ'),
                  OrderPaymentMethod.cash,
                  'F9',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _methodBtn('bKash', OrderPaymentMethod.bkash, 'F10'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          PcBtn(
            label: tr(
              'Settle · ${pcMoney(total)}',
              'নিষ্পত্তি · ${pcMoney(total)}',
            ),
            variant: PcVariant.dark,
            size: PcSize.xl,
            icon: 'printer',
            sk: 'Ctrl+P',
            full: true,
            onTap: disabled
                ? null
                : () => _settle(
                    selected,
                    [PcSplitShare(fraction: 1, paymentMethod: _method)],
                    discount,
                    service,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _methodBtn(String label, OrderPaymentMethod method, String? sk) {
    final on = _method == method;
    return PcBtn(
      label: label,
      variant: on ? PcVariant.primary : PcVariant.surface,
      size: PcSize.lg,
      sk: sk,
      onTap: () => setState(() => _method = method),
    );
  }

  Widget _row(String label, double value, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, color: Pc.textSec)),
        const Spacer(),
        Text(
          pcMoney(value),
          style: Pc.num(12.5, weight: FontWeight.w600, color: color ?? Pc.text),
        ),
      ],
    ),
  );

  // ---- helpers / actions --------------------------------------------------
  String _modeLabel() => switch (_mode) {
    _Mode.dineIn => tr('Dine-in', 'ডাইন-ইন'),
    _Mode.takeaway => tr('Parcel', 'পার্সেল'),
    _Mode.delivery => tr('Delivery', 'ডেলিভারি'),
  };

  String _modeName(_Mode mode) => switch (mode) {
    _Mode.dineIn => tr('Dine-in', 'ডাইন-ইন'),
    _Mode.takeaway => tr('Parcel', 'পার্সেল'),
    _Mode.delivery => tr('Delivery', 'ডেলিভারি'),
  };

  Future<void> _addMenuItem(MenuItem item) async {
    final selections = desktopMenuNeedsCustomization(item)
        ? await showDesktopMenuLineCustomizerLines(
            context,
            item: item,
            isBn: widget.chrome.isBn,
          )
        : [desktopRegularMenuLine(item)];
    if (selections == null || selections.isEmpty || !mounted) return;
    setState(() {
      for (final selection in selections) {
        final index = _cartLines.indexWhere(
          (line) => line.lineKey == selection.lineKey,
        );
        if (index >= 0) {
          final current = _cartLines[index];
          _cartLines[index] = _copyLine(
            current,
            qty: current.qty + selection.qty,
          );
        } else {
          _cartLines.add(selection);
        }
      }
    });
  }

  void _change(String lineKey, int delta) => setState(() {
    final index = _cartLines.indexWhere((line) => line.lineKey == lineKey);
    if (index < 0) return;
    final line = _cartLines[index];
    final next = line.qty + delta;
    if (next <= 0) {
      _cartLines.removeAt(index);
    } else {
      _cartLines[index] = _copyLine(line, qty: next);
    }
  });

  DesktopMenuLineSelection _copyLine(
    DesktopMenuLineSelection line, {
    int? qty,
    String? note,
    bool clearNote = false,
  }) {
    return DesktopMenuLineSelection(
      item: line.item,
      option: line.option,
      addOns: line.addOns,
      qty: qty ?? line.qty,
      note: clearNote ? null : note ?? line.note,
    );
  }

  double _discountValue(double subtotal) {
    final p = _discount;
    if (p == null) return 0;
    return p.kind == 'fixed' ? p.value : subtotal * p.value / 100;
  }

  Future<void> _editLineNote(DesktopMenuLineSelection line) async {
    final lineKey = line.lineKey;
    final controller = TextEditingController(text: line.note ?? '');
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr('Kitchen note', 'রান্নাঘরের নোট')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: tr('e.g. no chilli, extra sauce', 'যেমন: ঝাল ছাড়া'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('Cancel', 'বাতিল')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(tr('Save note', 'সেভ')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (note != null) {
      setState(() {
        final index = _cartLines.indexWhere((item) => item.lineKey == lineKey);
        if (index < 0) return;
        _cartLines[index] = _copyLine(
          _cartLines[index],
          note: note,
          clearNote: note.trim().isEmpty,
        );
      });
    }
  }

  Future<void> _settle(
    List<DesktopMenuLineSelection> selected,
    List<PcSplitShare> shares,
    double discount,
    double service,
  ) async {
    if (widget.shift == null) {
      widget.onRequireShift();
      return;
    }
    setState(() => _busy = true);
    final app = AppScope.of(context);
    try {
      final order = await app.createDesktopOrder(
        requestedItems: [for (final line in selected) line.toRequestItem()],
        shift: widget.shift!,
        settings: widget.settings,
        serviceType: _mode.serviceType,
        tableNo: widget.initialTableNo,
        covers: _mode == _Mode.dineIn ? _covers : null,
        customerName: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      final serviceAmount =
          order.subtotal * widget.settings.serviceChargePercent / 100;
      final total =
          order.subtotal +
          order.vatAmount +
          order.deliveryCharge +
          serviceAmount -
          discount;
      final shareTotal = shares.fold<double>(0, (s, x) => s + x.fraction);
      if ((shareTotal - 1).abs() > 0.0001) {
        throw Exception(
          tr(
            'Split allocations must add up to the full bill.',
            'ভাগ করা পরিমাণের যোগফল সম্পূর্ণ বিলের সমান হতে হবে।',
          ),
        );
      }
      final lines = <PosSettlementLine>[];
      var allocated = 0.0;
      for (var i = 0; i < shares.length; i++) {
        final amount = i == shares.length - 1
            ? double.parse((total - allocated).toStringAsFixed(2))
            : double.parse((total * shares[i].fraction).toStringAsFixed(2));
        allocated += amount;
        lines.add(
          PosSettlementLine(
            eventId: const Uuid().v4(),
            paymentMethod: shares[i].paymentMethod.value,
            amount: amount,
            payerLabel: shares.length > 1 ? shares[i].payerLabel : null,
          ),
        );
      }
      final settled = await app.settleDesktopOrder(
        order: order,
        shift: widget.shift!,
        settlements: lines,
        discountPresetId: _discount?.id,
        discountLabel: _discount?.label,
        discountAmount: discount,
        serviceChargeRatePercent: widget.settings.serviceChargePercent,
        serviceChargeAmount: serviceAmount,
      );
      if (!mounted) return;
      setState(() {
        _cartLines.clear();
        _discount = null;
      });
      widget.onOrderSaved(settled);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
