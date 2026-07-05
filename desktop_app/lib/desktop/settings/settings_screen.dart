import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';

import '../audit/audit_screen.dart';
import '../messaging/messages_screen.dart';
import '../printing/bt_printer_channel.dart';
import '../staff/staff_screen.dart';
import '../theme/desk_theme.dart';

/// Settings hub: printer setup, language, admin links (Staff / Audit /
/// Messages) and logout. Camera/scan and webview-based sub-pages are excluded.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  List<String>? _queues;
  bool _detecting = false;
  int _paperWidth = 58;

  List<BtDevice>? _btDevices;
  String? _btAddress;
  bool _btScanning = false;

  @override
  void initState() {
    super.initState();
    _paperWidth = AppScope.read(context).printerState.windowsPaperWidthMm;
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? PosColors.danger : PosColors.secondary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _detect() async {
    setState(() => _detecting = true);
    try {
      final queues = await AppScope.read(context).listSystemPrinterQueues();
      if (mounted) setState(() => _queues = queues);
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''), error: true);
    } finally {
      if (mounted) setState(() => _detecting = false);
    }
  }

  Future<void> _selectQueue(String name) async {
    await AppScope.read(context)
        .selectSystemPrinterQueue(name, paperWidthMm: _paperWidth);
  }

  Future<void> _test() async {
    final ok = await AppScope.read(context).testPrinter();
    _toast(ok ? 'Test ticket sent' : 'Test print failed — check the printer',
        error: !ok);
  }

  Future<void> _scanBt() async {
    setState(() => _btScanning = true);
    final devices = await BtPrinter.listPaired();
    if (mounted) {
      setState(() {
        _btDevices = devices;
        _btScanning = false;
      });
    }
  }

  Future<void> _btTest() async {
    final address = _btAddress;
    if (address == null) return;
    final bytes = escPosTestTicket(AppScope.read(context).outletName);
    final ok = await BtPrinter.printBytes(address, bytes);
    _toast(ok ? 'Bluetooth test sent' : 'Bluetooth print failed', error: !ok);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final printer = app.printerState;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _printerCard(printer.selectedWindowsQueueName,
                        printer.autoPrintEnabled),
                    const SizedBox(height: 16),
                    _btCard(),
                    const SizedBox(height: 16),
                    _languageCard(app.language),
                    if (app.isManager) ...[
                      const SizedBox(height: 16),
                      _adminCard(app.isOwner),
                    ],
                    const SizedBox(height: 16),
                    _accountCard(app.restaurantName, app.accountDisplayName,
                        app.accountRole.label),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: const BoxDecoration(
          color: PosColors.surface,
          border: Border(bottom: BorderSide(color: PosColors.line)),
        ),
        child: const Text('Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      );

  Widget _printerCard(String? selected, bool autoPrint) {
    return _card('Receipt printer', [
      Row(
        children: [
          Expanded(
            child: Text(
              selected == null || selected.isEmpty
                  ? 'No printer selected'
                  : 'Selected: $selected',
              style: TextStyle(
                  fontSize: 13.5,
                  color: selected == null ? PosColors.muted : PosColors.ink2),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _detecting ? null : _detect,
            icon: _detecting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search_rounded, size: 16),
            label: const Text('Detect'),
          ),
        ],
      ),
      if (_queues != null) ...[
        const SizedBox(height: 10),
        if (_queues!.isEmpty)
          Text('No Windows print queues found.',
              style: TextStyle(fontSize: 12.5, color: PosColors.muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in _queues!)
                ChoiceChip(
                  label: Text(q, style: const TextStyle(fontSize: 12.5)),
                  selected: q == selected,
                  selectedColor: PosColors.primary,
                  labelStyle: TextStyle(
                      color: q == selected
                          ? Colors.white
                          : PosColors.primaryDark),
                  onSelected: (_) => _selectQueue(q),
                ),
            ],
          ),
      ],
      const SizedBox(height: 12),
      Row(
        children: [
          Text('Paper width',
              style: TextStyle(fontSize: 13, color: PosColors.ink2)),
          const SizedBox(width: 12),
          for (final w in [58, 80])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${w}mm'),
                selected: _paperWidth == w,
                selectedColor: PosColors.primary,
                labelStyle: TextStyle(
                    color: _paperWidth == w
                        ? Colors.white
                        : PosColors.primaryDark),
                onSelected: (_) async {
                  setState(() => _paperWidth = w);
                  if (selected != null && selected.isNotEmpty) {
                    await _selectQueue(selected);
                  }
                },
              ),
            ),
        ],
      ),
      SwitchListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeThumbColor: PosColors.primary,
        value: autoPrint,
        onChanged: (v) => AppScope.read(context).setAutoPrintOrders(v),
        title: const Text('Auto-print accepted orders',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _test,
          icon: const Icon(Icons.print_outlined, size: 16),
          label: const Text('Test print'),
        ),
      ),
    ]);
  }

  Widget _btCard() {
    return _card('Bluetooth printer (beta)', [
      Text(
        'For Bluetooth-Classic (SPP) thermal printers. Pair the printer in '
        'Windows settings first, then detect it here.',
        style: TextStyle(fontSize: 12.5, color: PosColors.muted),
      ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _btScanning ? null : _scanBt,
          icon: _btScanning
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.bluetooth_searching_rounded, size: 16),
          label: const Text('Detect paired'),
        ),
      ),
      if (_btDevices != null) ...[
        const SizedBox(height: 10),
        if (_btDevices!.isEmpty)
          Text('No paired Bluetooth devices found.',
              style: TextStyle(fontSize: 12.5, color: PosColors.muted))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final device in _btDevices!)
                ChoiceChip(
                  label: Text(device.name,
                      style: const TextStyle(fontSize: 12.5)),
                  selected: device.address == _btAddress,
                  selectedColor: PosColors.primary,
                  labelStyle: TextStyle(
                      color: device.address == _btAddress
                          ? Colors.white
                          : PosColors.primaryDark),
                  onSelected: (_) =>
                      setState(() => _btAddress = device.address),
                ),
            ],
          ),
        if (_btAddress != null) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _btTest,
              icon: const Icon(Icons.print_outlined, size: 16),
              label: const Text('Bluetooth test print'),
            ),
          ),
        ],
      ],
    ]);
  }

  Widget _languageCard(AppLanguage current) {
    return _card('Language', [
      Row(
        children: [
          for (final lang in AppLanguage.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(lang.label),
                selected: current == lang,
                selectedColor: PosColors.primary,
                labelStyle: TextStyle(
                    color: current == lang
                        ? Colors.white
                        : PosColors.primaryDark),
                onSelected: (_) => AppScope.read(context).updateLanguage(lang),
              ),
            ),
        ],
      ),
    ]);
  }

  Widget _adminCard(bool isOwner) {
    return _card('Manage', [
      _navRow(Icons.chat_bubble_outline_rounded, 'Messages',
          () => _push('Messages', const MessagesScreen())),
      if (isOwner) ...[
        const Divider(height: 1, color: PosColors.line),
        _navRow(Icons.people_alt_outlined, 'Staff',
            () => _push('Staff', const StaffScreen())),
        const Divider(height: 1, color: PosColors.line),
        _navRow(Icons.fact_check_outlined, 'Audit trail',
            () => _push('Audit trail', const AuditScreen())),
      ],
    ]);
  }

  Widget _accountCard(String restaurant, String name, String role) {
    return _card('Account', [
      _infoRow('Restaurant', restaurant.isEmpty ? '—' : restaurant),
      _infoRow('Signed in', name.isEmpty ? role : '$name · $role'),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: PosColors.danger),
          onPressed: () => AppScope.read(context).logOut(),
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('Log out'),
        ),
      ),
    ]);
  }

  void _push(String title, Widget screen) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: PosColors.background,
            appBar: AppBar(
              title: Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 17)),
              backgroundColor: PosColors.surface,
              foregroundColor: PosColors.primaryDark,
              elevation: 0,
              shape: const Border(
                  bottom: BorderSide(color: PosColors.line)),
            ),
            body: screen,
          ),
        ),
      );

  Widget _navRow(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 19, color: PosColors.ink2),
            const SizedBox(width: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: PosColors.muted),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: PosColors.muted)),
            const Spacer(),
            Text(value,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line),
        boxShadow: PosShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
