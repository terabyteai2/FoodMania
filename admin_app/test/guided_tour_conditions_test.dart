import 'package:flutter_test/flutter_test.dart';

import 'package:local_pos/src/app.dart';
import 'package:local_pos/src/core/widgets/guided_tour.dart';

List<String> _spotNames(List<TourStep> steps) =>
    [for (final s in steps) if (s.spot != null) s.spot!];

void main() {
  group('buildTourSteps', () {
    const managerTabs = [
      'orders',
      'menu',
      'stock',
      'live',
      'salesSummary',
      'more',
    ];
    const ownerTabs = [
      'analytics',
      'orders',
      'stock',
      'menu',
      'reports',
      'more',
    ];
    const waiterTabs = ['tables', 'orders', 'more'];

    test('every step points at a spot; opens with the surface intro, then the '
        'shared header walk', () {
      final steps = buildTourSteps(
        tabs: managerTabs,
        noMenu: false,
        completedOrders: 0,
        canCreateOrders: true,
        actions: const {},
      );
      expect(steps.every((s) => !s.isOverview), isTrue);
      expect(steps.every((s) => s.spot != null), isTrue);
      expect(steps.first.spot, 'orders.newOrderFab');
      expect(
        _spotNames(steps).skip(1).take(3),
        ['header.menu', 'header.bell', 'header.avatar'],
      );
    });

    test('manager without creatable orders retargets the intro to the '
        'hamburger instead of the missing FAB', () {
      final steps = buildTourSteps(
        tabs: managerTabs,
        noMenu: false,
        completedOrders: 0,
        canCreateOrders: false,
        actions: const {},
      );
      expect(steps.first.spot, 'header.menu');
      expect(_spotNames(steps), isNot(contains('orders.newOrderFab')));
      // No duplicate hamburger step — the intro already covers it.
      expect(
        _spotNames(steps).where((s) => s == 'header.menu').length,
        1,
      );
    });

    test('empty menu adds the sidebar -> Menu -> scan-card flow (manager)',
        () {
      final steps = buildTourSteps(
        tabs: managerTabs,
        noMenu: true,
        completedOrders: 0,
        canCreateOrders: true,
        actions: const {},
      );
      expect(
        _spotNames(steps),
        containsAllInOrder(['nav.menu', 'menu.scanCta']),
      );
    });

    test('no menu steps when the Menu tab is not reachable (waiter)', () {
      final steps = buildTourSteps(
        tabs: waiterTabs,
        noMenu: true,
        completedOrders: 0,
        canCreateOrders: true,
        actions: const {},
      );
      expect(_spotNames(steps), isNot(contains('nav.menu')));
      expect(_spotNames(steps), isNot(contains('menu.scanCta')));
      expect(_spotNames(steps), contains('tables.grid'));
    });

    test('sales summary step appears at 20+ completed orders with live count',
        () {
      final steps = buildTourSteps(
        tabs: managerTabs,
        noMenu: false,
        completedOrders: 20,
        canCreateOrders: true,
        actions: const {},
      );
      final sales = steps.singleWhere((s) => s.spot == 'nav.salesSummary');
      expect(sales.body, contains('20 completed orders'));

      final below = buildTourSteps(
        tabs: managerTabs,
        noMenu: false,
        completedOrders: 19,
        canCreateOrders: true,
        actions: const {},
      );
      expect(_spotNames(below), isNot(contains('nav.salesSummary')));
    });

    test('owner surface gets analytics and reports pointers', () {
      final steps = buildTourSteps(
        tabs: ownerTabs,
        noMenu: false,
        completedOrders: 40,
        canCreateOrders: true,
        actions: const {},
      );
      expect(steps.first.spot, 'analytics.stats');
      expect(_spotNames(steps), contains('nav.analytics'));
      expect(_spotNames(steps), contains('nav.reports'));
      // Owners have no Sales Summary destination -> no step, even at 40.
      expect(_spotNames(steps), isNot(contains('nav.salesSummary')));
    });

    test('owner with an empty menu gets both passes merged', () {
      final steps = buildTourSteps(
        tabs: ownerTabs,
        noMenu: true,
        completedOrders: 0,
        canCreateOrders: true,
        actions: const {},
      );
      expect(
        _spotNames(steps),
        containsAllInOrder([
          'analytics.stats',
          'nav.menu',
          'menu.scanCta',
          'nav.analytics',
          'nav.reports',
        ]),
      );
    });

    test('waiter gets only the tables pointer', () {
      final steps = buildTourSteps(
        tabs: waiterTabs,
        noMenu: false,
        completedOrders: 99,
        canCreateOrders: true,
        actions: const {},
      );
      expect(_spotNames(steps), contains('tables.grid'));
      expect(_spotNames(steps), isNot(contains('orders.newOrderFab')));
      expect(_spotNames(steps), isNot(contains('nav.salesSummary')));
    });

    test('manager without creatable orders drops the FAB step', () {
      final steps = buildTourSteps(
        tabs: managerTabs,
        noMenu: false,
        completedOrders: 0,
        canCreateOrders: false,
        actions: const {},
      );
      expect(_spotNames(steps), isNot(contains('orders.newOrderFab')));
    });

    test('enter actions are wired from the actions map', () {
      void openDrawer() {}
      void selectMenu() {}
      final steps = buildTourSteps(
        tabs: managerTabs,
        noMenu: true,
        completedOrders: 0,
        canCreateOrders: true,
        actions: {'openDrawer': openDrawer, 'selectMenu': selectMenu},
      );
      final menu = steps.singleWhere((s) => s.spot == 'nav.menu');
      final scan = steps.singleWhere((s) => s.spot == 'menu.scanCta');
      expect(menu.onEnter, same(openDrawer));
      expect(scan.onEnter, same(selectMenu));
    });
  });
}
