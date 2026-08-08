import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/audit/audit_screen.dart';

Widget _scoped(PosAppController controller) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: AppTheme.light(), home: const AuditScreen()),
  );
}

void main() {
  testWidgets('audit screen renders filter chips and degrades gracefully', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller));
    await tester.pump(); // didChangeDependencies + first build
    await tester.pump(const Duration(milliseconds: 50)); // future resolves

    expect(tester.takeException(), isNull);
    // Type-filter chips render (the row is horizontally scrollable, so only
    // the leading chips are laid out in a 360px viewport).
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Void'), findsOneWidget);
    expect(find.text('Refund'), findsOneWidget);
    // With no cloud config the fetch fails → graceful error state (Retry).
    expect(find.text('Retry'), findsOneWidget);

    controller.dispose();
  });
}
