import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/core/widgets/tf_design_system.dart';
import 'package:local_pos/src/features/inventory/inventory_screen.dart';
import 'package:local_pos/src/models/inventory_summary.dart';

Widget _scoped(PosAppController controller) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: AppTheme.light(), home: const InventoryScreen()),
  );
}

void main() {
  testWidgets('stock screen renders the ranked table (spec §4.7)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = PosAppController()
      ..language = AppLanguage.en
      ..inventorySummary = InventorySummary(
        asOf: DateTime(2026, 6, 1),
        stockValueBdt: 12096,
        varianceTodayBdt: 0,
        varianceItemCount: 0,
        alerts: 1,
        categories: const [],
        items: [
          _summaryItem(
            id: 'rice',
            nameEn: 'Rice',
            nameBn: 'চাল',
            category: 'grain',
            onHand: 12,
            todayOut: 4.2,
            todaySpendBdt: 252,
          ),
          // ratio = onHand / par = 0.3 / 1 = 0.3 → below 0.6 ⇒ a 'low' dot.
          _summaryItem(
            id: 'mutton',
            nameEn: 'Mutton',
            nameBn: 'খাসি',
            category: 'meat',
            onHand: 0.3,
            todayOut: 1.8,
            todaySpendBdt: 1980,
            varianceStatus: 'low',
          ),
        ],
      );

    await tester.pumpWidget(_scoped(controller));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // Summary strip.
    expect(find.text('Stock value'), findsOneWidget);
    expect(find.text('Below par'), findsOneWidget);
    // Inventory eyebrow + advanced toggle.
    expect(find.text('INVENTORY'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    // Ranked table headers (QTY is the rightmost, left-justified column).
    expect(find.text('ITEM'), findsOneWidget);
    expect(find.text('VALUE'), findsOneWidget);
    expect(find.text('QTY'), findsOneWidget);
    // Items are listed.
    expect(find.text('Rice'), findsWidgets);
    expect(find.text('Mutton'), findsWidgets);
    // Bottom-bar actions replace top-bar buttons.
    expect(find.text('Count'), findsOneWidget);
    expect(find.text('Stock in'), findsOneWidget);
    // COVER column is hidden until Advanced is on.
    expect(find.text('COVER'), findsNothing);

    // Flip the Advanced toggle → cover column appears.
    await tester.tap(find.byType(AdvToggle));
    await tester.pump();
    expect(find.text('COVER'), findsOneWidget);

    controller.dispose();
  });
}

InventorySummaryItem _summaryItem({
  required String id,
  required String nameEn,
  required String nameBn,
  required String category,
  required double onHand,
  required double todayOut,
  required double todaySpendBdt,
  String varianceStatus = 'ok',
}) {
  return InventorySummaryItem(
    id: id,
    nameEn: nameEn,
    nameBn: nameBn,
    category: category,
    unit: 'kg',
    onHand: onHand,
    minThreshold: 1,
    todayIn: 0,
    todayOut: todayOut,
    todaySpendBdt: todaySpendBdt,
    varianceQty: 0,
    varianceStatus: varianceStatus,
    costPerUnit: 60,
  );
}
