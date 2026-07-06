import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tf_design_system.dart';

class ScanningProgress extends StatefulWidget {
  const ScanningProgress({
    required this.message,
    this.messageBn,
    this.height = 6,
    super.key,
  });

  final String message;
  final String? messageBn;
  final double height;

  @override
  State<ScanningProgress> createState() => _ScanningProgressState();
}

class _ScanningProgressState extends State<ScanningProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _controller.addListener(() => setState(() {}));
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fillFraction = 0.28;
    final label = tfPick(context, en: widget.message, bn: widget.messageBn);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(PosRadii.sm),
          child: SizedBox(
            height: widget.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final totalWidth = constraints.maxWidth;
                final fillWidth = totalWidth * fillFraction;
                final t = _controller.value;
                final left = (t * (1.0 + fillFraction) - fillFraction) * totalWidth;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: Container(color: PosColors.surfaceSunk),
                    ),
                    Positioned(
                      left: left,
                      width: fillWidth,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: PosColors.primary,
                          borderRadius: BorderRadius.circular(PosRadii.sm),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: PosSpacing.sp3),
        TfText(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: PosColors.slateSoft,
          ),
        ),
      ],
    );
  }
}

class ScanningProgressOverlay {
  static VoidCallback show(
    BuildContext context, {
    required String message,
    String? messageBn,
  }) {
    var open = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(PosSpacing.sp4),
            padding: const EdgeInsets.all(PosSpacing.sp4),
            decoration: BoxDecoration(
              color: PosColors.surface,
              borderRadius: BorderRadius.circular(PosRadii.card),
              boxShadow: PosShadows.card,
            ),
            child: SizedBox(
              width: 240,
              child: ScanningProgress(
                message: message,
                messageBn: messageBn,
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() => open = false);
    return () {
      if (open) {
        open = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    };
  }
}
