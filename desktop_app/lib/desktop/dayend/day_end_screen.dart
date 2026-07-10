import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/desktop_pos.dart';
import 'package:local_pos/src/models/order_payment_method.dart';
import 'package:local_pos/src/models/order_service_type.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
import '../theme/desk_widgets.dart';
import 'denomination_grid.dart';

/// Register shift + Day-End / Z-report (petpooja16/17). Open the register with a
/// counted float, watch the live Z-report, and close with a counted drawer
/// (expected-vs-counted variance).
class DayEndScreen extends StatefulWidget {
  const DayEndScreen({super.key});

  @override
  State<DayEndScreen> createState() => _DayEndScreenState();
}

class _DayEndScreenState extends State<DayEndScreen> {
  PosShift? _shift;
  PosReportSnapshot? _report;
  bool _loading = true;
  bool _busy = false;

  double _drawerTotal = 0;
  Map<String, int> _drawerCounts = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    final shift = await app.currentDesktopShift();
    final report = await app.desktopPosReport(days: 1);
    if (!mounted) return;
    setState(() {
      _shift = shift?.isOpen == true ? shift : null;
      _report = report;
      _loading = false;
      _drawerTotal = 0;
      _drawerCounts = const {};
    });
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? PosColors.danger : PosColors.secondary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final app = AppScope.read(context);
      await app.openDesktopShift(
        openingCash: _drawerTotal,
        denominations: _drawerCounts,
      );
      await _load();
      _toast('Register opened');
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final shift = _shift;
    if (shift == null) return;
    setState(() => _busy = true);
    try {
      final app = AppScope.read(context);
      final closed = await app.closeDesktopShift(
        shift: shift,
        countedCash: _drawerTotal,
        denominations: _drawerCounts,
      );
      if (!mounted) return;
      final variance = closed.varianceCash ?? 0;
      final message = variance == 0
          ? 'Register closed · balanced'
          : 'Register closed · variance ${money(context, variance)}';
      await _load();
      _toast(message);
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _shift == null ? _openPanel() : _openShiftBody(),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          const Text('Day End',
              style: TextStyle(fontSize: DeskTypography.displayPushed, fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            color: PosColors.ink2,
            onPressed: _load,
          ),
        ],
      ),
    );
  }

  Widget _openPanel() {
    return Center(
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(26),
        decoration: _cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Open register',
                style: TextStyle(
                    fontSize: DeskTypography.h1,
                    fontWeight: FontWeight.w800,
                    color: PosColors.primaryDark)),
            const SizedBox(height: 6),
            Text('Count the opening cash float.',
                style: TextStyle(fontSize: DeskTypography.body, color: PosColors.muted)),
            const SizedBox(height: 18),
            DenominationGrid(
                onChanged: (total, counts) => setState(() {
                      _drawerTotal = total;
                      _drawerCounts = counts;
                    })),
            const Divider(height: 28),
            _totalRow('Opening cash', _drawerTotal),
            const SizedBox(height: 18),
            _primaryButton('Open register', _busy ? null : _open),
          ],
        ),
      ),
    );
  }

  Widget _openShiftBody() {
    final report = _report;
    final shift = _shift!;
    final openedAt = DateFormat('d MMM · h:mm a').format(shift.openedAt.toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PosColors.successSoft,
            borderRadius: BorderRadius.circular(PosRadii.md),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_open_rounded,
                  size: 20, color: PosColors.success),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Register open since $openedAt · opening ${money(context, shift.openingCash)}',
                  style: TextStyle(
                      fontSize: DeskTypography.body, color: PosColors.statePrintedInk),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        if (report != null) ...[
          Wrap(
            spacing: DeskMetrics.panelGap,
            runSpacing: DeskMetrics.panelGap,
            children: [
              DeskStatTile(
                  icon: Icons.payments_rounded,
                  label: 'Sales',
                  value: money(context, report.sales),
                  width: 210),
              DeskStatTile(
                  icon: Icons.receipt_long_rounded,
                  label: 'Orders',
                  value: '${report.orders}',
                  width: 210),
              DeskStatTile(
                  icon: Icons.groups_rounded,
                  label: 'Covers',
                  value: '${report.covers}',
                  width: 210),
              DeskStatTile(
                  icon: Icons.sell_rounded,
                  label: 'Discounts',
                  value: money(context, report.discounts),
                  width: 210),
              DeskStatTile(
                  icon: Icons.percent_rounded,
                  label: 'VAT',
                  value: money(context, report.vatIncluded),
                  width: 210),
            ],
          ),
          if (_paymentSlices(report).isNotEmpty ||
              _serviceSlices(report).isNotEmpty) ...[
            const SizedBox(height: DeskMetrics.panelGap),
            Wrap(
              spacing: DeskMetrics.panelGap,
              runSpacing: DeskMetrics.panelGap,
              children: [
                if (_paymentSlices(report).isNotEmpty)
                  DeskCard(
                    width: 440,
                    title: 'Payment collection',
                    child: DeskDonut(
                      centerValue: money(context, _paymentTotal(report)),
                      centerLabel: 'collected',
                      data: _paymentSlices(report),
                    ),
                  ),
                if (_serviceSlices(report).isNotEmpty)
                  DeskCard(
                    width: 360,
                    title: 'Service-wise sales',
                    child: DeskBars(data: _serviceSlices(report)),
                  ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 26),
        _sectionTitle('Close register'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: _cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Count the cash in the drawer to close and get variance.',
                  style: TextStyle(fontSize: DeskTypography.body, color: PosColors.muted)),
              const SizedBox(height: 14),
              DenominationGrid(
                  onChanged: (total, counts) => setState(() {
                        _drawerTotal = total;
                        _drawerCounts = counts;
                      })),
              const Divider(height: 28),
              _totalRow('Counted cash', _drawerTotal),
              const SizedBox(height: 18),
              _primaryButton('Close register', _busy ? null : _close,
                  danger: true),
            ],
          ),
        ),
      ],
    );
  }

  // ── shared bits ──
  BoxDecoration _cardDeco() => deskCardDecoration();

  /// Payment split → donut slices, keyed through the real OrderPaymentMethod
  /// labels (bkash/nagad/…), not raw wire strings.
  List<DeskDatum> _paymentSlices(PosReportSnapshot report) {
    final isBn = AppScope.of(context).language.code == 'bn';
    final slices = <DeskDatum>[];
    for (final entry in report.paymentSplit.entries) {
      if (entry.value <= 0) continue;
      final method = OrderPaymentMethod.tryParse(entry.key);
      final label = method == null
          ? _titleCase(entry.key)
          : (isBn ? method.banglaLabel : method.label);
      slices.add(DeskDatum(label, entry.value, money(context, entry.value)));
    }
    return slices;
  }

  double _paymentTotal(PosReportSnapshot report) => report.paymentSplit.values
      .where((v) => v > 0)
      .fold(0.0, (a, b) => a + b);

  /// Service split → bars, keyed through OrderServiceType (Dine-in/Parcel/…).
  List<DeskDatum> _serviceSlices(PosReportSnapshot report) {
    final isBn = AppScope.of(context).language.code == 'bn';
    final slices = <DeskDatum>[];
    for (final entry in report.serviceSplit.entries) {
      if (entry.value <= 0) continue;
      final type = OrderServiceType.tryParse(entry.key);
      final label = type?.localized(isBn) ?? _titleCase(entry.key);
      slices.add(DeskDatum(label, entry.value, money(context, entry.value)));
    }
    return slices;
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: DeskTypography.h3, fontWeight: FontWeight.w800));

  Widget _totalRow(String label, double value) => Row(
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: DeskTypography.h2)),
          const Spacer(),
          Text(money(context, value),
              style: TextStyle(
                  fontSize: DeskTypography.h1,
                  fontWeight: FontWeight.w800,
                  color: PosColors.primary)),
        ],
      );

  Widget _primaryButton(String label, VoidCallback? onTap,
      {bool danger = false}) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: danger ? PosColors.danger : PosColors.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosRadii.md)),
        ),
        onPressed: onTap,
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.6, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: DeskTypography.h2)),
      ),
    );
  }

  String _titleCase(String key) =>
      key.isEmpty ? key : key[0].toUpperCase() + key.substring(1);
}
