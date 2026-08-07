import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/shell_nav_scope.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../core/widgets/subscription_gate_card.dart';
import '../../models/facebook_chatbot_config.dart';
import '../../models/pos_notification.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/menu_image_service.dart';
import '../../services/printer_service.dart';
import 'customer_menu_themes.dart';
import 'table_qr_labels_screen.dart';
import '../audit/audit_screen.dart';
import '../staff/staff_screen.dart';

const bool _showFacebookChatbotSettings = true;

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
  final TextEditingController _settingsSearchController =
      TextEditingController();
  bool _hydrated = false;
  int _handledReceiptPrinterOpenRequest = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    _hydrated = true;
    _openRequestedReceiptPrinterIfNeeded();
  }

  Future<void> _toggleSettleAndSave() async {
    final app = AppScope.of(context);
    await app.setSettleAndSaveEnabled(!app.settleAndSaveEnabled);
    setState(() {});
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
    _settingsSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final query = _settingsSearchController.text.trim().toLowerCase();
    // Staff users get a minimal settings list; managers get the full set.
    final groups = app.isManager
        ? [
            _SettingsGroupData(
              label: text.quickActions,
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
                if (_showFacebookChatbotSettings)
                  _SettingActionData(
                    title: text.facebookMessengerBot,
                    subtitle: text.facebookMessengerBotSubtitle,
                    icon: Icons.chat_bubble_outline_rounded,
                    trailing: _facebookBotTrailing(app, text),
                    onTap: _openFacebookChatbot,
                  ),
                _SettingActionData(
                  title: text.auditTrail,
                  subtitle: text.auditTrailSubtitle,
                  icon: Icons.fact_check_outlined,
                  onTap: _openAuditTrail,
                ),
                _SettingActionData(
                  title: text.staff,
                  subtitle: text.staffSubtitle,
                  icon: Icons.groups_outlined,
                  onTap: _openStaff,
                ),
                _SettingActionData(
                  title: 'Help & Guide',
                  subtitle: 'Replay the app walkthrough',
                  icon: Icons.tour_outlined,
                  onTap: () =>
                      ShellNavScope.maybeOf(context)?.startGuidedTour.call(),
                ),
              ],
            ),
            _SettingsGroupData(
              label: text.manageSection,
              items: [
                _SettingActionData(
                  title: text.myRestaurantDetailsGroup,
                  subtitle: text.restaurantDetailsSubtitle,
                  icon: Icons.storefront_outlined,
                  trailing: app.serverConfig.restaurantName.trim().isEmpty
                      ? text.setUpLabel
                      : app.serverConfig.restaurantName,
                  onTap: _openRestaurantDetails,
                ),
                _SettingActionData(
                  title: text.settingsSetTableNumbers,
                  subtitle: text.tablesSubtitle,
                  icon: Icons.table_restaurant_outlined,
                  trailing: text.tableCountLabel(app.serverConfig.tableCount),
                  onTap: _openTableSettings,
                ),
                _SettingActionData(
                  title: text.tableQrLabels,
                  subtitle: text.tableQrLabelsSubtitle,
                  icon: Icons.qr_code_rounded,
                  onTap: _openTableQrLabels,
                ),
                _SettingActionData(
                  title: text.autoKotPrint,
                  subtitle: text.autoKotPrintSubtitle,
                  icon: Icons.print_outlined,
                  action: Switch(
                    value: app.printerState.autoPrintEnabled,
                    onChanged: (v) => app.setAutoPrintOrders(v),
                    activeThumbColor: Colors.white,
                    inactiveThumbColor: Colors.white,
                  ),
                ),
                _SettingActionData(
                  title: text.bkashNagadPayments,
                  subtitle: text.bkashNagadPaymentsHint,
                  icon: Icons.payment_rounded,
                  trailing: app.settleAndSaveEnabled
                      ? (text.isBn ? 'চালু' : 'On')
                      : (text.isBn ? 'বন্ধ' : 'Off'),
                  onTap: _toggleSettleAndSave,
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
                  title: text.appLanguage,
                  subtitle: text.languageLabel,
                  icon: Icons.translate_rounded,
                  trailing: app.language == AppLanguage.bn
                      ? text.bangla
                      : text.english,
                  onTap: _toggleLanguage,
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
          ]
        : [
            // Staff: minimal settings only
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
                  title: 'Help & Guide',
                  subtitle: 'Replay the app walkthrough',
                  icon: Icons.tour_outlined,
                  onTap: () =>
                      ShellNavScope.maybeOf(context)?.startGuidedTour.call(),
                ),
              ],
            ),
            _SettingsGroupData(
              label: text.adminGroup,
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
                  title: text.appLanguage,
                  subtitle: text.languageLabel,
                  icon: Icons.translate_rounded,
                  trailing: app.language == AppLanguage.bn
                      ? text.bangla
                      : text.english,
                  onTap: _toggleLanguage,
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

    // Embedded directly in MoreScreen (the renamed Settings tab) — no
    // standalone page/Scaffold of its own, so there's no extra navigation to
    // get here and no duplicate top bar under More's own AppPageHeader.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
      ],
    );
  }

  Future<void> _openTableSettings() async {
    final app = AppScope.of(context);
    final text = app.strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _TableSettingsPage(
          initialCount: app.serverConfig.tableCount,
          onSave: (count) => app.updateTableCount(count),
          text: text,
        ),
      ),
    );
  }

  String _facebookBotTrailing(PosAppController app, AppStrings text) {
    final config = app.facebookChatbotConfig;
    if (config == null || !config.isConfigured) {
      return text.facebookBotNotConnected;
    }
    return config.isEnabled
        ? text.facebookBotConnected
        : text.facebookBotDisabled;
  }

  Future<void> _openFacebookChatbot() async {
    final text = AppScope.of(context).strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.facebookMessengerBot,
          child: const _FacebookChatbotSettingsPage(),
        ),
      ),
    );
  }

  Future<void> _openTableQrLabels() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const TableQrLabelsScreen()),
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
            onScan: _scanPrinters,
            onConnectUsb: _connectUsbPrinter,
            onConnectBluetooth: _connectPrinter,
            onTestPrint: _testPrinter,
          ),
        ),
      ),
    );
  }

  void _toggleLanguage() {
    final app = AppScope.of(context);
    final next = app.language == AppLanguage.bn
        ? AppLanguage.en
        : AppLanguage.bn;
    app.updateLanguage(next);
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

  Future<void> _scanPrinters() async {
    final app = AppScope.of(context);
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings scan printers '
        'supportsDirectBT=${app.supportsDirectBluetoothPrinting} '
        'busy=${app.printerState.busy} '
        'lastError="${app.printerState.lastError}"',
      );
    }
    await app.refreshPairedPrinters();
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] settings scan printers done '
        'busy=${app.printerState.busy} '
        'connected=${app.printerState.connected} '
        'devices=${app.pairedPrinters.length} '
        'lastError="${app.printerState.lastError}"',
      );
    }
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

  Future<void> _openAuditTrail() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AuditScreen()));
  }

  Future<void> _openStaff() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const StaffScreen()));
  }

  Future<void> _openRestaurantDetails() async {
    final text = AppScope.of(context).strings;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _SettingsSectionPage(
          title: text.myRestaurantDetailsGroup,
          child: const _RestaurantDetailsContent(),
        ),
      ),
    );
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

class _RestaurantDetailsContent extends StatefulWidget {
  const _RestaurantDetailsContent();

  @override
  State<_RestaurantDetailsContent> createState() =>
      _RestaurantDetailsContentState();
}

class _RestaurantDetailsContentState extends State<_RestaurantDetailsContent> {
  final MenuImageService _imageService = MenuImageService();
  bool _savingLogo = false;

  Future<void> _editSingleField({
    required String title,
    required String label,
    required String initialValue,
    required String saveLabel,
    required Future<bool> Function(String value) onSave,
    String? hint,
    String? helperText,
    String? suffixText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String value)? validator,
  }) async {
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SingleFieldEditSheet(
        title: title,
        label: label,
        initialValue: initialValue,
        saveLabel: saveLabel,
        hint: hint,
        helperText: helperText,
        suffixText: suffixText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        validator: validator,
      ),
    );
    if (value == null || !mounted) return;
    final app = AppScope.of(context);
    final text = app.strings;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await onSave(value);
    if (!mounted) return;
    setState(() {});
    messenger.showSnackBar(
      SnackBar(content: TfText(ok ? text.detailsPushed : text.saveFailed)),
    );
  }

  Future<void> _editAccountHolderName() async {
    final app = AppScope.of(context);
    final text = app.strings;
    return _editSingleField(
      title: text.accountHolderName,
      label: text.accountHolderName,
      initialValue: app.accountDisplayName,
      saveLabel: text.save,
      validator: (value) => value.trim().isEmpty ? text.requiredField : null,
      onSave: (value) => app.updateAccountDisplayName(value),
    );
  }

  Future<void> _editRestaurantName() async {
    final app = AppScope.of(context);
    final text = app.strings;
    return _editSingleField(
      title: text.restaurantName,
      label: text.restaurantName,
      initialValue: app.serverConfig.restaurantName,
      saveLabel: text.save,
      validator: (value) => value.trim().isEmpty ? text.requiredField : null,
      onSave: (value) => app.updateRestaurantProfile(restaurantName: value),
    );
  }

  Future<void> _editRestaurantPhone() async {
    final app = AppScope.of(context);
    final text = app.strings;
    return _editSingleField(
      title: text.restaurantPhoneLabel,
      label: text.restaurantPhoneLabel,
      initialValue: app.serverConfig.outletPhone,
      saveLabel: text.save,
      hint: '01XXXXXXXXX',
      keyboardType: TextInputType.phone,
      onSave: (value) => app.updateRestaurantProfile(phone: value),
    );
  }

  Future<void> _editWebsiteUrl() async {
    final app = AppScope.of(context);
    final text = app.strings;
    return _editSingleField(
      title: text.websiteUrlLabel,
      label: text.websiteUrlLabel,
      initialValue: app.serverConfig.publicSlug,
      saveLabel: text.save,
      helperText: 'https://name.quickbytes.buzz',
      suffixText: '.quickbytes.buzz',
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
        TextInputFormatter.withFunction((oldValue, newValue) {
          return newValue.copyWith(
            text: newValue.text.toLowerCase(),
            selection: newValue.selection,
          );
        }),
      ],
      validator: (value) =>
          value.trim().length < 3 ? text.urlNameTooShort : null,
      onSave: (value) => app.updatePublicMenuUrl(value),
    );
  }

  Future<void> _openHeroMedia() async {
    final app = AppScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _HeroMediaPage(
          outletId: app.serverConfig.outletId,
          cloudApiService: app.cloudApiService,
          baseUrl: app.cloudConfig.baseUrl,
        ),
      ),
    );
  }

  Future<void> _openRestaurantLogoUpload() async {
    final app = AppScope.of(context);
    final text = app.strings;
    try {
      final dataUrl = await _imageService.pickMenuImageDataUrl();
      if (dataUrl == null) return;
      setState(() => _savingLogo = true);
      final result = await app.cloudApiService.uploadOutletLogo(dataUrl);
      final url = result['logoUrl'];
      final bitmapUrl = result['logoBitmapUrl'];
      debugPrint(
        '[QB-LOGO] _openRestaurantLogoUpload result logoUrl="$url" logoBitmapUrl="$bitmapUrl"',
      );
      if (mounted) {
        if (url != null) AppScope.of(context).setLogoUrl(url);
        if (bitmapUrl != null) AppScope.of(context).setLogoBitmapUrl(bitmapUrl);
      }
      setState(() => _savingLogo = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.heroLogoUploaded)));
    } catch (e) {
      setState(() => _savingLogo = false);
      debugPrint('[QB-LOGO] _openRestaurantLogoUpload error="$e"');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openCustomerMenuTheme() async {
    final text = AppScope.of(context).strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.customerMenuTheme,
          child: const _CustomerMenuThemeCard(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final items = <_SettingActionData>[
      _SettingActionData(
        title: text.accountHolderName,
        subtitle: text.accountHolderNameSubtitle,
        icon: Icons.person_outline_rounded,
        trailing: app.accountDisplayName.trim().isEmpty
            ? text.setUpLabel
            : app.accountDisplayName,
        onTap: _editAccountHolderName,
      ),
      _SettingActionData(
        title: text.restaurantName,
        subtitle: text.restaurantNameFieldSubtitle,
        icon: Icons.storefront_outlined,
        trailing: app.serverConfig.restaurantName.trim().isEmpty
            ? text.setUpLabel
            : app.serverConfig.restaurantName,
        onTap: _editRestaurantName,
      ),
      _SettingActionData(
        title: text.restaurantPhoneLabel,
        subtitle: text.restaurantPhoneSubtitle,
        icon: Icons.call_outlined,
        trailing: app.serverConfig.outletPhone.trim().isEmpty
            ? text.setUpLabel
            : app.serverConfig.outletPhone,
        onTap: _editRestaurantPhone,
      ),
      _SettingActionData(
        title: text.websiteUrlLabel,
        subtitle: text.websiteUrlSubtitle,
        icon: Icons.link_rounded,
        trailing: app.serverConfig.publicSlug.trim().isEmpty
            ? text.setUpLabel
            : '${app.serverConfig.publicSlug}.quickbytes.buzz',
        onTap: _editWebsiteUrl,
      ),
      _SettingActionData(
        title: text.heroLogoTitle,
        subtitle: text.heroLogoSubtitle,
        icon: Icons.image_outlined,
        trailing: _savingLogo
            ? (text.isBn ? 'আপলোড হচ্ছে...' : 'Uploading...')
            : null,
        onTap: _savingLogo ? null : _openRestaurantLogoUpload,
      ),
      _SettingActionData(
        title: text.websiteImageVideoTitle,
        subtitle: text.heroMediaSubtitle,
        icon: Icons.photo_library_outlined,
        onTap: _openHeroMedia,
      ),
      _SettingActionData(
        title: text.settingsWebsiteTheme,
        subtitle: text.customerMenuThemeSubtitle,
        icon: Icons.palette_outlined,
        trailing: resolveCustomerMenuTheme(
          app.serverConfig.customerMenuTheme,
        ).displayName(isBn: text.isBn),
        onTap: _openCustomerMenuTheme,
      ),
    ];
    return SubscriptionGateCard(
      feature: 'website_qr',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: PosSpacing.sp2),
          _SettingsGroupCard(items: items),
        ],
      ),
    );
  }
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
    this.action,
    this.onTap,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? trailing;
  final Widget? action;
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
          if (item.action != null)
            item.action!
          else ...[
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
    return AppScaffold(title: title, showBackButton: true, child: child);
  }
}

/// Single-text-field bottom sheet — edit one value, save, return immediately
/// (no separate page). Modeled on menu_management_screen.dart's
/// _DeliveryChargeSheet. Used by the four "My restaurant details" identity
/// fields (Name, Restaurant Name, Phone, Website URL).
class _SingleFieldEditSheet extends StatefulWidget {
  const _SingleFieldEditSheet({
    required this.title,
    required this.label,
    required this.initialValue,
    required this.saveLabel,
    this.hint,
    this.helperText,
    this.suffixText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  final String title;
  final String label;
  final String initialValue;
  final String saveLabel;
  final String? hint;
  final String? helperText;
  final String? suffixText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String value)? validator;

  @override
  State<_SingleFieldEditSheet> createState() => _SingleFieldEditSheetState();
}

class _SingleFieldEditSheetState extends State<_SingleFieldEditSheet> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: PosColors.background,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PosRadii.card),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TfText(
                  widget.title,
                  style: const TextStyle(
                    color: PosColors.slate,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                TfField(
                  label: widget.label,
                  controller: _controller,
                  hint: widget.hint,
                  hintHelper: widget.helperText,
                  suffix: widget.suffixText != null
                      ? Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: TfText(
                            widget.suffixText!,
                            style: const TextStyle(
                              color: PosColors.muted,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : null,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  errorText: _error,
                  autofocus: true,
                ),
                const SizedBox(height: 14),
                TfButton(
                  label: widget.saveLabel,
                  icon: Icons.check_rounded,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    final value = _controller.text.trim();
    final error = widget.validator?.call(value);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(value);
  }
}

class _FacebookChatbotSettingsPage extends StatefulWidget {
  const _FacebookChatbotSettingsPage();

  @override
  State<_FacebookChatbotSettingsPage> createState() =>
      _FacebookChatbotSettingsPageState();
}

class _FacebookChatbotSettingsPageState
    extends State<_FacebookChatbotSettingsPage> {
  bool _enabled = true;
  bool _orderingEnabled = true;
  bool _loadRequested = false;
  String _configKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    final config = app.facebookChatbotConfig;
    final nextKey = config == null
        ? ''
        : '${config.pageId}|${config.isEnabled}|${config.orderingEnabled}';
    if (config != null && nextKey != _configKey) {
      _enabled = config.isEnabled;
      _orderingEnabled = config.orderingEnabled;
      _configKey = nextKey;
    }
    if (!_loadRequested) {
      _loadRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(AppScope.of(context).loadFacebookChatbotConfig());
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final config = app.facebookChatbotConfig;
    final statusLabel = config == null || !config.isConfigured
        ? text.facebookBotNotConnected
        : config.isEnabled
        ? text.facebookBotConnected
        : text.facebookBotDisabled;
    final statusKind = config == null || !config.isConfigured
        ? TfStatusKind.warning
        : config.isEnabled
        ? TfStatusKind.accepted
        : TfStatusKind.info;
    final webhookUrl = _webhookUrl(app.cloudConfig.baseUrl);

    return _SectionCard(
      title: text.facebookMessengerBot,
      subtitle: text.facebookMessengerBotSubtitle,
      icon: Icons.chat_bubble_outline_rounded,
      children: [
        SubscriptionGateCard(
          feature: 'messenger_bot',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: PosSpacing.sp2),
              Row(
                children: [
                  TfStatusBadge(label: statusLabel, kind: statusKind, upper: false),
                  if (app.facebookChatbotLoading) ...[
                    SizedBox(width: 8),
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 12),
              TfButton(
                label: config != null && config.isConfigured
                    ? text.reconnectFacebookPage
                    : text.connectFacebookPage,
                icon: Icons.login_rounded,
                busy: app.facebookChatbotLoading,
                fullWidth: true,
                onPressed: app.facebookChatbotLoading ? null : _connectWithFacebook,
              ),
              SizedBox(height: 8),
              _FacebookToggleRow(
                label: text.facebookBotEnabled,
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              _FacebookToggleRow(
                label: text.facebookOrderingEnabled,
                value: _orderingEnabled,
                onChanged: (value) => setState(() => _orderingEnabled = value),
              ),
              SizedBox(height: 10),
              _FacebookInfoRow(
                label: text.facebookWebhookUrl,
                value: webhookUrl,
                copyable: webhookUrl.isNotEmpty,
              ),
              if (config != null && config.isConfigured) ...[
                _FacebookInfoRow(
                  label: text.facebookPageName,
                  value: config.pageName,
                ),
                _FacebookInfoRow(label: text.facebookPageId, value: config.pageId),
                _FacebookInfoRow(
                  label: text.facebookTokenSavedAs,
                  value: config.tokenPreview,
                ),
              ],
              if ((app.facebookChatbotError ?? config?.lastError ?? '').isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: TfText(
                    app.facebookChatbotError ?? config?.lastError ?? '',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: PosColors.danger),
                  ),
                ),
              SizedBox(height: 14),
              TfButton(
                label: text.saveMessengerSettings,
                icon: Icons.check_rounded,
                busy: app.busy,
                fullWidth: true,
                onPressed: app.busy || config == null || !config.isConfigured
                    ? null
                    : _save,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _connectWithFacebook() async {
    final app = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final start = await app.startFacebookChatbotOAuth();
    if (!mounted) return;
    final url = start?.authorizationUrl.trim() ?? '';
    if (url.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          content: TfText(
            app.facebookChatbotError ??
                app.lastError ??
                app.strings.facebookLoginFailed,
          ),
        ),
      );
      return;
    }
    final sessionId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => _FacebookOAuthWebViewPage(initialUrl: url),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return;
    var connected = false;
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      connected =
          await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => _FacebookPageSelectionPage(sessionId: sessionId),
              fullscreenDialog: true,
            ),
          ) ==
          true;
    }
    if (connected) {
      await app.loadFacebookChatbotConfig();
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: TfText(
          connected
              ? app.strings.facebookLoginComplete
              : app.strings.facebookLoginFailed,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final app = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await app.saveFacebookChatbotConfig(
      pageAccessToken: '',
      isEnabled: _enabled,
      orderingEnabled: _orderingEnabled,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: TfText(
          ok
              ? app.strings.messengerSettingsSaved
              : app.lastError ?? app.strings.saveFailed,
        ),
      ),
    );
  }

  String _webhookUrl(String baseUrl) {
    final clean = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (clean.isEmpty) return '';
    return '$clean/webhooks/facebook';
  }
}

const _kFacebookOAuthUserAgent =
    'Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

class _FacebookOAuthWebViewPage extends StatefulWidget {
  const _FacebookOAuthWebViewPage({required this.initialUrl});

  final String initialUrl;

  @override
  State<_FacebookOAuthWebViewPage> createState() =>
      _FacebookOAuthWebViewPageState();
}

class _FacebookOAuthWebViewPageState extends State<_FacebookOAuthWebViewPage> {
  WebViewController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final initialUri = Uri.tryParse(widget.initialUrl);
    if (initialUri == null) {
      setState(() => _error = 'Facebook Login URL is invalid.');
      return;
    }
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_kFacebookOAuthUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final handled = _handleDoneUrl(request.url);
            return handled
                ? NavigationDecision.prevent
                : NavigationDecision.navigate;
          },
          onPageFinished: _handleDoneUrl,
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;
            setState(() {
              _error = 'Could not load Facebook Login (${error.description}).';
            });
          },
        ),
      );
    setState(() => _controller = controller);
    await controller.loadRequest(initialUri);
  }

  bool _handleDoneUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;
    final path = uri.path.replaceFirst(RegExp(r'/+\$'), '');
    if (!path.endsWith('/admin/chatbot/facebook/oauth/done') &&
        !path.endsWith('facebook/oauth/done')) {
      return false;
    }

    final params = <String, String>{};
    params.addAll(uri.queryParameters);
    if (uri.fragment.isNotEmpty) {
      try {
        params.addAll(Uri.splitQueryString(uri.fragment));
      } catch (_) {}
    }

    final success = params['status'] == 'success';
    if (success) {
      final sessionId = params['sessionId']?.trim() ?? '';
      if (sessionId.isNotEmpty && mounted) {
        Navigator.pop(context, sessionId);
      }
      return true;
    }

    if (mounted) {
      setState(() {
        _error =
            params['message'] ??
            AppScope.of(context).strings.facebookLoginFailed;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final error = _error;
    return AppScaffold(
      title: text.facebookLoginTitle,
      showBackButton: true,
      pinHeader: true,
      fillBody: true,
      child: Column(
        children: [
          if (error != null && error.isNotEmpty) ...[
            TfCard(
              color: PosColors.dangerSoft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    color: PosColors.danger,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TfText(
                      error,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: PosColors.danger),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
          ],
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PosRadii.md),
              child: ColoredBox(
                color: PosColors.surface,
                child: _controller == null
                    ? TfLoading(message: text.facebookLoginTitle)
                    : WebViewWidget(controller: _controller!),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FacebookPageSelectionPage extends StatefulWidget {
  const _FacebookPageSelectionPage({required this.sessionId});

  final String sessionId;

  @override
  State<_FacebookPageSelectionPage> createState() =>
      _FacebookPageSelectionPageState();
}

class _FacebookPageSelectionPageState
    extends State<_FacebookPageSelectionPage> {
  List<FacebookChatbotPage> _pages = const [];
  String _selectedPageId = '';
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final app = AppScope.of(context);
    final result = await app.loadFacebookChatbotOAuthPages(widget.sessionId);
    if (!mounted) return;
    final pages = result?.pages ?? const <FacebookChatbotPage>[];
    setState(() {
      _pages = pages;
      _selectedPageId = pages.length == 1 ? pages.first.pageId : '';
      _error = pages.isEmpty
          ? app.facebookChatbotError ?? app.strings.facebookLoginFailed
          : null;
      _loading = false;
    });
  }

  Future<void> _complete() async {
    final app = AppScope.of(context);
    final ok = await app.completeFacebookChatbotOAuth(
      sessionId: widget.sessionId,
      pageId: _selectedPageId,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _error =
          app.facebookChatbotError ?? app.lastError ?? app.strings.saveFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return AppScaffold(
      title: text.selectFacebookPage,
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TfText(text.selectFacebookPageSubtitle),
          SizedBox(height: 12),
          if (_loading)
            TfLoading(message: text.facebookLoginTitle)
          else
            RadioGroup<String>(
              groupValue: _selectedPageId,
              onChanged: (value) =>
                  setState(() => _selectedPageId = value ?? ''),
              child: Column(
                children: [
                  for (final page in _pages)
                    RadioListTile<String>(
                      value: page.pageId,
                      title: TfText(
                        page.pageName.isEmpty ? page.pageId : page.pageName,
                      ),
                      subtitle: page.pageName.isEmpty
                          ? null
                          : TfText(page.pageId),
                    ),
                ],
              ),
            ),
          if ((_error ?? '').isNotEmpty) ...[
            SizedBox(height: 8),
            TfText(
              _error!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: PosColors.danger),
            ),
          ],
          SizedBox(height: 12),
          TfButton(
            label: text.confirmFacebookPage,
            icon: Icons.check_rounded,
            busy: app.busy,
            fullWidth: true,
            onPressed: app.busy || _selectedPageId.isEmpty ? null : _complete,
          ),
        ],
      ),
    );
  }
}

class _FacebookToggleRow extends StatelessWidget {
  const _FacebookToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: TfText(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _FacebookInfoRow extends StatelessWidget {
  const _FacebookInfoRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final display = value.trim().isEmpty ? '—' : value.trim();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: TfText(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: PosColors.muted),
            ),
          ),
          Expanded(
            child: TfText(
              display,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          if (copyable)
            TfIconButton(
              icon: Icons.copy_rounded,
              tooltip: 'Copy',
              onPressed: () => Clipboard.setData(ClipboardData(text: display)),
            ),
        ],
      ),
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
            ...[
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
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CustomerMenuThemeCard extends StatelessWidget {
  const _CustomerMenuThemeCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final current = resolveCustomerMenuTheme(
      app.serverConfig.customerMenuTheme,
    );
    return _SectionCard(
      title: text.customerMenuTheme,
      subtitle: text.customerMenuThemeSubtitle,
      icon: Icons.palette_outlined,
      children: [
        InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: current.slug,
              isExpanded: true,
              items: customerMenuThemes.map((theme) {
                return DropdownMenuItem<String>(
                  value: theme.slug,
                  child: TfText(
                    theme.displayName(isBn: text.isBn),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                app.updateCustomerMenuTheme(value);
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        _CustomerMenuThemePreview(
          theme: current,
          isBn: text.isBn,
          previewLabel: text.customerMenuThemePreviewLabel,
        ),
      ],
    );
  }
}

class _CustomerMenuThemePreview extends StatelessWidget {
  const _CustomerMenuThemePreview({
    required this.theme,
    required this.isBn,
    required this.previewLabel,
  });

  final CustomerMenuThemeSpec theme;
  final bool isBn;
  final String previewLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TfText(
            previewLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: PosColors.muted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: theme.palette
                .map(
                  (color) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: PosColors.lineStrong,
                          width: 0.5,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          TfText(
            theme.sampleHeading,
            style: TextStyle(
              fontSize: 22,
              color: theme.primary,
              fontWeight: FontWeight.w700,
              fontStyle: theme.headingIsItalic
                  ? FontStyle.italic
                  : FontStyle.normal,
              fontFamily: theme.headingFontFamilyHint,
              letterSpacing: theme.headingIsItalic ? 0 : 1.4,
            ),
          ),
          const SizedBox(height: 4),
          TfText(
            theme.tagline(isBn: isBn),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: PosColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PrinterSettingsCard extends StatefulWidget {
  const _PrinterSettingsCard({
    required this.onScan,
    required this.onConnectUsb,
    required this.onConnectBluetooth,
    required this.onTestPrint,
  });

  final Future<void> Function() onScan;
  final Future<void> Function() onConnectUsb;
  final Future<void> Function(BluetoothPrinterDevice printer)
  onConnectBluetooth;
  final Future<void> Function() onTestPrint;

  @override
  State<_PrinterSettingsCard> createState() => _PrinterSettingsCardState();
}

class _PrinterSettingsCardState extends State<_PrinterSettingsCard> {
  bool _autoScanned = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_autoScanned) {
      _autoScanned = true;
      final app = AppScope.of(context);
      if (!app.printerState.connected) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onScan();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final state = app.printerState;
    final devices = app.pairedPrinters;

    return _SectionCard(
      title: text.receiptPrinter,
      icon: Icons.print_outlined,
      children: [
        _PrinterStatusTile(state: state, text: text),
        SizedBox(height: PosSpacing.sp3),
        TfButton(
          label: text.refreshPairedPrinters,
          icon: Icons.search_rounded,
          variant: TfButtonVariant.primary,
          busy: state.busy,
          onPressed: state.busy ? null : widget.onScan,
        ),
        if (state.usbPrinterAvailable ||
            state.builtInPrinterAvailable ||
            devices.isNotEmpty) ...[
          SizedBox(height: PosSpacing.sp2),
          if (state.usbPrinterAvailable)
            _PrinterTile(
              icon: Icons.usb_rounded,
              label: text.isBn ? 'USB প্রিন্টার' : 'USB Printer',
              connected:
                  state.activeTransport == PrinterTransport.usb ||
                  state.activeTransport == PrinterTransport.windowsUsb,
              onTap: state.busy ? null : widget.onConnectUsb,
            ),
          if (state.builtInPrinterAvailable)
            _PrinterTile(
              icon: Icons.print_rounded,
              label: text.isBn ? 'বিল্ট-ইন প্রিন্টার' : 'Built-in Printer',
              connected: state.activeTransport == PrinterTransport.builtIn,
              onTap: state.busy ? null : widget.onConnectUsb,
            ),
          for (final device in devices)
            _PrinterTile(
              icon: Icons.bluetooth_rounded,
              label: device.label,
              connected: device.address == state.selectedPrinterAddress,
              onTap: state.busy
                  ? null
                  : () => widget.onConnectBluetooth(device),
            ),
        ],
        if (state.lastError?.trim().isNotEmpty == true) ...[
          SizedBox(height: PosSpacing.sp2),
          _PrinterErrorHint(message: state.lastError!),
        ],
        if (state.connected) ...[
          SizedBox(height: PosSpacing.sp3),
          TfButton(
            label: text.testPrint,
            icon: Icons.receipt_long_outlined,
            variant: TfButtonVariant.primary,
            busy: state.busy,
            onPressed: state.busy ? null : widget.onTestPrint,
          ),
        ],
      ],
    );
  }
}

class _PrinterStatusTile extends StatelessWidget {
  const _PrinterStatusTile({required this.state, required this.text});

  final PrinterRuntimeState state;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final connected = state.connected;
    return Container(
      padding: EdgeInsets.all(PosSpacing.sp3),
      decoration: BoxDecoration(
        color: connected ? PosColors.successSoft : PosColors.background,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(
          color: connected ? PosColors.successSoft : PosColors.lineStrong,
        ),
      ),
      child: Row(
        children: [
          Icon(
            connected
                ? Icons.check_circle_rounded
                : Icons.print_disabled_outlined,
            color: connected ? PosColors.success : PosColors.muted,
            size: 20,
          ),
          SizedBox(width: PosSpacing.sp2),
          Expanded(
            child: TfText(
              connected
                  ? text.isBn
                        ? '${state.selectedPrinterLabel} কানেক্টেড'
                        : 'Connected to ${state.selectedPrinterLabel}'
                  : text.noPrinterSelected,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrinterTile extends StatelessWidget {
  const _PrinterTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.connected = false,
  });

  final IconData icon;
  final String label;
  final bool connected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppScope.of(context).strings;
    return Padding(
      padding: EdgeInsets.only(bottom: PosSpacing.sp2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosRadii.md),
        child: Container(
          padding: EdgeInsets.all(PosSpacing.sp3),
          decoration: BoxDecoration(
            color: connected ? PosColors.primarySoft : PosColors.background,
            borderRadius: BorderRadius.circular(PosRadii.md),
            border: Border.all(
              color: connected
                  ? PosColors.primaryWash
                  : PosColors.lineStrong.withValues(alpha: 0.48),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: connected ? PosColors.primarySoft : PosColors.surface,
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  border: Border.all(
                    color: connected ? PosColors.primaryWash : PosColors.line,
                  ),
                ),
                child: Icon(
                  connected ? Icons.check_circle_rounded : icon,
                  color: connected ? PosColors.primary : PosColors.muted,
                  size: 18,
                ),
              ),
              SizedBox(width: PosSpacing.sp2),
              Expanded(
                child: TfText(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (connected)
                TfText(
                  strings.connected,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: PosColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrinterErrorHint extends StatelessWidget {
  const _PrinterErrorHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(PosSpacing.sp2),
      decoration: BoxDecoration(
        color: PosColors.dangerSoft,
        borderRadius: BorderRadius.circular(PosRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: PosColors.danger, size: 18),
          SizedBox(width: PosSpacing.sp2),
          Expanded(
            child: TfText(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: PosColors.inkSoft),
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

// ─── Hero Media Page ──────────────────────────────────────────────────────────

class _HeroMediaPage extends StatefulWidget {
  const _HeroMediaPage({
    required this.outletId,
    required this.cloudApiService,
    required this.baseUrl,
  });

  final String outletId;
  final dynamic cloudApiService;
  final String baseUrl;

  @override
  State<_HeroMediaPage> createState() => _HeroMediaPageState();
}

class _HeroMediaPageState extends State<_HeroMediaPage> {
  final _imageService = MenuImageService();
  final _videoPicker = ImagePicker();
  List<String> _gallery = [];
  String? _currentLogoUrl;
  String? _currentVideoUrl;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchInfo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final base = widget.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      if (base.isEmpty) {
        throw Exception(
          'Cloud API URL is not configured. Open Settings → Connection URLs and set it.',
        );
      }
      final uri = Uri.parse('$base/customer/${widget.outletId}/info');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Server returned HTTP ${res.statusCode}.');
      }
      final data = jsonDecode(res.body);
      final info = data['data'] is Map
          ? Map<String, dynamic>.from(data['data'] as Map)
          : <String, dynamic>{};
      debugPrint(
        '[QB-LOGO] _fetchOutletInfo raw logoUrl="${info['logoUrl']}" logoBitmapUrl="${info['logoBitmapUrl']}"',
      );
      final rawGallery = info['galleryImages'];
      setState(() {
        _gallery = rawGallery is List
            ? rawGallery.map((e) => e.toString()).toList()
            : [];
        _currentLogoUrl = info['logoUrl']?.toString().trim().isEmpty == true
            ? null
            : info['logoUrl']?.toString().trim();
        if (mounted) AppScope.of(context).setLogoUrl(_currentLogoUrl);
        final bitmapUrl = info['logoBitmapUrl']?.toString().trim();
        if (mounted) {
          AppScope.of(
            context,
          ).setLogoBitmapUrl(bitmapUrl?.isNotEmpty == true ? bitmapUrl : null);
        }
        _currentVideoUrl = info['videoUrl']?.toString().trim().isEmpty == true
            ? null
            : info['videoUrl']?.toString().trim();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickAndUploadLogo() async {
    try {
      final dataUrl = await _imageService.pickMenuImageDataUrl();
      if (dataUrl == null) return;
      setState(() => _saving = true);
      final result = await widget.cloudApiService.uploadOutletLogo(dataUrl);
      final url = result['logoUrl'] as String?;
      final bitmapUrl = result['logoBitmapUrl'] as String?;
      debugPrint(
        '[QB-LOGO] _pickAndUploadLogo result logoUrl="$url" logoBitmapUrl="$bitmapUrl"',
      );
      setState(() {
        _currentLogoUrl = url;
        _saving = false;
      });
      if (!mounted) return;
      if (url != null) AppScope.of(context).setLogoUrl(url);
      if (bitmapUrl != null) AppScope.of(context).setLogoBitmapUrl(bitmapUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppScope.of(context).strings.heroLogoUploaded)),
      );
    } on MenuImageException catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _clearLogo() async {
    setState(() => _saving = true);
    try {
      await widget.cloudApiService.updateOutletLogo(null);
      debugPrint('[QB-LOGO] _clearLogo done');
      setState(() {
        _currentLogoUrl = null;
        _saving = false;
      });
      if (mounted) {
        AppScope.of(context).setLogoUrl(null);
        AppScope.of(context).setLogoBitmapUrl(null);
      }
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addImage() async {
    if (_gallery.length >= 5) {
      final text = AppScope.of(context).strings;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.heroMaxImages)));
      return;
    }
    try {
      final dataUrl = await _imageService.pickMenuImageDataUrl();
      if (dataUrl == null) return;
      setState(() => _saving = true);
      final updated =
          await widget.cloudApiService.uploadOutletImage(dataUrl)
              as List<String>;
      setState(() {
        _gallery = updated;
        _saving = false;
      });
    } on MenuImageException catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _deleteImage(int index) async {
    final text = AppScope.of(context).strings;
    TfConfirmSheet.show(
      context,
      title: text.heroRemoveImageTitle,
      description: text.remove,
      confirmLabel: text.remove,
      isDanger: true,
      onConfirm: () async {
        try {
          setState(() => _saving = true);
          final updated =
              await widget.cloudApiService.deleteOutletImage(index)
                  as List<String>;
          if (!mounted) return;
          setState(() {
            _gallery = updated;
            _saving = false;
          });
        } catch (e) {
          if (!mounted) return;
          setState(() => _saving = false);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.toString())));
        }
      },
    );
  }

  Future<void> _pickAndUploadVideo() async {
    final video = await _videoPicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (video == null) return;

    final bytes = await video.readAsBytes();
    const maxBytes = 50 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      if (!mounted) return;
      final text = AppScope.of(context).strings;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text.heroVideoTooLarge)));
      return;
    }

    setState(() => _saving = true);
    try {
      final url =
          await widget.cloudApiService.uploadOutletVideo(bytes, video.name)
              as String;
      setState(() {
        _currentVideoUrl = url;
        _saving = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppScope.of(context).strings.heroVideoUploaded)),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _clearVideo() async {
    setState(() => _saving = true);
    try {
      await widget.cloudApiService.updateOutletMedia(videoUrl: null);
      setState(() {
        _currentVideoUrl = null;
        _saving = false;
      });
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return Scaffold(
      appBar: AppBar(
        title: TfText(text.websiteImageVideoTitle),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TfText(_error!, textAlign: TextAlign.center),
                  SizedBox(height: 12),
                  TfButton(
                    label: text.retry,
                    onPressed: _fetchInfo,
                    fullWidth: false,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TfText(
                    text.heroLogoTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  TfText(
                    text.heroLogoSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _currentLogoUrl != null
                              ? Image.network(
                                  _currentLogoUrl!,
                                  width: 72,
                                  height: 72,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        width: 72,
                                        height: 72,
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.broken_image_outlined,
                                        ),
                                      ),
                                )
                              : Container(
                                  width: 72,
                                  height: 72,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                                  child: const Icon(
                                    Icons.storefront_outlined,
                                    size: 30,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TfText(
                            _currentLogoUrl == null
                                ? text.heroAddLogo
                                : text.heroLogoSet,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_currentLogoUrl != null) ...[
                          TfButton(
                            label: text.remove,
                            icon: Icons.delete_outline,
                            variant: TfButtonVariant.paper,
                            size: TfButtonSize.sm,
                            fullWidth: false,
                            onPressed: _saving ? null : _clearLogo,
                          ),
                          const SizedBox(width: 8),
                        ],
                        TfButton(
                          label: _currentLogoUrl == null
                              ? text.heroAddLogo
                              : text.heroReplaceLogo,
                          icon: Icons.add_photo_alternate_outlined,
                          variant: TfButtonVariant.paper,
                          size: TfButtonSize.sm,
                          fullWidth: false,
                          busy: _saving,
                          onPressed: _saving ? null : _pickAndUploadLogo,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  TfText(
                    text.heroPhotosTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  TfText(
                    text.heroPhotosSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 110,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        ..._gallery.asMap().entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    e.value,
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              width: 110,
                                              height: 110,
                                              color: Colors.grey.shade200,
                                              child: const Icon(
                                                Icons.broken_image_outlined,
                                              ),
                                            ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: _saving
                                        ? null
                                        : () => _deleteImage(e.key),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_gallery.length < 5)
                          GestureDetector(
                            onTap: _saving ? null : _addImage,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.outlineVariant,
                                  width: 1.5,
                                ),
                              ),
                              child: _saving
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 32,
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  TfText(
                    text.heroVideoTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  TfText(
                    text.heroVideoSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 14),
                  if (_currentVideoUrl != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.videocam_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TfText(
                              text.heroVideoSet,
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                          TfButton(
                            label: text.remove,
                            icon: Icons.delete_outline,
                            variant: TfButtonVariant.paper,
                            size: TfButtonSize.sm,
                            fullWidth: false,
                            onPressed: _saving ? null : _clearVideo,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TfButton(
                    label: _currentVideoUrl != null
                        ? text.heroReplaceVideo
                        : text.heroPickVideo,
                    icon: Icons.video_library_outlined,
                    busy: _saving,
                    onPressed: _saving ? null : _pickAndUploadVideo,
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Table Settings Page ──────────────────────────────────────────────────────

class _TableSettingsPage extends StatefulWidget {
  const _TableSettingsPage({
    required this.initialCount,
    required this.onSave,
    required this.text,
  });

  final int initialCount;
  final Future<void> Function(int) onSave;
  final AppStrings text;

  @override
  State<_TableSettingsPage> createState() => _TableSettingsPageState();
}

class _TableSettingsPageState extends State<_TableSettingsPage> {
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = widget.initialCount;
  }

  Future<void> _save() async {
    await widget.onSave(_count);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(widget.text.settingsSaved)));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    return Scaffold(
      appBar: AppBar(
        title: TfText(text.tables),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: TfButton(
              label: text.save,
              variant: TfButtonVariant.ghost,
              size: TfButtonSize.sm,
              fullWidth: false,
              onPressed: _save,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TfText(
                text.tablesSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              SizedBox(height: 32),
              Row(
                children: [
                  IconButton.filled(
                    icon: Icon(Icons.remove),
                    onPressed: _count > 0
                        ? () => setState(() => _count--)
                        : null,
                    style: IconButton.styleFrom(minimumSize: Size(48, 48)),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      children: [
                        TfText(
                          '$_count',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        TfText(
                          text.tables,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  IconButton.filled(
                    icon: Icon(Icons.add),
                    onPressed: _count < 200
                        ? () => setState(() => _count++)
                        : null,
                    style: IconButton.styleFrom(minimumSize: Size(48, 48)),
                  ),
                ],
              ),
              SizedBox(height: 32),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in [
                    0,
                    4,
                    6,
                    8,
                    10,
                    12,
                    15,
                    20,
                    25,
                    30,
                    40,
                    50,
                  ])
                    TfChip(
                      label: '$preset',
                      active: _count == preset,
                      small: true,
                      onTap: () => setState(() => _count = preset),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// About Us page
// ─────────────────────────────────────────────────────────────────────────────

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
                          color: PosColors.neutralSoft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PosColors.neutralWash),
                        ),
                        child: Icon(
                          Icons.restaurant_rounded,
                          color: PosColors.neutralInk,
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
        color: PosColors.neutralSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.neutralWash),
      ),
      child: TfText(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: PosColors.neutralInk,
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
