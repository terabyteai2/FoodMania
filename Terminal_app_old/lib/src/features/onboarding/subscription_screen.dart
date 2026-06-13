import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';

/// Activation-status page shown after restaurant setup.
/// The plan picker is hidden for now; platform admin activates the account
/// from the control panel.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _checkActivation() async {
    if (_busy) return;
    final app = AppScope.of(context);
    if (!app.cloudConfig.hasDeviceToken) {
      setState(() {
        _error =
            'Still signing in. Wait a moment and tap Check activation status again.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final issue = await app.refreshSubscriptionAccessFromCloud();
      if (!mounted) return;
      if (issue == null) {
        widget.onFinished();
        return;
      }
      setState(() => _error = issue);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.subscriptionState == 'paid' && !app.mustCompleteOnboardingPayment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished();
      });
    }
    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _buildActivationBody(),
        ),
      ),
    );
  }

  Widget _buildActivationBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const TfText(
          'Waiting for activation',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w500,
            color: PosColors.slate,
          ),
        ),
        const SizedBox(height: 8),
        const TfText(
          'Your restaurant account is being set up. Please contact customer support or try again a bit later.',
          style: TextStyle(
            fontSize: 13.5,
            color: PosColors.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        TfCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: PosColors.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PosColors.line),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: PosColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: TfText(
                      'Your restaurant isn\'t activated yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                        color: PosColors.slate,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const TfText(
                'After activation, tap "Check activation status" below to open the app.',
                style: TextStyle(fontSize: 12.5, color: PosColors.muted),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(message: _error!),
        ],
        const Spacer(),
        TfButton(
          label: 'Check activation status',
          busy: _busy,
          size: TfButtonSize.lg,
          onPressed: _checkActivation,
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: const EdgeInsets.all(12),
      color: PosColors.dangerSoft,
      child: TfText(
        message,
        style: const TextStyle(
          color: PosColors.danger,
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
