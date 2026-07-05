import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/desktop_pos.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
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
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          const Text('Day End',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
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
        width: 420,
        padding: const EdgeInsets.all(22),
        decoration: _cardDeco(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Open register',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: PosColors.primaryDark)),
            const SizedBox(height: 4),
            Text('Count the opening cash float.',
                style: TextStyle(fontSize: 12.5, color: PosColors.muted)),
            const SizedBox(height: 14),
            DenominationGrid(
                onChanged: (total, counts) => setState(() {
                      _drawerTotal = total;
                      _drawerCounts = counts;
                    })),
            const Divider(height: 24),
            _totalRow('Opening cash', _drawerTotal),
            const SizedBox(height: 16),
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PosColors.successSoft,
            borderRadius: BorderRadius.circular(PosRadii.md),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_open_rounded,
                  size: 18, color: PosColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Register open since $openedAt · opening ${money(context, shift.openingCash)}',
                  style: TextStyle(
                      fontSize: 13, color: PosColors.statePrintedInk),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (report != null) ...[
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _statCard('Sales', money(context, report.sales)),
              _statCard('Orders', '${report.orders}'),
              _statCard('Covers', '${report.covers}'),
              _statCard('Discounts', money(context, report.discounts)),
              _statCard('VAT', money(context, report.vatIncluded)),
            ],
          ),
          if (report.paymentSplit.isNotEmpty) ...[
            const SizedBox(height: 22),
            _sectionTitle('Payment collection'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: _cardDeco(),
              child: Column(
                children: [
                  for (final entry in report.paymentSplit.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text(_titleCase(entry.key),
                              style: TextStyle(color: PosColors.ink2)),
                          const Spacer(),
                          Text(money(context, entry.value),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
        const SizedBox(height: 22),
        _sectionTitle('Close register'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: _cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Count the cash in the drawer to close and get variance.',
                  style: TextStyle(fontSize: 12.5, color: PosColors.muted)),
              const SizedBox(height: 12),
              DenominationGrid(
                  onChanged: (total, counts) => setState(() {
                        _drawerTotal = total;
                        _drawerCounts = counts;
                      })),
              const Divider(height: 24),
              _totalRow('Counted cash', _drawerTotal),
              const SizedBox(height: 16),
              _primaryButton('Close register', _busy ? null : _close,
                  danger: true),
            ],
          ),
        ),
      ],
    );
  }

  // ── shared bits ──
  BoxDecoration _cardDeco() => BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
        boxShadow: PosShadows.soft,
      );

  Widget _statCard(String label, String value) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: PosColors.primaryDark)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12.5, color: PosColors.muted)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800));

  Widget _totalRow(String label, double value) => Row(
        children: [
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const Spacer(),
          Text(money(context, value),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: PosColors.primary)),
        ],
      );

  Widget _primaryButton(String label, VoidCallback? onTap,
      {bool danger = false}) {
    return SizedBox(
      height: 46,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: danger ? PosColors.danger : PosColors.primary,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosRadii.md)),
        ),
        onPressed: onTap,
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
            : Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
      ),
    );
  }

  String _titleCase(String key) =>
      key.isEmpty ? key : key[0].toUpperCase() + key.substring(1);
}
