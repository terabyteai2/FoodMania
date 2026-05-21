import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({this.message = 'Loading...', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 26, vertical: 22),
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(PosRadii.xl),
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
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      PosColors.primarySoft,
                      PosColors.primarySoft.withValues(alpha: 0.4),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    color: PosColors.primary,
                    strokeWidth: 2.6,
                  ),
                ),
              ),
              SizedBox(height: 14),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
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
