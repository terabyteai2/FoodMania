import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/localization/app_strings.dart';
import 'package:local_pos/src/features/analytics/analytics_screen.dart';

class _AnalyticsController extends PosAppController {
  _AnalyticsController(this.payload);

  final Map<String, Object?> payload;

  @override
  Future<Map<String, Object?>> fetchAnalyticsSummary({
    String range = 'today',
    String? start,
    String? end,
    String? service,
    String? paymentMethod,
    String? shiftId,
    String? user,
  }) async {
    return payload;
  }
}

Widget _scoped(PosAppController controller) {
  return AppScope(
    controller: controller,
    child: const MaterialApp(home: AnalyticsScreen()),
  );
}

void main() {
  testWidgets(
    'Sales Breakdown renders sections when collection has data without items',
    (tester) async {
      final controller = _AnalyticsController({
        'salesSummary': {
          'ordersCompleted': 0,
          'grossSales': 0,
          'discountByStaff': 0,
          'netSales': 0,
        },
        'totalCollection': 42,
        'collection': [
          {'key': 'cash', 'label': 'Cash', 'valueBdt': 42},
        ],
        'serviceWise': [],
        'profit': {'grossProfit': 0},
        'popularDishes': [],
        'itemWise': [],
        'trend': [],
      })..language = AppLanguage.en;
      addTearDown(controller.dispose);

      await tester.pumpWidget(_scoped(controller));
      await tester.pumpAndSettle();

      expect(find.text('Sales Summary'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Collection Summary'),
        240,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Collection Summary'), findsOneWidget);
      expect(find.text('No analytics yet'), findsNothing);
    },
  );
}
