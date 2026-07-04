import 'package:flutter/material.dart';

enum PosThemeTone { dark, light }

// ---------------------------------------------------------------------------
// PosColors — Volt POS lime design system (design_rules.md §2)
// One accent (#99FF47 lime) = go / primary / positive / active.
// Ink-on-lime (#14180E), never white. Borders not shadows. Crisp corners ≤12.
// ---------------------------------------------------------------------------
class PosColors {
  // ── Accent — lime ramp ──────────────────────────────────────────────────
  static const Color lime50 = Color(0xFFF3FDE7);
  static const Color lime100 = Color(0xFFE4FBC9);
  static const Color lime200 = Color(0xFFCDF79B);
  static const Color lime300 = Color(0xFFB4F46E);
  static const Color lime400 = Color(0xFF99FF47); // accent
  static const Color lime500 = Color(0xFF84F02C); // press
  static const Color lime600 = Color(0xFF67C81E);
  static const Color lime700 = Color(0xFF498F18); // accent-strong
  static const Color lime800 = Color(0xFF2F5E14);
  static const Color lime900 = Color(0xFF1E3D0F);

  // ── Primary tokens ──────────────────────────────────────────────────────
  static const Color primary = lime400; // #99FF47
  static const Color primaryDeep = lime500; // press state #84F02C
  static const Color primaryMid = lime600; // secondary emphasis
  static const Color primarySoft = Color(0xFFEAF7D6); // accent-tint
  static const Color primaryWash = lime200; // accent-tint-2
  static const Color accentInk = Color(0xFF14180E); // dark ink on lime fills
  static const Color accentSoftInk = Color(0xFF14180E); // text on accentSoft
  static const Color accentStrong = lime700; // #498F18 lime text on light
  static const Color accentOnInk = lime400; // lime on dark backgrounds

  // ── Ink — dark green-black ──────────────────────────────────────────────
  static const Color primaryDark = Color(0xFF14180E); // ink
  static const Color inkSoft = Color(0xFF4C5142); // ink-2
  static const Color onInk = Color(0xFFF1F4EC); // text on dark
  static const Color onInkSec = Color(0xB3F1F4EC); // white-ish 0.70
  static const Color onInkTer = Color(0x7AF1F4EC); // white-ish 0.48

  // ── Scaffold — LIGHT (neutral green-tinted) ─────────────────────────────
  static const Color background = Color(0xFFF3F5EE); // bg
  static const Color surface = Color(0xFFFFFFFF); // surface
  static const Color surfaceSunk = Color(0xFFECEFE4); // surface-2
  static const Color surface3 = Color(0xFFE2E6D8); // surface-3
  static const Color track = Color(0xFFECEFE4);
  static const Color trackInk = Color(0x2414180E);

  // ── Secondary text ──────────────────────────────────────────────────────
  static const Color muted = Color(0xFF7C8270); // muted
  static const Color mutedSoft = Color(0xFFA4A997); // placeholder

  // ── Borders ─────────────────────────────────────────────────────────────
  static const Color line = Color(0xFFE6E9DD); // line
  static const Color lineStrong = Color(0xFFD4D8C7); // line-2
  static const Color divider = Color(0xFFE6E9DD);

  // ── Signals (lime IS success; rest avoid green) ─────────────────────────
  static const Color success = Color(0xFF498F18);
  static const Color successSoft = Color(0xFFE4FBC9);
  static const Color good = success;
  static const Color goodSoft = successSoft;
  static const Color warning = Color(0xFFB0760A);
  static const Color warningSoft = Color(0xFFFBEFCD);
  static const Color warn = warning;
  static const Color warnSoft = warningSoft;
  static const Color danger = Color(0xFFD43A3F);
  static const Color dangerSoft = Color(0xFFFBE3E2);
  static const Color urgent = Color(0xFFB0760A); // late = warm amber
  static const Color urgentSoft = Color(0xFFFBEFCD);
  static const Color late = urgent;
  static const Color lateSoft = urgentSoft;
  static const Color info = Color(0xFF3E6FE0);
  static const Color infoSoft = Color(0xFFE3EAFC);

  // ── Backward-compatible aliases ─────────────────────────────────────────
  static const Color accent = primary;
  static const Color accentSoft = primarySoft;
  static const Color accentDeep = primaryDeep;
  static const Color accentMid = primaryMid;
  static const Color accentWash = primaryWash;
  static const Color slate = primaryDark; // ink alias
  static const Color slateSoft = inkSoft;
  static const Color text = primaryDark;
  static const Color textSec = muted;
  static const Color textTer = mutedSoft;
  static const Color primaryGlow = primary;
  static const Color surfaceWarm = background;
  static const Color surfaceTinted = surface;
  static const Color coral = urgent;
  static const Color coralSoft = urgentSoft;
  static const Color coralWash = urgentSoft;
  static const Color purple = muted;

  static PosThemeTone get tone => PosThemeTone.light;
  static void setTone(PosThemeTone tone) {}
}

// ---------------------------------------------------------------------------
// PosSpacing — base-4 spatial scale (design_rules.md §4)
// ---------------------------------------------------------------------------
class PosSpacing {
  static const double sp1 = 4;
  static const double sp2 = 8;
  static const double sp3 = 12;
  static const double sp4 = 16;
  static const double sp5 = 20;
  static const double sp6 = 24;
  static const double sp7 = 32;
  static const double sp8 = 40;
}

// ---------------------------------------------------------------------------
// PosRadii — crisp square-leaning corners ≤12px (design_rules.md §4)
// ---------------------------------------------------------------------------
class PosRadii {
  static const double xs = 3; // badges, signal chips
  static const double sm = 5; // inputs, small buttons, tags
  static const double md = 7; // cards, sheets, dialogs
  static const double lg = 9; // larger cards
  static const double xl = 12; // max radius
  static const double pill = 999; // toggles only
  // Backward-compatible aliases
  static const double card = md;
  static const double input = sm;
  static const double tile = md;
  static const double chip = sm; // crisp chips, not pill
  static const double toggle = 999;
  static const double tag = xs;
}

// ---------------------------------------------------------------------------
// PosShadows — minimal, only for sheets/modals/sticky bars (§4)
// ---------------------------------------------------------------------------
class PosShadows {
  static const List<BoxShadow> soft = [];
  static const List<BoxShadow> glow = [
    BoxShadow(color: Color(0x0D14180E), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> bar = [
    BoxShadow(color: Color(0x0D14180E), blurRadius: 16, offset: Offset(0, -4)),
  ];
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x1414180E), blurRadius: 32, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> card = soft;
}

class PosGradients {
  static const LinearGradient brand = LinearGradient(
    colors: [PosColors.primary, PosColors.primaryDeep],
  );

  static const LinearGradient brandDeep = LinearGradient(
    colors: [PosColors.primaryDark, PosColors.primaryDark],
  );

  static LinearGradient softWash({double opacity = 1}) => LinearGradient(
    colors: [
      PosColors.background.withValues(alpha: opacity),
      PosColors.background.withValues(alpha: 0),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static LinearGradient cardTint(Color color) =>
      LinearGradient(colors: [color, color.withValues(alpha: 0.6)]);
}

class AppTheme {
  static ThemeData dark({double uiScale = 1.0}) =>
      _build(uiScale: uiScale, dark: true);

  static ThemeData light({double uiScale = 1.0}) {
    PosColors.setTone(PosThemeTone.light);
    return _build(uiScale: uiScale, dark: false);
  }

  static ThemeData _build({required double uiScale, required bool dark}) {
    final scale = uiScale.clamp(0.78, 1.08).toDouble();
    double s(double value) => (value * scale).toDouble();

    // Dark overrides (design_rules.md §2)
    final bg = dark ? const Color(0xFF0E120D) : PosColors.background;
    final surf = dark ? const Color(0xFF181D16) : PosColors.surface;
    final surf2 = dark ? const Color(0xFF212720) : PosColors.surfaceSunk;
    final ink = dark ? const Color(0xFFF1F4EC) : PosColors.primaryDark;
    final mut = dark ? const Color(0xFF7E8576) : PosColors.muted;
    final ln = dark
        ? const Color(0x17FFFFFF)
        : PosColors.line;
    final ln2 = dark
        ? const Color(0x29FFFFFF)
        : PosColors.lineStrong;

    final colorScheme = dark
        ? ColorScheme.dark(
            primary: PosColors.primary, // lime stays identical
            onPrimary: PosColors.accentInk,
            secondary: ink,
            onSecondary: surf,
            surface: surf,
            onSurface: ink,
            error: PosColors.danger,
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: PosColors.primary,
            onPrimary: PosColors.accentInk,
            secondary: PosColors.primaryDark,
            onSecondary: Colors.white,
            surface: surf,
            onSurface: ink,
            error: PosColors.danger,
            onError: Colors.white,
          );

    final baseText = TextStyle(
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Hind Siliguri', 'Noto Sans Bengali'],
      color: ink,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Inter',
      fontFamilyFallback: const ['Hind Siliguri', 'Noto Sans Bengali'],
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
        // Display / screen title: 22/700
        displaySmall: baseText.copyWith(
          fontSize: s(22),
          fontWeight: FontWeight.w700,
          height: 1.18,
        ),
        // Money XL: 30/700 tabular
        headlineMedium: baseText.copyWith(
          fontSize: s(30),
          fontWeight: FontWeight.w700,
          height: 1.05,
          letterSpacing: s(-0.02 * 30),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        // Section (H2): 18/600
        titleLarge: baseText.copyWith(
          fontSize: s(18),
          fontWeight: FontWeight.w600,
          height: 1.22,
        ),
        // Money / price: 17/700 tabular
        titleMedium: baseText.copyWith(
          fontSize: s(17),
          fontWeight: FontWeight.w700,
          height: 1.26,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        // Title (row/tile): 15/600
        titleSmall: baseText.copyWith(
          fontSize: s(15),
          fontWeight: FontWeight.w600,
          height: 1.30,
        ),
        // Body: 14/400
        bodyLarge: baseText.copyWith(fontSize: s(14), height: 1.50),
        // Body S / desc: 13/400
        bodyMedium: baseText.copyWith(
          fontSize: s(13),
          color: mut,
          height: 1.45,
        ),
        bodySmall: baseText.copyWith(
          fontSize: s(12),
          color: mut,
          height: 1.30,
        ),
        // Label / status: 12-13/500-600
        labelLarge: baseText.copyWith(
          fontSize: s(13),
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        // Eyebrow: 12/700 · 0.05em UPPER
        labelSmall: baseText.copyWith(
          fontSize: s(12),
          fontWeight: FontWeight.w700,
          letterSpacing: s(0.05 * 12),
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: bg,
        foregroundColor: ink,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        color: surf,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.lg),
          side: BorderSide(color: ln, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surf,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          borderSide: BorderSide(color: ln, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          borderSide: BorderSide(color: ln2, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          borderSide: BorderSide(
            color: dark ? PosColors.primary : PosColors.accentStrong,
            width: 1,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          borderSide: BorderSide(color: PosColors.danger, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(PosRadii.md),
          borderSide: BorderSide(color: PosColors.danger, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: s(16), vertical: s(14)),
        labelStyle: TextStyle(color: mut, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: mut, fontSize: 14, fontWeight: FontWeight.w400),
        prefixIconColor: mut,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _buttonStyle(
          background: PosColors.primary,
          foreground: PosColors.accentInk,
          height: s(48),
          radius: PosRadii.md,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          background: PosColors.primary,
          foreground: PosColors.accentInk,
          height: s(48),
          radius: PosRadii.md,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(s(44), s(44)),
          foregroundColor: ink,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: ln2, width: 1),
          padding: EdgeInsets.symmetric(horizontal: s(16), vertical: s(12)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.md),
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
          foregroundColor: PosColors.accentStrong,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: s(70),
        backgroundColor: surf,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: surf2,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.sm),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: s(12),
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? ink : mut,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: s(22),
            color: selected ? ink : mut,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surf,
        selectedIconTheme: IconThemeData(color: ink, size: s(21)),
        unselectedIconTheme: IconThemeData(color: mut, size: s(20)),
        selectedLabelTextStyle: TextStyle(
          color: ink,
          fontWeight: FontWeight.w600,
          fontSize: s(12),
        ),
        unselectedLabelTextStyle: TextStyle(
          color: mut,
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
                ? PosColors.primarySoft
                : surf,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? ink
                : ink,
          ),
          side: WidgetStateProperty.all(
            BorderSide(color: ln, width: 1),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PosRadii.sm),
            ),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surf,
        selectedColor: PosColors.primary,
        side: BorderSide(color: ln2, width: 1),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
          color: ink,
        ),
        secondaryLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: PosColors.accentInk,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.sm),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? PosColors.primary
              : surf2,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : ln,
        ),
      ),
      dividerTheme: DividerThemeData(color: ln, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        backgroundColor: surf,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.xl),
          side: BorderSide(color: ln, width: 1),
        ),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: const ['Hind Siliguri', 'Noto Sans Bengali'],
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: ink,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontFamilyFallback: const ['Hind Siliguri', 'Noto Sans Bengali'],
          fontSize: 14,
          color: mut,
          height: 1.50,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surf,
        modalBackgroundColor: surf,
        showDragHandle: true,
        dragHandleColor: ln,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(PosRadii.xl),
          ),
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
          borderRadius: BorderRadius.circular(PosRadii.md),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: PosColors.primaryDark,
          borderRadius: BorderRadius.circular(PosRadii.xs),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: PosColors.primary,
        linearTrackColor: ln,
        circularTrackColor: ln,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: PosColors.primary,
        inactiveTrackColor: ln,
        thumbColor: PosColors.primary,
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
      textStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
    );
  }
}
