import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
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

class _AdminBlockingNoticeScreenState
    extends State<AdminBlockingNoticeScreen> {
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

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PosColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(PosSpacing.sp4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: TfCard(
                  padding: const EdgeInsets.all(PosSpacing.sp4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
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
                      ),
                      const SizedBox(height: PosSpacing.sp5),
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
                            borderRadius:
                                BorderRadius.circular(PosRadii.md),
                            color: PosColors.surface,
                          ),
                          alignment: Alignment.centerLeft,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
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
                      if (widget.error != null &&
                          widget.error!.trim().isNotEmpty) ...[
                        const SizedBox(height: PosSpacing.sp3),
                        TfText(
                          widget.error!,
                          style: const TextStyle(
                            color: PosColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            height: 1.45,
                          ),
                        ),
                      ],
                      const SizedBox(height: PosSpacing.sp4),
                      TfButton(
                        label: text.adminBlockingNoticeCheckAgain,
                        onPressed: widget.refreshing ? null : _handleRetry,
                        busy: widget.refreshing,
                        icon: Icons.refresh_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
