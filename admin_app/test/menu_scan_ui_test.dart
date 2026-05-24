import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/core/widgets/menu_image_view.dart';
import 'package:local_pos/src/core/widgets/notification_center.dart';
import 'package:local_pos/src/features/menu/menu_management_screen.dart';
import 'package:local_pos/src/features/menu/square_image_cropper.dart';
import 'package:local_pos/src/features/setup/tenant_setup_screen.dart';
import 'package:local_pos/src/models/account_role.dart';
import 'package:local_pos/src/models/pos_notification.dart';
import 'package:local_pos/src/services/cloud_api_service.dart';
import 'package:local_pos/src/services/menu_image_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  test('menu icon inference picks related placeholder keys', () {
    expect(
      inferMenuIconKey(name: 'Margherita Pizza', category: 'Mains'),
      'pizza',
    );
    expect(
      inferMenuIconKey(name: 'Mutton Kacchi Biryani', category: 'Biryani'),
      'biryani',
    );
    expect(inferMenuIconKey(name: 'Borhani', category: 'Drinks'), 'drink');
  });

  test('notification target resolver maps related pages', () {
    expect(
      PosNotification(
        id: 'n1',
        type: PosNotificationType.system,
        title: 'Stock',
        body: 'Low stock',
        actionTarget: 'stock',
        createdAt: DateTime(2026),
      ).target,
      PosNotificationTarget.inventory,
    );
    expect(
      PosNotification(
        id: 'n2',
        type: PosNotificationType.pendingOrder,
        title: 'Order',
        body: 'Pending',
        createdAt: DateTime(2026),
      ).target,
      PosNotificationTarget.orders,
    );
    expect(
      PosNotification(
        id: 'n3',
        type: PosNotificationType.system,
        title: 'Test',
        body: 'Only read',
        actionTarget: 'test',
        createdAt: DateTime(2026),
      ).target,
      PosNotificationTarget.none,
    );
  });

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
    expect(find.text('Item'), findsOneWidget);
    expect(find.text('AI scan'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    manager.dispose();

    final staff = PosAppController()
      ..language = AppLanguage.en
      ..accountRole = AccountRole.staff;
    await tester.pumpWidget(_scoped(staff, const MenuManagementScreen()));
    expect(find.text('Item'), findsNothing);
    expect(find.text('AI scan'), findsNothing);

    staff.dispose();
  });

  testWidgets('menu action bar fits Bangla labels on narrow screens', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = PosAppController()..language = AppLanguage.bn;
    await tester.pumpWidget(_scoped(controller, const MenuManagementScreen()));
    await tester.pump();

    expect(find.text('AI স্ক্যান'), findsOneWidget);
    expect(tester.takeException(), isNull);

    controller.dispose();
  });

  testWidgets('square cropper exports a compressed jpeg', (tester) async {
    final source = img.Image(width: 1600, height: 900);
    final sourceBytes = Uint8List.fromList(img.encodePng(source));
    final controller = PosAppController()..language = AppLanguage.en;
    Uint8List? cropped;

    await tester.pumpWidget(
      _scoped(
        controller,
        Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                cropped = await Navigator.of(context).push<Uint8List>(
                  MaterialPageRoute(
                    builder: (_) =>
                        SquareImageCropperPage(imageBytes: sourceBytes),
                  ),
                );
              },
              child: const Text('Open cropper'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Open cropper'));
    await tester.pumpAndSettle();
    expect(find.text('Crop menu photo'), findsOneWidget);

    await tester.tap(find.text('Use'));
    await tester.pumpAndSettle();

    expect(cropped, isNotNull);
    expect(cropped!.first, 0xff);
    expect(cropped![1], 0xd8);
    expect(cropped!.length, lessThan(MenuImageService.maxBinaryBytes));

    controller.dispose();
  });

  testWidgets('top notification toast has valid drag gestures', (tester) async {
    final controller = PosAppController()..language = AppLanguage.en;
    late BuildContext hostContext;

    await tester.pumpWidget(
      _scoped(
        controller,
        Scaffold(
          body: Builder(
            builder: (context) {
              hostContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    showTopNotificationToast(
      hostContext,
      title: 'New order',
      body: 'Table 3 is waiting.',
      duration: const Duration(milliseconds: 10),
    );
    await tester.pump();

    expect(find.text('New order'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 11));

    controller.dispose();
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
