import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
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
      ..subscriptionState = 'trial'
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
    // Ranked table headers — ITEM + IN/OUT + UNIT PRICE + QTY (no
    // VALUE/NET/COVER; the old summary strip and sticky footer are gone).
    expect(find.text('ITEM'), findsOneWidget);
    expect(find.text('IN/OUT'), findsOneWidget);
    expect(find.text('UNIT PRICE'), findsOneWidget);
    expect(find.text('QTY'), findsOneWidget);
    expect(find.text('NET'), findsNothing);
    expect(find.text('VALUE'), findsNothing);
    expect(find.text('COVER'), findsNothing);
    expect(find.text('Advanced'), findsNothing);
    // Legacy footer actions are gone (Scan lives in the drawer's Stock group).
    expect(find.text('Count'), findsNothing);
    expect(find.text('Stock in'), findsNothing);
    expect(find.text('Scan'), findsNothing);
    // Items are listed with their unit price.
    expect(find.text('Rice'), findsWidgets);
    expect(find.text('Mutton'), findsWidgets);
    expect(find.text('৳60'), findsNWidgets(2));
    // In-list Add item + advanced drill-downs.
    expect(find.text('Add Item'), findsOneWidget);
    expect(find.text('Daily variance'), findsOneWidget);
    expect(find.text('Suppliers'), findsOneWidget);

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