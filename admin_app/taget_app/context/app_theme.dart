import 'package:flutter/material.dart';

enum PosThemeTone { dark, light }

// ---------------------------------------------------------------------------
// PosColors — QuickBytes POS blue design system (redesign_source_of_truth.md §2)
// Petpooja clone, recolored: --primary #2F4FE0 royal-indigo = brand + main CTA.
// Navy (#1E2A44) = secondary action. Green ONLY for success/profit. Red ONLY
// for destructive. Pastel tints carry states. Soft rounded white cards.
//
// NOTE: token *names* are kept stable so the ~1000 references across screens
// keep compiling — only the *values* change. Because blue is a DARK fill,
// `accentInk` (text/icon on a primary fill) is now WHITE, not dark ink.
// ---------------------------------------------------------------------------
class PosColors {
  // ── Primary — blue ramp (royal-indigo) ──────────────────────────────────
  static const Color blue50 = Color(0xFFEEF1FE);
  static const Color blue100 = Color(0xFFDCE3FD);
  static const Color blue200 = Color(0xFFB9C7FB);
  static const Color blue300 = Color(0xFF8FA3F5);
  static const Color blue400 = Color(0xFF5E74EC);
  static const Color blue500 = Color(0xFF2F4FE0); // primary
  static const Color blue600 = Color(0xFF2440C2); // press
  static const Color blue700 = Color(0xFF1D339B); // primary-strong (text on white)
  static const Color blue800 = Color(0xFF182A7D);
  static const Color blue900 = Color(0xFF131F5A);

  // Legacy lime aliases kept so any lingering `lime*` reference still resolves
  // (remapped onto the blue ramp — there should be none left in mobile screens).
  static const Color lime50 = blue50;
  static const Color lime100 = blue100;
  static const Color lime200 = blue200;
  static const Color lime300 = blue300;
  static const Color lime400 = blue500;
  static const Color lime500 = blue600;
  static const Color lime600 = blue400;
  static const Color lime700 = blue700;
  static const Color lime800 = blue800;
  static const Color lime900 = blue900;

  // ── Primary tokens ──────────────────────────────────────────────────────
  static const Color primary = blue500; // #2F4FE0
  static const Color primaryDeep = blue600; // press state #2440C2
  static const Color primaryMid = blue400; // secondary emphasis
  static const Color primarySoft = blue50; // primary-tint #EEF1FE
  static const Color primaryWash = blue100; // #DCE3FD
  static const Color accentInk = Color(0xFFFFFFFF); // WHITE text/icon on blue fills
  static const Color accentSoftInk = blue700; // text on primarySoft (tint)
  static const Color accentStrong = blue700; // #1D339B blue text on white
  static const Color accentOnInk = blue300; // light blue on dark backgrounds

  // ── Secondary — navy (the calm dark CTA counterpart) ────────────────────
  static const Color secondary = Color(0xFF1E2A44); // --ink-btn
  static const Color secondaryPress = Color(0xFF15203A); // --ink-btn-press
  static const Color onSecondary = Color(0xFFFFFFFF);

  // ── Ink — neutral slate ─────────────────────────────────────────────────
  static const Color primaryDark = Color(0xFF1B2330); // ink
  static const Color inkSoft = Color(0xFF5A6475); // ink-2
  static const Color onInk = Color(0xFFF4F6FA); // text on dark
  static const Color onInkSec = Color(0xB3F4F6FA); // white-ish 0.70
  static const Color onInkTer = Color(0x7AF4F6FA); // white-ish 0.48

  // ── Scaffold — LIGHT (neutral) ──────────────────────────────────────────
  static const Color background = Color(0xFFF6F7F9); // bg
  static const Color surface = Color(0xFFFFFFFF); // surface
  static const Color surfaceSunk = Color(0xFFF1F3F6); // surface-2
  static const Color surface3 = Color(0xFFE7EAEF); // surface-3
  static const Color track = Color(0xFFF1F3F6);
  static const Color trackInk = Color(0x241B2330);

  // ── Secondary text ──────────────────────────────────────────────────────
  static const Color ink2 = Color(0xFF5A6475); // ink-2 (labels)
  static const Color muted = Color(0xFF8A93A3); // muted
  static const Color mutedSoft = Color(0xFFAAB2C0); // placeholder

  // ── Borders ─────────────────────────────────────────────────────────────
  static const Color line = Color(0xFFECEEF2); // line
  static const Color lineStrong = Color(0xFFDEE2E9); // line-2
  static const Color divider = Color(0xFFECEEF2);
  static const Color pendingBorder = Color(0xFFEFD9A8); // amber pending card

  // ── Table / order state fills (Petpooja pastels) ────────────────────────
  // running/seated (sky), printed (mint), kot (amber), available (white).
  static const Color stateRunning = Color(0xFFDCEBFB);
  static const Color stateRunningInk = Color(0xFF2B5C9E);
  static const Color statePrinted = Color(0xFFE3F6EC);
  static const Color statePrintedInk = Color(0xFF1E7A47);
  static const Color stateKot = Color(0xFFFCF3CF);
  static const Color stateKotInk = Color(0xFF9A7400);

  // ── Occupied-table wash (FOH) — sky tint, ink label ─────────────────────
  static const Color seatTint = stateRunning;
  static const Color seatLine = Color(0xFFBFD6F2);
  static const Color seatInk = stateRunningInk;

  // ── Channel hues (order feed) ───────────────────────────────────────────
  // counter navy · website/messenger blue · table-QR amber · waiter green.
  static const Color channelWebsite = blue500;
  static const Color channelMessenger = blue500;
  static const Color channelQr = Color(0xFFC98208);
  static const Color channelCounter = secondary; // navy
  static const Color channelDineIn = blue500;
  static const Color channelWaiter = Color(0xFF1E9E5A);
  static const Color channelManager = secondary;
  static const Color channelNeutralSoft = Color(0xFFE7EAEF);

  // ── Analytics tile-icon tints (QS stat cards — never status meaning) ─────
  static const Color tintPurple = Color(0xFFEFEAFB);
  static const Color iconPurple = Color(0xFF7C5CD6);
  static const Color tintBlue = Color(0xFFE4EFFA);
  static const Color iconBlue = Color(0xFF2F6FB0);
  static const Color tintGreen = Color(0xFFE6F6EC);
  static const Color iconGreen = Color(0xFF2E9E63);
  static const Color tintAmber = Color(0xFFFCF3CF);
  static const Color iconAmber = Color(0xFF9A7400);
  static const Color tintRed = Color(0xFFFBE5E6);
  static const Color iconRed = Color(0xFFC0454B);

  // ── Signals (green = success/profit ONLY; red = destructive ONLY) ───────
  static const Color success = Color(0xFF1E9E5A);
  static const Color successSoft = Color(0xFFE3F6EC);
  static const Color good = success;
  static const Color goodSoft = successSoft;
  static const Color warning = Color(0xFFC98208);
  static const Color warningSoft = Color(0xFFFCF0D8);
  static const Color warn = warning;
  static const Color warnSoft = warningSoft;
  static const Color danger = Color(0xFFD8434A);
  static const Color dangerSoft = Color(0xFFFBE5E6);
  static const Color urgent = Color(0xFFC98208); // late = warm amber
  static const Color urgentSoft = Color(0xFFFCF0D8);
  static const Color late = urgent;
  static const Color lateSoft = urgentSoft;
  static const Color info = primary; // info = primary blue
  static const Color infoSoft = primarySoft;

  // ── Semantic aliases ─────────────────────────────────────────────────────
  static const Color accent = primary;
  static const Color accentSoft = primarySoft;
  static const Color accentDeep = primaryDeep;
  static const Color accentMid = primaryMid;
  static const Color accentWash = primaryWash;
  static const Color slate = primaryDark;
  static const Color slateSoft = inkSoft;
  static const Color text = primaryDark;
  static const Color textSec = muted;
  static const Color textTer = mutedSoft;

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
  static const List<BoxShadow> e1 = [
    BoxShadow(color: Color(0x0F14180E), blurRadius: 2, offset: Offset(0, 1)),
  ];
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
  static const List<BoxShadow> fab = [
    // blue glow — 0 8px 22px -6px rgba(47,79,224,.55)
    BoxShadow(color: Color(0x8C2F4FE0), blurRadius: 22, offset: Offset(0, 8), spreadRadius: -6),
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
  static ThemeData dark() => _build(dark: true);

  static ThemeData light() {
    PosColors.setTone(PosThemeTone.light);
    return _build(dark: false);
  }

  static ThemeData _build({required bool dark}) {
    double s(double value) => value;

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
            primary: PosColors.primary, // blue #2F4FE0
            onPrimary: PosColors.accentInk, // white
            secondary: PosColors.secondary, // navy
            onSecondary: PosColors.onSecondary,
            surface: surf,
            onSurface: ink,
            error: PosColors.danger,
            onError: Colors.white,
          )
        : ColorScheme.light(
            primary: PosColors.primary,
            onPrimary: PosColors.accentInk, // white on blue
            secondary: PosColors.secondary, // navy secondary action
            onSecondary: PosColors.onSecondary,
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
        // Screen title (big) — tab roots: 26/700
        displaySmall: baseText.copyWith(
          fontSize: s(26),
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
        // Screen title (pushed): 22/700
        displayMedium: baseText.copyWith(
          fontSize: s(22),
          fontWeight: FontWeight.w700,
          height: 1.18,
        ),
        // Money / token hero: 33/800 tabular
        headlineMedium: baseText.copyWith(
          fontSize: s(33),
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: s(-0.02 * 33),
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
        // Section (H2): 15/700
        titleLarge: baseText.copyWith(
          fontSize: s(15),
          fontWeight: FontWeight.w700,
          height: 1.30,
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
        // Soft primary-tint pill behind the active icon (spec mobile bottom tab).
        indicatorColor: PosColors.primarySoft,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: s(12),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? PosColors.primary : mut,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: s(22),
            color: selected ? PosColors.primary : mut,
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
                ? surf
                : surf2,
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
