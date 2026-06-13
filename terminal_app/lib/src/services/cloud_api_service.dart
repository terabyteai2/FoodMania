import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../core/constants/cloud_defaults.dart';
import '../models/bkash_payment_session.dart';
import '../models/payment_gateway_config.dart';
import '../models/account_role.dart';
import '../models/admin_blocking_notice.dart';
import '../models/app_update_info.dart';
import '../models/audit_entry.dart';
import '../models/chat_thread.dart';
import '../models/daily_report.dart';
import '../models/dashboard_summary.dart';
import '../models/facebook_chatbot_config.dart';
import '../models/inventory_item.dart';
import '../models/inventory_summary.dart';
import '../models/inventory_supplier.dart';
import '../models/menu_item.dart';
import '../models/receipt_scan.dart';
import '../models/staff_member.dart';
import '../models/stock_adjustment.dart';
import '../models/order_model.dart';
import '../models/order_status.dart';
import '../models/server_config.dart';

class CloudApiException implements Exception {
  CloudApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Parses JSON from the API; turns ngrok/HTML/plain-text failures into readable [CloudApiException]s.
Object? _decodeCloudJsonBody(String body, Uri uri) {
  final t = body.trim();
  if (t.isEmpty) {
    return <String, Object?>{};
  }
  final lower = t.toLowerCase();
  // ngrok edge returns plain text when tunnel is down or hostname has no session
  if (lower.contains('is offline') ||
      lower.contains('endpoint is offline') ||
      lower.contains('err_ngrok') ||
      lower.contains('tunnel') && lower.contains('gone')) {
    throw CloudApiException(
      'Ngrok tunnel is not reachable at ${uri.scheme}://${uri.host}${uri.path}: '
      '${t.length > 240 ? "${t.substring(0, 240)}…" : t}\n\n'
      'Fix: run `cd backend && bash start_ngrok.sh` on your PC. '
      'In the app, server URL must match your reserved domain exactly '
      'including **.ngrok-free.dev** vs **.ngrok-free.app** — rebuild after changing Flutter defaults.',
    );
  }
  if (t.startsWith('<') ||
      lower.contains('<!doctype') ||
      lower.contains('<html')) {
    throw CloudApiException(
      'Received HTML instead of JSON from $uri. '
      'If you use ngrok, open the same URL in Chrome; add `ngrok-skip-browser-warning` is already sent — '
      'usually the tunnel is down or the hostname is wrong (.dev vs .app).',
    );
  }
  try {
    return jsonDecode(t);
  } on FormatException catch (e) {
    final preview = t.length > 180 ? '${t.substring(0, 180)}…' : t;
    throw CloudApiException(
      'Server response was not JSON (${e.message}). From $uri — body: $preview',
    );
  }
}

class CloudRealtimeConfig {
  CloudRealtimeConfig({
    required this.enabled,
    required this.supabaseUrl,
    required this.publishableKey,
    required this.channelPrefix,
    this.restBaseUrl = '',
    this.deviceToken = '',
  });

  final bool enabled;
  final String supabaseUrl;
  final String publishableKey;
  final String channelPrefix;
  // Used by the Python/native-WebSocket backend
  final String restBaseUrl;
  final String deviceToken;

  // For Supabase realtime: needs supabaseUrl + publishableKey
  // For Python backend: just needs restBaseUrl (enabled can be false)
  bool get canConnect {
    final hasSupabase =
        enabled &&
        supabaseUrl.trim().isNotEmpty &&
        publishableKey.trim().isNotEmpty &&
        channelPrefix.trim().isNotEmpty;
    final hasPython = restBaseUrl.trim().isNotEmpty;
    return hasSupabase || hasPython;
  }

  String channelName(String outletId) => '${channelPrefix.trim()}$outletId';

  static CloudRealtimeConfig? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final supabaseUrl = json['supabaseUrl']?.toString().trim() ?? '';
    final publishableKey = json['publishableKey']?.toString().trim() ?? '';
    final channelPrefix =
        json['channelPrefix']?.toString().trim() ?? 'pos:outlet:';
    return CloudRealtimeConfig(
      enabled: json['enabled'] == true,
      supabaseUrl: supabaseUrl,
      publishableKey: publishableKey,
      channelPrefix: channelPrefix,
    );
  }

  CloudRealtimeConfig withRestInfo({
    required String restBaseUrl,
    required String deviceToken,
  }) {
    return CloudRealtimeConfig(
      enabled: enabled,
      supabaseUrl: supabaseUrl,
      publishableKey: publishableKey,
      channelPrefix: channelPrefix,
      restBaseUrl: restBaseUrl,
      deviceToken: deviceToken,
    );
  }
}

class TenantBootstrapResult {
  TenantBootstrapResult({
    required this.serverId,
    required this.restaurantId,
    required this.outletId,
    required this.restaurantName,
    required this.outletName,
    required this.deviceToken,
    required this.tableCount,
    this.publicApiBaseUrl,
  });

  final String serverId;
  final String restaurantId;
  final String outletId;
  final String restaurantName;
  final String outletName;
  final String deviceToken;
  final int tableCount;
  final String? publicApiBaseUrl;

  static TenantBootstrapResult fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    return TenantBootstrapResult(
      serverId: _required(data, 'serverId'),
      restaurantId: _required(data, 'restaurantId'),
      outletId: _required(data, 'outletId'),
      restaurantName: _required(data, 'restaurantName'),
      outletName: _required(data, 'outletName'),
      deviceToken: _required(data, 'deviceToken'),
      tableCount: _tableCount(data['tableCount']),
      publicApiBaseUrl: _optional(data['publicApiBaseUrl']),
    );
  }

  static String? _optional(Object? value) {
    final s = value?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }

  static String _required(Map<String, Object?> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw CloudApiException('Cloud tenant response is missing $key.');
    }
    return value;
  }

  static int _tableCount(Object? value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return (parsed ?? 10).clamp(0, 200);
  }
}

class AdminLoginResult {
  AdminLoginResult({
    required this.email,
    required this.username,
    required this.accountId,
    required this.role,
    this.displayName,
    required this.serverId,
    required this.restaurantId,
    required this.outletId,
    required this.restaurantName,
    required this.outletName,
    required this.deviceToken,
    required this.tableCount,
    this.publicSlug,
    this.customerMenuUrl,
    this.publicApiBaseUrl,
    this.hasAppAccess = false,
  });

  final String email;
  final String username;
  final String accountId;
  final AccountRole role;
  final String? displayName;
  final String serverId;
  final String restaurantId;
  final String outletId;
  final String restaurantName;
  final String outletName;
  final String deviceToken;
  final int tableCount;
  final String? publicSlug;
  final String? customerMenuUrl;
  final String? publicApiBaseUrl;
  final bool hasAppAccess;

  static AdminLoginResult fromAuthPayload(Map<String, Object?> data) {
    final account = data['account'] is Map
        ? Map<String, Object?>.from(data['account'] as Map)
        : <String, Object?>{};
    return AdminLoginResult(
      email: account['email']?.toString().trim() ?? '',
      username: account['username']?.toString().trim() ?? '',
      accountId: account['id']?.toString().trim() ?? '',
      role: AccountRole.parse(
        account['role']?.toString().trim() ?? data['role']?.toString().trim(),
      ),
      displayName: account['displayName']?.toString().trim(),
      serverId: TenantBootstrapResult._required(data, 'serverId'),
      restaurantId: TenantBootstrapResult._required(data, 'restaurantId'),
      outletId: TenantBootstrapResult._required(data, 'outletId'),
      restaurantName: TenantBootstrapResult._required(data, 'restaurantName'),
      outletName: TenantBootstrapResult._required(data, 'outletName'),
      deviceToken: TenantBootstrapResult._required(data, 'deviceToken'),
      tableCount: TenantBootstrapResult._tableCount(data['tableCount']),
      publicSlug: TenantBootstrapResult._optional(data['publicSlug']),
      customerMenuUrl: TenantBootstrapResult._optional(data['customerMenuUrl']),
      publicApiBaseUrl: TenantBootstrapResult._optional(
        data['publicApiBaseUrl'],
      ),
      hasAppAccess: data['hasAppAccess'] == true,
    );
  }

  static AdminLoginResult fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    return AdminLoginResult.fromAuthPayload(data);
  }
}

class MenuScanPageUpload {
  const MenuScanPageUpload({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
  });

  final List<int> bytes;
  final String fileName;
  final String mimeType;
}

class MenuScanSubItem {
  const MenuScanSubItem({required this.nameEn, this.nameBn = ''});

  final String nameEn;
  final String nameBn;
}

class MenuScanAddOn {
  const MenuScanAddOn({
    required this.nameEn,
    this.nameBn = '',
    required this.price,
  });

  final String nameEn;
  final String nameBn;
  final double price;
}

class MenuScanCandidate {
  const MenuScanCandidate({
    required this.nameEn,
    required this.nameBn,
    required this.descriptionEn,
    required this.descriptionBn,
    required this.categoryEn,
    required this.categoryBn,
    required this.price,
    required this.isAvailable,
    this.iconKey = 'general',
    this.imageUrl,
    this.subItems = const [],
    this.addOns = const [],
  });

  final String nameEn;
  final String nameBn;
  final String descriptionEn;
  final String descriptionBn;
  final String categoryEn;
  final String categoryBn;
  final double price;
  final bool isAvailable;
  final String iconKey;
  final String? imageUrl;
  final List<MenuScanSubItem> subItems;
  final List<MenuScanAddOn> addOns;

  static MenuScanCandidate? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, Object?>.from(value);
    final (legacyNameEn, legacyNameBn) = _splitBilingual(json['name']);
    final (legacyDescriptionEn, legacyDescriptionBn) = _splitBilingual(
      json['description'],
    );
    final (legacyCategoryEn, legacyCategoryBn) = _splitBilingual(
      json['category'],
    );
    final nameEn = _text(json['nameEn']) ?? legacyNameEn;
    final nameBn = _text(json['nameBn']) ?? legacyNameBn;
    final descriptionEn = _text(json['descriptionEn']) ?? legacyDescriptionEn;
    final descriptionBn = _text(json['descriptionBn']) ?? legacyDescriptionBn;
    final categoryEn = _text(json['categoryEn']) ?? legacyCategoryEn;
    final categoryBn = _text(json['categoryBn']) ?? legacyCategoryBn;
    final rawPrice = json['price'];
    final price = rawPrice is num
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice?.toString() ?? '');
    if (nameEn.isEmpty ||
        nameBn.isEmpty ||
        descriptionEn.isEmpty ||
        descriptionBn.isEmpty ||
        price == null ||
        price <= 0) {
      return null;
    }
    final rawIcon = _text(json['iconKey'])?.toLowerCase() ?? 'general';
    return MenuScanCandidate(
      nameEn: nameEn,
      nameBn: nameBn,
      descriptionEn: descriptionEn,
      descriptionBn: descriptionBn,
      categoryEn: categoryEn.isEmpty ? 'General' : categoryEn,
      categoryBn: categoryBn.isEmpty ? 'সাধারণ' : categoryBn,
      price: price,
      isAvailable: json['isAvailable'] is bool
          ? json['isAvailable'] as bool
          : true,
      iconKey: rawIcon.isEmpty ? 'general' : rawIcon,
      imageUrl: _text(json['imageUrl']),
      subItems: _parseSubItems(json['subItems']),
      addOns: _parseAddOns(json['addOns']),
    );
  }

  static List<MenuScanSubItem> _parseSubItems(Object? raw) {
    if (raw is! List) return const [];
    final out = <MenuScanSubItem>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final m = Map<String, Object?>.from(entry);
      final nameEn = _text(m['nameEn']) ?? '';
      if (nameEn.isEmpty) continue;
      out.add(
        MenuScanSubItem(nameEn: nameEn, nameBn: _text(m['nameBn']) ?? ''),
      );
    }
    return out;
  }

  static List<MenuScanAddOn> _parseAddOns(Object? raw) {
    if (raw is! List) return const [];
    final out = <MenuScanAddOn>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final m = Map<String, Object?>.from(entry);
      final nameEn = _text(m['nameEn']) ?? '';
      if (nameEn.isEmpty) continue;
      final rawPrice = m['price'];
      final price = rawPrice is num
          ? rawPrice.toDouble()
          : double.tryParse(rawPrice?.toString() ?? '') ?? 0;
      if (price <= 0) continue;
      out.add(
        MenuScanAddOn(
          nameEn: nameEn,
          nameBn: _text(m['nameBn']) ?? '',
          price: price,
        ),
      );
    }
    return out;
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static (String, String) _splitBilingual(Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return ('', '');
    if (!text.contains('/')) return (text, '');
    final parts = text.split('/');
    return (parts.first.trim(), parts.skip(1).join('/').trim());
  }
}

class MenuScanResult {
  const MenuScanResult({
    required this.items,
    required this.provider,
    required this.pageCount,
    required this.warnings,
  });

  final List<MenuScanCandidate> items;
  final String provider;
  final int pageCount;
  final List<String> warnings;

  factory MenuScanResult.fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    final items = data['items'] is List
        ? (data['items'] as List)
              .map(MenuScanCandidate.fromJson)
              .whereType<MenuScanCandidate>()
              .toList(growable: false)
        : const <MenuScanCandidate>[];
    if (items.isEmpty) {
      throw CloudApiException('The menu scan did not return menu items.');
    }
    final rawWarnings = data['warnings'];
    final rawPageCount = data['pageCount'];
    final parsedPageCount = rawPageCount is num
        ? rawPageCount.toInt()
        : int.tryParse(rawPageCount?.toString() ?? '');
    return MenuScanResult(
      items: items,
      provider: data['provider']?.toString().trim() ?? '',
      pageCount: (parsedPageCount ?? 0).clamp(0, 999),
      warnings: rawWarnings is List
          ? rawWarnings.map((item) => item.toString()).toList(growable: false)
          : const [],
    );
  }
}

class OrderHistoryImportResult {
  const OrderHistoryImportResult({
    required this.importedOrders,
    required this.duplicateOrders,
    required this.skippedRows,
    required this.rowCount,
    required this.errors,
  });

  final int importedOrders;
  final int duplicateOrders;
  final int skippedRows;
  final int rowCount;
  final List<String> errors;

  factory OrderHistoryImportResult.fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    int readCount(String key) {
      final value = data[key];
      return value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    }

    final rawErrors = data['errors'];
    return OrderHistoryImportResult(
      importedOrders: readCount('importedOrders'),
      duplicateOrders: readCount('duplicateOrders'),
      skippedRows: readCount('skippedRows'),
      rowCount: readCount('rowCount'),
      errors: rawErrors is List
          ? rawErrors.map((error) => error.toString()).toList(growable: false)
          : const [],
    );
  }
}

class PhoneOtpSendResult {
  PhoneOtpSendResult({
    required this.smsSent,
    required this.phoneOtpMode,
    this.message,
    this.devOtpCode,
    this.phone,
  });

  final bool smsSent;
  final String phoneOtpMode;
  final String? message;
  final String? devOtpCode;
  final String? phone;

  static PhoneOtpSendResult fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    final mode = data['phoneOtpMode']?.toString() ?? 'unconfigured';
    return PhoneOtpSendResult(
      smsSent: data['smsSent'] == true,
      phoneOtpMode: mode,
      message: data['message']?.toString(),
      devOtpCode: data['devOtpCode']?.toString(),
      phone: data['phone']?.toString(),
    );
  }
}

class PhoneVerifyResult {
  PhoneVerifyResult({
    required this.status,
    this.login,
    this.signupToken,
    this.phone,
    this.inviteId,
    this.restaurantName,
    this.outletName,
  });

  final String status;
  final AdminLoginResult? login;
  final String? signupToken;
  final String? phone;
  final String? inviteId;
  final String? restaurantName;
  final String? outletName;

  static PhoneVerifyResult fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    final status = data['status']?.toString() ?? '';
    if (status == 'authenticated') {
      return PhoneVerifyResult(
        status: status,
        login: AdminLoginResult.fromAuthPayload(data),
      );
    }
    if (status == 'needs_restaurant_setup') {
      return PhoneVerifyResult(
        status: status,
        signupToken: data['signupToken']?.toString(),
        phone: data['phone']?.toString(),
      );
    }
    if (status == 'pending_staff_invite') {
      return PhoneVerifyResult(
        status: status,
        signupToken: data['signupToken']?.toString(),
        phone: data['phone']?.toString(),
        inviteId: data['inviteId']?.toString(),
        restaurantName: data['restaurantName']?.toString(),
        outletName: data['outletName']?.toString(),
      );
    }
    return PhoneVerifyResult(status: status);
  }
}

class AppAccessResult {
  const AppAccessResult({
    required this.hasAppAccess,
    this.subscriptionStatus,
    this.subscriptionPlan,
  });

  final bool hasAppAccess;
  final String? subscriptionStatus;
  final String? subscriptionPlan;

  static AppAccessResult fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    return AppAccessResult(
      hasAppAccess: data['hasAppAccess'] == true,
      subscriptionStatus: data['subscriptionStatus']?.toString(),
      subscriptionPlan: data['subscriptionPlan']?.toString(),
    );
  }
}

class CloudApiService {
  CloudApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  CloudConfig _cloudConfig = CloudConfig(
    baseUrl: CloudDefaults.baseUrl,
    enabled: CloudDefaults.shouldEnableSyncByDefault,
    deviceToken: '',
    autoSyncIntervalSeconds: 30,
  );
  ServerConfig? _serverConfig;
  CloudRealtimeConfig? _realtimeConfig;

  CloudRealtimeConfig? get realtimeConfig => _realtimeConfig;

  void configure({
    required CloudConfig cloudConfig,
    required ServerConfig serverConfig,
  }) {
    _cloudConfig = cloudConfig;
    _serverConfig = serverConfig;
  }

  Future<Map<String, Object?>> testHealth() async {
    final uri = _uri('/health');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('GET', uri);
    _captureRealtimeConfig(response);
    return response;
  }

  Future<AdminBlockingNotice> fetchAdminBlockingNotice() async {
    final uri = _uri('/admin/blocking-notice');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return AdminBlockingNotice.fromJson(await _sendJson('GET', uri));
  }

  Future<void> respondToBlockingNotice(String response) async {
    final uri = _uri('/admin/blocking-notice/respond');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    await _sendJson('POST', uri, body: {'response': response});
  }

  Future<CloudRealtimeConfig?> loadRealtimeConfig() async {
    if (_realtimeConfig?.canConnect == true) return _realtimeConfig;
    if (!_cloudConfig.canConnect) return null;
    await testHealth();
    return _realtimeConfig;
  }

  Future<TenantBootstrapResult> bootstrapTenant({
    required String serverId,
    required String restaurantName,
    String? managerName,
    required String outletName,
    required int tableCount,
    String? restaurantId,
    String? outletId,
  }) async {
    final uri = _uri('/tenants/bootstrap');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'serverId': serverId,
        'restaurantName': restaurantName,
        if (managerName?.trim().isNotEmpty == true)
          'managerName': managerName!.trim(),
        'outletName': outletName,
        'tableCount': tableCount.clamp(0, 200),
        if (restaurantId?.trim().isNotEmpty == true)
          'restaurantId': restaurantId!.trim(),
        if (outletId?.trim().isNotEmpty == true) 'outletId': outletId!.trim(),
      },
      idempotencyKey: 'tenant-bootstrap-$serverId',
    );
    return TenantBootstrapResult.fromJson(response);
  }

  Future<AdminLoginResult> loginAdminAccount({
    required String usernameOrEmail,
    required String password,
    required String serverId,
  }) async {
    final uri = _uri('/admin/login');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'usernameOrEmail': usernameOrEmail.trim(),
        'password': password,
        'serverId': serverId,
      },
    );
    return AdminLoginResult.fromJson(response);
  }

  Future<PhoneOtpSendResult> sendPhoneOtp({
    required String phone,
    String? appSignature,
  }) async {
    final uri = _uri('/admin/phone/send-otp');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'phone': phone.trim(),
        if (appSignature != null && appSignature.trim().isNotEmpty)
          'appSignature': appSignature.trim(),
      },
    );
    return PhoneOtpSendResult.fromJson(response);
  }

  Future<PhoneVerifyResult> verifyPhoneOtp({
    required String phone,
    required String code,
  }) async {
    final uri = _uri('/admin/phone/verify-otp');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {'phone': phone.trim(), 'code': code.trim()},
    );
    return PhoneVerifyResult.fromJson(response);
  }

  Future<AdminLoginResult> completeManagerPhoneSignup({
    required String signupToken,
    required String restaurantName,
    String? managerName,
    required int tableCount,
    String? outletName,
    String? serverId,
    String? outletId,
  }) async {
    final uri = _uri('/admin/phone/complete-manager-signup');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'signupToken': signupToken,
        'restaurantName': restaurantName.trim(),
        if (managerName?.trim().isNotEmpty == true)
          'managerName': managerName!.trim(),
        'tableCount': tableCount.clamp(0, 200),
        if (outletName?.trim().isNotEmpty == true)
          'outletName': outletName!.trim(),
        if (serverId?.trim().isNotEmpty == true) 'serverId': serverId!.trim(),
        if (outletId?.trim().isNotEmpty == true) 'outletId': outletId!.trim(),
      },
    );
    final data = response['data'] is Map
        ? Map<String, Object?>.from(response['data'] as Map)
        : response;
    return AdminLoginResult.fromAuthPayload(data);
  }

  Future<PhoneVerifyResult> respondToStaffInvite({
    required String signupToken,
    required String inviteId,
    required bool accept,
  }) async {
    final uri = _uri('/admin/staff/invite/respond');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'signupToken': signupToken,
        'inviteId': inviteId,
        'accept': accept,
      },
    );
    return PhoneVerifyResult.fromJson(response);
  }

  Future<AdminLoginResult> googleStartOrLogin({
    required String idToken,
    required AccountRole role,
    required String serverId,
    int? tableCount,
    String? restaurantName,
    String? outletName,
    String? restaurantId,
    String? outletId,
  }) async {
    final uri = _uri('/admin/google/start-or-login');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'idToken': idToken,
        'role': role.value,
        'serverId': serverId,
        if (tableCount != null) 'tableCount': tableCount.clamp(0, 200),
        if (restaurantName?.trim().isNotEmpty == true)
          'restaurantName': restaurantName!.trim(),
        if (outletName?.trim().isNotEmpty == true)
          'outletName': outletName!.trim(),
        if (restaurantId?.trim().isNotEmpty == true)
          'restaurantId': restaurantId!.trim(),
        if (outletId?.trim().isNotEmpty == true) 'outletId': outletId!.trim(),
      },
    );
    return AdminLoginResult.fromJson(response);
  }

  Future<AdminLoginResult> demoManagerLogin() async {
    final uri = _uri('/admin/demo/manager-login');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('POST', uri, body: {});
    return AdminLoginResult.fromJson(response);
  }

  Future<AdminLoginResult> staffDevBypassLogin({
    required String email,
    required String serverId,
    required String bypassSecret,
  }) async {
    final uri = _uri('/admin/staff/dev-bypass-login');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'email': email.trim(),
        'serverId': serverId.trim(),
        'bypassSecret': bypassSecret,
      },
    );
    return AdminLoginResult.fromJson(response);
  }

  /// Register monthly/annual plan choice so platform admin can activate the outlet.
  Future<void> registerOnboardingPlan({required String plan}) async {
    final uri = _uri('/admin/subscription/onboarding');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    await _sendJson('POST', uri, body: {'plan': plan.trim().toLowerCase()});
  }

  /// Server-side subscription gate (platform admin grants access).
  Future<AppAccessResult> fetchAppAccess() async {
    final uri = _uri('/admin/access');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('GET', uri);
    return AppAccessResult.fromJson(response);
  }

  Future<AppUpdateInfo> fetchAppUpdate() async {
    final uri = _uri('/admin/app-update');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('GET', uri);
    return AppUpdateInfo.fromJson(response);
  }

  Future<Map<String, Object?>> updatePublicUrl({
    required String publicSlug,
  }) async {
    final uri = _uri('/admin/public-url');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'PATCH',
      uri,
      body: {'publicSlug': publicSlug.trim()},
    );
    final data = response['data'] is Map
        ? Map<String, Object?>.from(response['data'] as Map)
        : response;
    return data;
  }

  Future<Map<String, Object?>> wipeCurrentOutlet({
    required String confirmation,
  }) async {
    final config = _requireServerConfig();
    final uri = _uri('/admin/outlets/${config.outletId}/wipe');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {'confirmation': confirmation.trim()},
    );
    return response['data'] is Map
        ? Map<String, Object?>.from(response['data'] as Map)
        : response;
  }

  Future<FacebookChatbotConfig> fetchFacebookChatbotConfig() async {
    final uri = _uri('/admin/chatbot/facebook');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('GET', uri);
    return FacebookChatbotConfig.fromJson(response);
  }

  Future<FacebookChatbotOAuthStart> startFacebookChatbotOAuth() async {
    final uri = _uri('/admin/chatbot/facebook/oauth/start');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('POST', uri);
    return FacebookChatbotOAuthStart.fromJson(response);
  }

  Future<FacebookChatbotOAuthPages> fetchFacebookChatbotOAuthPages({
    required String sessionId,
  }) async {
    final uri = _uri(
      '/admin/chatbot/facebook/oauth/pages',
    )?.replace(queryParameters: {'sessionId': sessionId.trim()});
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('GET', uri);
    return FacebookChatbotOAuthPages.fromJson(response);
  }

  Future<FacebookChatbotConfig> completeFacebookChatbotOAuth({
    required String sessionId,
    required String pageId,
  }) async {
    final uri = _uri('/admin/chatbot/facebook/oauth/complete');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {'sessionId': sessionId.trim(), 'pageId': pageId.trim()},
    );
    return FacebookChatbotConfig.fromJson(response);
  }

  Future<FacebookChatbotConfig> updateFacebookChatbotConfig({
    String? pageAccessToken,
    required bool isEnabled,
    required bool orderingEnabled,
  }) async {
    final uri = _uri('/admin/chatbot/facebook');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'PUT',
      uri,
      body: {
        if (pageAccessToken != null) 'pageAccessToken': pageAccessToken.trim(),
        'isEnabled': isEnabled,
        'orderingEnabled': orderingEnabled,
      },
    );
    return FacebookChatbotConfig.fromJson(response);
  }

  Future<Map<String, Object?>> createAdminAccount({
    required String outletId,
    required String email,
    required String username,
    String? password,
    AccountRole role = AccountRole.manager,
    String? displayName,
  }) async {
    final uri = _uri('/admin/create');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: {
        'outletId': outletId,
        'email': email,
        'username': username,
        if (password?.isNotEmpty == true) 'password': password,
        'role': role.value,
        if (displayName?.trim().isNotEmpty == true)
          'displayName': displayName!.trim(),
      },
    );
  }

  Future<List<Map<String, Object?>>> listStaffAccounts() async {
    final uri = _uri('/admin/staff');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('GET', uri);
    final data = response['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  Future<List<StaffMember>> fetchStaff() async {
    _requireServerConfig();
    final uri = _uri('/admin/staff');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    if (data is! List) {
      throw CloudApiException('Staff response was malformed.');
    }
    return data
        .whereType<Map>()
        .map((row) => StaffMember.fromJson(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  Future<Map<String, Object?>> addStaffAccount({
    String? phone,
    String? email,
    String? displayName,
    String? role,
  }) async {
    final uri = _uri('/admin/staff');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: {
        if (phone?.trim().isNotEmpty == true) 'phone': phone!.trim(),
        if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
        if (displayName?.trim().isNotEmpty == true)
          'displayName': displayName!.trim(),
        if (role?.trim().isNotEmpty == true) 'role': role!.trim(),
      },
    );
  }

  Future<void> updateStaffAccount({
    required String staffId,
    bool? isActive,
    String? displayName,
  }) async {
    final uri = _uri('/admin/staff/$staffId');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    await _sendJson(
      'PATCH',
      uri,
      body: {
        'isActive': ?isActive,
        if (displayName?.trim().isNotEmpty == true)
          'displayName': displayName!.trim(),
      },
    );
  }

  Future<BkashPaymentSession> createBkashSandboxPayment({
    required String serverId,
    required double amount,
  }) async {
    final uri = _uri('/payments/bkash/create');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'serverId': serverId,
        'amount': amount,
        'currency': 'BDT',
        'purpose': 'admin_activation',
      },
      idempotencyKey:
          'bkash-activation-$serverId-${DateTime.now().millisecondsSinceEpoch}',
    );
    return BkashPaymentSession.fromJson(response);
  }

  Future<BkashPaymentSession> verifyBkashPayment(String paymentId) async {
    final uri = _uri('/payments/bkash/$paymentId/verify');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('POST', uri);
    return BkashPaymentSession.fromJson(response);
  }

  Future<PaymentGatewayConfig?> fetchPaymentGatewayConfig() async {
    final uri = _uri('/payments/config');
    if (uri == null) return null;
    try {
      final response = await _sendJson('GET', uri);
      return PaymentGatewayConfig.fromJson(response);
    } catch (_) {
      return null;
    }
  }

  Future<BkashPaymentSession> createUddoktaPayment({
    required String serverId,
    required double amount,
    required String plan,
    String? fullName,
    String? email,
  }) async {
    final uri = _uri('/payments/uddokta/create');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'serverId': serverId,
        'amount': amount,
        'currency': 'BDT',
        'purpose': 'admin_activation',
        'plan': plan,
        if (fullName != null && fullName.trim().isNotEmpty)
          'fullName': fullName.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      },
      idempotencyKey:
          'uddokta-$serverId-${DateTime.now().millisecondsSinceEpoch}',
    );
    return BkashPaymentSession.fromJson(response);
  }

  Future<BkashPaymentSession> verifyUddoktaPayment(
    String paymentId, {
    String? invoiceId,
  }) async {
    final uri = _uri('/payments/uddokta/$paymentId/verify');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: invoiceId == null || invoiceId.trim().isEmpty
          ? null
          : {'invoiceId': invoiceId.trim()},
    );
    return BkashPaymentSession.fromJson(response);
  }

  Future<BkashPaymentSession> getBkashPaymentStatus(String paymentId) async {
    final uri = _uri('/payments/bkash/$paymentId/status');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('GET', uri);
    return BkashPaymentSession.fromJson(response);
  }

  Future<Map<String, Object?>> registerDevice({
    String? fcmToken,
    String? pushPlatform,
  }) async {
    final config = _requireServerConfig();
    final uri = _uri('/devices/register');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final body = <String, Object?>{
      'serverId': config.serverId,
      'restaurantId': config.restaurantId,
      'outletId': config.outletId,
      'restaurantName': config.restaurantName,
      'outletName': config.outletName,
      'tableCount': config.tableCount.clamp(0, 200),
    };
    final cleanFcmToken = fcmToken?.trim() ?? '';
    final cleanPushPlatform = pushPlatform?.trim() ?? '';
    if (cleanFcmToken.isNotEmpty) {
      body['fcmToken'] = cleanFcmToken;
    }
    if (cleanPushPlatform.isNotEmpty) {
      body['pushPlatform'] = cleanPushPlatform;
    }
    return _sendJson(
      'POST',
      uri,
      body: body,
      idempotencyKey: 'device-${config.serverId}',
    );
  }

  Future<Map<String, Object?>> pushMenuItem(MenuItem item) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/menu');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: item.toJson(),
      idempotencyKey: 'menu-${item.id}-${item.version}',
    );
  }

  Future<Map<String, Object?>> updateMenuItem(MenuItem item) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/menu/${item.id}');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'PATCH',
      uri,
      body: item.toJson(),
      idempotencyKey: 'menu-${item.id}-${item.version}',
    );
  }

  Future<String> uploadMenuImageDataUrl(String dataUrl) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/menu/images');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'dataUrl': dataUrl,
        'fileName': 'menu-${DateTime.now().millisecondsSinceEpoch}.jpg',
      },
      idempotencyKey:
          'menu-image-${config.serverId}-${DateTime.now().microsecondsSinceEpoch}',
    );
    final data = response['data'] is Map
        ? Map<String, Object?>.from(response['data'] as Map)
        : response;
    final publicUrl = data['publicUrl']?.toString().trim() ?? '';
    if (publicUrl.isEmpty) {
      throw CloudApiException('Cloud image upload did not return a URL.');
    }
    return publicUrl;
  }

  Future<MenuScanResult> scanMenuPages(List<MenuScanPageUpload> pages) async {
    final config = _requireServerConfig();
    if (pages.isEmpty) {
      throw CloudApiException('Select at least one menu image.');
    }
    final uri = _uri('/outlets/${config.outletId}/menu/scan');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    if (kDebugMode) {
      final totalBytes = pages.fold<int>(
        0,
        (sum, page) => sum + page.bytes.length,
      );
      debugPrint(
        '[MENU_SCAN] request POST ${uri.scheme}://${uri.host}${uri.path} '
        'pages=${pages.length} bytes=$totalBytes',
      );
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers.addAll(CloudDefaults.ngrokBrowserBypassHeaders(uri));
    if (_cloudConfig.deviceToken.trim().isNotEmpty) {
      request.headers['Authorization'] =
          'Bearer ${_cloudConfig.deviceToken.trim()}';
    }
    for (final page in pages) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          page.bytes,
          filename: page.fileName,
          contentType: MediaType.parse(page.mimeType),
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 180));
    final body = await streamed.stream.bytesToString();
    if (kDebugMode) {
      debugPrint(
        '[MENU_SCAN] response status=${streamed.statusCode} '
        'bodyChars=${body.length}',
      );
    }
    final decoded = _decodeCloudJsonBody(body, uri);
    final payload = decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{'data': decoded};
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final detail = payload['detail'];
      final message =
          payload['error']?.toString() ??
          (detail is String
              ? detail
              : detail is Map
              ? detail['message']?.toString()
              : null) ??
          'Menu scan failed: HTTP ${streamed.statusCode}';
      if (kDebugMode) {
        debugPrint(
          '[MENU_SCAN] request failed status=${streamed.statusCode} '
          'detail=$message',
        );
      }
      throw CloudApiException(message);
    }
    final result = MenuScanResult.fromJson(payload);
    if (kDebugMode) {
      debugPrint(
        '[MENU_SCAN] response parsed provider=${result.provider} '
        'pages=${result.pageCount} items=${result.items.length} '
        'warnings=${result.warnings.length}',
      );
    }
    return result;
  }

  Future<OrderHistoryImportResult> importOrderHistoryCsv(
    List<int> bytes,
    String fileName,
  ) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/orders/history/import');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    if (bytes.isEmpty) {
      throw CloudApiException('Choose a non-empty CSV export.');
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers.addAll(CloudDefaults.ngrokBrowserBypassHeaders(uri))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName.trim().isEmpty ? 'order-history.csv' : fileName,
          contentType: MediaType('text', 'csv'),
        ),
      );
    if (_cloudConfig.deviceToken.trim().isNotEmpty) {
      request.headers['Authorization'] =
          'Bearer ${_cloudConfig.deviceToken.trim()}';
    }

    final streamed = await request.send().timeout(const Duration(seconds: 180));
    final body = await streamed.stream.bytesToString();
    final decoded = _decodeCloudJsonBody(body, uri);
    final payload = decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{'data': decoded};
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final detail = payload['detail'];
      final message =
          payload['error']?.toString() ??
          (detail is String
              ? detail
              : detail is Map
              ? detail['message']?.toString()
              : null) ??
          'Order history import failed: HTTP ${streamed.statusCode}';
      throw CloudApiException(message);
    }
    return OrderHistoryImportResult.fromJson(payload);
  }

  Future<List<String>> uploadOutletImage(String dataUrl) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/images');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'dataUrl': dataUrl,
        'fileName': 'hero-${DateTime.now().millisecondsSinceEpoch}.jpg',
      },
    );
    final data = response['data'] is Map
        ? Map<String, Object?>.from(response['data'] as Map)
        : response;
    final raw = data['galleryImages'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  Future<List<String>> deleteOutletImage(int index) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/images/$index');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson('DELETE', uri);
    final data = response['data'] is Map
        ? Map<String, Object?>.from(response['data'] as Map)
        : response;
    final raw = data['galleryImages'];
    if (raw is List) return raw.map((e) => e.toString()).toList();
    return [];
  }

  Future<String> uploadOutletLogo(String dataUrl) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/logo');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final response = await _sendJson(
      'POST',
      uri,
      body: {
        'dataUrl': dataUrl,
        'fileName': 'logo-${DateTime.now().millisecondsSinceEpoch}.jpg',
      },
    );
    final data = response['data'] is Map
        ? Map<String, Object?>.from(response['data'] as Map)
        : response;
    final url = data['logoUrl']?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw CloudApiException('Logo upload did not return a public URL.');
    }
    return url;
  }

  Future<void> updateOutletMedia({String? videoUrl}) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/media');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    await _sendJson('PATCH', uri, body: {'videoUrl': videoUrl});
  }

  Future<void> updateOutletLogo(String? logoUrl) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/media');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    await _sendJson('PATCH', uri, body: {'logoUrl': logoUrl});
  }

  Future<void> updateOutletMenuTheme(String slug) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/media');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    await _sendJson('PATCH', uri, body: {'menuTheme': slug});
  }

  Future<void> updateOutletDeliveryCharge(double value) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/media');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    await _sendJson('PATCH', uri, body: {'deliveryCharge': value});
  }

  Future<String> uploadOutletVideo(List<int> bytes, String filename) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/video');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer ${_cloudConfig.deviceToken.trim()}'
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw CloudApiException(
        'Video upload failed: HTTP ${streamed.statusCode}',
      );
    }
    final decoded = jsonDecode(body);
    final data = decoded['data'] is Map
        ? Map<String, Object?>.from(decoded['data'] as Map)
        : <String, Object?>{};
    final url = data['videoUrl']?.toString().trim() ?? '';
    if (url.isEmpty) {
      throw CloudApiException('Server did not return a video URL.');
    }
    return url;
  }

  Future<Map<String, Object?>> deleteMenuItem(String id) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/menu/$id');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson('DELETE', uri, idempotencyKey: 'menu-delete-$id');
  }

  Future<Map<String, Object?>> pushOrder(OrderModel order) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/orders');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final payload = <String, Object?>{
      'id': order.id,
      'serialNumber': order.sequenceNo,
      'source': order.source.value,
      'status': order.status.value,
      'totalAmount': order.total,
      'items': order.items.map((item) => item.toJson()).toList(growable: false),
      'notes': order.note,
      'tableNo': order.tableNo,
      'customerName': order.customerName,
      'deliveryAddress': order.deliveryAddress,
      'mobileNumber': order.mobileNumber,
      'createdByAccountId': order.createdByAccountId,
      'createdByRole': order.createdByRole,
      'subtotal': order.subtotal,
      'vatRatePercent': order.vatRatePercent,
      'vatAmount': order.vatAmount,
      'deliveryCharge': order.deliveryCharge,
      'shiftId': order.shiftId,
      'discountLabel': order.discountLabel,
      'discountAmount': order.discountAmount,
      'serviceChargeRatePercent': order.serviceChargeRatePercent,
      'serviceChargeAmount': order.serviceChargeAmount,
      'billingSnapshot': order.billingSnapshot,
      'kotBatches': order.kotBatches,
      'settledAt': order.settledAt?.toUtc().toIso8601String(),
      'createdAt': order.createdAt.toUtc().toIso8601String(),
      'updatedAt': order.updatedAt.toUtc().toIso8601String(),
    };
    if (order.serviceType != null) {
      payload['serviceType'] = order.serviceType!.value;
    }
    if (order.covers != null) {
      payload['covers'] = order.covers;
    }
    if (order.paymentMethod != null) {
      payload['paymentMethod'] = order.paymentMethod!.value;
    }
    return _sendJson(
      'POST',
      uri,
      body: payload,
      idempotencyKey: 'order-${order.id}',
    );
  }

  Future<Map<String, Object?>> pushOrderStatus(
    String orderId,
    OrderStatus status,
  ) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/orders/$orderId/status');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'PATCH',
      uri,
      body: {
        'status': status.value,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
      idempotencyKey: 'order-status-$orderId-${status.value}',
    );
  }

  Future<Map<String, Object?>> pushOrderItems(OrderModel order) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/orders/${order.id}/items');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'PATCH',
      uri,
      body: {
        'items': order.items
            .map((item) => item.toJson())
            .toList(growable: false),
        'subtotal': order.subtotal,
        'totalAmount': order.total,
        'vatRatePercent': order.vatRatePercent,
        'vatAmount': order.vatAmount,
        'deliveryCharge': order.deliveryCharge,
        'updatedAt': order.updatedAt.toUtc().toIso8601String(),
      },
      idempotencyKey: 'order-items-${order.id}-${order.version}',
    );
  }

  Future<Map<String, Object?>> pushOrderDetails(OrderModel order) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/orders/${order.id}');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'PATCH',
      uri,
      body: {
        'serviceType': order.serviceType?.value,
        'tableNo': order.tableNo,
        'notes': order.note,
        'customerName': order.customerName,
        'deliveryAddress': order.deliveryAddress,
        'mobileNumber': order.mobileNumber,
        'updatedAt': order.updatedAt.toUtc().toIso8601String(),
      },
      idempotencyKey: 'order-details-${order.id}-${order.version}',
    );
  }

  Future<List<Map<String, Object?>>> pullMenu({DateTime? since}) async {
    final config = _requireServerConfig();
    final uri = _uri(
      '/outlets/${config.outletId}/menu',
      queryParameters: since == null
          ? null
          : {'since': since.toUtc().toIso8601String()},
    );
    if (uri == null) return [];
    final json = await _sendJson('GET', uri);
    return _extractList(json);
  }

  Future<List<Map<String, Object?>>> pullOrders({
    DateTime? since,
    int? limit,
  }) async {
    final config = _requireServerConfig();
    final query = <String, String>{
      if (since != null) 'since': since.toUtc().toIso8601String(),
      if (limit != null) 'limit': '$limit',
    };
    final uri = _uri(
      '/outlets/${config.outletId}/orders',
      queryParameters: query.isEmpty ? null : query,
    );
    if (uri == null) return [];
    if (kDebugMode) {
      debugPrint(
        '[QB-ORDERS-DIAG] cloud pullOrders request uri=$uri '
        'since=${since?.toUtc().toIso8601String()} limit=$limit',
      );
    }
    final json = await _sendJson('GET', uri);
    final rows = _extractList(json);
    if (kDebugMode) {
      debugPrint(
        '[QB-ORDERS-DIAG] cloud pullOrders response count=${rows.length} '
        '${_orderPayloadStatusCounts(rows)} sample=${_orderPayloadSample(rows)}',
      );
    }
    return rows;
  }

  String _orderPayloadStatusCounts(List<Map<String, Object?>> rows) {
    final counts = <String, int>{};
    for (final row in rows) {
      final status = row['status']?.toString().trim();
      final key = status == null || status.isEmpty ? '<missing>' : status;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final keys = counts.keys.toList()..sort();
    return 'statusCounts={${keys.map((k) => '$k:${counts[k]}').join(', ')}}';
  }

  String _orderPayloadSample(List<Map<String, Object?>> rows, {int limit = 5}) {
    return rows
        .take(limit)
        .map((row) {
          final id = row['id']?.toString() ?? '<no-id>';
          final serial = row['serialNumber'] ?? row['sequenceNo'] ?? '';
          final status = row['status'] ?? '';
          final source = row['source'] ?? '';
          final service = row['serviceType'] ?? '';
          final updated = row['updatedAt'] ?? '';
          return '$id#$serial:$status/$source/$service@$updated';
        })
        .join(' | ');
  }

  Future<Map<String, Object?>> pushDesktopPosSettings(
    Map<String, Object?> payload,
  ) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/pos/settings');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson('PATCH', uri, body: payload);
  }

  Future<Map<String, Object?>?> pullDesktopPosSettings() async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/pos/settings');
    if (uri == null) return null;
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    return data is Map ? Map<String, Object?>.from(data) : null;
  }

  Future<Map<String, Object?>?> pullDesktopCurrentShift() async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/pos/shifts/current');
    if (uri == null) return null;
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    return data is Map ? Map<String, Object?>.from(data) : null;
  }

  Future<Map<String, Object?>?> pullDesktopPosReport({int days = 1}) async {
    final config = _requireServerConfig();
    final uri = _uri(
      '/outlets/${config.outletId}/pos/reports',
      queryParameters: {'days': '$days'},
    );
    if (uri == null) return null;
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    return data is Map ? Map<String, Object?>.from(data) : null;
  }

  Future<Map<String, Object?>> pushDesktopPosShift(
    String shiftId,
    String action,
    Map<String, Object?> payload,
  ) async {
    final config = _requireServerConfig();
    final path = action == 'open'
        ? '/outlets/${config.outletId}/pos/shifts/open'
        : '/outlets/${config.outletId}/pos/shifts/$shiftId/close';
    final uri = _uri(path);
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: payload,
      idempotencyKey: 'pos-shift-$shiftId-$action',
    );
  }

  Future<Map<String, Object?>> pushDesktopKot(
    String orderId,
    Map<String, Object?> payload,
  ) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/pos/orders/$orderId/kot');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: payload,
      idempotencyKey: 'pos-kot-${payload['batchId']}',
    );
  }

  Future<Map<String, Object?>> pushDesktopSettlement(
    String orderId,
    Map<String, Object?> payload,
  ) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/pos/orders/$orderId/settle');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: payload,
      idempotencyKey: 'pos-settle-$orderId',
    );
  }

  Future<Map<String, Object?>> pushDesktopAudit(
    String orderId,
    Map<String, Object?> payload,
  ) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/pos/orders/$orderId/audit');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: payload,
      idempotencyKey: 'pos-audit-${payload['eventId']}',
    );
  }

  Future<Map<String, Object?>> pullInventory({DateTime? since}) async {
    final config = _requireServerConfig();
    final uri = _uri(
      '/outlets/${config.outletId}/inventory',
      queryParameters: since == null
          ? null
          : {'since': since.toUtc().toIso8601String()},
    );
    if (uri == null) return {};
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    if (data is Map) {
      return Map<String, Object?>.from(data);
    }
    return {};
  }

  Future<Map<String, Object?>> pushInventoryItem(InventoryItem item) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/inventory/items');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    return _sendJson(
      'POST',
      uri,
      body: item.toMap(),
      idempotencyKey:
          'inventory-item-${item.id}-${item.updatedAt.toIso8601String()}',
    );
  }

  Future<void> deleteInventoryItemCloud(String itemId) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/inventory/items/$itemId');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    await _sendJson('DELETE', uri);
  }

  Future<void> pushInventoryAdjustment(StockAdjustment adjustment) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/inventory/adjustments');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    await _sendJson(
      'POST',
      uri,
      body: adjustment.toMap(),
      idempotencyKey: 'inventory-adj-${adjustment.id}',
    );
  }

  Future<void> pushInventoryAdjustments(
    List<StockAdjustment> adjustments,
  ) async {
    if (adjustments.isEmpty) return;
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/inventory/adjustments/batch');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    await _sendJson(
      'POST',
      uri,
      body: {'adjustments': adjustments.map((row) => row.toMap()).toList()},
      idempotencyKey:
          'inventory-adj-batch-${adjustments.map((row) => row.id).join("-")}',
    );
  }

  Future<List<InventorySupplier>> fetchInventorySuppliers() async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/inventory/suppliers');
    if (uri == null) return const [];
    final json = await _sendJson('GET', uri);
    return _extractList(
      json,
    ).map(InventorySupplier.fromMap).toList(growable: false);
  }

  Future<InventorySupplier> saveInventorySupplier(
    InventorySupplier supplier,
  ) async {
    final config = _requireServerConfig();
    final uri = _uri('/outlets/${config.outletId}/inventory/suppliers');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('POST', uri, body: supplier.toJson());
    final data = json['data'];
    if (data is! Map) {
      throw CloudApiException('Supplier response was malformed.');
    }
    return InventorySupplier.fromMap(Map<String, Object?>.from(data));
  }

  Future<DashboardSummary> fetchDashboardSummary({DateTime? asOf}) async {
    final config = _requireServerConfig();
    final uri = _uri(
      '/outlets/${config.outletId}/dashboard/summary',
      queryParameters: asOf == null
          ? null
          : {'as_of': asOf.toUtc().toIso8601String()},
    );
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    if (data is! Map) {
      throw CloudApiException('Dashboard summary response was malformed.');
    }
    return DashboardSummary.fromJson(Map<String, Object?>.from(data));
  }

  Future<InventorySummary> fetchInventorySummary({DateTime? asOf}) async {
    final config = _requireServerConfig();
    final uri = _uri(
      '/outlets/${config.outletId}/inventory/summary',
      queryParameters: asOf == null
          ? null
          : {'as_of': asOf.toUtc().toIso8601String()},
    );
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    if (data is! Map) {
      throw CloudApiException('Inventory summary response was malformed.');
    }
    return InventorySummary.fromJson(Map<String, Object?>.from(data));
  }

  Future<DailyReport> fetchInventoryDailyReport({DateTime? date}) async {
    final config = _requireServerConfig();
    final isoDate = date == null
        ? null
        : '${date.year.toString().padLeft(4, '0')}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}';
    final uri = _uri(
      '/outlets/${config.outletId}/inventory/daily-report',
      queryParameters: isoDate == null ? null : {'date': isoDate},
    );
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    if (data is! Map) {
      throw CloudApiException('Daily report response was malformed.');
    }
    return DailyReport.fromJson(Map<String, Object?>.from(data));
  }

  Future<List<AuditEntry>> fetchPosAuditEvents({int days = 30}) async {
    final config = _requireServerConfig();
    final uri = _uri(
      '/outlets/${config.outletId}/pos/audit',
      queryParameters: {'days': '$days'},
    );
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    if (data is! Map) {
      throw CloudApiException('Audit response was malformed.');
    }
    final events = (data['events'] as List?) ?? const [];
    return events
        .whereType<Map>()
        .map((row) => AuditEntry.fromJson(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  /// Owner analytics (spec §4.8) — returns the raw `data` map; the analytics
  /// screen parses it. Range/channel/daypart scope the aggregation server-side.
  Future<Map<String, Object?>> fetchAnalytics({
    String range = 'today',
    String? start,
    String? end,
    String channel = 'all',
    String daypart = 'all',
  }) async {
    final config = _requireServerConfig();
    final uri = _uri(
      '/outlets/${config.outletId}/analytics',
      queryParameters: {
        'range': range,
        'start': ?start,
        'end': ?end,
        'channel': channel,
        'daypart': daypart,
      },
    );
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    if (data is! Map) {
      throw CloudApiException('Analytics response was malformed.');
    }
    return Map<String, Object?>.from(data);
  }

  /// Owner sales table (spec §4.8 "Detailed sales table") — returns the raw
  /// `data` map with `rows` keyed by item × service × channel. Range/channel
  /// scope the aggregation server-side; per-row `costBdt` is null when the
  /// menu item has no cost price.
  Future<Map<String, Object?>> fetchSalesTable({
    String range = 'today',
    String? start,
    String? end,
    String channel = 'all',
  }) async {
    final config = _requireServerConfig();
    final uri = _uri(
      '/outlets/${config.outletId}/analytics/sales-table',
      queryParameters: {
        'range': range,
        'start': ?start,
        'end': ?end,
        'channel': channel,
      },
    );
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    if (data is! Map) {
      throw CloudApiException('Sales table response was malformed.');
    }
    return Map<String, Object?>.from(data);
  }

  Future<List<ChatThread>> fetchChats() async {
    _requireServerConfig();
    final uri = _uri('/admin/chatbot/chats');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('GET', uri);
    final data = json['data'];
    if (data is! Map) {
      throw CloudApiException('Chats response was malformed.');
    }
    final chats = (data['chats'] as List?) ?? const [];
    return chats
        .whereType<Map>()
        .map((row) => ChatThread.fromJson(Map<String, Object?>.from(row)))
        .toList(growable: false);
  }

  Future<ChatThread> replyToChat(String conversationId, String text) async {
    _requireServerConfig();
    final uri = _uri('/admin/chatbot/chats/$conversationId/reply');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('POST', uri, body: {'text': text});
    final data = json['data'];
    if (data is! Map) {
      throw CloudApiException('Chat reply response was malformed.');
    }
    return ChatThread.fromJson(Map<String, Object?>.from(data));
  }

  Future<ChatThread> handBackChat(String conversationId) async {
    _requireServerConfig();
    final uri = _uri('/admin/chatbot/chats/$conversationId/handback');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }
    final json = await _sendJson('POST', uri);
    final data = json['data'];
    if (data is! Map) {
      throw CloudApiException('Chat handback response was malformed.');
    }
    return ChatThread.fromJson(Map<String, Object?>.from(data));
  }

  Future<ReceiptScanResult> scanInventoryReceipt(
    List<MenuScanPageUpload> pages,
  ) async {
    final config = _requireServerConfig();
    if (pages.isEmpty) {
      throw CloudApiException('Select at least one receipt image.');
    }
    final uri = _uri('/outlets/${config.outletId}/inventory/receipt/scan');
    if (uri == null) {
      throw CloudApiException('Cloud API URL is empty or invalid.');
    }

    final request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json'
      ..headers.addAll(CloudDefaults.ngrokBrowserBypassHeaders(uri));
    if (_cloudConfig.deviceToken.trim().isNotEmpty) {
      request.headers['Authorization'] =
          'Bearer ${_cloudConfig.deviceToken.trim()}';
    }
    for (final page in pages) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'files',
          page.bytes,
          filename: page.fileName,
          contentType: MediaType.parse(page.mimeType),
        ),
      );
    }

    final streamed = await request.send().timeout(const Duration(seconds: 180));
    final body = await streamed.stream.bytesToString();
    final decoded = _decodeCloudJsonBody(body, uri);
    final payload = decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{'data': decoded};
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      final detail = payload['detail'];
      final message =
          payload['error']?.toString() ??
          (detail is String
              ? detail
              : detail is Map
              ? detail['message']?.toString()
              : null) ??
          'Receipt scan failed: HTTP ${streamed.statusCode}';
      throw CloudApiException(message);
    }
    final data = payload['data'];
    if (data is! Map) {
      throw CloudApiException('Receipt scan response was malformed.');
    }
    return ReceiptScanResult.fromJson(Map<String, Object?>.from(data));
  }

  Future<Map<String, Object?>> _sendJson(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (_cloudConfig.deviceToken.trim().isNotEmpty)
        'Authorization': 'Bearer ${_cloudConfig.deviceToken.trim()}',
      ...CloudDefaults.ngrokBrowserBypassHeaders(uri),
    };
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final encodedBody = body == null ? null : jsonEncode(body);
    late http.Response response;
    try {
      response = await _request(method, uri, headers, encodedBody).timeout(
        Duration(seconds: 12),
        onTimeout: () {
          throw CloudApiException(
            'Cloud request timed out. Your phone could not reach $uri. '
            'In Settings, set Cloud API URL to the same address your manager uses '
            '(your HTTPS server or an active ngrok tunnel).',
          );
        },
      );
    } on SocketException catch (e) {
      throw CloudApiException(
        'Cannot reach the API at $uri (${e.message}). '
        'Open Settings and set Cloud API URL to match your manager (VPS URL or running ngrok).',
      );
    } on http.ClientException catch (e) {
      throw CloudApiException(
        'Connection to $uri failed (${e.message}). '
        'Use the same Cloud API URL as your manager.',
      );
    }
    final decoded = _decodeCloudJsonBody(response.body, uri);
    final payload = decoded is Map
        ? Map<String, Object?>.from(decoded)
        : <String, Object?>{'data': decoded};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // FastAPI HTTPException puts the message under "detail"; older custom
      // handlers used "error". Surface whichever is present so the user sees
      // the real backend message ("account_not_found: ...", "Manager access
      // required.", etc.) instead of the generic HTTP code.
      final detail = payload['detail'];
      final message =
          payload['error']?.toString() ??
          (detail is String
              ? detail
              : detail is Map
              ? detail['message']?.toString()
              : null) ??
          'Cloud request failed: HTTP ${response.statusCode}';
      throw CloudApiException(message);
    }
    return payload;
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    Map<String, String> headers,
    String? body,
  ) {
    switch (method) {
      case 'GET':
        return _client.get(uri, headers: headers);
      case 'POST':
        return _client.post(uri, headers: headers, body: body);
      case 'PUT':
        return _client.put(uri, headers: headers, body: body);
      case 'PATCH':
        return _client.patch(uri, headers: headers, body: body);
      case 'DELETE':
        return _client.delete(uri, headers: headers);
      default:
        throw CloudApiException('Unsupported cloud method $method.');
    }
  }

  List<Map<String, Object?>> _extractList(Map<String, Object?> json) {
    final raw = json['data'] ?? json['items'] ?? json['orders'] ?? json['menu'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }

  Uri? _uri(String path, {Map<String, String>? queryParameters}) {
    final base = _baseUri();
    if (base == null) return null;
    return base.replace(
      path: _joinPaths(base.path, path),
      queryParameters: queryParameters,
    );
  }

  Uri? _baseUri() {
    if (!_cloudConfig.canConnect) return null;
    return Uri.tryParse(_cloudConfig.baseUrl.trim());
  }

  String _joinPaths(String basePath, String endpointPath) {
    final cleanBase = basePath.endsWith('/')
        ? basePath.substring(0, basePath.length - 1)
        : basePath;
    final cleanEndpoint = endpointPath.startsWith('/')
        ? endpointPath.substring(1)
        : endpointPath;
    if (cleanBase.isEmpty) return '/$cleanEndpoint';
    return '$cleanBase/$cleanEndpoint';
  }

  ServerConfig _requireServerConfig() {
    final config = _serverConfig;
    if (config == null) {
      throw CloudApiException('Server config is not ready.');
    }
    return config;
  }

  void _captureRealtimeConfig(Map<String, Object?> json) {
    final config = CloudRealtimeConfig.fromJson(json['realtime']);
    if (config != null) _realtimeConfig = config;
  }

  void close() {
    _client.close();
  }
}
