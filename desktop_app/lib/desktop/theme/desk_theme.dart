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
  static const double topBar = 60;

  /// Left navigation rail — widened for larger icons + labels (web target).
  static const double railWidth = 240;

  /// Right checkout / cart panel (widened for larger controls).
  static const double checkoutWidth = 400;

  /// Billing category rail width (colored category list).
  static const double categoryRailWidth = 190;

  static const double gap = 16;
  static const double pad = 20;
  static const double rowMin = 52;
  static const double radius = PosRadii.md; // 10

  // ── Design-reset geometry (DESIGN_RESET_REFERENCE.md) ────────────────────
  // The reset moves desktop surfaces toward the softer "consumeristic" card
  // language of the M1–M3 mockups: larger radii, roomier padding, chart-first
  // panels. These are DESKTOP-ONLY — the phone density system (PosRadii.card=10)
  // is deliberately not changed. Screens converge on `DeskCard`/`DeskStatTile`
  // (theme/desk_widgets.dart) rather than re-deriving these.
  /// Soft panel/card corner radius (web target — softer rounded cards).
  static const double cardRadius = 10;

  /// Interior padding of a reset card/panel.
  static const double cardPad = 20;

  /// Gap between reset cards in a dashboard grid.
  static const double panelGap = 24;

  /// Smaller tile radius (stat tiles, chips, toggles-in-cards).
  static const double tileRadius = 8;

  /// Table tile height (FOH grid).
  static const double tableTileHeight = 92;

  /// Table tile corner radius.
  static const double tableTileRadius = 12;

  /// Item tile minimum height (billing grid).
  static const double itemTileMinHeight = 64;

  /// Service tab strip height.
  static const double serviceTabHeight = 44;

  /// Input field height (search / shortcode).
  static const double inputHeight = 40;

  /// Minimum window the layout is designed against.
  static const Size minWindow = Size(1180, 720);
}

// ---------------------------------------------------------------------------
// DeskTypography — Petpooja desktop font scale (DESIGN.md §3)
//
// Measured from the target screenshots (target1–target8). Desktop uses
// larger, more readable type than the phone-tuned AppTheme while keeping
// the same weight/role mapping. Screens and shared widgets must reference
// these tokens rather than hard-coding sizes.
// ---------------------------------------------------------------------------
class DeskTypography {
  DeskTypography._();

  // ── Display / Hero ────────────────────────────────────────────────────────
  static const double display = 24; // screen title (tab root)
  static const double displayPushed = 22; // pushed screen title
  static const double hero = 32; // money hero (payment total)

  // ── Headers ─────────────────────────────────────────────────────────────
  static const double h1 = 20; // page title (desktop top-level)
  static const double h2 = 16; // card / panel title
  static const double h3 = 15; // section subheader / price row

  // ── Content ─────────────────────────────────────────────────────────────
  static const double title = 15; // row/tile/item name (primary content)
  static const double body = 14; // body text
  static const double bodySmall = 13; // secondary / muted body
  static const double caption = 12; // tertiary captions

  // ── Functional ────────────────────────────────────────────────────────────
  static const double tab = 15; // tab labels (Dine In / Delivery / Pick Up)
  static const double nav = 14; // sidebar nav item
  static const double navSelected = 14; // sidebar nav selected
  static const double button = 13; // action button label
  static const double label = 13; // status labels, badges
  static const double eyebrow = 11; // uppercase kicker

  // ── Special ─────────────────────────────────────────────────────────────
  static const double tableNumber = 22; // FOH table tile number hero
  static const double tableMeta = 13; // FOH table tile meta (seats, elapsed)
  static const double orderSerial = 18; // order list serial number
  static const double moneyRow = 16; // money in list rows
  static const double itemPrice = 13; // item grid price
  static const double statValue = 26; // dashboard stat value
  static const double statLabel = 13; // dashboard stat label
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
/// The [textTheme] is overridden with [DeskTypography] so every screen that
/// consumes the Material text scale automatically matches the Petpooja target.
ThemeData deskThemeData() {
  final base = AppTheme.light();
  final ink = PosColors.primaryDark;
  final mut = PosColors.muted;
  final baseText = TextStyle(
    fontFamily: 'Plus Jakarta Sans',
    fontFamilyFallback: const ['Hind Siliguri', 'Noto Sans Bengali'],
    color: ink,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  return base.copyWith(
    visualDensity: VisualDensity.compact,
    scrollbarTheme: const ScrollbarThemeData(
      thumbVisibility: WidgetStatePropertyAll<bool>(true),
      thickness: WidgetStatePropertyAll<double>(8),
    ),
    textTheme: TextTheme(
      displaySmall: baseText.copyWith(
        fontSize: DeskTypography.display,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      displayMedium: baseText.copyWith(
        fontSize: DeskTypography.displayPushed,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      headlineMedium: baseText.copyWith(
        fontSize: DeskTypography.hero,
        fontWeight: FontWeight.w800,
        height: 1.05,
        letterSpacing: -0.02 * 32,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      titleLarge: baseText.copyWith(
        fontSize: DeskTypography.h2,
        fontWeight: FontWeight.w700,
        height: 1.30,
      ),
      titleMedium: baseText.copyWith(
        fontSize: DeskTypography.h3,
        fontWeight: FontWeight.w700,
        height: 1.26,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      titleSmall: baseText.copyWith(
        fontSize: DeskTypography.title,
        fontWeight: FontWeight.w600,
        height: 1.30,
      ),
      bodyLarge: baseText.copyWith(
        fontSize: DeskTypography.body,
        height: 1.50,
      ),
      bodyMedium: baseText.copyWith(
        fontSize: DeskTypography.bodySmall,
        color: mut,
        height: 1.45,
      ),
      bodySmall: baseText.copyWith(
        fontSize: DeskTypography.caption,
        color: mut,
        height: 1.30,
      ),
      labelLarge: baseText.copyWith(
        fontSize: DeskTypography.label,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelSmall: baseText.copyWith(
        fontSize: DeskTypography.eyebrow,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.05 * 11,
      ),
    ),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: baseText.copyWith(
        fontSize: DeskTypography.displayPushed,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
    ),
  );
}
