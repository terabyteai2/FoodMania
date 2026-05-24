import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Locale helpers
// ---------------------------------------------------------------------------

/// True when the active app locale is Bangla.
bool tfIsBn(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'bn';

String tfLocaleTag(BuildContext context) => tfIsBn(context) ? 'bn_BD' : 'en_US';

String tfFormatNumber(
  BuildContext context,
  num value, {
  int? decimalDigits,
}) {
  final formatter = decimalDigits == null
      ? NumberFormat.decimalPattern(tfLocaleTag(context))
      : NumberFormat.decimalPatternDigits(
          locale: tfLocaleTag(context),
          decimalDigits: decimalDigits,
        );
  final formatted = formatter.format(value);
  return tfIsBn(context) ? tfToBnNumbers(formatted) : formatted;
}

String tfFormatCurrency(
  BuildContext context,
  num amount, {
  String symbol = '৳',
  int decimalDigits = 0,
}) {
  final formatted = NumberFormat.currency(
    locale: tfLocaleTag(context),
    symbol: symbol,
    decimalDigits: decimalDigits,
  ).format(amount);
  return tfIsBn(context) ? tfToBnNumbers(formatted) : formatted;
}

/// Picks the locale-appropriate string: returns [bn] when the active locale
/// is Bangla and [bn] is non-empty, otherwise [en].
String tfPick(BuildContext context, {required String en, String? bn}) {
  if (bn == null || bn.isEmpty) return en;
  return tfIsBn(context) ? bn : en;
}

/// Dynamic Font Family utility ensuring baseline synchronization.
String tfFontFamily(BuildContext context) =>
    tfIsBn(context) ? 'Hind Siliguri' : 'Inter';

/// Internal utility to parse Western Arabic numbers into localized Eastern Bengali digits.
String tfToBnNumbers(String input) {
  const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const bangla = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
  String output = input;
  for (int i = 0; i < english.length; i++) {
    output = output.replaceAll(english[i], bangla[i]);
  }
  return output;
}

// ---------------------------------------------------------------------------
// TfText — Text that automatically handles localization and tracking safety.
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
    final isBn = tfIsBn(context);
    final base = style ?? const TextStyle();
    final family = base.fontFamily ?? tfFontFamily(context);

    // Safety check: Avoid dangerous text tracking configurations breaking nested Bangla glyph structures
    final double? tracking = isBn
        ? (base.letterSpacing != null && base.letterSpacing! < 0
              ? 0.0
              : base.letterSpacing)
        : base.letterSpacing;

    return Text(
      isBn ? tfToBnNumbers(text) : text,
      style: base.copyWith(fontFamily: family, letterSpacing: tracking),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

// ---------------------------------------------------------------------------
// TfMoney — Native Taka component featuring dynamic structural translation.
// ---------------------------------------------------------------------------
class TfMoney extends StatelessWidget {
  const TfMoney(this.amount, {this.style, this.showSymbol = true, super.key});

  final double amount;
  final TextStyle? style;
  final bool showSymbol;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);

    // Formats numbers cleanly into standard comma grouped structures (e.g. 15,300.00)
    final parts = amount.toStringAsFixed(2).split('.');
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String matchFunc(Match match) => '${match[1]},';
    final String formattedInteger = parts[0].replaceAllMapped(reg, matchFunc);
    final String cleanValue = parts[1] == '00'
        ? formattedInteger
        : '$formattedInteger.${parts[1]}';

    final baseStyle =
        style ??
        TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: PosColors.slate,
          fontFamily: tfFontFamily(context),
        );

    if (isBn) {
      final bnValue = tfToBnNumbers(cleanValue);
      return Text(
        showSymbol ? '৳$bnValue' : bnValue,
        style: baseStyle.copyWith(
          fontFamily: 'Hind Siliguri',
          letterSpacing:
              baseStyle.letterSpacing != null && baseStyle.letterSpacing! < 0
              ? 0
              : baseStyle.letterSpacing,
        ),
      );
    } else {
      return Text(
        showSymbol ? '৳$cleanValue' : cleanValue,
        style: baseStyle.copyWith(fontFamily: 'Inter'),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// TfTextPair — Backward compatible single-string localizer context.
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
    final style =
        (isBn ? (bnStyle ?? enStyle) : enStyle) ??
        const TextStyle(
          color: PosColors.slate,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );

    return TfText(text, textAlign: textAlign, style: style);
  }
}

// ---------------------------------------------------------------------------
// TfAppBar — Large structural title bar with safety alignments.
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
                TfText(
                  t,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: tfFontFamily(context),
                    color: PosColors.slate,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                    letterSpacing: 0,
                  ),
                ),
                if (s != null && s.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  TfText(
                    s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: tfFontFamily(context),
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
// TfButton — high performance tap variants.
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
    this.busy = false,
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
  final bool busy;

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

    final effHeight =
        height ??
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
          onTap: disabled || busy ? null : onPressed,
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
                if (busy || icon != null) ...[
                  if (busy)
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          disabled ? PosColors.muted : colors.$2,
                        ),
                      ),
                    )
                  else
                    Icon(
                      icon,
                      size: 18,
                      color: disabled ? PosColors.muted : colors.$2,
                    ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    isBn ? tfToBnNumbers(text) : text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: tfFontFamily(context),
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
// TfCard — Paper surface container context.
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
// TfChip — Pill toggles for lightning-fast catalog mutations.
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
                isBn ? tfToBnNumbers(text) : text,
                style: TextStyle(
                  fontFamily: tfFontFamily(context),
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
// TfStatusBadge — Clean tracking badges using updated warning schemas.
// ---------------------------------------------------------------------------
enum TfStatusKind { pending, accepted, late, served, info, warning }

class TfStatusBadge extends StatelessWidget {
  const TfStatusBadge({
    required this.label,
    required this.kind,
    this.upper = true,
    super.key,
  });

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
      TfStatusKind.warning => (PosColors.warningSoft, PosColors.warning),
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
          letterSpacing: tfIsBn(context) ? 0 : 0.2,
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
// TfIconButton — Square actionable targets with smart notification layer.
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
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: PosColors.surface, width: 1.5),
                  ),
                  child: Text(
                    badge! > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
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
// TfFab — Flat low-draw quick action trigger built for budget devices.
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
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: PosColors.primaryDark.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: PosShadows.glow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(999),
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
// TfBottomNav — Dynamic contextual footer layout tracking bar.
// ---------------------------------------------------------------------------
class TfBottomNavItem {
  const TfBottomNavItem({
    required this.icon,
    required this.label,
    this.labelBn,
    this.selectedIcon,
  });
  final IconData icon;
  final String label;
  final String? labelBn;
  final IconData? selectedIcon;
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
        border: Border(top: BorderSide(color: PosColors.line, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final it = items[i];
              final selected = i == activeIndex;
              final text = isBn && (it.labelBn?.isNotEmpty ?? false)
                  ? it.labelBn!
                  : it.label;
              return Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? (it.selectedIcon ?? it.icon) : it.icon,
                          size: 22,
                          color: selected ? PosColors.slate : PosColors.muted,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isBn ? tfToBnNumbers(text) : text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: tfFontFamily(context),
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: selected ? PosColors.slate : PosColors.muted,
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
// TfStickyCTA — Pinned situational workflow primary terminal block.
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
        border: Border(top: BorderSide(color: PosColors.line, width: 0.5)),
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
              style: const TextStyle(fontSize: 12, color: PosColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfRail — Colored accent visualization spine.
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
// TfSectionHeader — Consistent uppercase structural header text lines.
// ---------------------------------------------------------------------------
class TfSectionHeader extends StatelessWidget {
  const TfSectionHeader({
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(2, 0, 2, 8),
    this.color = PosColors.muted,
    super.key,
  });

  final String label;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: TfText(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: tfFontFamily(context),
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: tfIsBn(context) ? 0 : 0.5,
                color: color,
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
// TfField — Form validation wrapper now safely exposing error feedback paths.
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
    this.errorText, // Added primitive support for handling form invalidation feedback logic
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
  final String? errorText;

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
            child: TfText(
              lbl,
              style: TextStyle(
                fontFamily: tfFontFamily(context),
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
              fontFamily: tfFontFamily(context),
              fontSize: 15,
              color: PosColors.slate,
            ),
            decoration: InputDecoration(
              hintText: hnt,
              prefixIcon: prefix,
              suffixIcon: suffix,
              isDense: true,
              errorText: errorText != null
                  ? (isBn ? tfToBnNumbers(errorText!) : errorText)
                  : null,
              errorStyle: TextStyle(
                fontFamily: tfFontFamily(context),
                fontSize: 12,
              ),
            ),
          ),
          if (hintHelper != null && errorText == null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: TfText(
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
// TfSearchField — Standalone rounded search input with the standard PosRadii.
// ---------------------------------------------------------------------------
class TfSearchField extends StatelessWidget {
  const TfSearchField({
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
          fontFamily: tfFontFamily(context),
          color: PosColors.slate,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: PosColors.primary,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontFamily: tfFontFamily(context),
            color: PosColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(Icons.search_rounded, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 38),
          filled: true,
          fillColor: PosColors.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm),
            borderSide: const BorderSide(color: PosColors.line, width: 0.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm),
            borderSide: const BorderSide(color: PosColors.line, width: 0.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm),
            borderSide: const BorderSide(color: PosColors.primaryDark, width: 1),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfTabs — Linear segmented controls with safely unified family badge logic.
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
        final text = isBn && (it.labelBn?.isNotEmpty ?? false)
            ? it.labelBn!
            : it.label;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
            child: Material(
              color: selected ? PosColors.primaryDark : PosColors.surface,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? PosColors.primaryDark : PosColors.line,
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isBn ? tfToBnNumbers(text) : text,
                        style: TextStyle(
                          fontFamily: tfFontFamily(context),
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
                            isBn ? tfToBnNumbers('${it.count}') : '${it.count}',
                            style: TextStyle(
                              fontFamily: tfFontFamily(
                                context,
                              ), // Fixed: Routed via unified family configuration path
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
// Primitives: TfEmptyState — Universal empty context messaging module.
// ---------------------------------------------------------------------------
class TfEmptyState extends StatelessWidget {
  const TfEmptyState({
    required this.title,
    required this.message,
    this.titleBn,
    this.messageBn,
    this.icon = Icons.layers_clear_outlined,
    this.action,
    super.key,
  });

  final String title;
  final String? titleBn;
  final String message;
  final String? messageBn;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: PosColors.muted.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            TfText(
              tfPick(context, en: title, bn: titleBn),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: PosColors.slate,
              ),
            ),
            const SizedBox(height: 6),
            TfText(
              tfPick(context, en: message, bn: messageBn),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: PosColors.muted,
                height: 1.4,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Primitives: TfLoading — Hardware-efficient asynchronous block progress tracker.
// ---------------------------------------------------------------------------
class TfLoading extends StatelessWidget {
  const TfLoading({this.message, this.messageBn, super.key});
  final String? message;
  final String? messageBn;

  @override
  Widget build(BuildContext context) {
    final label = message != null
        ? tfPick(context, en: message!, bn: messageBn)
        : null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: PosColors.primaryDark,
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: 12),
              TfText(
                label,
                style: const TextStyle(fontSize: 13, color: PosColors.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Primitives: TfOfflineBanner — Low-latency localized environment banner.
// ---------------------------------------------------------------------------
class TfOfflineBanner extends StatelessWidget {
  const TfOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: PosColors.warning,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 14,
            color: PosColors.primaryDark,
          ),
          const SizedBox(width: 8),
          TfText(
            tfPick(
              context,
              en: "Offline Mode — Changes will sync automatically",
              bn: "অফলাইন মোড — পরিবর্তনগুলি স্বয়ংক্রিয়ভাবে সিঙ্ক হবে",
            ),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: PosColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Primitives: TfConfirmSheet — Dialog confirmation context wrappers.
// ---------------------------------------------------------------------------
class TfConfirmSheet extends StatelessWidget {
  const TfConfirmSheet({
    required this.title,
    required this.description,
    required this.onConfirm,
    this.titleBn,
    this.descriptionBn,
    this.confirmLabel,
    this.confirmLabelBn,
    this.isDanger = false,
    super.key,
  });

  final String title;
  final String? titleBn;
  final String description;
  final String? descriptionBn;
  final String? confirmLabel;
  final String? confirmLabelBn;
  final VoidCallback onConfirm;
  final bool isDanger;

  static void show(
    BuildContext context, {
    required String title,
    required String description,
    required VoidCallback onConfirm,
    String? titleBn,
    String? descriptionBn,
    String? confirmLabel,
    String? confirmLabelBn,
    bool isDanger = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TfConfirmSheet(
        title: title,
        titleBn: titleBn,
        description: description,
        descriptionBn: descriptionBn,
        onConfirm: onConfirm,
        confirmLabel: confirmLabel,
        confirmLabelBn: confirmLabelBn,
        isDanger: isDanger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TfText(
              tfPick(context, en: title, bn: titleBn),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: PosColors.slate,
              ),
            ),
            const SizedBox(height: 8),
            TfText(
              tfPick(context, en: description, bn: descriptionBn),
              style: const TextStyle(
                fontSize: 14,
                color: PosColors.muted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TfButton(
                    onPressed: () => Navigator.pop(context),
                    label: "Cancel",
                    labelBn: "বাতিল করুন",
                    variant: TfButtonVariant.paper,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TfButton(
                    label: confirmLabel ?? "Confirm",
                    labelBn: confirmLabelBn ?? "নিশ্চিত করুন",
                    variant: isDanger
                        ? TfButtonVariant.dark
                        : TfButtonVariant.primary,
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfNavIcon — Static lookup references matching layout blueprints.
// ---------------------------------------------------------------------------
class TfNavIcon {
  TfNavIcon._();

  static const IconData orders = Icons.receipt_long_outlined;
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
