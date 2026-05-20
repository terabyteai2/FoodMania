import 'package:flutter/foundation.dart';

/// Optional dev staff login without Google (server must set STAFF_DEV_BYPASS_SECRET).
class DevAuthDefaults {
  DevAuthDefaults._();

  /// Show "Dev sign-in (no Google)" when true, OR in debug builds (`flutter run`).
  static bool get showStaffBypassUi =>
      kDebugMode ||
      bool.fromEnvironment('POS_STAFF_DEV_BYPASS', defaultValue: false);
}
