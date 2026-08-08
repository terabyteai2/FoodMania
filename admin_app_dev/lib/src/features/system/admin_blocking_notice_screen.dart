import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/screen_blocker.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/admin_blocking_notice.dart';

class AdminBlockingNoticeScreen extends StatefulWidget {
  const AdminBlockingNoticeScreen({
    required this.notice,
    required this.refreshing,
    required this.onRetry,
    this.onRespond,
    this.onDismiss,
    this.error,
    super.key,
  });

  final AdminBlockingNotice notice;
  final bool refreshing;
  final VoidCallback onRetry;
  final Future<void> Function(String response)? onRespond;
  final VoidCallback? onDismiss;
  final String? error;

  @override
  State<AdminBlockingNoticeScreen> createState() =>
      _AdminBlockingNoticeScreenState();
}

class _AdminBlockingNoticeScreenState extends State<AdminBlockingNoticeScreen> {
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _handlePrimaryAction() async {
    final notice = widget.notice;

    if (notice.ctaUrl != null && notice.ctaUrl!.trim().isNotEmpty) {
      final uri = Uri.tryParse(notice.ctaUrl!);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    if (notice.inputField &&
        _inputController.text.trim().isNotEmpty &&
        widget.onRespond != null) {
      await widget.onRespond!(_inputController.text.trim());
    }
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(
      Localizations.localeOf(context).languageCode == 'bn'
          ? AppLanguage.bn
          : AppLanguage.en,
    );

    final notice = widget.notice;
    final title =
        notice.title.trim().isEmpty ? text.adminBlockingNoticeDefaultTitle : notice.title;

    final (leadingIcon, leadingColor) = switch (notice.type) {
      BlockingNoticeType.announcement => (Icons.campaign_outlined, PosColors.warning),
      BlockingNoticeType.subscription => (Icons.card_membership_outlined, PosColors.warning),
      BlockingNoticeType.paymentLink => (Icons.payment_outlined, PosColors.warning),
      BlockingNoticeType.adminNotice => (Icons.lock_outline_rounded, PosColors.danger),
    };

    final eyebrow = switch (notice.type) {
      BlockingNoticeType.announcement => text.adminBlockingNoticeEyebrowAnnouncement,
      BlockingNoticeType.subscription => text.adminBlockingNoticeEyebrow,
      BlockingNoticeType.paymentLink => text.adminBlockingNoticeEyebrowPaymentLink,
      BlockingNoticeType.adminNotice => text.adminBlockingNoticeEyebrow,
    };

    return ScreenBlocker(
      dismissible: notice.dismissible,
      onDismiss: widget.onDismiss,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: leadingColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(PosRadii.sm),
        ),
        child: Icon(leadingIcon, color: leadingColor, size: 24),
      ),
      imageUrl: notice.imageUrl,
      inputLabel: notice.inputField ? notice.inputLabel : null,
      inputController: notice.inputField ? _inputController : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TfText(
            eyebrow,
            style: TextStyle(
              color: leadingColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.77,
            ),
          ),
          if (notice.message.trim().isNotEmpty) ...[
            const SizedBox(height: PosSpacing.sp3),
            TfText(
              notice.message,
              style: const TextStyle(
                color: PosColors.inkSoft,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.55,
              ),
            ),
          ],
          const SizedBox(height: PosSpacing.sp2),
          TfText(
            title,
            style: const TextStyle(
              color: PosColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
          const SizedBox(height: PosSpacing.sp3),
          TfText(
            text.adminBlockingNoticeHelper,
            style: const TextStyle(
              color: PosColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              height: 1.45,
            ),
          ),
        ],
      ),
      error: widget.error,
      actions: [
        ScreenBlockerAction(
          label: notice.ctaLabel ?? text.adminBlockingNoticeCheckAgain,
          icon: notice.ctaUrl != null
              ? Icons.open_in_new_rounded
              : notice.dismissible
                  ? Icons.close_rounded
                  : Icons.refresh_rounded,
          busy: widget.refreshing,
          onPressed: widget.refreshing ? null : _handlePrimaryAction,
        ),
        if (notice.dismissible)
          ScreenBlockerAction(
            label: text.adminBlockingNoticeCheckAgain,
            icon: Icons.refresh_rounded,
            variant: TfButtonVariant.paper,
            busy: widget.refreshing,
            onPressed: widget.refreshing ? null : widget.onRetry,
          ),
      ],
    );
  }
}
