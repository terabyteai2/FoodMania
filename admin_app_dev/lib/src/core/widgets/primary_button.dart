import 'package:flutter/material.dart';

import 'tf_design_system.dart';

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.secondary = false,
    this.busy = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool busy;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  @override
  Widget build(BuildContext context) {
    return TfButton(
      label: widget.label,
      icon: widget.icon,
      onPressed: widget.onPressed,
      busy: widget.busy,
      variant: widget.secondary
          ? TfButtonVariant.paper
          : TfButtonVariant.primary,
      size: TfButtonSize.lg,
    );
  }
}
