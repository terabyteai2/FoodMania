import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_blocker.dart';
import '../../core/widgets/tf_design_system.dart';

/// Activation-status page shown after restaurant setup.
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

  Future<void> _openWhatsApp() async {
    final text = AppScope.of(context).strings;
    final msg = Uri.encodeQueryComponent(text.subscriptionWhatsAppMessage);
    final uri = Uri.parse('https://wa.me/8801575873000?text=$msg');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.subscriptionState == 'paid' && !app.mustCompleteOnboardingPayment) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onFinished();
      });
    }
    final text = AppScope.of(context).strings;
    return ScreenBlocker(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        color: PosColors.neutralSoft,
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
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: PosColors.primarySoft,
                  borderRadius: BorderRadius.circular(PosRadii.sm),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: PosColors.accentStrong,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TfText(
                      'Need help? Chat with our support team',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PosColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: _openWhatsApp,
                        icon: const Icon(Icons.chat_outlined, size: 16),
                        label: TfText(
                          text.subscriptionChatSupport,
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: PosColors.accentStrong,
                          side: const BorderSide(color: PosColors.lineStrong),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(PosRadii.md),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      error: _error,
      actions: [
        ScreenBlockerAction(
          label: 'Check activation status',
          icon: Icons.refresh_rounded,
          busy: _busy,
          onPressed: _checkActivation,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _checkActivation,
        backgroundColor: PosColors.success,
        foregroundColor: PosColors.surface,
        icon: const Icon(Icons.check_circle_outline),
        label: TfText(
          text.subscriptionIvePaid,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
