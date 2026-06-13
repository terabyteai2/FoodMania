import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/settings/settings_screen.dart';

Widget _scoped(PosAppController controller, Widget child) {
  return AppScope(
    controller: controller,
    child: MaterialApp(
      locale: controller.language.locale,
      supportedLocales: AppLanguage.values
          .map((language) => language.locale)
          .toList(growable: false),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      home: child,
    ),
  );
}

void main() {
  test('settings group labels never combine English and Bangla', () {
    final en = AppStrings.of(AppLanguage.en);
    final bn = AppStrings.of(AppLanguage.bn);

    expect(en.deviceGroup, 'Device');
    expect(en.accountGroup, 'Account');
    expect(en.todayLabel, 'Today');
    expect(bn.deviceGroup, 'ডিভাইস');
    expect(bn.accountGroup, 'অ্যাকাউন্ট');
    expect(bn.todayLabel, 'আজকে');
  });

  testWidgets('language selector lives in settings', (tester) async {
    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    await tester.scrollUntilVisible(
      find.text('Language'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();

    expect(find.text('Choose app display language.'), findsOneWidget);
    expect(find.text('বাংলা'), findsOneWidget);
    expect(find.text('English'), findsWidgets);

    controller.dispose();
  });

  testWidgets('printer settings page only shows scan and connect workflow', (
    tester,
  ) async {
    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));
    await tester.tap(find.text('Connect Printer'));
    await tester.pumpAndSettle();

    expect(find.text('Scan for devices'), findsOneWidget);
    expect(find.text('Printer diagnostics'), findsNothing);
    expect(find.text('Auto-accept & auto-print new orders'), findsNothing);

    controller.dispose();
  });

  testWidgets('removed owner sections are absent from the lean terminal', (
    tester,
  ) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..demoManagerLoginEnabled = true;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    // Owner / back-office sections were removed from the terminal build.
    expect(find.text('ChatBot'), findsNothing);
    expect(find.text('Reports'), findsNothing);
    expect(find.text('Employee Account Management'), findsNothing);
    expect(find.text('Import Sales Data'), findsNothing);
    expect(find.text('Hero Media'), findsNothing);
    expect(find.text('Website Theme'), findsNothing);
    expect(find.text('Wipe restaurant data'), findsNothing);

    // Kept tiles are present.
    expect(find.text('Connect Printer'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('about us and privacy policy use Terafoods copy', (tester) async {
    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    await tester.scrollUntilVisible(
      find.text('About Us'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Us'));
    await tester.pumpAndSettle();

    expect(find.text('Terafoods'), findsWidgets);
    expect(find.text('Restaurant POS for Bangladesh · v2.2.1'), findsOneWidget);
    expect(
      find.textContaining('mobile-first point-of-sale app'),
      findsOneWidget,
    );
    expect(find.text('Rush-ready ordering'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Privacy Policy'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(find.text('Last updated: May 25, 2026'), findsOneWidget);
    expect(
      find.textContaining('built Terafoods for restaurant owners'),
      findsOneWidget,
    );

    controller.dispose();
  });
}
