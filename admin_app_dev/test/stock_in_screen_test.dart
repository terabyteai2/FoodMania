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
  testWidgets('StockInScreen renders the source reset layout', (tester) async {
    final controller = PosAppController()..language = AppLanguage.en;

    await tester.pumpWidget(_scoped(controller, const StockInScreen()));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Stock in'), findsOneWidget);
    expect(find.text('Add received stock'), findsOneWidget);
    expect(find.text('Item name'), findsOneWidget);
    expect(find.text('Quantity'), findsOneWidget);
    expect(find.text('Cost / kg'), findsOneWidget);
    expect(find.text('Add another line'), findsOneWidget);
    expect(find.text('Total stock-in value'), findsOneWidget);
    expect(find.text('Scan bill'), findsOneWidget);
    expect(find.text('Add to inventory'), findsOneWidget);

    expect(find.text('Scan a receipt or add items manually.'), findsNothing);
    expect(find.text('Add from inventory'), findsNothing);
    expect(find.text('Bill reference (optional)'), findsNothing);
    expect(find.byIcon(Icons.photo_library_outlined), findsNothing);

    controller.dispose();
  });

  testWidgets(
    'Add another line creates a second source card with remove controls',
    (tester) async {
      final controller = PosAppController()..language = AppLanguage.en;

      await tester.pumpWidget(_scoped(controller, const StockInScreen()));
      await tester.pump();

      expect(find.text('Item name'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      await tester.tap(find.text('Add another line'));
      await tester.pump();

      expect(find.text('Item name'), findsNWidgets(2));
      expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump();

      expect(find.text('Item name'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsNothing);

      controller.dispose();
    },
  );

  testWidgets('Preseeded item fills the source line and header subtitle', (
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

    await tester.pumpWidget(
      _scoped(controller, const StockInScreen(preseedItemId: 'inv-onion')),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Stock in'), findsOneWidget);
    expect(find.text('Onion'), findsWidgets);
    expect(
      find.byKey(const ValueKey('stock-in-line-inv-onion')),
      findsOneWidget,
    );
    expect(find.text('Cost / kg'), findsOneWidget);
    expect(find.text('60'), findsOneWidget);

    controller.dispose();
  });

  testWidgets(
    'Quantity field keeps unit selector left of amount and updates cost label',
    (tester) async {
      final controller = PosAppController()..language = AppLanguage.en;

      await tester.pumpWidget(_scoped(controller, const StockInScreen()));
      await tester.pump();

      expect(find.text('Quantity'), findsOneWidget);
      expect(find.text('Cost / kg'), findsOneWidget);

      await tester.tap(find.text('kg').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('gm').last);
      await tester.pumpAndSettle();

      expect(find.text('Cost / gm'), findsOneWidget);
      expect(find.text('Quantity'), findsOneWidget);

      controller.dispose();
    },
  );
}
