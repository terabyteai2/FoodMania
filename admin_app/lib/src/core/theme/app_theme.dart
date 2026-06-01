import 'package:flutter/material.dart';

enum PosThemeTone { dark, light }

// ---------------------------------------------------------------------------
// PosColors — Deep Plum design system
// Accent (#4C1D5E) covers ≤ 5% of any screen. 95% remains near-monochrome.
// Dominance Rule: one full-saturation accent per viewport.
// ---------------------------------------------------------------------------
class PosColors {
  // Accent — Deep Plum (≤ 5% of viewport per Dominance Rule)
  static const Color primary = Color(0xFF4C1D5E);      // accent — CTAs, FAB, focused states
  static const Color primaryDeep = Color(0xFF351244);  // accentDeep — pressed states
  static const Color primaryMid = Color(0xFF6B3080);   // accentMid — secondary CTAs
  static const Color primarySoft = Color(0xFFE8D8F0);  // accentSoft — selected backgrounds
  static const Color primaryWash = Color(0xFFF4EDF8);  // accentWash — hover tints only
  static const Color accentInk = Color(0xFFFFFFFF);    // text/icons on accent surfaces

  // Ink — Violet-black (tonally related to accent)
  static const Color primaryDark = Color(0xFF16101E);  // ink — primary text, headings
  static const Color inkSoft = Color(0xFF2D2438);      // inkSoft — secondary emphasis

  // Scaffold — Neutral-cool violet base
  static const Color background = Color(0xFFF8F8FA);   // paper — scaffold background
  static const Color surface = Color(0xFFFFFFFF);      // surface — cards, sheets, inputs
  static const Color surfaceSunk = Color(0xFFF1F1F5);  // surfaceSunk — search wells, fills

  // Secondary text
  static const Color muted = Color(0xFF635B6E);        // muted — secondary text, helpers
  static const Color mutedSoft = Color(0xFFA097AB);    // mutedSoft — captions only

  // Borders
  static const Color line = Color(0xFFE2DDE8);         // line — 0.5px default borders
  static const Color lineStrong = Color(0xFFCAC3D4);   // lineStrong — active/focused

  // Signals — functional only, never decorative
  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFF7F1D1D);
  static const Color dangerSoft = Color(0xFFFEE2E2);
  static const Color urgent = Color(0xFF9A3412);       // late orders, expedite signals
  static const Color urgentSoft = Color(0xFFFFEDD5);

  // ---------------------------------------------------------------------------
  // Aliases — kept for backward compatibility with existing screens
  // ---------------------------------------------------------------------------
  static const Color accent = primary;
  static const Color accentSoft = primarySoft;
  static const Color accentDeep = primaryDeep;
  static const Color accentMid = primaryMid;
  static const Color accentWash = primaryWash;
  static const Color slate = primaryDark;          // ink alias
  static const Color slateSoft = inkSoft;
  static const Color primaryGlow = primary;
  static const Color surfaceWarm = background;
  static const Color surfaceTinted = surface;
  static const Color info = muted;
  static const Color coral = urgent;               // coral → urgent
  static const Color coralSoft = urgentSoft;
  static const Color coralWash = urgentSoft;
  // purple kept neutral
  static const Color purple = muted;

  static PosThemeTone get tone => PosThemeTone.light;
  static void setTone(PosThemeTone tone) {}
}

// ---------------------------------------------------------------------------
// PosSpacing — 6-step spatial scale
// ---------------------------------------------------------------------------
class PosSpacing {
  static const double sp1 = 4;
  static const double sp2 = 8;
  static const double sp3 = 12;
  static const double sp4 = 16;
  static const double sp5 = 24;
  static const double sp6 = 32;
}

// ---------------------------------------------------------------------------
// PosRadii
// ---------------------------------------------------------------------------
class PosRadii {
  static const double xs = 6;    // badges, signal chips
  static const double sm = 10;   // inputs, small buttons, tags
  static const double md = 14;   // cards, sheets, dialogs
  static const double lg = 14;   // alias → md
  static const double xl = 14;   // alias → md
  static const double pill = 999;
}

// ---------------------------------------------------------------------------
// PosShadows — cast in violet-black rgb(22,16,30), blur ≤ 12px
// ---------------------------------------------------------------------------
class PosShadows {
  // Stat tiles, KPI cards on surface
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x0D16101E), blurRadius: 2, offset: Offset(0, 1)),
  ];
  // Raised cards, FAB, active list items
  static const List<BoxShadow> glow = [
    BoxShadow(color: Color(0x1216101E), blurRadius: 12, offset: Offset(0, 4)),
  ];
  // Sticky CTAs, bottom sheets, dialogs
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1716101E), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // Alias used in older screens
  static const List<BoxShadow> card = soft;
}

class PosGradients {
  static const LinearGradient brand = LinearGradient(
    colors: [PosColors.primary, PosColors.primaryDeep],
  );

  static const LinearGradient brandDeep = LinearGradient(
    colors: [PosColors.primaryDark, PosColors.primaryDark],
  );

  static LinearGradient softWash({double opacity = 1}) => const LinearGradient(
    colors: [PosColors.background, PosColors.background],
  );

  static LinearGradient cardTint(Color color) =>
      const LinearGradient(colors: [PosColors.surface, PosColors.surface]);
}

class AppTheme {
  static ThemeData dark({double uiScale = 1.0}) => light(uiScale: uiScale);

  static ThemeData light({double uiScale = 1.0}) {
    PosColors.setTone(PosThemeTone.light);
    return _build(uiScale: uiScale);
  }

  static ThemeData _build({required double uiScale}) {
    final scale = uiScale.clamp(0.78, 1.08).toDouble();
    double s(double value) => (value * scale).toDouble();

    const colorScheme = ColorScheme.light(
      primary: PosColors.primary,
      onPrimary: PosColors.accentInk,
      secondary: PosColors.primaryDark,
      onSecondary: Colors.white,
      surface: PosColors.surface,
      onSurface: PosColors.primaryDark,
      error: PosColors.danger,
      onError: Colors.white,
    );

    final baseText = TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Hind Siliguri', 'Noto Sans Bengali'],
      color: PosColors.primaryDark,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PosColors.background,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Hind Siliguri', 'Noto Sans Bengali'],
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
        // Display — hero metrics, one per screen
        displaySmall: baseText.copyWith(
          fontSize: s(36),
          fontWeight: FontWeight.w700,
          height: 1.05,
          letterSpacing: -0.03 * 36,
        ),
        headlineMedium: baseText.copyWith(
          fontSize: s(28),
          fontWeight: FontWeight.w700,
          height: 1.06,
          letterSpacing: -0.03 * 28,
        ),
        // Title — card headers, section headers
        titleLarge: baseText.copyWith(
          fontSize: s(18),
          fontWeight: FontWeight.w600,
          height: 1.25,
          letterSpacing: -0.01 * 18,
        ),
        titleMedium: baseText.copyWith(
          fontSize: s(15),
          fontWeight: FontWeight.w600,
          height: 1.30,
          letterSpacing: -0.01 * 15,
        ),
        titleSmall: baseText.copyWith(
          fontSize: s(13),
          fontWeight: FontWeight.w600,
          height: 1.30,
        ),
        // Body — readable content
        bodyLarge: baseText.copyWith(fontSize: s(15), height: 1.55),
        bodyMedium: baseText.copyWith(
          fontSize: s(14),
          color: PosColors.muted,
          height: 1.50,
        ),
        bodySmall: baseText.copyWith(
          fontSize: s(12),
          color: PosColors.muted,
          height: 1.45,
        ),
        // Label — buttons, tab labels
        labelLarge: baseText.copyWith(
          fontSize: s(14),
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        labelSmall: baseText.copyWith(
          fontSize: s(11),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.07 * 11,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: PosColors.background,
        foregroundColor: PosColors.primaryDark,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        color: PosColors.surface,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          side: const BorderSide(color: PosColors.line, width: 0.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PosColors.surface,
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
          borderSide: const BorderSide(color: PosColors.lineStrong, width: 1),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.sm),
          borderSide: const BorderSide(color: PosColors.danger, width: 0.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.sm),
          borderSide: const BorderSide(color: PosColors.danger, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: s(14),
          vertical: s(13),
        ),
        labelStyle: const TextStyle(
          color: PosColors.muted,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: const TextStyle(color: PosColors.muted),
        prefixIconColor: PosColors.muted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(
          background: PosColors.primary,
          foreground: PosColors.accentInk,
          height: s(50),
          radius: PosRadii.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          background: PosColors.primary,
          foreground: PosColors.accentInk,
          height: s(50),
          radius: PosRadii.md,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(s(44), s(42)),
          foregroundColor: PosColors.primaryDark,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: PosColors.lineStrong, width: 0.5),
          padding: EdgeInsets.symmetric(horizontal: s(14), vertical: s(10)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm),
          ),
          textStyle: TextStyle(
            fontSize: s(14),
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PosColors.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: PosColors.primaryDark,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: s(70),
        backgroundColor: PosColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: PosColors.primarySoft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.xs),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: s(11),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? PosColors.primaryDark : PosColors.mutedSoft,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: s(22),
            color: selected ? PosColors.primaryDark : PosColors.mutedSoft,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: PosColors.surface,
        selectedIconTheme: IconThemeData(color: PosColors.primaryDark, size: s(21)),
        unselectedIconTheme: IconThemeData(color: PosColors.mutedSoft, size: s(20)),
        selectedLabelTextStyle: TextStyle(
          color: PosColors.primaryDark,
          fontWeight: FontWeight.w600,
          fontSize: s(12),
        ),
        unselectedLabelTextStyle: TextStyle(
          color: PosColors.mutedSoft,
          fontWeight: FontWeight.w400,
          fontSize: s(12),
        ),
        indicatorColor: PosColors.primarySoft,
        useIndicator: true,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? PosColors.primaryDark
                : PosColors.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? Colors.white
                : PosColors.primaryDark,
          ),
          side: WidgetStateProperty.all(
            const BorderSide(color: PosColors.line, width: 0.5),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosRadii.pill),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: PosColors.surface,
        selectedColor: PosColors.primaryDark,
        side: const BorderSide(color: PosColors.line, width: 0.5),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 13,
          color: PosColors.primaryDark,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.pill),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? PosColors.accentInk
              : PosColors.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? PosColors.primary
              : PosColors.line,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      dividerTheme: const DividerThemeData(
        color: PosColors.line,
        thickness: 0.5,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: PosColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          side: const BorderSide(color: PosColors.line, width: 0.5),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: ['Hind Siliguri', 'Noto Sans Bengali'],
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: PosColors.primaryDark,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: ['Hind Siliguri', 'Noto Sans Bengali'],
          fontSize: 14,
          color: PosColors.muted,
          height: 1.50,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: PosColors.surface,
        modalBackgroundColor: PosColors.surface,
        showDragHandle: true,
        dragHandleColor: PosColors.line,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(PosRadii.md)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: PosColors.primaryDark,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w400,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.sm),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: PosColors.primaryDark,
          borderRadius: BorderRadius.circular(PosRadii.xs),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PosColors.primary,
        linearTrackColor: PosColors.line,
        circularTrackColor: PosColors.line,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: PosColors.primary,
        inactiveTrackColor: PosColors.line,
        thumbColor: PosColors.primaryDeep,
        overlayColor: PosColors.primary.withValues(alpha: 0.12),
        valueIndicatorColor: PosColors.primaryDark,
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static ButtonStyle _buttonStyle({
    required Color background,
    required Color foreground,
    required double height,
    required double radius,
  }) {
    return FilledButton.styleFrom(
      minimumSize: Size(44, height),
      backgroundColor: background,
      foregroundColor: foreground,
      disabledBackgroundColor: PosColors.line,
      disabledForegroundColor: PosColors.muted,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
      ),
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}
