import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/features/inventory/inventory_screen.dart';
import 'package:local_pos/src/features/inventory/stock_in_screen.dart';
import 'package:local_pos/src/models/inventory_item.dart';
import 'package:local_pos/src/models/inventory_summary.dart';
import 'package:local_pos/src/models/inventory_unit.dart';
import 'package:local_pos/src/models/account_role.dart';

class _RecordingController extends PosAppController {
  _RecordingController() {
    language = AppLanguage.en;
    subscriptionState = 'trial';
    inventorySummary = _summary(onHand: 5);
  }

  final List<({String itemId, double qty})> commits = [];

  @override
  Future<InventoryItem> setInventoryQuantity({
    required String inventoryItemId,
    required double newQuantity,
    String note = 'Manual edit',
  }) async {
    commits.add((itemId: inventoryItemId, qty: newQuantity));
    final items = inventorySummary?.items ?? const <InventorySummaryItem>[];
    inventorySummary = InventorySummary(
      asOf: DateTime.now(),
      stockValueBdt: 0,
      varianceTodayBdt: 0,
      varianceItemCount: 0,
      alerts: 0,
      categories: const [],
      items: [
        for (final item in items)
          item.id == inventoryItemId
              ? InventorySummaryItem(
                  id: item.id,
                  nameEn: item.nameEn,
                  nameBn: item.nameBn,
                  category: item.category,
                  unit: item.unit,
                  onHand: newQuantity,
                  minThreshold: item.minThreshold,
                  todayIn: item.todayIn,
                  todayOut: item.todayOut,
                  todaySpendBdt: item.todaySpendBdt,
                  varianceQty: item.varianceQty,
                  varianceStatus: item.varianceStatus,
                  costPerUnit: item.costPerUnit,
                )
              : item,
      ],
    );
    notifyListeners();
    return InventoryItem(
      id: inventoryItemId,
      name: 'Rice',
      category: 'grains',
      unit: InventoryUnits.kg,
      quantity: newQuantity,
      minThreshold: 2,
      costPerUnit: 10,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

InventorySummary _summary({double onHand = 5}) {
  return InventorySummary(
    asOf: DateTime.now(),
    stockValueBdt: 0,
    varianceTodayBdt: 0,
    varianceItemCount: 0,
    alerts: 0,
    categories: const [],
    items: [
      InventorySummaryItem(
        id: 'item-1',
        nameEn: 'Rice',
        nameBn: '',
        category: 'grains',
        unit: 'kg',
        onHand: onHand,
        minThreshold: 2,
        todayIn: 0,
        todayOut: 0,
        todaySpendBdt: 0,
        varianceQty: 0,
        varianceStatus: 'ok',
        costPerUnit: 10,
      ),
    ],
  );
}

Widget _scoped(PosAppController controller) {
  return AppScope(
    controller: controller,
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const InventoryScreen(),
    ),
  );
}

void main() {
  testWidgets('tapping the qty value opens the scrubber panel, not the row',
      (tester) async {
    final controller = _RecordingController();
    await tester.pumpWidget(_scoped(controller));
    await tester.pump();

    expect(find.text('5'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.pump();

    // The tapped value now opens the anchored scrubber panel (slider +
    // editor); the row's detail screen must NOT be pushed.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byType(StockInScreen), findsNothing);
    expect(controller.commits, isEmpty);
    // Cell + panel label + panel editor each show the current value while
    // the delta is 0.
    expect(find.text('5'), findsNWidgets(3));

    controller.dispose();
  });

  testWidgets('typing a new qty and submitting commits once and updates the row',
      (tester) async {
    final controller = _RecordingController();
    await tester.pumpWidget(_scoped(controller));
    await tester.pump();

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '12');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();

    expect(controller.commits, hasLength(1));
    expect(controller.commits.single.itemId, 'item-1');
    expect(controller.commits.single.qty, 12);
    expect(find.text('12'), findsWidgets);
    expect(find.byType(TextField), findsNothing);
    // The struck-old / colored-new pair flashes ~1s, then settles.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('12'), findsOneWidget);
    expect(find.text('5'), findsNothing);

    controller.dispose();
  });

  testWidgets('tapping away commits the pending edit', (tester) async {
    final controller = _RecordingController();
    await tester.pumpWidget(_scoped(controller));
    await tester.pump();

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '3');
    // Tap a point clearly outside the panel (barrier commits + closes).
    await tester.tapAt(const Offset(30, 300));
    await tester.pump();
    await tester.pump();

    expect(controller.commits, hasLength(1));
    expect(controller.commits.single.qty, 3);
    expect(find.byType(TextField), findsNothing);
    await tester.pump(const Duration(seconds: 1));

    controller.dispose();
  });

  testWidgets('empty or invalid input reverts without committing',
      (tester) async {
    final controller = _RecordingController();
    await tester.pumpWidget(_scoped(controller));
    await tester.pump();

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.pump();

    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(controller.commits, isEmpty);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('5'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('waiter role cannot edit quantities', (tester) async {
    final controller = _RecordingController()
      ..realAccountRole = AccountRole.waiter;
    await tester.pumpWidget(_scoped(controller));
    await tester.pump();

    await tester.tap(find.text('5'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(TextField), findsNothing);
    expect(find.byType(Slider), findsNothing);
    expect(controller.commits, isEmpty);

    controller.dispose();
  });
}