import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../theme/app_theme.dart';
import 'tf_design_system.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return TfCard(
      padding: const EdgeInsets.all(PosSpacing.sp4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PosColors.dangerSoft,
              borderRadius: BorderRadius.circular(PosRadii.lg),
              border: Border.all(color: PosColors.line),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: PosColors.danger,
              size: 22,
            ),
          ),
          const SizedBox(width: PosSpacing.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TfText(
                  text.somethingWentWrong,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: PosSpacing.sp1),
                TfText(message, style: Theme.of(context).textTheme.bodyMedium),
                if (onRetry != null) ...[
                  const SizedBox(height: PosSpacing.sp3),
                  TfButton(
                    label: text.retry,
                    icon: Icons.refresh,
                    onPressed: onRetry,
                    variant: TfButtonVariant.paper,
                    size: TfButtonSize.sm,
                    fullWidth: false,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
