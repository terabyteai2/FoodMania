import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Locale helpers
// ---------------------------------------------------------------------------

/// True when the active app locale is Bangla.
bool tfIsBn(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'bn';

/// Picks the locale-appropriate string: returns [bn] when the active locale
/// is Bangla and [bn] is non-empty, otherwise [en]. Use this so screens stay
/// single-language; never render both at once.
String tfPick(BuildContext context, {required String en, String? bn}) {
  if (bn == null || bn.isEmpty) return en;
  return tfIsBn(context) ? bn : en;
}

/// Picks Hind Siliguri when the active locale is Bangla, Inter otherwise.
/// Pass to widgets that already set a TextStyle without `fontFamily`.
String tfFontFamily(BuildContext context) =>
    tfIsBn(context) ? 'Hind Siliguri' : 'Inter';

// ---------------------------------------------------------------------------
// TfText — a Text that auto-picks the Bangla font when locale is Bangla.
// ---------------------------------------------------------------------------

class TfText extends StatelessWidget {
  const TfText(
    this.text, {
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final base = style ?? const TextStyle();
    final family = base.fontFamily ?? tfFontFamily(context);
    return Text(
      text,
      style: base.copyWith(fontFamily: family),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

// ---------------------------------------------------------------------------
// TfTextPair — locale-aware single-string renderer.
//
// NOTE: kept for source compat with existing call sites that pass `en` + `bn`.
// It NO LONGER stacks both languages on screen. It picks one based on locale.
// The `axis`/`align`/`gap` params are retained but ignored. New code should
// just use [TfText] with a pre-localised string.
// ---------------------------------------------------------------------------

class TfTextPair extends StatelessWidget {
  const TfTextPair({
    required this.en,
    required this.bn,
    @Deprecated('Single-language only; axis is ignored.') this.axis,
    this.enStyle,
    this.bnStyle,
    @Deprecated('Single-language only; align is ignored.') this.align,
    this.textAlign = TextAlign.start,
    @Deprecated('Single-language only; gap is ignored.') this.gap,
    super.key,
  });

  final String en;
  final String bn;
  final Axis? axis;
  final TextStyle? enStyle;
  final TextStyle? bnStyle;
  final CrossAxisAlignment? align;
  final TextAlign textAlign;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    final text = isBn && bn.isNotEmpty ? bn : en;
    final style = (isBn ? (bnStyle ?? enStyle) : enStyle) ??
        const TextStyle(
          color: PosColors.slate,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );
    final family = style.fontFamily ?? (isBn ? 'Hind Siliguri' : 'Inter');
    return Text(
      text,
      textAlign: textAlign,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style.copyWith(fontFamily: family),
    );
  }
}

// ---------------------------------------------------------------------------
// TfAppBar — large title row with optional leading + trailing actions.
// ---------------------------------------------------------------------------

class TfAppBar extends StatelessWidget {
  const TfAppBar({
    required this.title,
    this.titleBn,
    this.subtitle,
    this.subtitleBn,
    this.leading,
    this.trailing = const [],
    super.key,
  });

  final String title;
  final String? titleBn;
  final String? subtitle;
  final String? subtitleBn;
  final Widget? leading;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    final t = isBn && (titleBn?.isNotEmpty ?? false) ? titleBn! : title;
    final s = isBn && (subtitleBn?.isNotEmpty ?? false)
        ? subtitleBn!
        : subtitle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: isBn ? 'Hind Siliguri' : 'Inter',
                    color: PosColors.slate,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
                if (s != null && s.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: isBn ? 'Hind Siliguri' : 'Inter',
                      color: PosColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: 8),
            Wrap(spacing: 8, children: trailing),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfButton — primary/dark/ghost/paper variants. 44px tap-target floor.
// ---------------------------------------------------------------------------

enum TfButtonVariant { primary, dark, ghost, paper }

enum TfButtonSize { lg, md, sm }

class TfButton extends StatelessWidget {
  const TfButton({
    required this.label,
    required this.onPressed,
    this.labelBn,
    this.icon,
    this.trailingIcon,
    this.variant = TfButtonVariant.primary,
    this.size = TfButtonSize.md,
    @Deprecated('Use [size] instead.') this.height,
    this.fullWidth = true,
    super.key,
  });

  final String label;
  final String? labelBn;
  final IconData? icon;
  final IconData? trailingIcon;
  final TfButtonVariant variant;
  final TfButtonSize size;
  final VoidCallback? onPressed;
  final double? height;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final colors = switch (variant) {
      TfButtonVariant.primary => (PosColors.primary, PosColors.primaryDark),
      TfButtonVariant.dark => (PosColors.primaryDark, Colors.white),
      TfButtonVariant.ghost => (Colors.transparent, PosColors.slate),
      TfButtonVariant.paper => (PosColors.surface, PosColors.slate),
    };
    final borderColor = switch (variant) {
      TfButtonVariant.primary => Colors.transparent,
      TfButtonVariant.dark => Colors.transparent,
      TfButtonVariant.ghost => PosColors.line,
      TfButtonVariant.paper => PosColors.line,
    };

    // Effective height: explicit height wins for legacy callers, otherwise
    // pick from the size enum. lg = 50, md = 42, sm = 32 (matches the JSX).
    final effHeight = height ??
        switch (size) {
          TfButtonSize.lg => 50.0,
          TfButtonSize.md => 42.0,
          TfButtonSize.sm => 32.0,
        };
    final isCompact = effHeight <= 34;
    final fontSize = isCompact ? 13.0 : (effHeight >= 48 ? 15.0 : 14.0);
    final radius = isCompact ? 8.0 : 12.0;

    final isBn = tfIsBn(context);
    final text = isBn && (labelBn?.isNotEmpty ?? false) ? labelBn! : label;

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      height: effHeight,
      child: Material(
        color: disabled ? PosColors.line : colors.$1,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: disabled ? PosColors.line : borderColor,
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 18,
                    color: disabled ? PosColors.muted : colors.$2,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: isBn ? 'Hind Siliguri' : 'Inter',
                      color: disabled ? PosColors.muted : colors.$2,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    trailingIcon,
                    size: 18,
                    color: disabled ? PosColors.muted : colors.$2,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfCard — paper surface, hairline border, 12px radius.
// ---------------------------------------------------------------------------

class TfCard extends StatelessWidget {
  const TfCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 12, 14, 12),
    this.color = PosColors.surface,
    this.clip = false,
    this.padded = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool clip;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.line, width: 0.5),
      ),
      child: padded ? Padding(padding: padding, child: child) : child,
    );
  }
}

// ---------------------------------------------------------------------------
// TfChip — pill toggle; active = dark fill.
// ---------------------------------------------------------------------------

class TfChip extends StatelessWidget {
  const TfChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.labelBn,
    this.small = false,
    this.leading,
    super.key,
  });

  final String label;
  final String? labelBn;
  final bool active;
  final bool small;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    final text = isBn && (labelBn?.isNotEmpty ?? false) ? labelBn! : label;
    return Material(
      color: active ? PosColors.primaryDark : PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.pill),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 11 : 14,
            vertical: small ? 6 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.pill),
            border: Border.all(
              color: active ? PosColors.primaryDark : PosColors.line,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(
                    size: small ? 13 : 14,
                    color: active ? Colors.white : PosColors.slate,
                  ),
                  child: leading!,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: TextStyle(
                  fontFamily: isBn ? 'Hind Siliguri' : 'Inter',
                  color: active ? Colors.white : PosColors.slate,
                  fontSize: small ? 12 : 13,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfStatusBadge — pending/accepted/late/served/info pill.
// ---------------------------------------------------------------------------

enum TfStatusKind { pending, accepted, late, served, info, warning }

class TfStatusBadge extends StatelessWidget {
  const TfStatusBadge({
    required this.label,
    required this.kind,
    this.upper = true,
    super.key,
  });

  /// Accepts either a [TfStatusKind] or the legacy string key
  /// ("pending" | "accepted" | "late" | "served" | "info").
  final String label;
  final Object kind;
  final bool upper;

  @override
  Widget build(BuildContext context) {
    final resolved = kind is TfStatusKind
        ? kind as TfStatusKind
        : _parseKind(kind.toString());
    final spec = switch (resolved) {
      TfStatusKind.pending => (PosColors.primarySoft, PosColors.primaryDark),
      TfStatusKind.accepted => (PosColors.successSoft, PosColors.success),
      TfStatusKind.late => (PosColors.dangerSoft, PosColors.danger),
      TfStatusKind.served => (PosColors.successSoft, PosColors.success),
      TfStatusKind.warning => (PosColors.coralSoft, PosColors.coral),
      TfStatusKind.info => (PosColors.background, PosColors.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: spec.$1,
        borderRadius: BorderRadius.circular(PosRadii.pill),
      ),
      child: Text(
        upper ? label.toUpperCase() : label,
        style: TextStyle(
          fontFamily: tfFontFamily(context),
          color: spec.$2,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  static TfStatusKind _parseKind(String value) {
    switch (value.toLowerCase()) {
      case 'pending':
        return TfStatusKind.pending;
      case 'accepted':
        return TfStatusKind.accepted;
      case 'late':
        return TfStatusKind.late;
      case 'served':
        return TfStatusKind.served;
      case 'warning':
      case 'coral':
        return TfStatusKind.warning;
      default:
        return TfStatusKind.info;
    }
  }
}

// ---------------------------------------------------------------------------
// TfIconButton — square 38px button, optional badge.
// ---------------------------------------------------------------------------

class TfIconButton extends StatelessWidget {
  const TfIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
    this.dark = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int? badge;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 38,
        height: 38,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: dark ? PosColors.primaryDark : PosColors.surface,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: dark ? PosColors.primaryDark : PosColors.line,
                        width: 0.5,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color: dark ? Colors.white : PosColors.slate,
                    ),
                  ),
                ),
              ),
            ),
            if (badge != null && badge! > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PosColors.danger,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: PosColors.surface, width: 1.5),
                  ),
                  child: Text(
                    badge! > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfFab — 56px amber floating action button with glow.
// ---------------------------------------------------------------------------

class TfFab extends StatelessWidget {
  const TfFab({
    required this.onPressed,
    this.tooltip,
    this.icon = Icons.add_rounded,
    super.key,
  });

  final VoidCallback onPressed;
  final String? tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? 'New',
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: PosColors.primary,
          borderRadius: BorderRadius.circular(28),
          boxShadow: PosShadows.glow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, color: PosColors.primaryDark),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfBottomNav — 5-item bottom navigation with amber pip under active item.
// ---------------------------------------------------------------------------

class TfBottomNavItem {
  const TfBottomNavItem({
    required this.icon,
    required this.label,
    this.labelBn,
  });
  final IconData icon;
  final String label;
  final String? labelBn;
}

class TfBottomNav extends StatelessWidget {
  const TfBottomNav({
    required this.items,
    required this.activeIndex,
    required this.onChanged,
    super.key,
  });

  final List<TfBottomNavItem> items;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    return Container(
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(
          top: BorderSide(color: PosColors.line, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final it = items[i];
              final selected = i == activeIndex;
              final text =
                  isBn && (it.labelBn?.isNotEmpty ?? false) ? it.labelBn! : it.label;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          it.icon,
                          size: 22,
                          color:
                              selected ? PosColors.slate : PosColors.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: isBn ? 'Hind Siliguri' : 'Inter',
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: selected
                                ? PosColors.slate
                                : PosColors.muted,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 18,
                          height: 3,
                          decoration: BoxDecoration(
                            color: selected
                                ? PosColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfStickyCTA — full-width sticky bottom CTA container with optional helper.
// ---------------------------------------------------------------------------

class TfStickyCTA extends StatelessWidget {
  const TfStickyCTA({required this.child, this.helper, super.key});

  final Widget child;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      decoration: const BoxDecoration(
        color: PosColors.background,
        border: Border(
          top: BorderSide(color: PosColors.line, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          if (helper != null) ...[
            const SizedBox(height: 10),
            TfText(
              helper!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: PosColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfRail — left-edge color stripe used inside order cards.
// ---------------------------------------------------------------------------

class TfRail extends StatelessWidget {
  const TfRail({required this.color, this.width = 4, super.key});
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfSectionHeader — "TODAY", "FOUND · 2" style small-caps label.
// ---------------------------------------------------------------------------

class TfSectionHeader extends StatelessWidget {
  const TfSectionHeader({
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(2, 0, 2, 8),
    super.key,
  });

  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: tfFontFamily(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
                color: PosColors.muted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfField — labelled text input wrapper (paper surface, 0.5px border,
// focused = 1px dark border).
// ---------------------------------------------------------------------------

class TfField extends StatelessWidget {
  const TfField({
    required this.label,
    this.labelBn,
    this.controller,
    this.hint,
    this.hintBn,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.autofocus = false,
    this.obscure = false,
    this.maxLines = 1,
    this.onChanged,
    this.hintHelper,
    super.key,
  });

  final String label;
  final String? labelBn;
  final String? hint;
  final String? hintBn;
  final TextEditingController? controller;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final bool autofocus;
  final bool obscure;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final String? hintHelper;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    final lbl = isBn && (labelBn?.isNotEmpty ?? false) ? labelBn! : label;
    final hnt = isBn && (hintBn?.isNotEmpty ?? false) ? hintBn! : hint;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 6),
            child: Text(
              lbl,
              style: TextStyle(
                fontFamily: isBn ? 'Hind Siliguri' : 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: PosColors.slate,
              ),
            ),
          ),
          TextField(
            controller: controller,
            autofocus: autofocus,
            obscureText: obscure,
            maxLines: obscure ? 1 : maxLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            style: TextStyle(
              fontFamily: isBn ? 'Hind Siliguri' : 'Inter',
              fontSize: 15,
              color: PosColors.slate,
            ),
            decoration: InputDecoration(
              hintText: hnt,
              prefixIcon: prefix,
              suffixIcon: suffix,
              isDense: true,
            ),
          ),
          if (hintHelper != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                hintHelper!,
                style: TextStyle(
                  fontFamily: tfFontFamily(context),
                  fontSize: 12,
                  color: PosColors.muted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfTabs — two/three-tab segmented pill row with optional counter chips.
// Active = dark fill; inactive = paper outline.
// ---------------------------------------------------------------------------

class TfTabItem {
  const TfTabItem({required this.label, this.labelBn, this.count});
  final String label;
  final String? labelBn;
  final int? count;
}

class TfTabs extends StatelessWidget {
  const TfTabs({
    required this.items,
    required this.activeIndex,
    required this.onChanged,
    super.key,
  });

  final List<TfTabItem> items;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    return Row(
      children: List.generate(items.length, (i) {
        final it = items[i];
        final selected = i == activeIndex;
        final text =
            isBn && (it.labelBn?.isNotEmpty ?? false) ? it.labelBn! : it.label;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: Material(
              color: selected ? PosColors.primaryDark : PosColors.surface,
              borderRadius: BorderRadius.circular(10),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color:
                          selected ? PosColors.primaryDark : PosColors.line,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        text,
                        style: TextStyle(
                          fontFamily: isBn ? 'Hind Siliguri' : 'Inter',
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: selected ? Colors.white : PosColors.slate,
                        ),
                      ),
                      if (it.count != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? PosColors.primary
                                : PosColors.background,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${it.count}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: selected
                                  ? PosColors.primaryDark
                                  : PosColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// TfNavIcon — strokes drawn directly so the icon set matches the JSX
// NavIcon (orders/menu/home/inventory/settings/bell/plus/arrow/back/check/
// search/camera/printer/bluetooth/wifi/close/minus/dot/chevron/sparkle/flame).
//
// Falls back to Material icons for everything else, so Flutter's IconData
// API stays the source of truth at call sites.
// ---------------------------------------------------------------------------

class TfNavIcon {
  TfNavIcon._();

  // Receipt-ish ticket — matches the JSX 'orders' glyph.
  static const IconData orders = Icons.receipt_long_outlined;
  // Fork + spoon — JSX 'menu' is a spoon/fork composition; closest Material is
  // restaurant_menu_outlined.
  static const IconData menu = Icons.restaurant_menu_outlined;
  static const IconData home = Icons.home_outlined;
  static const IconData inventory = Icons.inventory_2_outlined;
  static const IconData settings = Icons.settings_outlined;
  static const IconData bell = Icons.notifications_outlined;
  static const IconData plus = Icons.add_rounded;
  static const IconData arrow = Icons.arrow_forward_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData camera = Icons.camera_alt_outlined;
  static const IconData printer = Icons.print_outlined;
  static const IconData bluetooth = Icons.bluetooth;
  static const IconData wifi = Icons.wifi;
  static const IconData close = Icons.close_rounded;
  static const IconData minus = Icons.remove_rounded;
  static const IconData dot = Icons.circle;
  static const IconData chevron = Icons.chevron_right_rounded;
  static const IconData sparkle = Icons.auto_awesome_outlined;
  static const IconData flame = Icons.local_fire_department_outlined;
}
