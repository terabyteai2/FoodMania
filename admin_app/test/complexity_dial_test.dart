import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/enums/business_tier.dart';
import 'package:local_pos/src/core/widgets/complexity_dial.dart';

void main() {
  testWidgets('complexity dropdown exposes every tier and changes selection', (
    tester,
  ) async {
    final app = PosAppController();

    await tester.pumpWidget(
      AppScope(
        controller: app,
        child: const MaterialApp(home: Scaffold(body: HeaderComplexityDial())),
      ),
    );

    expect(find.text('Cafe'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('complexity-dial-dropdown')));
    await tester.pumpAndSettle();

    for (final tier in BusinessTier.values) {
      expect(find.byKey(ValueKey('complexity-dial-${tier.key}')), findsOne);
      expect(find.text(tier.displayName), findsWidgets);
    }
    expect(find.text('FoodCart'), findsOneWidget);
    expect(find.text('Restaurant'), findsOneWidget);
    expect(find.text('Enterprise'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('complexity-dial-enterprise')));
    await tester.pumpAndSettle();

    expect(app.businessTier, BusinessTier.enterprise);
  });
}
