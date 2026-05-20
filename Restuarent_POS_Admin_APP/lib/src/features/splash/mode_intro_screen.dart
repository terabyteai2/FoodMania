import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/constants/cloud_defaults.dart';
import '../../core/constants/payment_defaults.dart';
import '../../models/account_role.dart';
import '../payments/subscription_checkout_flow.dart';

class ModeIntroScreen extends StatefulWidget {
  const ModeIntroScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<ModeIntroScreen> createState() => _ModeIntroScreenState();
}

enum _AuthMode { choose, manager, payment, login, staff, heroMedia }

// How the manager wants to authenticate after the demo-payment step. We
// gate Google through the same payment screen as password so the
// subscription-fee step is always visible to the manager.
enum _AuthIntent { password, google }

class _ModeIntroScreenState extends State<ModeIntroScreen> {
  final _restaurantCtrl = TextEditingController();
  final _outletCtrl = TextEditingController(text: 'Main Outlet');
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _staffCloudApiUrlCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  _AuthMode _mode = _AuthMode.choose;
  _AuthIntent _authIntent = _AuthIntent.password;
  _DemoPlan _plan = _DemoPlan.monthly;
  String? _error;
  // Hero media state — collected after manager signup succeeds.
  String? _heroVideoName;
  List<int>? _heroVideoBytes;
  final List<String> _heroImageDataUrls = [];
  bool _heroBusy = false;
  String? _heroStatus;

  @override
  void dispose() {
    _restaurantCtrl.dispose();
    _outletCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _staffCloudApiUrlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    // If a manager just finished signup the parent shell pins this screen on
    // top until the hero-media step is done — force the hero-media view in
    // that case regardless of the local _mode.
    final activeMode = app.pendingHeroMediaSetup ? _AuthMode.heroMedia : _mode;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: switch (activeMode) {
                _AuthMode.choose => _heroView(app),
                _AuthMode.manager => _managerForm(app),
                _AuthMode.payment => _paymentDemo(app),
                _AuthMode.login => _loginForm(app),
                _AuthMode.staff => _staffGoogle(app),
                _AuthMode.heroMedia => _heroMediaForm(app),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _heroView(PosAppController app) {
    return _ScreenBody(
      key: const ValueKey('hero'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 58),
          const _BrandMark(icon: Icons.restaurant_menu_rounded),
          const SizedBox(height: 40),
          const Text('Welcome to\nTerafoods.', style: _kTitleStyle),
          const SizedBox(height: 24),
          const Text(
            'Take orders, track sales, manage your\nmenu — all from your phone.',
            style: _kBodyStyle,
          ),
          const SizedBox(height: 14),
          const Text(
            'রেস্টুরেন্ট চালান আপনার মোবাইল থেকেই।',
            style: _kMutedBnStyle,
          ),
          const Spacer(),
          _YellowButton(
            label: 'Create restaurant',
            icon: Icons.storefront_outlined,
            busy: app.busy,
            onPressed: () => _go(_AuthMode.manager),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _OutlineActionButton(
                  label: 'Log in',
                  iconText: '→',
                  onPressed: () => _go(_AuthMode.login),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OutlineActionButton(
                  label: 'Staff',
                  iconText: 'G',
                  onPressed: () => _go(_AuthMode.staff),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _managerForm(PosAppController app) {
    return _ScreenBody(
      key: const ValueKey('manager'),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              _BackButton(
                onPressed: app.busy ? null : () => _go(_AuthMode.choose),
              ),
              const SizedBox(width: 14),
              const Text('Step 1 of 2', style: _kSmallStyle),
            ],
          ),
          const SizedBox(height: 14),
          const _StepProgress(activeStep: 1),
          const SizedBox(height: 24),
          const Text('Create your\nmanager account', style: _kFormTitleStyle),
          const SizedBox(height: 8),
          const Text(
            "You'll be the admin for this restaurant.",
            style: _kSmallBodyStyle,
          ),
          const SizedBox(height: 26),
          _LabeledField(
            label: 'Restaurant name',
            controller: _restaurantCtrl,
            hintText: 'e.g. Spice Garden',
            icon: Icons.storefront_outlined,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          _LabeledField(
            label: 'Outlet / branch',
            controller: _outletCtrl,
            hintText: 'Main Outlet',
            icon: Icons.location_on_outlined,
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          _LabeledField(
            label: 'Email',
            controller: _emailCtrl,
            hintText: 'manager@restaurant.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _LabeledField(
            label: 'Password',
            controller: _passwordCtrl,
            hintText: 'At least 8 characters',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
          if (_error != null) _InlineError(message: _error!),
          const SizedBox(height: 22),
          _YellowButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            busy: app.busy,
            onPressed: app.busy
                ? null
                : () => _validateManagerStep(_AuthIntent.password),
          ),
          const SizedBox(height: 14),
          const _OrDivider(),
          const SizedBox(height: 10),
          _WhiteButton(
            label: 'Continue with Google',
            iconText: 'G',
            busy: app.busy,
            onPressed: app.busy
                ? null
                : () => _validateManagerStep(_AuthIntent.google),
          ),
        ],
      ),
    );
  }

  Widget _paymentDemo(PosAppController app) {
    return _ScreenBody(
      key: const ValueKey('payment'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Row(
            children: [
              _BackButton(
                onPressed: app.busy ? null : () => _go(_AuthMode.manager),
              ),
              const SizedBox(width: 14),
              const Text('Step 2 of 2', style: _kSmallStyle),
            ],
          ),
          const SizedBox(height: 14),
          const _StepProgress(activeStep: 2),
          const SizedBox(height: 34),
          const _BrandMark(icon: Icons.payments_outlined),
          const SizedBox(height: 30),
          const Text('Subscription payment', style: _kFormTitleStyle),
          const SizedBox(height: 16),
          const Text(
            'Choose a plan, then pay securely (bKash, Nagad, etc.) to activate your restaurant.',
            style: _kBodyStyle,
          ),
          const SizedBox(height: 20),
          _PlanTile(
            title: 'Monthly',
            amount: '৳${PaymentDefaults.monthlyPlanAmount.toStringAsFixed(0)}',
            selected: _plan == _DemoPlan.monthly,
            onTap: () => setState(() => _plan = _DemoPlan.monthly),
          ),
          const SizedBox(height: 10),
          _PlanTile(
            title: 'Annual',
            amount: '৳${PaymentDefaults.annualPlanAmount.toStringAsFixed(0)}',
            selected: _plan == _DemoPlan.annual,
            onTap: () => setState(() => _plan = _DemoPlan.annual),
          ),
          if (_error != null) _InlineError(message: _error!),
          const Spacer(),
          _YellowButton(
            label: _authIntent == _AuthIntent.google
                ? 'Pay & continue with Google'
                : 'Pay & create restaurant',
            icon: _authIntent == _AuthIntent.google
                ? null
                : Icons.arrow_forward_rounded,
            iconText: _authIntent == _AuthIntent.google ? 'G' : null,
            busy: app.busy,
            onPressed: app.busy
                ? null
                : () => _completeDemoPayment(context, app),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDemoPayment(
    BuildContext context,
    PosAppController app,
  ) async {
    setState(() {
      _error = null;
    });
    final paid = await SubscriptionCheckoutFlow.run(
      context,
      amount: _plan.amount,
      plan: _plan.name,
      email: _emailCtrl.text.trim(),
      fullName: _restaurantCtrl.text.trim(),
    );
    if (!paid || !mounted) return;
    if (_authIntent == _AuthIntent.google) {
      await _google(app, AccountRole.manager);
    } else {
      await _createManager(app);
    }
  }

  Widget _loginForm(PosAppController app) {
    return _ScreenBody(
      key: const ValueKey('login'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _BackButton(onPressed: app.busy ? null : () => _go(_AuthMode.choose)),
          const SizedBox(height: 64),
          const Text('Welcome back', style: _kFormTitleStyle),
          const SizedBox(height: 14),
          const Text(
            'Log in to your manager or staff account.',
            style: _kBodyStyle,
          ),
          const SizedBox(height: 22),
          _BareField(
            controller: _emailCtrl,
            hintText: 'Email',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 10),
          _BareField(
            controller: _passwordCtrl,
            hintText: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Forgot password?', style: _kTinyStyle),
            ),
          ),
          if (_error != null) _InlineError(message: _error!),
          const SizedBox(height: 14),
          _YellowButton(
            label: 'Log in',
            icon: Icons.arrow_forward_rounded,
            busy: app.busy,
            onPressed: app.busy ? null : () => _passwordLogin(app),
          ),
          const SizedBox(height: 14),
          const _OrDivider(),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Sign in with Google',
              style: _kSmallStyle,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _OutlineActionButton(
                  label: 'Manager',
                  iconText: 'G',
                  onPressed: app.busy
                      ? () {}
                      : () => _googleLoginReturning(app, AccountRole.manager),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OutlineActionButton(
                  label: 'Staff',
                  iconText: 'G',
                  onPressed: app.busy ? () {} : () => _go(_AuthMode.staff),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _staffGoogle(PosAppController app) {
    return _ScreenBody(
      key: const ValueKey('staff'),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _BackButton(onPressed: app.busy ? null : () => _go(_AuthMode.choose)),
          const Spacer(),
          const Center(
            child: _BrandMark(icon: Icons.sentiment_satisfied_alt_rounded),
          ),
          const SizedBox(height: 34),
          const Center(child: Text('Staff sign-in', style: _kStaffTitleStyle)),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Use the Google email your manager\nadded to staff list. No password needed.',
              textAlign: TextAlign.center,
              style: _kBodyStyle,
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'ম্যানেজারের দেয়া স্টাফ ইমেইল ব্যবহার করুন',
              textAlign: TextAlign.center,
              style: _kMutedBnStyle,
            ),
          ),
          const SizedBox(height: 20),
          _LabeledField(
            label: 'Restaurant server URL',
            controller: _staffCloudApiUrlCtrl,
            hintText: CloudDefaults.defaultPublicApiBase,
            icon: Icons.cloud_outlined,
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 6),
          const Text(
            'Same URL your manager uses in Settings → Connection / Cloud sync. No trailing slash.',
            style: _kSmallBodyStyle,
          ),
          if (_error != null) _InlineError(message: _error!),
          const Spacer(),
          _YellowButton(
            label: 'Continue with Google',
            iconText: 'G',
            busy: app.busy,
            onPressed: app.busy ? null : () => _google(app, AccountRole.staff),
          ),
        ],
      ),
    );
  }

  /// Sign in with Google for an EXISTING account (login path). Skips the
  /// restaurant-name form and payment gate — the backend looks up the account
  /// by google_sub / email and returns the existing tenant info.
  ///
  /// If no account exists yet, the backend returns "account_not_found:..." —
  /// we treat that as "this Google email has never signed up" and route the
  /// user into the create-restaurant flow instead of leaving them stuck on a
  /// raw error message.
  Future<void> _googleLoginReturning(
    PosAppController app,
    AccountRole role,
  ) async {
    final ok = await app.googleLoginOrSignup(role: role);
    if (!mounted) return;
    if (ok) {
      _finishOrShowError(app, ok);
      return;
    }
    final error = app.lastError ?? '';
    if (role.isManager && error.contains('account_not_found')) {
      // Brand-new manager email: send them through proper signup.
      setState(() {
        _error = null;
        _mode = _AuthMode.manager;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No restaurant is linked to this Google account yet. '
            'Enter your restaurant name to sign up.',
          ),
        ),
      );
      return;
    }
    _finishOrShowError(app, ok);
  }

  void _go(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      if (mode == _AuthMode.staff) {
        final saved = AppScope.of(context).cloudConfig.baseUrl.trim();
        if (_staffCloudApiUrlCtrl.text.trim().isEmpty && saved.isNotEmpty) {
          _staffCloudApiUrlCtrl.text = saved;
        }
      }
    });
  }

  void _validateManagerStep(_AuthIntent intent) {
    final restaurant = _restaurantCtrl.text.trim();
    if (restaurant.isEmpty) {
      setState(() => _error = 'Restaurant name is required.');
      return;
    }
    if (intent == _AuthIntent.password) {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      if (email.isEmpty || password.length < 8) {
        setState(
          () => _error =
              'Email and an 8+ character password are required.',
        );
        return;
      }
    }
    setState(() {
      _authIntent = intent;
      _error = null;
      _mode = _AuthMode.payment;
    });
  }

  Future<void> _createManager(PosAppController app) async {
    final restaurant = _restaurantCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (restaurant.isEmpty || email.isEmpty || password.length < 8) {
      setState(
        () => _error =
            'Restaurant, email, and an 8+ character password are required.',
      );
      return;
    }
    final ok = await app.createManagerWithPassword(
      restaurantName: restaurant,
      outletName: _outletCtrl.text,
      email: email,
      password: password,
    );
    _finishOrShowError(app, ok, goToHeroMedia: true);
  }

  Future<void> _passwordLogin(PosAppController app) async {
    final ok = await app.loginWithAccount(
      usernameOrEmail: _emailCtrl.text,
      password: _passwordCtrl.text,
    );
    _finishOrShowError(app, ok);
  }

  Future<void> _google(PosAppController app, AccountRole role) async {
    if (role.isManager && _restaurantCtrl.text.trim().isEmpty) {
      setState(
        () => _error = 'Restaurant name is required for manager signup.',
      );
      return;
    }
    if (role == AccountRole.staff) {
      final url = _staffCloudApiUrlCtrl.text.trim();
      final uri = Uri.tryParse(url);
      final okUrl = uri != null &&
          uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
      if (!okUrl) {
        setState(
          () => _error =
              'Enter the restaurant server URL (https://… or http://…). Ask your manager for the link.',
        );
        return;
      }
    }
    final ok = await app.googleLoginOrSignup(
      role: role,
      restaurantName: _restaurantCtrl.text,
      outletName: _outletCtrl.text,
      cloudApiUrlOverride: role == AccountRole.staff ? _staffCloudApiUrlCtrl.text : null,
    );
    _finishOrShowError(
      app,
      ok,
      goToHeroMedia: role.isManager && _mode == _AuthMode.manager,
    );
  }

  void _finishOrShowError(
    PosAppController app,
    bool ok, {
    bool goToHeroMedia = false,
  }) {
    if (!mounted) return;
    if (ok) {
      if (goToHeroMedia && app.isManager && app.isTenantReady) {
        _go(_AuthMode.heroMedia);
        return;
      }
      widget.onFinished();
      return;
    }
    // Strip the internal "account_not_found:" marker so the user sees the
    // human-readable half if the message ever surfaces here.
    final raw = app.lastError ?? 'Could not complete sign in.';
    var cleaned = raw.startsWith('account_not_found:')
        ? raw.substring('account_not_found:'.length)
        : raw;
    cleaned = cleaned.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    setState(() => _error = cleaned);
  }

  Future<void> _pickHeroVideo() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      final bytes = await video.readAsBytes();
      // Cap at ~40 MB so the upload doesn't time out on slow connections.
      if (bytes.length > 40 * 1024 * 1024) {
        setState(() => _heroStatus = 'Video is too large (max 40 MB).');
        return;
      }
      setState(() {
        _heroVideoBytes = bytes;
        _heroVideoName = video.name;
        _heroStatus = null;
      });
    } catch (error) {
      setState(() => _heroStatus = 'Could not pick video: $error');
    }
  }

  Future<void> _pickHeroImage() async {
    if (_heroImageDataUrls.length >= 5) {
      setState(() => _heroStatus = 'Up to 5 images for the customer hero.');
      return;
    }
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 72,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 900 * 1024) {
        setState(() => _heroStatus = 'Image too large after compression.');
        return;
      }
      final mime = image.mimeType ?? _mimeFromName(image.name);
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      setState(() {
        _heroImageDataUrls.add(dataUrl);
        _heroStatus = null;
      });
    } catch (error) {
      setState(() => _heroStatus = 'Could not pick image: $error');
    }
  }

  String _mimeFromName(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _submitHeroMedia(PosAppController app) async {
    setState(() {
      _heroBusy = true;
      _heroStatus = null;
    });
    try {
      if (_heroVideoBytes != null) {
        final filename = _heroVideoName ?? 'hero.mp4';
        await app.uploadOutletHeroVideo(_heroVideoBytes!, filename);
      }
      for (final dataUrl in _heroImageDataUrls) {
        await app.uploadOutletHeroImage(dataUrl);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _heroStatus = 'Upload failed: $error';
        _heroBusy = false;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _heroBusy = false);
    // Clearing the flag tells the parent shell it can finally mount MainShell.
    app.completeHeroMediaSetup();
    widget.onFinished();
  }

  void _skipHeroMedia(PosAppController app) {
    app.completeHeroMediaSetup();
    widget.onFinished();
  }

  Widget _heroMediaForm(PosAppController app) {
    return _ScreenBody(
      key: const ValueKey('hero-media'),
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const Row(
            children: [Text('Last step · final touch', style: _kSmallStyle)],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Container(height: 3, color: _kYellow)),
              const SizedBox(width: 4),
              Expanded(child: Container(height: 3, color: _kYellow)),
              const SizedBox(width: 4),
              Expanded(child: Container(height: 3, color: _kYellow)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Customer hero media', style: _kFormTitleStyle),
          const SizedBox(height: 8),
          const Text(
            'Add a short welcome video and a few photos. Customers see these on the menu page.',
            style: _kSmallBodyStyle,
          ),
          const SizedBox(height: 22),
          _HeroVideoTile(
            videoName: _heroVideoName,
            onPick: _heroBusy ? null : _pickHeroVideo,
            onClear: _heroBusy
                ? null
                : () => setState(() {
                    _heroVideoBytes = null;
                    _heroVideoName = null;
                  }),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text('Customer hero images', style: _kLabelStyle),
              ),
              Text(
                '${_heroImageDataUrls.length}/5',
                style: _kSmallStyle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _HeroImageGrid(
            dataUrls: _heroImageDataUrls,
            onAdd: _heroBusy ? null : _pickHeroImage,
            onRemove: _heroBusy
                ? null
                : (index) =>
                      setState(() => _heroImageDataUrls.removeAt(index)),
          ),
          if (_heroStatus != null) _InlineError(message: _heroStatus!),
          const SizedBox(height: 22),
          _YellowButton(
            label: _heroVideoBytes == null && _heroImageDataUrls.isEmpty
                ? 'Skip & finish'
                : 'Upload & finish',
            icon: Icons.check_rounded,
            busy: _heroBusy,
            onPressed: _heroBusy ? null : () => _submitHeroMedia(app),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _heroBusy ? null : () => _skipHeroMedia(app),
              child: const Text(
                "I'll do this later",
                style: TextStyle(
                  color: Color(0xFF57524C),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DemoPlan {
  monthly(PaymentDefaults.monthlyPlanAmount),
  annual(PaymentDefaults.annualPlanAmount);

  const _DemoPlan(this.amount);
  final double amount;
}

class _ScreenBody extends StatelessWidget {
  const _ScreenBody({required this.child, this.scrollable = false, super.key});

  final Widget child;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padded = Padding(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 24),
          child: child,
        );
        if (!scrollable) {
          return SizedBox(
            width: double.infinity,
            height: constraints.maxHeight,
            child: padded,
          );
        }
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: padded,
          ),
        );
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: _kYellow,
        border: Border.all(color: Colors.black, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: Colors.black, size: 42),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Icon(Icons.arrow_back_rounded, size: 20),
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.activeStep});

  final int activeStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 3, color: _kYellow)),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: activeStep == 2 ? _kYellow : Colors.white,
              border: Border.all(color: Colors.black45, width: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _kLabelStyle),
        const SizedBox(height: 7),
        _BareField(
          controller: controller,
          hintText: hintText,
          icon: icon,
          keyboardType: keyboardType,
          obscureText: obscureText,
          textCapitalization: textCapitalization,
        ),
      ],
    );
  }
}

class _BareField extends StatelessWidget {
  const _BareField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        cursorColor: Colors.black,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF9E9B96),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(icon, size: 17, color: Colors.black87),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.3),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.black, width: 1.6),
          ),
        ),
      ),
    );
  }
}

class _YellowButton extends StatelessWidget {
  const _YellowButton({
    required this.label,
    this.icon,
    this.iconText,
    this.busy = false,
    this.onPressed,
  });

  final String label;
  final IconData? icon;
  final String? iconText;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _kYellow,
          disabledBackgroundColor: _kYellow.withValues(alpha: 0.55),
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.black, width: 1.6),
          ),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : _ButtonLabel(label: label, icon: icon, iconText: iconText),
      ),
    );
  }
}

class _WhiteButton extends StatelessWidget {
  const _WhiteButton({
    required this.label,
    required this.iconText,
    this.busy = false,
    this.onPressed,
  });

  final String label;
  final String iconText;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: OutlinedButton(
        onPressed: busy ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
          side: const BorderSide(color: Colors.black, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : _ButtonLabel(label: label, iconText: iconText),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  const _OutlineActionButton({
    required this.label,
    required this.iconText,
    required this.onPressed,
  });

  final String label;
  final String iconText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
          side: const BorderSide(color: Colors.black, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _ButtonLabel(label: label, iconText: iconText),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.label, this.icon, this.iconText});

  final String label;
  final IconData? icon;
  final String? iconText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) Icon(icon, size: 18),
        if (iconText != null)
          Text(
            iconText!,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        if (icon != null || iconText != null) const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  const _PlanTile({
    required this.title,
    required this.amount,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String amount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? _kYellow.withValues(alpha: 0.28) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: selected ? 1.8 : 1.2),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 22,
              color: Colors.black,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              amount,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFBDB8B1), height: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 9),
          child: Text(
            'OR',
            style: TextStyle(color: Color(0xFF9E9B96), fontSize: 10),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFBDB8B1), height: 1)),
      ],
    );
  }
}

class _HeroVideoTile extends StatelessWidget {
  const _HeroVideoTile({
    required this.videoName,
    required this.onPick,
    required this.onClear,
  });

  final String? videoName;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasVideo = videoName != null;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: hasVideo ? _kYellow.withValues(alpha: 0.24) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 1.4),
        ),
        child: Row(
          children: [
            Icon(
              hasVideo
                  ? Icons.video_collection_rounded
                  : Icons.video_camera_back_outlined,
              size: 26,
              color: Colors.black,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasVideo ? 'Hero video ready' : 'Pick a hero video',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasVideo
                        ? videoName!
                        : 'Short clip shown on the customer menu.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF57524C),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (hasVideo)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                tooltip: 'Remove video',
              ),
          ],
        ),
      ),
    );
  }
}

class _HeroImageGrid extends StatelessWidget {
  const _HeroImageGrid({
    required this.dataUrls,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> dataUrls;
  final VoidCallback? onAdd;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      for (var i = 0; i < dataUrls.length; i++)
        _ImageThumb(
          dataUrl: dataUrls[i],
          onRemove: onRemove == null ? null : () => onRemove!(i),
        ),
      if (dataUrls.length < 5)
        InkWell(
          onTap: onAdd,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.black,
                width: 1.2,
                style: BorderStyle.solid,
              ),
            ),
            child: const Center(
              child: Icon(Icons.add_a_photo_outlined, size: 26),
            ),
          ),
        ),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: tiles);
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.dataUrl, required this.onRemove});

  final String dataUrl;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final bytes = _bytesFromDataUrl(dataUrl);
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: bytes == null
                ? Container(
                    color: Colors.black12,
                    child: const Icon(Icons.broken_image_outlined),
                  )
                : Image.memory(
                    bytes,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Uint8List? _bytesFromDataUrl(String dataUrl) {
  final idx = dataUrl.indexOf(',');
  if (idx < 0) return null;
  try {
    return base64Decode(dataUrl.substring(idx + 1));
  } catch (_) {
    return null;
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB42318),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

const _kYellow = Color(0xFFFFCC29);

const _kTitleStyle = TextStyle(
  color: Colors.black,
  fontSize: 44,
  fontWeight: FontWeight.w900,
  height: 0.98,
  letterSpacing: 0,
);

const _kFormTitleStyle = TextStyle(
  color: Colors.black,
  fontSize: 28,
  fontWeight: FontWeight.w900,
  height: 1.02,
  letterSpacing: 0,
);

const _kStaffTitleStyle = TextStyle(
  color: Colors.black,
  fontSize: 30,
  fontWeight: FontWeight.w900,
  height: 1,
  letterSpacing: 0,
);

const _kBodyStyle = TextStyle(
  color: Color(0xFF57524C),
  fontSize: 17,
  fontWeight: FontWeight.w600,
  height: 1.32,
  letterSpacing: 0,
);

const _kSmallBodyStyle = TextStyle(
  color: Color(0xFF57524C),
  fontSize: 14,
  fontWeight: FontWeight.w600,
  height: 1.28,
  letterSpacing: 0,
);

const _kMutedBnStyle = TextStyle(
  color: Color(0xFFA29D96),
  fontSize: 15,
  fontWeight: FontWeight.w600,
  height: 1.25,
  letterSpacing: 0,
);

const _kSmallStyle = TextStyle(
  color: Color(0xFF57524C),
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
);

const _kTinyStyle = TextStyle(
  color: Color(0xFF57524C),
  fontSize: 12,
  fontWeight: FontWeight.w700,
  letterSpacing: 0,
);

const _kLabelStyle = TextStyle(
  color: Color(0xFF57524C),
  fontSize: 11,
  fontWeight: FontWeight.w800,
  letterSpacing: 0,
);
