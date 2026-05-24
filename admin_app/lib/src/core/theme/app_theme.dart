import 'package:flutter/material.dart';

enum PosThemeTone { dark, light }

class PosColors {
  static const Color primary = Color(0xFFF5C127);
  static const Color primarySoft = Color(0xFFFEF1C5);
  static const Color primaryWash = Color(0xFFFFF9E0);
  static const Color primaryDark = Color(0xFF1C1A17);
  static const Color primaryGlow = Color(0xFFF5C127);

  static const Color background = Color(0xFFF7F4EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceWarm = Color(0xFFF7F4EE);
  static const Color surfaceTinted = Color(0xFFFFF9E0);

  static const Color slate = Color(0xFF1C1A17);
  static const Color slateSoft = Color(0xFF1C1A17);
  static const Color muted = Color(0xFF888780);
  static const Color mutedSoft = Color(0xFFE8E4DC);

  static const Color success = Color(0xFF3D7A5A);
  static const Color successSoft = Color(0xFFEAF4EE);

  // Semantic fix: Changed warning color to distinct amber-orange to separate it from Primary Yellow
  static const Color warning = Color(0xFFE28714);
  static const Color warningSoft = Color(0xFFFFF3E0);

  static const Color danger = Color(0xFFA32D2D);
  static const Color dangerSoft = Color(0xFFFCEBEB);
  static const Color info = Color(0xFF888780);
  static const Color purple = Color(0xFF888780);

  static const Color coral = Color(0xFFE88060);
  static const Color coralSoft = Color(0xFFFBE4DB);
  static const Color coralWash = Color(0xFFFDEFE9);

  static const Color accent = primary;
  static const Color accentSoft = primaryWash;
  static const Color line = Color(0xFFE8E4DC);
  static const Color lineStrong = Color(0xFFE8E4DC);

  static PosThemeTone get tone => PosThemeTone.light;

  static void setTone(PosThemeTone tone) {}
}

class PosRadii {
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 12;
  static const double lg = 12;
  static const double xl = 12;
  static const double pill = 999;
}

class PosShadows {
  static const List<BoxShadow> card = [];
  // 1px Flat Rule: single-layer, low-blur drop shadow (blur <= 8) for budget GPU compatibility.
  static const List<BoxShadow> raised = [
    BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 6)),
  ];

  // Optimization: Budget-GPU friendly alternative avoiding costly multi-layer heavy blurs
  static const List<BoxShadow> glow = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4)),
  ];
}

class PosGradients {
  static const LinearGradient brand = LinearGradient(
    colors: [PosColors.primary, PosColors.primary],
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
      onPrimary: PosColors.primaryDark,
      secondary: PosColors.primaryDark,
      onSecondary: Colors.white,
      surface: PosColors.surface,
      onSurface: PosColors.slate,
      error: PosColors.danger,
      onError: Colors.white,
    );

    final baseText = TextStyle(
      fontFamily: 'Inter',
      color: PosColors.slate,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: PosColors.background,
      fontFamily: 'Inter',
      splashFactory: InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
        displaySmall: baseText.copyWith(
          fontSize: s(28),
          fontWeight: FontWeight.w500,
          height: 1.06,
          letterSpacing: 0,
        ),
        headlineMedium: baseText.copyWith(
          fontSize: s(24),
          fontWeight: FontWeight.w500,
          height: 1.1,
          letterSpacing: 0,
        ),
        titleLarge: baseText.copyWith(
          fontSize: s(18),
          fontWeight: FontWeight.w500,
          height: 1.18,
          letterSpacing: 0,
        ),
        titleMedium: baseText.copyWith(
          fontSize: s(15),
          fontWeight: FontWeight.w500,
          height: 1.22,
        ),
        titleSmall: baseText.copyWith(
          fontSize: s(13),
          fontWeight: FontWeight.w500,
          height: 1.22,
        ),
        bodyLarge: baseText.copyWith(fontSize: s(15), height: 1.4),
        bodyMedium: baseText.copyWith(
          fontSize: s(14),
          color: PosColors.muted,
          height: 1.4,
        ),
        bodySmall: baseText.copyWith(
          fontSize: s(12),
          color: PosColors.muted,
          height: 1.3,
        ),
        labelLarge: baseText.copyWith(
          fontSize: s(14),
          fontWeight: FontWeight.w500,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: PosColors.background,
        foregroundColor: PosColors.slate,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shadowColor: Colors.transparent,
        color: PosColors.surface,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.sm),
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
          borderSide: const BorderSide(color: PosColors.primaryDark, width: 1),
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
          foreground: PosColors.primaryDark,
          height: s(42),
          radius: PosRadii.sm,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _buttonStyle(
          background: PosColors.primary,
          foreground: PosColors.primaryDark,
          height: s(42),
          radius: PosRadii.sm,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(s(44), s(42)),
          foregroundColor: PosColors.slate,
          backgroundColor: Colors.transparent,
          side: const BorderSide(color: PosColors.line, width: 0.5),
          padding: EdgeInsets.symmetric(horizontal: s(14), vertical: s(10)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosRadii.sm),
          ),
          textStyle: TextStyle(
            fontSize: s(14),
            fontWeight: FontWeight.w500,
            letterSpacing: 0,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PosColors.primaryDark,
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: PosColors.slate,
          minimumSize: const Size(38, 38),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: s(70),
        backgroundColor: PosColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: s(11),
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? PosColors.slate : PosColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: s(22),
            color: selected ? PosColors.slate : PosColors.muted,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: PosColors.surface,
        selectedIconTheme: IconThemeData(color: PosColors.slate, size: s(21)),
        unselectedIconTheme: IconThemeData(color: PosColors.muted, size: s(20)),
        selectedLabelTextStyle: TextStyle(
          color: PosColors.slate,
          fontWeight: FontWeight.w500,
          fontSize: s(12),
        ),
        unselectedLabelTextStyle: TextStyle(
          color: PosColors.muted,
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
                : PosColors.slate,
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
            const TextStyle(fontWeight: FontWeight.w500),
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
          color: PosColors.slate,
        ),
        secondaryLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
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
              ? PosColors.primaryDark
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
          borderRadius: BorderRadius.circular(PosRadii.sm),
          side: const BorderSide(color: PosColors.line, width: 0.5),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: PosColors.slate,
        ),
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          color: PosColors.muted,
          height: 1.45,
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
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
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PosColors.primaryDark,
        linearTrackColor: PosColors.line,
        circularTrackColor: PosColors.line,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: PosColors.primary,
        inactiveTrackColor: PosColors.line,
        thumbColor: PosColors.primaryDark,
        overlayColor: PosColors.primary.withValues(alpha: 0.12),
        valueIndicatorColor: PosColors.primaryDark,
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
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
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
    );
  }
}
