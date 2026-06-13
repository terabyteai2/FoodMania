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
        padding: EdgeInsets.all(24),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 26, vertical: 22),
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
                  color: PosColors.primarySoft,
                  borderRadius: BorderRadius.circular(PosRadii.tile),
                  border: Border.all(color: PosColors.line),
                ),
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    color: PosColors.primaryDark,
                    strokeWidth: 2.6,
                  ),
                ),
              ),
              SizedBox(height: 14),
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
