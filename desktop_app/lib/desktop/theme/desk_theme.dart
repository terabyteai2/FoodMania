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

  /// Minimum window the layout is designed against.
  static const Size minWindow = Size(1180, 720);
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
