import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_blocker.dart';
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
    final app = AppScope.read(context);
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
    final app = AppScope.selectMany(
      context,
      const [AppAspect.account, AppAspect.language],
    );
    final invite = app.pendingStaffInvite;
    if (invite == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final roleLabel = invite.role == 'manager' ? 'Manager' : 'Staff';
    final inviter = invite.invitedBy?.trim().isNotEmpty == true
        ? invite.invitedBy!
        : 'Someone';

    return ScreenBlocker(
      body: Column(
        children: [
          const Icon(
            Icons.storefront_rounded,
            size: 56,
            color: PosColors.primaryDark,
          ),
          const SizedBox(height: 24),
          TfText(
            '$inviter has invited you to become a $roleLabel of ${invite.restaurantName}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: PosColors.slate,
              height: 1.25,
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
        ],
      ),
      error: _error,
      actions: [
        ScreenBlockerAction(
          label: 'Accept',
          busy: _busy,
          onPressed: () => _respond(accept: true),
        ),
        ScreenBlockerAction(
          label: 'Decline',
          variant: TfButtonVariant.paper,
          onPressed: _busy ? null : () => _respond(accept: false),
        ),
      ],
    );
  }
}
