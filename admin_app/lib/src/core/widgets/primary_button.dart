import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.busy;

    final iconWidget = widget.busy
        ? SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.secondary ? PosColors.primaryDark : PosColors.slate,
              ),
            ),
          )
        : Icon(widget.icon, size: 18);

    final child = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          SizedBox(width: 8),
          Text(widget.label, maxLines: 1),
        ],
      ),
    );

    if (widget.secondary) {
      return AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: Duration(milliseconds: 100),
        child: OutlinedButton(
          onPressed: disabled ? null : widget.onPressed,
          onLongPress: disabled ? null : widget.onPressed,
          onHover: (_) {},
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            child: child,
          ),
        ),
      );
    }

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: Duration(milliseconds: 100),
      child: GestureDetector(
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.sm + 2),
            gradient: disabled ? null : PosGradients.brand,
            color: disabled ? PosColors.mutedSoft : null,
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: PosColors.primary.withValues(alpha: 0.32),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
          ),
          child: ElevatedButton(
            onPressed: disabled ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: PosColors.slate,
              disabledForegroundColor: PosColors.muted,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
