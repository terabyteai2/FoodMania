import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/settings/settings_screen.dart';
import 'package:local_pos/src/models/account_role.dart';
import 'package:local_pos/src/models/server_config.dart';

/// SettingsScreen no longer brings its own Scaffold/scroll view — it's
/// embedded content now (shared by the mobile Settings tab and the desktop
/// POS shell), so the test harness provides the scroll container, the same
/// way MoreScreen's AppScaffold does in the real app.
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
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  test('settings group labels never combine English and Bangla', () {
    final en = AppStrings.of(AppLanguage.en);
    final bn = AppStrings.of(AppLanguage.bn);

    expect(en.myRestaurantDetailsGroup, 'My restaurant details');
    expect(en.deviceGroup, 'Device');
    expect(en.adminGroup, 'Admin');
    expect(en.accountGroup, 'Account');
    expect(en.settingsTab, 'Settings');
    expect(en.todayLabel, 'Today');
    expect(bn.myRestaurantDetailsGroup, 'আমার রেস্টুরেন্টের তথ্য');
    expect(bn.deviceGroup, 'ডিভাইস');
    expect(bn.adminGroup, 'অ্যাডমিন');
    expect(bn.accountGroup, 'অ্যাকাউন্ট');
    expect(bn.settingsTab, 'সেটিংস');
    expect(bn.todayLabel, 'আজকে');
  });

  testWidgets('settings shows Facebook chatbot setup row', (tester) async {
    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    expect(find.text('Facebook Messenger bot'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
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
    await tester.scrollUntilVisible(
      find.text('Connect Printer'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Connect Printer'));
    await tester.pumpAndSettle();

    expect(find.text('Scan for devices'), findsOneWidget);
    expect(find.text('Test print'), findsNothing);
    expect(find.text('Printer diagnostics'), findsNothing);
    expect(find.text('Auto-accept & auto-print new orders'), findsNothing);

    controller.dispose();
  });

  testWidgets('manager settings follow the requested visible order, '
      'with restaurant identity fields up top and no Restaurant/Restaurant '
      'Details detour', (tester) async {
    final controller = PosAppController()
      ..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    const expected = [
      'Name',
      'Restaurant name',
      'Restaurant phone',
      'Website URL',
      'Restaurant Logo',
      'Set Table Numbers',
      'All QR Codes',
      'Website image/video',
      'Website Theme',
      'ChatBot',
      'Connect Printer',
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
    // The old "Restaurant Details" sub-page and the deferred "Restaurant"
    // entry are both gone — their fields live in the flat list above now.
    expect(find.text('Restaurant Details'), findsNothing);
    expect(find.text('Employee Account Management'), findsNothing);
    expect(find.text('Inventory settings'), findsNothing);
    expect(find.text('Display Size'), findsNothing);
    expect(find.text('Wipe restaurant data'), findsNothing);
    expect(find.text('Diagnostics'), findsNothing);

    controller.dispose();
  });

  testWidgets(
    'tapping a restaurant identity row opens a bottom sheet, not a page',
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
      await tester.tap(find.text('Restaurant name'));
      await tester.pumpAndSettle();

      // A bottom sheet (not a pushed AppScaffold page) with the current
      // value pre-filled and a Save action.
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Cafe One'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
      // No back button / new page chrome — the underlying settings list is
      // still in the tree behind the sheet.
      expect(find.text('Restaurant Logo'), findsOneWidget);

      // Clearing the field and saving surfaces the required-field validator
      // without ever leaving the sheet or hitting the network.
      await tester.enterText(find.widgetWithText(TextField, 'Cafe One'), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);

      controller.dispose();
    },
  );

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

  testWidgets('staff (non-manager) settings keep the reduced set, no '
      'restaurant identity fields', (tester) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..setAccountRoleDemo(AccountRole.waiter);

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    expect(find.text('Restaurant name'), findsNothing);
    expect(find.text('Website URL'), findsNothing);
    expect(find.text('Connect Printer'), findsOneWidget);
    expect(find.text('All QR Codes'), findsOneWidget);
    expect(find.text('About Us'), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
    // Language now lives only in the Settings panel — its single home after
    // Phase 5 removed the duplicate drawer-footer and avatar-dropdown toggles.
    expect(find.text('App language'), findsOneWidget);

    controller.dispose();
  });
}
