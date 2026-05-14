import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    PosColors.danger.withValues(alpha: 0.18),
                    PosColors.danger.withValues(alpha: 0.06),
                  ],
                ),
                borderRadius: BorderRadius.circular(PosRadii.md),
                border: Border.all(
                  color: PosColors.danger.withValues(alpha: 0.22),
                ),
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
                  Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SizedBox(height: 4),
                  Text(message, style: Theme.of(context).textTheme.bodyMedium),
                  if (onRetry != null) ...[
                    SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: Icon(Icons.refresh),
                      label: Text('Retry'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
