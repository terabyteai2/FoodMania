import 'package:flutter/material.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';

// Re-export the brand tokens so desktop widgets import one file. The blue ramp
// (PosColors.primary #2F4FE0) already encodes the Petpooja-red → blue swap.
export 'package:local_pos/src/core/theme/app_theme.dart'
    show PosColors, PosSpacing, PosRadii, PosShadows;

/// Desktop-scale layout metrics, measured from the Petpooja desktop screens
/// (petpooja13–17). These are deliberately separate from the phone-tuned
/// `PosDensity` tokens — a desktop register packs a 3-pane billing layout on a
/// wide monitor, not a single scrolling column.
class DeskMetrics {
  DeskMetrics._();

  /// Slim top app bar (logo · New Order · Bill No · actions).
  static const double topBar = 56;

  /// Left category / navigation rail (petpooja13 left column).
  static const double railWidth = 212;

  /// Right checkout / cart panel (petpooja13 right column).
  static const double checkoutWidth = 428;

  static const double gap = 12;
  static const double pad = 16;
  static const double rowMin = 44;
  static const double radius = PosRadii.md; // 10

  // ── Design-reset geometry (DESIGN_RESET_REFERENCE.md) ────────────────────
  // The reset moves desktop surfaces toward the softer "consumeristic" card
  // language of the M1–M3 mockups: larger radii, roomier padding, chart-first
  // panels. These are DESKTOP-ONLY — the phone density system (PosRadii.card=10)
  // is deliberately not changed. Screens converge on `DeskCard`/`DeskStatTile`
  // (theme/desk_widgets.dart) rather than re-deriving these.
  /// Soft panel/card corner radius (M1–M3 rounded cards).
  static const double cardRadius = 16;

  /// Interior padding of a reset card/panel.
  static const double cardPad = 18;

  /// Gap between reset cards in a dashboard grid.
  static const double panelGap = 16;

  /// Smaller tile radius (stat tiles, chips, toggles-in-cards).
  static const double tileRadius = 12;

  /// Minimum window the layout is designed against.
  static const Size minWindow = Size(1180, 720);
}

/// Categorical chart palette for desktop analytics (M3). This is the design
/// system's own "QS stat-card" tint family — validated colorblind-safe as a
/// categorical set (scripts/validate_palette.js: all six checks PASS, worst
/// adjacent CVD ΔE 27.3). Hues are assigned in this FIXED order and never
/// cycled; a series past the 5th folds into "Other". `tint` is the matching
/// low-chroma wash for tracks / donut gaps. Text never wears these — labels use
/// ink tokens; the mark beside them carries identity.
class DeskChart {
  DeskChart._();

  static const List<Color> series = <Color>[
    PosColors.iconBlue, // #2F6FB0
    PosColors.iconGreen, // #2E9E63
    PosColors.iconAmber, // #9A7400
    PosColors.iconRed, // #C0454B  (analytics tint — not status)
    PosColors.iconPurple, // #7C5CD6
  ];

  static const List<Color> tint = <Color>[
    PosColors.tintBlue,
    PosColors.tintGreen,
    PosColors.tintAmber,
    PosColors.tintRed,
    PosColors.tintPurple,
  ];

  /// Recessive gridline / baseline colour for chart axes.
  static const Color grid = PosColors.line;

  /// Hue for a series at [index], folding anything past the 5th onto muted grey.
  static Color hue(int index) =>
      index < series.length ? series[index] : PosColors.muted;

  static Color hueTint(int index) =>
      index < tint.length ? tint[index] : PosColors.surfaceSunk;
}

/// Base Material theme for the desktop app. Reuses the mobile [AppTheme.light]
/// (fonts + blue color scheme) and tightens density for a mouse/keyboard POS.
ThemeData deskThemeData() {
  final base = AppTheme.light();
  return base.copyWith(
    visualDensity: VisualDensity.compact,
    scrollbarTheme: const ScrollbarThemeData(
      thumbVisibility: WidgetStatePropertyAll<bool>(true),
      thickness: WidgetStatePropertyAll<double>(8),
    ),
  );
}
