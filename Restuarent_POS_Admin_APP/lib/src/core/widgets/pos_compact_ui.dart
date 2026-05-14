import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CompactHeader extends StatelessWidget {
  const CompactHeader({
    required this.title,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: PosColors.slate,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.02,
                  letterSpacing: 0,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: 4),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          SizedBox(width: 10),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    );
  }
}

class CompactIconButton extends StatelessWidget {
  const CompactIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    this.filled = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final background = filled ? PosColors.primary : PosColors.surface;
    final foreground = filled ? PosColors.primaryDark : PosColors.slate;
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 36,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, color: foreground, size: 18),
          ),
        ),
      ),
    );
  }
}

class CompactSearchField extends StatelessWidget {
  const CompactSearchField({
    required this.controller,
    required this.hintText,
    this.onChanged,
    super.key,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          color: PosColors.slate,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        cursorColor: PosColors.primary,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: PosColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Icon(Icons.search_rounded, size: 17),
          prefixIconConstraints: BoxConstraints(minWidth: 38),
          filled: true,
          fillColor: PosColors.surface,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: PosColors.lineStrong),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: PosColors.lineStrong),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: PosColors.primary, width: 1.2),
          ),
        ),
      ),
    );
  }
}

class CompactSectionLabel extends StatelessWidget {
  const CompactSectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: PosColors.muted,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        height: 1,
        letterSpacing: 0.8,
      ),
    );
  }
}

class CompactSurface extends StatelessWidget {
  const CompactSurface({
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 9,
    this.color,
    this.borderColor,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = BoxDecoration(
      color: color ?? PosColors.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? PosColors.lineStrong),
    );
    final content = Container(decoration: box, padding: padding, child: child);
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

class CountBadge extends StatelessWidget {
  const CountBadge({
    required this.label,
    this.background,
    this.foreground,
    super.key,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: 17),
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: background ?? PosColors.primary,
        borderRadius: BorderRadius.circular(PosRadii.pill),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foreground ?? PosColors.primaryDark,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class EmptyCompactState extends StatelessWidget {
  const EmptyCompactState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: PosColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: PosColors.lineStrong),
              ),
              child: Icon(icon, color: PosColors.muted, size: 28),
            ),
            SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PosColors.slate,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: PosColors.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
