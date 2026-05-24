import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/pos_notification.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/menu_image_service.dart';
import '../../services/printer_service.dart';
import '../reports/reports_screen.dart';
import 'qr_pdf_screen.dart';

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
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _restaurantInfoFormKey = GlobalKey<FormState>();
  final TextEditingController _restaurantController = TextEditingController();
  final TextEditingController _publicSlugController = TextEditingController();
  final TextEditingController _cloudUrlController = TextEditingController();
  final TextEditingController _restaurantIdController = TextEditingController();
  final TextEditingController _outletIdController = TextEditingController();
  final TextEditingController _syncIntervalController = TextEditingController();
  final TextEditingController _infoTitleController = TextEditingController();
  final TextEditingController _infoPhoneController = TextEditingController();
  final TextEditingController _infoEmailController = TextEditingController();
  final TextEditingController _infoAddressController = TextEditingController();
  final TextEditingController _infoWebsiteController = TextEditingController();
  final TextEditingController _infoDescriptionController =
      TextEditingController();
  final TextEditingController _settingsSearchController =
      TextEditingController();
  Timer? _autoSaveDebounce;
  bool _cloudSyncEnabled = false;
  bool _importingOrderHistory = false;
  double _displayScale = 1.0;
  bool _hydrated = false;
  int _handledReceiptPrinterOpenRequest = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrated) return;
    final app = AppScope.of(context);
    _restaurantController.text = app.serverConfig.restaurantName;
    _publicSlugController.text = app.serverConfig.publicSlug;
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
    _publicSlugController.dispose();
    _cloudUrlController.dispose();
    _restaurantIdController.dispose();
    _outletIdController.dispose();
    _syncIntervalController.dispose();
    _infoTitleController.dispose();
    _infoPhoneController.dispose();
    _infoEmailController.dispose();
    _infoAddressController.dispose();
    _infoWebsiteController.dispose();
    _infoDescriptionController.dispose();
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
              label: text.storeGroup,
              items: [
                _SettingActionData(
                  title: text.restaurantSection,
                  subtitle: text.restaurantSubtitle,
                  icon: Icons.storefront_outlined,
                  trailing: app.serverConfig.restaurantName.trim().isEmpty
                      ? 'Setup'
                      : app.serverConfig.restaurantName,
                  onTap: _openRestaurantInfo,
                ),
                _SettingActionData(
                  title: text.heroMediaTitle,
                  subtitle: text.heroMediaSubtitle,
                  icon: Icons.photo_library_outlined,
                  onTap: _openHeroMedia,
                ),
                _SettingActionData(
                  title: text.tables,
                  subtitle: text.tablesSubtitle,
                  icon: Icons.table_restaurant_outlined,
                  trailing: '${app.serverConfig.tableCount} tables',
                  onTap: _openTableSettings,
                ),
              ],
            ),
            _SettingsGroupData(
              label: text.deviceGroup,
              items: [
                _SettingActionData(
                  title: text.receiptPrinter,
                  subtitle: text.receiptPrinterSubtitle,
                  icon: Icons.print_outlined,
                  trailing: app.printerState.connected ? 'Connected' : 'Pair',
                  onTap: _openReceiptPrinter,
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
              label: text.adminGroup,
              items: [
                _SettingActionData(
                  title: text.tableQrCodes,
                  subtitle: text.tableQrSubtitle,
                  icon: Icons.qr_code_rounded,
                  onTap: _openQrCodes,
                ),
                _SettingActionData(
                  title: text.reports,
                  subtitle: 'Sales summaries, trends, and export.',
                  icon: Icons.assessment_outlined,
                  onTap: _openReports,
                ),
                _SettingActionData(
                  title: text.importOrderHistory,
                  subtitle: text.importOrderHistorySubtitle,
                  icon: Icons.upload_file_outlined,
                  trailing: _importingOrderHistory
                      ? text.importOrderHistoryLoading
                      : text.importOrderHistoryCsv,
                  onTap: _importingOrderHistory ? null : _importOrderHistory,
                ),
                _SettingActionData(
                  title: text.yourRestaurantInfo,
                  subtitle: text.yourRestaurantInfoSubtitle,
                  icon: Icons.business_outlined,
                  onTap: _openYourRestaurantInfo,
                ),
                _SettingActionData(
                  title: text.staffAccounts,
                  subtitle: text.staffAccountsSubtitle,
                  icon: Icons.groups_2_outlined,
                  onTap: _openStaffAccounts,
                ),
                _SettingActionData(
                  title: text.aboutUs,
                  subtitle: 'Product and company details',
                  icon: Icons.info_outline_rounded,
                  onTap: _openAboutUs,
                ),
                _SettingActionData(
                  title: text.privacyPolicy,
                  subtitle: 'How we handle data and privacy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: _openPrivacyPolicy,
                ),
                _SettingActionData(
                  title: text.logOut,
                  subtitle: text.logOutSubtitle,
                  icon: Icons.logout_rounded,
                  onTap: _confirmLogout,
                  danger: true,
                ),
              ],
            ),
            _SettingsGroupData(
              label: text.dangerZoneGroup,
              items: [
                _SettingActionData(
                  title: text.wipeRestaurantData,
                  subtitle: text.wipeRestaurantDataSubtitle,
                  icon: Icons.delete_forever_rounded,
                  onTap: _confirmWipeRestaurant,
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
                  title: text.receiptPrinter,
                  subtitle: text.receiptPrinterSubtitle,
                  icon: Icons.print_outlined,
                  trailing: app.printerState.connected ? 'Connected' : 'Pair',
                  onTap: _openReceiptPrinter,
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
              label: text.adminGroup,
              items: [
                _SettingActionData(
                  title: text.tableQrCodes,
                  subtitle: text.tableQrSubtitle,
                  icon: Icons.qr_code_rounded,
                  onTap: _openQrCodes,
                ),
                _SettingActionData(
                  title: text.aboutUs,
                  subtitle: 'Product and company details',
                  icon: Icons.info_outline_rounded,
                  onTap: _openAboutUs,
                ),
                _SettingActionData(
                  title: text.privacyPolicy,
                  subtitle: 'How we handle data and privacy',
                  icon: Icons.privacy_tip_outlined,
                  onTap: _openPrivacyPolicy,
                ),
                _SettingActionData(
                  title: text.logOut,
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
                    TfAppBar(
                      title: text.settings,
                      subtitle: text.isBn
                          ? 'সেটিংস · v2.2.1'
                          : 'Settings · v2.2.1',
                      trailing: [
                        HeaderLanguageButton(),
                        HeaderNotificationBell(
                          onNavigateToOrders:
                              widget.onNavigateToOrders ?? () {},
                          onNavigateToTarget: widget.onNavigateToTarget,
                        ),
                      ],
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

  Future<void> _openRestaurantInfo() async {
    final text = AppScope.of(context).strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.restaurantSection,
          child: Form(
            key: _formKey,
            child: _SectionCard(
              title: text.restaurantSection,
              subtitle: text.restaurantSubtitle,
              icon: Icons.storefront_outlined,
              children: [
                TextFormField(
                  controller: _restaurantController,
                  decoration: InputDecoration(
                    labelText: text.restaurantName,
                    prefixIcon: Icon(Icons.restaurant_outlined),
                  ),
                  validator: _required,
                ),
                SizedBox(height: 10),
                TextFormField(
                  controller: _publicSlugController,
                  decoration: InputDecoration(
                    labelText: 'Customer URL',
                    prefixIcon: Icon(Icons.link_rounded),
                    helperText: 'https://name.quickbytes.buzz',
                    suffixText: '.quickbytes.buzz',
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9-]')),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      return newValue.copyWith(
                        text: newValue.text.toLowerCase(),
                        selection: newValue.selection,
                      );
                    }),
                  ],
                ),
                SizedBox(height: 10),
                PrimaryButton(
                  label: 'Save customer URL',
                  icon: Icons.check_rounded,
                  busy: AppScope.of(context).busy,
                  onPressed: AppScope.of(context).busy
                      ? null
                      : () => _savePublicUrl(context),
                ),
                SizedBox(height: 10),
                _ResponsiveFields(
                  children: [
                    TextFormField(
                      controller: _restaurantIdController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: text.restaurantId,
                        prefixIcon: Icon(Icons.badge_outlined),
                        helperText: text.restaurantIdHelper,
                      ),
                      validator: _required,
                    ),
                    TextFormField(
                      controller: _outletIdController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: text.outletId,
                        prefixIcon: Icon(Icons.pin_drop_outlined),
                        helperText: text.outletIdHelper,
                      ),
                      validator: _required,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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

  Future<void> _openQrCodes() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const QrPdfScreen()));
  }

  Future<void> _openReports() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ReportsScreen()));
  }

  Future<void> _importOrderHistory() async {
    final app = AppScope.of(context);
    final text = app.strings;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty || !mounted) return;
      final file = picked.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        throw Exception(
          text.isBn
              ? 'নির্বাচিত CSV ফাইল পড়া যায়নি।'
              : 'Could not read the selected CSV file.',
        );
      }

      setState(() => _importingOrderHistory = true);
      final result = await app.importOrderHistoryCsv(
        bytes: bytes,
        fileName: file.name,
      );
      if (!mounted) return;
      final skipped = result.duplicateOrders + result.skippedRows;
      final detail = result.errors.isEmpty ? '' : ' ${result.errors.first}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(
            text.orderHistoryImportSuccess(
              result.importedOrders,
              skipped,
              detail,
            ),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TfText(text.orderHistoryImportFailed(error))),
      );
    } finally {
      if (mounted) setState(() => _importingOrderHistory = false);
    }
  }

  Future<void> _openReceiptPrinter() async {
    final app = AppScope.of(context);
    final text = app.strings;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: text.receiptPrinter,
          child: _PrinterSettingsCard(
            text: text,
            state: app.printerState,
            devices: app.pairedPrinters,
            onAutoPrintChanged: app.setAutoPrintOrders,
            onRefresh: _refreshPrinters,
            onConnect: _connectPrinter,
            onDisconnect: _disconnectPrinter,
            onTestPrint: _testPrinter,
          ),
        ),
      ),
    );
  }

  Future<void> _openStaffAccounts() async {
    final app = AppScope.of(context);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _SettingsSectionPage(
          title: 'Staff accounts',
          child: _StaffAccountsCard(app: app),
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

  Future<void> _confirmWipeRestaurant() async {
    final app = AppScope.of(context);
    final text = app.strings;
    final outletId = app.serverConfig.outletId.trim();
    if (!app.cloudConfig.canSync || outletId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(text.wipeRequiresCloud)));
      return;
    }
    final wiped = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _WipeRestaurantDialog(app: app, text: text, outletId: outletId),
    );
    if (!mounted || wiped != true) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: TfText(text.wipeRestaurantSuccess)));
  }

  Future<void> _openYourRestaurantInfo() async {
    final app = AppScope.of(context);
    _infoTitleController.text = app.serverConfig.restaurantName;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final a = AppScope.of(context);
          final t = a.strings;
          return _SettingsSectionPage(
            title: t.yourRestaurantInfo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Account Identity (read-only) ──────────────────────────
                _SectionCard(
                  title: t.accountIdentity,
                  subtitle: t.accountIdentitySubtitle,
                  icon: Icons.verified_user_outlined,
                  children: [
                    _ReadOnlyInfoTile(
                      icon: Icons.email_outlined,
                      label: t.managerEmail,
                      value: a.accountEmail.isNotEmpty ? a.accountEmail : '—',
                    ),
                    SizedBox(height: 8),
                    _ReadOnlyInfoTile(
                      icon: Icons.badge_outlined,
                      label: t.accountRole,
                      value: a.accountRole.label,
                    ),
                    SizedBox(height: 8),
                    _ReadOnlyInfoTile(
                      icon: Icons.restaurant_outlined,
                      label: t.restaurantName,
                      value: a.serverConfig.restaurantName.isNotEmpty
                          ? a.serverConfig.restaurantName
                          : '—',
                    ),
                    SizedBox(height: 8),
                    _ReadOnlyInfoTile(
                      icon: Icons.fingerprint_outlined,
                      label: t.restaurantId,
                      value: a.serverConfig.restaurantId.isNotEmpty
                          ? a.serverConfig.restaurantId
                          : '—',
                      monospace: true,
                    ),
                    SizedBox(height: 8),
                    _ReadOnlyInfoTile(
                      icon: Icons.qr_code_outlined,
                      label: t.outletId,
                      value: a.serverConfig.outletId.isNotEmpty
                          ? a.serverConfig.outletId
                          : '—',
                      monospace: true,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // ── Editable public contact info ──────────────────────────
                Form(
                  key: _restaurantInfoFormKey,
                  child: _SectionCard(
                    title: t.yourRestaurantInfo,
                    subtitle: t.yourRestaurantInfoSubtitle,
                    icon: Icons.business_outlined,
                    children: [
                      TextFormField(
                        controller: _infoTitleController,
                        decoration: InputDecoration(
                          labelText: t.restaurantName,
                          prefixIcon: Icon(Icons.store_mall_directory_outlined),
                        ),
                        validator: _required,
                      ),
                      SizedBox(height: 10),
                      _ResponsiveFields(
                        children: [
                          TextFormField(
                            controller: _infoPhoneController,
                            decoration: InputDecoration(
                              labelText: t.contactPhone,
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          TextFormField(
                            controller: _infoEmailController,
                            decoration: InputDecoration(
                              labelText: t.contactEmail,
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      TextFormField(
                        controller: _infoAddressController,
                        decoration: InputDecoration(
                          labelText: t.contactAddress,
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextFormField(
                        controller: _infoWebsiteController,
                        decoration: InputDecoration(
                          labelText: t.website,
                          prefixIcon: Icon(Icons.language_outlined),
                        ),
                      ),
                      SizedBox(height: 10),
                      TextFormField(
                        controller: _infoDescriptionController,
                        minLines: 3,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: t.description,
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.notes_outlined),
                        ),
                      ),
                      SizedBox(height: 14),
                      TfButton(
                        label: t.pushToCloud,
                        icon: Icons.cloud_upload_outlined,
                        onPressed: _pushRestaurantInfo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
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

  Future<void> _pushRestaurantInfo() async {
    if (!_restaurantInfoFormKey.currentState!.validate()) return;
    final app = AppScope.of(context);
    final text = app.strings;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await app.pushRestaurantInfo(
      title: _infoTitleController.text,
      phone: _infoPhoneController.text,
      email: _infoEmailController.text,
      address: _infoAddressController.text,
      website: _infoWebsiteController.text,
      description: _infoDescriptionController.text,
    );
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: TfText(
          ok ? text.detailsPushed : (app.lastError ?? text.saveFailed),
        ),
      ),
    );
  }

  Future<void> _savePublicUrl(BuildContext context) async {
    final app = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final slug = _publicSlugController.text.trim().toLowerCase();
    if (slug.length < 3) {
      messenger.showSnackBar(
        SnackBar(content: TfText('URL name must be at least 3 characters.')),
      );
      return;
    }
    final ok = await app.updatePublicMenuUrl(slug);
    if (!mounted) return;
    _publicSlugController.text = app.serverConfig.publicSlug;
    messenger.showSnackBar(
      SnackBar(
        content: TfText(
          ok
              ? 'Customer URL saved: https://${app.serverConfig.publicSlug}.quickbytes.buzz'
              : app.lastError ?? 'Could not save customer URL.',
        ),
      ),
    );
    setState(() {});
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
    final printers = await app.refreshPairedPrinters();
    if (!mounted) return;
    final error = app.printerState.lastError;
    final message =
        error ??
        (printers.isEmpty
            ? text.noPairedPrintersFound
            : text.pairedPrinterFound(printers.length));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _connectPrinter(BluetoothPrinterDevice printer) async {
    final app = AppScope.of(context);
    final text = app.strings;
    final ok = await app.connectPrinter(printer);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TfText(
          ok
              ? text.connectedTo(printer.label)
              : app.printerState.lastError ?? text.printerConnectionFailed,
        ),
      ),
    );
  }

  Future<void> _disconnectPrinter() async {
    final app = AppScope.of(context);
    final text = app.strings;
    final ok = await app.disconnectPrinter();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? text.printerDisconnected : text.disconnectFailed),
      ),
    );
  }

  Future<void> _testPrinter() async {
    final app = AppScope.of(context);
    final text = app.strings;
    final ok = await app.testPrinter();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TfText(
          ok
              ? text.testTicketSent
              : app.printerState.lastError ?? text.testFailed,
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppScope.of(context).strings.requiredField;
    }
    return null;
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
    final iconColor = item.danger ? PosColors.danger : PosColors.slate;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: PosColors.surfaceWarm.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: iconColor, size: 16),
          ),
          SizedBox(width: 10),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 2),
                TfText(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
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
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
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

class _WipeRestaurantDialog extends StatefulWidget {
  const _WipeRestaurantDialog({
    required this.app,
    required this.text,
    required this.outletId,
  });

  final PosAppController app;
  final AppStrings text;
  final String outletId;

  @override
  State<_WipeRestaurantDialog> createState() => _WipeRestaurantDialogState();
}

class _WipeRestaurantDialogState extends State<_WipeRestaurantDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  bool get _matches => _controller.text.trim() == widget.outletId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _wipe() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await widget.app.wipeCurrentRestaurant(
      confirmation: _controller.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _submitting = false;
      _error = widget.text.wipeRestaurantFailed(
        widget.app.lastError ?? widget.text.somethingWentWrong,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: TfText(widget.text.wipeRestaurantDialogTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TfText(
              widget.text.wipeRestaurantDialogMessage(widget.outletId),
              style: const TextStyle(color: PosColors.muted, height: 1.45),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              enabled: !_submitting,
              decoration: InputDecoration(
                labelText: widget.text.typeOutletIdToConfirm,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              TfText(
                _error!,
                style: const TextStyle(color: PosColors.danger, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: 118,
          child: TfButton(
            label: widget.text.cancel,
            variant: TfButtonVariant.paper,
            fullWidth: true,
            onPressed: _submitting ? null : () => Navigator.pop(context, false),
          ),
        ),
        SizedBox(
          width: 150,
          child: TfButton(
            label: widget.text.wipeRestaurantConfirm,
            variant: TfButtonVariant.dark,
            fullWidth: true,
            busy: _submitting,
            onPressed: !_matches || _submitting ? null : _wipe,
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyInfoTile extends StatelessWidget {
  const _ReadOnlyInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: PosColors.muted),
        SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TfText(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: PosColors.muted,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(height: 2),
              SelectableText(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: PosColors.slate,
                  fontFamily: monospace ? 'monospace' : null,
                  letterSpacing: monospace ? 0.5 : 0,
                ),
              ),
            ],
          ),
        ),
      ],
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

// ignore: unused_element
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

class _ResponsiveFields extends StatelessWidget {
  const _ResponsiveFields({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 640) {
          return Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: 10),
                children[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: 12),
              Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

class _PrinterSettingsCard extends StatelessWidget {
  const _PrinterSettingsCard({
    required this.text,
    required this.state,
    required this.devices,
    required this.onAutoPrintChanged,
    required this.onRefresh,
    required this.onConnect,
    required this.onDisconnect,
    required this.onTestPrint,
  });

  final AppStrings text;
  final PrinterRuntimeState state;
  final List<BluetoothPrinterDevice> devices;
  final ValueChanged<bool> onAutoPrintChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(BluetoothPrinterDevice printer) onConnect;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onTestPrint;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: text.receiptPrinter,
      subtitle: text.receiptPrinterSubtitle,
      icon: Icons.print_outlined,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PosColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: state.connected
                  ? PosColors.success.withValues(alpha: 0.24)
                  : PosColors.lineStrong.withValues(alpha: 0.48),
            ),
          ),
          child: Row(
            children: [
              Icon(
                state.connected
                    ? Icons.print_rounded
                    : Icons.print_disabled_outlined,
                color: state.connected ? PosColors.success : PosColors.muted,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TfText(
                      state.hasSelectedPrinter
                          ? state.selectedPrinterLabel
                          : text.noPrinterSelected,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 2),
                    TfText(
                      state.connected
                          ? text.printerConnectedAuto
                          : text.pairPrinterInstruction,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        SwitchListTile.adaptive(
          value: state.autoPrintEnabled,
          onChanged: state.busy ? null : onAutoPrintChanged,
          contentPadding: EdgeInsets.zero,
          title: Text(text.autoPrintNewOrders),
          subtitle: Text(text.autoPrintNewOrdersSubtitle),
        ),
        if (state.lastError != null) ...[
          SizedBox(height: 8),
          _PrinterErrorBanner(message: state.lastError!),
        ],
        SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TfButton(
              label: text.refreshPairedPrinters,
              icon: Icons.bluetooth_searching_rounded,
              variant: TfButtonVariant.paper,
              size: TfButtonSize.sm,
              fullWidth: false,
              onPressed: state.busy ? null : onRefresh,
            ),
            TfButton(
              label: text.testPrint,
              icon: Icons.receipt_long_outlined,
              variant: TfButtonVariant.paper,
              size: TfButtonSize.sm,
              fullWidth: false,
              onPressed: state.busy || !state.hasSelectedPrinter
                  ? null
                  : onTestPrint,
            ),
            if (state.connected)
              TfButton(
                label: text.disconnect,
                icon: Icons.link_off_rounded,
                variant: TfButtonVariant.paper,
                size: TfButtonSize.sm,
                fullWidth: false,
                onPressed: state.busy ? null : onDisconnect,
              ),
          ],
        ),
        if (devices.isNotEmpty) ...[
          SizedBox(height: 12),
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
      ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  printer.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 2),
                TfText(
                  printer.address,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
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

class _PrinterErrorBanner extends StatelessWidget {
  const _PrinterErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PosColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.danger.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: PosColors.danger),
          SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
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
      final rawGallery = info['galleryImages'];
      setState(() {
        _gallery = rawGallery is List
            ? rawGallery.map((e) => e.toString()).toList()
            : [];
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
      appBar: AppBar(title: TfText(text.heroMediaTitle), centerTitle: false),
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

// ─── Connection URLs Page ─────────────────────────────────────────────────────

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
                    onPressed: _count > 1
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

class _StaffAccountsCard extends StatefulWidget {
  const _StaffAccountsCard({required this.app});

  final PosAppController app;

  @override
  State<_StaffAccountsCard> createState() => _StaffAccountsCardState();
}

class _StaffAccountsCardState extends State<_StaffAccountsCard> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  late Future<List<Map<String, Object?>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.app.loadStaffAccounts();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return TfCard(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: text.staffPhoneNumber,
              hintText: '01XXXXXXXXX',
              prefixIcon: Icon(Icons.phone_android_rounded),
            ),
          ),
          SizedBox(height: 10),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: text.nameOptional,
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          SizedBox(height: 12),
          PrimaryButton(
            label: text.addStaffPhone,
            icon: Icons.person_add_alt_1_rounded,
            busy: widget.app.busy,
            onPressed: widget.app.busy ? null : _add,
          ),
          SizedBox(height: 18),
          FutureBuilder<List<Map<String, Object?>>>(
            future: _future,
            builder: (context, snapshot) {
              final staff = snapshot.data ?? const <Map<String, Object?>>[];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (staff.isEmpty) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: TfText(text.noStaffYet)),
                );
              }
              return Column(
                children: staff
                    .map((account) {
                      final staffId = account['id']?.toString() ?? '';
                      final isActive = account['isActive'] != false;
                      final inviteStatus =
                          account['inviteStatus']?.toString() ?? '';
                      final statusLabel = inviteStatus == 'pending'
                          ? text.inviteStatusPending
                          : inviteStatus == 'declined'
                          ? text.inviteStatusDeclined
                          : isActive
                          ? text.activeStatus
                          : text.disabledStatus;
                      final statusColor = inviteStatus == 'pending'
                          ? PosColors.warning
                          : inviteStatus == 'declined' || !isActive
                          ? PosColors.muted
                          : PosColors.success;
                      final phone =
                          account['phone']?.toString() ??
                          account['email']?.toString() ??
                          '';
                      return ListTile(
                        leading: Icon(Icons.badge_rounded),
                        title: TfText(
                          account['displayName']?.toString().isNotEmpty == true
                              ? account['displayName'].toString()
                              : phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: TfText(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TfText(
                              statusLabel,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(width: 4),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: PosColors.danger,
                                size: 20,
                              ),
                              tooltip: text.deleteStaff,
                              onPressed: widget.app.busy
                                  ? null
                                  : () => _confirmDelete(
                                      context,
                                      staffId,
                                      account['phone']?.toString() ??
                                          account['email']?.toString() ??
                                          '',
                                    ),
                            ),
                          ],
                        ),
                      );
                    })
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _add() async {
    final text = AppScope.of(context).strings;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;
    final ok = await widget.app.addStaffPhone(
      phone,
      displayName: _nameController.text,
    );
    if (!mounted) return;
    if (ok) {
      _phoneController.clear();
      _nameController.clear();
      setState(() => _future = widget.app.loadStaffAccounts());
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: TfText(
          ok ? text.staffAdded : widget.app.lastError ?? 'Could not add staff.',
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String staffId,
    String email,
  ) async {
    final text = AppScope.of(context).strings;
    TfConfirmSheet.show(
      context,
      title: text.deleteStaff,
      description: '${text.deleteStaffConfirm}\n\n$email',
      confirmLabel: text.deleteStaff,
      isDanger: true,
      onConfirm: () async {
        if (!mounted) return;
        final ok = await widget.app.removeStaffAccount(staffId);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TfText(
              ok
                  ? text.staffRemoved
                  : widget.app.lastError ?? 'Could not remove staff.',
            ),
          ),
        );
        if (ok) setState(() => _future = widget.app.loadStaffAccounts());
      },
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
                              'Rastarant POS',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            TfText(
                              'Version 2.2.1 · by Terabyte AI',
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
                    'Rastarant POS is a modern, offline-first point-of-sale system '
                    'designed for Bangladeshi restaurants of every size. It combines '
                    'the reliability of local storage with the power of real-time cloud '
                    'sync, giving your team a single, fast control center for every '
                    'aspect of daily restaurant operations — from taking the first order '
                    'of the day to closing out the final shift.',
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
                  icon: Icons.wifi_off_rounded,
                  color: PosColors.warning,
                  title: 'Offline-First',
                  subtitle:
                      'Take orders, update menu, and manage staff even when the internet goes down. All data syncs automatically when connectivity is restored.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.cloud_sync_outlined,
                  color: PosColors.info,
                  title: 'Real-Time Cloud Sync',
                  subtitle:
                      'Orders and menu changes flow instantly to customer-facing web menus and other devices via secure Supabase Edge Functions.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.groups_2_outlined,
                  color: PosColors.success,
                  title: 'Manager & Staff Roles',
                  subtitle:
                      'Managers get full access to dashboard, reporting, and settings. Staff get a focused interface for placing and tracking orders.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.translate_rounded,
                  color: PosColors.accent,
                  title: 'Bilingual — বাংলা / English',
                  subtitle:
                      'Switch the entire app between Bangla and English at any time from the Language setting. Every screen, label, and notification respects your choice.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.print_outlined,
                  color: PosColors.purple,
                  title: 'Bluetooth Thermal Printing',
                  subtitle:
                      'Pair a Deli ES421 or compatible Bluetooth thermal printer to auto-print kitchen tickets for every new accepted order.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.qr_code_rounded,
                  color: PosColors.primary,
                  title: 'Table QR Codes',
                  subtitle:
                      'Generate a branded QR code PDF for each table. Customers scan to access the digital menu and place orders directly.',
                ),
                _divider(),
                _featureTile(
                  context,
                  icon: Icons.assessment_outlined,
                  color: PosColors.danger,
                  title: 'Sales Reports & Analytics',
                  subtitle:
                      'Track daily sales, top-selling items, shift performance, and service-mix trends with built-in reporting tools.',
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
                    'Set up your restaurant',
                    'A manager creates the restaurant profile and outlet identity on first launch. A private device token is generated and stored securely on the device.',
                  ),
                  const SizedBox(height: 12),
                  _stepRow(
                    context,
                    '2',
                    'Add your menu',
                    'Create categories and menu items with names, prices, photos, and availability flags. Changes sync to the cloud and the customer-facing web menu instantly.',
                  ),
                  const SizedBox(height: 12),
                  _stepRow(
                    context,
                    '3',
                    'Invite staff',
                    'Managers add staff by mobile number. Staff verify their phone and accept the invite on their own device.',
                  ),
                  const SizedBox(height: 12),
                  _stepRow(
                    context,
                    '4',
                    'Take orders & serve',
                    'Staff or managers create manual orders. Orders arrive on kitchen screens, get printed automatically, and move through Pending → Accepted → Served states.',
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
                  _techChip(context, 'Supabase'),
                  _techChip(context, 'SQLite (sqflite)'),
                  _techChip(context, 'Google Sign-In'),
                  _techChip(context, 'bKash Payment'),
                  _techChip(context, 'Bluetooth ESC/POS'),
                  _techChip(context, 'WebSocket'),
                  _techChip(context, 'PDF Generation'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Company & contact ───────────────────────────────────────────────
          _infoSectionHeader(context, Icons.business_rounded, 'Terabyte AI'),
          const SizedBox(height: 8),
          _settingsCard(
            child: Column(
              children: [
                _contactTile(
                  context,
                  icon: Icons.apartment_rounded,
                  label: 'Company',
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
              'Rastarant POS is a proprietary software product. '
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
              color: Colors.white,
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
                              'Last updated: January 1, 2026',
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
                    'Terabyte AI ("we", "us", or "our") built the Rastarant POS app. '
                    'This Privacy Policy explains how we collect, use, store, and protect '
                    'information when you use this application. By using the app, you agree '
                    'to the practices described in this policy.',
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
                    'When you sign in with Google, we receive your Google account email address and display name. This is used solely to authenticate your identity and link you to your restaurant account. We do not receive your Google password.',
                  ),
                  const SizedBox(height: 12),
                  _policySubheading(context, 'Restaurant & Operational Data'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'Orders, menu items, table configurations, staff accounts, and sales records are stored locally on the device using an encrypted SQLite database. When cloud sync is enabled, this data is also sent to your configured Supabase backend for cross-device visibility and backup.',
                  ),
                  const SizedBox(height: 12),
                  _policySubheading(context, 'Device & App Data'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'App preferences such as language, display size, and theme are stored only on the local device using Android SharedPreferences. We do not transmit these preferences to any server.',
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
              'To authenticate you and associate your session with the correct restaurant outlet.',
            ),
            _policyPoint(
              context,
              Icons.check_circle_outline_rounded,
              PosColors.success,
              'To sync your restaurant\'s menu, orders, and operational data across your manager and staff devices in real time.',
            ),
            _policyPoint(
              context,
              Icons.check_circle_outline_rounded,
              PosColors.success,
              'To send order notifications to the correct devices when new orders arrive or status changes occur.',
            ),
            _policyPoint(
              context,
              Icons.check_circle_outline_rounded,
              PosColors.success,
              'To generate sales reports and analytics for your restaurant management.',
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
              'We do NOT use your data for profiling, marketing, or any purpose beyond operating the POS system.',
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
                    'All operational data (orders, menu, inventory, notifications) is stored in a SQLite database on the device. The app is designed to function fully without internet access so your restaurant never stops serving customers.',
                  ),
                  const SizedBox(height: 12),
                  _policySubheading(context, 'Cloud Storage'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'When cloud sync is enabled, data is transmitted over HTTPS to your Supabase instance using device-specific private tokens. These tokens are generated once, stored securely on the device, and never exposed in the UI. Supabase enforces Row-Level Security (RLS) so each restaurant\'s data is isolated from others.',
                  ),
                  const SizedBox(height: 12),
                  _policySubheading(context, 'Secret Management'),
                  const SizedBox(height: 6),
                  _policyBody(
                    context,
                    'API keys and backend secrets are stored inside Supabase Edge Functions and are never transmitted to or stored in this app. Only your restaurant\'s private device token is kept on-device — and it is not visible in any settings screen.',
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
                      'Used for authentication only. Google may collect sign-in analytics per their own Privacy Policy at policies.google.com.',
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _thirdPartyTile(
                  context,
                  icon: Icons.payment_rounded,
                  name: 'bKash Payment Gateway',
                  description:
                      'Used for subscription checkout. Payment data is processed entirely by bKash. We do not store card or wallet credentials.',
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _thirdPartyTile(
                  context,
                  icon: Icons.cloud_outlined,
                  name: 'Supabase',
                  description:
                      'Used as the cloud database and realtime sync backend. Data at rest is encrypted. See supabase.com/privacy for their policy.',
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
              'Data deletion: You can clear all local cached data at any time from Settings → App Cache → Clear Data.',
            ),
            _policyPoint(
              context,
              Icons.logout_rounded,
              PosColors.warning,
              'Account removal: Contact support@terabyteai.com to request full deletion of your restaurant account and cloud data.',
            ),
            _policyPoint(
              context,
              Icons.visibility_off_outlined,
              PosColors.muted,
              'Cloud sync opt-out: You may disable cloud sync at any time. The app continues to work offline with local data only.',
            ),
            _policyPoint(
              context,
              Icons.download_outlined,
              PosColors.success,
              'Data export: Sales reports can be exported from the Reports section for your own records.',
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
                'Restaurant owners and operators are solely responsible for complying with applicable data protection, privacy, and consumer laws in their jurisdiction (including Bangladesh\'s Digital Security Act and any applicable GDPR-equivalent regulations). '
                'This includes obtaining necessary customer consent for data collection, displaying required privacy notices at the point of order, and retaining or deleting customer order data in accordance with local law. '
                'Terabyte AI provides the technical platform but does not act as a data controller for your customers\' personal information.',
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
                'This application is intended for use by restaurant operators, managers, and staff who are 18 years of age or older. We do not knowingly collect personal information from individuals under the age of 18. If you believe a minor has submitted information through this app, please contact us immediately.',
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
                'We may update this Privacy Policy from time to time. When we do, the "Last updated" date at the top of this page will be revised. For significant changes, we will provide an in-app notice. Continued use of the app after changes are posted constitutes acceptance of the updated policy.',
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
                    'If you have questions, concerns, or requests regarding this Privacy Policy or your personal data, please contact us:',
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
              'This Privacy Policy is effective as of January 1, 2026 and was last reviewed on May 20, 2026.',
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
