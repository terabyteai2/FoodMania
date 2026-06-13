import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/admin_blocking_notice.dart';

class AdminBlockingNoticeScreen extends StatelessWidget {
  const AdminBlockingNoticeScreen({
    required this.notice,
    required this.refreshing,
    required this.onRetry,
    this.error,
    super.key,
  });

  final AdminBlockingNotice notice;
  final bool refreshing;
  final VoidCallback onRetry;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = AppStrings.of(
      Localizations.localeOf(context).languageCode == 'bn'
          ? AppLanguage.bn
          : AppLanguage.en,
    );
    final title = notice.title.trim().isEmpty
        ? text.adminBlockingNoticeDefaultTitle
        : notice.title;

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
                        notice.message,
                        style: const TextStyle(
                          color: PosColors.inkSoft,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: PosSpacing.sp5),
                      TfText(
                        text.adminBlockingNoticeHelper,
                        style: const TextStyle(
                          color: PosColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          height: 1.45,
                        ),
                      ),
                      if (error != null && error!.trim().isNotEmpty) ...[
                        const SizedBox(height: PosSpacing.sp3),
                        TfText(
                          error!,
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
                        onPressed: refreshing ? null : onRetry,
                        busy: refreshing,
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
