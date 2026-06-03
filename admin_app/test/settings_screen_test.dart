import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/settings/settings_screen.dart';
import 'package:local_pos/src/models/server_config.dart';

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
    expect(en.storeGroup, 'Store');
    expect(en.adminGroup, 'Admin');
    expect(en.accountGroup, 'Account');
    expect(en.todayLabel, 'Today');
    expect(bn.deviceGroup, 'ডিভাইস');
    expect(bn.storeGroup, 'স্টোর');
    expect(bn.adminGroup, 'অ্যাডমিন');
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

  testWidgets('import sales data setting is localized in Bangla', (
    tester,
  ) async {
    final controller = PosAppController()..language = AppLanguage.bn;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    expect(find.text('বিক্রির ডাটা ইমপোর্ট'), findsOneWidget);
    expect(
      find.text('পুরনো POS থেকে CSV এক্সপোর্ট আপলোড করুন।'),
      findsOneWidget,
    );
    expect(find.text('Import Sales Data'), findsNothing);

    controller.dispose();
  });

  testWidgets('settings shows Facebook chatbot setup with its logo', (
    tester,
  ) async {
    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    expect(find.text('ChatBot'), findsOneWidget);
    expect(find.byIcon(Icons.facebook), findsOneWidget);
    expect(
      find.text(
        'Answer menu questions and take delivery orders from Messenger.',
      ),
      findsOneWidget,
    );

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
    expect(find.text('Test print'), findsNothing);
    expect(find.text('Printer diagnostics'), findsNothing);
    expect(find.text('Auto-accept & auto-print new orders'), findsNothing);

    controller.dispose();
  });

  testWidgets('manager settings follow the requested visible order', (
    tester,
  ) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..demoManagerLoginEnabled = true;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    const expected = [
      'ChatBot',
      'Connect Printer',
      'Language',
      'All QR Codes',
      'Hero Media',
      'Website Theme',
      'Restaurant Details',
      'Reports',
      'Employee Account Management',
      'Import Sales Data',
      'Set Table Numbers',
      'About Us',
      'Privacy Policy',
      'Log Out',
    ];
    final textValues = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .toList(growable: false);
    final positions = [for (final label in expected) textValues.indexOf(label)];

    expect(positions, everyElement(greaterThanOrEqualTo(0)));
    expect(positions, orderedEquals([...positions]..sort()));
    expect(find.text('Inventory settings'), findsNothing);
    expect(find.text('Display Size'), findsNothing);
    expect(find.text('Wipe restaurant data'), findsNothing);
    expect(find.text('Diagnostics'), findsNothing);

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
    expect(find.text('AI Scan Images'), findsOneWidget);
    expect(find.text('Terafoods Cloud Backend'), findsOneWidget);

    controller.dispose();
  });

  testWidgets(
    'restaurant details hides account identity and duplicate heading',
    (tester) async {
      final controller = PosAppController()
        ..language = AppLanguage.en
        ..serverConfig = ServerConfig(
          serverId: 'server-1',
          restaurantId: 'restaurant-1',
          outletId: 'outlet-1',
          restaurantName: 'Cafe One',
          outletName: 'Cafe One',
        );

      await tester.pumpWidget(_scoped(controller, const SettingsScreen()));
      await tester.scrollUntilVisible(
        find.text('Restaurant Details'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Restaurant Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restaurant Details'));
      await tester.pumpAndSettle();

      expect(find.text('Your Restaurant Info'), findsOneWidget);
      expect(find.text('Account Identity'), findsNothing);
      expect(find.text('Restaurant name'), findsOneWidget);

      controller.dispose();
    },
  );

  testWidgets('reports page exposes a top-left back button', (tester) async {
    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));
    await tester.scrollUntilVisible(
      find.text('Reports'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Reports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    controller.dispose();
  });

  testWidgets('wipe restaurant action is hidden from the settings panel', (
    tester,
  ) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..serverConfig = ServerConfig(
        serverId: 'server-confirm-123',
        restaurantId: 'restaurant-confirm-123',
        outletId: 'outlet-confirm-123',
        restaurantName: 'Confirm Cafe',
        outletName: 'Confirm Cafe',
      )
      ..cloudConfig = CloudConfig(
        baseUrl: 'https://example.com',
        enabled: true,
        deviceToken: 'token',
        autoSyncIntervalSeconds: 30,
      );

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    expect(find.text('Wipe restaurant data'), findsNothing);

    controller.dispose();
  });
}
