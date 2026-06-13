// QuickBytes Desktop — ephemeral UI state for the counter-station surface,
// mirroring the jsx `useDesk()` store (`desktop-app.jsx`). Data, role and
// language live in the global [PosAppController]; this holds only the desktop
// shell's view state (active tab, popovers, slide-over, toast, selection, and
// — from Milestone 2 — the in-progress register draft).

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../models/account_role.dart';
import '../../models/desktop_pos.dart';
import '../../models/order_service_type.dart';
import 'widgets/menu_line_customizer.dart';

/// One line in the in-progress register order (reuses the existing
/// [DesktopMenuLineSelection] pricing/modifier model). Immutable; mutations
/// replace it.
DesktopMenuLineSelection _withQty(DesktopMenuLineSelection l, int qty) =>
    DesktopMenuLineSelection(item: l.item, option: l.option, addOns: l.addOns, qty: qty, note: l.note);

/// The register draft (jsx `blankDraft()`): service type, table/delivery context,
/// lines and an optional discount preset. Shared so Tables can seed it.
class DeskDraft {
  DeskDraft({
    this.type = OrderServiceType.dineIn,
    this.table,
    this.customer = '',
    this.phone = '',
    this.addr = '',
    this.area,
    this.charge = 0,
    List<DesktopMenuLineSelection>? lines,
    this.discount,
  }) : lines = lines ?? <DesktopMenuLineSelection>[];

  OrderServiceType type;
  String? table;
  String customer;
  String phone;
  String addr;
  String? area;
  double charge;
  List<DesktopMenuLineSelection> lines;
  PosDiscountPreset? discount;

  int get count => lines.fold(0, (s, l) => s + l.qty);
}

/// Delivery areas → charge (jsx `DELIVERY_AREAS`). Used until the mobile
/// delivery-areas editor feeds desktop (Phase 4); null-safe default.
const List<(String, double)> kDkDeliveryAreas = [
  ('Dhanmondi', 60),
  ('Mohammadpur', 80),
  ('Banani', 100),
  ('Mirpur', 110),
  ('Uttara', 150),
  ('Other', 130),
];

/// The five desktop operational destinations. `dashboard` renders Analytics for
/// owners and Control Tower for managers (the jsx `analytics`/`tower` ids).
enum DeskTab { register, tables, orders, inventory, dashboard }

/// Which rail popover is open.
enum DeskPop { none, notif, account }

/// One nav entry: tab + EN/BN label + icon name (`dk_icons` key).
class DeskNavItem {
  const DeskNavItem(this.tab, this.labelEn, this.labelBn, this.icon);
  final DeskTab tab;
  final String labelEn;
  final String labelBn;
  final String icon;
}

/// Role-aware desktop nav (jsx `DESK_NAV` + `DESK_NAV_BN`). Back-office
/// (Menu/Settings/Staff/Audit) intentionally stays on the phone surface.
const Map<AccountRole, List<DeskNavItem>> kDeskNav = {
  AccountRole.owner: [
    DeskNavItem(DeskTab.register, 'Register', 'রেজিস্টার', 'bag'),
    DeskNavItem(DeskTab.tables, 'Tables', 'টেবিল', 'table'),
    DeskNavItem(DeskTab.orders, 'Orders', 'অর্ডার', 'receipt'),
    DeskNavItem(DeskTab.inventory, 'Stock', 'স্টক', 'box'),
    DeskNavItem(DeskTab.dashboard, 'Analytics', 'বিশ্লেষণ', 'chart'),
  ],
  AccountRole.manager: [
    DeskNavItem(DeskTab.register, 'Register', 'রেজিস্টার', 'bag'),
    DeskNavItem(DeskTab.tables, 'Tables', 'টেবিল', 'table'),
    DeskNavItem(DeskTab.orders, 'Orders', 'অর্ডার', 'receipt'),
    DeskNavItem(DeskTab.inventory, 'Stock', 'স্টক', 'box'),
    DeskNavItem(DeskTab.dashboard, 'Live', 'লাইভ', 'tower'),
  ],
  AccountRole.waiter: [
    DeskNavItem(DeskTab.register, 'Register', 'রেজিস্টার', 'bag'),
    DeskNavItem(DeskTab.tables, 'Tables', 'টেবিল', 'table'),
    DeskNavItem(DeskTab.orders, 'Orders', 'অর্ডার', 'receipt'),
  ],
};

List<DeskNavItem> deskNavForRole(AccountRole role) => kDeskNav[role] ?? kDeskNav[AccountRole.manager]!;

class DeskController extends ChangeNotifier {
  DeskTab _tab = DeskTab.register;
  DeskPop _pop = DeskPop.none;
  bool _msgOpen = false;
  String? _selOrderId;
  String? _toast;
  DeskDraft _draft = DeskDraft();

  DeskTab get tab => _tab;
  DeskPop get pop => _pop;
  bool get msgOpen => _msgOpen;
  String? get selOrderId => _selOrderId;
  String? get toastMessage => _toast;
  DeskDraft get draft => _draft;

  void setTab(DeskTab tab) {
    if (_tab == tab && _pop == DeskPop.none) return;
    _tab = tab;
    _pop = DeskPop.none;
    _selOrderId = null;
    notifyListeners();
  }

  /// Clamp to a permitted tab for [role]; falls back to Register. Called by the
  /// shell after a demo role switch (jsx: `if (!allowed.includes(tab)) setTab('register')`).
  void clampToRole(AccountRole role) {
    final allowed = deskNavForRole(role).map((e) => e.tab).toSet();
    if (!allowed.contains(_tab)) {
      _tab = DeskTab.register;
      notifyListeners();
    }
  }

  void togglePop(DeskPop which) {
    _pop = _pop == which ? DeskPop.none : which;
    notifyListeners();
  }

  void closePop() {
    if (_pop == DeskPop.none) return;
    _pop = DeskPop.none;
    notifyListeners();
  }

  void setMsgOpen(bool open) {
    if (_msgOpen == open) return;
    _msgOpen = open;
    if (open) _pop = DeskPop.none;
    notifyListeners();
  }

  void setSelOrder(String? id) {
    _selOrderId = id;
    notifyListeners();
  }

  void openOrder(String id) {
    _selOrderId = id;
    _tab = DeskTab.orders;
    _pop = DeskPop.none;
    notifyListeners();
  }

  Timer? _toastTimer;

  // ── Register draft mutations (jsx draft store) ─────────────────────────────

  void setDraftType(OrderServiceType type) {
    _draft.type = type;
    if (type != OrderServiceType.dineIn) _draft.table = null;
    if (type != OrderServiceType.delivery) {
      _draft.area = null;
      _draft.charge = 0;
    }
    notifyListeners();
  }

  void setDraftTable(String? table) {
    _draft.table = table;
    notifyListeners();
  }

  void setDraftArea(String area, double charge) {
    _draft.area = area;
    _draft.charge = charge;
    notifyListeners();
  }

  void setDraftCustomer(String v) {
    _draft.customer = v;
    notifyListeners();
  }

  void setDraftPhone(String v) {
    _draft.phone = v;
    notifyListeners();
  }

  void setDraftAddr(String v) {
    _draft.addr = v;
    notifyListeners();
  }

  void setDraftDiscount(PosDiscountPreset? preset) {
    _draft.discount = preset;
    notifyListeners();
  }

  /// Add a line, merging into an existing identical line (same [lineKey]).
  void addDraftLine(DesktopMenuLineSelection line) {
    final i = _draft.lines.indexWhere((l) => l.lineKey == line.lineKey);
    if (i >= 0) {
      _draft.lines[i] = _withQty(_draft.lines[i], _draft.lines[i].qty + line.qty);
    } else {
      _draft.lines.add(line);
    }
    notifyListeners();
  }

  void setDraftLineQty(String lineKey, int qty) {
    final i = _draft.lines.indexWhere((l) => l.lineKey == lineKey);
    if (i < 0) return;
    if (qty < 1) {
      _draft.lines.removeAt(i);
    } else {
      _draft.lines[i] = _withQty(_draft.lines[i], qty);
    }
    notifyListeners();
  }

  void removeDraftLine(String lineKey) {
    _draft.lines.removeWhere((l) => l.lineKey == lineKey);
    notifyListeners();
  }

  void clearDraft() {
    _draft = DeskDraft(type: _draft.type, table: _draft.table);
    notifyListeners();
  }

  void resetDraft() {
    _draft = DeskDraft();
    notifyListeners();
  }

  /// From Tables: start a dine-in order on [table] and jump to Register.
  void startDineIn(String table) {
    _draft = DeskDraft(type: OrderServiceType.dineIn, table: table);
    _tab = DeskTab.register;
    _pop = DeskPop.none;
    notifyListeners();
  }

  /// From Tables: start a parcel/delivery order and jump to Register.
  void startType(OrderServiceType type) {
    _draft = DeskDraft(type: type);
    _tab = DeskTab.register;
    _pop = DeskPop.none;
    notifyListeners();
  }

  void showToast(String message) {
    _toast = message;
    notifyListeners();
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(milliseconds: 1900), clearToast);
  }

  void clearToast() {
    if (_toast == null) return;
    _toast = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }
}

/// Provides [DeskController] to the desktop subtree.
class DeskScope extends InheritedNotifier<DeskController> {
  const DeskScope({required DeskController controller, required super.child, super.key})
      : super(notifier: controller);

  static DeskController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DeskScope>();
    assert(scope != null, 'DeskScope not found in the widget tree.');
    return scope!.notifier!;
  }

  static DeskController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<DeskScope>();
    assert(scope != null, 'DeskScope not found in the widget tree.');
    return scope!.notifier!;
  }
}
