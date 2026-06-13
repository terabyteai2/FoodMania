import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/features/desktop_pos/desk_controller.dart';
import 'package:local_pos/src/features/desktop_pos/widgets/dk_icons.dart';
import 'package:local_pos/src/features/desktop_pos/widgets/dk_kit.dart';
import 'package:local_pos/src/features/desktop_pos/widgets/menu_line_customizer.dart';
import 'package:local_pos/src/models/account_role.dart';
import 'package:local_pos/src/models/menu_item.dart';
import 'package:local_pos/src/models/order_service_type.dart';

MenuItem _item({String id = 'm1', double price = 100}) => MenuItem(
      id: id,
      name: 'Test Item',
      description: 'desc',
      category: 'Burgers',
      price: price,
      isAvailable: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  group('deskNavForRole', () {
    test('owner gets 5 operational tabs ending in dashboard (Analytics)', () {
      final nav = deskNavForRole(AccountRole.owner);
      expect(nav.length, 5);
      expect(nav.map((e) => e.tab).toList(),
          [DeskTab.register, DeskTab.tables, DeskTab.orders, DeskTab.inventory, DeskTab.dashboard]);
      expect(nav.last.labelEn, 'Analytics');
    });

    test('manager dashboard tab is labelled Live', () {
      expect(deskNavForRole(AccountRole.manager).last.labelEn, 'Live');
    });

    test('waiter gets only Register/Tables/Orders (back-office stays on mobile)', () {
      final nav = deskNavForRole(AccountRole.waiter);
      expect(nav.map((e) => e.tab).toList(), [DeskTab.register, DeskTab.tables, DeskTab.orders]);
    });
  });

  group('DeskController draft', () {
    test('adding the same regular line twice merges and sums qty', () {
      final c = DeskController();
      c.addDraftLine(desktopRegularMenuLine(_item()));
      c.addDraftLine(desktopRegularMenuLine(_item()));
      expect(c.draft.lines.length, 1);
      expect(c.draft.lines.first.qty, 2);
      expect(c.draft.count, 2);
    });

    test('setDraftType to non-delivery clears area + charge', () {
      final c = DeskController();
      c.setDraftArea('Uttara', 150);
      c.setDraftType(OrderServiceType.delivery);
      expect(c.draft.area, 'Uttara');
      c.setDraftType(OrderServiceType.dineIn);
      expect(c.draft.area, isNull);
      expect(c.draft.charge, 0);
    });

    test('startDineIn seeds a fresh dine-in draft and switches to Register', () {
      final c = DeskController();
      c.setTab(DeskTab.orders);
      c.startDineIn('5');
      expect(c.tab, DeskTab.register);
      expect(c.draft.type, OrderServiceType.dineIn);
      expect(c.draft.table, '5');
    });

    test('clampToRole resets a forbidden tab to Register', () {
      final c = DeskController();
      c.setTab(DeskTab.inventory);
      c.clampToRole(AccountRole.waiter); // waiter has no Stock tab
      expect(c.tab, DeskTab.register);
    });
  });

  group('dkMoney', () {
    test('groups thousands with the Taka sign', () {
      expect(dkMoney(1551), '৳1,551');
      expect(dkMoney(60), '৳60');
      expect(dkMoney(184600), '৳184,600');
    });

    test('handles negatives (change/discount)', () {
      expect(dkMoney(-50), '-৳50');
    });
  });

  group('parseSvgPath', () {
    test('parses a closed square to the expected bounds', () {
      final p = parseSvgPath('M0 0 L10 0 L10 10 L0 10 Z');
      final b = p.getBounds();
      expect(b.left, closeTo(0, 0.01));
      expect(b.top, closeTo(0, 0.01));
      expect(b.right, closeTo(10, 0.01));
      expect(b.bottom, closeTo(10, 0.01));
    });

    test('handles relative commands and arc flags without throwing', () {
      // The trickiest real icon path (search) mixes relative line + arc flags.
      final p = parseSvgPath(kDkIconPaths['search']!);
      expect(p.getBounds().isEmpty, isFalse);
    });
  });
}
