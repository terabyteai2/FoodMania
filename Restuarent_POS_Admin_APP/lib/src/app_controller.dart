import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'core/constants/cloud_defaults.dart';
import 'core/constants/google_auth_defaults.dart';
import 'core/constants/payment_defaults.dart';
import 'core/localization/app_strings.dart';
import 'models/account_role.dart';
import 'models/bkash_payment_session.dart';
import 'models/dashboard_metrics.dart';
import 'models/inventory_item.dart';
import 'models/menu_item.dart';
import 'models/order_item.dart';
import 'models/order_model.dart';
import 'models/order_source.dart';
import 'models/order_status.dart';
import 'models/pos_notification.dart';
import 'models/sales_report.dart';
import 'models/server_config.dart';
import 'models/stock_adjustment.dart';
import 'models/sync_event.dart';
import 'services/cloud_api_service.dart';
import 'services/cloud_realtime_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_database_service.dart';
import 'services/printer_service.dart';
import 'services/sync_service.dart';
import 'services/system_notification_service.dart';

enum AppThemePreference {
  black('black'),
  white('white'),
  device('device');

  const AppThemePreference(this.code);
  final String code;

  static AppThemePreference parse(String? _) {
    return AppThemePreference.white;
  }
}

class PosAppController extends ChangeNotifier {
  PosAppController({
    LocalDatabaseService? database,
    PrinterService? printerService,
    CloudApiService? cloudApiService,
    CloudRealtimeService? cloudRealtimeService,
    ConnectivityService? connectivityService,
    SyncService? syncService,
    SystemNotificationService? systemNotifications,
  }) : database = database ?? LocalDatabaseService(),
       printerService = printerService ?? PrinterService(),
       cloudApiService = cloudApiService ?? CloudApiService(),
       cloudRealtimeService = cloudRealtimeService ?? CloudRealtimeService(),
       connectivityService = connectivityService ?? ConnectivityService(),
       systemNotifications =
           systemNotifications ?? SystemNotificationService() {
    this.syncService =
        syncService ??
        SyncService(
          database: this.database,
          cloudApi: this.cloudApiService,
          cloudRealtime: this.cloudRealtimeService,
          connectivity: this.connectivityService,
        );
  }

  final LocalDatabaseService database;
  final PrinterService printerService;
  final CloudApiService cloudApiService;
  final CloudRealtimeService cloudRealtimeService;
  final ConnectivityService connectivityService;
  final SystemNotificationService systemNotifications;
  late final SyncService syncService;

  final Uuid _uuid = Uuid();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final Set<String> _knownOrderIds = <String>{};
  final Set<String> _autoPrintInFlight = <String>{};
  final AudioPlayer _notificationPlayer = AudioPlayer();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['openid', 'email', 'profile'],
    serverClientId: GoogleAuthDefaults.webClientId,
  );

  bool initialized = false;
  bool busy = false;
  // True while the app is in the foreground. Drives whether new notifications
  // also fire an OS-level notification (only when backgrounded — otherwise the
  // in-app toast + sound is enough and a system notification would be noisy).
  bool isAppForeground = true;
  bool hasSeenIntro = false;
  bool bkashPaymentVerified = false;
  // True between "manager signup succeeded" and "manager finished or skipped
  // the hero-media step". The app shell uses this to keep ModeIntroScreen on
  // screen (forcing the hero-media view) even though the manager is already
  // logged-in + has a tenant — otherwise MainShell would mount immediately
  // after signup and the hero-media step would never get a chance to render.
  bool pendingHeroMediaSetup = false;
  String? lastBkashPaymentId;
  String? lastBkashTransactionId;
  AppLanguage language = AppLanguage.bn;
  AppThemePreference themePreference = AppThemePreference.white;
  double uiScale = 1.06;
  String? lastError;
  bool isLoggedIn = false;
  AccountRole accountRole = AccountRole.manager;
  String accountId = '';
  String accountEmail = '';
  String accountUsername = '';
  String accountDisplayName = '';
  String _accountPassword = '';
  bool notificationSoundEnabled = true;
  String notificationSoundPath = '';
  List<MenuItem> menuItems = [];
  List<OrderModel> orders = [];
  List<PosNotification> notifications = [];
  List<SyncEvent> syncEvents = [];
  List<InventoryItem> inventoryItems = [];
  List<BluetoothPrinterDevice> pairedPrinters = [];
  PrinterRuntimeState printerState = PrinterRuntimeState(
    autoPrintEnabled: true,
    connected: false,
    busy: false,
  );
  SyncRuntimeState syncState = SyncRuntimeState(
    isSyncing: false,
    cloudConnected: false,
    pendingCount: 0,
    failedCount: 0,
    logs: [],
  );

  ServerConfig serverConfig = ServerConfig(
    serverId: '',
    restaurantId: '',
    outletId: '',
    restaurantName: '',
    outletName: '',
  );
  CloudConfig cloudConfig = CloudConfig(
    baseUrl: CloudDefaults.baseUrl,
    enabled: CloudDefaults.shouldEnableSyncByDefault,
    deviceToken: '',
    autoSyncIntervalSeconds: 30,
  );

  String get restaurantName => serverConfig.restaurantName;
  String get outletName => serverConfig.outletName;
  AppStrings get strings => AppStrings.of(language);
  bool get requiresBkashPayment {
    return PaymentDefaults.requireBkashGate && !bkashPaymentVerified;
  }

  String get uiScaleLabel {
    final text = strings;
    if (uiScale <= 0.88) return text.compact;
    if (uiScale >= 0.98) return text.large;
    return text.comfortable;
  }

  // App is ready to use as soon as the restaurant has a name.
  // Cloud sync is optional and configured separately.
  bool get isTenantReady {
    return serverConfig.restaurantName.trim().isNotEmpty &&
        serverConfig.outletName.trim().isNotEmpty;
  }

  bool get isCloudReady =>
      cloudConfig.hasDeviceToken && cloudConfig.hasValidBaseUrl;
  bool get isManager => accountRole.isManager;
  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.isRead).length;

  Future<void> onResumed() async {
    isAppForeground = true;
    // Resuming clears any stale OS notifications that the user has obviously
    // seen by virtue of opening the app.
    unawaited(systemNotifications.cancelAll());
    // Re-check notification permission in case the user just granted it from
    // system settings while the app was backgrounded.
    unawaited(systemNotifications.ensurePermissionGranted());
    if (!isCloudReady || !cloudConfig.canSync) return;
    final hasInternet = await connectivityService.hasInternetAccess();
    if (hasInternet) {
      unawaited(syncService.syncNow());
    }
  }

  void onPaused() {
    isAppForeground = false;
  }

  Future<void> initialize() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      hasSeenIntro = preferences.getBool(_seenIntroKey) ?? false;
      bkashPaymentVerified =
          preferences.getBool(_bkashPaymentVerifiedKey) ??
          !PaymentDefaults.requireBkashGate;
      lastBkashPaymentId = preferences.getString(_bkashPaymentIdKey);
      lastBkashTransactionId = preferences.getString(_bkashTransactionIdKey);
      final deviceLanguage = AppLanguage.fromLocale(
        ui.PlatformDispatcher.instance.locale,
      );
      final hasManualLanguage =
          preferences.getBool(_languagePreferenceSetKey) ?? false;
      language = hasManualLanguage
          ? AppLanguage.parse(
              preferences.getString(_languageKey),
              fallback: deviceLanguage,
            )
          : deviceLanguage;
      themePreference = AppThemePreference.white;
      uiScale = (preferences.getDouble(_uiScaleKey) ?? 1.06)
          .clamp(minUiScale, maxUiScale)
          .toDouble();
      serverConfig = ServerConfig(
        serverId: await _getOrCreatePreference(
          preferences,
          _serverIdKey,
          _uuid.v4(),
        ),
        restaurantId: preferences.getString(_restaurantIdKey) ?? '',
        outletId: preferences.getString(_outletIdKey) ?? '',
        restaurantName: preferences.getString(_restaurantNameKey) ?? '',
        outletName: preferences.getString(_outletNameKey) ?? '',
        tableCount: preferences.getInt(_tableCountKey) ?? 10,
      );
      cloudConfig = CloudConfig(
        baseUrl: CloudDefaults.resolveBaseUrl(
          preferences.getString(_cloudApiUrlKey),
        ),
        enabled:
            preferences.getBool(_cloudSyncEnabledKey) ??
            CloudDefaults.shouldEnableSyncByDefault,
        deviceToken: preferences.getString(_deviceTokenKey) ?? '',
        autoSyncIntervalSeconds: preferences.getInt(_autoSyncIntervalKey) ?? 30,
      );
      accountEmail = preferences.getString(_accountEmailKey) ?? '';
      accountUsername = preferences.getString(_accountUsernameKey) ?? '';
      accountId = preferences.getString(_accountIdKey) ?? '';
      accountDisplayName = preferences.getString(_accountDisplayNameKey) ?? '';
      accountRole = AccountRole.parse(preferences.getString(_accountRoleKey));
      _accountPassword = preferences.getString(_accountPasswordKey) ?? '';
      notificationSoundEnabled =
          preferences.getBool(_notificationSoundEnabledKey) ?? true;
      notificationSoundPath =
          preferences.getString(_notificationSoundPathKey) ?? '';
      isLoggedIn = preferences.getBool(_accountLoggedInKey) ?? isTenantReady;

      await printerService.initialize();
      printerState = printerService.state;
      await systemNotifications.initialize();
      // Existing installs may have stored either an app-private file path or
      // a file:// URI to external storage. Neither plays through the system
      // notification process. Upgrade to a content:// URI by registering with
      // MediaStore — that's the only URI form the system reliably plays.
      if (notificationSoundPath.isNotEmpty &&
          !notificationSoundPath.startsWith('content://')) {
        try {
          final mirrored = await _mirrorSoundToSharedLocation(
            notificationSoundPath,
          );
          final contentUri = await systemNotifications.registerSoundWithSystem(
            mirrored,
          );
          if (contentUri != notificationSoundPath) {
            notificationSoundPath = contentUri;
            await preferences.setString(
              _notificationSoundPathKey,
              notificationSoundPath,
            );
          }
        } catch (_) {
          // Source likely missing (cache was cleared). Leave as-is; channel
          // will fall back to the system default sound.
        }
      }
      await systemNotifications.configureSound(
        enabled: notificationSoundEnabled,
        soundPath: notificationSoundPath,
      );
      _subscriptions.add(
        database.changes.listen((_) {
          unawaited(_handleDatabaseChanged());
          unawaited(syncService.refreshSummary());
        }),
      );
      _subscriptions.add(
        printerService.stateStream.listen((state) {
          printerState = state;
          notifyListeners();
        }),
      );
      _subscriptions.add(
        syncService.stateStream.listen((state) {
          syncState = state;
          notifyListeners();
        }),
      );

      // Open the per-tenant database file. Two restaurants on the same phone
      // (different Google accounts) must never see each other's menu, orders,
      // inventory, etc. — using outletId as the file scope keeps them
      // physically separated on disk.
      await database.initialize(tenantKey: serverConfig.outletId);
      await syncService.initialize(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      // One-time heal for installs that copied another outlet's SQLite file
      // into this tenant's DB before the isolation fix shipped.
      await _healTenantDataIfNeeded(preferences);
      await reloadData();
      _knownOrderIds
        ..clear()
        ..addAll(orders.map((order) => order.id));
      if (isCloudReady && cloudConfig.canSync) {
        unawaited(syncService.syncNow());
      }
      initialized = true;
      lastError = null;
    } catch (error) {
      lastError = 'App initialization failed: $error';
    } finally {
      notifyListeners();
    }
  }

  DashboardMetrics get metrics {
    final now = DateTime.now();
    final todaysOrders = orders
        .where((order) {
          return order.createdAt.year == now.year &&
              order.createdAt.month == now.month &&
              order.createdAt.day == now.day;
        })
        .toList(growable: false);
    final todayStart = DateTime(now.year, now.month, now.day);
    final sevenDayStart = todayStart.subtract(Duration(days: 6));
    final thirtyDayStart = todayStart.subtract(Duration(days: 29));

    return DashboardMetrics(
      todayOrders: todaysOrders.length,
      pendingOrders: orders.where((order) => order.status.isOpen).length,
      completedOrders: orders
          .where((order) => order.status == OrderStatus.served)
          .length,
      totalSales: todaysOrders
          .where((order) => order.status != OrderStatus.cancelled)
          .fold<double>(0, (total, order) => total + order.total),
      sevenDaySales: _salesSince(sevenDayStart),
      thirtyDaySales: _salesSince(thirtyDayStart),
      menuItemsCount: menuItems.length,
      availableItemsCount: menuItems.where((item) => item.isAvailable).length,
      pendingSyncCount: syncState.pendingCount,
    );
  }

  SalesReport salesReportForDays(int days) {
    return SalesReport.fromOrders(orders: orders, days: days);
  }

  List<String> get categories {
    final values = menuItems.map((item) => item.category).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  double _salesSince(DateTime startAt) {
    return orders
        .where(
          (order) =>
              !order.createdAt.isBefore(startAt) &&
              order.status != OrderStatus.cancelled,
        )
        .fold<double>(0, (total, order) => total + order.total);
  }

  Future<void> completeIntro() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_seenIntroKey, true);
    hasSeenIntro = true;
    notifyListeners();
  }

  Future<void> saveLocalSetup({
    required String restaurantName,
    required String outletName,
  }) async {
    final cleanRestaurantName = restaurantName.trim();
    final cleanOutletName = outletName.trim().isEmpty
        ? 'Main Outlet'
        : outletName.trim();
    serverConfig = serverConfig.copyWith(
      restaurantName: cleanRestaurantName,
      outletName: cleanOutletName,
    );
    isLoggedIn = true;
    hasSeenIntro = true;
    await _persistSettings();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_seenIntroKey, true);
    await preferences.setBool(_accountLoggedInKey, true);
    if (cloudConfig.canConnect) {
      try {
        await _provisionTenantInternal(
          restaurantName: cleanRestaurantName,
          outletName: cleanOutletName,
        );
      } catch (error) {
        lastError = error.toString();
      }
    }
    notifyListeners();
  }

  Future<BkashPaymentSession> createBkashSandboxPayment({
    required double amount,
  }) {
    return createSubscriptionCheckout(amount: amount, plan: 'monthly');
  }

  Future<BkashPaymentSession> createSubscriptionCheckout({
    required double amount,
    required String plan,
    String? email,
    String? fullName,
  }) {
    cloudApiService.configure(
      cloudConfig: cloudConfig,
      serverConfig: serverConfig,
    );
    final name = (fullName?.trim().isNotEmpty == true)
        ? fullName!.trim()
        : (accountDisplayName.isNotEmpty
              ? accountDisplayName
              : accountUsername);
    final resolvedEmail = (email?.trim().isNotEmpty == true)
        ? email!.trim()
        : (accountEmail.isNotEmpty ? accountEmail : 'manager@example.com');
    if (PaymentDefaults.useUddoktaPay) {
      return cloudApiService.createUddoktaPayment(
        serverId: serverConfig.serverId,
        amount: amount,
        plan: plan,
        fullName: name,
        email: resolvedEmail,
      );
    }
    return cloudApiService.createBkashSandboxPayment(
      serverId: serverConfig.serverId,
      amount: amount,
    );
  }

  Future<bool> verifyBkashSandboxPayment(
    String paymentId, {
    String? invoiceId,
  }) async {
    return verifySubscriptionPayment(paymentId, invoiceId: invoiceId);
  }

  Future<bool> verifySubscriptionPayment(
    String paymentId, {
    String? invoiceId,
  }) async {
    var verified = false;
    final ok = await _runBusy(() async {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      final session = PaymentDefaults.useUddoktaPay
          ? await cloudApiService.verifyUddoktaPayment(
              paymentId,
              invoiceId: invoiceId,
            )
          : await cloudApiService.verifyBkashPayment(paymentId);
      verified = session.paid;
      if (!verified) {
        throw CloudApiException(
          session.lastError ??
              'Payment is not completed yet. Finish checkout in the payment window.',
        );
      }
      await _persistBkashPayment(session);
    });
    return ok && verified;
  }

  Future<void> markTemporaryBkashPaymentVerified({
    required String plan,
    required double amount,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final paymentId =
        'temporary_${plan}_${DateTime.now().millisecondsSinceEpoch}';
    bkashPaymentVerified = true;
    lastBkashPaymentId = paymentId;
    lastBkashTransactionId = 'temporary_bkash_sandbox';
    hasSeenIntro = true;
    await preferences.setBool(_bkashPaymentVerifiedKey, true);
    await preferences.setString(_bkashPaymentIdKey, paymentId);
    await preferences.setString(
      _bkashTransactionIdKey,
      'temporary_bkash_sandbox_${amount.toStringAsFixed(0)}',
    );
    await preferences.setBool(_seenIntroKey, true);
    notifyListeners();
  }

  int get lowStockCount =>
      inventoryItems.where((i) => i.isLowStock || i.isOutOfStock).length;

  List<String> get inventoryCategories {
    final cats =
        inventoryItems
            .map((i) => i.category)
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return cats;
  }

  Future<void> reloadData() async {
    menuItems = await database.getMenuItems();
    orders = await database.getOrders();
    syncEvents = await database.getSyncEvents(statuses: null, limit: 100);
    inventoryItems = await database.getInventoryItems();
    notifications = await database.getNotifications();
    notifyListeners();
  }

  Future<void> _handleDatabaseChanged() async {
    final previousOrderIds = Set<String>.from(_knownOrderIds);
    await reloadData();
    _knownOrderIds
      ..clear()
      ..addAll(orders.map((order) => order.id));
    await _autoPrintNewOrders(previousOrderIds);
  }

  Future<bool> saveSettings({
    required String restaurantName,
    required String outletName,
    required String cloudApiUrl,
    required String restaurantId,
    required String outletId,
    required bool cloudSyncEnabled,
    required int autoSyncIntervalSeconds,
  }) async {
    return _runBusy(() async {
      serverConfig = serverConfig.copyWith(
        restaurantName: restaurantName.trim(),
        outletName: outletName.trim(),
        restaurantId: restaurantId.trim().isEmpty
            ? serverConfig.restaurantId
            : restaurantId.trim(),
        outletId: outletId.trim().isEmpty
            ? serverConfig.outletId
            : outletId.trim(),
      );
      cloudConfig = cloudConfig.copyWith(
        baseUrl: CloudDefaults.resolveBaseUrl(cloudApiUrl),
        enabled: cloudSyncEnabled,
        autoSyncIntervalSeconds: autoSyncIntervalSeconds.clamp(10, 3600),
      );
      await _persistSettings();
      syncService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      if (cloudConfig.canConnect && accountId.trim().isEmpty) {
        // No account-bound token yet: bootstrap to mint one for this device.
        await _provisionTenantInternal(
          restaurantName: serverConfig.restaurantName,
          outletName: serverConfig.outletName,
        );
      } else if (isCloudReady && cloudConfig.canSync) {
        unawaited(syncService.syncNow());
      }
    });
  }

  Future<bool> provisionTenant({
    required String restaurantName,
    required String outletName,
  }) async {
    return _runBusy(() async {
      await _provisionTenantInternal(
        restaurantName: restaurantName,
        outletName: outletName,
      );
    });
  }

  Future<bool> createAccountAndProvisionTenant({
    required String restaurantName,
    required String outletName,
    required String email,
    required String username,
    required String password,
  }) async {
    return _runBusy(() async {
      await _prepareNewRestaurantIdentity();
      await _provisionTenantInternal(
        restaurantName: restaurantName,
        outletName: outletName,
      );
      accountEmail = email.trim();
      accountUsername = username.trim();
      accountRole = AccountRole.manager;
      accountDisplayName = username.trim();
      _accountPassword = password;
      if (cloudConfig.canSync) {
        await cloudApiService.createAdminAccount(
          outletId: serverConfig.outletId,
          email: accountEmail,
          username: accountUsername,
          password: password,
          role: AccountRole.manager,
          displayName: accountDisplayName,
        );
        await _loginCloudAccount(
          usernameOrEmail: accountEmail,
          password: password,
        );
        pendingHeroMediaSetup = true;
        return;
      }
      isLoggedIn = true;
      await _persistAccountAuth();
      pendingHeroMediaSetup = true;
    });
  }

  Future<bool> createManagerWithPassword({
    required String restaurantName,
    required String outletName,
    required String email,
    required String password,
  }) {
    final username = email.trim().toLowerCase();
    return createAccountAndProvisionTenant(
      restaurantName: restaurantName,
      outletName: outletName,
      email: username,
      username: username,
      password: password,
    );
  }

  Future<bool> googleLoginOrSignup({
    required AccountRole role,
    String? restaurantName,
    String? outletName,
    /// When set (e.g. staff flow), used as Cloud API base before hitting /admin/google.
    String? cloudApiUrlOverride,
  }) async {
    return _runBusy(() async {
      GoogleSignInAccount? googleUser;
      // Always sign the previous Google session out first so the account
      // chooser is shown. Without this, a returning user is silently logged
      // in to the cached account and can never pick a different one for a
      // second restaurant.
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Ignore — first run on a device has nothing to sign out from.
      }
      try {
        googleUser = await _googleSignIn.signIn();
      } on PlatformException catch (error) {
        throw Exception(
          'Google sign-in failed on this Android build. Add package com.terabyteai.foodmania.posadmin and this build SHA-1 to a Google Cloud Android OAuth client, then rebuild. Details: ${error.code}${error.message == null ? '' : ' - ${error.message}'}',
        );
      }
      if (googleUser == null) {
        throw Exception('Google sign-in was cancelled.');
      }
      final auth = await googleUser.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google did not return an ID token. Check POS_GOOGLE_WEB_CLIENT_ID and make sure it is a Web OAuth client ID.',
        );
      }
      // Manager signup with a restaurant name is a create-tenant flow — do not
      // reuse this device's serverId or the backend will bind to an old outlet.
      if (role.isManager && (restaurantName?.trim().isNotEmpty ?? false)) {
        await _prepareNewRestaurantIdentity();
      }
      final resolvedBase = _resolvedCloudBaseUrl(cloudApiUrlOverride);
      final loginCloudConfig = cloudConfig.copyWith(
        baseUrl: resolvedBase,
        enabled: true,
      );
      if (!loginCloudConfig.hasValidBaseUrl) {
        throw Exception(
          'Enter a valid server URL (https://… or http://…). Ask your manager for the same link they use in Settings → Cloud sync.',
        );
      }
      cloudConfig = loginCloudConfig;
      await _persistSettings();
      cloudApiService.configure(
        cloudConfig: loginCloudConfig,
        serverConfig: serverConfig,
      );
      // Pass through whatever the caller supplied — the signup flow sends the
      // restaurant the user just typed, the login flow sends nothing. The
      // backend uses presence of a restaurant name to decide whether this is
      // a create-tenant attempt; without it, it returns "account not found"
      // instead of auto-creating a placeholder restaurant.
      final result = await cloudApiService.googleStartOrLogin(
        idToken: idToken,
        role: role,
        serverId: serverConfig.serverId,
        restaurantName: restaurantName,
        outletName: outletName,
        restaurantId: serverConfig.restaurantId,
        outletId: serverConfig.outletId,
      );
      final wasFreshTenant =
          role.isManager && serverConfig.outletId != result.outletId;
      _applyAdminLoginResult(result, password: '');
      hasSeenIntro = true;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_seenIntroKey, true);
      await _persistSettings();
      await _persistAccountAuth();
      await _switchTenantIfNeeded();
      syncService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      unawaited(syncService.syncNow());
      // Only ask for hero media when this Google sign-in created a brand-new
      // tenant — returning managers should land straight on the dashboard.
      if (wasFreshTenant) {
        pendingHeroMediaSetup = true;
      }
    });
  }

  /// Called by the hero-media step when the manager finishes uploads (or
  /// taps "I'll do this later"). Clears the flag so the parent shell can
  /// finally mount MainShell.
  void completeHeroMediaSetup() {
    if (!pendingHeroMediaSetup) return;
    pendingHeroMediaSetup = false;
    notifyListeners();
  }

  Future<bool> loginWithAccount({
    required String usernameOrEmail,
    required String password,
  }) async {
    return _runBusy(() async {
      final id = usernameOrEmail.trim().toLowerCase();
      final cloudErrors = <Object>[];
      if (cloudConfig.hasValidBaseUrl) {
        try {
          await _loginCloudAccount(usernameOrEmail: id, password: password);
          return;
        } catch (error) {
          cloudErrors.add(error);
        }
      }

      if (accountUsername.trim().isEmpty || _accountPassword.isEmpty) {
        if (cloudErrors.isNotEmpty) {
          throw Exception(cloudErrors.first.toString());
        }
        throw Exception(
          'No account found on this device. Please create account first.',
        );
      }
      await _loginLocalAccount(usernameOrEmail: id, password: password);
    });
  }

  Future<void> _loginCloudAccount({
    required String usernameOrEmail,
    required String password,
  }) async {
    final loginCloudConfig = cloudConfig.copyWith(
      baseUrl: CloudDefaults.resolveBaseUrl(cloudConfig.baseUrl),
      enabled: true,
    );
    cloudApiService.configure(
      cloudConfig: loginCloudConfig,
      serverConfig: serverConfig,
    );
    final result = await cloudApiService.loginAdminAccount(
      usernameOrEmail: usernameOrEmail,
      password: password,
      serverId: serverConfig.serverId,
    );
    cloudConfig = loginCloudConfig;
    _applyAdminLoginResult(result, password: password);
    await _persistSettings();
    await _persistAccountAuth();
    await _switchTenantIfNeeded();
    syncService.configure(cloudConfig: cloudConfig, serverConfig: serverConfig);
    unawaited(syncService.syncNow());
  }

  /// Open the local SQLite file that belongs to the current tenant. Two
  /// restaurants on the same phone must each see only their own menu items,
  /// orders, inventory, etc. — switching here keeps that isolation enforced
  /// every time the active tenant changes (login, account switch, bootstrap).
  Future<void> _switchTenantIfNeeded() async {
    final tenantKey = serverConfig.outletId.trim();
    if (tenantKey.isEmpty) return;
    final previousTenant = database.activeTenantKey;
    if (previousTenant == tenantKey) return;
    await database.switchTenant(tenantKey);
    // When moving from one outlet to another on the same device, wipe any
    // stale rows (e.g. from an accidental legacy-db copy) and re-pull from
    // cloud so the UI cannot show the previous restaurant's menu/orders.
    if (previousTenant.isNotEmpty) {
      await database.clearLocalData();
      syncService.resetCloudPullState();
    }
    await reloadData();
    _knownOrderIds
      ..clear()
      ..addAll(orders.map((order) => order.id));
    if (isCloudReady && cloudConfig.canSync) {
      await syncService.syncNow();
    }
  }

  /// Mint a fresh device server id before creating a brand-new restaurant.
  /// The backend keys outlets by serverId; reusing the id from a previous
  /// restaurant on this phone would attach the new signup to the old outlet.
  static const _tenantIsolationHealKey = 'local_pos_tenant_isolation_heal_v1';

  Future<void> _healTenantDataIfNeeded(SharedPreferences preferences) async {
    final outletId = serverConfig.outletId.trim();
    if (!isLoggedIn || outletId.isEmpty || !isCloudReady) return;
    final healKey = '$_tenantIsolationHealKey:$outletId';
    if (preferences.getBool(healKey) ?? false) return;
    await database.clearLocalData();
    syncService.resetCloudPullState();
    await preferences.setBool(healKey, true);
    if (cloudConfig.canSync) {
      await syncService.syncNow();
    }
  }

  Future<void> _prepareNewRestaurantIdentity() async {
    final newServerId = _uuid.v4();
    serverConfig = serverConfig.copyWith(
      serverId: newServerId,
      restaurantId: '',
      outletId: '',
    );
    cloudConfig = cloudConfig.copyWith(deviceToken: '');
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_serverIdKey, newServerId);
    await preferences.remove(_restaurantIdKey);
    await preferences.remove(_outletIdKey);
    await preferences.remove(_deviceTokenKey);
  }

  String _mergePublicApiBaseUrl(String? fromServer, String fallback) {
    final raw = fromServer?.trim() ?? '';
    if (raw.isEmpty) return fallback;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return fallback;
    return raw;
  }

  String _resolvedCloudBaseUrl(String? override) {
    final hint = override?.trim();
    if (hint != null && hint.isNotEmpty) {
      return CloudDefaults.resolveBaseUrl(hint);
    }
    return CloudDefaults.resolveBaseUrl(cloudConfig.baseUrl);
  }

  void _applyAdminLoginResult(
    AdminLoginResult result, {
    required String password,
  }) {
    final resolvedBase = _mergePublicApiBaseUrl(
      result.publicApiBaseUrl,
      CloudDefaults.resolveBaseUrl(cloudConfig.baseUrl),
    );
    serverConfig = serverConfig.copyWith(
      serverId: result.serverId,
      restaurantId: result.restaurantId,
      outletId: result.outletId,
      restaurantName: result.restaurantName,
      outletName: result.outletName,
    );
    cloudConfig = cloudConfig.copyWith(
      baseUrl: resolvedBase,
      enabled: true,
      deviceToken: result.deviceToken,
    );
    accountId = result.accountId;
    accountEmail = result.email;
    accountUsername = result.username;
    accountDisplayName = result.displayName ?? result.username;
    accountRole = result.role;
    _accountPassword = password;
    isLoggedIn = true;
  }

  Future<void> _loginLocalAccount({
    required String usernameOrEmail,
    required String password,
  }) async {
    final usernameMatch =
        accountUsername.trim().toLowerCase() == usernameOrEmail;
    final emailMatch = accountEmail.trim().toLowerCase() == usernameOrEmail;
    if ((!usernameMatch && !emailMatch) || _accountPassword != password) {
      throw Exception('Invalid username/email or password.');
    }
    if (!isTenantReady) {
      throw Exception(
        'Restaurant setup is incomplete on this device. Please create account again.',
      );
    }
    isLoggedIn = true;
    accountRole = AccountRole.manager;
    await _persistAccountAuth();
  }

  Future<void> logOut() async {
    isLoggedIn = false;
    lastError = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_accountLoggedInKey, false);
    // Clear tenant-scoped prefs so the next login cannot briefly show the
    // previous restaurant's outlet id / token before switchTenant runs.
    serverConfig = serverConfig.copyWith(
      restaurantId: '',
      outletId: '',
      restaurantName: '',
      outletName: '',
    );
    cloudConfig = cloudConfig.copyWith(deviceToken: '');
    await preferences.remove(_outletIdKey);
    await preferences.remove(_restaurantIdKey);
    await preferences.remove(_deviceTokenKey);
    await preferences.remove(_restaurantNameKey);
    await preferences.remove(_outletNameKey);
    // Drop the cached Google session so the next sign-in shows the account
    // chooser instead of silently re-using the previous account.
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    // Tear down the realtime WebSocket so the next login forces a fresh
    // connection with the new device token — otherwise the stale socket
    // would keep using the old JWT and order events could stop flowing.
    unawaited(cloudRealtimeService.disconnect());
    notifyListeners();
  }

  Future<List<Map<String, Object?>>> loadStaffAccounts() async {
    if (!isManager || !cloudConfig.canSync) return const [];
    cloudApiService.configure(
      cloudConfig: cloudConfig,
      serverConfig: serverConfig,
    );
    return cloudApiService.listStaffAccounts();
  }

  Future<bool> addStaffEmail(String email, {String? displayName}) async {
    if (!isManager) {
      lastError = 'Only managers can add staff.';
      notifyListeners();
      return false;
    }
    return _runBusy(() async {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      await cloudApiService.addStaffAccount(
        email: email,
        displayName: displayName,
      );
    });
  }

  Future<void> saveMenuItem({
    String? id,
    required String name,
    required String description,
    required String category,
    required double price,
    required bool isAvailable,
    String? imageUrl,
    int? preparationTimeMinutes,
    List<String> tags = const [],
    DateTime? createdAt,
  }) async {
    final now = DateTime.now();
    final item = MenuItem(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      description: description.trim(),
      category: category.trim().isEmpty ? 'General' : category.trim(),
      price: price,
      imageUrl: _cleanNullable(imageUrl),
      isAvailable: isAvailable,
      preparationTimeMinutes: preparationTimeMinutes,
      tags: tags,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
    await database.upsertMenuItem(item);
    await _syncWithFreshTenantToken();
  }

  Future<String> uploadMenuImageDataUrl(String dataUrl) async {
    if (!cloudConfig.canSync) return dataUrl;
    return cloudApiService.uploadMenuImageDataUrl(dataUrl);
  }

  Future<List<String>> uploadOutletHeroImage(String dataUrl) async {
    cloudApiService.configure(
      cloudConfig: cloudConfig,
      serverConfig: serverConfig,
    );
    return cloudApiService.uploadOutletImage(dataUrl);
  }

  Future<String> uploadOutletHeroVideo(
    List<int> bytes,
    String filename,
  ) async {
    cloudApiService.configure(
      cloudConfig: cloudConfig,
      serverConfig: serverConfig,
    );
    return cloudApiService.uploadOutletVideo(bytes, filename);
  }

  Future<void> deleteMenuItem(String id) async {
    await database.deleteMenuItem(id);
    await _syncWithFreshTenantToken();
  }

  Future<void> toggleMenuAvailability(String id, bool isAvailable) async {
    await database.toggleMenuAvailability(id, isAvailable);
    await _syncWithFreshTenantToken();
  }

  // ── Inventory ─────────────────────────────────────────────────────────────

  Future<void> saveInventoryItem(InventoryItem item) async {
    await database.upsertInventoryItem(item);
  }

  Future<void> deleteInventoryItem(String id) async {
    await database.deleteInventoryItem(id);
  }

  Future<InventoryItem> adjustStock({
    required String inventoryItemId,
    required double delta,
    required AdjustmentType type,
    String note = '',
  }) async {
    return database.adjustStock(
      inventoryItemId: inventoryItemId,
      delta: delta,
      type: type.value,
      note: note,
    );
  }

  Future<List<StockAdjustment>> getStockAdjustments(
    String inventoryItemId,
  ) async {
    return database.getStockAdjustments(inventoryItemId);
  }

  Future<OrderModel> createManualOrder({
    required List<OrderRequestItem> requestedItems,
    String? customerName,
    String? tableNo,
    String? note,
  }) async {
    final order = await database.createOrder(
      requestedItems: requestedItems,
      customerName: customerName,
      tableNo: tableNo,
      note: note,
      source: OrderSource.manual,
      createdByAccountId: accountId.isEmpty ? null : accountId,
      createdByRole: accountRole.value,
      initialStatus: OrderStatus.served,
    );
    unawaited(syncService.syncNow());
    return order;
  }

  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    await database.updateOrderStatus(id, status);
    if (status == OrderStatus.accepted || status == OrderStatus.served) {
      final order = await database.getOrderById(id);
      if (order != null) {
        await _printAcceptedOrderIfNeeded(order);
      }
    }
    unawaited(syncService.syncNow());
  }

  Future<bool> testCloud() async {
    var cloudOk = false;
    final actionOk = await _runBusy(() async {
      cloudOk = await syncService.testCloud();
    });
    return actionOk && cloudOk;
  }

  Future<bool> syncNow() async {
    return _runBusy(_syncWithFreshTenantToken);
  }

  Future<bool> retryFailedSync() async {
    return _runBusy(syncService.retryFailed);
  }

  Future<bool> pushRestaurantInfo({
    required String title,
    required String phone,
    required String email,
    required String address,
    required String website,
    required String description,
  }) async {
    return _runBusy(() async {
      final payload = <String, Object?>{
        'serverId': serverConfig.serverId,
        'restaurantId': serverConfig.restaurantId,
        'outletId': serverConfig.outletId,
        'restaurantName': serverConfig.restaurantName,
        'outletName': serverConfig.outletName,
        'infoTitle': title.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'address': address.trim(),
        'website': website.trim(),
        'description': description.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await database.queueServerConfigSync(
        serverId: serverConfig.serverId,
        payload: payload,
      );
      syncService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      if (cloudConfig.canSync) {
        await syncService.syncNow();
      }
    });
  }

  Future<void> updateUiScale(double value) async {
    final next = value.clamp(minUiScale, maxUiScale).toDouble();
    if ((uiScale - next).abs() < 0.001) return;
    uiScale = next;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_uiScaleKey, uiScale);
  }

  Future<void> updateTableCount(int count) async {
    final clamped = count.clamp(1, 200);
    if (serverConfig.tableCount == clamped) return;
    serverConfig = serverConfig.copyWith(tableCount: clamped);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_tableCountKey, clamped);
  }

  Future<void> updateLanguage(AppLanguage value) async {
    if (language == value) return;
    language = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_languageKey, value.code);
    await preferences.setBool(_languagePreferenceSetKey, true);
  }

  Future<void> updateThemePreference(AppThemePreference value) async {
    if (themePreference == AppThemePreference.white) return;
    themePreference = AppThemePreference.white;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _themePreferenceKey,
      AppThemePreference.white.code,
    );
  }

  Future<void> clearLocalData() async {
    await database.clearLocalData();
    await reloadData();
  }

  Future<String> printTicketPreview(OrderModel order) {
    return printerService.previewTicket(
      order,
      restaurantName: restaurantName,
      outletName: outletName,
    );
  }

  Future<List<BluetoothPrinterDevice>> refreshPairedPrinters() async {
    pairedPrinters = await printerService.refreshPairedPrinters();
    notifyListeners();
    return pairedPrinters;
  }

  Future<bool> connectPrinter(BluetoothPrinterDevice printer) async {
    final ok = await printerService.connect(printer);
    printerState = printerService.state;
    if (ok) {
      await refreshPairedPrinters();
    } else {
      notifyListeners();
    }
    return ok;
  }

  Future<bool> disconnectPrinter() async {
    final ok = await printerService.disconnect();
    printerState = printerService.state;
    notifyListeners();
    return ok;
  }

  Future<void> setAutoPrintOrders(bool value) async {
    await printerService.setAutoPrintEnabled(value);
    printerState = printerService.state;
    notifyListeners();
  }

  Future<bool> testPrinter() {
    return printerService.testPrint(
      restaurantName: restaurantName,
      outletName: outletName,
    );
  }

  Future<bool> printOrderTicket(OrderModel order) {
    return printerService
        .printOrderTicket(
          order,
          restaurantName: restaurantName,
          outletName: outletName,
        )
        .then((ok) async {
          await addNotification(
            type: ok
                ? PosNotificationType.printSuccess
                : PosNotificationType.printFailed,
            title: ok ? 'Ticket printed' : 'Print failed',
            body: ok
                ? '${order.displaySequence} was sent to the printer.'
                : (printerState.lastError ??
                      '${order.displaySequence} could not print.'),
            orderId: order.id,
            actionTarget: 'orders',
            playSound: !ok,
          );
          return ok;
        });
  }

  Future<void> addNotification({
    required PosNotificationType type,
    required String title,
    required String body,
    String? orderId,
    String? actionTarget,
    bool playSound = true,
  }) async {
    final notification = PosNotification(
      id: _uuid.v4(),
      type: type,
      title: title,
      body: body,
      orderId: orderId,
      actionTarget: actionTarget,
      createdAt: DateTime.now(),
    );
    await database.upsertNotification(notification);
    notifications = await database.getNotifications();
    if (isAppForeground) {
      // Foreground: in-app toast (see MainShell) + the same in-app audio that
      // we've always played.
      if (playSound) unawaited(playNotificationSound());
    } else {
      // Background: fire an OS-level notification. Its channel was created
      // with the user's chosen sound (see SystemNotificationService.configureSound),
      // so the system plays the custom sound itself. We deliberately skip the
      // in-app audio path here to avoid double-playing on platforms where
      // audioplayers might still emit audio in background.
      // Android notification IDs must fit in 32-bit int — derive from the
      // UUID hash so re-issuing the same notification stays idempotent.
      final notificationId = notification.id.hashCode & 0x7fffffff;
      unawaited(
        systemNotifications.show(
          id: notificationId,
          title: title,
          body: body,
          payload: actionTarget,
        ),
      );
    }
    notifyListeners();
  }

  Future<void> markNotificationRead(String id) async {
    await database.markNotificationRead(id);
    notifications = await database.getNotifications();
    notifyListeners();
  }

  Future<void> markAllNotificationsRead() async {
    await database.markAllNotificationsRead();
    notifications = await database.getNotifications();
    notifyListeners();
  }

  Future<void> setNotificationSoundEnabled(bool value) async {
    notificationSoundEnabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationSoundEnabledKey, value);
    await systemNotifications.configureSound(
      enabled: notificationSoundEnabled,
      soundPath: notificationSoundPath,
    );
    notifyListeners();
  }

  Future<void> setNotificationSoundPath(String path) async {
    var stored = path.trim();
    if (stored.isNotEmpty && !stored.startsWith('content://')) {
      // file_picker hands us a path inside the app's private cache. Android's
      // NotificationManager runs in system_server and cannot read app-private
      // files via file:// URIs, so we register the sound with MediaStore and
      // use the content:// URI it returns — that one *is* readable by the
      // system. We still mirror to external storage first as a stable copy
      // (file_picker's cache can be evicted).
      try {
        final mirrored = await _mirrorSoundToSharedLocation(stored);
        final contentUri = await systemNotifications.registerSoundWithSystem(
          mirrored,
        );
        stored = contentUri;
      } catch (error, stack) {
        debugPrint('Failed to prepare notification sound: $error\n$stack');
        // Fall through with the original path — the service will fall back to
        // the system default if the URI ends up unreadable.
      }
    }
    notificationSoundPath = stored;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _notificationSoundPathKey,
      notificationSoundPath,
    );
    await systemNotifications.configureSound(
      enabled: notificationSoundEnabled,
      soundPath: notificationSoundPath,
    );
    notifyListeners();
  }

  Future<String> _mirrorSoundToSharedLocation(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) return sourcePath;
    Directory? baseDir;
    if (Platform.isAndroid) {
      // /storage/emulated/0/Android/data/<package>/files — readable by the
      // Android system process, which is what the notification channel needs.
      baseDir = await getExternalStorageDirectory();
    }
    baseDir ??= await getApplicationSupportDirectory();
    final soundsDir = Directory('${baseDir.path}/notification_sounds');
    if (!await soundsDir.exists()) {
      await soundsDir.create(recursive: true);
    }
    final originalName = sourcePath.split(Platform.pathSeparator).last;
    final extension = originalName.contains('.')
        ? originalName.substring(originalName.lastIndexOf('.'))
        : '.mp3';
    final hash = sourcePath.hashCode.abs().toRadixString(36);
    final destPath = '${soundsDir.path}/sound_$hash$extension';
    final destFile = File(destPath);
    if (!await destFile.exists()) {
      await source.copy(destPath);
    }
    return destPath;
  }

  Future<void> resetNotificationSound() => setNotificationSoundPath('');

  /// Fire a real OS notification so the user can verify that channel sound,
  /// permission, and heads-up behavior all work without waiting for an order.
  Future<void> sendTestNotification() async {
    await systemNotifications.show(
      id: 999001,
      title: 'Test notification',
      body: 'If you can hear this, alerts are wired up correctly.',
      payload: 'test',
    );
    if (notificationSoundEnabled) {
      unawaited(playNotificationSound());
    }
  }

  Future<void> playNotificationSound() async {
    if (!notificationSoundEnabled) return;
    final path = notificationSoundPath.trim();
    final fallbackUri = systemNotifications.effectiveDefaultSoundUri;
    try {
      // content:// URIs (MediaStore-registered sounds) and file:// URIs go
      // through UrlSource so audioplayers can hand them to Android's
      // MediaPlayer, which natively understands both. Bare paths still use
      // DeviceFileSource so iOS / desktop keep working.
      if (path.isEmpty) {
        // No custom sound — play the system default notification tone via
        // its well-known content URI. Much more audible than the tiny click
        // SystemSound.alert produces on most devices.
        await _notificationPlayer.play(UrlSource(fallbackUri));
        return;
      }
      if (path.startsWith('content://') || path.startsWith('file://')) {
        await _notificationPlayer.play(UrlSource(path));
      } else {
        await _notificationPlayer.play(DeviceFileSource(path));
      }
    } catch (_) {
      // Last-ditch fallback: try the system default URI once more, then the
      // built-in click. We don't want the user to hear silence on every
      // notification because of a single bad URI.
      try {
        await _notificationPlayer.play(UrlSource(fallbackUri));
      } catch (_) {
        await SystemSound.play(SystemSoundType.alert);
      }
    }
  }

  Future<void> _autoPrintNewOrders(Set<String> previousOrderIds) async {
    final newOrders =
        orders
            .where((order) => !previousOrderIds.contains(order.id))
            .toList(growable: false)
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (newOrders.isEmpty) return;

    for (final order in newOrders) {
      if (order.status.adminStatus == OrderStatus.pending) {
        await addNotification(
          type: PosNotificationType.pendingOrder,
          title: 'New pending order',
          body:
              '${order.displaySequence} · ${order.items.length} items · ৳${order.total.toStringAsFixed(0)}',
          orderId: order.id,
          actionTarget: 'pending_orders',
        );
      }
      await _printAcceptedOrderIfNeeded(order);
    }
  }

  Future<void> _printAcceptedOrderIfNeeded(OrderModel order) async {
    // Only the manager device auto-prints. Staff devices forward to manager
    // via cloud sync; the manager app then receives the order and prints.
    if (!isManager) return;
    final status = order.status.adminStatus;
    final isAccepted =
        status == OrderStatus.accepted || status == OrderStatus.served;
    if (!isAccepted ||
        !printerState.autoPrintEnabled ||
        !printerState.hasSelectedPrinter ||
        printerService.hasPrintedOrder(order.id) ||
        _autoPrintInFlight.contains(order.id)) {
      return;
    }
    _autoPrintInFlight.add(order.id);
    try {
      await printOrderTicket(order);
    } finally {
      _autoPrintInFlight.remove(order.id);
    }
  }

  List<OrderModel> ordersFor({OrderStatus? status, OrderSource? source}) {
    return orders
        .where((order) {
          final matchesStatus =
              status == null || order.status.adminStatus == status;
          final matchesSource = source == null || order.source == source;
          return matchesStatus && matchesSource;
        })
        .toList(growable: false);
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(syncService.dispose());
    unawaited(printerService.dispose());
    unawaited(_notificationPlayer.dispose());
    cloudApiService.close();
    unawaited(database.close());
    super.dispose();
  }

  Future<bool> _runBusy(Future<void> Function() action) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      lastError = error.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _persistSettings() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _restaurantNameKey,
      serverConfig.restaurantName,
    );
    await preferences.setString(_outletNameKey, serverConfig.outletName);
    await preferences.setString(_restaurantIdKey, serverConfig.restaurantId);
    await preferences.setString(_outletIdKey, serverConfig.outletId);
    await preferences.setString(_serverIdKey, serverConfig.serverId);
    await preferences.setString(_cloudApiUrlKey, cloudConfig.baseUrl);
    await preferences.setBool(_cloudSyncEnabledKey, cloudConfig.enabled);
    await preferences.setString(_deviceTokenKey, cloudConfig.deviceToken);
    await preferences.setString(_languageKey, language.code);
    await preferences.setString(_themePreferenceKey, themePreference.code);
    await preferences.setDouble(_uiScaleKey, uiScale);
    await preferences.setInt(
      _autoSyncIntervalKey,
      cloudConfig.autoSyncIntervalSeconds,
    );
    await preferences.setInt(_tableCountKey, serverConfig.tableCount);
  }

  Future<void> _persistAccountAuth() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_accountIdKey, accountId);
    await preferences.setString(_accountEmailKey, accountEmail);
    await preferences.setString(_accountUsernameKey, accountUsername);
    await preferences.setString(_accountDisplayNameKey, accountDisplayName);
    await preferences.setString(_accountRoleKey, accountRole.value);
    await preferences.setString(_accountPasswordKey, _accountPassword);
    await preferences.setBool(_accountLoggedInKey, isLoggedIn);
  }

  Future<void> _provisionTenantInternal({
    required String restaurantName,
    required String outletName,
  }) async {
    final bootstrapCloudConfig = cloudConfig.copyWith(
      baseUrl: CloudDefaults.resolveBaseUrl(cloudConfig.baseUrl),
      enabled: true,
    );
    cloudApiService.configure(
      cloudConfig: bootstrapCloudConfig,
      serverConfig: serverConfig,
    );
    final tenant = await cloudApiService.bootstrapTenant(
      serverId: serverConfig.serverId,
      restaurantName: restaurantName.trim(),
      outletName: outletName.trim(),
      restaurantId: serverConfig.restaurantId,
      outletId: serverConfig.outletId,
    );
    serverConfig = serverConfig.copyWith(
      serverId: tenant.serverId,
      restaurantId: tenant.restaurantId,
      outletId: tenant.outletId,
      restaurantName: tenant.restaurantName,
      outletName: tenant.outletName,
    );
    // /tenants/bootstrap returns a token that only carries outlet_id. If the
    // user is already logged in, their existing token also carries account_id
    // (required by manager-only endpoints like /admin/staff). Keep the
    // account-bound token so those calls don't 401.
    final hasAccountToken =
        accountId.trim().isNotEmpty && cloudConfig.deviceToken.trim().isNotEmpty;
    final mergedBase = _mergePublicApiBaseUrl(
      tenant.publicApiBaseUrl,
      bootstrapCloudConfig.baseUrl,
    );
    cloudConfig = bootstrapCloudConfig.copyWith(
      deviceToken: hasAccountToken
          ? cloudConfig.deviceToken
          : tenant.deviceToken,
      baseUrl: mergedBase,
    );
    await _persistSettings();
    await _switchTenantIfNeeded();
    syncService.configure(cloudConfig: cloudConfig, serverConfig: serverConfig);
    await syncService.syncNow();
  }

  Future<void> _syncWithFreshTenantToken() async {
    // Logged-in managers/staff already hold an account-bound token that
    // satisfies every endpoint. Re-bootstrapping here would swap it for an
    // outlet-only token and break /admin/staff (and similar manager-only
    // endpoints) with HTTP 401.
    if (accountId.trim().isNotEmpty) {
      if (cloudConfig.canSync) {
        await syncService.syncNow();
      }
      return;
    }
    if (cloudConfig.canConnect && isTenantReady) {
      try {
        await _provisionTenantInternal(
          restaurantName: serverConfig.restaurantName,
          outletName: serverConfig.outletName,
        );
        return;
      } catch (_) {
        // Fall through to the normal sync path so the sync screen shows the
        // backend error instead of hiding it behind token refresh.
      }
    }
    await syncService.syncNow();
  }

  Future<void> _persistBkashPayment(BkashPaymentSession session) async {
    final preferences = await SharedPreferences.getInstance();
    bkashPaymentVerified = true;
    lastBkashPaymentId = session.paymentId;
    lastBkashTransactionId = session.transactionId;
    hasSeenIntro = true;
    await preferences.setBool(_bkashPaymentVerifiedKey, true);
    await preferences.setString(_bkashPaymentIdKey, session.paymentId);
    await preferences.setBool(_seenIntroKey, true);
    final transactionId = session.transactionId?.trim();
    if (transactionId != null && transactionId.isNotEmpty) {
      await preferences.setString(_bkashTransactionIdKey, transactionId);
    }
    notifyListeners();
  }

  Future<String> _getOrCreatePreference(
    SharedPreferences preferences,
    String key,
    String fallback,
  ) async {
    final existing = preferences.getString(key);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    await preferences.setString(key, fallback);
    return fallback;
  }

  String? _cleanNullable(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static final String _seenIntroKey = 'local_pos_seen_intro';
  static final String _restaurantNameKey = 'local_pos_restaurant_name';
  static final String _outletNameKey = 'local_pos_outlet_name';
  static final String _serverIdKey = 'local_pos_server_id';
  static final String _restaurantIdKey = 'local_pos_restaurant_id';
  static final String _outletIdKey = 'local_pos_outlet_id';
  static final String _cloudApiUrlKey = 'local_pos_cloud_api_url';
  static final String _deviceTokenKey = 'local_pos_device_token';
  static final String _cloudSyncEnabledKey = 'local_pos_cloud_sync_enabled';
  static final String _autoSyncIntervalKey = 'local_pos_auto_sync_interval';
  static final String _uiScaleKey = 'local_pos_ui_scale';
  static final String _languageKey = 'local_pos_language';
  static final String _languagePreferenceSetKey =
      'local_pos_language_preference_set';
  static final String _themePreferenceKey = 'local_pos_theme_preference';
  static final String _bkashPaymentVerifiedKey =
      'local_pos_bkash_payment_verified';
  static final String _bkashPaymentIdKey = 'local_pos_bkash_payment_id';
  static final String _bkashTransactionIdKey = 'local_pos_bkash_transaction_id';
  static final String _accountEmailKey = 'local_pos_account_email';
  static final String _accountIdKey = 'local_pos_account_id';
  static final String _accountUsernameKey = 'local_pos_account_username';
  static final String _accountDisplayNameKey = 'local_pos_account_display_name';
  static final String _accountRoleKey = 'local_pos_account_role';
  static final String _accountPasswordKey = 'local_pos_account_password';
  static final String _accountLoggedInKey = 'local_pos_account_logged_in';
  static final String _notificationSoundEnabledKey =
      'local_pos_notification_sound_enabled';
  static final String _notificationSoundPathKey =
      'local_pos_notification_sound_path';
  static final String _tableCountKey = 'local_pos_table_count';
  static double minUiScale = 0.96;
  static double maxUiScale = 1.18;
}
