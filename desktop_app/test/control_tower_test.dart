import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/core/widgets/tf_design_system.dart';
import 'package:local_pos/src/features/tower/control_tower_screen.dart';

Widget _scoped(PosAppController controller) {
  return AppScope(
    controller: controller,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const ControlTowerScreen(),
    ),
  );
}

void main() {
  testWidgets('control tower renders live ops with no orders (spec §4.9)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // No alerts ⇒ all-clear banner.
    expect(find.text('All clear — no alerts right now'), findsOneWidget);
    // Quick stats are always visible.
    expect(find.text('Open orders'), findsOneWidget);
    expect(find.text('Tables seated'), findsOneWidget);
    expect(find.text('Avg wait'), findsOneWidget);
    // Channel-load card present.
    expect(find.text('Order channels · now'), findsOneWidget);
    // Advanced cards are hidden until the toggle is flipped.
    expect(find.text('Pace to target'), findsNothing);

    await tester.tap(find.byType(TfToggle));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Pace to target'), findsOneWidget);
    expect(find.text('Orders by staff'), findsOneWidget);

    controller.dispose();
  });
}
