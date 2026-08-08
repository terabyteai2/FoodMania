import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Token bridge for the desktop "Computer OS" surface.
///
/// The JSX source-of-truth (`tf-pc-*.jsx`) references a `DASH` / `PC.C.*`
/// token set. Those map 1:1 onto the existing [PosColors] deep-plum system, so
/// this class is a thin alias layer — no new colour literals are introduced.
/// Numerics use Inter with tabular figures; "mono" labels use the bundled
/// Inter family (already declared in pubspec.yaml).
class Pc {
  Pc._();

  // Surfaces ----------------------------------------------------------------
  static const Color bg = PosColors.background; // paper
  static const Color surface = PosColors.surface; // cards / panels
  static const Color surfaceAlt = PosColors.surfaceSunk; // wells, header rows

  // Ink + text --------------------------------------------------------------
  static const Color ink = PosColors.primaryDark; // hero numerics, headings
  static const Color inkRaised = PosColors.inkSoft; // donut segments, dark fill
  static const Color text = PosColors.primaryDark;
  static const Color textSec = PosColors.muted;
  static const Color textTer = PosColors.mutedSoft;
  static const Color onInk = Colors.white;

  // Borders -----------------------------------------------------------------
  static const Color border = PosColors.line;
  static const Color borderStrong = PosColors.lineStrong;

  // Accent — deep plum ------------------------------------------------------
  static const Color accent = PosColors.primary;
  static const Color accentDeep = PosColors.primaryDeep;
  static const Color accentMid = PosColors.primaryMid;
  static const Color accentSoft = PosColors.primarySoft;
  static const Color accentWash = PosColors.primaryWash;
  static const Color accentInk = PosColors.accentInk;

  // Functional signals ------------------------------------------------------
  static const Color good = PosColors.success;
  static const Color goodSoft = PosColors.successSoft;
  static const Color warn = PosColors.warning;
  static const Color warnSoft = PosColors.warningSoft;
  static const Color danger = PosColors.danger;
  static const Color dangerSoft = PosColors.dangerSoft;
  // Late orders / expedite — burnt orange, never red (per design rules).
  static const Color late = PosColors.urgent;
  static const Color lateSoft = PosColors.urgentSoft;

  // Shadows -----------------------------------------------------------------
  static const List<BoxShadow> shadowSoft = PosShadows.soft;
  static const List<BoxShadow> shadowRaised = PosShadows.raised;

  // Geometry ----------------------------------------------------------------
  static const double railW = 72;
  static const double topbar = 56;
  static const double footer = 28;

  // Radii (mirror PosRadii) -------------------------------------------------
  static const double rXs = PosRadii.xs;
  static const double rSm = PosRadii.sm;
  static const double rMd = PosRadii.md;
  static const double rPill = PosRadii.pill;

  static const String monoFamily = 'Inter';

  /// Tabular-figure numeric style on the bundled Inter family.
  static TextStyle num(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = ink,
    double letterSpacing = 0,
    double? height,
  }) => TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: const ['Noto Sans Bengali'],
    fontFeatures: const [FontFeature.tabularFigures()],
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  /// Monospace style for eyebrows, keyboard hints and dense metadata.
  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = textSec,
    double letterSpacing = 0.4,
  }) => TextStyle(
    fontFamily: monoFamily,
    fontFeatures: const [FontFeature.tabularFigures()],
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
  );
}

/// Taka amount with thousands grouping, e.g. `৳1,082` / `-৳50`.
String pcMoney(num value, {int decimals = 0}) {
  final negative = value < 0;
  final fixed = value.abs().toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
    buffer.write(intPart[i]);
  }
  final grouped = parts.length > 1 ? '$buffer.${parts[1]}' : buffer.toString();
  return '${negative ? '-' : ''}৳$grouped';
}

/// Visual state of a dine-in table on the floor map.
enum PcTableState { idle, seated, kitchen, served, bill, late }

class PcTableStyle {
  const PcTableStyle({
    required this.bg,
    required this.border,
    required this.fg,
    required this.dot,
    required this.label,
  });

  final Color bg;
  final Color border;
  final Color fg;
  final Color dot;
  final String label;

  static PcTableStyle of(PcTableState state) => switch (state) {
    PcTableState.idle => const PcTableStyle(
      bg: Pc.surface,
      border: Pc.border,
      fg: Pc.textSec,
      dot: Pc.textTer,
      label: 'FREE',
    ),
    PcTableState.seated => const PcTableStyle(
      bg: Pc.accentWash,
      border: Pc.accent,
      fg: Pc.ink,
      dot: Pc.accent,
      label: 'SEATED',
    ),
    PcTableState.kitchen => const PcTableStyle(
      bg: Pc.warnSoft,
      border: Pc.warn,
      fg: Pc.ink,
      dot: Pc.warn,
      label: 'IN KITCHEN',
    ),
    PcTableState.served => const PcTableStyle(
      bg: Pc.goodSoft,
      border: Pc.good,
      fg: Pc.ink,
      dot: Pc.good,
      label: 'SERVED',
    ),
    PcTableState.bill => const PcTableStyle(
      bg: Pc.surfaceAlt,
      border: Pc.ink,
      fg: Pc.ink,
      dot: Pc.ink,
      label: 'BILL',
    ),
    PcTableState.late => const PcTableStyle(
      bg: Pc.lateSoft,
      border: Pc.late,
      fg: Pc.ink,
      dot: Pc.late,
      label: 'LATE',
    ),
  };
}
