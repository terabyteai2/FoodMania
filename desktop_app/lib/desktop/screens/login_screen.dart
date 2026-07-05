import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/constants/cloud_defaults.dart';

import '../theme/desk_theme.dart';

/// Desktop sign-in. The mobile app authenticates with phone-OTP / Google, which
/// aren't viable on Windows, so the register logs in with the outlet's
/// **Server ID + account credentials** against `POST /admin/login`
/// (backend looks the outlet up by `server_id`, then the account within it).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _urlCtl;
  late final TextEditingController _serverCtl;
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
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
    _userCtl.dispose();
    _passCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final app = AppScope.read(context);
    final base = CloudDefaults.resolveBaseUrl(_urlCtl.text.trim());
    final serverId = _serverCtl.text.trim();
    final id = _userCtl.text.trim();
    final pw = _passCtl.text;
    if (serverId.isEmpty || id.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Enter Server ID, username/email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    app.cloudConfig = app.cloudConfig.copyWith(baseUrl: base, enabled: true);
    app.serverConfig = app.serverConfig.copyWith(serverId: serverId);
    try {
      await app.loginWithAccount(usernameOrEmail: id, password: pw);
      // On success isLoggedIn flips and the parent rebuilds into DeskShell,
      // unmounting this screen — so only handle the no-throw failure case.
      if (mounted && !app.isLoggedIn) {
        setState(() {
          _busy = false;
          _error = 'Login failed. Check the Server ID and your credentials.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _clean(error);
        });
      }
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
                _field('Username or email', _userCtl),
                const SizedBox(height: 14),
                _field(
                  'Password',
                  _passCtl,
                  obscure: _obscure,
                  onSubmitted: (_) => _submit(),
                  trailing: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                      color: PosColors.muted,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
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
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.4, color: Colors.white),
                          )
                        : const Text('Sign in',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
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
