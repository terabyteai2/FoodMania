import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/models/desktop_pos.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_model.dart';
import 'package:local_pos/src/models/order_service_type.dart';

import '../shell/desk_nav.dart';
import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
import 'cart_line.dart';
import 'item_customizer.dart';
import 'open_shift_dialog.dart';
import 'settle_flow.dart';

const _allCategory = '__all__';
const _favCategory = '__fav__';

/// The core register — 3-pane billing screen (petpooja13/14): category rail,
/// item grid + search, and the checkout/cart panel. Sits behind an open shift.
class BillingScreen extends StatefulWidget {
  const BillingScreen({this.seed, super.key});

  /// Optional table / service to pre-select (set when opened from Tables).
  final BillingSeed? seed;

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

enum _ActionStyle { primary, dark, outline }

class _BillingScreenState extends State<BillingScreen> {
  PosShift? _shift;
  DesktopPosSettings? _settings;
  bool _loading = true;
  String? _loadError;
  bool _busy = false;

  final List<CartLine> _cart = [];
  OrderServiceType _serviceType = OrderServiceType.dineIn;
  final _tableCtl = TextEditingController();

  String _category = _allCategory;
  final _searchCtl = TextEditingController();
  final _shortCodeCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final seed = widget.seed;
    if (seed != null) {
      _serviceType = seed.serviceType;
      if (seed.tableLabel != null) _tableCtl.text = seed.tableLabel!;
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _tableCtl.dispose();
    _searchCtl.dispose();
    _shortCodeCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final app = AppScope.read(context);
    try {
      final settings = await app.loadDesktopPosSettings();
      final shift = await app.currentDesktopShift();
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _shift = shift?.isOpen == true ? shift : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openRegister() async {
    final app = AppScope.read(context);
    final opening = await showOpenShiftDialog(context);
    if (opening == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final shift = await app.openDesktopShift(
        openingCash: opening,
        denominations: const {},
      );
      if (mounted) setState(() => _shift = shift);
    } catch (error) {
      _toast('Could not open register: ${_clean(error)}', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── cart ops ──────────────────────────────────────────────
  void _addLine(CartLine line) {
    final existing = _cart.indexWhere((l) => l.mergeKey == line.mergeKey);
    setState(() {
      if (existing >= 0) {
        _cart[existing].qty += line.qty;
      } else {
        _cart.add(line);
      }
    });
  }

  Future<void> _tapItem(MenuItem item) async {
    final needsCustomize =
        item.extras.options.isNotEmpty || item.extras.addOns.isNotEmpty;
    if (needsCustomize) {
      final line = await showItemCustomizer(context, item: item);
      if (line != null) _addLine(line);
    } else {
      _addLine(CartLine(item: item));
    }
  }

  void _changeQty(CartLine line, int delta) {
    setState(() {
      final next = line.qty + delta;
      if (next <= 0) {
        _cart.remove(line);
      } else {
        line.qty = next;
      }
    });
  }

  void _clearCart() => setState(_cart.clear);

  double get _subtotal =>
      _cart.fold(0, (sum, line) => sum + line.lineTotal);
  double get _vatRate => _settings?.vatRatePercent ?? 0;
  double get _vatAmount =>
      double.parse((_subtotal * _vatRate / 100).toStringAsFixed(2));
  double get _serviceChargeRate => _settings?.serviceChargePercent ?? 0;
  double get _serviceChargeAmount =>
      double.parse((_subtotal * _serviceChargeRate / 100).toStringAsFixed(2));
  double get _grandTotal => _subtotal + _vatAmount + _serviceChargeAmount;

  // ── order actions ─────────────────────────────────────────
  Future<OrderModel?> _createOrder() async {
    final app = AppScope.read(context);
    final shift = _shift, settings = _settings;
    if (shift == null || settings == null) return null;
    final tableNo = _serviceType == OrderServiceType.dineIn
        ? (_tableCtl.text.trim().isEmpty ? null : _tableCtl.text.trim())
        : null;
    return app.createDesktopOrder(
      requestedItems: [for (final l in _cart) l.toRequestItem()],
      shift: shift,
      settings: settings,
      serviceType: _serviceType,
      tableNo: tableNo,
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_cart.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _toast(_clean(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() => _run(() async {
        final order = await _createOrder();
        if (order == null || !mounted) return;
        _clearCart();
        _toast('Saved ${order.displaySequence}');
      });

  Future<void> _kot({required bool print}) => _run(() async {
        final app = AppScope.read(context);
        final order = await _createOrder();
        if (order == null) return;
        final withKot = await app.sendDesktopKot(order);
        // Printing is best-effort — a printer problem must not lose the KOT.
        final printed = print ? await _tryPrint(() => app.printOrderTicket(withKot)) : true;
        if (!mounted) return;
        _clearCart();
        _toast(printed
            ? 'KOT sent ${order.displaySequence}'
            : 'KOT sent ${order.displaySequence} · print failed');
      });

  /// Runs a print call, swallowing printer errors so the sale still completes.
  Future<bool> _tryPrint(Future<bool> Function() print) async {
    try {
      return await print();
    } catch (_) {
      return false;
    }
  }

  Future<void> _settle() => _run(() async {
        final app = AppScope.read(context);
        final order = await _createOrder();
        if (order == null || !mounted) return;
        final message =
            await runSettlement(context, app, order: order, shift: _shift!);
        if (!mounted) return;
        _clearCart();
        _toast(message ?? 'Order ${order.displaySequence} saved (not settled)');
      });

  // ── build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return _centered(Icons.error_outline_rounded,
          'Could not load register', _loadError!);
    }
    if (_shift == null) return _openRegisterView();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryRail(
          categories: _categories(),
          selected: _category,
          onSelect: (c) => setState(() => _category = c),
          itemCountFor: _categoryItemCount,
        ),
        Expanded(child: _itemPane()),
        _checkoutPanel(),
      ],
    );
  }

  Widget _openRegisterView() {
    return Center(
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.xl),
          border: Border.all(color: PosColors.line),
          boxShadow: PosShadows.soft,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_open_rounded,
                size: 34, color: PosColors.primary),
            const SizedBox(height: 12),
            Text('Register is closed',
                style: TextStyle(
                    fontSize: DeskTypography.h3,
                    fontWeight: FontWeight.w800,
                    color: PosColors.primaryDark)),
            const SizedBox(height: 6),
            Text('Open the register with a cash float to start billing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: DeskTypography.bodySmall,
                    color: PosColors.muted)),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: PosColors.primary),
                onPressed: _busy ? null : _openRegister,
                child: const Text('Open register',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── item pane ──
  List<String> _categories() {
    final app = AppScope.read(context);
    final set = <String>{};
    for (final item in app.menuItems) {
      final c = item.category.trim();
      if (c.isNotEmpty) set.add(c);
    }
    final list = set.toList()..sort();
    return [_favCategory, _allCategory, ...list];
  }

  int _categoryItemCount(String category) {
    final app = AppScope.read(context);
    if (category == _allCategory) {
      return app.menuItems.where((i) => i.isAvailable).length;
    }
    if (category == _favCategory) {
      return app.menuItems.where((i) => i.isAvailable && i.isFavorite).length;
    }
    return app.menuItems
        .where((i) => i.isAvailable && i.category.trim() == category)
        .length;
  }

  List<MenuItem> _visibleItems() {
    final app = AppScope.read(context);
    final query = _searchCtl.text.trim().toLowerCase();
    return app.menuItems.where((item) {
      if (!item.isAvailable) return false;
      if (_category == _favCategory && !item.isFavorite) return false;
      if (_category != _allCategory && _category != _favCategory && item.category.trim() != _category) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          (item.shortCode?.toString().contains(query) ?? false);
    }).toList();
  }

  void _submitShortCode(String raw) {
    final code = int.tryParse(raw.trim());
    if (code == null) return;
    final app = AppScope.read(context);
    final match = app.menuItems
        .where((i) => i.isAvailable && i.shortCode == code)
        .toList();
    if (match.isNotEmpty) {
      _tapItem(match.first);
      _shortCodeCtl.clear();
    }
  }

  Widget _itemPane() {
    final items = _visibleItems();
    return Container(
      color: PosColors.background,
      child: Column(
        children: [
          Container(
            color: PosColors.surface,
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: _searchField(
                    _searchCtl,
                    'Search item',
                    Icons.search_rounded,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 180,
                  child: _searchField(
                    _shortCodeCtl,
                    'Short Code',
                    Icons.tag_rounded,
                    onSubmitted: _submitShortCode,
                    numeric: true,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text('No items',
                        style: TextStyle(
                            fontSize: 15, color: PosColors.muted)))
                : GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisExtent: 64,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, i) =>
                        _ItemCard(item: items[i], onTap: () => _tapItem(items[i])),
                  ),
          ),
        ],
      ),
    );
  }

  // ── checkout ──
  String _selectedPayment = 'Cash';

  Widget _checkoutPanel() {
    final lang = AppScope.of(context).language;
    return Container(
      width: DeskMetrics.checkoutWidth,
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(left: BorderSide(color: PosColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ServiceTabs(
            selected: _serviceType,
            onSelect: (s) => setState(() => _serviceType = s),
          ),
          if (_serviceType == OrderServiceType.dineIn) _tableSelectorButton(),
          _cartHeader(),
          Expanded(
            child: _cart.isEmpty
                ? Center(
                    child: Text('Tap items to build the order',
                        style: TextStyle(
                            fontSize: DeskTypography.bodySmall,
                            color: PosColors.muted)),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    children: [
                      _kotGroupHeader('KOT 1'),
                      for (final line in _cart) ...[
                        _cartRow(line, lang),
                        const Divider(height: 1, color: PosColors.line),
                      ],
                    ],
                  ),
          ),
          _totals(),
          _paymentRow(),
          _actions(),
        ],
      ),
    );
  }

  Widget _tableSelectorButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
      child: Row(
        children: [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: PosColors.ink,
              side: const BorderSide(color: PosColors.lineStrong),
              backgroundColor: PosColors.surfaceSunk,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosRadii.sm)),
            ),
            onPressed: () {},
            icon: const Icon(Icons.table_restaurant_rounded, size: 16),
            label: Text(
              _tableCtl.text.isEmpty ? 'Select table' : _tableCtl.text,
              style: const TextStyle(
                  fontSize: DeskTypography.caption,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotGroupHeader(String label) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      color: PosColors.surfaceSunk,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: PosColors.primary,
              borderRadius: BorderRadius.circular(PosRadii.xs),
            ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: DeskTypography.eyebrow,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
          ),
          const Spacer(),
          Text(
            '${_cart.length} items',
            style: TextStyle(
                fontSize: DeskTypography.eyebrow, color: PosColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _cartHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: PosColors.primary, width: 2),
                  ),
                ),
                child: _eyebrow('ITEMS'),
              ),
            ),
          ),
          SizedBox(width: 92, child: Center(child: _eyebrow('QTY.'))),
          SizedBox(
              width: 84,
              child: Align(
                  alignment: Alignment.centerRight, child: _eyebrow('PRICE'))),
        ],
      ),
    );
  }

  Widget _cartRow(CartLine line, AppLanguage lang) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 7, 10, 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: InkWell(
              onTap: () => setState(() => _cart.remove(line)),
              child: const Text('✕',
                  style: TextStyle(
                      fontSize: 12, color: PosColors.danger)),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.displayName(lang),
                    style: const TextStyle(
                        fontSize: DeskTypography.bodySmall,
                        fontWeight: FontWeight.w600)),
                if (line.note != null && line.note!.isNotEmpty)
                  Text(line.note!,
                      style: TextStyle(
                          fontSize: DeskTypography.eyebrow,
                          color: PosColors.muted)),
              ],
            ),
          ),
          SizedBox(
            width: 92,
            child: _MiniStepper(
              qty: line.qty,
              onMinus: () => _changeQty(line, -1),
              onPlus: () => _changeQty(line, 1),
            ),
          ),
          SizedBox(
            width: 84,
            child: Text(money(context, line.lineTotal),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: DeskTypography.bodySmall,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _totals() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PosColors.line)),
      ),
      child: Column(
        children: [
          _totalRow('Subtotal', _subtotal),
          if (_vatAmount > 0)
            _totalRow('VAT (${_vatRate.toStringAsFixed(0)}%)', _vatAmount),
          if (_serviceChargeAmount > 0)
            _totalRow('Service (${_serviceChargeRate.toStringAsFixed(0)}%)', _serviceChargeAmount),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {},
                child: Text('+ Discount',
                    style: TextStyle(
                        fontSize: DeskTypography.bodySmall,
                        fontWeight: FontWeight.w600,
                        color: PosColors.primary)),
              ),
              Text(
                '',
                style: TextStyle(
                    fontSize: DeskTypography.bodySmall,
                    color: PosColors.ink2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Spacer(),
              Text('Total',
                  style: TextStyle(
                      fontSize: DeskTypography.body,
                      fontWeight: FontWeight.w700,
                      color: PosColors.ink2)),
              const SizedBox(width: 4),
              Text(money(context, _grandTotal),
                  style: const TextStyle(
                      fontSize: DeskTypography.moneyRow,
                      fontWeight: FontWeight.w800,
                      color: PosColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _paymentRow() {
    const methods = ['Cash', 'Card', 'bKash', 'Nagad', 'Due'];
    return Container(
      color: PosColors.stripBg,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final m in methods)
            GestureDetector(
              onTap: () => setState(() => _selectedPayment = m),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: Radio<String>(
                      value: m,
                      groupValue: _selectedPayment,
                      onChanged: (v) => setState(() => _selectedPayment = v!),
                      activeColor: PosColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    m,
                    style: TextStyle(
                      fontSize: DeskTypography.bodySmall,
                      fontWeight: _selectedPayment == m
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: _selectedPayment == m
                          ? Colors.white
                          : const Color(0xB3FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              minimumSize: const Size(0, 28),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(PosRadii.sm)),
            ),
            onPressed: _cart.isNotEmpty ? () {} : null,
            child: const Text('Split',
                style: TextStyle(
                    fontSize: DeskTypography.caption,
                    fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text('Total ',
              style: TextStyle(
                  fontSize: DeskTypography.body,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xB3FFFFFF))),
          Text(money(context, _grandTotal),
              style: const TextStyle(
                  fontSize: DeskTypography.moneyRow,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ),
    );
  }

  Widget _actions() {
    final enabled = _cart.isNotEmpty && !_busy;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: const BoxDecoration(
        color: PosColors.stripBg,
        border: Border(top: BorderSide(color: PosColors.railLine)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _actionBtn('Save', enabled ? _save : null,
                    style: _ActionStyle.primary),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionBtn('Save & Print',
                    enabled ? _save : null,
                    style: _ActionStyle.primary),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionBtn('Save & eBill', null,
                    style: _ActionStyle.outline),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _actionBtn('KOT',
                    enabled ? () => _kot(print: false) : null,
                    style: _ActionStyle.dark),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionBtn('KOT & Print',
                    enabled ? () => _kot(print: true) : null,
                    style: _ActionStyle.outline),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _actionBtn('Hold', null, style: _ActionStyle.outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: PosColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PosRadii.md)),
              ),
              onPressed: enabled ? _settle : null,
              child: _busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.6, color: Colors.white))
                  : const Text('Settle & Save',
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: DeskTypography.h3)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, VoidCallback? onTap,
      {required _ActionStyle style}) {
    final bg = switch (style) {
      _ActionStyle.primary => PosColors.primary,
      _ActionStyle.dark => PosColors.secondary,
      _ActionStyle.outline => PosColors.surface,
    };
    final fg = switch (style) {
      _ActionStyle.primary || _ActionStyle.dark => Colors.white,
      _ActionStyle.outline => PosColors.ink,
    };
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          side: style == _ActionStyle.outline
              ? const BorderSide(color: PosColors.lineStrong)
              : null,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosRadii.md)),
          textStyle:
              const TextStyle(
                  fontSize: DeskTypography.button,
                  fontWeight: FontWeight.w700),
        ),
        onPressed: onTap,
        child: Text(label),
      ),
    );
  }

  // ── small shared widgets ──
  Widget _eyebrow(String text) => Text(
        text,
        style: TextStyle(
          fontSize: DeskTypography.eyebrow,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: PosColors.muted,
        ),
      );

  Widget _totalRow(String label, double value, {bool strong = false}) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: strong ? 16 : 13.5,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
                color: strong ? PosColors.primaryDark : PosColors.ink2)),
        const Spacer(),
        Text(money(context, value),
            style: TextStyle(
                fontSize: strong ? 20 : 14,
                fontWeight: FontWeight.w800,
                color: strong ? PosColors.primary : PosColors.primaryDark)),
      ],
    );
  }

  Widget _searchField(
    TextEditingController ctl,
    String hint,
    IconData icon, {
    VoidCallback? onChanged,
    ValueChanged<String>? onSubmitted,
    bool numeric = false,
  }) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: ctl,
        onChanged: onChanged == null ? null : (_) => onChanged(),
        onSubmitted: onSubmitted,
        keyboardType: numeric ? TextInputType.number : null,
        inputFormatters: numeric
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: Icon(icon, size: 20, color: PosColors.muted),
          hintText: hint,
          filled: true,
          fillColor: PosColors.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.md),
            borderSide: const BorderSide(color: PosColors.lineStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.md),
            borderSide: const BorderSide(color: PosColors.lineStrong),
          ),
        ),
      ),
    );
  }

  Widget _centered(IconData icon, String title, String body) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 34, color: PosColors.muted),
          const SizedBox(height: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: DeskTypography.h2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SizedBox(
            width: 360,
            child: Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: DeskTypography.caption,
                    color: PosColors.muted)),
          ),
        ],
      ),
    );
  }

  String _clean(Object error) =>
      error.toString().replaceFirst('Exception: ', '').trim();

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? PosColors.danger : PosColors.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ─────────────────────────── sub-widgets ───────────────────────────

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selected,
    required this.onSelect,
    required this.itemCountFor,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  final int Function(String category) itemCountFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DeskMetrics.categoryRailWidth,
      color: PosColors.railBg,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        itemCount: categories.length,
        itemBuilder: (_, i) {
          final c = categories[i];
          final active = c == selected;
          final isFav = c == _favCategory;
          final isAll = c == _allCategory;
          final label = isFav
              ? 'Favorite Items'
              : isAll
                  ? 'All Items'
                  : c;
          final count = itemCountFor(c);

          Color bg;
          Color fg;
          if (isFav) {
            bg = active ? PosColors.primary : PosColors.success;
            fg = Colors.white;
          } else if (isAll) {
            bg = active ? PosColors.primary : PosColors.railItem;
            fg = Colors.white;
          } else {
            bg = active ? PosColors.primary : PosColors.railItem;
            fg = active ? Colors.white : const Color(0xFFE6E9F0);
          }

          return InkWell(
            onTap: () => onSelect(c),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: bg,
                border: Border(
                  bottom: BorderSide(color: PosColors.railLine),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: DeskTypography.nav,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: fg,
                      ),
                    ),
                  ),
                  if (isAll) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(PosRadii.pill),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: DeskTypography.eyebrow,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});
  final MenuItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(PosRadii.sm),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.sm),
            border: Border(
              left: BorderSide(color: PosColors.lineStrong, width: 4),
              top: BorderSide(color: PosColors.lineStrong),
              right: BorderSide(color: PosColors.lineStrong),
              bottom: BorderSide(color: PosColors.lineStrong),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: DeskTypography.title,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    money(context, item.price),
                    style: const TextStyle(
                      fontSize: DeskTypography.itemPrice,
                      fontWeight: FontWeight.w700,
                      color: PosColors.ink2,
                    ),
                  ),
                ],
              ),
              if (item.isFavorite)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Text('♥',
                      style: TextStyle(fontSize: 11, color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceTabs extends StatelessWidget {
  const _ServiceTabs({required this.selected, required this.onSelect});
  final OrderServiceType selected;
  final ValueChanged<OrderServiceType> onSelect;

  static const _labels = <(OrderServiceType, String)>[
    (OrderServiceType.dineIn, 'Dine In'),
    (OrderServiceType.delivery, 'Delivery'),
    (OrderServiceType.takeaway, 'Pick Up'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: DeskMetrics.serviceTabHeight,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++) ...[
            if (i > 0)
              Container(width: 1, color: const Color(0x1FFFFFFF)),
            Expanded(
              child: InkWell(
                onTap: () => onSelect(_labels[i].$1),
                child: Container(
                  alignment: Alignment.center,
                  color: _labels[i].$1 == selected
                      ? PosColors.primary
                      : PosColors.stripBg,
                  child: Text(
                    _labels[i].$2,
                    style: const TextStyle(
                      fontSize: DeskTypography.tab,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _btn(Icons.remove_rounded, onMinus),
        SizedBox(
          width: 26,
          child: Text('$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: DeskTypography.bodySmall,
                  fontWeight: FontWeight.w700)),
        ),
        _btn(Icons.add_rounded, onPlus),
      ],
    );
  }

  Widget _btn(IconData icon, VoidCallback onTap) {
    return InkResponse(
      onTap: onTap,
      radius: 16,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: PosColors.surface,
          border: Border.all(color: PosColors.primary, width: 1.5),
        ),
        child: Icon(icon, size: 14, color: PosColors.primary),
      ),
    );
  }
}
