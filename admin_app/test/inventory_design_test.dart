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
  testWidgets('standard inventory matches the compact reference hierarchy', (
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
        categories: [
          InventoryCategoryBucket(
            key: 'all',
            labelEn: 'All',
            labelBn: 'সব',
            count: 2,
          ),
          InventoryCategoryBucket(
            key: 'meat',
            labelEn: 'Meat',
            labelBn: 'মাংস',
            count: 1,
          ),
        ],
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
          _summaryItem(
            id: 'mutton',
            nameEn: 'Mutton',
            nameBn: 'খাসি',
            category: 'meat',
            onHand: 0.8,
            todayOut: 1.8,
            todaySpendBdt: 1980,
            varianceStatus: 'low',
          ),
        ],
      );

    await tester.pumpWidget(_scoped(controller));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('STOCK VALUE'), findsOneWidget);
    expect(find.text('TOP MOVERS · TODAY'), findsOneWidget);
    expect(find.text('ALL ITEMS'), findsOneWidget);
    expect(find.text('Mutton'), findsWidgets);
    expect(find.text('LOW'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('complexity-dial-dropdown')),
      findsOneWidget,
    );

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
