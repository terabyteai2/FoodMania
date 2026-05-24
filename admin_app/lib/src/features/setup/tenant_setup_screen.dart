import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../services/cloud_api_service.dart';
import '../../services/menu_image_service.dart';
import '../../services/printer_service.dart';

// 4-step onboarding wizard (Basics → Menu → Printer → Online page → Done).
//
// Provisioning (`saveLocalSetup`) is deferred until the user finishes the
// wizard. The reason: the parent shell unmounts this screen the moment
// `isLoggedIn` flips, so any provisioning mid-flow would tear down later
// steps. We hold the basics in memory and only call saveLocalSetup +
// onProvisioned at the end (or when the user chooses an "I'll set this up
// now" shortcut on steps 2-4, which finishes the wizard and lands them on
// the relevant tab via [pendingOnboardingLanding]).
class TenantSetupScreen extends StatefulWidget {
  const TenantSetupScreen({required this.onProvisioned, super.key});

  final VoidCallback onProvisioned;

  @override
  State<TenantSetupScreen> createState() => _TenantSetupScreenState();
}

class _TenantSetupScreenState extends State<TenantSetupScreen> {
  static const int _totalSteps = 4;
  static const int _defaultTableCount = 10;

  final _restaurantCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _pageController = PageController();
  final MenuImageService _menuImageService = MenuImageService();

  int _step = 0; // 0..3 = wizard pages, 4 = Done.
  bool _busy = false;
  bool _menuScanBusy = false;
  String? _menuScanError;
  List<PickedMenuScanPage> _pendingMenuScanPages = const [];
  String? _pendingPublicSlug;

  @override
  void initState() {
    super.initState();
    _restaurantCtrl.addListener(() => setState(() {}));
    _ownerCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _restaurantCtrl.dispose();
    _ownerCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  bool get _basicsReady =>
      _restaurantCtrl.text.trim().isNotEmpty &&
      _ownerCtrl.text.trim().isNotEmpty;

  void _goTo(int step) {
    if (_busy) return;
    if (step < 0 || step > _totalSteps) return;
    setState(() => _step = step);
    if (step < _totalSteps) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_step == 0) return;
    _goTo(_step - 1);
  }

  // Final commit. Provisions the tenant then dismisses.
  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final app = AppScope.of(context);
    try {
      final restaurant = _restaurantCtrl.text.trim();
      final owner = _ownerCtrl.text.trim();
      if (owner.isNotEmpty) app.accountDisplayName = owner;
      await app.saveLocalSetup(
        restaurantName: restaurant,
        tableCount: _defaultTableCount,
      );
      final slug = _pendingPublicSlug?.trim();
      if (slug != null && slug.isNotEmpty) {
        await app.saveLocalPublicSlug(slug);
        if (app.cloudConfig.canSync) {
          await app.updatePublicMenuUrl(slug);
        }
      }
      await _importPendingMenuScan(app);
      if (!mounted) return;
      widget.onProvisioned();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureMenuScan({required bool fromCamera}) async {
    if (_menuScanBusy) return;
    setState(() {
      _menuScanBusy = true;
      _menuScanError = null;
    });
    try {
      final pages = <PickedMenuScanPage>[];
      if (fromCamera) {
        final page = await _menuImageService.captureMenuScanPage(
          pageNumber: _pendingMenuScanPages.length + 1,
        );
        if (page != null) pages.add(page);
      } else {
        pages.addAll(await _menuImageService.pickMenuScanPages());
      }
      if (pages.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _pendingMenuScanPages = [..._pendingMenuScanPages, ...pages];
      });
    } on MenuImageException catch (error) {
      if (!mounted) return;
      setState(() => _menuScanError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _menuScanError = error.toString());
    } finally {
      if (mounted) setState(() => _menuScanBusy = false);
    }
  }

  Future<void> _importPendingMenuScan(PosAppController app) async {
    final pages = _pendingMenuScanPages;
    if (pages.isEmpty || !app.cloudConfig.canSync) return;
    try {
      await app.scanAndImportMenu(
        pages
            .map(
              (page) => MenuScanPageUpload(
                bytes: page.bytes,
                fileName: page.fileName,
                mimeType: page.mimeType,
              ),
            )
            .toList(growable: false),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  Future<void> _searchPrinters() async {
    final app = AppScope.of(context);
    final text = app.strings;
    final printers = await app.refreshPairedPrinters();
    if (!mounted) return;
    if (printers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: TfText(            app.printerState.lastError ?? text.noPairedPrintersFound,
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrinterSearchSheet(
        printers: printers,
        onConnect: (printer) async {
          final ok = await app.connectPrinter(printer);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: TfText(                ok
                    ? text.connectedTo(printer.label)
                    : app.printerState.lastError ??
                          text.printerConnectionFailed,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final isBn = text.isBn;
    final identityLine = _identityLine();

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              step: _step,
              totalSteps: _totalSteps,
              onBack: _step > 0 && _step < _totalSteps ? _back : null,
              showSkip: _step >= 1 && _step < _totalSteps,
              onSkip: () => _goTo(_step + 1),
              isBn: isBn,
            ),
            _ProgressBar(step: _step, total: _totalSteps),
            Expanded(
              child: _step == _totalSteps
                  ? _DoneStep(
                      restaurant: _restaurantCtrl.text.trim(),
                      owner: _ownerCtrl.text.trim(),
                      busy: _busy,
                      onOpen: _finish,
                      isBn: isBn,
                    )
                  : PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _BasicsStep(
                          restaurantCtrl: _restaurantCtrl,
                          ownerCtrl: _ownerCtrl,
                          identityLine: identityLine,
                          isBn: isBn,
                          canContinue: _basicsReady,
                          onContinue: _basicsReady ? () => _goTo(1) : null,
                        ),
                        _MenuPitchStep(
                          isBn: isBn,
                          busy: _menuScanBusy,
                          capturedCount: _pendingMenuScanPages.length,
                          error: _menuScanError,
                          onCapture: () => _captureMenuScan(fromCamera: true),
                          onUpload: () => _captureMenuScan(fromCamera: false),
                          onContinue: () => _goTo(2),
                        ),
                        _PrinterPitchStep(
                          isBn: isBn,
                          onSearchPrinters: _searchPrinters,
                          onContinue: () => _goTo(3),
                        ),
                        _OnlinePageStep(
                          restaurantName: _restaurantCtrl.text.trim(),
                          isBn: isBn,
                          onContinue: (slug) {
                            _pendingPublicSlug = slug;
                            _goTo(4);
                          },
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String? _identityLine() {
    final app = AppScope.of(context);
    final phone = app.verifiedPhoneDisplay;
    final email = app.accountEmail.isEmpty ? null : app.accountEmail;
    return phone ?? email;
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.totalSteps,
    required this.onBack,
    required this.showSkip,
    required this.onSkip,
    required this.isBn,
  });

  final int step;
  final int totalSteps;
  final VoidCallback? onBack;
  final bool showSkip;
  final VoidCallback onSkip;
  final bool isBn;

  @override
  Widget build(BuildContext context) {
    final stepLabel = step >= totalSteps
        ? (isBn ? 'সম্পন্ন' : 'COMPLETE')
        : '${isBn ? "ধাপ" : "STEP"} ${step + 1} ${isBn ? "এর" : "OF"} $totalSteps';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Row(
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: onBack != null
                ? TfIconButton(
                    icon: TfNavIcon.back,
                    tooltip: isBn ? 'পেছনে' : 'Back',
                    onPressed: onBack,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TfText(
              stepLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: PosColors.muted,
              ),
            ),
          ),
          if (showSkip)
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onSkip,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: TfText(
                  isBn ? 'এড়িয়ে যান' : 'Skip',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PosColors.muted,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                height: 4,
                decoration: BoxDecoration(
                  color: i < step.clamp(0, total)
                      ? PosColors.primary
                      : PosColors.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (i < total - 1) const SizedBox(width: 5),
          ],
        ],
      ),
    );
  }
}

// ── Step 1: Basics (restaurant + owner) ───────────────────────────────────

class _BasicsStep extends StatelessWidget {
  const _BasicsStep({
    required this.restaurantCtrl,
    required this.ownerCtrl,
    required this.identityLine,
    required this.isBn,
    required this.canContinue,
    required this.onContinue,
  });

  final TextEditingController restaurantCtrl;
  final TextEditingController ownerCtrl;
  final String? identityLine;
  final bool isBn;
  final bool canContinue;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (identityLine != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: PosColors.line, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 14,
                          color: PosColors.muted,
                        ),
                        const SizedBox(width: 8),
                        TfText(                          identityLine!,
                          style: TextStyle(
                            fontFamily: tfFontFamily(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: PosColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                TfText(
                  isBn
                      ? 'আপনার রেস্টুরেন্ট সম্পর্কে বলুন'
                      : "Tell us about your restaurant",
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                TfText(
                  isBn
                      ? 'এক মিনিটেরও কম সময়ে শুরু করুন।'
                      : "We'll get you running in under a minute.",
                  style: const TextStyle(
                    fontSize: 14,
                    color: PosColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 26),
                TfField(
                  label: isBn ? 'রেস্টুরেন্টের নাম' : 'Restaurant name',
                  hint: isBn ? 'যেমন: স্পাইস গার্ডেন' : 'e.g. Spice Garden',
                  controller: restaurantCtrl,
                  autofocus: true,
                  hintHelper: isBn
                      ? 'রিসিপ্ট, অনলাইন পেজ ও প্রিন্টারে এই নামটি দেখাবে।'
                      : 'Shown on receipts, your online page, and the printer.',
                ),
                TfField(
                  label: isBn ? 'মালিকের নাম' : 'Your name',
                  hint: isBn ? 'যেমন: করিম হোসেন' : 'e.g. Karim Hossain',
                  controller: ownerCtrl,
                  hintHelper: isBn
                      ? 'অভিবাদন এবং শিফট ট্র্যাকিংয়ে দেখাবে।'
                      : 'Used for greetings and shift handoffs.',
                ),
              ],
            ),
          ),
        ),
        TfStickyCTA(
          child: TfButton(
            label: isBn ? 'চালিয়ে যান' : 'Continue',
            trailingIcon: TfNavIcon.arrow,
            size: TfButtonSize.lg,
            onPressed: onContinue,
          ),
        ),
      ],
    );
  }
}

// ── Step 2: Menu pitch ────────────────────────────────────────────────────

class _MenuPitchStep extends StatelessWidget {
  const _MenuPitchStep({
    required this.isBn,
    required this.busy,
    required this.capturedCount,
    required this.error,
    required this.onCapture,
    required this.onUpload,
    required this.onContinue,
  });
  final bool isBn;
  final bool busy;
  final int capturedCount;
  final String? error;
  final VoidCallback onCapture;
  final VoidCallback onUpload;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  isBn ? 'আপনার মেনু যোগ করুন' : 'Add your menu',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                TfText(
                  isBn
                      ? 'মুদ্রিত মেনু ছবি তুলুন — আমরা টাইপ করে দেব।'
                      : "Snap a photo of your printed menu — we'll do the typing.",
                  style: const TextStyle(
                    fontSize: 14,
                    color: PosColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                // Hero dark card.
                Container(
                  decoration: BoxDecoration(
                    color: PosColors.primaryDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: PosColors.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              TfNavIcon.sparkle,
                              size: 13,
                              color: PosColors.primaryDark,
                            ),
                            const SizedBox(width: 6),
                            TfText(
                              isBn ? 'AI · ৩০ সেকেন্ড' : 'AI · 30 sec',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: PosColors.primaryDark,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TfText(
                        isBn
                            ? 'আপনার মুদ্রিত মেনু স্ক্যান করুন'
                            : 'Scan your printed menu',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TfText(
                        isBn
                            ? 'আইটেম, দাম ও ক্যাটাগরি অটো-পূরণ হবে। সেভ করার আগে রিভিউ করতে পারবেন।'
                            : 'Items, prices and categories — auto-filled. You can review before saving.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TfButton(
                              label: isBn ? 'ক্যামেরা খুলুন' : 'Open camera',
                              icon: TfNavIcon.camera,
                              size: TfButtonSize.md,
                              onPressed: busy ? null : onCapture,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TfButton(
                              label: isBn ? 'আপলোড' : 'Upload',
                              variant: TfButtonVariant.paper,
                              size: TfButtonSize.md,
                              onPressed: busy ? null : onUpload,
                            ),
                          ),
                        ],
                      ),
                      if (busy || capturedCount > 0 || error != null) ...[
                        const SizedBox(height: 12),
                        TfText(
                          busy
                              ? (isBn ? 'ক্যামেরা খুলছে…' : 'Opening scanner…')
                              : error != null
                              ? error!
                              : (isBn
                                    ? '$capturedCount পেজ প্রস্তুত — শেষে ইমপোর্ট হবে।'
                                    : '$capturedCount page ready — it will import after setup.'),
                          style: TextStyle(
                            fontSize: 12,
                            color: error == null
                                ? Colors.white.withValues(alpha: 0.72)
                                : PosColors.primary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Manual fallback row.
                Material(
                  color: PosColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onContinue,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PosColors.line, width: 0.5),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: PosColors.background,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              TfNavIcon.plus,
                              size: 18,
                              color: PosColors.slate,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TfText(
                                  isBn
                                      ? 'ম্যানুয়ালি আইটেম যোগ করুন'
                                      : 'Add items manually',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: PosColors.slate,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                TfText(
                                  isBn
                                      ? '৮-এর কম আইটেমের জন্য দ্রুততম'
                                      : 'Fastest for fewer than 8 items',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: PosColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            TfNavIcon.chevron,
                            size: 18,
                            color: PosColors.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        TfStickyCTA(
          child: TfButton(
            label: isBn ? 'চালিয়ে যান' : 'Continue',
            trailingIcon: TfNavIcon.arrow,
            size: TfButtonSize.lg,
            onPressed: onContinue,
          ),
        ),
      ],
    );
  }
}

// ── Step 3: Printer pitch ─────────────────────────────────────────────────

class _PrinterPitchStep extends StatelessWidget {
  const _PrinterPitchStep({
    required this.isBn,
    required this.onSearchPrinters,
    required this.onContinue,
  });
  final bool isBn;
  final VoidCallback onSearchPrinters;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final checklist = isBn
        ? const [
            'প্রিন্টার চালু করুন',
            'ব্লুটুথ চালু আছে নিশ্চিত করুন',
            'প্রিন্টার ২ মিটারের মধ্যে রাখুন',
          ]
        : const [
            'Turn on the printer',
            'Make sure Bluetooth is on',
            'Keep it within 2 metres',
          ];
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  isBn ? 'প্রিন্টার যুক্ত করুন' : 'Pair your printer',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                TfText(
                  isBn
                      ? 'রান্নাঘরের টিকেট ও কাস্টমার রিসিপ্টের জন্য ব্লুটুথ থার্মাল প্রিন্টার যুক্ত করুন।'
                      : 'Connect a Bluetooth thermal printer for kitchen tickets and customer receipts.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: PosColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // Illustration medallion.
                Center(
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: PosColors.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      TfNavIcon.printer,
                      size: 44,
                      color: PosColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: PosColors.primaryWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TfText(
                        isBn ? 'শুরু করার আগে' : 'Before you start',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: PosColors.slate,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final item in checklist)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: PosColors.primary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 11,
                                  color: PosColors.primaryDark,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TfText(
                                  item,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: PosColors.slate,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        TfStickyCTA(
          helper: isBn
              ? 'প্রিন্টার নেই? সেটিংস থেকে পরে যুক্ত করতে পারবেন।'
              : "Don't have a printer? You can pair one later from Settings.",
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TfButton(
                label: isBn ? 'প্রিন্টার খুঁজুন' : 'Search printers',
                icon: TfNavIcon.bluetooth,
                size: TfButtonSize.lg,
                onPressed: onSearchPrinters,
              ),
              const SizedBox(height: 8),
              TfButton(
                label: isBn ? 'পরে যুক্ত করব' : "I'll set this up later",
                variant: TfButtonVariant.paper,
                trailingIcon: TfNavIcon.arrow,
                size: TfButtonSize.md,
                onPressed: onContinue,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrinterSearchSheet extends StatelessWidget {
  const _PrinterSearchSheet({required this.printers, required this.onConnect});

  final List<BluetoothPrinterDevice> printers;
  final Future<void> Function(BluetoothPrinterDevice printer) onConnect;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottom),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PosColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TfText(
            text.refreshPairedPrinters,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: PosColors.slate,
            ),
          ),
          const SizedBox(height: 12),
          for (final printer in printers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TfCard(
                child: Row(
                  children: [
                    const Icon(
                      TfNavIcon.printer,
                      size: 20,
                      color: PosColors.slate,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TfText(                            printer.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: PosColors.slate,
                            ),
                          ),
                          const SizedBox(height: 2),
                          TfText(                            printer.address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: PosColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    TfButton(
                      label: text.isBn ? 'যুক্ত করুন' : 'Connect',
                      size: TfButtonSize.sm,
                      fullWidth: false,
                      onPressed: () async {
                        await onConnect(printer);
                        if (context.mounted) Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Step 4: Online page ───────────────────────────────────────────────────

class _OnlinePageStep extends StatelessWidget {
  const _OnlinePageStep({
    required this.restaurantName,
    required this.isBn,
    required this.onContinue,
  });

  final String restaurantName;
  final bool isBn;
  final ValueChanged<String> onContinue;

  String get _slug {
    final lowered = restaurantName.toLowerCase().trim();
    if (lowered.isEmpty) return 'your-restaurant';
    final slug = lowered
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? 'your-restaurant' : slug;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  (isBn ? 'ঐচ্ছিক' : 'OPTIONAL').toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: PosColors.muted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                TfText(
                  isBn ? 'ফ্রি অনলাইন পেজ পান' : 'Get a free online page',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                TfText(
                  isBn
                      ? 'কাস্টমাররা স্ক্যান করে বা লিংক দিয়ে আপনার মেনু দেখতে পারবেন।'
                      : 'Customers can scan a QR or open this link to see your menu.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: PosColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                // URL preview chip.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: PosColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PosColors.line, width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.link_rounded,
                        size: 16,
                        color: PosColors.muted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontFamily: 'JetBrains Mono',
                              fontSize: 13,
                              color: PosColors.muted,
                            ),
                            children: [
                              const TextSpan(text: 'terafoods.app/'),
                              TextSpan(
                                text: _slug,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: PosColors.slate,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TfText(
                  (isBn ? 'ছবি · সর্বোচ্চ ৬টি' : 'PHOTOS · UP TO 6')
                      .toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: PosColors.muted,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 6,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (_, _) => Container(
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: PosColors.line,
                        width: 0.5,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        TfNavIcon.plus,
                        size: 20,
                        color: PosColors.muted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        TfStickyCTA(
          child: TfButton(
            label: isBn ? 'আমার পেজ প্রকাশ করুন' : 'Publish my page',
            trailingIcon: TfNavIcon.arrow,
            size: TfButtonSize.lg,
            onPressed: () => onContinue(_slug),
          ),
        ),
      ],
    );
  }
}

// ── Done step ─────────────────────────────────────────────────────────────

class _DoneStep extends StatelessWidget {
  const _DoneStep({
    required this.restaurant,
    required this.owner,
    required this.busy,
    required this.onOpen,
    required this.isBn,
  });

  final String restaurant;
  final String owner;
  final bool busy;
  final VoidCallback onOpen;
  final bool isBn;

  @override
  Widget build(BuildContext context) {
    final firstName = owner.split(' ').first.trim().isEmpty
        ? owner
        : owner.split(' ').first;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            child: Column(
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: PosColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 44,
                    color: PosColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 22),
                TfText(
                  isBn
                      ? '${firstName.isEmpty ? "আপনি" : firstName}, সব প্রস্তুত'
                      : "You're all set${firstName.isEmpty ? "" : ", $firstName"}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                TfText(
                  isBn
                      ? '${restaurant.isEmpty ? "আপনার রেস্টুরেন্ট" : restaurant} অর্ডার নিতে প্রস্তুত।'
                      : '${restaurant.isEmpty ? "Your restaurant" : restaurant} is ready to take orders.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: PosColors.muted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                _SummaryRow(
                  icon: TfNavIcon.menu,
                  title: isBn ? 'মেনু' : 'Menu',
                  subtitle: isBn
                      ? 'মেনু ট্যাব থেকে যেকোনো সময় যোগ করুন'
                      : 'Add items any time from the Menu tab',
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  icon: TfNavIcon.printer,
                  title: isBn ? 'প্রিন্টার' : 'Printer',
                  subtitle: isBn
                      ? 'সেটিংস থেকে যুক্ত করুন'
                      : 'Pair from Settings → Printer',
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  icon: TfNavIcon.wifi,
                  title: isBn ? 'অনলাইন পেজ' : 'Online page',
                  subtitle:
                      'terafoods.app/${restaurant.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
                ),
              ],
            ),
          ),
        ),
        TfStickyCTA(
          child: TfButton(
            label: busy
                ? (isBn ? 'সেট আপ হচ্ছে…' : 'Setting up…')
                : (isBn ? 'ড্যাশবোর্ড খুলুন' : 'Open dashboard'),
            trailingIcon: busy ? null : TfNavIcon.arrow,
            size: TfButtonSize.lg,
            onPressed: busy ? null : onOpen,
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PosColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: PosColors.slate),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                  ),
                ),
                const SizedBox(height: 2),
                TfText(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: PosColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
