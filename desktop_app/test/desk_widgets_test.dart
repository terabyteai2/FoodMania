// Verifies the design-reset shared widgets (DESIGN_RESET_REFERENCE.md) lay out
// and — for the charts — paint without throwing. These are pure-UI (no AppScope
// / SQLite), so they run headless, unlike the full DesktopApp.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quickbytes_desktop/desktop/theme/desk_widgets.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 640, child: child)),
      ),
    );

void main() {
  testWidgets('DeskStatTile shows value + label', (tester) async {
    await tester.pumpWidget(_host(const DeskStatTile(
      label: 'Orders',
      value: '42',
      icon: Icons.receipt_long_rounded,
    )));
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DeskSegment reports selection changes', (tester) async {
    var value = 'today';
    await tester.pumpWidget(_host(StatefulBuilder(
      builder: (context, setState) => DeskSegment<String>(
        options: const [('today', 'Today'), ('week', '7 days')],
        value: value,
        onChanged: (v) => setState(() => value = v),
      ),
    )));
    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.text('7 days'));
    await tester.pump();
    expect(value, 'week');
  });

  testWidgets('DeskCard renders title + child', (tester) async {
    await tester.pumpWidget(_host(const DeskCard(
      title: 'Revenue trend',
      child: Text('body'),
    )));
    expect(find.text('Revenue trend'), findsOneWidget);
    expect(find.text('body'), findsOneWidget);
  });

  testWidgets('DeskDonut paints slices + legend', (tester) async {
    await tester.pumpWidget(_host(const DeskDonut(
      centerValue: '৳100',
      centerLabel: 'collected',
      data: [
        DeskDatum('Cash', 60, '৳60'),
        DeskDatum('Card', 40, '৳40'),
      ],
    )));
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('৳100'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DeskDonut is NULL-safe on a zero total', (tester) async {
    await tester.pumpWidget(_host(const DeskDonut(
      centerValue: '৳0',
      centerLabel: 'collected',
      data: [DeskDatum('Cash', 0, '৳0')],
    )));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DeskBars renders labelled bars', (tester) async {
    await tester.pumpWidget(_host(const DeskBars(data: [
      DeskDatum('Dine In', 100, '৳100'),
      DeskDatum('Delivery', 50, '৳50'),
    ])));
    expect(find.text('Dine In'), findsOneWidget);
    expect(find.text('৳50'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DeskTrendChart paints with data and when empty', (tester) async {
    await tester
        .pumpWidget(_host(const DeskTrendChart(values: [1, 3, 2, 5, 4])));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(_host(const DeskTrendChart(values: [])));
    expect(tester.takeException(), isNull);
  });
}
