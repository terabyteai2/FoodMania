import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/dashboard/dashboard_screen.dart';
import 'package:local_pos/src/models/menu_item.dart';

Widget _scoped(PosAppController controller, Widget child) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

MenuItem _menuItem() {
  final now = DateTime(2026, 5, 22, 12);
  return MenuItem(
    id: 'menu-1',
    name: 'Burger',
    description: 'Juicy burger.',
    category: 'Mains',
    price: 220,
    isAvailable: true,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('dashboard manager FAB opens the new order flow', (tester) async {
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..menuItems = [_menuItem()];

    await tester.pumpWidget(
      _scoped(controller, DashboardScreen(onNavigate: (_) {})),
    );

    expect(find.byTooltip('New order'), findsOneWidget);

    await tester.tap(find.byTooltip('New order'));
    await tester.pumpAndSettle();

    expect(find.text("Where's this order for?"), findsOneWidget);

    controller.dispose();
  });
}
