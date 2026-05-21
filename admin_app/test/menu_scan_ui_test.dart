import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/menu/menu_management_screen.dart';
import 'package:local_pos/src/features/setup/tenant_setup_screen.dart';
import 'package:local_pos/src/models/account_role.dart';
import 'package:local_pos/src/services/cloud_api_service.dart';

Widget _scoped(PosAppController controller, Widget child) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

void main() {
  test('menu scan response keeps valid import candidates and table count', () {
    final result = MenuScanResult.fromJson({
      'data': {
        'provider': 'xai',
        'pageCount': 2,
        'items': [
          {
            'name': 'Chicken Roll',
            'description': 'Warm chicken roll.',
            'category': 'Snacks',
            'price': 180,
            'isAvailable': true,
          },
          {
            'name': 'Broken price',
            'description': 'Skip this one.',
            'category': 'General',
            'price': 0,
          },
        ],
      },
    });
    final tenant = TenantBootstrapResult.fromJson({
      'data': {
        'serverId': 'server',
        'restaurantId': 'restaurant',
        'outletId': 'outlet',
        'restaurantName': 'Scan Cafe',
        'outletName': 'Main',
        'deviceToken': 'token',
        'tableCount': 42,
      },
    });

    expect(result.provider, 'xai');
    expect(result.pageCount, 2);
    expect(result.items.map((item) => item.name), ['Chicken Roll']);
    expect(tenant.tableCount, 42);
  });

  testWidgets('scan menu floating action is manager only', (tester) async {
    final manager = PosAppController();
    await tester.pumpWidget(_scoped(manager, const MenuManagementScreen()));
    expect(find.byType(FloatingActionButton), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    manager.dispose();

    final staff = PosAppController()..accountRole = AccountRole.staff;
    await tester.pumpWidget(_scoped(staff, const MenuManagementScreen()));
    expect(find.byType(FloatingActionButton), findsNothing);

    staff.dispose();
  });

  testWidgets('restaurant setup validates a default table count', (
    tester,
  ) async {
    final controller = PosAppController();
    await tester.pumpWidget(
      _scoped(controller, TenantSetupScreen(onProvisioned: () {})),
    );

    final tableField = find.byKey(const Key('tenant-setup-table-count'));
    expect(tester.widget<TextField>(tableField).controller!.text, '10');

    await tester.enterText(find.byType(TextField).first, 'Scan Cafe');
    await tester.enterText(tableField, '0');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );

    await tester.enterText(tableField, '12');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNotNull,
    );
    controller.dispose();
  });
}
