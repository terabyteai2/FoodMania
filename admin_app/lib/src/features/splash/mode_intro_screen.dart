import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';

/// Extracts a 6-digit OTP from SMS text or platform autofill payloads.
final RegExp _otpSixDigits = RegExp(r'\d{6}');

class ModeIntroScreen extends StatefulWidget {
  const ModeIntroScreen({required this.onFinished, super.key});

  final void Function(String? nextStep) onFinished;

  @override
  State<ModeIntroScreen> createState() => _ModeIntroScreenState();
}

class _ModeIntroScreenState extends State<ModeIntroScreen> {
  final _phoneController = TextEditingController();
  final _otpFocusNode = FocusNode();

  bool _busy = false;
  bool _otpSent = false;
  String? _error;
  bool _autoVerifyScheduled = false;
  bool _otpVerified = false;
  String _otpCode = '';

  static const _otpListenPattern = r'\d{6}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.of(context).refreshCloudCapabilities();
    });
  }

  @override
  void dispose() {
    _otpFocusNode.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _scheduleAutoVerify() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tryAutoVerify();
    });
  }

  void _tryAutoVerify() {
    if (!_otpSent || _busy || _autoVerifyScheduled || _otpVerified) return;
    if (_otpCode.trim().length != 6) return;
    _autoVerifyScheduled = true;
    unawaited(_verifyOtp());
  }

  void _applyOtpCode(String raw) {
    final match = _otpSixDigits.firstMatch(raw.replaceAll(RegExp(r'\s'), ''));
    if (match == null) return;
    final otp = match.group(0)!;
    if (otp == _otpCode) {
      _scheduleAutoVerify();
      return;
    }
    setState(() => _otpCode = otp);
    _scheduleAutoVerify();
  }

  void _onOtpChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 6) return;
    setState(() {
      _otpCode = digits;
      if (digits.length < 6) _autoVerifyScheduled = false;
    });
    if (digits.length == 6) _scheduleAutoVerify();
  }

  Future<String?> _readAppSmsHash() async {
    try {
      final raw = await SmsAutoFill().getAppSignature;
      if (raw.isEmpty) return null;
      final line = raw.split(RegExp(r'[\r\n]+')).first.trim();
      return line.isEmpty ? null : line;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendOtp() async {
    final app = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _autoVerifyScheduled = false;
    });
    try {
      final appSignature = await _readAppSmsHash();

      final ok = await app.sendPhoneOtp(
        _phoneController.text,
        appSignature: appSignature,
      );
      if (!ok) {
        throw Exception(app.lastError ?? 'Could not send code.');
      }
      if (!mounted) return;

      setState(() {
        _otpSent = true;
        _otpCode = '';
        _otpVerified = false;
        _autoVerifyScheduled = false;
      });

      if (app.showDevOtpHint) {
        _applyOtpCode(app.devOtpCodeHint);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanizeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _demoLogin() async {
    final app = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await app.loginAsDemoManager();
      if (!ok) {
        throw Exception(app.lastError ?? 'Demo login failed.');
      }
      if (!mounted) return;
      widget.onFinished('authenticated');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _humanizeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final app = AppScope.of(context);
    final code = _otpCode.trim();
    if (code.length < 6) {
      if (mounted) {
        setState(() {
          _error = 'Enter the 6-digit code.';
          _autoVerifyScheduled = false;
        });
      }
      return;
    }
    if (_busy || _otpVerified) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final next = await app.verifyPhoneOtp(
        phoneInput: _phoneController.text,
        code: code,
      );
      if (!mounted) return;
      if (next == null) {
        setState(() {
          _error = app.lastError ?? 'Verification failed.';
          _autoVerifyScheduled = false;
        });
        return;
      }
      _otpVerified = true;
      widget.onFinished(next);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _humanizeError(error);
        _autoVerifyScheduled = false;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanizeError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.length > 240 ? '${message.substring(0, 240)}…' : message;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final compact = bottomInset > 0 || _otpSent;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFFFFDF5),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        SizedBox(height: compact ? 8 : 32),
                        const _BrandMark(),
                        SizedBox(height: compact ? 16 : 28),
                        Text(
                          _otpSent ? 'Enter verification code' : 'Welcome',
                          style: TextStyle(
                            fontSize: compact ? 26 : 30,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF14110E),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _otpSent
                              ? (app.showDevOtpHint
                                  ? 'SMS was not sent (dev mode).\nEnter code ${app.devOtpCodeHint} or tap Verify.'
                                  : 'We sent a code to your phone.\nIt may fill in automatically, or enter it and tap Verify.')
                              : 'Sign in with your Bangladesh\nmobile number.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.4,
                            color: Color(0xFF5A5450),
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 32),
                        if (!_otpSent) ...[
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9+\s-]'),
                              ),
                              LengthLimitingTextInputFormatter(14),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Mobile number',
                              hintText: '01XXXXXXXXX',
                              prefixIcon: Icon(Icons.phone_android_rounded),
                            ),
                            onSubmitted: (_) => _busy ? null : _sendOtp(),
                          ),
                        ] else ...[
                          TextFieldPinAutoFill(
                            key: ValueKey('otp-${_otpSent ? 'sent' : 'idle'}'),
                            focusNode: _otpFocusNode,
                            currentCode: _otpCode,
                            codeLength: 6,
                            autoFocus: true,
                            smsCodeRegexPattern: _otpListenPattern,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: '6-digit code',
                              prefixIcon: Icon(Icons.sms_outlined),
                            ),
                            onCodeSubmitted: _applyOtpCode,
                            onCodeChanged: _onOtpChanged,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      setState(() {
                                        _otpSent = false;
                                        _otpCode = '';
                                        _error = null;
                                        _autoVerifyScheduled = false;
                                      });
                                    },
                              child: const Text('Change phone number'),
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDECEA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE5B4B0)),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: Color(0xFF8A2A1F),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (app.demoManagerLoginEnabled && !_otpSent) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: _busy ? null : _demoLogin,
                              child: const Text(
                                'Try demo restaurant',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: compact ? 20 : 40),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: PosColors.primary,
                              foregroundColor: const Color(0xFF14110E),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _busy
                                ? null
                                : (_otpSent
                                    ? () {
                                        _autoVerifyScheduled = false;
                                        unawaited(_verifyOtp());
                                      }
                                    : _sendOtp),
                            child: _busy
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF14110E),
                                    ),
                                  )
                                : Text(
                                    _otpSent ? 'Verify' : 'Send code',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'By continuing, you agree to\nTerms & Privacy Policy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9A9388),
                            height: 1.4,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7DA),
        shape: BoxShape.circle,
        border: Border.all(color: PosColors.primary, width: 2),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: Color(0xFFF2C744),
          size: 34,
        ),
      ),
    );
  }
}
