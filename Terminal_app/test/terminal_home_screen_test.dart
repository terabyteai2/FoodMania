import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terminal_pos/src/app_controller.dart';
import 'package:terminal_pos/src/app_scope.dart';
import 'package:terminal_pos/src/core/enums/business_tier.dart';
import 'package:terminal_pos/src/core/localization/app_strings.dart';
import 'package:terminal_pos/src/core/theme/app_theme.dart';
import 'package:terminal_pos/src/features/terminal/terminal_home_screen.dart';
import 'package:terminal_pos/src/models/menu_item.dart';

Widget _scoped(PosAppController controller) {
  return AppScope(
    controller: controller,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: TerminalHomeScreen(
        onNavigateToOrders: () {},
        onNavigateToMenu: () {},
        onNavigateToSettings: () {},
      ),
    ),
  );
}

MenuItem _menuItem() {
  final now = DateTime(2026, 6, 1, 12);
  return MenuItem(
    id: 'tea',
    name: 'Milk Tea',
    description: 'Fresh milk tea.',
    category: 'Tea',
    price: 30,
    isAvailable: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('terminal home renders cafe manager dashboard', (tester) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..businessTier = BusinessTier.standard
      ..menuItems = [_menuItem()];
    controller.serverConfig = controller.serverConfig.copyWith(
      outletName: 'Cha Ghor',
    );

    await tester.pumpWidget(_scoped(controller));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Top sellers · tap to add'), findsOneWidget);
    expect(find.text('Floor'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    expect(find.text('Milk Tea'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('terminal enterprise home suppresses ring-up', (tester) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..businessTier = BusinessTier.enterprise
      ..menuItems = [_menuItem()];
    controller.serverConfig = controller.serverConfig.copyWith(
      outletName: 'Spice Group',
    );

    await tester.pumpWidget(_scoped(controller));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('FLEET REVENUE · TODAY'), findsOneWidget);
    expect(find.text('Top sellers · tap to add'), findsNothing);
    expect(find.text('Search item or scan code'), findsNothing);

    controller.dispose();
  });
}
