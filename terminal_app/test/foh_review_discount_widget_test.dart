import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/orders/orders_screen.dart';
import 'package:local_pos/src/models/account_role.dart';
import 'package:local_pos/src/models/desktop_pos.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_service_type.dart';
import 'package:local_pos/src/models/server_config.dart';
import 'package:local_pos/src/services/local_database_service.dart';

class _DiscountSettingsDatabase extends LocalDatabaseService {
  _DiscountSettingsDatabase(this.presets);

  final List<PosDiscountPreset> presets;

  @override
  Future<DesktopPosSettings> getDesktopPosSettings({
    required int fallbackTableCount,
  }) async {
    return DesktopPosSettings(
      floorLayout: DesktopPosSettings.fallbackFloor(fallbackTableCount),
      discountPresets: presets,
    );
  }
}

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

PosAppController _controller({
  required AccountRole role,
  List<PosDiscountPreset> presets = const [],
}) {
  final controller =
      PosAppController(database: _DiscountSettingsDatabase(presets))
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

    expect(find.text('Add discount'), findsOneWidget);
  });

  testWidgets('waiter does not see add discount on FOH review', (tester) async {
    final controller = _controller(role: AccountRole.waiter);
    addTearDown(controller.dispose);

    await _openReview(tester, controller);

    expect(find.text('Add discount'), findsNothing);
  });

  testWidgets('custom flat discount updates review total', (tester) async {
    final controller = _controller(role: AccountRole.manager);
    addTearDown(controller.dispose);

    await _openReview(tester, controller);
    await tester.tap(find.text('Add discount'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Discount value'),
      '10',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Custom discount'),
      'Promo',
    );
    await tester.tap(find.text('Apply discount'));
    await tester.pumpAndSettle();

    expect(find.text('Promo'), findsWidgets);
    expect(find.text('Total: ৳90'), findsOneWidget);
  });

  testWidgets('preset percent discount updates review total', (tester) async {
    final controller = _controller(
      role: AccountRole.manager,
      presets: const [
        PosDiscountPreset(
          id: 'staff',
          label: 'Staff 10%',
          kind: 'percent',
          value: 10,
        ),
      ],
    );
    addTearDown(controller.dispose);

    await _openReview(tester, controller);
    await tester.tap(find.text('Add discount'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff 10%'));
    await tester.tap(find.text('Apply discount'));
    await tester.pumpAndSettle();

    expect(find.text('Staff 10%'), findsWidgets);
    expect(find.text('Total: ৳90'), findsOneWidget);
  });
}
