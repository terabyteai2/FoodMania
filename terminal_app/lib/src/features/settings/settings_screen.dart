import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../models/pos_notification.dart';
import '../../services/printer_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    this.receiptPrinterOpenRequest = 0,
    super.key,
  });

  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final int receiptPrinterOpenRequest;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _cloudUrlController = TextEditingController();
  final TextEditingController _restaurantIdController = TextEditingController();
  final TextEditingController _outletIdController = TextEditingController();
  final TextEditingController _syncIntervalController = TextEditingController();
  final TextEditingController _settingsSearchController =
      TextEditingController();
  Timer? _autoSaveDebounce;
  bool _cloudSyncEnabled = false;
  double _displayScale = 1.0;
  bool _hydrated = false;
  int _handledReceiptPrinterOpenRequest = 0;

  bool get _showDeferredSettings => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    final app = AppScope.of(context);
    _restaurantController.text = app.serverConfig.restaurantName;
    _cloudUrlController.text = app.cloudConfig.baseUrl;
    _restaurantIdController.text = app.serverConfig.restaurantId;
    _outletIdController.text = app.serverConfig.outletId;
    _syncIntervalController.text = app.cloudConfig.autoSyncIntervalSeconds
        .toString();
    _cloudSyncEnabled = app.cloudConfig.enabled;
    _displayScale = app.uiScale;
    _restaurantController.addListener(_scheduleAutoSave);
    _cloudUrlController.addListener(_scheduleAutoSave);
    _outletIdController.addListener(_scheduleAutoSave);
    _syncIntervalController.addListener(_scheduleAutoSave);
    _hydrated = true;
    _openRequestedReceiptPrinterIfNeeded();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receiptPrinterOpenRequest !=
        widget.receiptPrinterOpenRequest) {
      _openRequestedReceiptPrinterIfNeeded();
    }
  }

  void _openRequestedReceiptPrinterIfNeeded() {
    if (widget.receiptPrinterOpenRequest <= _handledReceiptPrinterOpenRequest) {
      return;
    }
    _handledReceiptPrinterOpenRequest = widget.receiptPrinterOpenRequest;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_openReceiptPrinter());
    });
  }

  @override
  void dispose() {
    _autoSaveDebounce?.cancel();
    _restaurantController.dispose();
    _cloudUrlController.dispose();
    _restaurantIdController.dispose();
    _outletIdController.dispose();
    _syncIntervalController.dispose();
    _settingsSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final query = _settingsSearchController.text.trim().toLowerCase();
    // Lean terminal settings — manager-only device, no owner sections.
    final groups = [
      _SettingsGroupData(
        label: text.deviceGroup,
        items: [
          _SettingActionData(
            title: text.settingsConnectPrinter,
            subtitle: text.receiptPrinterSubtitle,
            icon: Icons.print_outlined,
            trailing: app.printerState.connected
                ? text.connected
                : text.connect,
            onTap: _openReceiptPrinter,
          ),
          _SettingActionData(
            title: text.liveDiagnostics,
            subtitle: text.liveDiagnosticsSubtitle,
            icon: Icons.monitor_heart_outlined,
            onTap: _openLiveDiagnostics,
          ),
          _SettingActionData(
            title: text.languageLabel,
            subtitle: text.languageSubtitle,
            icon: Icons.translate_rounded,
            trailing: app.language.label,
            onTap: _openLanguageSettings,
          ),
          _SettingActionData(
            title: text.displaySize,
            subtitle: app.uiScaleLabel,
            icon: Icons.tune_rounded,
            onTap: _openDisplaySettings,
          ),
        ],
      ),
      _SettingsGroupData(
        label: text.isBn ? 'সংযোগ' : 'Connection',
        items: [
          _SettingActionData(
            title: text.isBn ? 'সার্ভার ও মেনু URL' : 'Server & Menu URLs',
            subtitle: text.isBn
                ? 'সার্ভার URL ও আউটলেট আইডি'
                : 'Server URL and outlet ID',
            icon: Icons.link_rounded,
            onTap: _openConnectionUrls,
          ),
        ],
      ),
      _SettingsGroupData(
        label: text.accountGroup,
        items: [
          _SettingActionData(
            title: text.aboutUs,
            subtitle: text.isBn
                ? 'Terafoods কী করে এবং কার জন্য তৈরি'
                : 'What Terafoods does and who it is for',
            icon: Icons.info_outline_rounded,
            onTap: _openAboutUs,
          ),
          _SettingActionData(
            title: text.privacyPolicy,
            subtitle: text.isBn
                ? 'Terafoods কীভাবে রেস্টুরেন্টের ডাটা পরিচালনা করে'
                : 'How Terafoods handles restaurant data',
            icon: Icons.privacy_tip_outlined,
            onTap: _openPrivacyPolicy,
          ),
          _SettingActionData(
            title: text.settingsLogOut,
            subtitle: text.logOutSubtitle,
            icon: Icons.logout_rounded,
            onTap: _confirmLogout,
            danger: true,
          ),
        ],
      ),
    ];
    final visibleGroups = groups
        .map((group) => group.filtered(query))
        .where((group) => group.items.isNotEmpty)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12, 14, 12, 18),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TfGlobalTopBar(
                      title: text.settings,
                      subtitle: text.isBn
                          ? 'সেটিংস · v2.2.1'
                          : 'Settings · v2.2.1',
                      onNavigateToOrders: widget.onNavigateToOrders,
                      onNavigateToTarget: widget.onNavigateToTarget,
                    ),
                    SizedBox(height: 14),
                    TfSearchField(
                      controller: _settingsSearchController,
                      hintText: text.searchSettingsHint,
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: 12),
                    if (visibleGroups.isEmpty)
                      TfEmptyState(
                        icon: Icons.search_off_rounded,
                        title: text.noSettingsFound,
                        message: text.tryDifferentSearch,
                      )
                    else
                      for (var i = 0; i < visibleGroups.length; i++) ...[
                        TfSectionHeader(label: visibleGroups[i].label),
                        SizedBox(height: 7),
                        _SettingsGroupCard(items: visibleGroups[i].items),
                        if (i < visibleGroups.length - 1) SizedBox(height: 14),
                      ],
                    if (_showDeferredSettings &&
                        app.demoManagerLoginEnabled) ...[
                      SizedBox(height: 14),
                      TfSectionHeader(label: 'Diagnostics'),
                      SizedBox(height: 7),
                      _DiagnosticsCard(app: app),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDisplaySettings() async {
    final app = AppScope.of(context);
    final text = app.strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.displaySize,
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DisplaySizeCard(
                    value: _displayScale,
                    label: AppScope.of(ctx).uiScaleLabel,
                    text: text,
                    onChanged: (value) {
                      setState(() => _displayScale = value);
                      setLocal(() {});
                    },
                    onChangeEnd: _updateDisplayScale,
                    onPreset: (value) {
                      setState(() => _displayScale = value);
                      setLocal(() {});
                      _updateDisplayScale(value);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openLanguageSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _LanguageSettingsPage()),
    );
  }

  Future<void> _openReceiptPrinter() async {
    final app = AppScope.of(context);
    final text = app.strings;
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings open receipt printer page '
        'state transport=${app.printerState.activeTransport.name} '
        'connected=${app.printerState.connected} '
        'busy=${app.printerState.busy} '
        'usb=${app.printerState.usbPrinterAvailable} '
        'btSelected=${app.printerState.selectedPrinterAddress?.isNotEmpty == true} '
        'systemQueue="${app.printerState.selectedWindowsQueueName ?? ''}"',
      );
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.receiptPrinter,
          child: _PrinterSettingsCard(
            onUsbConnect: _connectUsbPrinter,
            onRefresh: _refreshPrinters,
            onConnect: _connectPrinter,
            onTestPrint: _testPrinter,
          ),
        ),
      ),
    );
  }

  Future<void> _openLiveDiagnostics() async {
    final app = AppScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: app.strings.liveDiagnostics,
          child: _LiveDiagnosticsCard(app: app),
        ),
      ),
    );
  }

  Future<void> _openConnectionUrls() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ConnectionUrlsPage(
          urlController: _cloudUrlController,
          outletIdController: _outletIdController,
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final text = AppScope.of(context).strings;
    TfConfirmSheet.show(
      context,
      title: text.logOut,
      description: text.logOutSubtitle,
      confirmLabel: text.logOut,
      onConfirm: () async {
        if (!mounted) return;
        await AppScope.of(context).logOut();
      },
    );
  }

  Future<void> _openAboutUs() async {
    final text = AppScope.of(context).strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.aboutUs,
          child: const _AboutUsPage(),
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy() async {
    final text = AppScope.of(context).strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.privacyPolicy,
          child: const _PrivacyPolicyPage(),
        ),
      ),
    );
  }

  void _scheduleAutoSave() {
    if (!_hydrated) return;
    _autoSaveDebounce?.cancel();
    _autoSaveDebounce = Timer(Duration(milliseconds: 450), _saveSilently);
  }

  Future<void> _saveSilently() async {
    if (!mounted) return;
    if (!_isValidAutoSavePayload()) return;
    final app = AppScope.of(context);
    await app.saveSettings(
      restaurantName: _restaurantController.text,
      cloudApiUrl: _cloudUrlController.text,
      restaurantId: _restaurantIdController.text,
      outletId: _outletIdController.text,
      cloudSyncEnabled: _cloudSyncEnabled,
      autoSyncIntervalSeconds: int.parse(_syncIntervalController.text),
    );
  }

  bool _isValidAutoSavePayload() {
    if (_restaurantController.text.trim().isEmpty) return false;
    final seconds = int.tryParse(_syncIntervalController.text.trim());
    if (seconds == null || seconds < 10) return false;
    return true;
  }

  Future<void> _updateDisplayScale(double value) async {
    final app = AppScope.of(context);
    await app.updateUiScale(value);
  }

  Future<void> _refreshPrinters() async {
    final app = AppScope.of(context);
    final text = app.strings;
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings tap Bluetooth refresh '
        'supportsDirect=${app.supportsDirectBluetoothPrinting} '
        'busy=${app.printerState.busy}',
      );
    }
    if (!app.supportsDirectBluetoothPrinting) {
      await _connectBluetoothSystemPrinter();
      return;
    }
    final printers = await app.refreshPairedPrinters();
    if (!mounted) return;
    final error = app.printerState.lastError;
    final message =
        error ??
        (printers.isEmpty
            ? text.noPairedPrintersFound
            : text.pairedPrinterFound(printers.length));
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings Bluetooth refresh result '
        'printers=${printers.length} lastError="$error" snackbar="$message"',
      );
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connectBluetoothSystemPrinter() async {
    final app = AppScope.of(context);
    final text = app.strings;
    final queues = await app.listSystemPrinterQueues();
    if (!mounted) return;
    if (queues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(
            text.isBn
                ? 'Bluetooth প্রিন্টার OS/CUPS-এ pair/install করুন, তারপর আবার চেষ্টা করুন।'
                : 'Pair/install the Bluetooth printer in the OS first, then try again.',
          ),
        ),
      );
      return;
    }
    final choice = await showDialog<(String, int)>(
      context: context,
      builder: (_) => _SystemPrinterQueueDialog(
        printers: queues,
        selectedPrinter: app.printerState.selectedWindowsQueueName,
        initialWidth: app.printerState.windowsPaperWidthMm,
        title: text.isBn ? 'Bluetooth প্রিন্টার' : 'Bluetooth printer',
      ),
    );
    if (choice == null) return;
    await app.selectSystemPrinterQueue(choice.$1, paperWidthMm: choice.$2);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: TfText(text.connectedTo(choice.$1))));
  }

  Future<void> _connectUsbPrinter() async {
    final app = AppScope.of(context);
    final text = app.strings;
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings tap USB connect '
        'busy=${app.printerState.busy} '
        'systemQueue="${app.printerState.selectedWindowsQueueName ?? ''}"',
      );
    }
    try {
      final queues = await app.listSystemPrinterQueues();
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] settings USB system queues=${queues.length}',
        );
      }
      if (!mounted) return;

      if (queues.isNotEmpty) {
        final choice = queues.length == 1
            ? (queues.first, app.printerState.windowsPaperWidthMm)
            : await showDialog<(String, int)>(
                context: context,
                builder: (_) => _SystemPrinterQueueDialog(
                  printers: queues,
                  selectedPrinter: app.printerState.selectedWindowsQueueName,
                  initialWidth: app.printerState.windowsPaperWidthMm,
                  title: text.isBn ? 'USB প্রিন্টার' : 'USB printer',
                ),
              );
        if (choice == null) return;
        await app.selectSystemPrinterQueue(choice.$1, paperWidthMm: choice.$2);
        if (!mounted) return;
        if (kDebugMode) {
          debugPrint(
            '[QB-PRINTER-DIAG] settings USB selected system queue '
            'queue="${choice.$1}" width=${choice.$2}',
          );
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: TfText(text.connectedTo(choice.$1))));
        return;
      }

      final ok = await app.connectLocalUsbPrinterAuto();
      if (!mounted) return;
      final message = ok
          ? text.connectedTo(app.printerState.selectedPrinterLabel)
          : app.printerState.lastError ?? text.printerConnectionFailed;
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] settings USB auto result ok=$ok '
          'lastError="${app.printerState.lastError ?? ''}" '
          'snackbar="$message"',
        );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(message)));
    } catch (error) {
      if (!mounted) return;
      final message = _printerErrorMessage(error, text);
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] settings USB exception error="$error" '
          'snackbar="$message"',
        );
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(message)));
    }
  }

  Future<void> _connectPrinter(BluetoothPrinterDevice printer) async {
    final app = AppScope.of(context);
    final text = app.strings;
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings _connectPrinter name="${printer.name}" '
        'address=${printer.address}',
      );
    }
    final ok = await app.connectPrinter(printer);
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings _connectPrinter ok=$ok '
        'lastError=${app.printerState.lastError}',
      );
    }
    if (!mounted) return;
    final message = ok
        ? text.connectedTo(printer.label)
        : app.printerState.lastError ?? text.printerConnectionFailed;
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings Bluetooth connect snackbar="$message"',
      );
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: TfText(message)));
  }

  Future<void> _testPrinter() async {
    final app = AppScope.of(context);
    final text = app.strings;
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings tap test print '
        'transport=${app.printerState.activeTransport.name} '
        'connected=${app.printerState.connected} '
        'hasSelected=${app.printerState.hasSelectedPrinter}',
      );
    }
    final ok = await app.testPrinter();
    if (!mounted) return;
    final message = ok
        ? text.testTicketSent
        : app.printerState.lastError ?? text.testFailed;
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings test print result ok=$ok '
        'lastError="${app.printerState.lastError ?? ''}" '
        'snackbar="$message"',
      );
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: TfText(message)));
  }

  String _printerErrorMessage(Object error, AppStrings text) {
    final message = error is PrinterException ? error.message : '$error';
    if (message.contains('Choose a USB/system printer')) {
      return text.isBn
          ? 'লিস্ট থেকে USB/system প্রিন্টার সিলেক্ট করুন।'
          : 'Choose a USB/system printer from the list.';
    }
    if (message.contains('No USB printer found')) {
      return text.isBn
          ? 'USB প্রিন্টার পাওয়া যায়নি। USB লাগান অথবা Bluetooth ব্যবহার করুন।'
          : 'No USB printer found. Plug in USB or use Bluetooth.';
    }
    return message;
  }
}

Widget _settingsCard({
  required Widget child,
  Clip clipBehavior = Clip.none,
  EdgeInsetsGeometry? margin,
}) {
  return Padding(
    padding: margin ?? EdgeInsets.zero,
    child: TfCard(
      color: PosColors.surface,
      padded: false,
      clip: clipBehavior != Clip.none,
      child: child,
    ),
  );
}

class _SettingsGroupData {
  const _SettingsGroupData({required this.label, required this.items});

  final String label;
  final List<_SettingActionData> items;

  _SettingsGroupData filtered(String query) {
    if (query.isEmpty) return this;
    return _SettingsGroupData(
      label: label,
      items: items
          .where(
            (item) =>
                item.title.toLowerCase().contains(query) ||
                item.subtitle.toLowerCase().contains(query) ||
                (item.trailing ?? '').toLowerCase().contains(query),
          )
          .toList(growable: false),
    );
  }
}

class _SettingActionData {
  const _SettingActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? trailing;
  final VoidCallback? onTap;
  final bool danger;
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.items});

  final List<_SettingActionData> items;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _SettingsActionTile(item: items[i]),
            if (i < items.length - 1)
              Divider(height: 1, color: PosColors.lineStrong),
          ],
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({required this.item});

  final _SettingActionData item;

  @override
  Widget build(BuildContext context) {
    final iconColor = item.danger ? PosColors.danger : PosColors.muted;
    final content = Padding(
      padding: EdgeInsets.all(PosSpacing.sp3),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: PosColors.surfaceSunk,
              borderRadius: BorderRadius.circular(PosRadii.sm),
            ),
            child: Icon(item.icon, color: iconColor, size: 16),
          ),
          SizedBox(width: PosSpacing.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: item.danger ? PosColors.danger : PosColors.slate,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: PosSpacing.sp1),
                TfText(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: PosSpacing.sp2),
          ...[
            if (item.trailing != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 104),
                child: TfText(
                  item.trailing!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: PosColors.muted, size: 18),
          ],
        ],
      ),
    );

    if (item.onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: item.onTap, child: content),
    );
  }
}

class _SettingsSectionPage extends StatelessWidget {
  const _SettingsSectionPage({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      showDatePill: false,
      showBackButton: true,
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return _settingsCard(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: PosColors.background,
                    borderRadius: BorderRadius.circular(PosRadii.md),
                    border: Border.all(color: PosColors.lineStrong),
                  ),
                  child: Icon(icon, color: PosColors.slate, size: 19),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TfText(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 3),
                        TfText(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DisplaySizeCard extends StatelessWidget {
  const _DisplaySizeCard({
    required this.value,
    required this.label,
    required this.text,
    required this.onChanged,
    required this.onChangeEnd,
    required this.onPreset,
  });

  final double value;
  final String label;
  final AppStrings text;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final ValueChanged<double> onPreset;

  @override
  Widget build(BuildContext context) {
    final percent = (value * 100).round();
    return _settingsCard(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: PosColors.background,
                    borderRadius: BorderRadius.circular(PosRadii.md),
                    border: Border.all(color: PosColors.lineStrong),
                  ),
                  child: Icon(
                    Icons.fit_screen_rounded,
                    color: PosColors.slate,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TfText(
                        text.displaySize,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      SizedBox(height: 3),
                      TfText(
                        text.displaySizeSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                _ScalePill(label: label, percent: percent),
              ],
            ),
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PresetChip(
                  label: text.compact,
                  selected: value <= 0.88,
                  onTap: () => onPreset(0.84),
                ),
                _PresetChip(
                  label: text.comfortable,
                  selected: value > 0.88 && value < 0.98,
                  onTap: () => onPreset(0.92),
                ),
                _PresetChip(
                  label: text.large,
                  selected: value >= 0.98,
                  onTap: () => onPreset(1.02),
                ),
              ],
            ),
            SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.remove_rounded, color: PosColors.muted, size: 18),
                Expanded(
                  child: Slider(
                    value: value.clamp(
                      PosAppController.minUiScale,
                      PosAppController.maxUiScale,
                    ),
                    min: PosAppController.minUiScale,
                    max: PosAppController.maxUiScale,
                    divisions: 16,
                    label: '$percent%',
                    onChanged: onChanged,
                    onChangeEnd: onChangeEnd,
                  ),
                ),
                Icon(Icons.add_rounded, color: PosColors.muted, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.selected,
    required this.text,
    required this.onChanged,
  });

  final AppLanguage selected;
  final AppStrings text;
  final ValueChanged<AppLanguage> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: text.languageLabel,
      subtitle: text.languageSubtitle,
      icon: Icons.translate_rounded,
      children: [
        SegmentedButton<AppLanguage>(
          segments: [
            ButtonSegment<AppLanguage>(
              value: AppLanguage.bn,
              label: Text(text.bangla),
              icon: TfText('অ'),
            ),
            ButtonSegment<AppLanguage>(
              value: AppLanguage.en,
              label: Text(text.english),
              icon: TfText('A'),
            ),
          ],
          selected: {selected},
          showSelectedIcon: true,
          onSelectionChanged: (values) => onChanged(values.first),
        ),
      ],
    );
  }
}

class _LanguageSettingsPage extends StatelessWidget {
  const _LanguageSettingsPage();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return _SettingsSectionPage(
      title: text.languageLabel,
      child: _LanguageCard(
        selected: app.language,
        text: text,
        onChanged: app.updateLanguage,
      ),
    );
  }
}

class _ScalePill extends StatelessWidget {
  const _ScalePill({required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.lineStrong),
      ),
      child: TfText(
        '$label - $percent%',
        style: TextStyle(
          color: PosColors.slate,
          fontWeight: FontWeight.w500,
          fontSize: 11.4,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TfChip(
      label: label,
      active: selected,
      leading: selected ? const Icon(Icons.check_rounded) : null,
      onTap: onTap,
    );
  }
}

class _PrinterSettingsCard extends StatelessWidget {
  const _PrinterSettingsCard({
    required this.onUsbConnect,
    required this.onRefresh,
    required this.onConnect,
    required this.onTestPrint,
  });

  final Future<void> Function() onUsbConnect;
  final Future<void> Function() onRefresh;
  final Future<void> Function(BluetoothPrinterDevice printer) onConnect;
  final Future<void> Function() onTestPrint;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final state = app.printerState;
    final devices = app.pairedPrinters;
    final usbSelected =
        state.activeTransport == PrinterTransport.usb ||
        state.activeTransport == PrinterTransport.windowsUsb ||
        state.usbPrinterAvailable ||
        (state.selectedWindowsQueueName?.trim().isNotEmpty ?? false);
    final bluetoothSelected =
        state.activeTransport == PrinterTransport.bluetooth ||
        (state.selectedPrinterAddress?.trim().isNotEmpty ?? false);
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings printer page build '
        'usbSelected=$usbSelected bluetoothSelected=$bluetoothSelected '
        'busy=${state.busy} devices=${devices.length} '
        'testVisible=${state.hasSelectedPrinter} '
        'transport=${state.activeTransport.name} '
        'usbAvailable=${state.usbPrinterAvailable} '
        'builtInHidden=${state.builtInPrinterAvailable}',
      );
    }

    return _SectionCard(
      title: text.receiptPrinter,
      subtitle: text.pairPrinterInstruction,
      icon: Icons.print_outlined,
      children: [
        _PrinterStatusPanel(state: state, text: text),
        const SizedBox(height: 12),
        _PrinterConnectionOption(
          title: text.isBn ? 'USB প্রিন্টার' : 'USB printer',
          subtitle: text.isBn
              ? 'USB কেবল লাগান। অ্যাপ নিজে প্রিন্টার খুঁজে নেবে।'
              : 'Plug in USB. The app will detect the printer automatically.',
          icon: Icons.usb_rounded,
          selected: usbSelected,
          busy: state.busy,
          buttonLabel: usbSelected ? text.reconnect : text.connect,
          onPressed: state.busy ? null : onUsbConnect,
        ),
        const SizedBox(height: 10),
        _PrinterConnectionOption(
          title: text.isBn ? 'Bluetooth প্রিন্টার' : 'Bluetooth printer',
          subtitle: text.isBn
              ? 'USB না থাকলে Bluetooth ডিভাইস স্ক্যান করে কানেক্ট করুন।'
              : 'If USB is not available, scan and connect a Bluetooth device.',
          icon: Icons.bluetooth_rounded,
          selected: bluetoothSelected,
          busy: state.busy,
          buttonLabel: text.refreshPairedPrinters,
          onPressed: state.busy ? null : onRefresh,
        ),
        if (devices.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...devices.map(
            (printer) => _PrinterDeviceTile(
              printer: printer,
              selected: printer.address == state.selectedPrinterAddress,
              busy: state.busy,
              text: text,
              onConnect: () => onConnect(printer),
            ),
          ),
        ],
        if (state.lastError?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 10),
          _PrinterHint(
            icon: Icons.error_outline_rounded,
            message: state.lastError!,
            color: PosColors.danger,
          ),
        ],
        if (state.hasSelectedPrinter) ...[
          const SizedBox(height: 12),
          TfButton(
            label: text.testPrint,
            icon: Icons.receipt_long_outlined,
            variant: TfButtonVariant.dark,
            busy: state.busy,
            onPressed: state.busy ? null : onTestPrint,
          ),
        ],
      ],
    );
  }
}

class _PrinterStatusPanel extends StatelessWidget {
  const _PrinterStatusPanel({required this.state, required this.text});

  final PrinterRuntimeState state;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final ready = state.connected;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ready
            ? PosColors.success.withValues(alpha: 0.08)
            : PosColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready
              ? PosColors.success.withValues(alpha: 0.26)
              : PosColors.lineStrong,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ready ? Icons.check_circle_rounded : Icons.print_disabled_outlined,
            color: ready ? PosColors.success : PosColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  ready ? text.printerConnectedAuto : text.noPrinterSelected,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                TfText(
                  state.selectedPrinterLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: PosColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinterConnectionOption extends StatelessWidget {
  const _PrinterConnectionOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.busy,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool busy;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? PosColors.primary.withValues(alpha: 0.28)
              : PosColors.lineStrong.withValues(alpha: 0.48),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: selected
                  ? PosColors.primary.withValues(alpha: 0.10)
                  : PosColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PosColors.line),
            ),
            child: Icon(
              selected ? Icons.check_circle_rounded : icon,
              color: selected ? PosColors.primary : PosColors.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                TfText(
                  subtitle,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: PosColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TfButton(
            label: buttonLabel,
            size: TfButtonSize.sm,
            fullWidth: false,
            busy: busy,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _PrinterHint extends StatelessWidget {
  const _PrinterHint({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TfText(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: PosColors.slate),
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemPrinterQueueDialog extends StatefulWidget {
  const _SystemPrinterQueueDialog({
    required this.printers,
    required this.initialWidth,
    required this.title,
    this.selectedPrinter,
  });

  final List<String> printers;
  final String? selectedPrinter;
  final int initialWidth;
  final String title;

  @override
  State<_SystemPrinterQueueDialog> createState() =>
      _SystemPrinterQueueDialogState();
}

class _SystemPrinterQueueDialogState extends State<_SystemPrinterQueueDialog> {
  late String _printer;
  late int _width;

  @override
  void initState() {
    super.initState();
    _printer = _initialPrinter();
    _width = widget.initialWidth == 80 ? 80 : 58;
  }

  String _initialPrinter() {
    final selected = widget.selectedPrinter?.trim();
    if (selected != null &&
        selected.isNotEmpty &&
        widget.printers.contains(selected)) {
      return selected;
    }
    return widget.printers.first;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return AlertDialog(
      title: TfText(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _printer,
            decoration: InputDecoration(
              labelText: text.isBn ? 'প্রিন্টার' : 'Printer',
            ),
            items: [
              for (final printer in widget.printers)
                DropdownMenuItem(value: printer, child: Text(printer)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _printer = value);
            },
          ),
          const SizedBox(height: 14),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 58, label: Text('58 mm')),
              ButtonSegment(value: 80, label: Text('80 mm')),
            ],
            selected: {_width},
            onSelectionChanged: (value) => setState(() => _width = value.first),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: TfText(text.close),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_printer, _width)),
          child: TfText(text.connect),
        ),
      ],
    );
  }
}

class _LiveDiagnosticsCard extends StatefulWidget {
  const _LiveDiagnosticsCard({required this.app});

  final PosAppController app;

  @override
  State<_LiveDiagnosticsCard> createState() => _LiveDiagnosticsCardState();
}

class _LiveDiagnosticsCardState extends State<_LiveDiagnosticsCard> {
  late Future<Map<String, Object?>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.app.loadLiveDiagnostics();
  }

  void _refresh() {
    setState(() => _future = widget.app.loadLiveDiagnostics());
  }

  Map<String, Object?> _map(Object? value) {
    return value is Map ? Map<String, Object?>.from(value) : const {};
  }

  String _label(String en, String bn) {
    return widget.app.strings.isBn ? bn : en;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.app.strings;
    return FutureBuilder<Map<String, Object?>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _SectionCard(
            title: text.liveDiagnostics,
            subtitle: snapshot.error.toString(),
            icon: Icons.cloud_off_outlined,
            children: [
              TfButton(
                label: text.refresh,
                icon: Icons.refresh_rounded,
                onPressed: _refresh,
              ),
            ],
          );
        }
        final envelope = _map(snapshot.data);
        final data = _map(envelope['data']);
        final diagnostics = _map(data['diagnostics']);
        final database = _map(diagnostics['database']);
        final storage = _map(diagnostics['storage']);
        final sms = _map(diagnostics['sms']);
        final facebook = _map(diagnostics['facebook']);
        final chatbot = _map(diagnostics['chatbotAi']);
        final realtime = _map(diagnostics['realtime']);
        final sync = widget.app.syncState;
        return _SectionCard(
          title: text.liveDiagnostics,
          subtitle: text.liveDiagnosticsSubtitle,
          icon: Icons.monitor_heart_outlined,
          children: [
            _DiagnosticStatusRow(
              label: _label('Cloud API', 'ক্লাউড API'),
              ok: data['status'] == 'ok',
            ),
            _DiagnosticStatusRow(
              label: _label('Database', 'ডাটাবেজ'),
              ok: database['ok'] == true,
            ),
            _DiagnosticStatusRow(
              label: _label('Writable media storage', 'মিডিয়া স্টোরেজ'),
              ok: storage['ok'] == true,
            ),
            _DiagnosticStatusRow(
              label: _label('SMS provider', 'SMS প্রোভাইডার'),
              ok: sms['ok'] == true,
            ),
            _DiagnosticStatusRow(
              label: _label('Facebook OAuth', 'Facebook OAuth'),
              ok: facebook['oauthReady'] == true,
            ),
            _DiagnosticStatusRow(
              label: _label(
                'Facebook Android app redirect',
                'Facebook Android অ্যাপ রিডাইরেক্ট',
              ),
              ok: facebook['nativeAndroidReady'] == true,
            ),
            _DiagnosticStatusRow(
              label: _label('Facebook webhook', 'Facebook webhook'),
              ok: facebook['webhookReady'] == true,
            ),
            _DiagnosticStatusRow(
              label: _label('Chatbot AI provider', 'Chatbot AI প্রোভাইডার'),
              ok: chatbot['ok'] == true,
            ),
            _DiagnosticStatusRow(
              label: _label('Realtime updates', 'তাৎক্ষণিক আপডেট'),
              ok: realtime['enabled'] == true,
            ),
            _DiagnosticStatusRow(
              label: _label('Local printer', 'লোকাল প্রিন্টার'),
              ok: widget.app.printerState.connected,
            ),
            _DiagnosticStatusRow(
              label: _label('Local sync queue', 'লোকাল সিঙ্ক তালিকা'),
              ok: sync.failedCount == 0,
              detail: _label(
                '${sync.pendingCount} অপেক্ষমান, ${sync.failedCount} ব্যর্থ',
                '${sync.pendingCount} pending, ${sync.failedCount} failed',
              ),
            ),
            const SizedBox(height: 12),
            TfButton(
              label: text.refresh,
              icon: Icons.refresh_rounded,
              onPressed: _refresh,
            ),
          ],
        );
      },
    );
  }
}

class _DiagnosticStatusRow extends StatelessWidget {
  const _DiagnosticStatusRow({
    required this.label,
    required this.ok,
    this.detail,
  });

  final String label;
  final bool ok;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: ok ? PosColors.success : PosColors.danger,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: TfText(label)),
          if (detail != null)
            TfText(
              detail!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: PosColors.muted),
            ),
        ],
      ),
    );
  }
}

class _PrinterDeviceTile extends StatelessWidget {
  const _PrinterDeviceTile({
    required this.printer,
    required this.selected,
    required this.busy,
    required this.text,
    required this.onConnect,
  });

  final BluetoothPrinterDevice printer;
  final bool selected;
  final bool busy;
  final AppStrings text;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected
              ? PosColors.primary.withValues(alpha: 0.24)
              : PosColors.lineStrong.withValues(alpha: 0.48),
        ),
      ),
      child: Row(
        children: [
          Icon(
            selected ? Icons.check_circle_rounded : Icons.bluetooth_rounded,
            color: selected ? PosColors.primary : PosColors.muted,
          ),
          SizedBox(width: 10),
          Expanded(
            child: TfText(
              printer.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TfButton(
            label: selected ? text.reconnect : text.connect,
            size: TfButtonSize.sm,
            fullWidth: false,
            onPressed: busy ? null : onConnect,
          ),
        ],
      ),
    );
  }
}

// ─── Hero Media Page ──────────────────────────────────────────────────────────

class _ConnectionUrlsPage extends StatefulWidget {
  const _ConnectionUrlsPage({
    required this.urlController,
    required this.outletIdController,
  });

  final TextEditingController urlController;
  final TextEditingController outletIdController;

  @override
  State<_ConnectionUrlsPage> createState() => _ConnectionUrlsPageState();
}

class _ConnectionUrlsPageState extends State<_ConnectionUrlsPage> {
  @override
  void initState() {
    super.initState();
    widget.urlController.addListener(_rebuild);
    widget.outletIdController.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.urlController.removeListener(_rebuild);
    widget.outletIdController.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  String get _menuUrl {
    final app = AppScope.of(context);
    final slug = app.serverConfig.publicSlug.trim().toLowerCase();
    if (slug.isNotEmpty &&
        RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$').hasMatch(slug)) {
      return 'https://$slug.quickbytes.buzz';
    }
    final base = widget.urlController.text.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final outlet = widget.outletIdController.text.trim();
    if (base.isEmpty || outlet.isEmpty) return '';
    return '$base/menu/$outlet';
  }

  @override
  Widget build(BuildContext context) {
    final menuUrl = _menuUrl;
    return _SettingsSectionPage(
      title: 'Server & Menu URLs',
      child: _SectionCard(
        title: 'Connection Settings',
        subtitle: 'Tunnel URL, outlet ID, and customer menu link',
        icon: Icons.link_rounded,
        children: [
          TfText('Server URL', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: 6),
          TextField(
            controller: widget.urlController,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'https://your-tunnel.trycloudflare.com',
              prefixIcon: Icon(Icons.dns_rounded),
            ),
          ),
          SizedBox(height: 16),
          TfText('Outlet ID', style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: 6),
          TextField(
            controller: widget.outletIdController,
            autocorrect: false,
            decoration: InputDecoration(
              hintText: 'outlet UUID',
              prefixIcon: Icon(Icons.pin_drop_outlined),
              helperText:
                  'Auto-generated. Only change if re-registering the outlet.',
            ),
          ),
          SizedBox(height: 20),
          TfText(
            'Customer Menu URL',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: menuUrl.isEmpty
                  ? PosColors.background
                  : PosColors.primarySoft,
              borderRadius: BorderRadius.circular(PosRadii.md),
              border: Border.all(
                color: menuUrl.isEmpty
                    ? PosColors.lineStrong.withValues(alpha: 0.48)
                    : PosColors.primary.withValues(alpha: 0.50),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TfText(
                    menuUrl.isEmpty
                        ? 'Set server URL and outlet ID above'
                        : menuUrl,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: menuUrl.isEmpty
                          ? PosColors.muted
                          : PosColors.primaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (menuUrl.isNotEmpty) ...[
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copy URL',
                    style: IconButton.styleFrom(
                      foregroundColor: PosColors.primaryDark,
                      backgroundColor: PosColors.primary.withValues(
                        alpha: 0.20,
                      ),
                      minimumSize: Size(36, 36),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: menuUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: TfText('Menu URL copied')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 10),
          TfText(
            'Share this link with customers to let them view your menu.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: PosColors.muted),
          ),
        ],
      ),
    );
  }
}

// ─── Table Settings Page ──────────────────────────────────────────────────────

class _AboutUsPage extends StatelessWidget {
  const _AboutUsPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── App identity ────────────────────────────────────────────────────
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: PosColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: PosColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Icon(
                          Icons.restaurant_rounded,
                          color: PosColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TfText(
                              'Terafoods',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            TfText(
                              'Restaurant POS for Bangladesh · v2.2.1',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: PosColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  TfText(
                    'Terafoods is a mobile-first point-of-sale app built for '
                    'mid-range and street-side restaurants in Bangladesh. Owners, '
                    'managers, and waiters use it on Android phones during real '
                    'rush hours, often with one hand, in bright light, and on budget '
                    'devices. The app keeps ordering, printing, inventory, online '
                    'orders, and daily reporting fast, obvious, and local.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Key features ────────────────────────────────────────────────────
          _infoSectionHeader(context, Icons.star_rounded, 'Key Features'),
          const SizedBox(height: 8),
          _settingsCard(
            child: Column(
              children: [
                _featureTile(
                  context,
                  icon: Icons.touch_app_outlined,
                  color: PosColors.warning,
                  title: 'Rush-ready ordering',
                  subtitle:
                      'Create dine-in or takeaway orders in a simple 3-step flow with large touch targets made for phones and crowded counters.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.groups_2_outlined,
                  color: PosColors.info,
                  title: 'Manager and waiter modes',
                  subtitle:
                      'Managers get full control over orders, reports, staff, menu, and settings. Waiters get a focused flow for taking and tracking orders.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.storefront_outlined,
                  color: PosColors.success,
                  title: 'Online storefront and orders',
                  subtitle:
                      'Publish a customer ordering page, accept online orders, and keep staff devices in sync with restaurant activity.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.print_outlined,
                  color: PosColors.accent,
                  title: 'Kitchen copy and receipt printing',
                  subtitle:
                      'Send kitchen tickets and customer receipts to supported Bluetooth or USB thermal printers without slowing the counter down.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.inventory_2_outlined,
                  color: PosColors.muted,
                  title: 'Inventory and stock counts',
                  subtitle:
                      'Track stock-in, start counts, low-stock items, mismatches, and daily inventory movement from the same app.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.auto_awesome_outlined,
                  color: PosColors.primary,
                  title: 'AI-assisted setup',
                  subtitle:
                      'Scan a physical menu card or inventory receipt to autofill menu items, prices, stock-in fields, and reporting notes for review.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.assessment_outlined,
                  color: PosColors.danger,
                  title: 'Daily earnings and top items',
                  subtitle:
                      'Owners can review daily and weekly sales, top-selling dishes, service mix, and export-friendly reports after the rush.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── How it works ────────────────────────────────────────────────────
          _infoSectionHeader(
            context,
            Icons.info_outline_rounded,
            'How It Works',
          ),
          const SizedBox(height: 8),
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stepRow(
                    context,
                    '1',
                    'Set up the outlet',
                    'A manager adds the restaurant profile, outlet identity, tables, staff roles, printer, and cloud connection.',
                  ),
                  const SizedBox(height: 12),
                  _stepRow(
                    context,
                    '2',
                    'Add or scan the menu',
                    'Create categories and dishes manually, or scan a physical menu card so Terafoods can suggest names, prices, and categories for approval.',
                  ),
                  const SizedBox(height: 12),
                  _stepRow(
                    context,
                    '3',
                    'Take orders fast',
                    'Managers and waiters create dine-in, takeaway, and online orders, then accept, prepare, print, and serve them from the order queue.',
                  ),
                  const SizedBox(height: 12),
                  _stepRow(
                    context,
                    '4',
                    'Close the day clearly',
                    'Staff update inventory counts and owners check earnings, top items, online order performance, and backup-ready reports.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Technology ──────────────────────────────────────────────────────
          _infoSectionHeader(context, Icons.code_rounded, 'Built With'),
          const SizedBox(height: 8),
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _techChip(context, 'Flutter'),
                  _techChip(context, 'Dart'),
                  _techChip(context, 'FastAPI'),
                  _techChip(context, 'SQLite (sqflite)'),
                  _techChip(context, 'Google Sign-In'),
                  _techChip(context, 'bKash Payment'),
                  _techChip(context, 'Bluetooth ESC/POS'),
                  _techChip(context, 'WebSocket'),
                  _techChip(context, 'AI Menu & Inventory Scan'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Company & contact ───────────────────────────────────────────────
          _infoSectionHeader(
            context,
            Icons.business_rounded,
            'Terafoods by Terabyte AI',
          ),
          const SizedBox(height: 8),
          _settingsCard(
            child: Column(
              children: [
                _contactTile(
                  context,
                  icon: Icons.apartment_rounded,
                  label: 'Product',
                  value: 'Terafoods',
                ),
                _divider(),
                _contactTile(
                  context,
                  icon: Icons.business_center_outlined,
                  label: 'Developer',
                  value: 'Terabyte AI',
                ),
                _divider(),
                _contactTile(
                  context,
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: 'Dhaka, Bangladesh',
                ),
                _divider(),
                _contactTile(
                  context,
                  icon: Icons.email_outlined,
                  label: 'Support Email',
                  value: 'support@terabyteai.com',
                ),
                _divider(),
                _contactTile(
                  context,
                  icon: Icons.language_outlined,
                  label: 'Website',
                  value: 'www.terabyteai.com',
                ),
                _divider(),
                _contactTile(
                  context,
                  icon: Icons.phone_outlined,
                  label: 'Phone / WhatsApp',
                  value: '+880 1XXX-XXXXXX',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Legal ───────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: TfText(
              '© 2024–2026 Terabyte AI. All rights reserved.\n'
              'Terafoods is a proprietary software product. '
              'Unauthorized copying, redistribution, or reverse-engineering is prohibited.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: PosColors.muted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _infoSectionHeader(BuildContext context, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: PosColors.muted),
          const SizedBox(width: 6),
          Expanded(
            child: TfSectionHeader(label: label, padding: EdgeInsets.zero),
          ),
        ],
      ),
    );
  }

  Widget _featureTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                TfText(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: PosColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepRow(
    BuildContext context,
    String step,
    String title,
    String body,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PosColors.primary,
            shape: BoxShape.circle,
          ),
          child: TfText(
            step,
            style: const TextStyle(
              color: PosColors.accentInk,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TfText(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 3),
              TfText(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: PosColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _techChip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: PosColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.primary.withValues(alpha: 0.25)),
      ),
      child: TfText(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: PosColors.primary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _contactTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: PosColors.muted),
      title: TfText(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: PosColors.muted),
      ),
      subtitle: TfText(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Policy page
// ─────────────────────────────────────────────────────────────────────────────

class _PrivacyPolicyPage extends StatelessWidget {
  const _PrivacyPolicyPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: PosColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.privacy_tip_rounded,
                          color: PosColors.success,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TfText(
                              'Privacy Policy',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            TfText(
                              'Last updated: May 25, 2026',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: PosColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  TfText(
                    'Terabyte AI ("we", "us", or "our") built Terafoods for '
                    'restaurant owners, managers, waiters, and staff in Bangladesh. '
                    'This Privacy Policy explains how Terafoods handles information '
                    'inside the manager app, waiter app, online storefront, AI scan '
                    'features, inventory tools, and cloud sync.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Data we collect ─────────────────────────────────────────────────
          _sectionHeader(context, '1. Information We Collect'),
          const SizedBox(height: 8),
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _policySubheading(context, 'Account Information'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'When you sign in, we may receive your name, phone number, email address, Google account profile details, role, and restaurant/outlet access. We use this to authenticate your identity and show the correct manager or waiter experience. We do not receive your Google password.',
                  ),
                  const SizedBox(height: 12),
                  _policySubheading(context, 'Restaurant & Operational Data'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'Terafoods stores the information needed to run the POS: menu items, categories, prices, photos, availability, tables, dine-in and takeaway orders, online orders, kitchen copy status, receipts, staff actions, inventory counts, stock-in records, mismatch reports, daily sales, top items, and report history.',
                  ),
                  const SizedBox(height: 12),
                  _policySubheading(context, 'Customer Order Details'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'For online, takeaway, or delivery orders, the app may store customer-provided details such as name, phone number, address, order notes, payment method, and order status. Only collect details your restaurant needs to prepare, deliver, and support the order.',
                  ),
                  const SizedBox(height: 12),
                  _policySubheading(context, 'AI Scan Images'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'If you use AI menu scanning or inventory scanning, images of menu cards, receipts, or stock documents are sent to the Terafoods backend for extraction. The result is shown for review before it changes your menu or inventory.',
                  ),
                  const SizedBox(height: 12),
                  _policySubheading(context, 'Device & App Data'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'The app may store device identifiers created by Terafoods, private device tokens, printer preferences, language, display size, theme, app version, sync status, and troubleshooting logs. This helps keep devices connected to the right restaurant and resolve support issues.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── How data is used ────────────────────────────────────────────────
          _sectionHeader(context, '2. How We Use Your Information'),
          const SizedBox(height: 8),
          _policyCard(context, [
            _policyPoint(
              context,
              Icons.check_circle_outline_rounded,
              PosColors.success,
              'To authenticate staff and connect each device to the correct restaurant, outlet, and role.',
            ),
            _policyPoint(
              context,
              Icons.check_circle_outline_rounded,
              PosColors.success,
              'To take orders, accept online orders, create kitchen copies, print receipts, update status, and keep service moving during rush hours.',
            ),
            _policyPoint(
              context,
              Icons.check_circle_outline_rounded,
              PosColors.success,
              'To sync menu, order, inventory, staff, and report data across manager and waiter devices and the online storefront.',
            ),
            _policyPoint(
              context,
              Icons.check_circle_outline_rounded,
              PosColors.success,
              'To process menu-card and inventory images so the app can suggest autofill results that your team can approve or edit.',
            ),
            _policyPoint(
              context,
              Icons.check_circle_outline_rounded,
              PosColors.success,
              'To generate daily and weekly reports, top-item summaries, inventory mismatch reports, and office backup data for restaurant owners.',
            ),
            _policyPoint(
              context,
              Icons.block_rounded,
              PosColors.danger,
              'We do NOT sell, rent, or share your data with third-party advertisers.',
            ),
            _policyPoint(
              context,
              Icons.block_rounded,
              PosColors.danger,
              'We do NOT use restaurant, staff, or customer order data for third-party advertising.',
            ),
          ]),
          const SizedBox(height: 12),

          // ── Data storage ────────────────────────────────────────────────────
          _sectionHeader(context, '3. Data Storage & Security'),
          const SizedBox(height: 8),
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _policySubheading(context, 'Local Storage'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'Operational data is stored in a local SQLite database on the device, with app preferences stored in Android SharedPreferences. This lets Terafoods keep core restaurant work available even when the internet is slow or unavailable.',
                  ),
                  const SizedBox(height: 12),
                  _policySubheading(context, 'Cloud Storage'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'When cloud sync, online ordering, storefront, or backup features are enabled, relevant data is transmitted over HTTPS to the Terafoods cloud backend. Each restaurant and outlet is separated by its tenant identity so staff devices only receive data they are authorized to access.',
                  ),
                  const SizedBox(height: 12),
                  _policySubheading(context, 'Tokens and Secrets'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'Backend secrets, API keys, and payment credentials are kept on the server side. The app stores only the private tokens required for the signed-in device to connect to its restaurant. These tokens are hidden from normal settings screens.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Third-party services ────────────────────────────────────────────
          _sectionHeader(context, '4. Third-Party Services'),
          const SizedBox(height: 8),
          _settingsCard(
            child: Column(
              children: [
                _thirdPartyTile(
                  context,
                  icon: Icons.account_circle_outlined,
                  name: 'Google Sign-In',
                  description:
                      'Used for manager or staff authentication when Google login is enabled. Google handles sign-in under its own privacy policy.',
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _thirdPartyTile(
                  context,
                  icon: Icons.payment_rounded,
                  name: 'bKash Payment Gateway',
                  description:
                      'Used for subscription checkout where available. Payment credentials are processed by bKash; Terafoods stores payment status and reference IDs needed for activation and support.',
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _thirdPartyTile(
                  context,
                  icon: Icons.cloud_outlined,
                  name: 'Terafoods Cloud Backend',
                  description:
                      'Used for sync, online storefronts, online orders, notifications, reports, backups, and device authorization.',
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _thirdPartyTile(
                  context,
                  icon: Icons.auto_awesome_outlined,
                  name: 'AI Scan Processing',
                  description:
                      'Used only when you scan menu cards, receipts, or stock documents. The scan output is returned as suggested menu or inventory fields for staff review.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── User rights ─────────────────────────────────────────────────────
          _sectionHeader(context, '5. Your Rights & Choices'),
          const SizedBox(height: 8),
          _policyCard(context, [
            _policyPoint(
              context,
              Icons.delete_outline_rounded,
              PosColors.info,
              'Local data: Managers can clear device cache or wipe restaurant data from Settings where those actions are available.',
            ),
            _policyPoint(
              context,
              Icons.logout_rounded,
              PosColors.warning,
              'Account or cloud deletion: Contact support@terabyteai.com to request deletion of your restaurant account, outlet data, staff accounts, or cloud backups.',
            ),
            _policyPoint(
              context,
              Icons.visibility_off_outlined,
              PosColors.muted,
              'Cloud sync choices: If your plan and setup allow offline-only use, you may keep work local. Online storefronts, multi-device sync, AI scanning, and backups require cloud services.',
            ),
            _policyPoint(
              context,
              Icons.download_outlined,
              PosColors.success,
              'Exports and reports: Sales and inventory reports can be reviewed or exported by authorized users for restaurant records.',
            ),
          ]),
          const SizedBox(height: 12),

          // ── Restaurant owner responsibility ─────────────────────────────────
          _sectionHeader(context, '6. Restaurant Owner Responsibility'),
          const SizedBox(height: 8),
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _policyBody(
                context,
                'Restaurant owners and operators control what customer details their staff collect through Terafoods and how long those details are needed for service, delivery, support, accounting, and reporting. '
                'You are responsible for giving customers appropriate notice, collecting only necessary information, and handling order data according to the rules that apply to your restaurant. '
                'Terafoods provides the POS platform and support tools for operating the restaurant workflow.',
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Children ────────────────────────────────────────────────────────
          _sectionHeader(context, '7. Children\'s Privacy'),
          const SizedBox(height: 8),
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _policyBody(
                context,
                'This application is intended for restaurant operators, managers, waiters, and staff who are authorized to work for the restaurant. It is not designed for children. If you believe a child has submitted personal information through the app or storefront, contact us so we can help review and remove it.',
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Changes ─────────────────────────────────────────────────────────
          _sectionHeader(context, '8. Changes to This Policy'),
          const SizedBox(height: 8),
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _policyBody(
                context,
                'We may update this Privacy Policy as Terafoods adds or changes features. When we do, the "Last updated" date at the top of this page will be revised. For significant changes, we will provide an in-app notice or support communication.',
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Contact ─────────────────────────────────────────────────────────
          _sectionHeader(context, '9. Contact Us'),
          const SizedBox(height: 8),
          _settingsCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _policyBody(
                    context,
                    'For privacy questions, support requests, account deletion, or restaurant data review, contact us:',
                  ),
                  const SizedBox(height: 12),
                  _contactRow(
                    context,
                    Icons.email_outlined,
                    'support@terabyteai.com',
                  ),
                  const SizedBox(height: 6),
                  _contactRow(
                    context,
                    Icons.language_outlined,
                    'www.terabyteai.com',
                  ),
                  const SizedBox(height: 6),
                  _contactRow(
                    context,
                    Icons.location_on_outlined,
                    'Terabyte AI, Dhaka, Bangladesh',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Footer ──────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TfText(
              'This Privacy Policy is effective as of May 25, 2026.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: PosColors.muted,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: TfText(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: PosColors.slate,
        ),
      ),
    );
  }

  Widget _policySubheading(BuildContext context, String text) {
    return TfText(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
        color: PosColors.slate,
      ),
    );
  }

  Widget _policyBody(BuildContext context, String text) {
    return TfText(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: PosColors.muted, height: 1.6),
    );
  }

  Widget _policyCard(BuildContext context, List<Widget> children) {
    return _settingsCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(children: children),
      ),
    );
  }

  Widget _policyPoint(
    BuildContext context,
    IconData icon,
    Color color,
    String text,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: TfText(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
                color: PosColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thirdPartyTile(
    BuildContext context, {
    required IconData icon,
    required String name,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: PosColors.slate),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                TfText(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: PosColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(BuildContext context, IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: PosColors.muted),
        const SizedBox(width: 8),
        TfText(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Hidden dev-only diagnostics card. Visible in the Settings list when
/// [PosAppController.demoManagerLoginEnabled] is true. Surfaces the counts
/// behind the RAM-optimization work (orders/menu/inventory/notification list
/// sizes, alert dedupe set size, active subscription count) plus the global
/// Flutter image cache size so memory hotspots can be spot-checked without
/// attaching Flutter DevTools.
class _DiagnosticsCard extends StatefulWidget {
  const _DiagnosticsCard({required this.app});
  final PosAppController app;

  @override
  State<_DiagnosticsCard> createState() => _DiagnosticsCardState();
}

class _DiagnosticsCardState extends State<_DiagnosticsCard> {
  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final imageCache = PaintingBinding.instance.imageCache;
    final cacheKb = (imageCache.currentSizeBytes / 1024).round();
    final cacheMaxKb = (imageCache.maximumSizeBytes / 1024).round();

    return TfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DiagRow(
            label: 'Orders in memory',
            value: '${app.diagOrdersInMemory}',
          ),
          _DiagRow(
            label: 'More orders to load',
            value: app.hasMoreOrders
                ? (app.loadingMoreOrders ? 'loading…' : 'yes')
                : 'no',
          ),
          _DiagRow(label: 'Menu items', value: '${app.diagMenuInMemory}'),
          _DiagRow(
            label: 'Inventory items',
            value: '${app.diagInventoryInMemory}',
          ),
          _DiagRow(
            label: 'Notifications',
            value: '${app.diagNotificationsInMemory}',
          ),
          _DiagRow(label: 'Alert dedupe set', value: '${app.diagAlertSetSize}'),
          _DiagRow(
            label: 'Active subscriptions',
            value: '${app.diagSubscriptionCount}',
          ),
          _DiagRow(
            label: 'Image cache',
            value:
                '$cacheKb / $cacheMaxKb kB · ${imageCache.liveImageCount} live',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TfButton(
                  label: 'Refresh',
                  variant: TfButtonVariant.paper,
                  size: TfButtonSize.sm,
                  onPressed: () => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TfButton(
                  label: 'Clear image cache',
                  variant: TfButtonVariant.paper,
                  size: TfButtonSize.sm,
                  onPressed: () {
                    imageCache.clear();
                    imageCache.clearLiveImages();
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DiagRow extends StatelessWidget {
  const _DiagRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: TfText(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: PosColors.slate,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TfText(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: PosColors.primaryDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
