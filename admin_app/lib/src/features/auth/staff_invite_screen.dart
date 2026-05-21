import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';

class StaffInviteScreen extends StatefulWidget {
  const StaffInviteScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<StaffInviteScreen> createState() => _StaffInviteScreenState();
}

class _StaffInviteScreenState extends State<StaffInviteScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _respond({required bool accept}) async {
    final app = AppScope.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await app.respondToStaffInvite(accept: accept);
      if (!ok) {
        throw Exception(app.lastError ?? 'Could not update invite.');
      }
      if (!mounted) return;
      widget.onFinished();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final invite = app.pendingStaffInvite;
    if (invite == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Icon(
                Icons.storefront_rounded,
                size: 56,
                color: Color(0xFFF2C744),
              ),
              const SizedBox(height: 24),
              Text(
                '${invite.restaurantName} wants to add you as staff',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF14110E),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Outlet: ${invite.outletName}\nPhone: ${invite.phone}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5A5450),
                  height: 1.4,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                Container(
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
              const Spacer(flex: 3),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: PosColors.primary,
                    foregroundColor: const Color(0xFF14110E),
                  ),
                  onPressed: _busy ? null : () => _respond(accept: true),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Accept',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _respond(accept: false),
                  child: const Text(
                    'Decline',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
