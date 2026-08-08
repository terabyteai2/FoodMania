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
    this.imageUrl,
    this.inputLabel,
    this.inputController,
    this.dismissible = false,
    this.onDismiss,
    super.key,
  });

  final Widget? leading;
  final Widget? body;
  final String? error;
  final List<ScreenBlockerAction> actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final String? imageUrl;
  final String? inputLabel;
  final TextEditingController? inputController;
  final bool dismissible;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: dismissible,
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
                      if (imageUrl != null && imageUrl!.trim().isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(PosRadii.md),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 220),
                            child: Image.network(
                              imageUrl!,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        const SizedBox(height: PosSpacing.sp4),
                      ],
                      if (body != null) ...[
                        body!,
                        const SizedBox(height: PosSpacing.sp3),
                      ],
                      if (inputLabel != null && inputController != null) ...[
                        Container(
                          height: 44,
                          decoration: BoxDecoration(
                            border: Border.all(color: PosColors.lineStrong),
                            borderRadius: BorderRadius.circular(PosRadii.md),
                            color: PosColors.surface,
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: inputController,
                            style: TextStyle(
                              fontFamily: tfFontFamily(context),
                              fontSize: 15,
                              color: PosColors.primaryDark,
                            ),
                            decoration: InputDecoration(
                              hintText: inputLabel,
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
                        const SizedBox(height: PosSpacing.sp4),
                      ],
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
