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
  testWidgets('terminal home renders terminal-specific dashboard variant', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    expect(find.text('Terminal'), findsOneWidget);
    expect(find.textContaining('Cha Ghor'), findsWidgets);
    expect(find.text('TODAY SALES'), findsOneWidget);
    expect(find.text('ORDERS'), findsOneWidget);
    expect(find.text('QUICK ACTIONS'), findsOneWidget);
    expect(find.text('New order'), findsOneWidget);
    expect(find.text('Top sellers · tap to add'), findsNothing);
    expect(find.text('Floor'), findsNothing);

    controller.dispose();
  });

  testWidgets('terminal home keeps terminal content for enterprise tier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    expect(find.text('Terminal'), findsOneWidget);
    expect(find.text('TODAY SALES'), findsOneWidget);
    expect(find.text('ORDERS'), findsOneWidget);
    expect(find.byTooltip('Settings'), findsNothing);
    expect(find.text('FLEET REVENUE · TODAY'), findsNothing);
    expect(find.text('Top sellers · tap to add'), findsNothing);
    expect(find.text('Search item or scan code'), findsNothing);

    controller.dispose();
  });
}
