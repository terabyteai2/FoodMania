// QuickBytes Desktop — Stock (ranked table). Faithful to `desktop-floor.jsx`
// StockScreen: KPI tiles + sort chips, a single fixed-width status-dot column
// keeps every row aligned, and a minimal Advanced toggle reveals the Cover
// column. Cover needs 7-day usage data we don't track yet, so it shows "—"
// (null-safe: hide, never fabricate).

import 'package:flutter/material.dart';

import '../../../app_scope.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/inventory_item.dart';
import '../desk_controller.dart';
import '../widgets/dk_kit.dart';

class DeskStockScreen extends StatefulWidget {
  const DeskStockScreen({super.key});

  @override
  State<DeskStockScreen> createState() => _DeskStockScreenState();
}

class _DeskStockScreenState extends State<DeskStockScreen> {
  bool _adv = false;
  String _sort = 'value';

  bool get _isBn => AppScope.of(context).language == AppLanguage.bn;
  String _t(String en, String bn) => _isBn ? bn : en;

  String _kind(InventoryItem it) => it.isOutOfStock ? 'no' : (it.isLowStock ? 'low' : 'ok');
  double _value(InventoryItem it) => it.quantity * it.costPerUnit;
  String _name(InventoryItem it) {
    final v = _isBn ? it.nameBn : it.nameEn;
    return v.trim().isNotEmpty ? v.trim() : it.name;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final desk = DeskScope.of(context);
    final rows = [...app.inventoryItems];
    rows.sort((a, b) {
      switch (_sort) {
        case 'qty':
          return b.quantity.compareTo(a.quantity);
        case 'name':
          return _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
        default:
          return _value(b).compareTo(_value(a));
      }
    });
    final totalValue = rows.fold<double>(0, (s, r) => s + _value(r));
    final below = rows.where((r) => _kind(r) != 'ok').length;

    return Container(
      color: Dk.bg,
      child: Column(
        children: [
          Container(
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
                      Text(_t('Stock', 'স্টক'), style: dkText(22, weight: FontWeight.w700, letterSpacing: -0.4)),
                      if (app.restaurantName.trim().isNotEmpty)
                        Text(app.restaurantName, maxLines: 1, overflow: TextOverflow.ellipsis, style: dkText(13, weight: FontWeight.w500, color: Dk.muted)),
                    ],
                  ),
                ),
                DkAdvToggle(on: _adv, label: _t('Advanced', 'অ্যাডভান্সড'), onChanged: (v) => setState(() => _adv = v)),
              ],
            ),
          ),
          // KPI + sort
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: DkKpi(label: _t('Stock value', 'স্টক মূল্য'), value: dkMoney(totalValue))),
                const SizedBox(width: 14),
                Expanded(child: DkKpi(label: _t('Below par', 'পার-এর নিচে'), value: '$below ${_t('items', 'আইটেম')}', valueColor: below > 0 ? Dk.warning : Dk.ink)),
                const SizedBox(width: 14),
                Expanded(child: DkKpi(label: _t('Tracked items', 'মোট আইটেম'), value: '${rows.length}')),
                const SizedBox(width: 14),
                Expanded(
                  flex: 1,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _sortChip('value', _t('Value', 'মূল্য')),
                      _sortChip('qty', _t('Qty', 'পরিমাণ')),
                      if (_adv) _sortChip('cover', _t('Cover', 'কভার')),
                      _sortChip('name', 'A–Z'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: _table(rows),
            ),
          ),
          Container(
            decoration: const BoxDecoration(color: Dk.surface, border: Border(top: BorderSide(color: Dk.line))),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                DkButton(label: _t('Count', 'গণনা'), icon: 'count', variant: DkBtnVariant.ghost, size: DkBtnSize.lg, onTap: () => desk.showToast(_t('Starting count', 'স্টক গণনা শুরু'))),
                const SizedBox(width: 10),
                DkButton(label: _t('Stock in', 'স্টক ইন'), icon: 'boxin', variant: DkBtnVariant.primary, size: DkBtnSize.lg, onTap: () => desk.showToast(_t('Stock in', 'স্টক ইন'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sortChip(String id, String label) =>
      DkChip(label: label, active: _sort == id, onTap: () => setState(() => _sort = id));

  Widget _table(List<InventoryItem> rows) {
    Color? dotColor(String kind) => kind == 'no' ? Dk.danger : (kind == 'low' ? Dk.warning : null);
    TextStyle headStyle() => dkText(11.5, weight: FontWeight.w700, color: Dk.muted, letterSpacing: 0.45);

    return Column(
      children: [
        // header
        Container(
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Dk.line2))),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const SizedBox(width: 34),
              SizedBox(width: 30, child: Text('#'.toUpperCase(), style: headStyle())),
              Expanded(child: Text(_t('Item', 'আইটেম').toUpperCase(), style: headStyle())),
              if (_adv) SizedBox(width: 110, child: Text(_t('Cover', 'কভার').toUpperCase(), textAlign: TextAlign.right, style: headStyle())),
              SizedBox(width: 130, child: Text(_t('Value', 'মূল্য').toUpperCase(), textAlign: TextAlign.right, style: headStyle())),
              SizedBox(width: 110, child: Text(_t('Qty', 'পরিমাণ').toUpperCase(), style: headStyle())),
            ],
          ),
        ),
        for (var i = 0; i < rows.length; i++) _row(rows[i], i, dotColor),
      ],
    );
  }

  Widget _row(InventoryItem it, int i, Color? Function(String) dotColor) {
    final kind = _kind(it);
    final dc = dotColor(kind);
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Dk.line))),
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Center(
              child: dc == null
                  ? const SizedBox.shrink()
                  : Container(width: 9, height: 9, decoration: BoxDecoration(color: dc, shape: BoxShape.circle)),
            ),
          ),
          SizedBox(width: 30, child: Text('${i + 1}', style: dkNum(14, weight: FontWeight.w600, color: Dk.muted))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_name(it), style: dkText(14, weight: FontWeight.w600)),
                Text(
                  kind != 'ok'
                      ? '${it.category} · ${_t('par', 'পার')} ${it.minThreshold.round()} ${it.unit}'
                      : it.category,
                  style: dkText(12, color: Dk.muted),
                ),
              ],
            ),
          ),
          if (_adv)
            SizedBox(
              width: 110,
              child: Text('—', textAlign: TextAlign.right, style: dkText(14, weight: FontWeight.w600, color: Dk.muted)),
            ),
          SizedBox(width: 130, child: Text(dkMoney(_value(it)), textAlign: TextAlign.right, style: dkNum(14, weight: FontWeight.w700))),
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Text('${it.quantity % 1 == 0 ? it.quantity.toInt() : it.quantity} ', style: dkNum(14, weight: FontWeight.w700)),
                Text(it.unit, style: dkText(14, weight: FontWeight.w500, color: Dk.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
