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
    // Advanced view toggle lives in the top bar (no INVENTORY eyebrow row).
    expect(find.text('Advanced'), findsOneWidget);
    // Ranked table headers — simple view is ITEM + QTY (no VALUE column).
    expect(find.text('ITEM'), findsOneWidget);
    expect(find.text('VALUE'), findsNothing);
    expect(find.text('QTY'), findsOneWidget);
    // Items are listed.
    expect(find.text('Rice'), findsWidgets);
    expect(find.text('Mutton'), findsWidgets);
    // Bottom-bar actions (Scan moved to the drawer's Stock group).
    expect(find.text('Count'), findsOneWidget);
    expect(find.text('Stock in'), findsOneWidget);
    expect(find.text('Scan'), findsNothing);

    // Flip the Advanced toggle → IN/OUT + NET appear; QTY stays (no COVER).
    await tester.tap(find.byType(AdvToggle));
    await tester.pump();
    expect(find.text('IN/OUT'), findsOneWidget);
    expect(find.text('NET'), findsOneWidget);
    expect(find.text('COVER'), findsNothing);
    expect(find.text('QTY'), findsOneWidget);

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
