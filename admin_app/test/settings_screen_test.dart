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
  testWidgets('import order history setting is localized in Bangla', (
    tester,
  ) async {
    final controller = PosAppController()..language = AppLanguage.bn;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    expect(find.text('অর্ডার হিস্টরি ইমপোর্ট'), findsOneWidget);
    expect(
      find.text('পুরনো POS থেকে CSV এক্সপোর্ট আপলোড করুন।'),
      findsOneWidget,
    );
    expect(find.text('Import order history'), findsNothing);

    controller.dispose();
  });

  testWidgets('settings shows Facebook Messenger chatbot setup', (
    tester,
  ) async {
    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller, const SettingsScreen()));

    expect(find.text('Facebook Messenger bot'), findsOneWidget);
    expect(
      find.text(
        'Answer menu questions and take delivery orders from Messenger.',
      ),
      findsOneWidget,
    );

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

  testWidgets('wipe restaurant action requires typed outlet confirmation', (
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

    await tester.scrollUntilVisible(
      find.text('Wipe restaurant data'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wipe restaurant data'));
    await tester.pumpAndSettle();

    expect(find.text('Wipe all restaurant data?'), findsOneWidget);
    expect(find.text('Type outlet ID to confirm'), findsOneWidget);
    expect(find.textContaining('outlet-confirm-123'), findsOneWidget);

    controller.dispose();
  });
}
