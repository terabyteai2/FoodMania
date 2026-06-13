import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/staff/staff_screen.dart';

Widget _scoped(PosAppController controller) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: AppTheme.light(), home: const StaffScreen()),
  );
}

void main() {
  testWidgets('staff screen shows invite CTA and degrades gracefully', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    // Bottom-bar invite CTA is always present.
    expect(find.text('Invite staff'), findsOneWidget);
    // No cloud config → graceful retry state.
    expect(find.text('Retry'), findsOneWidget);

    controller.dispose();
  });
}
