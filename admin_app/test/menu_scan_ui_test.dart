import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/menu/menu_management_screen.dart';
import 'package:local_pos/src/features/setup/tenant_setup_screen.dart';
import 'package:local_pos/src/models/account_role.dart';
import 'package:local_pos/src/services/cloud_api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
            'nameEn': 'Chicken Roll',
            'nameBn': 'চিকেন রোল',
            'descriptionEn': 'Warm chicken roll.',
            'descriptionBn': 'গরম চিকেন রোল।',
            'categoryEn': 'Snacks',
            'categoryBn': 'স্ন্যাকস',
            'price': 180,
            'isAvailable': true,
          },
          {
            'nameEn': 'Broken price',
            'nameBn': 'ভাঙা দাম',
            'descriptionEn': 'Skip this one.',
            'descriptionBn': 'এটি বাদ দিন।',
            'categoryEn': 'General',
            'categoryBn': 'সাধারণ',
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
    expect(result.items.map((item) => item.nameEn), ['Chicken Roll']);
    expect(tenant.tableCount, 42);
  });

  testWidgets('scan menu floating action is manager only', (tester) async {
    final manager = PosAppController()..language = AppLanguage.en;
    await tester.pumpWidget(_scoped(manager, const MenuManagementScreen()));
    // The menu screen surfaces two floating buttons (Add item + AI scan) for
    // managers — they live inside a floating _MenuActionBar action row.
    expect(find.text('Add Menu Item'), findsOneWidget);
    expect(find.text('AI scan'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    manager.dispose();

    final staff = PosAppController()
      ..language = AppLanguage.en
      ..accountRole = AccountRole.staff;
    await tester.pumpWidget(_scoped(staff, const MenuManagementScreen()));
    expect(find.text('Add Menu Item'), findsNothing);
    expect(find.text('AI scan'), findsNothing);

    staff.dispose();
  });

  testWidgets('restaurant setup validates a default table count', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = PosAppController()..language = AppLanguage.en;
    var provisioned = false;
    await tester.pumpWidget(
      _scoped(
        controller,
        TenantSetupScreen(onProvisioned: () => provisioned = true),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'Scan Cafe');
    await tester.enterText(find.byType(TextField).at(1), 'Moon Ahmed');
    await tester.pump();
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open dashboard'));
    for (var i = 0; i < 10 && !provisioned; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(provisioned, isTrue);
    expect(controller.serverConfig.tableCount, 10);
    controller.dispose();
  });
}
