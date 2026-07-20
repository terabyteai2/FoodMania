import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../menu/menu_scan_screen.dart';

class TenantSetupScreen extends StatefulWidget {
  const TenantSetupScreen({required this.onProvisioned, super.key});

  final VoidCallback onProvisioned;

  @override
  State<TenantSetupScreen> createState() => _TenantSetupScreenState();
}

class _TenantSetupScreenState extends State<TenantSetupScreen> {
  static const int _totalSteps = 4;
  static const int _maxTableCount = 200;

  final _ownerCtrl = TextEditingController();
  final _restaurantCtrl = TextEditingController();
  final _tablesCtrl = TextEditingController();
  final _pageController = PageController();

  int _step = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ownerCtrl.addListener(_refresh);
    _restaurantCtrl.addListener(_refresh);
    _tablesCtrl.addListener(_refresh);
  }

  @override
  void dispose() {
    _ownerCtrl
      ..removeListener(_refresh)
      ..dispose();
    _restaurantCtrl
      ..removeListener(_refresh)
      ..dispose();
    _tablesCtrl
      ..removeListener(_refresh)
      ..dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  bool get _ownerReady => _ownerCtrl.text.trim().isNotEmpty;
  bool get _restaurantReady => _restaurantCtrl.text.trim().isNotEmpty;

  /// Parsed table count; null when the field is empty/invalid. 0 is a valid
  /// answer and means a counter-only outlet (no table map in the order flow).
  int? get _tableCount {
    final raw = _tablesCtrl.text.trim();
    if (raw.isEmpty) return null;
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed < 0 || parsed > _maxTableCount) return null;
    return parsed;
  }

  bool get _tablesReady => _tableCount != null;

  void _goTo(int step) {
    if (_busy || step < 0 || step >= _totalSteps) return;
    setState(() => _step = step);
    _pageController.jumpToPage(step);
  }

  Future<void> _finish() async {
    final tableCount = _tableCount;
    if (_busy || !_restaurantReady || !_ownerReady || tableCount == null) {
      return;
    }
    setState(() => _busy = true);
    final app = AppScope.of(context);
    try {
      await app.saveLocalSetup(
        restaurantName: _restaurantCtrl.text.trim(),
        managerName: _ownerCtrl.text.trim(),
        tableCount: tableCount,
      );
      if (!mounted) return;
      widget.onProvisioned();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scanNow() async {
    final app = AppScope.of(context);

    // Logged-in users already have a cloud token — scan directly.
    if (app.cloudConfig.canSync) {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MenuScanScreen()),
      );
      if (!mounted) return;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: TfText('Menu scanned! Items added to your menu.')),
        );
      }
      _finish();
      return;
    }

    // New tenant — no cloud token yet. Provision the tenant first, then let
    // MainShell pick up the pending flag and navigate to the scan screen.
    final restaurantName = _restaurantCtrl.text.trim();
    final managerName = _ownerCtrl.text.trim();
    final tableCount = _tableCount ?? 0;

    if (_busy || !_restaurantReady || tableCount <= 0) return;
    setState(() => _busy = true);

    app.pendingOnboardingMenuScan = true;

    try {
      final ok = await app.completeManagerPhoneSignup(
        restaurantName: restaurantName,
        managerName: managerName,
        tableCount: tableCount,
        outletName: restaurantName,
      );
      if (!ok) {
        app.pendingOnboardingMenuScan = false;
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TfText(
              app.lastError ?? 'Could not create restaurant.',
            ),
          ),
        );
        setState(() => _busy = false);
        return;
      }
    } catch (error) {
      app.pendingOnboardingMenuScan = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: TfText('$error')),
      );
      setState(() => _busy = false);
      return;
    }

    // Notify parent — TenantSetupScreen is replaced by MainShell,
    // which will pick up the pending flag and navigate to MenuScanScreen.
    widget.onProvisioned();
  }

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    height: 38,
                    child: _step > 0
                        ? TfIconButton(
                            icon: TfNavIcon.back,
                            tooltip: isBn ? 'পেছনে' : 'Back',
                            onPressed: () => _goTo(_step - 1),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TfText(
                      isBn
                          ? 'ধাপ ${tfToBnNumbers('${_step + 1}')} এর ${tfToBnNumbers('$_totalSteps')}'
                          : 'STEP ${_step + 1} OF $_totalSteps',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: PosColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: (_step + 1) / _totalSteps,
                  backgroundColor: PosColors.line,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    PosColors.primary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _SetupStep(
                    title: isBn ? 'আপনার নাম কী?' : 'What is your name?',
                    subtitle: isBn
                        ? 'এই নামটি মালিকের অ্যাকাউন্টে দেখানো হবে।'
                        : 'This will appear on the owner account.',
                    field: TfField(
                      label: 'Owner name',
                      labelBn: 'মালিকের নাম',
                      hint: 'e.g. Ahmed Rahman',
                      hintBn: 'যেমন আহমেদ রহমান',
                      controller: _ownerCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        if (_ownerReady) _goTo(1);
                      },
                    ),
                    cta: TfButton(
                      label: 'Continue',
                      labelBn: 'চালিয়ে যান',
                      trailingIcon: TfNavIcon.arrow,
                      onPressed: _ownerReady ? () => _goTo(1) : null,
                    ),
                  ),
                  _SetupStep(
                    title: isBn
                        ? 'রেস্টুরেন্টের নাম দিন'
                        : 'Name your restaurant',
                    subtitle: isBn
                        ? 'এই নামটি POS, রসিদ এবং কাস্টমার মেনুতে ব্যবহৃত হবে।'
                        : 'This name appears in POS, receipts, and the customer menu.',
                    field: TfField(
                      label: 'Restaurant name',
                      labelBn: 'রেস্টুরেন্টের নাম',
                      hint: 'e.g. Terafoods Cafe',
                      hintBn: 'যেমন টেরাফুডস ক্যাফে',
                      controller: _restaurantCtrl,
                      autofocus: true,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        if (_restaurantReady) _goTo(2);
                      },
                    ),
                    cta: TfButton(
                      label: 'Continue',
                      labelBn: 'চালিয়ে যান',
                      trailingIcon: TfNavIcon.arrow,
                      onPressed: _restaurantReady ? () => _goTo(2) : null,
                    ),
                  ),
                  _SetupStep(
                    title: isBn ? 'কয়টি টেবিল আছে?' : 'How many tables?',
                    subtitle: isBn
                        ? 'কাউন্টার-শুধু সার্ভিসের জন্য ০ লিখুন — অর্ডার নেওয়ার সময় টেবিল বাছাই থাকবে না।'
                        : 'Enter 0 for counter-only service — ordering skips the table picker.',
                    field: TfField(
                      label: 'Number of tables',
                      labelBn: 'টেবিলের সংখ্যা',
                      hint: 'e.g. 12',
                      hintBn: 'যেমন ১২',
                      controller: _tablesCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) {
                        if (_tablesReady) _goTo(3);
                      },
                    ),
                    cta: TfButton(
                      label: 'Continue',
                      labelBn: 'চালিয়ে যান',
                      trailingIcon: TfNavIcon.arrow,
                      onPressed: _tablesReady ? () => _goTo(3) : null,
                    ),
                  ),
                  _ScanPromptStep(
                    onScanNow: _scanNow,
                    onSkip: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanPromptStep extends StatelessWidget {
  const _ScanPromptStep({
    required this.onScanNow,
    required this.onSkip,
  });

  final VoidCallback onScanNow;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 24),
      children: [
        TfText(
          isBn ? 'আপনার মেনু কার্ড স্ক্যান করুন?' : 'Scan your menu card?',
          style: TextStyle(
            fontFamily: tfFontFamily(context),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: PosColors.slate,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        TfText(
          isBn
              ? 'AI আপনার ফিজিক্যাল মেনু পড়ে আইটেমগুলি স্বয়ংক্রিয়ভাবে যোগ করুক।'
              : 'Let AI read your physical menu and add items automatically.',
          style: const TextStyle(
            fontSize: 15,
            color: PosColors.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: PosColors.primarySoft,
              borderRadius: BorderRadius.circular(PosRadii.xl),
            ),
            child: const Icon(
              Icons.document_scanner_outlined,
              size: 48,
              color: PosColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 40),
        TfButton(
          label: 'Scan Now',
          labelBn: 'এখন স্ক্যান করুন',
          trailingIcon: TfNavIcon.arrow,
          onPressed: onScanNow,
        ),
        const SizedBox(height: 12),
        TfButton(
          label: "I'll do this later",
          labelBn: 'পরে করব',
          variant: TfButtonVariant.ghost,
          fullWidth: true,
          onPressed: onSkip,
        ),
      ],
    );
  }
}

class _SetupStep extends StatelessWidget {
  const _SetupStep({
    required this.title,
    required this.subtitle,
    required this.field,
    required this.cta,
  });

  final String title;
  final String subtitle;
  final Widget field;
  final Widget cta;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 54, 20, 24),
      children: [
        TfText(
          title,
          style: TextStyle(
            fontFamily: tfFontFamily(context),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: PosColors.slate,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 10),
        TfText(
          subtitle,
          style: const TextStyle(
            fontSize: 15,
            color: PosColors.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 30),
        field,
        const SizedBox(height: 14),
        cta,
      ],
    );
  }
}
