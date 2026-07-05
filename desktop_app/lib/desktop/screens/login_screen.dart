import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/constants/cloud_defaults.dart';

import '../theme/desk_theme.dart';

/// Desktop sign-in using phone OTP, matching the mobile app's auth flow.
/// Users enter their Server ID + phone number, receive a 6-digit code via SMS,
/// and verify to log in. Unregistered phones and pending staff invites are
/// redirected to the mobile app.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _urlCtl;
  late final TextEditingController _serverCtl;
  final _phoneCtl = TextEditingController();
  final _otpCtl = TextEditingController();

  bool _busy = false;
  bool _otpSent = false;
  String _otpCode = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(context);
    final existingUrl = app.cloudConfig.baseUrl.trim();
    _urlCtl = TextEditingController(
      text: existingUrl.isEmpty ? CloudDefaults.resolveBaseUrl(null) : existingUrl,
    );
    _serverCtl = TextEditingController(text: app.serverConfig.serverId.trim());
  }

  @override
  void dispose() {
    _urlCtl.dispose();
    _serverCtl.dispose();
    _phoneCtl.dispose();
    _otpCtl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final app = AppScope.of(context);
    final base = CloudDefaults.resolveBaseUrl(_urlCtl.text.trim());
    final serverId = _serverCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    if (serverId.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Enter Server ID and phone number.');
      return;
    }
    app.cloudConfig = app.cloudConfig.copyWith(baseUrl: base, enabled: true);
    app.serverConfig = app.serverConfig.copyWith(serverId: serverId);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await app.sendPhoneOtp(phone);
      if (!ok) {
        throw Exception(app.lastError ?? 'Could not send code.');
      }
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        _otpCode = '';
        _otpCtl.clear();
      });
      if (app.showDevOtpHint) {
        final code = app.devOtpCodeHint;
        _otpCtl.text = code;
        _onOtpChanged(code);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onOtpChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 6) return;
    setState(() => _otpCode = digits);
  }

  Future<void> _verifyOtp() async {
    final app = AppScope.of(context);
    final code = _otpCode.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await app.verifyPhoneOtp(
        phoneInput: _phoneCtl.text,
        code: code,
      );
      if (!mounted) return;
      if (next == null) {
        setState(() => _error = app.lastError ?? 'Verification failed.');
        return;
      }
      if (next == 'needs_restaurant_setup') {
        setState(
          () => _error = 'This phone is not registered. Please sign up using the mobile app first.',
        );
        return;
      }
      if (next == 'pending_staff_invite') {
        setState(
          () => _error = 'You have a pending staff invitation. Please respond using the mobile app.',
        );
        return;
      }
      // 'authenticated' — isLoggedIn flips, parent rebuilds into DeskShell
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _clean(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _clean(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '').trim();
    return message.isEmpty ? 'Could not sign in. Please try again.' : message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PosColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: PosColors.surface,
              borderRadius: BorderRadius.circular(PosRadii.xl),
              border: Border.all(color: PosColors.line),
              boxShadow: PosShadows.soft,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: PosColors.primary,
                        borderRadius: BorderRadius.circular(PosRadii.md),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.point_of_sale_rounded,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'QuickBytes',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: PosColors.primary,
                      ),
                    ),
                    Text(
                      '  Desktop POS',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: PosColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _field('Server ID', _serverCtl, hint: 'Outlet server id'),
                const SizedBox(height: 14),
                if (!_otpSent) ...[
                  _field('Phone number', _phoneCtl,
                    hint: '01XXXXXXXXX',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
                      LengthLimitingTextInputFormatter(14),
                    ],
                  ),
                ] else ...[
                  _field('Verification code', _otpCtl,
                    hint: '6-digit code',
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: _onOtpChanged,
                    onSubmitted: (_) => _verifyOtp(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _otpSent = false;
                                _otpCode = '';
                                _otpCtl.clear();
                                _error = null;
                              }),
                      child: Text(
                        'Change phone number',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: PosColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _field('Server URL', _urlCtl),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PosColors.dangerSoft,
                      borderRadius: BorderRadius.circular(PosRadii.sm),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          color: PosColors.danger, fontSize: 12.5),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  height: 46,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: PosColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(PosRadii.md),
                      ),
                    ),
                    onPressed: _busy ? null : (_otpSent ? _verifyOtp : _sendOtp),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : Text(
                            _otpSent ? 'Verify' : 'Send code',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool obscure = false,
    String? hint,
    Widget? trailing,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: PosColors.ink2,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          onSubmitted: onSubmitted,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            suffixIcon: trailing,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadii.md),
              borderSide: const BorderSide(color: PosColors.lineStrong),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadii.md),
              borderSide: const BorderSide(color: PosColors.lineStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(PosRadii.md),
              borderSide: const BorderSide(color: PosColors.primary, width: 1.6),
            ),
          ),
        ),
      ],
    );
  }
}
