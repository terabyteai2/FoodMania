import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tf_design_system.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({this.message = 'Loading...', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PosSpacing.sp6),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PosSpacing.sp6,
            vertical: PosSpacing.sp5,
          ),
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.card),
            border: Border.all(color: PosColors.line),
            boxShadow: PosShadows.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: PosColors.neutralSoft,
                  borderRadius: BorderRadius.circular(PosRadii.lg),
                  border: Border.all(color: PosColors.line),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(PosSpacing.sp4),
                  child: CircularProgressIndicator(
                    color: PosColors.primary,
                    strokeWidth: 2.6,
                  ),
                ),
              ),
              const SizedBox(height: PosSpacing.sp3),
              TfText(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: PosColors.slateSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
