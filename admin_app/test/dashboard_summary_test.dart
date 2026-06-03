import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/models/dashboard_summary.dart';

void main() {
  test('dashboard summary keeps additive fields backward compatible', () {
    final legacy = DashboardSummary.fromJson({
      'asOf': '2026-06-01T00:00:00Z',
      'moneyFirst': {},
      'rightNow': {},
      'review': {'fleet': {}},
    });

    expect(legacy.moneyFirst.serviceMix, isEmpty);
    expect(legacy.rightNow.floorTables, isEmpty);
    expect(legacy.review!.fleet.alerts, isEmpty);
    expect(legacy.review!.fleet.goal.targetBdt, 0);
  });

  test('dashboard summary parses floor, service mix, and fleet operations', () {
    final summary = DashboardSummary.fromJson({
      'asOf': '2026-06-01T00:00:00Z',
      'moneyFirst': {
        'serviceMix': [
          {'key': 'delivery', 'label': 'Delivery', 'valueBdt': 450, 'pct': 30},
        ],
      },
      'rightNow': {
        'floorTables': [
          {'tableNo': '3', 'state': 'bill', 'covers': 4, 'orderId': 'order-3'},
        ],
      },
      'review': {
        'fleet': {
          'goal': {'targetBdt': 10000, 'progressPct': 75, 'remainingBdt': 2500},
          'alerts': [
            {
              'kind': 'capacity',
              'title': 'Main is full',
              'body': '90% occupancy',
            },
          ],
          'benchmarks': {
            'bestAvgTicketOutlet': 'Main',
            'worstLateOutlet': 'North',
          },
          'staffingSuggestion': {'outletName': 'North', 'peakLabel': '8:00 PM'},
          'openOutlets': ['Main'],
        },
      },
    });

    expect(summary.moneyFirst.serviceMix.single.key, 'delivery');
    expect(summary.rightNow.floorTables.single.state, 'bill');
    expect(summary.review!.fleet.goal.progressPct, 75);
    expect(summary.review!.fleet.alerts.single.kind, 'capacity');
    expect(summary.review!.fleet.openOutlets, ['Main']);
  });
}
