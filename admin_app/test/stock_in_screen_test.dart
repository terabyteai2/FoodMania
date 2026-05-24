import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/inventory/stock_in_screen.dart';
import 'package:local_pos/src/models/inventory_item.dart';
import 'package:local_pos/src/models/inventory_unit.dart';

Widget _scoped(PosAppController controller, Widget child) {
  return AppScope(
    controller: controller,
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

void main() {
  testWidgets('StockInScreen renders without throwing', (tester) async {
    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller, const StockInScreen()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Stock in'), findsOneWidget);
    expect(find.text('Scan a receipt or add items manually.'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('StockInScreen shows inventory picker and adds an item', (
    tester,
  ) async {
    final now = DateTime(2026, 5, 24, 10);
    final controller = PosAppController()
      ..language = AppLanguage.en
      ..inventoryItems = [
        InventoryItem(
          id: 'inv-onion',
          name: 'Onion',
          category: 'Raw',
          unit: InventoryUnits.kg,
          quantity: 4,
          minThreshold: 1,
          costPerUnit: 60,
          notes: '',
          createdAt: now,
          updatedAt: now,
        ),
      ];

    await tester.pumpWidget(_scoped(controller, const StockInScreen()));
    await tester.pump();

    expect(find.text('Add from inventory'), findsOneWidget);
    expect(find.text('Onion'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('stock-in-add-inv-onion')));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('stock-in-line-inv-onion')),
      findsOneWidget,
    );
    expect(find.text('Added'), findsOneWidget);

    controller.dispose();
  });
}
