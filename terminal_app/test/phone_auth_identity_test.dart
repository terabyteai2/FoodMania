import 'package:flutter_test/flutter_test.dart';
import 'package:local_pos/src/app_controller.dart';
import 'package:local_pos/src/models/account_role.dart';
import 'package:local_pos/src/models/staff_member.dart';
import 'package:local_pos/src/services/cloud_api_service.dart';

Map<String, Object?> _authPayload({required Map<String, Object?> account}) {
  return {
    'serverId': 'server-1',
    'restaurantId': 'restaurant-1',
    'outletId': 'outlet-1',
    'restaurantName': 'Cafe',
    'outletName': 'Cafe Outlet',
    'deviceToken': 'device-token',
    'tableCount': 10,
    'account': account,
  };
}

void main() {
  test('login result strips synthetic phone identifiers', () {
    final result = AdminLoginResult.fromAuthPayload(
      _authPayload(
        account: {
          'id': 'account-1',
          'email': '01921512040@phone.rastarant.local',
          'username': '+8801921512040@phone.restaurant.local',
          'displayName': '01921512040@phone.rastarant.local',
          'role': 'waiter',
        },
      ),
    );

    expect(result.email, isEmpty);
    expect(result.username, isEmpty);
    expect(result.displayName, isNull);
    expect(result.role, AccountRole.waiter);
  });

  test(
    'controller display label uses role placeholder for no-name phone users',
    () {
      final controller = PosAppController()
        ..accountRole = AccountRole.waiter
        ..accountEmail = '01921512040@phone.rastarant.local'
        ..accountUsername = '01921512040@phone.rastarant.local'
        ..accountDisplayName = '01921512040@phone.rastarant.local';

      expect(controller.accountDisplayLabel, 'Staff member');
      expect(controller.accountDisplayLabel, isNot(contains('@phone')));

      controller.dispose();
    },
  );

  test('staff member name does not fall back to phone or synthetic email', () {
    final staff = StaffMember(
      id: 'staff-1',
      role: AccountRole.waiter,
      isActive: true,
      phone: '01921512040',
      email: '01921512040@phone.rastarant.local',
    );

    expect(staff.name, 'Staff member');
  });

  test('adding phone staff requires a display name before API call', () async {
    final controller = PosAppController()..accountRole = AccountRole.manager;

    final ok = await controller.addStaffPhone('01921512040', displayName: ' ');

    expect(ok, isFalse);
    expect(controller.lastError, contains('Staff name is required'));

    controller.dispose();
  });
}
