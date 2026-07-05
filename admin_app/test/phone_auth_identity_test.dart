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
  test('login result parses account fields without email/username', () {
    final result = AdminLoginResult.fromAuthPayload(
      _authPayload(
        account: {
          'id': 'account-1',
          'displayName': 'John',
          'role': 'waiter',
        },
      ),
    );

    expect(result.accountId, 'account-1');
    expect(result.displayName, 'John');
    expect(result.role, AccountRole.waiter);
  });

  test('staff member name falls back to phone when display name is missing', () {
    final staff = StaffMember(
      id: 'staff-1',
      role: AccountRole.waiter,
      isActive: true,
      phone: '01921512040',
      email: '01921512040@phone.rastarant.local',
    );

    expect(staff.name, '01921512040');
  });

  test('adding phone staff without cloud config returns missing token', () async {
    final controller = PosAppController()..accountRole = AccountRole.manager;

    final ok = await controller.addStaffPhone('01921512040', displayName: ' ');

    expect(ok, isFalse);
    expect(controller.lastError, contains('Missing token'));

    controller.dispose();
  });
}
