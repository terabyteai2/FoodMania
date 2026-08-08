import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/core/theme/app_theme.dart';
import 'package:local_pos/src/core/widgets/app_scaffold.dart';
import 'package:local_pos/src/core/widgets/tf_design_system.dart';
import 'package:local_pos/src/core/widgets/tf_global_top_bar.dart';

void main() {
  testWidgets('source brand header matches wordmark and mark sizing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: TfBrandHeader(
            title: 'QuickBytes',
            subtitle: 'Spice Garden - Dhanmondi',
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(TfBrandMark)), const Size(35, 35));

    final wordmark = tester.widget<RichText>(
      find.byWidgetPredicate(
        (w) => w is RichText && w.text.toPlainText() == 'QuickBytes',
      ),
    );
    final span = wordmark.text as TextSpan;
    expect(span.style?.fontSize, 20);
    expect(span.style?.fontWeight, FontWeight.w800);
    expect(
      (span.children!.first as TextSpan).style?.fontWeight,
      FontWeight.w600,
    );
  });

  testWidgets('source bar button is 42 square with source badge typography', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: TfBarButton(
              icon: TfSourceIconName.chat,
              tooltip: 'Messages',
              badge: 3,
              onPressed: () {},
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(TfBarButton)), const Size(42, 42));

    final badge = tester.widget<Text>(find.text('3'));
    expect(badge.style?.fontSize, 10.5);
    expect(badge.style?.fontWeight, FontWeight.w800);
  });

  testWidgets('pushed AppScaffold header uses the v4 slim-bar title and '
      'source back icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const AppScaffold(
          title: 'Audit trail',
          showBackButton: true,
          child: SizedBox.shrink(),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Audit trail'));
    expect(title.style?.fontSize, TfTextStyles.appBarTitle.fontSize);
    expect(title.style?.fontWeight, FontWeight.w700);

    final backIcon = tester.widget<TfSourceIcon>(find.byType(TfSourceIcon));
    expect(backIcon.name, TfSourceIconName.back);
    expect(backIcon.size, 22);
    expect(backIcon.strokeWidth, 2);
  });

  testWidgets('root TfGlobalTopBar renders its title', (tester) async {
    await tester.pumpWidget(
      AppScope(
        controller: PosAppController(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: TfGlobalTopBar(title: 'Tables')),
        ),
      ),
    );

    expect(find.text('Tables'), findsOneWidget);
  });
}
