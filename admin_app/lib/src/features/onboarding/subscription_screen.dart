import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';

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
      backgroundColor: const Color(0xFFFFFDF5),
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
        const Text(
          'Waiting for activation',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: Color(0xFF14110E),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your restaurant account is being set up. Please contact customer support or try again a bit later.',
          style: TextStyle(
            fontSize: 13.5,
            color: Color(0xFF5A5450),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E0D0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7DA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: Color(0xFF14110E),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Your restaurant isn\'t activated yet',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF14110E),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'After activation, tap "Check activation status" below to open the app.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF5A5450),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorBox(message: _error!),
        ],
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              foregroundColor: const Color(0xFF14110E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _busy ? null : _checkActivation,
            child: _busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF14110E),
                    ),
                  )
                : const Text(
                    'Check activation status',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
          ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5B4B0)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF8A2A1F),
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
