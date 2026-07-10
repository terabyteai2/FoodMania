import 'package:flutter/material.dart';

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
    this.error,
    super.key,
  });

  final AdminBlockingNotice notice;
  final bool refreshing;
  final VoidCallback onRetry;
  final Future<void> Function(String response)? onRespond;
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

  Future<void> _handleRetry() async {
    if (widget.notice.inputField &&
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
    final title = widget.notice.title.trim().isEmpty
        ? text.adminBlockingNoticeDefaultTitle
        : widget.notice.title;

    return ScreenBlocker(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: PosColors.dangerSoft,
          borderRadius: BorderRadius.circular(PosRadii.sm),
        ),
        child: const Icon(
          Icons.lock_outline_rounded,
          color: PosColors.danger,
          size: 24,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TfText(
            text.adminBlockingNoticeEyebrow,
            style: const TextStyle(
              color: PosColors.danger,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.77,
            ),
          ),
          if (widget.notice.imageUrl != null) ...[
            const SizedBox(height: PosSpacing.sp4),
            ClipRRect(
              borderRadius: BorderRadius.circular(PosRadii.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: Image.network(
                  widget.notice.imageUrl!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
          ],
          if (widget.notice.message.trim().isNotEmpty) ...[
            const SizedBox(height: PosSpacing.sp3),
            TfText(
              widget.notice.message,
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
          if (widget.notice.inputField) ...[
            const SizedBox(height: PosSpacing.sp4),
            Container(
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(color: PosColors.lineStrong),
                borderRadius: BorderRadius.circular(PosRadii.md),
                color: PosColors.surface,
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _inputController,
                style: TextStyle(
                  fontFamily: tfFontFamily(context),
                  fontSize: 15,
                  color: PosColors.primaryDark,
                ),
                decoration: InputDecoration(
                  hintText: widget.notice.inputLabel,
                  hintStyle: TextStyle(
                    color: PosColors.mutedSoft,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ],
        ],
      ),
      error: widget.error,
      actions: [
        ScreenBlockerAction(
          label: text.adminBlockingNoticeCheckAgain,
          icon: Icons.refresh_rounded,
          busy: widget.refreshing,
          onPressed: widget.refreshing ? null : _handleRetry,
        ),
      ],
    );
  }
}
