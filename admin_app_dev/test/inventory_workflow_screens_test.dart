import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/inventory/end_of_day_count_screen.dart';
import 'package:local_pos/src/features/inventory/used_stock_screen.dart';
import 'package:local_pos/src/models/inventory_item.dart';

Widget _scoped(PosAppController controller, Widget child) => AppScope(
  controller: controller,
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  final now = DateTime(2026, 6, 1);
  late PosAppController controller;

  setUp(() {
    controller = PosAppController()
      ..language = AppLanguage.en
      ..inventoryItems = [
        InventoryItem(
          id: 'rice',
          name: 'Rice',
          category: 'Dry',
          unit: 'kg',
          quantity: 12,
          minThreshold: 4,
          costPerUnit: 60,
          createdAt: now,
          updatedAt: now,
        ),
      ];
  });

  tearDown(() => controller.dispose());

  testWidgets('used stock page exposes reasons and quantity meter', (
    tester,
  ) async {
    await tester.pumpWidget(_scoped(controller, const UsedStockScreen()));
    await tester.pump();

    expect(find.text('Record used stock'), findsOneWidget);
    expect(find.text('Spoiled'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('end-of-day count page lists countable inventory items', (
    tester,
  ) async {
    await tester.pumpWidget(_scoped(controller, const EndOfDayCountScreen()));
    await tester.pump();

    expect(find.text('Stock Remaining'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Finish count'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
