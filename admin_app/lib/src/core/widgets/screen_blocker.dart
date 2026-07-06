import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'tf_design_system.dart';

class ScreenBlockerAction {
  const ScreenBlockerAction({
    required this.label,
    this.onPressed,
    this.busy = false,
    this.variant = TfButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final TfButtonVariant variant;
  final IconData? icon;
}

class ScreenBlocker extends StatelessWidget {
  const ScreenBlocker({
    required this.actions,
    this.leading,
    this.body,
    this.error,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    super.key,
  });

  final Widget? leading;
  final Widget? body;
  final String? error;
  final List<ScreenBlockerAction> actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: PosColors.background,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
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
                      if (leading != null) ...[
                        Align(alignment: Alignment.centerLeft, child: leading!),
                        const SizedBox(height: PosSpacing.sp5),
                      ],
                      ?body,
                      if (error != null && error!.trim().isNotEmpty) ...[
                        const SizedBox(height: PosSpacing.sp3),
                        TfCard(
                          padding: const EdgeInsets.all(12),
                          color: PosColors.dangerSoft,
                          child: TfText(
                            error!,
                            style: const TextStyle(
                              color: PosColors.danger,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: PosSpacing.sp4),
                        for (final action in actions) ...[
                          if (action != actions.first)
                            const SizedBox(height: 12),
                          TfButton(
                            label: action.label,
                            icon: action.icon,
                            busy: action.busy,
                            variant: action.variant,
                            size: TfButtonSize.lg,
                            onPressed: action.onPressed,
                          ),
                        ],
                      ],
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
