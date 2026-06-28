import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tf_design_system.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    required this.icon,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      clip: true,
      padding: const EdgeInsets.symmetric(
        horizontal: PosSpacing.sp6,
        vertical: PosSpacing.sp7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: PosColors.primarySoft,
              borderRadius: BorderRadius.circular(PosRadii.lg),
              border: Border.all(color: PosColors.line),
            ),
            child: Icon(icon, color: PosColors.accentStrong, size: 30),
          ),
          const SizedBox(height: PosSpacing.sp4),
          TfText(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PosSpacing.sp2),
          TfText(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...[
            const SizedBox(height: PosSpacing.sp4),
            action!,
          ],
        ],
      ),
    );
  }
}
