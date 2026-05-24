import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tf_design_system.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: PosColors.dangerSoft,
              borderRadius: BorderRadius.circular(PosRadii.md),
              border: Border.all(color: PosColors.line),
            ),
            child: Icon(
              Icons.error_outline_rounded,
              color: PosColors.danger,
              size: 22,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TfText(
                  'Something went wrong',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(height: 4),
                TfText(message, style: Theme.of(context).textTheme.bodyMedium),
                if (onRetry != null) ...[
                  SizedBox(height: 12),
                  TfButton(
                    label: 'Retry',
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
