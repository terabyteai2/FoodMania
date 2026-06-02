import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../models/desktop_pos.dart';
import '../../models/order_model.dart';
import '../inventory/inventory_screen.dart';
import '../menu/menu_management_screen.dart';
import '../settings/settings_screen.dart';
import 'screens/analytics_screen.dart';
import 'screens/counter_screen.dart';
import 'screens/day_open_screen.dart';
import 'screens/floor_screen.dart';
import 'screens/order_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/z_report_screen.dart';
import 'widgets/pc_shell.dart';
import 'widgets/pc_theme.dart';

/// Desktop "Computer OS" POS shell. Owns navigation + the shared chrome and
/// routes to the rebuilt screens; all data still flows through the existing
/// [PosAppController] methods (createDesktopOrder / settleDesktopOrder /
/// sendDesktopKot / openDesktopShift / closeDesktopShift / desktopPosReport).
class DesktopPosShell extends StatefulWidget {
  const DesktopPosShell({this.onMounted, super.key});

  final VoidCallback? onMounted;

  @override
  State<DesktopPosShell> createState() => _DesktopPosShellState();
}

class _DesktopPosShellState extends State<DesktopPosShell> {
  PcNav _section = PcNav.counter;
  DesktopPosSettings? _settings;
  PosShift? _shift;
  PosReportSnapshot? _report;
  OrderModel? _activeOrder;
  String? _draftTableNo;
  bool _showZ = false;
  StreamSubscription<void>? _databaseSubscription;
  bool _loading = true;
  bool _bootstrapCloudStarted = false;
  int _receiptPrinterOpenRequest = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMounted?.call();
      final app = AppScope.of(context);
      _databaseSubscription = app.database.changes.listen((_) => _reload());
      unawaited(_reload());
    });
  }

  @override
  void dispose() {
    unawaited(_databaseSubscription?.cancel());
    super.dispose();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    final app = AppScope.of(context);
    if (!_bootstrapCloudStarted) {
      _bootstrapCloudStarted = true;
      unawaited(app.refreshDesktopPosFromCloud().then((_) => _reload()));
    }
    final settings = await app.loadDesktopPosSettings();
    final shift = await app.currentDesktopShift();
    final report = await app.desktopPosReport();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _shift = shift;
      _report = report;
      _loading = false;
      // Refresh the active order reference if it changed underneath us.
      if (_activeOrder != null) {
        _activeOrder = app.orders.firstWhere(
          (o) => o.id == _activeOrder!.id,
          orElse: () => _activeOrder!,
        );
      }
    });
  }

  void _navigate(PcNav nav) => setState(() {
    _section = nav;
    _activeOrder = null;
    _showZ = false;
    _draftTableNo = null;
  });

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.f1): _NavIntent(PcNav.counter),
        SingleActivator(LogicalKeyboardKey.f2): _NavIntent(PcNav.floor),
        SingleActivator(LogicalKeyboardKey.f3): _NavIntent(PcNav.orders),
        SingleActivator(LogicalKeyboardKey.f4): _NavIntent(PcNav.menu),
        SingleActivator(LogicalKeyboardKey.f5): _NavIntent(PcNav.stock),
        SingleActivator(LogicalKeyboardKey.f6): _NavIntent(PcNav.reports),
        SingleActivator(LogicalKeyboardKey.keyP, control: true): _PrintIntent(),
        SingleActivator(LogicalKeyboardKey.keyS, control: true): _SyncIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
      },
      child: Actions(
        actions: {
          _NavIntent: CallbackAction<_NavIntent>(
            onInvoke: (intent) {
              _navigate(intent.section);
              return null;
            },
          ),
          _PrintIntent: CallbackAction<_PrintIntent>(
            onInvoke: (_) {
              if (_activeOrder != null) unawaited(_print(_activeOrder!));
              return null;
            },
          ),
          _SyncIntent: CallbackAction<_SyncIntent>(
            onInvoke: (_) {
              unawaited(_sync());
              return null;
            },
          ),
          _CancelIntent: CallbackAction<_CancelIntent>(
            onInvoke: (_) {
              setState(() {
                if (_activeOrder != null) {
                  _activeOrder = null;
                } else if (_showZ) {
                  _showZ = false;
                } else {
                  _draftTableNo = null;
                  _section = PcNav.counter;
                }
              });
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Pc.bg,
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : _activeBody(),
          ),
        ),
      ),
    );
  }

  PcChrome _chrome(PosAppController app) {
    return PcChrome(
      onNav: _navigate,
      outletName: app.outletName,
      counterLabel: 'Counter 1',
      online: app.syncState.cloudConnected,
      pendingCount: app.syncState.pendingCount,
      lastSyncLabel: app.syncState.cloudConnected ? 'Synced' : null,
      printerLabel: app.printerState.selectedPrinterLabel,
      printerReady: _printerReady(app.printerState.selectedPrinterLabel),
      onPrinter: _openPrinterSettings,
      isBn: app.strings.isBn,
      onToggleLang: _toggleLang,
      shiftOpen: _shift != null,
      shiftClock: _shift == null ? null : _elapsed(_shift!.openedAt),
      userInitials: _initials(app.outletName),
      alertBadge: 0,
    );
  }

  Widget _activeBody() {
    final app = AppScope.of(context);
    final chrome = _chrome(app);
    final settings =
        _settings ??
        DesktopPosSettings(floorLayout: DesktopPosSettings.fallbackFloor(10));

    if (_activeOrder != null) {
      return OrderScreen(
        chrome: chrome,
        order: _activeOrder!,
        settings: settings,
        shift: _shift,
        onChanged: (order) => setState(() => _activeOrder = order),
        onBack: () => setState(() => _activeOrder = null),
        onPrint: _print,
        onPrintPrebill: _printPrebill,
      );
    }

    if (_showZ && _shift != null && _report != null) {
      return ZReportScreen(
        chrome: chrome,
        report: _report!,
        shift: _shift!,
        onClose: _closeShift,
        onBack: () => setState(() => _showZ = false),
        onPrintZ: () => _message(
          _t(
            'Z report sent to printer.',
            'Z রিপোর্ট প্রিন্টারে পাঠানো হয়েছে।',
          ),
        ),
      );
    }

    final needsShift =
        _section == PcNav.counter ||
        _section == PcNav.floor ||
        _section == PcNav.orders ||
        _section == PcNav.reports;
    if (_shift == null && needsShift) {
      return DayOpenScreen(chrome: chrome, onStart: _openShift);
    }

    switch (_section) {
      case PcNav.counter:
        return CounterScreen(
          key: ValueKey(_draftTableNo),
          chrome: chrome,
          settings: settings,
          shift: _shift,
          initialTableNo: _draftTableNo,
          onRequireShift: () => setState(() {}),
          onOrderSaved: (order) => setState(() {
            _draftTableNo = null;
            _activeOrder = order;
          }),
        );
      case PcNav.floor:
        return FloorScreen(
          chrome: chrome,
          settings: settings,
          orders: app.orders,
          onConfigure: app.isManager ? _configureFloor : null,
          onTable: (tableNo, order) => setState(() {
            if (order != null) {
              _activeOrder = order;
            } else {
              _draftTableNo = tableNo;
              _section = PcNav.counter;
            }
          }),
        );
      case PcNav.orders:
        return OrdersScreen(
          chrome: chrome,
          orders: app.orders,
          onOpen: (order) => setState(() => _activeOrder = order),
        );
      case PcNav.menu:
        return PcShell(
          chrome: chrome,
          activeNav: PcNav.menu,
          title: _t('Menu', 'মেনু'),
          child: const MenuManagementScreen(desktop: true),
        );
      case PcNav.stock:
        return PcShell(
          chrome: chrome,
          activeNav: PcNav.stock,
          title: _t('Stock', 'স্টক'),
          child: const InventoryScreen(),
        );
      case PcNav.reports:
        return AnalyticsScreen(
          chrome: chrome,
          report: _report!,
          canCloseDay: _shift != null && app.isManager,
          onCloseDay: () {
            if (!app.isManager) {
              _message(
                _t(
                  'Only a manager can close the register.',
                  'শুধু ম্যানেজার রেজিস্টার বন্ধ করতে পারবেন।',
                ),
              );
              return;
            }
            setState(() => _showZ = true);
          },
        );
      case PcNav.settings:
        return PcShell(
          chrome: chrome,
          activeNav: PcNav.settings,
          title: _t('Settings', 'সেটিংস'),
          topActions: [
            if (app.isManager)
              _PcGhost(
                label: _t('Desktop POS setup', 'ডেস্কটপ POS সেটআপ'),
                onTap: _configureFloor,
              ),
            _PcGhost(
              label: _t('Printer', 'প্রিন্টার'),
              onTap: _openPrinterSettings,
            ),
          ],
          child: SettingsScreen(
            receiptPrinterOpenRequest: _receiptPrinterOpenRequest,
          ),
        );
    }
  }

  // ---- controller-backed actions -----------------------------------------
  Future<void> _openShift(double total, Map<String, int> denoms) async {
    try {
      await AppScope.of(
        context,
      ).openDesktopShift(openingCash: total, denominations: denoms);
      await _reload();
    } catch (error) {
      _message('$error');
    }
  }

  Future<void> _closeShift(double counted, Map<String, int> denoms) async {
    final shift = _shift;
    if (shift == null) return;
    final app = AppScope.of(context);
    try {
      final closed = await app.closeDesktopShift(
        shift: shift,
        countedCash: counted,
        denominations: denoms,
      );
      if (!mounted) return;
      setState(() => _showZ = false);
      await _reload();
      _message(
        _t(
          'Day closed · variance ${pcMoney(closed.varianceCash ?? 0)}',
          'দিন শেষ · পার্থক্য ${pcMoney(closed.varianceCash ?? 0)}',
        ),
      );
    } catch (error) {
      _message('$error');
    }
  }

  Future<void> _configureFloor() async {
    final settings = _settings;
    if (settings == null) return;
    final result = await showDialog<DesktopPosSettings>(
      context: context,
      builder: (_) => _FloorSettingsDialog(settings: settings),
    );
    if (result == null || !mounted) return;
    try {
      await AppScope.of(context).saveDesktopPosSettings(result);
      await _reload();
    } catch (error) {
      _message('$error');
    }
  }

  void _openPrinterSettings() {
    setState(() {
      _activeOrder = null;
      _showZ = false;
      _draftTableNo = null;
      _section = PcNav.settings;
      _receiptPrinterOpenRequest++;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _receiptPrinterOpenRequest = 0);
    });
  }

  Future<void> _print(OrderModel order) async {
    final ok = await AppScope.of(context).printCustomerInvoice(order);
    if (mounted) {
      _message(
        ok
            ? _t('Receipt sent to printer.', 'রিসিট প্রিন্টারে পাঠানো হয়েছে।')
            : _t('Printer is unavailable.', 'প্রিন্টার পাওয়া যাচ্ছে না।'),
      );
    }
  }

  Future<void> _printPrebill(OrderModel order) async {
    final ok = await AppScope.of(context).printOrderTicket(order);
    if (mounted) {
      _message(
        ok
            ? _t(
                'Pre-bill sent to printer.',
                'প্রি-বিল প্রিন্টারে পাঠানো হয়েছে।',
              )
            : _t('Printer is unavailable.', 'প্রিন্টার পাওয়া যাচ্ছে না।'),
      );
    }
  }

  Future<void> _sync() async {
    final ok = await AppScope.of(context).syncNow();
    await _reload();
    if (mounted) {
      _message(
        ok
            ? _t('Sync complete.', 'সিঙ্ক সম্পন্ন হয়েছে।')
            : _t('Sync could not complete.', 'সিঙ্ক সম্পন্ন হয়নি।'),
      );
    }
  }

  void _toggleLang() {
    final app = AppScope.of(context);
    app.updateLanguage(
      app.language.code == 'en' ? AppLanguage.bn : AppLanguage.en,
    );
  }

  // ---- helpers ------------------------------------------------------------
  String _t(String en, String bn) =>
      AppScope.of(context).strings.isBn ? bn : en;

  bool _printerReady(String label) {
    final lower = label.toLowerCase();
    return label.isNotEmpty &&
        !lower.contains('no ') &&
        !lower.contains('none');
  }

  String _elapsed(DateTime since) {
    final d = DateTime.now().difference(since);
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'TF';
    if (words.length == 1) {
      return words.first.characters.take(2).toString().toUpperCase();
    }
    return (words[0].characters.first + words[1].characters.first)
        .toUpperCase();
  }

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }
}

// ============================================================================
// Keyboard intents
// ============================================================================
class _NavIntent extends Intent {
  const _NavIntent(this.section);
  final PcNav section;
}

class _PrintIntent extends Intent {
  const _PrintIntent();
}

class _SyncIntent extends Intent {
  const _SyncIntent();
}

class _CancelIntent extends Intent {
  const _CancelIntent();
}

/// Small ghost-style top action button reused by the settings PcShell header.
class _PcGhost extends StatelessWidget {
  const _PcGhost({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: PosColors.primaryDark,
      side: const BorderSide(color: PosColors.lineStrong),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.sm),
      ),
    ),
    child: Text(label),
  );
}

// ============================================================================
// Floor / discount / printer configuration dialogs (kept from prior shell —
// they edit DesktopPosSettings + select the Windows print queue).
// ============================================================================
String _dlg(BuildContext context, String en, String bn) =>
    AppScope.of(context).strings.isBn ? bn : en;

class _FloorSettingsDialog extends StatefulWidget {
  const _FloorSettingsDialog({required this.settings});
  final DesktopPosSettings settings;
  @override
  State<_FloorSettingsDialog> createState() => _FloorSettingsDialogState();
}

class _FloorSettingsDialogState extends State<_FloorSettingsDialog> {
  late final List<PosFloorZone> _zones = [...widget.settings.floorLayout];
  late final List<PosDiscountPreset> _presets = [
    ...widget.settings.discountPresets,
  ];
  late final TextEditingController _vat = TextEditingController(
    text: '${widget.settings.vatRatePercent}',
  );
  late final TextEditingController _service = TextEditingController(
    text: '${widget.settings.serviceChargePercent}',
  );

  @override
  void dispose() {
    _vat.dispose();
    _service.dispose();
    super.dispose();
  }

  int get _tableCount =>
      _zones.fold(0, (total, zone) => total + zone.tables.length);

  void _replaceZone(int index, {String? name, List<PosFloorTable>? tables}) {
    final current = _zones[index];
    _zones[index] = PosFloorZone(
      id: current.id,
      name: name ?? current.name,
      sortOrder: index,
      tables: tables ?? current.tables,
    );
  }

  void _addZone() => setState(() {
    final next = _tableCount + 1;
    _zones.add(
      PosFloorZone(
        id: const Uuid().v4(),
        name: _dlg(
          context,
          'Zone ${_zones.length + 1}',
          'জোন ${_zones.length + 1}',
        ),
        sortOrder: _zones.length,
        tables: [PosFloorTable(id: const Uuid().v4(), label: '$next')],
      ),
    );
  });

  void _addTable(int zoneIndex) {
    if (_tableCount >= 200) return;
    setState(() {
      final zone = _zones[zoneIndex];
      _replaceZone(
        zoneIndex,
        tables: [
          ...zone.tables,
          PosFloorTable(
            id: const Uuid().v4(),
            label: '${_tableCount + 1}',
            sortOrder: zone.tables.length,
          ),
        ],
      );
    });
  }

  void _removeTable(int zoneIndex, String tableId) => setState(() {
    final zone = _zones[zoneIndex];
    _replaceZone(
      zoneIndex,
      tables: zone.tables
          .where((table) => table.id != tableId)
          .toList(growable: false),
    );
  });

  Future<void> _addPreset() async {
    final preset = await showDialog<PosDiscountPreset>(
      context: context,
      builder: (_) => const _DiscountPresetDialog(),
    );
    if (preset != null) setState(() => _presets.add(preset));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_dlg(context, 'Desktop POS setup', 'ডেস্কটপ POS সেটআপ')),
    content: SizedBox(
      width: 620,
      height: 580,
      child: ListView(
        children: [
          Text(
            _dlg(
              context,
              'Zones and table labels are shared with desktop. Mobile receives the synchronized total table count.',
              'জোন ও টেবিল লেবেল ডেস্কটপে শেয়ার হবে। মোবাইলে মোট টেবিল সংখ্যা যাবে।',
            ),
          ),
          const SizedBox(height: 12),
          for (var zoneIndex = 0; zoneIndex < _zones.length; zoneIndex++)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _zones[zoneIndex].name,
                            decoration: InputDecoration(
                              labelText: _dlg(
                                context,
                                'Zone name',
                                'জোনের নাম',
                              ),
                            ),
                            onChanged: (value) =>
                                _replaceZone(zoneIndex, name: value),
                          ),
                        ),
                        IconButton(
                          onPressed: _zones.length == 1
                              ? null
                              : () =>
                                    setState(() => _zones.removeAt(zoneIndex)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final table in _zones[zoneIndex].tables)
                          InputChip(
                            label: Text(
                              _dlg(
                                context,
                                'T${table.label}  ${table.seats} seats',
                                'T${table.label}  ${table.seats} আসন',
                              ),
                            ),
                            onDeleted: () => _removeTable(zoneIndex, table.id),
                          ),
                        ActionChip(
                          label: Text(_dlg(context, '+ Table', '+ টেবিল')),
                          onPressed: () => _addTable(zoneIndex),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _addZone,
            icon: const Icon(Icons.add),
            label: Text(_dlg(context, 'Add floor zone', 'ফ্লোর জোন যোগ করুন')),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _vat,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'VAT %'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _service,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _dlg(
                      context,
                      'Service charge %',
                      'সার্ভিস চার্জ %',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                _dlg(context, 'Staff quick discounts', 'স্টাফ দ্রুত ডিসকাউন্ট'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _addPreset,
                icon: const Icon(Icons.add),
                label: Text(_dlg(context, 'Preset', 'প্রিসেট')),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            children: [
              for (final preset in _presets)
                InputChip(
                  label: Text(
                    '${preset.label}  ${preset.kind == 'percent' ? '${preset.value}%' : '৳${preset.value}'}',
                  ),
                  onDeleted: () => setState(() => _presets.remove(preset)),
                ),
            ],
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_dlg(context, 'Cancel', 'বাতিল')),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          DesktopPosSettings(
            floorLayout: _zones,
            vatRatePercent: (double.tryParse(_vat.text) ?? 0).clamp(0, 100),
            serviceChargePercent: (double.tryParse(_service.text) ?? 0).clamp(
              0,
              100,
            ),
            discountPresets: _presets,
          ),
        ),
        child: Text(_dlg(context, 'Save', 'সেভ')),
      ),
    ],
  );
}

class _DiscountPresetDialog extends StatefulWidget {
  const _DiscountPresetDialog();
  @override
  State<_DiscountPresetDialog> createState() => _DiscountPresetDialogState();
}

class _DiscountPresetDialogState extends State<_DiscountPresetDialog> {
  final _label = TextEditingController();
  final _value = TextEditingController();
  String _kind = 'percent';

  @override
  void dispose() {
    _label.dispose();
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      _dlg(context, 'Quick discount preset', 'দ্রুত ডিসকাউন্ট প্রিসেট'),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _label,
          decoration: InputDecoration(
            labelText: _dlg(context, 'Label', 'লেবেল'),
          ),
        ),
        DropdownButtonFormField(
          initialValue: _kind,
          items: [
            DropdownMenuItem(
              value: 'percent',
              child: Text(_dlg(context, 'Percentage', 'শতাংশ')),
            ),
            DropdownMenuItem(
              value: 'fixed',
              child: Text(_dlg(context, 'Fixed amount', 'নির্দিষ্ট পরিমাণ')),
            ),
          ],
          onChanged: (value) => setState(() => _kind = value!),
        ),
        TextField(
          controller: _value,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: _dlg(context, 'Value', 'মান')),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_dlg(context, 'Cancel', 'বাতিল')),
      ),
      FilledButton(
        onPressed: () {
          final value = double.tryParse(_value.text) ?? 0;
          if (_label.text.trim().isEmpty ||
              value <= 0 ||
              _kind == 'percent' && value > 100) {
            return;
          }
          Navigator.pop(
            context,
            PosDiscountPreset(
              id: const Uuid().v4(),
              label: _label.text.trim(),
              kind: _kind,
              value: value,
            ),
          );
        },
        child: Text(_dlg(context, 'Add', 'যোগ করুন')),
      ),
    ],
  );
}
