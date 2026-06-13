import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';

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
      backgroundColor: PosColors.background,
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
                color: PosColors.primaryDark,
              ),
              const SizedBox(height: 24),
              TfText(
                '${invite.restaurantName} wants to add you as staff',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: PosColors.slate,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              TfText(
                'Outlet: ${invite.outletName}\nPhone: ${invite.phone}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: PosColors.muted,
                  height: 1.4,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 20),
                TfCard(
                  padding: const EdgeInsets.all(12),
                  color: PosColors.dangerSoft,
                  child: TfText(
                    _error!,
                    style: const TextStyle(
                      color: PosColors.danger,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              const Spacer(flex: 3),
              TfButton(
                label: 'Accept',
                busy: _busy,
                size: TfButtonSize.lg,
                onPressed: () => _respond(accept: true),
              ),
              const SizedBox(height: 12),
              TfButton(
                label: 'Decline',
                variant: TfButtonVariant.paper,
                size: TfButtonSize.lg,
                onPressed: _busy ? null : () => _respond(accept: false),
              ),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
