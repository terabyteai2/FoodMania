import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import 'menu_image_view.dart';

// ---------------------------------------------------------------------------
// Locale helpers
// ---------------------------------------------------------------------------

/// True when the active app locale is Bangla.
bool tfIsBn(BuildContext context) =>
    Localizations.localeOf(context).languageCode.toLowerCase() == 'bn';

String tfLocaleTag(BuildContext context) => tfIsBn(context) ? 'bn_BD' : 'en_US';

String tfFormatNumber(BuildContext context, num value, {int? decimalDigits}) {
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

const String tfEnglishFontFamily = 'Inter';
const String tfBanglaFontFamily = 'Hind Siliguri';
const double tfBanglaMinLineHeight = 1.36;

/// Dynamic Font Family utility ensuring baseline synchronization.
String tfFontFamily(BuildContext context) =>
    tfIsBn(context) ? tfBanglaFontFamily : tfEnglishFontFamily;

TextStyle tfSafeTextStyle(
  BuildContext context,
  TextStyle base, {
  double minBnHeight = tfBanglaMinLineHeight,
}) {
  final isBn = tfIsBn(context);
  final safeHeight = isBn && (base.height == null || base.height! < minBnHeight)
      ? minBnHeight
      : base.height;
  final tracking = isBn && base.letterSpacing != null && base.letterSpacing! < 0
      ? 0.0
      : base.letterSpacing;
  final family = isBn
      ? tfBanglaFontFamily
      : (base.fontFamily ?? tfEnglishFontFamily);

  return base.copyWith(
    fontFamily: family,
    fontFamilyFallback: isBn
        ? const [tfBanglaFontFamily]
        : base.fontFamilyFallback,
    letterSpacing: tracking,
    height: safeHeight,
    leadingDistribution: isBn
        ? TextLeadingDistribution.even
        : base.leadingDistribution,
  );
}

StrutStyle? tfSafeStrutStyle(
  BuildContext context,
  TextStyle base, {
  double minBnHeight = tfBanglaMinLineHeight,
}) {
  if (!tfIsBn(context)) return null;
  final safeHeight = base.height == null || base.height! < minBnHeight
      ? minBnHeight
      : base.height;
  return StrutStyle(
    fontFamily: tfBanglaFontFamily,
    fontFamilyFallback: const [tfBanglaFontFamily],
    fontSize: base.fontSize,
    height: safeHeight,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

TextHeightBehavior? tfSafeTextHeightBehavior(BuildContext context) {
  if (!tfIsBn(context)) return null;
  return const TextHeightBehavior(
    applyHeightToFirstAscent: true,
    applyHeightToLastDescent: true,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

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
// Named text styles — roles not covered by the TextTheme slots.
// ---------------------------------------------------------------------------
class TfTextStyles {
  TfTextStyles._();

  /// Order serial hero: #24 on order cards — 19/800 tabular.
  static const TextStyle orderSerial = TextStyle(
    fontFamily: tfEnglishFontFamily,
    fontSize: 19,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );
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
    final safeStyle = tfSafeTextStyle(context, base);

    return Text(
      isBn ? tfToBnNumbers(text) : text,
      style: safeStyle,
      strutStyle: tfSafeStrutStyle(context, safeStyle),
      textHeightBehavior: tfSafeTextHeightBehavior(context),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}

// ---------------------------------------------------------------------------
// TfMicroLabel — Soft POS eyebrow label.
// ---------------------------------------------------------------------------
class TfMicroLabel extends StatelessWidget {
  const TfMicroLabel(this.text, {this.color, this.style, super.key});
  final String text;
  final Color? color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
    tfIsBn(context) ? tfToBnNumbers(text) : text,
    style: TextStyle(
      fontSize: 12,
      fontFamily: tfFontFamily(context),
      fontWeight: FontWeight.w700,
      color: color ?? PosColors.textTer,
      letterSpacing: tfIsBn(context) ? 0 : 0.48,
      height: 1.3,
    ).merge(style),
  );
}

// ---------------------------------------------------------------------------
// TfDelta — Inline plain-language comparison.
// ---------------------------------------------------------------------------
class TfDelta extends StatelessWidget {
  const TfDelta({
    required this.value,
    this.pct,
    this.down = false,
    this.baselineLabel,
    this.prefix,
    this.size = 13.0,
    super.key,
  });

  final String value;
  final String? pct;
  final bool down;
  final String? baselineLabel;
  final String? prefix;
  final double size;

  @override
  Widget build(BuildContext context) {
    final up = !down;
    final color = up ? PosColors.good : PosColors.danger;
    final verb = prefix ?? (up ? 'more than' : 'less than');

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: up ? '↑ ' : '↓ ',
            style: TextStyle(fontSize: size - 1, fontWeight: FontWeight.w700),
          ),
          TextSpan(
            text: value,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: size),
          ),
          if (baselineLabel != null) ...[
            TextSpan(
              text: ' $verb ',
              style: TextStyle(
                color: PosColors.text,
                fontWeight: FontWeight.w500,
                fontSize: size,
              ),
            ),
            TextSpan(
              text: baselineLabel,
              style: TextStyle(
                color: PosColors.text,
                fontWeight: FontWeight.w500,
                fontSize: size,
              ),
            ),
          ],
          if (pct != null)
            TextSpan(
              text: ' ($pct)',
              style: TextStyle(
                color: PosColors.textSec,
                fontWeight: FontWeight.w500,
                fontSize: size,
              ),
            ),
        ],
      ),
      style: TextStyle(
        color: color,
        fontFamily: tfFontFamily(context),
        height: 1.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfOpenTicketsBar — Slim one-line strip for live operational numbers.
// ---------------------------------------------------------------------------
class TfOpenTicketsBar extends StatelessWidget {
  const TfOpenTicketsBar({
    required this.count,
    required this.total,
    this.late = 0,
    super.key,
  });

  final int count;
  final String total;
  final int late;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: PosColors.primaryDark,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$count open',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: ' · $total in flight',
                      style: const TextStyle(
                        color: PosColors.textSec,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: PosColors.text,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (late > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: PosColors.lateSoft,
                borderRadius: BorderRadius.circular(PosRadii.tag),
              ),
              child: Text(
                '$late LATE',
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: tfEnglishFontFamily,
                  fontWeight: FontWeight.w600,
                  color: PosColors.late,
                  letterSpacing: 0,
                ),
              ),
            ),
        ],
      ),
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
          fontWeight: FontWeight.w700,
          color: PosColors.slate,
          fontFamily: tfFontFamily(context),
        );

    if (isBn) {
      final bnValue = tfToBnNumbers(cleanValue);
      final safeStyle = tfSafeTextStyle(context, baseStyle);
      return Text(
        showSymbol ? '৳$bnValue' : bnValue,
        style: safeStyle,
        strutStyle: tfSafeStrutStyle(context, safeStyle),
        textHeightBehavior: tfSafeTextHeightBehavior(context),
      );
    } else {
      return Text(
        showSymbol ? '৳$cleanValue' : cleanValue,
        style: baseStyle.copyWith(fontFamily: tfEnglishFontFamily),
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
          fontWeight: FontWeight.w600,
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

    return TfUnifiedTopNav(
      title: t,
      subtitle: s,
      leading: leading,
      trailing: trailing,
    );
  }
}

// ---------------------------------------------------------------------------
// TfUnifiedTopNav — Common app chrome from the dashboard design canvas.
// ---------------------------------------------------------------------------
class TfUnifiedTopNav extends StatelessWidget {
  const TfUnifiedTopNav({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing = const [],
    this.below,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 10),
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> trailing;
  final Widget? below;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfText(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: tfFontFamily(context),
            color: PosColors.text,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.15,
            letterSpacing: -0.52,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          TfText(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: tfFontFamily(context),
              color: PosColors.textSec,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(child: titleBlock),
              if (trailing.isNotEmpty) ...[
                const SizedBox(width: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 7,
                  runSpacing: 8,
                  children: trailing,
                ),
              ],
            ],
          ),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Source top-bar icons — small 20x20 line glyphs from bytes-shared.jsx.
// ---------------------------------------------------------------------------
enum TfSourceIconName { back, chat, bell, bolt }

class TfSourceIcon extends StatelessWidget {
  const TfSourceIcon({
    required this.name,
    this.size = 20,
    this.color = PosColors.primaryDark,
    this.strokeWidth = 1.8,
    super.key,
  });

  final TfSourceIconName name;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _TfSourceIconPainter(
        name: name,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _TfSourceIconPainter extends CustomPainter {
  const _TfSourceIconPainter({
    required this.name,
    required this.color,
    required this.strokeWidth,
  });

  final TfSourceIconName name;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 20, size.height / 20);
    if (name == TfSourceIconName.bolt) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawPath(_boltPath(), paint);
      canvas.restore();
      return;
    }

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(_linePath(name), paint);
    canvas.restore();
  }

  Path _linePath(TfSourceIconName icon) {
    switch (icon) {
      case TfSourceIconName.back:
        return Path()
          ..moveTo(12, 4)
          ..lineTo(6, 10)
          ..lineTo(12, 16);
      case TfSourceIconName.chat:
        return Path()
          ..moveTo(4.5, 4)
          ..lineTo(15.5, 4)
          ..quadraticBezierTo(17, 4, 17, 5.5)
          ..lineTo(17, 11.5)
          ..quadraticBezierTo(17, 13, 15.5, 13)
          ..lineTo(8, 13)
          ..lineTo(4, 16)
          ..lineTo(4, 13)
          ..quadraticBezierTo(3, 13, 3, 11.5)
          ..lineTo(3, 5.5)
          ..quadraticBezierTo(3, 4, 4.5, 4);
      case TfSourceIconName.bell:
        return Path()
          ..moveTo(10, 3)
          ..cubicTo(12.5, 3, 14.5, 5, 14.5, 7.5)
          ..cubicTo(14.5, 11.5, 16, 12.5, 16, 12.5)
          ..lineTo(4, 12.5)
          ..cubicTo(4, 12.5, 5.5, 11.5, 5.5, 7.5)
          ..cubicTo(5.5, 5, 7.5, 3, 10, 3)
          ..moveTo(8.5, 16)
          ..cubicTo(8.9, 17.2, 11.1, 17.2, 11.5, 16);
      case TfSourceIconName.bolt:
        return _boltPath();
    }
  }

  Path _boltPath() {
    return Path()
      ..moveTo(11, 2)
      ..lineTo(4, 11)
      ..lineTo(9, 11)
      ..lineTo(8, 18)
      ..lineTo(15, 9)
      ..lineTo(10, 9)
      ..close();
  }

  @override
  bool shouldRepaint(_TfSourceIconPainter oldDelegate) =>
      oldDelegate.name != name ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

class TfBrandMark extends StatelessWidget {
  const TfBrandMark({this.size = 35, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PosColors.primary,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      alignment: Alignment.center,
      child: TfSourceIcon(
        name: TfSourceIconName.bolt,
        size: size * 0.58,
        color: PosColors.accentInk,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfBrandHeader — Source top-bar wordmark + outlet subtitle block.
// ---------------------------------------------------------------------------
class TfBrandHeader extends StatelessWidget {
  const TfBrandHeader({
    required this.title,
    this.subtitle,
    this.icon = Icons.bolt_rounded,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TfBrandMark(),
        const SizedBox(width: 9),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _TfWordmark(title: title),
              if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                TfText(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: PosColors.muted,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TfWordmark extends StatelessWidget {
  const _TfWordmark({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final lower = title.toLowerCase().replaceAll(' ', '');
    if (lower == 'quickbytes') {
      return RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: const TextSpan(
          style: TextStyle(
            fontFamily: tfEnglishFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: PosColors.primaryDark,
            height: 1,
            letterSpacing: 0,
          ),
          children: [
            TextSpan(
              text: 'Quick',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: 'Bytes'),
          ],
        ),
      );
    }
    return TfText(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: tfEnglishFontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: PosColors.primaryDark,
        height: 1,
        letterSpacing: 0,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfButton — Soft POS action button.
// ---------------------------------------------------------------------------
enum TfButtonVariant { primary, dark, ghost, paper, accent }

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
      TfButtonVariant.primary => (PosColors.primary, PosColors.accentInk),
      TfButtonVariant.dark => (PosColors.primaryDark, Colors.white),
      TfButtonVariant.ghost => (Colors.transparent, PosColors.primaryDark),
      TfButtonVariant.paper => (PosColors.surface, PosColors.primaryDark),
      // Accent-wash: the QuickBytes "Accept" / emphasis action — soft lime tint
      // with dark ink, never solid lime (spec §3).
      TfButtonVariant.accent => (PosColors.accentSoft, PosColors.accentSoftInk),
    };
    final borderColor = switch (variant) {
      TfButtonVariant.primary => Colors.transparent,
      TfButtonVariant.dark => Colors.transparent,
      TfButtonVariant.ghost => PosColors.line,
      TfButtonVariant.paper => PosColors.line,
      TfButtonVariant.accent => PosColors.primaryWash,
    };

    final effHeight =
        height ??
        switch (size) {
          TfButtonSize.lg => 52.0,
          TfButtonSize.md => 44.0,
          TfButtonSize.sm => 36.0,
        };
    final isCompact = effHeight <= 38;
    final fontSize = isCompact ? 13.0 : (effHeight >= 50 ? 15.0 : 14.0);
    final radius = isCompact ? PosRadii.sm : PosRadii.md;

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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: disabled ? PosColors.line : borderColor,
                width: 1,
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
                  child: TfText(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: disabled ? PosColors.muted : colors.$2,
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
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
    this.padding = const EdgeInsets.all(16),
    this.color = PosColors.surface,
    this.borderColor = PosColors.line,
    this.clip = false,
    this.padded = true,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final bool clip;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: clip ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: padded ? Padding(padding: padding, child: child) : child,
    );
  }
}

// ---------------------------------------------------------------------------
// TfListCard — Card container for list rows (unpadded, inset dividers).
// ---------------------------------------------------------------------------
class TfListCard extends StatelessWidget {
  const TfListCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line, width: 1),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// TfItemRow — Menu-list row (icon + body + trailing price/toggle).
// ---------------------------------------------------------------------------
class TfItemRow extends StatelessWidget {
  const TfItemRow({
    required this.icon,
    required this.title,
    required this.desc,
    required this.status,
    required this.price,
    required this.on,
    required this.onChanged,
    this.first = false,
    this.onTap,
    this.onLongPress,
    this.statusColor,
    this.selected = false,
    this.selectionMode = false,
    this.onSelect,
    this.discountPrice,
    this.discountLabel,
    this.onAddImage,
    super.key,
  });

  final Widget icon;
  final String title;
  final String desc;
  final String status;
  final String price;
  final bool on;
  final ValueChanged<bool> onChanged;
  final bool first;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? statusColor;
  final bool selected;
  final bool selectionMode;
  final VoidCallback? onSelect;
  final String? discountPrice;
  final String? discountLabel;
  final VoidCallback? onAddImage;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          border: first
              ? null
              : Border(top: BorderSide(color: PosColors.divider, width: 1)),
        ),
        child: Row(
          children: [
            if (selectionMode) ...[
              Checkbox(value: selected, onChanged: (_) => onSelect?.call()),
              const SizedBox(width: 6),
            ],
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onAddImage,
              child: SizedBox(width: 48, height: 48, child: icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TfText(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PosColors.slate,
                      height: 1.2,
                    ),
                  ),
                  TfText(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: PosColors.textSec,
                      height: 1.45,
                    ),
                  ),
                  Row(
                    children: [
                      TfText(
                        status,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: statusColor ?? PosColors.good,
                          height: 1.3,
                        ),
                      ),
                      if (discountLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: PosColors.danger.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(PosRadii.tag),
                          ),
                          child: TfText(
                            discountLabel!,
                            style: const TextStyle(
                              color: PosColors.danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (discountPrice != null) ...[
                  TfText(
                    price,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: PosColors.textTer,
                      height: 1.2,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  TfText(
                    discountPrice!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PosColors.danger,
                      height: 1.2,
                    ),
                  ),
                ] else
                  TfText(
                    price,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: PosColors.slate,
                      height: 1.2,
                    ),
                  ),
                const SizedBox(height: 4),
                TfToggle(value: on, onChanged: onChanged),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfChip — Soft POS pill filter.
// ---------------------------------------------------------------------------
class TfChip extends StatelessWidget {
  const TfChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.labelBn,
    this.count,
    this.small = false,
    this.tint = false,
    this.leading,
    super.key,
  });

  final String label;
  final String? labelBn;
  final bool active;
  final int? count;
  final bool small;
  final bool tint;
  final Widget? leading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    final text = isBn && (labelBn?.isNotEmpty ?? false) ? labelBn! : label;

    final Color fillColor;
    final Color textColor;
    final Color borderColor;
    if (active && tint) {
      fillColor = PosColors.primarySoft;
      textColor = PosColors.accentStrong;
      borderColor = Colors.transparent;
    } else if (active) {
      fillColor = PosColors.primary;
      textColor = PosColors.accentInk;
      borderColor = PosColors.primary;
    } else {
      fillColor = PosColors.surface;
      textColor = PosColors.primaryDark;
      borderColor = PosColors.lineStrong;
    }

    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(PosRadii.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: small ? 36 : 44),
          padding: EdgeInsets.symmetric(
            horizontal: small ? 12 : 16,
            vertical: small ? 7 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.chip),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                IconTheme(
                  data: IconThemeData(size: small ? 14 : 16, color: textColor),
                  child: leading!,
                ),
                const SizedBox(width: 6),
              ],
              TfText(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: small ? 13 : 14,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 4),
                Text(
                  tfFormatNumber(context, count!),
                  style: TextStyle(
                    fontSize: small ? 11 : 13,
                    fontWeight: FontWeight.w500,
                    color: active
                        ? textColor.withValues(alpha: 0.7)
                        : PosColors.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfFilterChipData — Data class for a filter chip.
// ---------------------------------------------------------------------------
class TfFilterChipData {
  const TfFilterChipData({
    required this.label,
    this.labelBn,
    this.count,
    this.active = false,
  });

  final String label;
  final String? labelBn;
  final int? count;
  final bool active;
}

// ---------------------------------------------------------------------------
// TfFilterChipRow — Horizontal scroll of pill filter chips.
// ---------------------------------------------------------------------------
class TfFilterChipRow extends StatelessWidget {
  const TfFilterChipRow({
    required this.chips,
    required this.onSelected,
    super.key,
  });

  final List<TfFilterChipData> chips;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final chip = chips[index];
          return TfChip(
            label: chip.label,
            labelBn: chip.labelBn,
            count: chip.count,
            active: chip.active,
            onTap: () => onSelected(index),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfToggle — Soft POS availability/state switch.
// ---------------------------------------------------------------------------
class TfToggle extends StatelessWidget {
  const TfToggle({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.semanticLabel,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final trackColor = value ? PosColors.primary : PosColors.surfaceSunk;
    final outlineColor = value ? Colors.transparent : PosColors.line;
    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged(!value) : null,
        child: SizedBox(
          width: 52,
          height: 44,
          child: Align(
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 52,
              height: 32,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: enabled ? trackColor : PosColors.line,
                borderRadius: BorderRadius.circular(PosRadii.toggle),
                border: Border.all(color: outlineColor, width: 1),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: PosColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: PosShadows.soft,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: spec.$1,
        borderRadius: BorderRadius.circular(PosRadii.xs),
        border: Border.all(color: spec.$2.withValues(alpha: 0.14), width: 1),
      ),
      child: Text(
        upper ? label.toUpperCase() : label,
        style: TextStyle(
          fontFamily: tfFontFamily(context),
          color: spec.$2,
          fontSize: 13,
          fontWeight: FontWeight.w600,
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
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: dark ? PosColors.primaryDark : PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadii.tile),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(PosRadii.tile),
                      border: Border.all(
                        color: dark ? PosColors.primaryDark : PosColors.line,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 20,
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
                    borderRadius: BorderRadius.circular(PosRadii.pill),
                    border: Border.all(color: PosColors.surface, width: 1.5),
                  ),
                  child: Text(
                    badge! > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      fontFamily: tfEnglishFontFamily,
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
// TfBarButton — Source-of-truth 42px square top-bar action button.
// ---------------------------------------------------------------------------
class TfBarButton extends StatelessWidget {
  const TfBarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.badge,
    this.accent = false,
    this.dot = false,
    super.key,
  });

  final TfSourceIconName icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final int? badge;
  final bool accent;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final hasBadge = badge != null && badge! > 0;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Material(
                color: accent ? PosColors.primary : PosColors.surface,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onPressed,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: accent
                            ? PosColors.primary
                            : PosColors.lineStrong,
                      ),
                    ),
                    child: Center(
                      child: TfSourceIcon(
                        name: icon,
                        size: 20,
                        color: accent
                            ? PosColors.accentInk
                            : PosColors.primaryDark,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (hasBadge)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: PosColors.danger,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: PosColors.background, width: 2),
                  ),
                  child: Text(
                    badge! > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      fontFamily: tfEnglishFontFamily,
                      height: 1,
                    ),
                  ),
                ),
              )
            else if (dot)
              Positioned(
                top: 9,
                right: 10,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: PosColors.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: PosColors.surface, width: 1.5),
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
          borderRadius: BorderRadius.circular(PosRadii.xl),
          border: Border.all(
            color: PosColors.primaryDark.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: PosShadows.fab,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(PosRadii.xl),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Icon(icon, color: PosColors.accentInk),
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
    this.badge,
  });
  final IconData icon;
  final String label;
  final String? labelBn;
  final IconData? selectedIcon;
  final int? badge;
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
        border: Border(top: BorderSide(color: PosColors.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
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
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? PosColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(
                                  PosRadii.pill,
                                ),
                              ),
                              child: Icon(
                                selected
                                    ? (it.selectedIcon ?? it.icon)
                                    : it.icon,
                                size: 22,
                                color: selected
                                    ? PosColors.accentInk
                                    : PosColors.muted,
                              ),
                            ),
                            if (it.badge != null && it.badge! > 0)
                              Positioned(
                                top: -2,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: PosColors.danger,
                                    borderRadius: BorderRadius.circular(
                                      PosRadii.pill,
                                    ),
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 16,
                                    minHeight: 16,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    it.badge! > 99 ? '99+' : '${it.badge}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        TfText(
                          isBn ? tfToBnNumbers(text) : text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? PosColors.slate : PosColors.muted,
                            height: 1,
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        boxShadow: PosShadows.bar,
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
// TfDualActionBar — Fixed bottom bar with two action buttons.
// ---------------------------------------------------------------------------
class TfDualActionBar extends StatelessWidget {
  const TfDualActionBar({required this.left, required this.right, super.key});

  final TfDualActionBarItem left;
  final TfDualActionBarItem right;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        boxShadow: PosShadows.bar,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TfButton(
                label: left.label,
                labelBn: left.labelBn,
                icon: left.icon,
                variant: TfButtonVariant.dark,
                onPressed: left.onPressed,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TfButton(
                label: right.label,
                labelBn: right.labelBn,
                icon: right.icon,
                variant: TfButtonVariant.primary,
                onPressed: right.onPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TfDualActionBarItem {
  const TfDualActionBarItem({
    required this.label,
    required this.onPressed,
    this.labelBn,
    this.icon,
  });

  final String label;
  final String? labelBn;
  final VoidCallback onPressed;
  final IconData? icon;
}

// ---------------------------------------------------------------------------
// TfSectionHeader — Soft POS section heading.
// ---------------------------------------------------------------------------
class TfSectionHeader extends StatelessWidget {
  const TfSectionHeader({
    required this.label,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(2, 0, 2, 12),
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
              label,
              style: TextStyle(
                fontFamily: tfFontFamily(context),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
                color: color == PosColors.muted ? PosColors.text : color,
                height: 1.25,
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
    this.onSubmitted,
    this.textInputAction,
    this.hintHelper,
    this.errorText, // Added primitive support for handling form invalidation feedback logic
    this.inputFormatters,
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
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final String? hintHelper;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;

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
                fontSize: 14,
                fontWeight: FontWeight.w600,
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
            textInputAction: textInputAction,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            inputFormatters: inputFormatters,
            style: TextStyle(
              fontFamily: tfFontFamily(context),
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: PosColors.slate,
            ),
            decoration: InputDecoration(
              hintText: hnt,
              prefixIcon: prefix,
              suffixIcon: suffix,
              errorText: errorText != null
                  ? (isBn ? tfToBnNumbers(errorText!) : errorText)
                  : null,
              errorStyle: TextStyle(
                fontFamily: tfFontFamily(context),
                fontSize: 13,
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
// TfSearchField — Soft POS rounded search input.
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
      height: 56,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(
          fontFamily: tfFontFamily(context),
          color: PosColors.slate,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: PosColors.primaryDark,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            fontFamily: tfFontFamily(context),
            color: PosColors.textTer,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: PosColors.textSec,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 44),
          filled: true,
          fillColor: PosColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.input),
            borderSide: const BorderSide(color: PosColors.line, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.input),
            borderSide: const BorderSide(color: PosColors.line, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.input),
            borderSide: const BorderSide(color: PosColors.lineStrong, width: 1),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.sm),
      ),
      child: Row(
        children: List.generate(items.length, (i) {
          final it = items[i];
          final selected = i == activeIndex;
          final text = isBn && (it.labelBn?.isNotEmpty ?? false)
              ? it.labelBn!
              : it.label;
          return Expanded(
            child: Material(
              color: selected ? PosColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(PosRadii.xs),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => onChanged(i),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PosRadii.xs),
                    border: Border.all(
                      color: selected ? PosColors.line : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TfText(
                        text,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          color: PosColors.slate,
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
                                ? PosColors.surfaceSunk
                                : PosColors.surface3,
                            borderRadius: BorderRadius.circular(PosRadii.chip),
                          ),
                          child: TfText(
                            '${it.count}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: PosColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
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
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: PosColors.slate,
              ),
            ),
            const SizedBox(height: 6),
            TfText(
              tfPick(context, en: message, bn: messageBn),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: PosColors.muted,
                height: 1.45,
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
                style: const TextStyle(
                  fontSize: 14,
                  color: PosColors.muted,
                  fontWeight: FontWeight.w500,
                ),
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
              fontWeight: FontWeight.w600,
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
                fontWeight: FontWeight.w700,
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

// ---------------------------------------------------------------------------
// TfDividerBand — Horizontal structural divider with center chip.
// ---------------------------------------------------------------------------
class TfDividerBand extends StatelessWidget {
  const TfDividerBand({required this.label, this.labelBn, super.key});
  final String label;
  final String? labelBn;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        const Expanded(
          child: Divider(color: PosColors.lineStrong, thickness: 1, height: 1),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: PosColors.surface,
            border: Border.all(color: PosColors.lineStrong, width: 1),
            borderRadius: BorderRadius.circular(PosRadii.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: PosColors.textTer,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              TfText(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: PosColors.textSec,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const Expanded(
          child: Divider(color: PosColors.lineStrong, thickness: 1, height: 1),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// TfDashTopBar — Compact app bar for dashboards.
// ---------------------------------------------------------------------------
class TfDashTopBar extends StatelessWidget {
  const TfDashTopBar({
    required this.outlet,
    this.mode,
    this.time,
    this.role,
    this.onRoleChange,
    this.drawer,
    this.drawerLabel = 'Drawer',
    super.key,
  });

  final String outlet;
  final String? mode;
  final String? time;
  final String? role;
  final ValueChanged<String>? onRoleChange;
  final String? drawer;
  final String drawerLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      outlet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: PosColors.text,
                        letterSpacing: -0.18,
                        height: 1.1,
                      ),
                    ),
                    if (mode != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: PosColors.surfaceSunk,
                          borderRadius: BorderRadius.circular(PosRadii.tag),
                          border: Border.all(color: PosColors.line, width: 1),
                        ),
                        child: Text(
                          mode!.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: tfEnglishFontFamily,
                            fontWeight: FontWeight.w700,
                            color: PosColors.textSec,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ),
                  ],
                ),
                if (time != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    time!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PosColors.textSec,
                      fontWeight: FontWeight.w500,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (role != null)
            TfCompactRoleToggle(
              key: const ValueKey('dashboard-view-dropdown'),
              role: role!,
              onChanged: onRoleChange!,
            ),
          if (drawer != null) ...[
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TfMicroLabel(drawerLabel, color: PosColors.textTer),
                const SizedBox(height: 2),
                Text(
                  drawer!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PosColors.text,
                    letterSpacing: -0.2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfCompactRoleToggle — Small segmented toggle for the app bar.
// ---------------------------------------------------------------------------
class TfCompactRoleToggle extends StatelessWidget {
  const TfCompactRoleToggle({
    required this.role,
    required this.onChanged,
    super.key,
  });

  final String role;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.input),
        border: Border.all(color: PosColors.line, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [_buildItem('Mgr', 'manager'), _buildItem('Owner', 'owner')],
      ),
    );
  }

  Widget _buildItem(String label, String value) {
    final on = role == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: on ? PosColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(PosRadii.tag),
          border: on
              ? Border.all(color: PosColors.lineStrong, width: 1)
              : Border.all(color: Colors.transparent, width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: on ? PosColors.text : PosColors.textSec,
            letterSpacing: -0.1,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfPeriodSelector — Primary control on the Owner screen.
// ---------------------------------------------------------------------------
class TfPeriodSelector extends StatelessWidget {
  const TfPeriodSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const List<String> periods = ['Today', 'Week', 'Month', 'Custom'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.tile),
        border: Border.all(color: PosColors.line, width: 1),
        boxShadow: PosShadows.soft,
      ),
      child: Row(
        children: periods.map((p) {
          final on = p == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: on ? PosColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(PosRadii.tag),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      p,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                        color: on ? PosColors.accentInk : PosColors.textSec,
                        letterSpacing: -0.1,
                      ),
                    ),
                    if (p == 'Custom') ...[
                      const SizedBox(width: 4),
                      Text(
                        '▾',
                        style: TextStyle(
                          fontSize: 10,
                          color: (on ? PosColors.accentInk : PosColors.textSec)
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfPeriodSubtitle — Baseline label under the selector.
// ---------------------------------------------------------------------------
class TfPeriodSubtitle extends StatelessWidget {
  const TfPeriodSubtitle({
    required this.range,
    required this.compare,
    super.key,
  });
  final String range;
  final String compare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            range,
            style: const TextStyle(
              fontSize: 12,
              color: PosColors.textSec,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'vs $compare',
            style: const TextStyle(
              fontSize: 11,
              color: PosColors.textTer,
              fontFamily: tfEnglishFontFamily,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.44,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfRingupSearch — Large search well + recent chips for manage-mode counters.
// ---------------------------------------------------------------------------
class TfRingupSearch extends StatelessWidget {
  const TfRingupSearch({
    required this.placeholder,
    this.recent = const [],
    this.onTap,
    this.onRecentTap,
    super.key,
  });

  final String placeholder;
  final List<String> recent;
  final VoidCallback? onTap;
  final ValueChanged<String>? onRecentTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.tile),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(PosRadii.tile),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PosRadii.tile),
                border: Border.all(color: PosColors.line, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    TfNavIcon.search,
                    size: 24,
                    color: PosColors.textTer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      placeholder,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: PosColors.textTer,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    decoration: BoxDecoration(
                      color: PosColors.surfaceSunk,
                      borderRadius: BorderRadius.circular(PosRadii.tag),
                      border: Border.all(color: PosColors.line, width: 1),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '⌘K',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PosColors.textSec,
                        fontFamily: tfEnglishFontFamily,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const TfMicroLabel('Recent'),
              for (final item in recent.take(3))
                GestureDetector(
                  onTap: onRecentTap == null ? null : () => onRecentTap!(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: PosColors.surface,
                      borderRadius: BorderRadius.circular(PosRadii.tile),
                      border: Border.all(color: PosColors.line, width: 1),
                    ),
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PosColors.text,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TfFohTile — Text-first ring-up tiles.
// ---------------------------------------------------------------------------
class TfFohTile extends StatelessWidget {
  const TfFohTile({
    required this.name,
    required this.price,
    this.category,
    this.glyph,
    this.imageUrl,
    this.iconKey,
    this.tint,
    this.qty = 0,
    this.onTap,
    super.key,
  });

  final String name;
  final String price;
  final String? category;
  final IconData? glyph;
  final String? imageUrl;
  final String? iconKey;
  final Color? tint;
  final int qty;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = qty > 0;
    return Material(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(PosRadii.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 102),
          padding: const EdgeInsets.fromLTRB(10, 8, 9, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.tile),
            border: Border.all(
              color: active ? PosColors.text : PosColors.line,
              width: active ? 1.8 : 1,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (active)
                Positioned(
                  top: -14,
                  right: -13,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 21),
                    height: 21,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: PosColors.text,
                      borderRadius: BorderRadius.circular(PosRadii.pill),
                      border: Border.all(color: PosColors.background, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$qty',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(PosRadii.tile),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child:
                        (imageUrl ?? '').trim().isNotEmpty ||
                            (iconKey ?? '').trim().isNotEmpty
                        ? MenuImageView(
                            imageUrl: imageUrl,
                            iconKey: iconKey,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            glyph ?? Icons.restaurant_outlined,
                            size: 24,
                            color: PosColors.textSec,
                          ),
                  ),
                ),
              ),
              Positioned(
                top: 52,
                left: 0,
                right: 0,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PosColors.text,
                    letterSpacing: 0,
                    height: 1.1,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Text(
                  price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PosColors.text,
                    letterSpacing: 0,
                    height: 1.1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
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
// TfFohCounter — Ring-up tile grid.
// ---------------------------------------------------------------------------
class TfFohCounter extends StatelessWidget {
  const TfFohCounter({
    required this.tiles,
    this.title = 'Counter · top sellers',
    this.action = 'Edit',
    this.onAction,
    this.cols = 3,
    super.key,
  });

  final String title;
  final List<TfFohTile> tiles;
  final String action;
  final VoidCallback? onAction;
  final int cols;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PosColors.text,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: PosColors.surface,
                  borderRadius: BorderRadius.circular(PosRadii.tag),
                  border: Border.all(color: PosColors.line, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(TfNavIcon.settings, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      action,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: tfEnglishFontFamily,
                        letterSpacing: 0.5,
                        color: PosColors.textSec,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: 102,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) => tiles[index],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// TfCreateOrderTray — Sticky cart summary above bottom nav.
// ---------------------------------------------------------------------------
class TfCreateOrderTray extends StatelessWidget {
  const TfCreateOrderTray({
    required this.count,
    required this.total,
    this.label = 'Create order',
    this.busy = false,
    this.onTap,
    super.key,
  });

  final int count;
  final String total;
  final String label;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 11, 11, 11),
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.tile),
          border: Border.all(color: PosColors.line, width: 1),
          boxShadow: PosShadows.raised,
        ),
        child: Row(
          children: [
            Expanded(child: TfMicroLabel('$count items in order')),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: busy ? null : onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: PosColors.primary,
                  borderRadius: BorderRadius.circular(PosRadii.input),
                  boxShadow: PosShadows.glow,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: PosColors.accentInk,
                        ),
                      )
                    else
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: PosColors.accentInk,
                        ),
                      ),
                    const SizedBox(width: 10),
                    Text(
                      total,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PosColors.accentInk,
                        letterSpacing: -0.3,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
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
// TfCollapsedSummary — Demoted today-summary for Manager screens.
// ---------------------------------------------------------------------------
class TfCollapsedSummary extends StatefulWidget {
  const TfCollapsedSummary({
    required this.cash,
    required this.orders,
    this.top,
    super.key,
  });

  final String cash;
  final int orders;
  final String? top;

  @override
  State<TfCollapsedSummary> createState() => _TfCollapsedSummaryState();
}

class _TfCollapsedSummaryState extends State<TfCollapsedSummary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const TfMicroLabel('Today so far'),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              widget.cash,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: PosColors.text,
                                letterSpacing: -0.3,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${widget.orders} orders',
                              style: const TextStyle(
                                fontSize: 12,
                                color: PosColors.textSec,
                                fontWeight: FontWeight.w500,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: PosColors.textSec,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: PosColors.divider, width: 1),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.top != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const TfMicroLabel('TOP ITEM'),
                        Text(
                          widget.top!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PosColors.text,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Text(
                    'Open the Reports tab for hour-by-hour and menu trends.',
                    style: TextStyle(
                      fontSize: 11,
                      color: PosColors.textTer,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TfLineChart — Excel-familiar revenue line.
// ---------------------------------------------------------------------------
class TfLineChart extends StatelessWidget {
  const TfLineChart({
    required this.today,
    this.yesterday,
    this.height = 140,
    this.todayLabel = 'Today',
    this.priorLabel = 'Prior',
    this.xLabels = const ['9 AM', '12 PM', '3 PM', '6 PM', '11 PM'],
    super.key,
  });

  final List<double> today;
  final List<double>? yesterday;
  final double height;
  final String todayLabel;
  final String priorLabel;
  final List<String> xLabels;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _LineChartPainter(
        today: today,
        yesterday: yesterday,
        todayLabel: todayLabel,
        priorLabel: priorLabel,
        xLabels: xLabels,
        isBn: tfIsBn(context),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.today,
    required this.yesterday,
    required this.todayLabel,
    required this.priorLabel,
    required this.xLabels,
    required this.isBn,
  });

  final List<double> today;
  final List<double>? yesterday;
  final String todayLabel;
  final String priorLabel;
  final List<String> xLabels;
  final bool isBn;

  @override
  void paint(Canvas canvas, Size size) {
    const double padL = 8;
    const double padR = 56;
    const double padTop = 18;
    const double padBot = 26;

    final double maxVal =
        ([
                  ...today,
                  ...(yesterday ?? [0.0]),
                ].reduce((a, b) => a > b ? a : b) *
                1.08)
            .clamp(1.0, double.infinity);
    final double innerW = size.width - padL - padR;
    final double innerH = size.height - padTop - padBot;

    // Gridlines
    final gridPaint = Paint()
      ..color = PosColors.divider
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 4; i++) {
      final y = padTop + innerH - (i / 4) * innerH;
      canvas.drawLine(Offset(padL, y), Offset(padL + innerW, y), gridPaint);
    }

    // Bottom border
    gridPaint.color = PosColors.lineStrong;
    canvas.drawLine(
      Offset(padL, padTop + innerH),
      Offset(padL + innerW, padTop + innerH),
      gridPaint,
    );

    Offset getPos(int index, double value, int total) {
      final x = padL + (index / (total - 1)) * innerW;
      final y = padTop + innerH - (value / maxVal) * innerH;
      return Offset(x, y);
    }

    // Draw Yesterday (dashed)
    if (yesterday != null && yesterday!.isNotEmpty) {
      final priorPaint = Paint()
        ..color = PosColors.textTer
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path();
      for (int i = 0; i < yesterday!.length; i++) {
        final pos = getPos(i, yesterday![i], yesterday!.length);
        if (i == 0) {
          path.moveTo(pos.dx, pos.dy);
        } else {
          path.lineTo(pos.dx, pos.dy);
        }
      }

      // Dashed effect implementation
      _drawDashedPath(canvas, path, priorPaint);

      // Prior end dot
      final lastPos = getPos(
        yesterday!.length - 1,
        yesterday!.last,
        yesterday!.length,
      );
      canvas.drawCircle(lastPos, 2, Paint()..color = PosColors.surface);
      canvas.drawCircle(
        lastPos,
        2,
        priorPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Prior labels
      _drawLabel(
        canvas,
        lastPos + const Offset(6, 4),
        _fmt(yesterday!.last),
        PosColors.textSec,
        10.5,
        FontWeight.w600,
      );
      _drawLabel(
        canvas,
        lastPos + const Offset(6, -7),
        priorLabel.toUpperCase(),
        PosColors.textTer,
        8.5,
        FontWeight.w600,
        letterSpacing: 0.4,
      );
    }

    // Draw Today
    if (today.isNotEmpty) {
      final todayPaint = Paint()
        ..color = PosColors.accent
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      for (int i = 0; i < today.length; i++) {
        final pos = getPos(i, today[i], today.length);
        if (i == 0) {
          path.moveTo(pos.dx, pos.dy);
        } else {
          path.lineTo(pos.dx, pos.dy);
        }
      }
      canvas.drawPath(path, todayPaint);

      // Today end dot
      final lastPos = getPos(today.length - 1, today.last, today.length);
      canvas.drawCircle(lastPos, 3, Paint()..color = PosColors.surface);
      canvas.drawCircle(
        lastPos,
        3,
        todayPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );

      // Today labels
      _drawLabel(
        canvas,
        lastPos + const Offset(6, 4),
        _fmt(today.last),
        PosColors.accent,
        10.5,
        FontWeight.w700,
      );
      _drawLabel(
        canvas,
        lastPos + const Offset(6, -7),
        todayLabel.toUpperCase(),
        PosColors.textSec,
        8.5,
        FontWeight.w600,
        letterSpacing: 0.4,
      );
    }

    // X Labels
    for (int i = 0; i < xLabels.length; i++) {
      final f = i / (xLabels.length - 1);
      final x = padL + f * innerW;
      final align = i == 0
          ? TextAlign.start
          : (i == xLabels.length - 1 ? TextAlign.end : TextAlign.center);
      _drawLabel(
        canvas,
        Offset(x, size.height - 8),
        xLabels[i],
        PosColors.textTer,
        9,
        FontWeight.w600,
        align: align,
        letterSpacing: 0.4,
      );
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashWidth = 3, dashSpace = 3;
    double distance = 0.0;
    for (final ui.PathMetric measure in path.computeMetrics()) {
      while (distance < measure.length) {
        canvas.drawPath(
          measure.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
      distance = 0.0;
    }
  }

  void _drawLabel(
    Canvas canvas,
    Offset offset,
    String text,
    Color color,
    double fontSize,
    FontWeight weight, {
    TextAlign align = TextAlign.start,
    double letterSpacing = 0.2,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: weight,
          fontFamily: tfEnglishFontFamily,
          letterSpacing: letterSpacing,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    tp.layout();
    double dx = offset.dx;
    if (align == TextAlign.center) {
      dx -= tp.width / 2;
    } else if (align == TextAlign.end) {
      dx -= tp.width;
    }
    tp.paint(canvas, Offset(dx, offset.dy - tp.height / 2));
  }

  String _fmt(double v) {
    final s = v >= 1000 ? '৳${(v / 1000).round()}k' : '৳${v.round()}';
    return isBn ? tfToBnNumbers(s) : s;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TfLineChartCard extends StatelessWidget {
  const TfLineChartCard({
    required this.title,
    required this.today,
    this.yesterday,
    this.todayLabel = 'Today',
    this.priorLabel = 'Prior',
    this.xLabels = const ['9 AM', '12 PM', '3 PM', '6 PM', '11 PM'],
    this.peakNote,
    super.key,
  });

  final String title;
  final List<double> today;
  final List<double>? yesterday;
  final String todayLabel;
  final String priorLabel;
  final List<String> xLabels;
  final String? peakNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line, width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                TfMicroLabel(title, color: PosColors.textSec),
                if (peakNote != null)
                  TfMicroLabel(peakNote!, color: PosColors.textSec),
              ],
            ),
          ),
          TfLineChart(
            today: today,
            yesterday: yesterday,
            todayLabel: todayLabel,
            priorLabel: priorLabel,
            xLabels: xLabels,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
            child: Row(
              children: [
                _LegendItem(label: todayLabel, color: PosColors.accent),
                if (yesterday != null) ...[
                  const SizedBox(width: 14),
                  _LegendItem(
                    label: priorLabel,
                    color: PosColors.textTer,
                    dashed: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.label,
    required this.color,
    this.dashed = false,
  });
  final String label;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          CustomPaint(
            size: const Size(16, 2),
            painter: _DashPainter(color: color),
          )
        else
          Container(
            width: 16,
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: PosColors.textSec),
        ),
      ],
    );
  }
}

class _DashPainter extends CustomPainter {
  _DashPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset.zero, const Offset(3, 0), paint);
    canvas.drawLine(const Offset(6, 0), const Offset(9, 0), paint);
    canvas.drawLine(const Offset(12, 0), const Offset(15, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// TfMenuPerfTable — Excel-like table for menu performance.
// ---------------------------------------------------------------------------
class TfMenuPerfRow {
  const TfMenuPerfRow({
    required this.name,
    required this.qty,
    required this.rev,
    this.share,
    this.margin,
    this.vsPrev,
    this.warn,
  });
  final String name;
  final int qty;
  final String rev;
  final String? share;
  final String? margin;
  final String? vsPrev;
  final String? warn;
}

class TfMenuPerfTable extends StatelessWidget {
  const TfMenuPerfTable({
    required this.rows,
    this.showMargin = false,
    super.key,
  });

  final List<TfMenuPerfRow> rows;
  final bool showMargin;

  @override
  Widget build(BuildContext context) {
    final cols = showMargin
        ? const [1.5, 0.6, 1.1, 0.7, 1.0]
        : const [1.6, 0.6, 1.1, 0.7, 1.0];
    final headers = showMargin
        ? ['Item', 'Qty', 'Revenue', 'Margin', 'vs prev']
        : ['Item', 'Qty', 'Revenue', 'Share', 'vs prev'];

    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.line, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            color: PosColors.surfaceSunk,
            child: _GridRow(
              flexes: cols,
              children: headers
                  .map((h) => TfMicroLabel(h, color: PosColors.textTer))
                  .toList(),
            ),
          ),
          // Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = rows[index];
              final deltaUp =
                  !(r.vsPrev ?? '').startsWith('-') &&
                  !(r.vsPrev ?? '').startsWith('−');
              final deltaCol = r.vsPrev == null || r.vsPrev == '—'
                  ? PosColors.textTer
                  : (deltaUp ? PosColors.good : PosColors.danger);

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: _GridRow(
                  flexes: cols,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 14,
                          child: TfMicroLabel('${index + 1}'.padLeft(2, '0')),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PosColors.text,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                        if (r.warn != null) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: PosColors.warnSoft,
                              borderRadius: BorderRadius.circular(PosRadii.tag),
                            ),
                            child: TfMicroLabel(
                              r.warn!,
                              color: PosColors.warn,
                              style: const TextStyle(fontSize: 9),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      '${r.qty}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      r.rev,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      showMargin ? (r.margin ?? '') : (r.share ?? ''),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        color: PosColors.textSec,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (r.vsPrev != null && r.vsPrev != '—')
                          Text(
                            deltaUp ? '↑' : '↓',
                            style: TextStyle(
                              color: deltaCol,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        const SizedBox(width: 3),
                        Text(
                          r.vsPrev ?? '—',
                          style: TextStyle(
                            fontSize: 12,
                            color: deltaCol,
                            fontWeight: FontWeight.w600,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GridRow extends StatelessWidget {
  const _GridRow({required this.flexes, required this.children});
  final List<double> flexes;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(children.length, (i) {
        return Expanded(flex: (flexes[i] * 100).toInt(), child: children[i]);
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// TfMenuPerfHeader — Sortable column chips.
// ---------------------------------------------------------------------------
class TfMenuPerfHeader extends StatelessWidget {
  const TfMenuPerfHeader({
    required this.sort,
    required this.onChanged,
    super.key,
  });
  final String sort;
  final ValueChanged<String> onChanged;

  static const List<Map<String, String>> sorts = [
    {'id': 'rev', 'l': 'Revenue'},
    {'id': 'qty', 'l': 'Qty'},
    {'id': 'margin', 'l': 'Margin'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
      child: Row(
        children: [
          const TfMicroLabel('Sort', color: PosColors.textTer),
          const SizedBox(width: 10),
          ...sorts.map((s) {
            final on = s['id'] == sort;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InkWell(
                onTap: () => onChanged(s['id']!),
                borderRadius: BorderRadius.circular(PosRadii.chip),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: on ? PosColors.accentSoft : PosColors.surface,
                    borderRadius: BorderRadius.circular(PosRadii.chip),
                    border: Border.all(
                      color: on ? Colors.transparent : PosColors.line,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        s['l']!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                          color: on
                              ? PosColors.accentSoftInk
                              : PosColors.textSec,
                        ),
                      ),
                      if (on) ...[
                        const SizedBox(width: 4),
                        const Opacity(
                          opacity: 0.7,
                          child: Text(
                            '▼',
                            style: TextStyle(
                              fontSize: 9,
                              color: PosColors.accentSoftInk,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
