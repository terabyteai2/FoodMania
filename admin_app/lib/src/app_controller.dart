import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'core/constants/cloud_defaults.dart';
import 'core/constants/google_auth_defaults.dart';
import 'core/constants/payment_defaults.dart';
import 'core/localization/app_strings.dart';
import 'core/utils/bounded_string_set.dart';
import 'models/account_role.dart';
import 'models/app_update_info.dart';
import 'models/bkash_payment_session.dart';
import 'models/daily_report.dart';
import 'models/dashboard_metrics.dart';
import 'models/dashboard_summary.dart';
import 'models/facebook_chatbot_config.dart';
import 'models/inventory_item.dart';
import 'models/inventory_summary.dart';
import 'models/inventory_unit.dart';
import 'models/receipt_scan.dart';
import 'models/menu_item.dart';
import 'models/order_item.dart';
import 'models/order_model.dart';
import 'models/order_payment_method.dart';
import 'models/order_service_type.dart';
import 'models/order_source.dart';
import 'models/order_status.dart';
import 'models/pos_notification.dart';
import 'models/sales_report.dart';
import 'models/server_config.dart';
import 'models/stock_adjustment.dart';
import 'models/sync_event.dart';
import 'services/app_update_installer_service.dart';
import 'services/cloud_api_service.dart';
import 'services/cloud_realtime_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_database_service.dart';
import 'services/printer_service.dart';
import 'services/sync_service.dart';
import 'services/system_notification_service.dart';

class StaffInvitePending {
  const StaffInvitePending({
    required this.inviteId,
    required this.restaurantName,
    required this.outletName,
    required this.signupToken,
    required this.phone,
  });

  final String inviteId;
  final String restaurantName;
  final String outletName;
  final String signupToken;
  final String phone;
}

class MenuScanImportResult {
  const MenuScanImportResult({
    required this.createdCount,
    required this.skippedDuplicateCount,
    required this.scanResult,
  });

  final int createdCount;
  final int skippedDuplicateCount;
  final MenuScanResult scanResult;
}

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

/// Initial slice of orders pulled into memory on reload — newest first.
const int kOrdersInitialPage = 200;

/// Page size for `loadMoreOrders()`; the orders list grows by this much
/// each time the orders screen reaches the end of the scroll extent.
const int kOrdersPageSize = 100;

/// Hard cap on the per-restaurant alert-tracking sets so they cannot grow
/// without bound over a long-running app session.
const int kAlertSetCap = 2000;

class PosAppController extends ChangeNotifier {
  PosAppController({
    LocalDatabaseService? database,
    PrinterService? printerService,
    CloudApiService? cloudApiService,
    CloudRealtimeService? cloudRealtimeService,
    AppUpdateInstallerService? appUpdateInstaller,
    ConnectivityService? connectivityService,
    SyncService? syncService,
    SystemNotificationService? systemNotifications,
  }) : database = database ?? LocalDatabaseService(),
       printerService = printerService ?? PrinterService(),
       cloudApiService = cloudApiService ?? CloudApiService(),
       cloudRealtimeService = cloudRealtimeService ?? CloudRealtimeService(),
       appUpdateInstaller = appUpdateInstaller ?? AppUpdateInstallerService(),
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
          onRemoteEvent: _handleRemoteSyncEvent,
        );
  }

  final LocalDatabaseService database;
  final PrinterService printerService;
  final CloudApiService cloudApiService;
  final CloudRealtimeService cloudRealtimeService;
  final AppUpdateInstallerService appUpdateInstaller;
  final ConnectivityService connectivityService;
  final SystemNotificationService systemNotifications;
  late final SyncService syncService;

  final Uuid _uuid = Uuid();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final BoundedStringSet _knownOrderIds = BoundedStringSet(cap: kAlertSetCap);
  final Set<String> _autoPrintInFlight = <String>{};

  /// Coalesces concurrent print requests for the same order (auto + manual).
  final Map<String, Future<bool>> _orderPrintFutures = <String, Future<bool>>{};

  /// Orders we already fired a pending alert for (prevents sync/DB replay loops).
  final BoundedStringSet _alertedPendingOrderIds = BoundedStringSet(
    cap: kAlertSetCap,
  );

  /// Orders we already fired an accepted/served alert for.
  final BoundedStringSet _alertedAcceptedOrderIds = BoundedStringSet(
    cap: kAlertSetCap,
  );

  /// Orders we already surfaced a print success/fail alert for.
  final BoundedStringSet _alertedPrintOrderIds = BoundedStringSet(
    cap: kAlertSetCap,
  );

  /// Auto-print stopped after a failure so DB churn does not re-print forever.
  final BoundedStringSet _autoPrintGiveUpOrderIds = BoundedStringSet(
    cap: kAlertSetCap,
  );

  /// Set when Bluetooth/printer is unavailable — blocks auto-print for all orders.
  String? _autoPrintInfrastructureBlocked;

  /// One in-app alert per infrastructure error message (e.g. Bluetooth off).
  final BoundedStringSet _alertedPrintFailureReasons = BoundedStringSet(
    cap: kAlertSetCap,
  );
  Timer? _databaseChangeDebounce;
  bool _handlingDatabaseChange = false;
  bool _databaseChangePending = false;
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
  // Onboarding subscription choice: 'none' (not picked), 'trial', or 'paid'.
  String subscriptionState = 'none';
  DateTime? trialEndsAt;
  // True from the moment onboarding completes (subscription chosen) until
  // MainShell mounts and consumes it — drives "land on menu tab on first run".
  bool pendingOnboardingLanding = false;
  // True between "manager signup succeeded" and "manager finished or skipped
  // the hero-media step". The app shell uses this to keep ModeIntroScreen on
  // screen (forcing the hero-media view) even though the manager is already
  // logged-in + has a tenant — otherwise MainShell would mount immediately
  // after signup and the hero-media step would never get a chance to render.
  bool pendingHeroMediaSetup = false;
  String? phoneSignupToken;
  String? verifiedPhoneDisplay;
  StaffInvitePending? pendingStaffInvite;

  /// New manager sign-up must pay before using the app (survives app restarts).
  bool needsOnboardingPayment = false;
  String selectedSubscriptionPlan = '';
  String? lastBkashPaymentId;
  String? lastBkashTransactionId;
  AppLanguage language = AppLanguage.bn;
  AppThemePreference themePreference = AppThemePreference.white;
  double uiScale = 1.06;
  String? lastError;
  bool demoManagerLoginEnabled = false;
  String phoneOtpMode = 'unconfigured';
  bool showDevOtpHint = false;
  String devOtpCodeHint = '000000';
  bool isLoggedIn = false;
  AccountRole accountRole = AccountRole.manager;
  String accountId = '';
  String accountEmail = '';
  String accountUsername = '';
  String accountDisplayName = '';
  String _accountPassword = '';
  bool notificationSoundEnabled = true;
  String notificationSoundPath = '';
  bool varianceTrackingEnabled = false;
  List<MenuItem> menuItems = [];
  List<OrderModel> orders = [];
  bool _hasMoreOrders = false;
  bool _loadingMoreOrders = false;
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
  DashboardSummary? dashboardSummary;
  bool dashboardSummaryLoading = false;
  String? dashboardSummaryError;
  InventorySummary? inventorySummary;
  bool inventorySummaryLoading = false;
  String? inventorySummaryError;
  AppUpdateInfo? pendingAppUpdate;
  bool appUpdateBusy = false;
  String appUpdateStatus = '';
  String? appUpdateError;
  FacebookChatbotConfig? facebookChatbotConfig;
  bool facebookChatbotLoading = false;
  String? facebookChatbotError;
  int _dismissedAppUpdateVersionCode = 0;
  AppUpdateInfo? _appUpdateWaitingForPermission;
  bool _checkingForAppUpdate = false;

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

  /// Manager must pick a plan and receive activation before using the app.
  bool get mustCompleteOnboardingPayment =>
      isManager && needsOnboardingPayment && subscriptionState != 'paid';

  String get uiScaleLabel {
    final text = strings;
    if (uiScale <= 0.88) return text.compact;
    if (uiScale >= 0.98) return text.large;
    return text.comfortable;
  }

  // Alias so widgets can compare without importing controller constants.
  static const double kCompactScale = 0.84;
  static const double kComfortableScale = 0.92;
  static const double kLargeScale = 1.02;

  // App is ready to use as soon as the restaurant has a name.
  // Cloud sync is optional and configured separately.
  bool get isTenantReady {
    return serverConfig.restaurantName.trim().isNotEmpty &&
        serverConfig.outletName.trim().isNotEmpty;
  }

  bool get isCloudReady =>
      cloudConfig.hasDeviceToken && cloudConfig.hasValidBaseUrl;
  bool get isManager => accountRole.isManager;

  /// Temporary kill switch for order-triggered printer side effects.
  ///
  /// Pending/accepted order notifications still fire; printer preflight,
  /// auto-print, and printer success/failure alerts are paused for now.
  bool get orderPrinterSideEffectsEnabled => false;

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
      if (_appUpdateWaitingForPermission != null) {
        unawaited(_resumeAppUpdateAfterPermission());
      }
      unawaited(syncService.syncNow());
      unawaited(syncSubscriptionAccessFromCloud());
      unawaited(checkForAppUpdate());
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
      subscriptionState =
          preferences.getString(_subscriptionStateKey) ?? 'none';
      needsOnboardingPayment =
          preferences.getBool(_needsOnboardingPaymentKey) ?? false;
      selectedSubscriptionPlan = preferences.getString(_selectedPlanKey) ?? '';
      final trialEndsMillis = preferences.getInt(_trialEndsAtKey);
      trialEndsAt = trialEndsMillis == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(trialEndsMillis);
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
      final storedRestaurantName =
          preferences.getString(_restaurantNameKey) ?? '';
      final storedOutletName = preferences.getString(_outletNameKey) ?? '';
      serverConfig = ServerConfig(
        serverId: await _getOrCreatePreference(
          preferences,
          _serverIdKey,
          _uuid.v4(),
        ),
        restaurantId: preferences.getString(_restaurantIdKey) ?? '',
        outletId: preferences.getString(_outletIdKey) ?? '',
        restaurantName: storedRestaurantName,
        outletName: storedOutletName.trim().isEmpty
            ? storedRestaurantName
            : storedOutletName,
        publicSlug: preferences.getString(_publicSlugKey) ?? '',
        tableCount: preferences.getInt(_tableCountKey) ?? 10,
        customerMenuTheme:
            preferences.getString(_customerMenuThemeKey) ?? 'napoli_trattoria',
      );
      // Auto-migrate stale URLs: any previously stored ngrok tunnel is treated
      // as expired and replaced with the compile-time default (now the VPS).
      final storedCloudUrl = preferences.getString(_cloudApiUrlKey);
      final effectiveCloudUrl =
          (storedCloudUrl != null &&
              storedCloudUrl.toLowerCase().contains('ngrok'))
          ? null
          : storedCloudUrl;
      if (storedCloudUrl != effectiveCloudUrl) {
        debugPrint(
          '[QB-AUTH] migrating stale stored ngrok URL $storedCloudUrl -> default ${CloudDefaults.embeddedBaseUrl}',
        );
        await preferences.remove(_cloudApiUrlKey);
      }
      cloudConfig = CloudConfig(
        baseUrl: CloudDefaults.resolveBaseUrl(effectiveCloudUrl),
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
      varianceTrackingEnabled =
          preferences.getBool(_varianceTrackingEnabledKey) ?? false;
      _dismissedAppUpdateVersionCode =
          preferences.getInt(_dismissedAppUpdateVersionCodeKey) ?? 0;
      isLoggedIn = preferences.getBool(_accountLoggedInKey) ?? isTenantReady;

      await printerService.initialize();
      printerState = printerService.state;
      await systemNotifications.initialize();
      unawaited(systemNotifications.requestNotificationAccess());
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
          _scheduleDatabaseChanged();
          unawaited(syncService.refreshSummary());
        }),
      );
      _subscriptions.add(
        printerService.stateStream.listen((state) {
          printerState = state;
          if (state.connected &&
              !_isInfrastructurePrintError(state.lastError)) {
            _autoPrintInfrastructureBlocked = null;
          }
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
      _seedOrderAlertState();
      if (isCloudReady && cloudConfig.canSync) {
        unawaited(syncService.syncNow());
      }
      if (isLoggedIn && cloudConfig.hasDeviceToken) {
        unawaited(syncSubscriptionAccessFromCloud());
        unawaited(checkForAppUpdate());
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
    final values =
        menuItems
            .map((item) => item.localizedCategory(language))
            .where((category) => category.trim().isNotEmpty)
            .toSet()
            .toList()
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

  /// After an automatic Google signup (account_not_found fallback), force the
  /// next screen to collect the real restaurant/outlet names. Backend may hold
  /// a temporary placeholder, which will be replaced when setup is submitted.
  Future<void> requireRestaurantNamingAfterGoogleSignup() async {
    await markOnboardingPaymentRequired();
    serverConfig = serverConfig.copyWith(restaurantName: '', outletName: '');
    await _persistSettings();
    notifyListeners();
  }

  /// Ensures a new manager completes plan selection / activation after setup.
  Future<void> markOnboardingPaymentRequired() async {
    needsOnboardingPayment = true;
    subscriptionState = 'none';
    bkashPaymentVerified = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_needsOnboardingPaymentKey, true);
    await preferences.setString(_subscriptionStateKey, 'none');
    await preferences.setBool(_bkashPaymentVerifiedKey, false);
    notifyListeners();
  }

  Future<void> clearOnboardingPaymentRequired() async {
    needsOnboardingPayment = false;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_needsOnboardingPaymentKey, false);
    notifyListeners();
  }

  Future<void> startFreeTrial() async {
    final preferences = await SharedPreferences.getInstance();
    final ends = DateTime.now().add(const Duration(days: 30));
    subscriptionState = 'trial';
    trialEndsAt = ends;
    pendingOnboardingLanding = true;
    await preferences.setString(_subscriptionStateKey, subscriptionState);
    await preferences.setInt(_trialEndsAtKey, ends.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> markSubscriptionPaid() async {
    final preferences = await SharedPreferences.getInstance();
    subscriptionState = 'paid';
    pendingOnboardingLanding = true;
    await preferences.setString(_subscriptionStateKey, subscriptionState);
    await clearOnboardingPaymentRequired();
    notifyListeners();
  }

  void consumeOnboardingLanding() {
    if (!pendingOnboardingLanding) return;
    pendingOnboardingLanding = false;
    notifyListeners();
  }

  /// Saves the manager's plan choice; app unlocks when platform admin activates access.
  Future<void> confirmSubscriptionPlan({required String plan}) async {
    final clean = plan.trim().toLowerCase();
    if (clean != 'monthly' && clean != 'annual') {
      throw Exception('Invalid subscription plan.');
    }
    selectedSubscriptionPlan = clean;
    await markOnboardingPaymentRequired();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_selectedPlanKey, clean);
    if (cloudConfig.hasDeviceToken && cloudConfig.hasValidBaseUrl) {
      try {
        cloudApiService.configure(
          cloudConfig: cloudConfig,
          serverConfig: serverConfig,
        );
        await cloudApiService.registerOnboardingPlan(plan: clean);
      } catch (error) {
        debugPrint('[QB-ONBOARD] plan register failed: $error');
      }
    }
    notifyListeners();
  }

  Future<void> saveLocalSetup({
    required String restaurantName,
    required int tableCount,
  }) async {
    final cleanRestaurantName = restaurantName.trim();
    final cleanOutletName = cleanRestaurantName;
    final cleanTableCount = tableCount.clamp(1, 200);
    if (phoneSignupToken != null && phoneSignupToken!.isNotEmpty) {
      final ok = await completeManagerPhoneSignup(
        restaurantName: cleanRestaurantName,
        outletName: cleanOutletName,
        tableCount: cleanTableCount,
      );
      if (!ok) {
        throw Exception(lastError ?? 'Could not create restaurant.');
      }
      return;
    }
    serverConfig = serverConfig.copyWith(
      restaurantName: cleanRestaurantName,
      outletName: cleanOutletName,
      tableCount: cleanTableCount,
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
    throw Exception(
      'Online payment is not available yet. Choose your plan and wait for activation, '
      'or ask support to enable your account from the admin panel.',
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
    final loadedOrders = await database.getOrders(limit: kOrdersInitialPage);
    orders = loadedOrders;
    _hasMoreOrders = loadedOrders.length >= kOrdersInitialPage;
    syncEvents = await database.getSyncEvents(statuses: null, limit: 100);
    inventoryItems = await database.getInventoryItems();
    inventoryTodaySpend = await database.getInventoryPurchaseTotalForDate(
      DateTime.now(),
    );
    notifications = await database.getNotifications();
    notifyListeners();
  }

  /// Append the next page of older orders to [orders] for scroll-to-load-more.
  /// Idempotent while a load is in flight or after the tail has been reached.
  Future<void> loadMoreOrders() async {
    if (!_hasMoreOrders || _loadingMoreOrders) return;
    _loadingMoreOrders = true;
    notifyListeners();
    try {
      final more = await database.getOrders(
        limit: kOrdersPageSize,
        offset: orders.length,
      );
      if (more.isEmpty) {
        _hasMoreOrders = false;
      } else {
        orders = [...orders, ...more];
        _hasMoreOrders = more.length >= kOrdersPageSize;
        // Treat the appended ids as already known so a later sync diff does
        // not retroactively fire "new order" alerts for historical rows.
        _knownOrderIds.addAll(more.map((o) => o.id));
      }
    } finally {
      _loadingMoreOrders = false;
      notifyListeners();
    }
  }

  bool get hasMoreOrders => _hasMoreOrders;
  bool get loadingMoreOrders => _loadingMoreOrders;

  /// Reset every per-restaurant alert-dedupe set. Called on wipe/logout so a
  /// fresh tenant does not inherit notification-suppression state from the
  /// previous one.
  void _clearOrderAlertTracking() {
    _knownOrderIds.clear();
    _alertedPendingOrderIds.clear();
    _alertedAcceptedOrderIds.clear();
    _alertedPrintOrderIds.clear();
    _autoPrintGiveUpOrderIds.clear();
    _alertedPrintFailureReasons.clear();
  }

  // Diagnostics — surfaced by the hidden dev panel in SettingsScreen.
  int get diagOrdersInMemory => orders.length;
  int get diagMenuInMemory => menuItems.length;
  int get diagInventoryInMemory => inventoryItems.length;
  int get diagNotificationsInMemory => notifications.length;
  int get diagAlertSetSize =>
      _knownOrderIds.length +
      _alertedPendingOrderIds.length +
      _alertedAcceptedOrderIds.length +
      _alertedPrintOrderIds.length +
      _autoPrintGiveUpOrderIds.length +
      _alertedPrintFailureReasons.length;
  int get diagSubscriptionCount => _subscriptions.length;

  Future<void> refreshInventory() async {
    inventoryItems = await database.getInventoryItems();
    inventoryTodaySpend = await database.getInventoryPurchaseTotalForDate(
      DateTime.now(),
    );
    notifyListeners();
  }

  Future<void> refreshDashboardSummary() async {
    if (!isCloudReady) {
      dashboardSummaryError = 'Cloud sync not configured.';
      notifyListeners();
      return;
    }
    dashboardSummaryLoading = true;
    dashboardSummaryError = null;
    notifyListeners();
    try {
      dashboardSummary = await cloudApiService.fetchDashboardSummary();
    } on CloudApiException catch (error) {
      dashboardSummaryError = error.message;
    } catch (error) {
      dashboardSummaryError = error.toString();
    } finally {
      dashboardSummaryLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshInventorySummary() async {
    if (!isCloudReady) {
      inventorySummaryError = 'Cloud sync not configured.';
      notifyListeners();
      return;
    }
    inventorySummaryLoading = true;
    inventorySummaryError = null;
    notifyListeners();
    try {
      inventorySummary = await cloudApiService.fetchInventorySummary();
    } on CloudApiException catch (error) {
      inventorySummaryError = error.message;
    } catch (error) {
      inventorySummaryError = error.toString();
    } finally {
      inventorySummaryLoading = false;
      notifyListeners();
    }
  }

  Future<DailyReport> fetchDailyReport({DateTime? date}) {
    if (!isCloudReady) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.fetchInventoryDailyReport(date: date);
  }

  Future<ReceiptScanResult> scanInventoryReceipt(
    List<MenuScanPageUpload> pages,
  ) {
    if (!isCloudReady) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.scanInventoryReceipt(pages);
  }

  void _scheduleDatabaseChanged() {
    _databaseChangeDebounce?.cancel();
    _databaseChangeDebounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(_handleDatabaseChanged()),
    );
  }

  /// Mark existing orders as already alerted so a fresh install/sync does not
  /// replay notifications for historical rows.
  void _seedOrderAlertState() {
    _alertedPendingOrderIds.clear();
    _alertedAcceptedOrderIds.clear();
    for (final order in orders) {
      final status = order.status.adminStatus;
      if (status == OrderStatus.pending) {
        _alertedPendingOrderIds.add(order.id);
      }
      if (status == OrderStatus.accepted || status == OrderStatus.served) {
        _alertedAcceptedOrderIds.add(order.id);
      }
      if (printerService.hasPrintedOrder(order.id)) {
        _alertedPrintOrderIds.add(order.id);
      }
    }
  }

  Future<void> _handleDatabaseChanged() async {
    if (_handlingDatabaseChange) {
      _databaseChangePending = true;
      return;
    }
    _handlingDatabaseChange = true;
    try {
      do {
        _databaseChangePending = false;
        final previousOrderIds = Set<String>.from(_knownOrderIds);
        final previousStatusById = <String, OrderStatus>{
          for (final order in orders) order.id: order.status.adminStatus,
        };
        await reloadData();
        _knownOrderIds
          ..clear()
          ..addAll(orders.map((order) => order.id));
        await _processOrderAlerts(
          previousOrderIds: previousOrderIds,
          previousStatusById: previousStatusById,
        );
      } while (_databaseChangePending);
    } finally {
      _handlingDatabaseChange = false;
    }
  }

  Future<bool> saveSettings({
    required String restaurantName,
    required String cloudApiUrl,
    required String restaurantId,
    required String outletId,
    required bool cloudSyncEnabled,
    required int autoSyncIntervalSeconds,
  }) async {
    return _runBusy(() async {
      final cleanRestaurantName = restaurantName.trim();
      serverConfig = serverConfig.copyWith(
        restaurantName: cleanRestaurantName,
        outletName: cleanRestaurantName,
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

  Future<bool> updatePublicMenuUrl(String publicSlug) async {
    return _runBusy(() async {
      final requestedSlug = _normalizePublicSlug(publicSlug);
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      final data = await cloudApiService.updatePublicUrl(
        publicSlug: requestedSlug,
      );
      final cleanSlug = _normalizePublicSlug(
        data['publicSlug']?.toString().trim() ?? requestedSlug,
      );
      serverConfig = serverConfig.copyWith(publicSlug: cleanSlug);
      await _persistSettings();
    });
  }

  Future<void> loadFacebookChatbotConfig() async {
    if (!isManager || !cloudConfig.canSync) return;
    facebookChatbotLoading = true;
    facebookChatbotError = null;
    notifyListeners();
    try {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      facebookChatbotConfig = await cloudApiService
          .fetchFacebookChatbotConfig();
    } catch (error) {
      facebookChatbotError = _userVisibleError(error);
    } finally {
      facebookChatbotLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveFacebookChatbotConfig({
    required String pageAccessToken,
    required bool isEnabled,
    required bool orderingEnabled,
  }) async {
    if (!isManager) {
      lastError = 'Manager access is required.';
      notifyListeners();
      return false;
    }
    if (!cloudConfig.canSync) {
      lastError = 'Cloud sync must be connected before configuring Messenger.';
      notifyListeners();
      return false;
    }
    return _runBusy(() async {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      facebookChatbotConfig = await cloudApiService.updateFacebookChatbotConfig(
        pageAccessToken: pageAccessToken.trim().isEmpty
            ? null
            : pageAccessToken.trim(),
        isEnabled: isEnabled,
        orderingEnabled: orderingEnabled,
      );
      facebookChatbotError = null;
    });
  }

  Future<bool> wipeCurrentRestaurant({required String confirmation}) async {
    final outletId = serverConfig.outletId.trim();
    if (!isManager) {
      lastError = 'Only managers can wipe restaurant data.';
      notifyListeners();
      return false;
    }
    if (!isCloudReady || !cloudConfig.canSync || outletId.isEmpty) {
      lastError = 'Cloud sync must be connected before wiping restaurant data.';
      notifyListeners();
      return false;
    }
    if (confirmation.trim() != outletId) {
      lastError = 'Type the outlet ID exactly to confirm.';
      notifyListeners();
      return false;
    }

    return _runBusy(() async {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      await cloudApiService.wipeCurrentOutlet(confirmation: outletId);
      await database.clearLocalData();
      syncService.resetCloudPullState();
      menuItems = [];
      orders = [];
      notifications = [];
      syncEvents = [];
      inventoryItems = [];
      dashboardSummary = null;
      dashboardSummaryError = null;
      inventorySummary = null;
      inventorySummaryError = null;
      _clearOrderAlertTracking();
      await _prepareNewRestaurantIdentity();
      await _clearWipedRestaurantPrefs();
      unawaited(cloudRealtimeService.disconnect());
    });
  }

  Future<void> saveLocalPublicSlug(String publicSlug) async {
    final cleanSlug = _normalizePublicSlug(publicSlug);
    serverConfig = serverConfig.copyWith(publicSlug: cleanSlug);
    await _persistSettings();
    notifyListeners();
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

  String _normalizeBdPhoneInput(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('880')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.length != 10 || !digits.startsWith('1')) {
      throw Exception('Enter a valid Bangladesh mobile number (01XXXXXXXXX).');
    }
    return '+880$digits';
  }

  Future<void> _ensurePhoneAuthCloudConfigured() async {
    final resolvedBase = CloudDefaults.resolveBaseUrl(cloudConfig.baseUrl);
    final loginCloudConfig = cloudConfig.copyWith(
      baseUrl: resolvedBase,
      enabled: true,
    );
    if (!loginCloudConfig.hasValidBaseUrl) {
      throw Exception('Cloud API URL is not configured.');
    }
    cloudConfig = loginCloudConfig;
    await _persistSettings();
    cloudApiService.configure(
      cloudConfig: loginCloudConfig,
      serverConfig: serverConfig,
    );
  }

  Future<void> refreshCloudCapabilities() async {
    if (!cloudConfig.canConnect) {
      demoManagerLoginEnabled = false;
      phoneOtpMode = 'unconfigured';
      showDevOtpHint = false;
      notifyListeners();
      return;
    }
    try {
      await _ensurePhoneAuthCloudConfigured();
      final health = await cloudApiService.testHealth();
      final data = health['data'] is Map
          ? Map<String, Object?>.from(health['data'] as Map)
          : health;
      demoManagerLoginEnabled = data['demoManagerLoginEnabled'] == true;
      phoneOtpMode = data['phoneOtpMode']?.toString() ?? 'unconfigured';
      showDevOtpHint =
          phoneOtpMode == 'dev_bypass' || phoneOtpMode == 'dev_fallback';
    } catch (_) {
      demoManagerLoginEnabled = false;
      phoneOtpMode = 'unconfigured';
      showDevOtpHint = false;
    }
    notifyListeners();
  }

  Future<bool> loginAsDemoManager() async {
    return _runBusy(() async {
      await _ensurePhoneAuthCloudConfigured();
      final result = await cloudApiService.demoManagerLogin();
      await _finishPhoneAuthenticatedLogin(result);
      await clearOnboardingPaymentRequired();
    });
  }

  Future<bool> sendPhoneOtp(String phoneInput, {String? appSignature}) async {
    return _runBusy(() async {
      final phone = _normalizeBdPhoneInput(phoneInput);
      await _ensurePhoneAuthCloudConfigured();
      final result = await cloudApiService.sendPhoneOtp(
        phone: phone,
        appSignature: appSignature,
      );
      verifiedPhoneDisplay = phone;
      phoneOtpMode = result.phoneOtpMode;
      showDevOtpHint =
          !result.smsSent &&
          (result.phoneOtpMode == 'dev_fallback' ||
              result.phoneOtpMode == 'dev_bypass');
      if (result.devOtpCode != null && result.devOtpCode!.isNotEmpty) {
        devOtpCodeHint = result.devOtpCode!;
      }
      notifyListeners();
    });
  }

  Future<String?> verifyPhoneOtp({
    required String phoneInput,
    required String code,
  }) async {
    String? nextStep;
    final ok = await _runBusy(() async {
      final phone = _normalizeBdPhoneInput(phoneInput);
      await _ensurePhoneAuthCloudConfigured();
      final result = await cloudApiService.verifyPhoneOtp(
        phone: phone,
        code: code,
      );
      verifiedPhoneDisplay = result.phone ?? phone;
      pendingStaffInvite = null;
      phoneSignupToken = null;

      if (result.status == 'authenticated' && result.login != null) {
        await _finishPhoneAuthenticatedLogin(result.login!);
        nextStep = 'authenticated';
        return;
      }
      if (result.status == 'needs_restaurant_setup') {
        phoneSignupToken = result.signupToken;
        if (phoneSignupToken == null || phoneSignupToken!.isEmpty) {
          throw Exception('Signup session expired. Request a new code.');
        }
        await _prepareNewRestaurantIdentity();
        serverConfig = serverConfig.copyWith(
          restaurantName: '',
          outletName: '',
        );
        await completeIntro();
        nextStep = 'needs_restaurant_setup';
        return;
      }
      if (result.status == 'pending_staff_invite') {
        final token = result.signupToken;
        final inviteId = result.inviteId;
        if (token == null ||
            token.isEmpty ||
            inviteId == null ||
            inviteId.isEmpty) {
          throw Exception('Invite session expired. Request a new code.');
        }
        pendingStaffInvite = StaffInvitePending(
          inviteId: inviteId,
          restaurantName: result.restaurantName ?? 'Restaurant',
          outletName: result.outletName ?? 'Outlet',
          signupToken: token,
          phone: verifiedPhoneDisplay ?? phone,
        );
        await completeIntro();
        nextStep = 'pending_staff_invite';
        return;
      }
      throw Exception('Unexpected verification response.');
    });
    if (!ok) {
      throw Exception(lastError ?? 'Verification failed.');
    }
    return nextStep;
  }

  Future<void> _finishPhoneAuthenticatedLogin(AdminLoginResult result) async {
    final wasFreshTenant = serverConfig.outletId != result.outletId;
    _applyAdminLoginResult(result, password: '');
    await _applyServerAppAccess(result.hasAppAccess);
    hasSeenIntro = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_seenIntroKey, true);
    await _persistSettings();
    await _persistAccountAuth();
    await _switchTenantIfNeeded();
    syncService.configure(cloudConfig: cloudConfig, serverConfig: serverConfig);
    unawaited(syncService.syncNow());
    unawaited(syncSubscriptionAccessFromCloud());
    if (result.role.isManager && wasFreshTenant) {
      pendingHeroMediaSetup = true;
      await markOnboardingPaymentRequired();
    } else if (result.role.isManager) {
      await clearOnboardingPaymentRequired();
    }
    notifyListeners();
  }

  Future<bool> completeManagerPhoneSignup({
    required String restaurantName,
    required int tableCount,
    String? outletName,
  }) async {
    return _runBusy(() async {
      final token = phoneSignupToken;
      if (token == null || token.isEmpty) {
        throw Exception(
          'Signup session expired. Sign in again with your phone.',
        );
      }
      await _ensurePhoneAuthCloudConfigured();
      final result = await cloudApiService.completeManagerPhoneSignup(
        signupToken: token,
        restaurantName: restaurantName,
        tableCount: tableCount,
        outletName: outletName,
        serverId: serverConfig.serverId,
        outletId: serverConfig.outletId,
      );
      phoneSignupToken = null;
      await _finishPhoneAuthenticatedLogin(result);
      await markOnboardingPaymentRequired();
    });
  }

  Future<bool> respondToStaffInvite({required bool accept}) async {
    return _runBusy(() async {
      final pending = pendingStaffInvite;
      if (pending == null) {
        throw Exception('No pending staff invite.');
      }
      await _ensurePhoneAuthCloudConfigured();
      final result = await cloudApiService.respondToStaffInvite(
        signupToken: pending.signupToken,
        inviteId: pending.inviteId,
        accept: accept,
      );
      pendingStaffInvite = null;
      if (!accept) {
        isLoggedIn = false;
        notifyListeners();
        return;
      }
      if (result.status != 'authenticated' || result.login == null) {
        throw Exception('Could not complete staff activation.');
      }
      await _finishPhoneAuthenticatedLogin(result.login!);
      await clearOnboardingPaymentRequired();
    });
  }

  void clearPendingStaffInvite() {
    pendingStaffInvite = null;
    notifyListeners();
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
      GoogleAuthPreflightResult? googlePreflight;
      debugPrint(
        '[QB-AUTH] googleLoginOrSignup start role=$role url=$cloudApiUrlOverride',
      );
      googlePreflight = await connectivityService.runGoogleAuthPreflight();
      debugPrint('[QB-AUTH] google preflight: ${googlePreflight.debugSummary}');
      if (!googlePreflight.ok) {
        throw Exception(
          'Google sign-in preflight failed (${googlePreflight.reasonCode}). ${googlePreflight.userMessage}',
        );
      }
      // Always sign the previous Google session out first so the account
      // chooser is shown. Without this, a returning user is silently logged
      // in to the cached account and can never pick a different one for a
      // second restaurant.
      try {
        await _googleSignIn.signOut();
        debugPrint('[QB-AUTH] previous Google session signed out');
      } catch (e) {
        debugPrint('[QB-AUTH] signOut threw (ok on first run): $e');
      }
      try {
        debugPrint('[QB-AUTH] invoking GoogleSignIn.signIn()');
        googleUser = await _googleSignIn.signIn();
        debugPrint(
          '[QB-AUTH] signIn() returned: ${googleUser?.email ?? 'null'}',
        );
      } on PlatformException catch (error) {
        debugPrint(
          '[QB-AUTH] PlatformException code=${error.code} message=${error.message} details=${error.details}',
        );
        // GMS codes: 7=NETWORK_ERROR, 10=DEVELOPER_ERROR (SHA-1/client config),
        // 12500=SIGN_IN_FAILED, 12501=SIGN_IN_CANCELLED, 12502=SIGN_IN_CURRENTLY_IN_PROGRESS.
        final code = error.code;
        final msg = error.message ?? '';
        String friendly;
        if (code == 'network_error' || msg.contains('ApiException: 7')) {
          debugPrint(
            '[QB-AUTH] ApiException:7 diagnostics -> ${googlePreflight.debugSummary}',
          );
          friendly =
              "Couldn't reach Google to complete sign-in. "
              '${googlePreflight.userMessage}';
        } else if (msg.contains('ApiException: 10')) {
          friendly =
              'Google rejected this build. Register an Android OAuth client in Google Cloud with package com.terabyteai.foodmania.posadmin and this build\'s SHA-1, then rebuild.';
        } else if (msg.contains('ApiException: 12501') ||
            code == 'sign_in_canceled') {
          friendly = 'Sign-in cancelled.';
        } else {
          friendly =
              'Google sign-in failed. Details: $code${msg.isEmpty ? '' : ' — $msg'}';
        }
        throw Exception(friendly);
      } catch (error) {
        debugPrint('[QB-AUTH] signIn() unknown error: $error');
        rethrow;
      }
      if (googleUser == null) {
        debugPrint(
          '[QB-AUTH] googleUser is null (user cancelled OR no Android OAuth client registered)',
        );
        throw Exception('Google sign-in was cancelled.');
      }
      debugPrint('[QB-AUTH] requesting authentication tokens…');
      final auth = await googleUser.authentication;
      final idToken = auth.idToken;
      debugPrint(
        '[QB-AUTH] idToken length=${idToken?.length ?? 0} accessTokenPresent=${auth.accessToken != null}',
      );
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google did not return an ID token. Check POS_GOOGLE_WEB_CLIENT_ID and make sure it is a Web OAuth client ID.',
        );
      }
      debugPrint(
        '[QB-AUTH] posting idToken to backend at ${cloudApiUrlOverride ?? cloudConfig.baseUrl}',
      );
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
      AdminLoginResult result;
      var mustCollectRestaurantNameAfterAuth = false;
      // Pass through whatever the caller supplied. If manager login returns
      // account_not_found, retry once in the same Google session with temporary
      // names so we don't force the user to pick the same Google account twice.
      try {
        result = await cloudApiService.googleStartOrLogin(
          idToken: idToken,
          role: role,
          serverId: serverConfig.serverId,
          tableCount: serverConfig.tableCount,
          restaurantName: restaurantName,
          outletName: outletName,
          restaurantId: serverConfig.restaurantId,
          outletId: serverConfig.outletId,
        );
      } catch (error) {
        final fallbackToSignup =
            role.isManager &&
            (restaurantName?.trim().isEmpty ?? true) &&
            _isAccountNotFoundError(error);
        if (!fallbackToSignup) rethrow;
        debugPrint(
          '[QB-AUTH] account_not_found -> auto-signup retry with same Google token',
        );
        result = await cloudApiService.googleStartOrLogin(
          idToken: idToken,
          role: role,
          serverId: serverConfig.serverId,
          tableCount: serverConfig.tableCount,
          restaurantName: 'My Restaurant',
          outletName: 'My Restaurant',
          restaurantId: serverConfig.restaurantId,
          outletId: serverConfig.outletId,
        );
        mustCollectRestaurantNameAfterAuth = true;
      }
      final wasFreshTenant =
          role.isManager && serverConfig.outletId != result.outletId;
      _applyAdminLoginResult(result, password: '');
      await _applyServerAppAccess(result.hasAppAccess);
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
      unawaited(syncSubscriptionAccessFromCloud());
      // Only ask for hero media when this Google sign-in created a brand-new
      // tenant — returning managers should land straight on the dashboard.
      if (wasFreshTenant) {
        pendingHeroMediaSetup = true;
        await markOnboardingPaymentRequired();
      } else {
        await clearOnboardingPaymentRequired();
      }
      if (mustCollectRestaurantNameAfterAuth) {
        await requireRestaurantNamingAfterGoogleSignup();
      }
    });
  }

  /// Staff sign-in without Google — only works when backend sets STAFF_DEV_BYPASS_SECRET.
  /// Enabled in Flutter via debug builds or --dart-define=POS_STAFF_DEV_BYPASS=true.
  Future<bool> staffDevBypassLogin({
    required String email,
    required String serverId,
    required String bypassSecret,
    String? cloudApiUrlOverride,
  }) async {
    return _runBusy(() async {
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
      final result = await cloudApiService.staffDevBypassLogin(
        email: email,
        serverId: serverId,
        bypassSecret: bypassSecret,
      );
      _applyAdminLoginResult(result, password: '');
      await _applyServerAppAccess(result.hasAppAccess);
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
      unawaited(syncSubscriptionAccessFromCloud());
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
    await _applyServerAppAccess(result.hasAppAccess);
    await _persistSettings();
    await _persistAccountAuth();
    await _switchTenantIfNeeded();
    syncService.configure(cloudConfig: cloudConfig, serverConfig: serverConfig);
    unawaited(syncService.syncNow());
    unawaited(syncSubscriptionAccessFromCloud());
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

  Future<void> _clearWipedRestaurantPrefs() async {
    isLoggedIn = false;
    hasSeenIntro = false;
    needsOnboardingPayment = false;
    pendingOnboardingLanding = false;
    pendingHeroMediaSetup = false;
    bkashPaymentVerified = false;
    subscriptionState = 'none';
    trialEndsAt = null;
    selectedSubscriptionPlan = '';
    lastBkashPaymentId = null;
    lastBkashTransactionId = null;
    accountId = '';
    accountEmail = '';
    accountUsername = '';
    accountDisplayName = '';
    accountRole = AccountRole.manager;
    _accountPassword = '';
    phoneSignupToken = null;
    verifiedPhoneDisplay = null;
    pendingStaffInvite = null;
    serverConfig = serverConfig.copyWith(
      restaurantName: '',
      outletName: '',
      publicSlug: '',
      tableCount: 10,
    );
    cloudConfig = cloudConfig.copyWith(deviceToken: '');

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_accountLoggedInKey, false);
    await preferences.remove(_seenIntroKey);
    await preferences.remove(_restaurantNameKey);
    await preferences.remove(_outletNameKey);
    await preferences.remove(_publicSlugKey);
    await preferences.remove(_restaurantIdKey);
    await preferences.remove(_outletIdKey);
    await preferences.remove(_deviceTokenKey);
    await preferences.remove(_accountIdKey);
    await preferences.remove(_accountEmailKey);
    await preferences.remove(_accountUsernameKey);
    await preferences.remove(_accountDisplayNameKey);
    await preferences.remove(_accountRoleKey);
    await preferences.remove(_accountPasswordKey);
    await preferences.remove(_selectedPlanKey);
    await preferences.remove(_subscriptionStateKey);
    await preferences.remove(_trialEndsAtKey);
    await preferences.remove(_bkashPaymentVerifiedKey);
    await preferences.remove(_bkashPaymentIdKey);
    await preferences.remove(_bkashTransactionIdKey);
    await preferences.remove(_needsOnboardingPaymentKey);
    await preferences.setInt(_tableCountKey, 10);
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

  void _handleRemoteSyncEvent(Map<String, Object?> event) {
    final type = event['type']?.toString() ?? '';
    final data = event['data'];
    if (type == 'app_update_disabled') {
      pendingAppUpdate = null;
      appUpdateError = null;
      appUpdateStatus = '';
      notifyListeners();
      return;
    }
    if (type != 'app_update_available' || data is! Map) return;
    unawaited(
      _considerAppUpdate(
        AppUpdateInfo.fromJson(Map<String, Object?>.from(data)),
      ),
    );
  }

  Future<void> checkForAppUpdate({bool quiet = true}) async {
    if (_checkingForAppUpdate ||
        !isLoggedIn ||
        !cloudConfig.canSync ||
        !cloudConfig.hasDeviceToken ||
        !cloudConfig.hasValidBaseUrl ||
        serverConfig.outletId.trim().isEmpty) {
      return;
    }
    _checkingForAppUpdate = true;
    try {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      final update = await cloudApiService.fetchAppUpdate();
      await _considerAppUpdate(update);
    } catch (error) {
      if (!quiet) rethrow;
      debugPrint('[QB-UPDATE] check failed: $error');
    } finally {
      _checkingForAppUpdate = false;
    }
  }

  Future<void> _considerAppUpdate(AppUpdateInfo update) async {
    final runtime = await appUpdateInstaller.runtimeInfo();
    if (!runtime.supported || !update.isNewerThan(runtime.versionCode)) {
      if (pendingAppUpdate?.versionCode == update.versionCode ||
          !update.enabled) {
        pendingAppUpdate = null;
        notifyListeners();
      }
      return;
    }
    if (!update.required &&
        _dismissedAppUpdateVersionCode == update.versionCode) {
      return;
    }
    if (pendingAppUpdate?.versionCode == update.versionCode) return;
    pendingAppUpdate = update;
    appUpdateError = null;
    appUpdateStatus = '';
    notifyListeners();
  }

  Future<void> dismissAppUpdate(AppUpdateInfo update) async {
    if (update.required) return;
    _dismissedAppUpdateVersionCode = update.versionCode;
    pendingAppUpdate = null;
    appUpdateError = null;
    appUpdateStatus = '';
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _dismissedAppUpdateVersionCodeKey,
      update.versionCode,
    );
    notifyListeners();
  }

  Future<void> startAppUpdate(AppUpdateInfo update) async {
    if (appUpdateBusy) return;
    appUpdateBusy = true;
    appUpdateError = null;
    appUpdateStatus = strings.appUpdatePreparing;
    notifyListeners();
    try {
      final canInstall = await appUpdateInstaller.canRequestPackageInstalls();
      if (!canInstall) {
        _appUpdateWaitingForPermission = update;
        appUpdateStatus = strings.appUpdatePermissionRequired;
        appUpdateBusy = false;
        notifyListeners();
        await appUpdateInstaller.openInstallPermissionSettings();
        return;
      }
      await _downloadAndOpenAppUpdate(update);
    } catch (error) {
      appUpdateError = error.toString().replaceFirst('Exception: ', '');
      appUpdateStatus = '';
      appUpdateBusy = false;
      notifyListeners();
    }
  }

  Future<void> _resumeAppUpdateAfterPermission() async {
    final update = _appUpdateWaitingForPermission;
    if (update == null) return;
    final canInstall = await appUpdateInstaller.canRequestPackageInstalls();
    if (!canInstall) {
      appUpdateError = strings.appUpdatePermissionStillNeeded;
      appUpdateStatus = '';
      notifyListeners();
      return;
    }
    _appUpdateWaitingForPermission = null;
    await startAppUpdate(update);
  }

  Future<void> _downloadAndOpenAppUpdate(AppUpdateInfo update) async {
    appUpdateStatus = strings.appUpdateDownloading;
    notifyListeners();
    final path = await appUpdateInstaller.downloadApk(update);
    appUpdateStatus = strings.appUpdateOpeningInstaller;
    notifyListeners();
    await appUpdateInstaller.installApk(path);
    pendingAppUpdate = null;
    appUpdateStatus = '';
    appUpdateBusy = false;
    notifyListeners();
  }

  Future<void> syncSubscriptionAccessFromCloud({bool quiet = true}) async {
    if (!isLoggedIn ||
        !cloudConfig.hasDeviceToken ||
        !cloudConfig.hasValidBaseUrl ||
        serverConfig.outletId.trim().isEmpty) {
      return;
    }
    try {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      final access = await cloudApiService.fetchAppAccess();
      await _applyServerAppAccess(access.hasAppAccess);
    } catch (error) {
      if (!quiet) rethrow;
      debugPrint('[QB-ACCESS] sync failed: $error');
    }
  }

  Future<void> _applyServerAppAccess(bool hasAccess) async {
    if (!hasAccess) return;
    subscriptionState = 'paid';
    needsOnboardingPayment = false;
    pendingOnboardingLanding = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_subscriptionStateKey, 'paid');
    await preferences.setBool(_needsOnboardingPaymentKey, false);
    notifyListeners();
  }

  /// Manual check from the plan screen — surfaces API errors to the user.
  Future<String?> refreshSubscriptionAccessFromCloud() async {
    if (!cloudConfig.hasDeviceToken) {
      return 'Not signed in yet. Wait a moment and try again.';
    }
    if (!cloudConfig.hasValidBaseUrl) {
      return 'Cloud server URL is not set. Check Settings → Cloud sync.';
    }
    if (serverConfig.outletId.trim().isEmpty) {
      return 'Restaurant setup is incomplete. Sign out and sign in again.';
    }
    try {
      await syncSubscriptionAccessFromCloud(quiet: false);
      if (subscriptionState == 'paid') {
        return null;
      }
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      final access = await cloudApiService.fetchAppAccess();
      final status = access.subscriptionStatus?.trim();
      if (status == null || status.isEmpty) {
        return 'Waiting for activation. In platform admin, open Activations and tap '
            'Activate for this restaurant (outlet ${serverConfig.outletId.substring(0, 8)}…).';
      }
      return 'Server subscription status: $status. Ask support to set it to active '
          'for outlet ${serverConfig.outletId.substring(0, 8)}…';
    } catch (error) {
      final message = error.toString().replaceFirst('Exception: ', '');
      if (message.toLowerCase().contains('invalid token')) {
        return 'Session expired. Sign out, sign in with Google again, then tap Check activation status.';
      }
      return message;
    }
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
      publicSlug: result.publicSlug ?? serverConfig.publicSlug,
      tableCount: result.tableCount,
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
    phoneSignupToken = null;
    verifiedPhoneDisplay = null;
    pendingStaffInvite = null;
    pendingAppUpdate = null;
    _appUpdateWaitingForPermission = null;
    appUpdateError = null;
    appUpdateStatus = '';
    _clearOrderAlertTracking();
    // Stop the notification sound if it is mid-playback so the audio buffer
    // is released along with the rest of the per-session state.
    unawaited(_notificationPlayer.stop());
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
    await preferences.remove(_selectedPlanKey);
    selectedSubscriptionPlan = '';
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

  Future<bool> addStaffPhone(String phone, {String? displayName}) async {
    if (!isManager) {
      lastError = 'Only managers can add staff.';
      notifyListeners();
      return false;
    }
    return _runBusy(() async {
      final normalized = _normalizeBdPhoneInput(phone);
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      await cloudApiService.addStaffAccount(
        phone: normalized,
        displayName: displayName,
      );
    });
  }

  Future<bool> removeStaffAccount(String staffId) async {
    if (!isManager) {
      lastError = 'Only managers can remove staff.';
      notifyListeners();
      return false;
    }
    return _runBusy(() async {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      await cloudApiService.updateStaffAccount(
        staffId: staffId,
        isActive: false,
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
    String? nameEn,
    String? nameBn,
    String? descriptionEn,
    String? descriptionBn,
    String? categoryEn,
    String? categoryBn,
    String? imageUrl,
    int? preparationTimeMinutes,
    List<String> tags = const [],
    DateTime? createdAt,
    bool syncAfterSave = true,
  }) async {
    final now = DateTime.now();
    final item = MenuItem(
      id: id ?? _uuid.v4(),
      name: name.trim(),
      nameEn: (nameEn ?? name).trim(),
      nameBn: (nameBn ?? '').trim(),
      description: description.trim(),
      descriptionEn: (descriptionEn ?? description).trim(),
      descriptionBn: (descriptionBn ?? '').trim(),
      category: category.trim().isEmpty ? 'General' : category.trim(),
      categoryEn: (categoryEn ?? category).trim().isEmpty
          ? 'General'
          : (categoryEn ?? category).trim(),
      categoryBn: (categoryBn ?? '').trim(),
      price: price,
      imageUrl: _cleanNullable(imageUrl),
      isAvailable: isAvailable,
      preparationTimeMinutes: preparationTimeMinutes,
      tags: tags,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
    await database.upsertMenuItem(item);
    if (syncAfterSave) {
      await _syncWithFreshTenantToken();
    }
  }

  Future<MenuScanImportResult> scanAndImportMenu(
    List<MenuScanPageUpload> pages,
  ) async {
    if (!isManager) {
      throw Exception('Only managers can scan menus.');
    }
    if (!cloudConfig.canSync) {
      throw Exception('Menu scan needs an online cloud connection.');
    }
    cloudApiService.configure(
      cloudConfig: cloudConfig,
      serverConfig: serverConfig,
    );
    final scanResult = await cloudApiService.scanMenuPages(pages);
    if (kDebugMode) {
      debugPrint(
        '[MENU_SCAN] import start candidates=${scanResult.items.length}',
      );
    }
    final seenKeys = menuItems
        .map((item) => _menuScanDuplicateKey(item.nameEn, item.categoryEn))
        .toSet();
    var created = 0;
    var skipped = 0;

    for (final candidate in scanResult.items) {
      final key = _menuScanDuplicateKey(candidate.nameEn, candidate.categoryEn);
      if (!seenKeys.add(key)) {
        skipped += 1;
        continue;
      }
      final tags = <String>[];
      if (candidate.iconKey.trim().isNotEmpty) {
        tags.add('icon:${candidate.iconKey.trim()}');
      }
      for (final sub in candidate.subItems) {
        tags.add('inc:${sub.nameEn.trim()}');
      }
      for (final addon in candidate.addOns) {
        final priceStr = addon.price == addon.price.roundToDouble()
            ? addon.price.toInt().toString()
            : addon.price.toStringAsFixed(2);
        tags.add('addon:$priceStr:${addon.nameEn.trim()}');
      }
      await saveMenuItem(
        name: candidate.nameEn,
        nameEn: candidate.nameEn,
        nameBn: candidate.nameBn,
        description: candidate.descriptionEn,
        descriptionEn: candidate.descriptionEn,
        descriptionBn: candidate.descriptionBn,
        category: candidate.categoryEn,
        categoryEn: candidate.categoryEn,
        categoryBn: candidate.categoryBn,
        price: candidate.price,
        imageUrl: candidate.imageUrl,
        isAvailable: candidate.isAvailable,
        tags: tags,
        syncAfterSave: false,
      );
      created += 1;
    }
    if (created > 0) {
      await _syncWithFreshTenantToken();
    }
    await reloadData();
    if (kDebugMode) {
      debugPrint(
        '[MENU_SCAN] import complete created=$created skippedDuplicates=$skipped',
      );
    }
    return MenuScanImportResult(
      createdCount: created,
      skippedDuplicateCount: skipped,
      scanResult: scanResult,
    );
  }

  Future<OrderHistoryImportResult> importOrderHistoryCsv({
    required List<int> bytes,
    required String fileName,
  }) async {
    if (!isManager) {
      throw Exception('Only managers can import order history.');
    }
    if (!cloudConfig.canSync) {
      throw Exception('Order history import needs an online cloud connection.');
    }
    cloudApiService.configure(
      cloudConfig: cloudConfig,
      serverConfig: serverConfig,
    );
    final result = await cloudApiService.importOrderHistoryCsv(bytes, fileName);
    await _syncWithFreshTenantToken();
    await reloadData();
    return result;
  }

  String _menuScanDuplicateKey(String name, String category) {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    return '${normalize(name)}|${normalize(category.isEmpty ? 'General' : category)}';
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

  Future<String> uploadOutletHeroVideo(List<int> bytes, String filename) async {
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

  double inventoryTodaySpend = 0;

  Future<void> _pushInventoryItemToCloud(InventoryItem item) async {
    if (!cloudConfig.canSync) return;
    try {
      await cloudApiService.pushInventoryItem(item);
    } catch (_) {}
  }

  Future<void> _pushLatestInventoryAdjustment(String inventoryItemId) async {
    if (!cloudConfig.canSync) return;
    try {
      final rows = await database.getStockAdjustments(
        inventoryItemId,
        limit: 1,
      );
      if (rows.isEmpty) return;
      await cloudApiService.pushInventoryAdjustment(rows.first);
    } catch (_) {}
  }

  Future<void> saveInventoryItem(InventoryItem item) async {
    final normalized = item.copyWith(
      unit: InventoryUnits.normalize(item.unit),
      updatedAt: DateTime.now(),
    );
    await database.upsertInventoryItem(normalized);
    await refreshInventory();
    await _pushInventoryItemToCloud(normalized);
  }

  Future<void> deleteInventoryItem(String id) async {
    await database.deleteInventoryItem(id);
    await refreshInventory();
    if (cloudConfig.canSync) {
      try {
        await cloudApiService.deleteInventoryItemCloud(id);
      } catch (_) {}
    }
  }

  Future<InventoryItem> recordInventoryPurchase({
    required String inventoryItemId,
    required double quantity,
    required double totalCostBdt,
    String note = '',
  }) async {
    if (quantity <= 0) {
      throw Exception('Enter a quantity greater than zero.');
    }
    final updated = await database.adjustStock(
      inventoryItemId: inventoryItemId,
      delta: quantity,
      type: AdjustmentType.restock.value,
      note: note,
      totalCostBdt: totalCostBdt,
    );
    await refreshInventory();
    await _pushLatestInventoryAdjustment(inventoryItemId);
    await _pushInventoryItemToCloud(updated);
    return updated;
  }

  Future<InventoryItem> recordInventoryUsage({
    required String inventoryItemId,
    required double quantity,
    String note = '',
  }) async {
    if (quantity <= 0) {
      throw Exception('Enter a quantity greater than zero.');
    }
    final updated = await database.adjustStock(
      inventoryItemId: inventoryItemId,
      delta: -quantity,
      type: AdjustmentType.usage.value,
      note: note,
    );
    await refreshInventory();
    await _pushLatestInventoryAdjustment(inventoryItemId);
    await _pushInventoryItemToCloud(updated);
    return updated;
  }

  Future<InventoryItem> setInventoryEndOfDayCount({
    required String inventoryItemId,
    required double quantity,
  }) async {
    final updated = await database.setDailyStockCount(
      inventoryItemId: inventoryItemId,
      quantity: quantity,
    );
    await refreshInventory();
    await _pushLatestInventoryAdjustment(inventoryItemId);
    await _pushInventoryItemToCloud(updated);
    return updated;
  }

  Future<double?> yesterdayClosingQuantity(String inventoryItemId) async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return database.getDailyStockQuantity(
      inventoryItemId: inventoryItemId,
      day: yesterday,
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
    OrderServiceType? serviceType,
    int? covers,
    OrderPaymentMethod? paymentMethod,
  }) async {
    final order = await database.createOrder(
      requestedItems: requestedItems,
      customerName: customerName,
      tableNo: tableNo,
      note: note,
      serviceType: serviceType,
      covers: covers,
      paymentMethod: paymentMethod,
      source: OrderSource.manual,
      createdByAccountId: accountId.isEmpty ? null : accountId,
      createdByRole: accountRole.value,
      // All manually-created orders (both manager and staff) go straight to
      // accepted so they are ready to serve immediately.
      initialStatus: OrderStatus.accepted,
    );
    unawaited(syncService.syncNow());
    if (orderPrinterSideEffectsEnabled) {
      unawaited(_notifyPrinterUnavailableForCreatedOrder(order));
    }
    return order;
  }

  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    await database.updateOrderStatus(id, status);
    // Auto-print runs from [_processOrderAlerts] on database change — no second call here.
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
    if (cloudConfig.canSync) {
      try {
        cloudApiService.configure(
          cloudConfig: cloudConfig,
          serverConfig: serverConfig,
        );
        await cloudApiService.registerDevice();
      } catch (error) {
        debugPrint('[QB-TABLES] could not sync table count: $error');
      }
    }
  }

  Future<void> updateCustomerMenuTheme(String slug) async {
    final clean = slug.trim();
    if (clean.isEmpty || serverConfig.customerMenuTheme == clean) return;
    serverConfig = serverConfig.copyWith(customerMenuTheme: clean);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_customerMenuThemeKey, clean);
    if (serverConfig.outletId.trim().isNotEmpty && cloudConfig.canSync) {
      try {
        cloudApiService.configure(
          cloudConfig: cloudConfig,
          serverConfig: serverConfig,
        );
        await cloudApiService.updateOutletMenuTheme(clean);
      } catch (error) {
        debugPrint('[QB-THEME] could not sync menu theme: $error');
      }
    }
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
      language: language,
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
    if (!isManager) return;
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
    if (printerService.hasPrintedOrder(order.id)) {
      return Future<bool>.value(true);
    }
    final existing = _orderPrintFutures[order.id];
    if (existing != null) return existing;

    final future = printerService
        .printOrderTicket(
          order,
          restaurantName: restaurantName,
          outletName: outletName,
          language: language,
        )
        .then((ok) async {
          if (!orderPrinterSideEffectsEnabled) {
            return ok;
          }
          if (!ok) {
            final err = printerState.lastError;
            final fromAuto = _autoPrintInFlight.contains(order.id);
            if (fromAuto && _isInfrastructurePrintError(err)) {
              _autoPrintInfrastructureBlocked ??= err;
              await _notifyPrintInfrastructureOnce(err!);
              _markAcceptedOrdersPrintAlerted();
              return ok;
            }
          }
          if (!_alertedPrintOrderIds.contains(order.id)) {
            _alertedPrintOrderIds.add(order.id);
            final error = printerState.lastError ?? strings.printFailed;
            await addNotification(
              type: ok
                  ? PosNotificationType.printSuccess
                  : PosNotificationType.printFailed,
              title: ok ? strings.ticketSentToPrinter : strings.printFailed,
              body: ok ? strings.ticketPrinted(order.displaySequence) : error,
              orderId: order.id,
              actionTarget: !ok && _isInfrastructurePrintError(error)
                  ? 'settings_printer'
                  : 'orders',
              playSound: !ok,
            );
          }
          if (!ok && _autoPrintInFlight.contains(order.id)) {
            _autoPrintGiveUpOrderIds.add(order.id);
          }
          return ok;
        });
    _orderPrintFutures[order.id] = future;
    return future.whenComplete(() => _orderPrintFutures.remove(order.id));
  }

  Future<bool> printCustomerInvoice(OrderModel order) async {
    final ok = await printerService.printCustomerInvoice(
      order,
      restaurantName: restaurantName,
      outletName: outletName,
      language: language,
    );
    printerState = printerService.state;
    if (ok && order.status.adminStatus == OrderStatus.accepted) {
      await updateOrderStatus(order.id, OrderStatus.served);
    }
    if (orderPrinterSideEffectsEnabled &&
        !_alertedPrintOrderIds.contains('${order.id}:invoice')) {
      _alertedPrintOrderIds.add('${order.id}:invoice');
      final error = printerState.lastError ?? strings.printFailed;
      await addNotification(
        type: ok
            ? PosNotificationType.printSuccess
            : PosNotificationType.printFailed,
        title: ok ? strings.printBillAction : strings.printFailed,
        body: ok ? strings.billPrinted(order.displaySequence) : error,
        orderId: order.id,
        actionTarget: !ok && _isInfrastructurePrintError(error)
            ? 'settings_printer'
            : 'orders',
        playSound: !ok,
      );
    }
    notifyListeners();
    return ok;
  }

  Future<void> addNotification({
    required PosNotificationType type,
    required String title,
    required String body,
    String? orderId,
    String? actionTarget,
    bool playSound = true,
  }) async {
    final isPrinterAlert =
        type == PosNotificationType.printSuccess ||
        type == PosNotificationType.printFailed;
    if (isPrinterAlert && !orderPrinterSideEffectsEnabled) return;

    if (type == PosNotificationType.printFailed) {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      final duplicate = notifications.any(
        (n) =>
            n.type == type &&
            n.title == title &&
            n.body == body &&
            n.orderId == orderId &&
            n.actionTarget == actionTarget &&
            n.createdAt.isAfter(cutoff),
      );
      if (duplicate) {
        notifyListeners();
        return;
      }
    }
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
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final inForeground =
        lifecycle == AppLifecycleState.resumed && isAppForeground;
    final soundOn = playSound && notificationSoundEnabled;

    if (inForeground) {
      // Foreground: in-app toast (see MainShell) + asset sound.
      if (soundOn) unawaited(playNotificationSound(type: type));
    } else {
      // Background / screen off: OS notification + channel sound.
      // Stable id per order+type replaces the previous alert instead of stacking.
      final notificationId = orderId != null
          ? Object.hash(orderId, type.name).abs() & 0x7fffffff
          : notification.id.hashCode & 0x7fffffff;
      unawaited(
        systemNotifications.show(
          id: notificationId,
          title: title,
          body: body,
          payload: actionTarget,
          type: type,
          playSound: soundOn,
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

  Future<void> setVarianceTrackingEnabled(bool value) async {
    if (varianceTrackingEnabled == value) return;
    varianceTrackingEnabled = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_varianceTrackingEnabledKey, value);
    if (value) {
      unawaited(refreshInventorySummary());
    }
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
    await systemNotifications.requestNotificationAccess();
    await systemNotifications.show(
      id: 999001,
      title: strings.testNotificationTitle,
      body: strings.testNotificationBody,
      payload: 'test',
      type: PosNotificationType.pendingOrder,
    );
    if (notificationSoundEnabled) {
      unawaited(playNotificationSound());
    }
  }

  /// Play the hardcoded in-app notification sound for [type].
  /// - [PosNotificationType.pendingOrder] → urgent double-beep
  /// - [PosNotificationType.acceptedOrder] → soft confirmation ding
  /// - Other types → system alert fallback
  Future<void> playNotificationSound({
    PosNotificationType type = PosNotificationType.pendingOrder,
  }) async {
    if (!notificationSoundEnabled) return;
    final assetPath = _assetSoundForType(type);
    try {
      await _notificationPlayer.stop();
      if (assetPath != null) {
        await _notificationPlayer.play(AssetSource(assetPath));
        return;
      }
      // Fallback for types without a dedicated asset (print events, etc.)
      final playedBySystem = await systemNotifications
          .playDefaultNotificationSound();
      if (playedBySystem) return;
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {
      try {
        final playedBySystem = await systemNotifications
            .playDefaultNotificationSound();
        if (playedBySystem) return;
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        await SystemSound.play(SystemSoundType.alert);
      }
    }
  }

  /// Returns the asset path (relative to assets/) for the given type,
  /// or null if no dedicated asset exists for that type.
  String? _assetSoundForType(PosNotificationType type) {
    switch (type) {
      case PosNotificationType.pendingOrder:
        return 'sounds/pending_order.wav';
      case PosNotificationType.acceptedOrder:
        return 'sounds/accepted_order.wav';
      default:
        return null;
    }
  }

  String _localizedNotificationOrderBody(OrderModel order) {
    final itemCount = language == AppLanguage.bn
        ? '${_toBnDigits(order.items.length.toString())} আইটেম'
        : '${order.items.length} items';
    final total = language == AppLanguage.bn
        ? '৳${_toBnDigits(order.total.toStringAsFixed(0))}'
        : '৳${order.total.toStringAsFixed(0)}';
    final sequence = language == AppLanguage.bn
        ? _toBnDigits(order.displaySequence)
        : order.displaySequence;
    return '$sequence · $itemCount · $total';
  }

  static String _toBnDigits(String input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    var output = input;
    for (var i = 0; i < en.length; i++) {
      output = output.replaceAll(en[i], bn[i]);
    }
    return output;
  }

  static bool _isInfrastructurePrintError(String? message) {
    if (message == null || message.trim().isEmpty) return false;
    const known = <String>{
      'Turn on Bluetooth first.',
      'Printer is not connected.',
      'Select a Bluetooth printer first.',
      'Connect a USB printer or select a Bluetooth printer first.',
      'Bluetooth permission is required.',
      'Printer permission is required.',
      'Bluetooth is not ready.',
      'USB printer is not ready.',
    };
    return known.contains(message.trim());
  }

  Future<void> _notifyPrintInfrastructureOnce(String reason) async {
    if (!orderPrinterSideEffectsEnabled) return;
    if (_alertedPrintFailureReasons.contains(reason)) return;
    _alertedPrintFailureReasons.add(reason);
    await addNotification(
      type: PosNotificationType.printFailed,
      title: strings.printFailed,
      body: reason,
      actionTarget: 'settings_printer',
      playSound: true,
    );
  }

  Future<void> _notifyPrinterUnavailableForCreatedOrder(
    OrderModel order,
  ) async {
    if (!orderPrinterSideEffectsEnabled) return;
    final reason = await printerService.preflightBlockReason();
    printerState = printerService.state;
    if (reason == null) {
      notifyListeners();
      return;
    }
    await addNotification(
      type: PosNotificationType.printFailed,
      title: strings.printFailed,
      body: reason,
      orderId: order.id,
      actionTarget: 'settings_printer',
      playSound: true,
    );
  }

  void _markAcceptedOrdersPrintAlerted() {
    for (final order in orders) {
      final status = order.status.adminStatus;
      if (status == OrderStatus.accepted || status == OrderStatus.served) {
        _alertedPrintOrderIds.add(order.id);
        _autoPrintGiveUpOrderIds.add(order.id);
      }
    }
  }

  Future<void> _processOrderAlerts({
    required Set<String> previousOrderIds,
    required Map<String, OrderStatus> previousStatusById,
  }) async {
    final sorted = List<OrderModel>.from(orders)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    for (final order in sorted) {
      final id = order.id;
      final status = order.status.adminStatus;
      final wasKnown = previousOrderIds.contains(id);
      final previousStatus = previousStatusById[id];
      if (order.createdByRole?.trim().toLowerCase() == 'legacy_import') {
        _alertedAcceptedOrderIds.add(id);
        _alertedPrintOrderIds.add(id);
        continue;
      }

      if (status == OrderStatus.pending) {
        final becamePending =
            !wasKnown ||
            (previousStatus != null && previousStatus != OrderStatus.pending);
        if (becamePending && !_alertedPendingOrderIds.contains(id)) {
          _alertedPendingOrderIds.add(id);
          await addNotification(
            type: PosNotificationType.pendingOrder,
            title: strings.isBn ? 'নতুন পেন্ডিং অর্ডার' : 'New pending order',
            body: _localizedNotificationOrderBody(order),
            orderId: id,
            actionTarget: 'pending_orders',
          );
        }
      }

      if (status == OrderStatus.accepted || status == OrderStatus.served) {
        final becameAccepted =
            !wasKnown ||
            previousStatus == OrderStatus.pending ||
            (previousStatus != null &&
                previousStatus != OrderStatus.accepted &&
                previousStatus != OrderStatus.served);
        if (becameAccepted && !_alertedAcceptedOrderIds.contains(id)) {
          _alertedAcceptedOrderIds.add(id);
          await addNotification(
            type: PosNotificationType.acceptedOrder,
            title: strings.isBn ? 'অর্ডার অ্যাকসেপ্ট হয়েছে' : 'Order accepted',
            body: _localizedNotificationOrderBody(order),
            orderId: id,
            actionTarget: 'orders',
          );
        }
      }

      if (orderPrinterSideEffectsEnabled) {
        await _printAcceptedOrderIfNeeded(order);
      }
    }
  }

  Future<void> _printAcceptedOrderIfNeeded(OrderModel order) async {
    if (!orderPrinterSideEffectsEnabled) return;
    // Only the manager device auto-prints. Staff devices forward to manager
    // via cloud sync; the manager app then receives the order and prints.
    if (!isManager) return;
    if (_autoPrintInfrastructureBlocked != null) return;
    final status = order.status.adminStatus;
    final isAccepted =
        status == OrderStatus.accepted || status == OrderStatus.served;
    if (isAccepted &&
        printerState.autoPrintEnabled &&
        !printerState.hasSelectedPrinter) {
      final reason = await printerService.preflightBlockReason();
      printerState = printerService.state;
      if (reason != null) return;
      notifyListeners();
    }
    if (!isAccepted ||
        !printerState.autoPrintEnabled ||
        !printerState.hasSelectedPrinter ||
        printerService.hasPrintedOrder(order.id) ||
        _autoPrintGiveUpOrderIds.contains(order.id) ||
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
    // Common case: no filter — return the underlying list reference so
    // identity stays stable across rebuilds and downstream memoization can
    // skip work when [orders] has not changed.
    if (status == null && source == null) return orders;
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
    _databaseChangeDebounce?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(syncService.dispose());
    unawaited(printerService.dispose());
    unawaited(_notificationPlayer.dispose());
    appUpdateInstaller.close();
    cloudApiService.close();
    unawaited(database.close());
    super.dispose();
  }

  static String _userVisibleError(Object error) {
    var m = error.toString().trim();
    const prefix = 'Exception: ';
    while (m.startsWith(prefix)) {
      m = m.substring(prefix.length).trim();
    }
    return m;
  }

  static String _normalizePublicSlug(String value) {
    final slug = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    return slug.isEmpty ? 'your-restaurant' : slug;
  }

  Future<bool> _runBusy(Future<void> Function() action) async {
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (error) {
      lastError = _userVisibleError(error);
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
    await preferences.setString(_publicSlugKey, serverConfig.publicSlug);
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
    await preferences.setString(
      _customerMenuThemeKey,
      serverConfig.customerMenuTheme,
    );
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
    final cleanRestaurantName = restaurantName.trim();
    final cleanOutletName = outletName.trim().isEmpty
        ? cleanRestaurantName
        : outletName.trim();
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
      restaurantName: cleanRestaurantName,
      outletName: cleanOutletName,
      tableCount: serverConfig.tableCount,
      restaurantId: serverConfig.restaurantId,
      outletId: serverConfig.outletId,
    );
    serverConfig = serverConfig.copyWith(
      serverId: tenant.serverId,
      restaurantId: tenant.restaurantId,
      outletId: tenant.outletId,
      restaurantName: tenant.restaurantName,
      outletName: tenant.outletName,
      tableCount: tenant.tableCount,
    );
    // /tenants/bootstrap returns a token that only carries outlet_id. If the
    // user is already logged in, their existing token also carries account_id
    // (required by manager-only endpoints like /admin/staff). Keep the
    // account-bound token so those calls don't 401.
    final hasAccountToken =
        accountId.trim().isNotEmpty &&
        cloudConfig.deviceToken.trim().isNotEmpty;
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

  bool _isAccountNotFoundError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('account_not_found:') ||
        message.contains(
          'no restaurant account is linked to this google email',
        );
  }

  static final String _seenIntroKey = 'local_pos_seen_intro';
  static final String _restaurantNameKey = 'local_pos_restaurant_name';
  static final String _outletNameKey = 'local_pos_outlet_name';
  static final String _serverIdKey = 'local_pos_server_id';
  static final String _publicSlugKey = 'local_pos_public_slug';
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
  static final String _varianceTrackingEnabledKey =
      'local_pos_variance_tracking_enabled';
  static final String _dismissedAppUpdateVersionCodeKey =
      'local_pos_dismissed_app_update_version_code';
  static final String _tableCountKey = 'local_pos_table_count';
  static final String _customerMenuThemeKey = 'local_pos_customer_menu_theme';
  static final String _subscriptionStateKey = 'local_pos_subscription_state';
  static final String _needsOnboardingPaymentKey =
      'local_pos_needs_onboarding_payment';
  static final String _selectedPlanKey = 'local_pos_selected_subscription_plan';
  static final String _trialEndsAtKey = 'local_pos_trial_ends_at';
  static double minUiScale = 0.78;
  static double maxUiScale = 1.18;
}
