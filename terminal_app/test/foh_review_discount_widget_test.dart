import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/orders/orders_screen.dart';
import 'package:local_pos/src/models/account_role.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_service_type.dart';
import 'package:local_pos/src/models/server_config.dart';

MenuItem _menuItem() {
  final now = DateTime(2026, 6, 13, 12);
  return MenuItem(
    id: 'menu-1',
    name: 'Rice bowl',
    description: 'Test item',
    category: 'Mains',
    price: 100,
    isAvailable: true,
    createdAt: now,
    updatedAt: now,
  );
}

PosAppController _controller({required AccountRole role}) {
  final controller = PosAppController()
    ..language = AppLanguage.en
    ..accountRole = role
    ..menuItems = [_menuItem()]
    ..serverConfig = ServerConfig(
      serverId: 'server',
      restaurantId: 'restaurant',
      outletId: 'outlet',
      restaurantName: 'Test Cafe',
      outletName: 'Main',
      tableCount: 4,
    );
  return controller;
}

Widget _harness(PosAppController controller) {
  return AppScope(
    controller: controller,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => openNewOrderForm(
                  context,
                  initialServiceType: OrderServiceType.takeaway,
                  initialMenuItemQuantities: const {'menu-1': 1},
                  startAtReview: true,
                ),
                child: const Text('Open'),
              ),
            ),
          );
        },
      ),
    ),
  );
}

Future<void> _openReview(
  WidgetTester tester,
  PosAppController controller,
) async {
  await tester.pumpWidget(_harness(controller));
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('manager sees add discount on FOH review', (tester) async {
    final controller = _controller(role: AccountRole.manager);
    addTearDown(controller.dispose);

    await _openReview(tester, controller);

    expect(find.text('Discount (flat ৳)'), findsOneWidget);
  });

  testWidgets('custom flat discount updates review total', (tester) async {
    final controller = _controller(role: AccountRole.manager);
    addTearDown(controller.dispose);

    await _openReview(tester, controller);

    // Enter a flat discount of 10 in the discount field.
    await tester.enterText(
      find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.controller != null &&
            w.decoration?.hintText == '0',
      ),
      '10',
    );
    await tester.pump();

    expect(find.text('Total: ৳90'), findsOneWidget);
  });
}
