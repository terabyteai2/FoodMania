// QuickBytes Desktop — Register (the counter-station heart). Faithful to
// `desktop-register.jsx`: menu grid + persistent order ticket, modifier modal,
// payment (cash keypad / card / mobile) and the success token. The single solid
// lime action per view is Charge / Confirm payment. Wired to the real
// create → KOT → settle flow on [PosAppController].

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../app_controller.dart';
import '../../../app_scope.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/desktop_pos.dart';
import '../../../models/menu_item.dart';
import '../../../models/order_payment_method.dart';
import '../../../models/order_service_type.dart';
import '../desk_controller.dart';
import '../widgets/dk_icons.dart';
import '../widgets/dk_kit.dart';
import '../widgets/menu_line_customizer.dart';

const double _kVat = 0.05; // fallback when settings define no VAT rate

/// Default discount presets when settings define none (jsx `DISCOUNT_PRESETS`).
List<PosDiscountPreset> _defaultDiscountPresets() => const [
      PosDiscountPreset(id: 'pct10', label: '10%', kind: 'percent', value: 10),
      PosDiscountPreset(id: 'pct15', label: '15%', kind: 'percent', value: 15),
      PosDiscountPreset(id: 'pct20', label: '20%', kind: 'percent', value: 20),
      PosDiscountPreset(id: 'flat50', label: '৳50', kind: 'flat', value: 50),
      PosDiscountPreset(id: 'flat100', label: '৳100', kind: 'flat', value: 100),
    ];

class DeskTotals {
  const DeskTotals(this.subtotal, this.discount, this.vat, this.service, this.charge, this.total, this.count);
  final double subtotal, discount, vat, service, charge, total;
  final int count;
}

/// Generic full-stage modal barrier matching `.dk-scrim`.
Future<T?> _showDkModal<T>(BuildContext context, Widget child, {double opacity = 0.46}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'dismiss',
    barrierColor: Color.fromRGBO(20, 24, 14, opacity),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (_, _, _) => Center(child: Material(color: Colors.transparent, child: child)),
    transitionBuilder: (_, anim, _, c) => FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
        child: c,
      ),
    ),
  );
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.settings, required this.shift, required this.ensureShift, super.key});

  final DesktopPosSettings settings;
  final PosShift? shift;
  final Future<PosShift?> Function() ensureShift;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String _cat = 'All';
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _isBn => AppScope.of(context).language == AppLanguage.bn;
  String _t(String en, String bn) => _isBn ? bn : en;

  List<PosDiscountPreset> get _presets =>
      widget.settings.discountPresets.isNotEmpty ? widget.settings.discountPresets : _defaultDiscountPresets();

  double get _vatRate =>
      widget.settings.vatRatePercent > 0 ? widget.settings.vatRatePercent / 100 : _kVat;

  DeskTotals _totals(DeskDraft d) {
    final subtotal = d.lines.fold<double>(0, (s, l) => s + l.lineTotal);
    double disc = 0;
    final p = d.discount;
    if (p != null) {
      disc = p.kind == 'flat' ? p.value : subtotal * p.value / 100;
      if (disc > subtotal) disc = subtotal;
    }
    final vat = ((subtotal - disc) * _vatRate).roundToDouble();
    final service = subtotal * widget.settings.serviceChargePercent / 100;
    final charge = d.type == OrderServiceType.delivery ? d.charge : 0.0;
    return DeskTotals(subtotal, disc, vat, service, charge, subtotal - disc + vat + service + charge, d.count);
  }

  bool _deliveryValid(DeskDraft d) =>
      d.type != OrderServiceType.delivery ||
      (d.customer.trim().isNotEmpty && d.phone.trim().length >= 6 && d.addr.trim().isNotEmpty && d.area != null);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final desk = DeskScope.of(context);
    final draft = desk.draft;
    return Container(
      color: Dk.bg,
      child: Column(
        children: [
          _header(app, desk),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _menuColumn(app, desk, draft)),
                _Ticket(
                  app: app,
                  desk: desk,
                  settings: widget.settings,
                  totals: _totals(draft),
                  presets: _presets,
                  valid: _deliveryValid(draft),
                  busy: _busy,
                  vatPercent: (_vatRate * 100).round(),
                  onCharge: () => _openPayment(desk, draft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(PosAppController app, DeskController desk) {
    final now = TimeOfDay.now();
    final dateStr = '${now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod}:'
        '${now.minute.toString().padLeft(2, '0')} ${now.period == DayPeriod.am ? 'AM' : 'PM'}';
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(color: Dk.surface, border: Border(bottom: BorderSide(color: Dk.line))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t('Register', 'রেজিস্টার'), style: dkText(22, weight: FontWeight.w700, letterSpacing: -0.4)),
                Text(
                  app.restaurantName.trim().isNotEmpty
                      ? _t('Counter · ${app.restaurantName}', 'কাউন্টার · ${app.restaurantName}')
                      : _t('Counter', 'কাউন্টার'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: dkText(13, weight: FontWeight.w500, color: Dk.muted),
                ),
              ],
            ),
          ),
          Text(dateStr, style: dkNum(13, weight: FontWeight.w600, color: Dk.muted)),
          const SizedBox(width: 12),
          DkButton(
            label: _t('Reset', 'রিসেট'),
            icon: 'refresh',
            variant: DkBtnVariant.ghost,
            size: DkBtnSize.sm,
            onTap: () => desk.clearDraft(),
          ),
        ],
      ),
    );
  }

  Widget _menuColumn(PosAppController app, DeskController desk, DeskDraft draft) {
    final lang = app.language;
    final items = app.menuItems.where((m) => m.deletedAt == null).toList();
    final cats = <String>[];
    for (final m in items) {
      final c = m.localizedCategory(lang);
      if (c.trim().isNotEmpty && !cats.contains(c)) cats.add(c);
    }
    final q = _query.trim().toLowerCase();
    final filtered = items.where((m) {
      final inCat = _cat == 'All' || m.localizedCategory(lang) == _cat;
      return inCat && (q.isEmpty || m.searchText(lang).contains(q));
    }).toList();

    final qtyById = <String, int>{};
    for (final l in draft.lines) {
      qtyById[l.item.id] = (qtyById[l.item.id] ?? 0) + l.qty;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 10),
          child: Row(
            children: [
              DkSeg(
                selected: draft.type.value,
                onSelect: (id) => desk.setDraftType(_typeFromValue(id)),
                items: [
                  DkSegItem('dine_in', _t('Dine-in', 'ডাইন-ইন'), icon: 'table'),
                  DkSegItem('takeaway', _t('Parcel', 'পার্সেল'), icon: 'bag'),
                  DkSegItem('delivery', _t('Delivery', 'ডেলিভারি'), icon: 'truck'),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: DkField(
                    controller: _search,
                    placeholder: _t('Search the menu…', 'মেনু খুঁজুন…'),
                    showClear: true,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(_t('Tap an item to add it', 'যোগ করতে আইটেমে চাপুন'),
                  style: dkText(12.5, weight: FontWeight.w500, color: Dk.muted)),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(22, 2, 22, 12),
            children: [
              for (final c in ['All', ...cats])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DkChip(
                    label: c == 'All' ? _t('All', 'সব') : c,
                    active: _cat == c,
                    height: 40,
                    onTap: () => setState(() => _cat = c),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(_t('Nothing matches that search.', 'কিছু পাওয়া যায়নি'), style: dkText(14, color: Dk.muted)))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisExtent: 190,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final m = filtered[i];
                    return _MenuCard(
                      item: m,
                      lang: lang,
                      isBn: _isBn,
                      qty: qtyById[m.id] ?? 0,
                      onTap: () => _onPickItem(desk, m),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _onPickItem(DeskController desk, MenuItem m) async {
    if (!desktopMenuNeedsCustomization(m)) {
      desk.addDraftLine(desktopRegularMenuLine(m));
      return;
    }
    final line = await _showDkModal<DesktopMenuLineSelection>(context, _ModifierModal(item: m, isBn: _isBn));
    if (line != null) desk.addDraftLine(line);
  }

  Future<void> _openPayment(DeskController desk, DeskDraft draft) async {
    if (_busy) return;
    final totals = _totals(draft);
    final result = await _showDkModal<_PayResult>(context, _PaymentModal(totals: totals, isBn: _isBn));
    if (result == null || !mounted) return;
    final success = await _charge(desk, draft, result.method, result.change);
    if (success != null && mounted) {
      await _showDkModal<void>(
        context,
        _SuccessOverlay(data: success, isBn: _isBn, onToast: desk.showToast),
        opacity: 0.55,
      );
    }
  }

  OrderServiceType _typeFromValue(String v) => switch (v) {
        'takeaway' => OrderServiceType.takeaway,
        'delivery' => OrderServiceType.delivery,
        _ => OrderServiceType.dineIn,
      };

  Future<_Success?> _charge(DeskController desk, DeskDraft draft, OrderPaymentMethod method, double change) async {
    setState(() => _busy = true);
    final app = AppScope.read(context);
    try {
      final shift = widget.shift ?? await widget.ensureShift();
      if (shift == null) throw Exception('Register shift unavailable.');
      final t = _totals(draft);
      final isDelivery = draft.type == OrderServiceType.delivery;
      final typeLabel = _typeLabel(draft);
      final order = await app.createDesktopOrder(
        requestedItems: [for (final l in draft.lines) l.toRequestItem()],
        shift: shift,
        settings: widget.settings,
        serviceType: draft.type,
        tableNo: draft.type == OrderServiceType.dineIn ? draft.table : null,
        customerName: draft.customer.trim().isEmpty ? null : draft.customer.trim(),
        deliveryAddress: isDelivery && draft.addr.trim().isNotEmpty ? draft.addr.trim() : null,
        mobileNumber: isDelivery && draft.phone.trim().isNotEmpty ? draft.phone.trim() : null,
        deliveryCharge: isDelivery ? draft.charge : 0,
      );
      await app.sendDesktopKot(order);
      final serviceAmount = order.subtotal * widget.settings.serviceChargePercent / 100;
      final total = order.subtotal + order.vatAmount + order.deliveryCharge + serviceAmount - t.discount;
      final settled = await app.settleDesktopOrder(
        order: order,
        shift: shift,
        settlements: [
          PosSettlementLine(eventId: const Uuid().v4(), paymentMethod: method.value, amount: double.parse(total.toStringAsFixed(2))),
        ],
        discountAmount: t.discount,
        serviceChargeRatePercent: widget.settings.serviceChargePercent,
        serviceChargeAmount: serviceAmount,
        discountPresetId: draft.discount?.id,
        discountLabel: draft.discount?.label,
      );
      desk.resetDraft();
      if (mounted) setState(() => _busy = false);
      return _Success(
        token: settled.sequenceNo,
        total: total,
        count: t.count,
        typeLabel: typeLabel,
        methodLabel: _methodLabel(method),
        change: change > 0 ? change : 0,
      );
    } catch (error) {
      if (mounted) setState(() => _busy = false);
      desk.showToast('$error');
      return null;
    }
  }

  String _typeLabel(DeskDraft d) {
    if (d.type == OrderServiceType.dineIn) {
      return d.table != null ? _t('Table ${d.table}', 'টেবিল ${d.table}') : _t('Dine-in', 'ডাইন-ইন');
    }
    return d.type.localized(_isBn);
  }

  String _methodLabel(OrderPaymentMethod m) => switch (m) {
        OrderPaymentMethod.cash => _t('Cash', 'নগদ'),
        OrderPaymentMethod.card => _t('Card', 'কার্ড'),
        _ => 'bKash / Nagad',
      };
}

// ── Menu card (`.dk-card`) ───────────────────────────────────────────────────
class _MenuCard extends StatefulWidget {
  const _MenuCard({required this.item, required this.lang, required this.isBn, required this.qty, required this.onTap});
  final MenuItem item;
  final AppLanguage lang;
  final bool isBn;
  final int qty;
  final VoidCallback onTap;
  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    final m = widget.item;
    final tint = dkCatTint(m.localizedCategory(widget.lang));
    final selected = widget.qty > 0;
    final out = !m.isAvailable;
    String tr(String en, String bn) => widget.isBn ? bn : en;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: out ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: out ? null : widget.onTap,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Dk.surface,
            borderRadius: BorderRadius.circular(Dk.rLg),
            border: Border.all(color: selected ? Dk.accent : (_hover ? Dk.line2 : Dk.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                children: [
                  Container(
                    height: 96,
                    color: tint.bg,
                    child: Center(child: DkIcon(tint.icon, size: 42, color: tint.fg, strokeWidth: 1.6)),
                  ),
                  if (widget.qty > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 26),
                        height: 26,
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        decoration: BoxDecoration(color: Dk.accent, borderRadius: BorderRadius.circular(Dk.rSm)),
                        alignment: Alignment.center,
                        child: Text('${widget.qty}', style: dkNum(14, weight: FontWeight.w800, color: Dk.accentInk)),
                      ),
                    ),
                  if (desktopMenuNeedsCustomization(m))
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        height: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(Dk.rXs),
                          border: Border.all(color: Dk.line2),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const DkIcon('sort', size: 12, color: Dk.ink2),
                            const SizedBox(width: 4),
                            Text(tr('Options', 'অপশন'), style: dkText(11, weight: FontWeight.w700, color: Dk.ink2)),
                          ],
                        ),
                      ),
                    ),
                  if (out)
                    Positioned.fill(
                      child: Container(
                        color: Dk.bg.withValues(alpha: 0.66),
                        alignment: Alignment.center,
                        child: DkBadge(label: tr('Sold out', 'শেষ'), variant: DkBadgeVariant.danger),
                      ),
                    ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.localizedName(widget.lang),
                          maxLines: 2, overflow: TextOverflow.ellipsis, style: dkText(14, weight: FontWeight.w600, height: 1.25)),
                      const SizedBox(height: 3),
                      Expanded(
                        child: Text(m.localizedDescription(widget.lang),
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: dkText(11.5, color: Dk.muted, height: 1.3)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(dkMoney(m.price), style: dkNum(15, weight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ticket (`.dk-ticket`) ────────────────────────────────────────────────────
class _Ticket extends StatelessWidget {
  const _Ticket({
    required this.app,
    required this.desk,
    required this.settings,
    required this.totals,
    required this.presets,
    required this.valid,
    required this.busy,
    required this.vatPercent,
    required this.onCharge,
  });

  final PosAppController app;
  final DeskController desk;
  final DesktopPosSettings settings;
  final DeskTotals totals;
  final List<PosDiscountPreset> presets;
  final bool valid;
  final bool busy;
  final int vatPercent;
  final VoidCallback onCharge;

  bool get _isBn => app.language == AppLanguage.bn;
  String _t(String en, String bn) => _isBn ? bn : en;

  @override
  Widget build(BuildContext context) {
    final d = desk.draft;
    final typeIcon = d.type == OrderServiceType.dineIn ? 'table' : d.type == OrderServiceType.takeaway ? 'bag' : 'truck';
    final ctx = d.type == OrderServiceType.dineIn
        ? (d.table != null ? _t('Table ${d.table}', 'টেবিল ${d.table}') : _t('Pick a table', 'টেবিল নির্বাচন করুন'))
        : d.type == OrderServiceType.takeaway
            ? _t('Parcel · Takeaway', 'পার্সেল · টেকঅ্যাওয়ে')
            : _t('Delivery order', 'ডেলিভারি');

    return Container(
      width: 396,
      decoration: const BoxDecoration(color: Dk.surface, border: Border(left: BorderSide(color: Dk.line))),
      child: Column(
        children: [
          // head
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: Dk.accentTint, borderRadius: BorderRadius.circular(8)),
                      child: Center(child: DkIcon(typeIcon, size: 19, color: Dk.accentStrong)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ctx, maxLines: 1, overflow: TextOverflow.ellipsis, style: dkText(16, weight: FontWeight.w700)),
                          Text(_t('${d.type.label} order', '${d.type.banglaLabel} অর্ডার'),
                              style: dkText(12, color: Dk.muted)),
                        ],
                      ),
                    ),
                    if (d.lines.isNotEmpty)
                      DkXBtn(icon: 'trash', size: 34, tooltip: 'Clear order', onTap: () => desk.clearDraft()),
                  ],
                ),
                if (d.type == OrderServiceType.dineIn) _TableField(app: app, desk: desk, settings: settings),
                if (d.type == OrderServiceType.delivery) _DeliveryForm(desk: desk, isBn: _isBn),
                if (d.type == OrderServiceType.takeaway) _ParcelField(desk: desk, isBn: _isBn),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Dk.line),
          // body
          Expanded(
            child: d.lines.isEmpty
                ? _emptyTicket()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                    itemCount: d.lines.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (_, i) => _ticketLine(d.lines[i]),
                  ),
          ),
          // foot
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Dk.line))),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (d.lines.isNotEmpty) ...[
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        DkChip(label: _t('No disc.', 'ছাড় নেই'), active: d.discount == null, onTap: () => desk.setDraftDiscount(null)),
                        for (final p in presets) ...[
                          const SizedBox(width: 6),
                          DkChip(label: p.label, tint: true, active: d.discount?.id == p.id, onTap: () => desk.setDraftDiscount(p)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _summary(d),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: DkButton(
                        label: _t('Hold', 'হোল্ড'),
                        icon: 'clock',
                        variant: DkBtnVariant.ghost,
                        expand: true,
                        onTap: d.lines.isEmpty ? null : () => desk.showToast(_t('Order held', 'অর্ডার হোল্ডে রাখা হয়েছে')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DkButton(
                        label: 'KOT',
                        icon: 'printer',
                        variant: DkBtnVariant.ghost,
                        expand: true,
                        onTap: d.lines.isEmpty ? null : () => desk.showToast(_t('KOT sent to kitchen', 'KOT রান্নাঘরে পাঠানো হয়েছে')),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                DkButton(
                  label: '${_t('Charge', 'চার্জ')} ${dkMoney(totals.total)}',
                  icon: 'taka',
                  variant: DkBtnVariant.primary,
                  size: DkBtnSize.lg,
                  expand: true,
                  onTap: (d.lines.isEmpty || !valid || busy) ? null : onCharge,
                ),
                if (!valid && d.lines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_t('Complete delivery details to charge', 'ডেলিভারির তথ্য পূরণ করুন'),
                        textAlign: TextAlign.center, style: dkText(12, color: Dk.warning)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyTicket() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: Dk.surface2, borderRadius: BorderRadius.circular(16)),
              child: const Center(child: DkIcon('bag', size: 28, color: Dk.placeholder)),
            ),
            const SizedBox(height: 14),
            Text(_t('No items yet', 'অর্ডার খালি'), style: dkText(15, weight: FontWeight.w600, color: Dk.ink2)),
            const SizedBox(height: 4),
            Text(_t('Tap dishes on the left to build this order.', 'বাম পাশের মেনু থেকে আইটেম যোগ করুন'),
                textAlign: TextAlign.center, style: dkText(13, color: Dk.muted)),
          ],
        ),
      ),
    );
  }

  Widget _ticketLine(DesktopMenuLineSelection l) {
    final mod = l.modifierLabel;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: Dk.surface2, borderRadius: BorderRadius.circular(Dk.rMd)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.item.localizedName(app.language), style: dkText(14, weight: FontWeight.w600)),
                if (mod.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(mod, style: dkText(11.5, color: Dk.muted, height: 1.35)),
                  ),
                if ((l.note ?? '').trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('“${l.note!.trim()}”', style: dkText(11.5, color: Dk.muted, height: 1.35)),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    DkQty(value: l.qty, onChanged: (q) => desk.setDraftLineQty(l.lineKey, q), min: 0),
                    const SizedBox(width: 10),
                    DkXBtn(icon: 'trash', size: 26, onTap: () => desk.removeDraftLine(l.lineKey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Text(dkMoney(l.lineTotal), style: dkNum(14, weight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _summary(DeskDraft d) {
    Widget row(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: dkText(14, color: color ?? Dk.ink2)),
              Text(value, style: dkNum(14, weight: FontWeight.w600, color: color ?? Dk.ink)),
            ],
          ),
        );
    return Column(
      children: [
        row(_t('Subtotal', 'সাবটোটাল'), dkMoney(totals.subtotal)),
        if (totals.discount > 0)
          row('${_t('Discount', 'ছাড়')} (${d.discount?.label ?? ''})', '−${dkMoney(totals.discount)}', color: Dk.accentStrong),
        row('${_t('VAT', 'ভ্যাট')} ($vatPercent%)', dkMoney(totals.vat)),
        if (totals.service > 0) row(_t('Service', 'সার্ভিস'), dkMoney(totals.service)),
        if (d.type == OrderServiceType.delivery)
          row('${_t('Delivery', 'ডেলিভারি')}${d.area != null ? ' · ${d.area}' : ''}', dkMoney(totals.charge)),
      ],
    );
  }
}

// ── Per-type ticket fields ───────────────────────────────────────────────────
class _TableField extends StatefulWidget {
  const _TableField({required this.app, required this.desk, required this.settings});
  final PosAppController app;
  final DeskController desk;
  final DesktopPosSettings settings;
  @override
  State<_TableField> createState() => _TableFieldState();
}

class _TableFieldState extends State<_TableField> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final isBn = widget.app.language == AppLanguage.bn;
    String t(String en, String bn) => isBn ? bn : en;
    final tables = [for (final z in widget.settings.floorLayout) ...z.tables];
    final occupied = <String>{
      for (final o in widget.app.orders)
        if (o.serviceType == OrderServiceType.dineIn && o.status.isOpen && (o.tableNo ?? '').isNotEmpty) o.tableNo!,
    };
    final sel = widget.desk.draft.table;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() => _open = !_open),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Dk.surface,
                borderRadius: BorderRadius.circular(Dk.rMd),
                border: Border.all(color: Dk.line2),
              ),
              child: Row(
                children: [
                  const DkIcon('table', size: 18, color: Dk.muted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      sel != null ? t('Table $sel', 'টেবিল $sel') : t('Select a table', 'টেবিল নির্বাচন করুন'),
                      style: dkText(14, weight: FontWeight.w600, color: sel != null ? Dk.ink : Dk.placeholder),
                    ),
                  ),
                  const DkIcon('chevd', size: 16, color: Dk.muted),
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Dk.surface,
                borderRadius: BorderRadius.circular(Dk.rLg),
                border: Border.all(color: Dk.line2),
                boxShadow: Dk.e3,
              ),
              child: Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final tb in tables)
                    _tableCell(tb.label, occupied.contains(tb.label), sel == tb.label, () {
                      widget.desk.setDraftTable(tb.label);
                      setState(() => _open = false);
                    }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tableCell(String label, bool occ, bool sel, VoidCallback onTap) {
    return SizedBox(
      width: 70,
      height: 46,
      child: GestureDetector(
        onTap: occ ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            color: sel ? Dk.accentTint : (occ ? Dk.seatTint : Dk.surface),
            borderRadius: BorderRadius.circular(Dk.rMd),
            border: Border.all(color: sel ? Dk.accent : (occ ? Dk.seatLine : Dk.line2)),
          ),
          alignment: Alignment.center,
          child: Opacity(
            opacity: occ ? 0.6 : 1,
            child: Text(label, style: dkNum(14, weight: FontWeight.w700, color: occ ? Dk.seatInk : Dk.ink)),
          ),
        ),
      ),
    );
  }
}

class _ParcelField extends StatelessWidget {
  const _ParcelField({required this.desk, required this.isBn});
  final DeskController desk;
  final bool isBn;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DkField(
        icon: 'user',
        placeholder: isBn ? 'কাস্টমারের নাম (ঐচ্ছিক)' : 'Customer name (optional)',
        onChanged: desk.setDraftCustomer,
      ),
    );
  }
}

class _DeliveryForm extends StatelessWidget {
  const _DeliveryForm({required this.desk, required this.isBn});
  final DeskController desk;
  final bool isBn;
  @override
  Widget build(BuildContext context) {
    final d = desk.draft;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          DkField(icon: 'user', placeholder: isBn ? 'প্রাপকের নাম' : 'Recipient name', onChanged: desk.setDraftCustomer),
          const SizedBox(height: 8),
          DkField(icon: 'phone', placeholder: '01XXX-XXXXXX', keyboardType: TextInputType.phone, onChanged: desk.setDraftPhone),
          const SizedBox(height: 8),
          DkField(icon: 'pin', placeholder: isBn ? 'বাসা, রোড, এলাকা' : 'House, road, landmark', onChanged: desk.setDraftAddr),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final a in kDkDeliveryAreas)
                DkChip(
                  label: a.$1,
                  active: d.area == a.$1,
                  trailing: Text(dkMoney(a.$2), style: dkText(12, weight: FontWeight.w600, color: d.area == a.$1 ? Dk.accentStrong : Dk.muted)),
                  onTap: () => desk.setDraftArea(a.$1, a.$2),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Modifier modal ───────────────────────────────────────────────────────────
class _ModifierModal extends StatefulWidget {
  const _ModifierModal({required this.item, required this.isBn});
  final MenuItem item;
  final bool isBn;
  @override
  State<_ModifierModal> createState() => _ModifierModalState();
}

class _ModifierModalState extends State<_ModifierModal> {
  late final List<DesktopMenuOption> _options = desktopConfiguredMenuOptionsFor(widget.item);
  late DesktopMenuOption? _option = _options.isNotEmpty ? _options.first : null;
  final Set<int> _addOns = {};
  int _qty = 1;
  final TextEditingController _note = TextEditingController();

  String _t(String en, String bn) => widget.isBn ? bn : en;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  double get _unit {
    var p = widget.item.price + (_option?.priceDelta ?? 0);
    for (final i in _addOns) {
      p += widget.item.extras.addOns[i].price;
    }
    return p < 0 ? 0 : p;
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).language;
    final addOns = widget.item.extras.addOns;
    return Container(
      width: 540,
      constraints: const BoxConstraints(maxHeight: 680),
      decoration: BoxDecoration(color: Dk.surface, borderRadius: BorderRadius.circular(Dk.rXl)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: dkCatTint(widget.item.localizedCategory(lang)).bg, borderRadius: BorderRadius.circular(Dk.rMd)),
                  child: Center(child: DkIcon(dkCatTint(widget.item.localizedCategory(lang)).icon, size: 26, color: dkCatTint(widget.item.localizedCategory(lang)).fg)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.item.localizedName(lang), style: dkText(18, weight: FontWeight.w700)),
                      Text(widget.item.localizedDescription(lang),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: dkText(13, color: Dk.muted)),
                    ],
                  ),
                ),
                DkXBtn(icon: 'x', size: 34, onTap: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          const Divider(height: 1, color: Dk.line),
          // body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_options.isNotEmpty) ...[
                    _groupHeader(_t('Size / option', 'সাইজ / অপশন'), _t('Pick one', 'একটি বাছুন'), required: true),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final o in _options) _optChip(o.label, o.priceDelta, _option == o, () => setState(() => _option = o)),
                      ],
                    ),
                  ],
                  if (addOns.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _groupHeader(_t('Add-ons', 'অ্যাড-অন'), _t('Any number', 'একাধিক')),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < addOns.length; i++)
                          _optChip(addOns[i].name, addOns[i].price, _addOns.contains(i), () => setState(() {
                                _addOns.contains(i) ? _addOns.remove(i) : _addOns.add(i);
                              })),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(_t('Kitchen note', 'রান্নাঘরের নোট'), style: dkText(14, weight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  DkField(
                    icon: 'note',
                    controller: _note,
                    placeholder: _t('e.g. less spicy, no onion', 'যেমন: কম ঝাল'),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Dk.line),
          // footer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
            child: Row(
              children: [
                DkQty(value: _qty, onChanged: (q) => setState(() => _qty = q < 1 ? 1 : q), scale: 1.1),
                const SizedBox(width: 14),
                Expanded(
                  child: DkButton(
                    label: '${_t('Add to order', 'অর্ডারে যোগ করুন')} · ${dkMoney(_unit * _qty)}',
                    variant: DkBtnVariant.primary,
                    size: DkBtnSize.lg,
                    expand: true,
                    onTap: () {
                      final selected = [for (final i in _addOns) widget.item.extras.addOns[i]];
                      final note = _note.text.trim().isEmpty ? null : _note.text.trim();
                      Navigator.of(context).pop(DesktopMenuLineSelection(
                        item: widget.item,
                        option: _option ?? const DesktopMenuOption(label: ''),
                        addOns: selected,
                        qty: _qty,
                        note: note,
                      ));
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(String title, String hint, {bool required = false}) {
    return Row(
      children: [
        Text(title, style: dkText(14, weight: FontWeight.w700)),
        if (required) ...[const SizedBox(width: 8), DkBadge(label: _t('Required', 'প্রয়োজন'), variant: DkBadgeVariant.neutral)],
        const Spacer(),
        Text(hint, style: dkText(12, color: Dk.muted)),
      ],
    );
  }

  Widget _optChip(String label, double delta, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: on ? Dk.accentTint : Dk.surface,
          borderRadius: BorderRadius.circular(Dk.rMd),
          border: Border.all(color: on ? Dk.accent : Dk.line2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: dkText(14, weight: FontWeight.w600, color: on ? Dk.accentStrong : Dk.ink)),
            if (delta > 0) ...[
              const SizedBox(width: 8),
              Text('+${dkMoney(delta)}', style: dkNum(13, weight: FontWeight.w700, color: on ? Dk.accentStrong : Dk.muted)),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Payment modal ────────────────────────────────────────────────────────────
class _PayResult {
  const _PayResult(this.method, this.change);
  final OrderPaymentMethod method;
  final double change;
}

class _PaymentModal extends StatefulWidget {
  const _PaymentModal({required this.totals, required this.isBn});
  final DeskTotals totals;
  final bool isBn;
  @override
  State<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<_PaymentModal> {
  OrderPaymentMethod _method = OrderPaymentMethod.cash;
  String _tendered = '';

  String _t(String en, String bn) => widget.isBn ? bn : en;

  double get _total => widget.totals.total;
  int get _tNum => int.tryParse(_tendered.isEmpty ? '0' : _tendered) ?? 0;
  double get _change => _tNum - _total;
  bool get _canPay => _method == OrderPaymentMethod.cash ? _tNum >= _total : true;

  void _press(String k) {
    setState(() {
      if (k == 'del') {
        _tendered = _tendered.isEmpty ? '' : _tendered.substring(0, _tendered.length - 1);
      } else {
        var s = (_tendered + k);
        s = s.replaceFirst(RegExp(r'^0+(\d)'), r'$1');
        if (s.length > 7) s = s.substring(0, 7);
        _tendered = s;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final quick = <int>{};
    quick.add(_total.ceil());
    quick.add((_total / 100).ceil() * 100);
    quick.add((_total / 500).ceil() * 500);
    quick.add(1000);
    quick.add(2000);
    final quickList = quick.where((v) => v >= _total).toList()..sort();
    final quicks = quickList.take(4).toList();

    return Container(
      width: 760,
      constraints: const BoxConstraints(maxWidth: 760),
      decoration: BoxDecoration(color: Dk.surface, borderRadius: BorderRadius.circular(Dk.rXl)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Dk.line))),
            child: Row(
              children: [
                Expanded(child: Text(_t('Take payment', 'পেমেন্ট নিন'), style: dkText(18, weight: FontWeight.w700))),
                DkXBtn(icon: 'x', size: 34, onTap: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // left: amount + methods
                Container(
                  width: 320,
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(border: Border(right: BorderSide(color: Dk.line))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_t('Total due', 'মোট বকেয়া'), style: dkText(13, weight: FontWeight.w600, color: Dk.muted)),
                      const SizedBox(height: 2),
                      Text(dkMoney(_total), style: dkNum(44, weight: FontWeight.w800, letterSpacing: -1)),
                      const SizedBox(height: 2),
                      Text('${widget.totals.count} ${_t('items · incl. VAT', 'আইটেম · ভ্যাট সহ')}',
                          style: dkText(12.5, color: Dk.muted)),
                      const SizedBox(height: 22),
                      for (final m in [
                        (OrderPaymentMethod.cash, _t('Cash', 'নগদ'), 'cash'),
                        (OrderPaymentMethod.card, _t('Card', 'কার্ড'), 'card'),
                        (OrderPaymentMethod.bkash, 'bKash · Nagad', 'phone'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _methodBtn(m.$1, m.$2, m.$3),
                        ),
                    ],
                  ),
                ),
                // right: body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_method == OrderPaymentMethod.cash) ...[
                          Row(
                            children: [
                              Expanded(child: _amountBox(_t('Tendered', 'গৃহীত'), _tendered.isEmpty ? '—' : dkMoney(_tNum), false)),
                              const SizedBox(width: 12),
                              Expanded(child: _amountBox(_t('Change', 'ফেরত'), _tendered.isNotEmpty && _change >= 0 ? dkMoney(_change) : '—', _tendered.isNotEmpty && _change >= 0)),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              for (final v in quicks)
                                DkChip(
                                  label: v == _total.ceil() ? _t('Exact', 'সঠিক') : dkMoney(v),
                                  height: 40,
                                  onTap: () => setState(() => _tendered = '$v'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          _keypad(),
                        ] else
                          Expanded(child: _methodInstruction()),
                        const SizedBox(height: 16),
                        DkButton(
                          label: '${_t('Confirm payment', 'পেমেন্ট নিশ্চিত করুন')} · ${dkMoney(_total)}',
                          icon: 'check',
                          variant: DkBtnVariant.primary,
                          size: DkBtnSize.lg,
                          expand: true,
                          onTap: _canPay
                              ? () => Navigator.of(context).pop(_PayResult(_method, _method == OrderPaymentMethod.cash ? _change : 0))
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodBtn(OrderPaymentMethod m, String label, String icon) {
    final on = _method == m;
    return GestureDetector(
      onTap: () => setState(() => _method = m),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: on ? Dk.accentTint : Dk.surface,
          borderRadius: BorderRadius.circular(Dk.rMd),
          border: Border.all(color: on ? Dk.accent : Dk.line2),
        ),
        child: Row(
          children: [
            DkIcon(icon, size: 20, color: on ? Dk.accentStrong : Dk.ink),
            const SizedBox(width: 11),
            Expanded(child: Text(label, style: dkText(15, weight: FontWeight.w600, color: on ? Dk.accentStrong : Dk.ink))),
            if (on) const DkIcon('check', size: 18, color: Dk.accentStrong),
          ],
        ),
      ),
    );
  }

  Widget _amountBox(String label, String value, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: active ? Dk.accentTint : Dk.surface,
        borderRadius: BorderRadius.circular(Dk.rMd),
        border: Border.all(color: active ? Dk.accent : Dk.line2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: dkText(11.5, weight: FontWeight.w600, color: Dk.muted)),
          const SizedBox(height: 2),
          Text(value, style: dkNum(24, weight: FontWeight.w700, color: active ? Dk.accentStrong : Dk.ink)),
        ],
      ),
    );
  }

  Widget _keypad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '00', '0', 'del'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.9,
      children: [
        for (final k in keys)
          GestureDetector(
            onTap: () => _press(k),
            child: Container(
              decoration: BoxDecoration(
                color: Dk.surface,
                borderRadius: BorderRadius.circular(Dk.rMd),
                border: Border.all(color: Dk.line2),
              ),
              alignment: Alignment.center,
              child: Text(k == 'del' ? '⌫' : k, style: dkNum(22, weight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }

  Widget _methodInstruction() {
    final card = _method == OrderPaymentMethod.card;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: Dk.accentTint, borderRadius: BorderRadius.circular(24)),
            child: Center(child: DkIcon(card ? 'card' : 'phone', size: 46, color: Dk.accentStrong)),
          ),
          const SizedBox(height: 18),
          Text(
            card ? _t('Insert or tap card on terminal', 'টার্মিনালে কার্ড দিন') : _t('Payment request sent to phone', 'ফোনে পেমেন্ট রিকোয়েস্ট পাঠানো হয়েছে'),
            textAlign: TextAlign.center,
            style: dkText(17, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              card ? _t('Confirm once the customer approves the charge.', 'গ্রাহক অনুমোদন করলে নিশ্চিত করুন') : _t('Confirm once paid via bKash or Nagad.', 'গ্রাহক বিকাশ/নগদে অনুমোদন করলে নিশ্চিত করুন'),
              textAlign: TextAlign.center,
              style: dkText(13.5, color: Dk.muted),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success overlay ──────────────────────────────────────────────────────────
class _Success {
  const _Success({required this.token, required this.total, required this.count, required this.typeLabel, required this.methodLabel, required this.change});
  final int token;
  final double total;
  final int count;
  final String typeLabel;
  final String methodLabel;
  final double change;
}

class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay({required this.data, required this.isBn, required this.onToast});
  final _Success data;
  final bool isBn;
  final ValueChanged<String> onToast;
  String _t(String en, String bn) => isBn ? bn : en;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 480,
      padding: const EdgeInsets.fromLTRB(34, 34, 34, 26),
      decoration: BoxDecoration(color: Dk.surface, borderRadius: BorderRadius.circular(Dk.rXl)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(color: Dk.accent, shape: BoxShape.circle),
              child: const Center(child: DkIcon('check', size: 40, color: Dk.accentInk, strokeWidth: 2.4)),
            ),
          ),
          const SizedBox(height: 16),
          Text(_t('Order confirmed', 'অর্ডার নিশ্চিত'), textAlign: TextAlign.center, style: dkText(22, weight: FontWeight.w800, letterSpacing: -0.4)),
          const SizedBox(height: 4),
          Text(
            '${data.typeLabel} · ${data.count} ${_t('items', 'আইটেম')} · ${dkMoney(data.total)} · ${data.methodLabel}'
            '${data.change > 0 ? ' · ${_t('change', 'ফেরত')} ${dkMoney(data.change)}' : ''}',
            textAlign: TextAlign.center,
            style: dkText(13.5, color: Dk.muted),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(Dk.rLg), border: Border.all(color: Dk.ink, width: 2)),
            child: Column(
              children: [
                dkEyebrow(_t('Customer token', 'কাস্টমার টোকেন'), color: Dk.ink2),
                const SizedBox(height: 2),
                Text('${data.token}', style: dkNum(64, weight: FontWeight.w800, letterSpacing: -2, height: 1.05)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final p in [('printer', 'KOT'), ('receipt', _t('Token', 'টোকেন')), ('taka', _t('Bill', 'বিল'))]) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => onToast('${_t('Printing', 'প্রিন্ট:')} ${p.$2}'),
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(color: Dk.surface, borderRadius: BorderRadius.circular(Dk.rMd), border: Border.all(color: Dk.line2)),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          DkIcon(p.$1, size: 20, color: Dk.ink),
                          const SizedBox(height: 4),
                          Text(p.$2, style: dkText(12.5, color: Dk.ink)),
                        ],
                      ),
                    ),
                  ),
                ),
                if (p.$2 != _t('Bill', 'বিল')) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DkButton(label: _t('Done', 'সম্পন্ন'), variant: DkBtnVariant.ghost, size: DkBtnSize.lg, expand: true, onTap: () => Navigator.of(context).pop()),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: DkButton(label: _t('New order', 'নতুন অর্ডার'), icon: 'plus', variant: DkBtnVariant.primary, size: DkBtnSize.lg, expand: true, onTap: () => Navigator.of(context).pop()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
