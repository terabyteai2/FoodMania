import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'core/constants/cloud_defaults.dart';
import 'core/constants/payment_defaults.dart';
import 'core/localization/app_strings.dart';
import 'core/utils/bounded_string_set.dart';
import 'models/account_role.dart';
import 'models/admin_blocking_notice.dart';
import 'models/app_update_info.dart';
import 'models/audit_entry.dart';
import 'models/bkash_payment_session.dart';
import 'models/chat_thread.dart';
import 'models/staff_member.dart';
import 'models/daily_report.dart';
import 'models/dashboard_metrics.dart';
import 'models/dashboard_summary.dart';
import 'models/desktop_pos.dart';
import 'models/facebook_chatbot_config.dart';
import 'models/inventory_item.dart';
import 'models/inventory_summary.dart';
import 'models/inventory_supplier.dart';
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
import 'services/background_service.dart';
import 'services/cloud_api_service.dart';
import 'services/cloud_realtime_service.dart';
import 'services/connectivity_service.dart';
import 'services/local_database_service.dart';
import 'services/printer_service.dart';
import 'services/push_notification_service.dart';
import 'services/sync_service.dart';
import 'services/system_notification_service.dart';

class StaffInvitePending {
  const StaffInvitePending({
    required this.inviteId,
    required this.restaurantName,
    required this.outletName,
    required this.signupToken,
    required this.phone,
    this.role,
    this.invitedBy,
  });

  final String inviteId;
  final String restaurantName;
  final String outletName;
  final String signupToken;
  final String phone;
  final String? role;
  final String? invitedBy;
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

/// Hard ceiling on how many orders are held in memory at once. Older orders
/// stay in the local DB and can still be reached via search/reports, but the
/// resident list is capped so long sessions never balloon memory.
const int kOrdersMaxInMemory = 500;

/// Hard cap on the per-restaurant alert-tracking sets so they cannot grow
/// without bound over a long-running app session.
const int kAlertSetCap = 2000;

class _QueuedPosNotification {
  const _QueuedPosNotification({
    required this.type,
    required this.title,
    required this.body,
    this.orderId,
    this.actionTarget,
  });

  final PosNotificationType type;
  final String title;
  final String body;
  final String? orderId;
  final String? actionTarget;
}

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
    PushNotificationService? pushNotificationService,
  }) : database = database ?? LocalDatabaseService(),
       printerService = printerService ?? PrinterService(),
       cloudApiService = cloudApiService ?? CloudApiService(),
       cloudRealtimeService = cloudRealtimeService ?? CloudRealtimeService(),
       appUpdateInstaller = appUpdateInstaller ?? AppUpdateInstallerService(),
       connectivityService = connectivityService ?? ConnectivityService(),
       systemNotifications = systemNotifications ?? SystemNotificationService(),
       pushNotificationService =
           pushNotificationService ?? PushNotificationService() {
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
  final PushNotificationService pushNotificationService;
  late final SyncService syncService;

  final Uuid _uuid = Uuid();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final StreamController<Map<String, Object?>> _chatEventController =
      StreamController<Map<String, Object?>>.broadcast();
  final BoundedStringSet _knownOrderIds = BoundedStringSet(cap: kAlertSetCap);
  final Set<String> _autoPrintInFlight = <String>{};

  /// Coalesces concurrent print requests for the same order (auto + manual).
  final Map<String, Future<bool>> _orderPrintFutures = <String, Future<bool>>{};

  Stream<Map<String, Object?>> get chatEvents => _chatEventController.stream;

  @visibleForTesting
  void debugEmitChatEvent(Map<String, Object?> event) {
    _chatEventController.add(event);
  }

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

  /// Persisted set of accepted orders whose KOT failed to auto-print.
  /// Prevents re-print on restart; drives the "KOT not printed" UI indicator.
  final BoundedStringSet _unprintedKotOrderIds = BoundedStringSet(
    cap: kAlertSetCap,
  );

  /// Set when Bluetooth/printer is unavailable — blocks auto-print for all orders.
  String? _autoPrintInfrastructureBlocked;
  String? _lastFcmToken;
  String _lastPushPlatform = 'unknown';
  String? _registeredFcmToken;
  String? _registeredPushOutletId;
  bool _pushNotificationsStarted = false;

  /// One in-app alert per infrastructure error message (e.g. Bluetooth off).
  final BoundedStringSet _alertedPrintFailureReasons = BoundedStringSet(
    cap: kAlertSetCap,
  );
  bool? _lastInternetOnline;
  bool _lastIsSyncing = false;
  bool _coalesceNextOrderAlertBatch = false;

  /// Set to true when the app transitions from background to foreground. While
  /// true, [addNotification] shows an OS notification even though the app is
  /// technically in the resumed state — this lets the user see alerts for
  /// events that arrived via sync while the Dart isolate was frozen.
  bool _justResumedFromBackground = false;

  /// Pending FCM notification tap data — set by the push notification service
  /// when a remote notification is tapped. The shell picks this up on its next
  /// build and navigates accordingly.
  Map<String, String>? pendingFcmNavigation;

  /// Chat conversations already surfaced while in manager-help state.
  final BoundedStringSet _alertedNeedsHelpChatIds = BoundedStringSet(
    cap: kAlertSetCap,
  );
  Timer? _databaseChangeDebounce;
  Timer? _adminBlockingNoticePollTimer;
  bool _handlingDatabaseChange = false;
  bool _databaseChangePending = false;
  AudioPlayer? _notificationPlayer;

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
  /// Set by [TenantSetupScreen] before tenant provision so [MainShell] can
  /// navigate to [MenuScanScreen] immediately after mount.
  bool pendingOnboardingMenuScan = false;
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
  String? lastError;
  String phoneOtpMode = 'unconfigured';
  bool showDevOtpHint = false;
  String devOtpCodeHint = '000000';
  bool isLoggedIn = false;
  AccountRole accountRole = AccountRole.manager;
  String accountId = '';
  String accountDisplayName = '';
  bool notificationSoundEnabled = true;
  String notificationSoundPath = '';
  bool _settleAndSaveEnabled = false;

  /// When true, Print Bill on the ongoing orders tab shows the settle & save
  /// dialog (with bKash/Nagad payment options) before completing the order.
  bool get settleAndSaveEnabled => _settleAndSaveEnabled;

  /// Counter (quick-sell) outlet: no tables configured. Drives the quick-sell
  /// Tables grid and the order wizard's skip-table flow.
  bool get isCounterOutlet => serverConfig.tableCount == 0;
  List<MenuItem> menuItems = [];
  Map<String, int> itemPopularity = {};
  List<String> quickSellMenuItemIds = [];
  List<OrderModel> orders = [];
  int? _lastOrdersForIdentityHash;
  String? _lastOrdersForDiagSignature;
  bool _hasMoreOrders = false;
  bool _loadingMoreOrders = false;
  List<PosNotification> notifications = [];
  List<SyncEvent> syncEvents = [];
  List<InventoryItem> inventoryItems = [];
  List<InventorySupplier> inventorySuppliers = [];
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
  bool _checkingAdminBlockingNotice = false;
  AdminBlockingNotice? adminBlockingNotice;
  bool adminBlockingNoticeRefreshing = false;
  String? adminBlockingNoticeError;

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

  // App is ready to use as soon as the restaurant has a name.
  // Cloud sync is optional and configured separately.
  bool get isTenantReady {
    return serverConfig.restaurantName.trim().isNotEmpty &&
        serverConfig.outletName.trim().isNotEmpty;
  }

  bool get isCloudReady =>
      cloudConfig.hasDeviceToken && cloudConfig.hasValidBaseUrl;
  bool get isManager => accountRole.isManager;

  /// Owner-only — full Analytics, Settings, invite any role.
  bool get isOwner => accountRole.isOwner;

  /// Floor-only role (Tables · Orders · More).
  bool get isWaiter => accountRole.isWaiter;

  /// Settings is owner-only (spec §RBAC).
  bool get canManageSettings => isOwner;

  /// Messenger chat takeover — owner & manager.
  bool get canMessages => isManager;

  /// Stock & inventory — owner only (managers & waiters blocked entirely).
  bool get canManageStock => isOwner;

  /// True when the owner/manager "view as" switch (top-bar avatar dropdown)
  /// should be offered. Stays true while a genuine owner previews the manager
  /// surface so they can switch back, and is never set for a real manager/waiter
  /// — the switch is the only writer and is hidden from them, so they cannot
  /// self-elevate.
  bool _ownerViewPreview = false;
  bool get demoOwnerAccess => isOwner || _ownerViewPreview;

  /// Owner-only demo "view as" switch (top-bar avatar dropdown). In production
  /// the role comes from the authenticated session; here it lets an owner
  /// preview the manager navigation/access. Persists so it survives a relaunch.
  Future<void> setAccountRoleDemo(AccountRole role) async {
    if (accountRole == role) return;
    accountRole = role;
    // Remember when an owner is previewing the manager surface so the switch
    // stays reachable (demoOwnerAccess) to return to the owner view.
    _ownerViewPreview = role.isManager;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_accountRoleKey, role.value);
    await preferences.setBool(_ownerViewPreviewKey, _ownerViewPreview);
    notifyListeners();
  }

  Future<void> setLogoUrl(String? url) async {
    final cleaned = url?.trim().isEmpty == true ? null : url?.trim();
    if (serverConfig.logoUrl == cleaned) return;
    serverConfig = serverConfig.copyWith(logoUrl: cleaned);
    final preferences = await SharedPreferences.getInstance();
    if (cleaned == null) {
      await preferences.remove(_logoUrlKey);
    } else {
      await preferences.setString(_logoUrlKey, cleaned);
    }
    notifyListeners();
  }

  Future<void> setLogoBitmapUrl(String? url) async {
    final cleaned = url?.trim().isEmpty == true ? null : url?.trim();
    debugPrint(
      '[QB-LOGO] setLogoBitmapUrl input="$url" cleaned="$cleaned" current="${serverConfig.logoBitmapUrl}"',
    );
    if (serverConfig.logoBitmapUrl == cleaned) return;
    serverConfig = serverConfig.copyWith(logoBitmapUrl: cleaned);
    final preferences = await SharedPreferences.getInstance();
    if (cleaned == null) {
      await preferences.remove(_logoBitmapUrlKey);
    } else {
      await preferences.setString(_logoBitmapUrlKey, cleaned);
    }
    notifyListeners();
  }

  Future<void> _applyOutletConfigUpdate(Map<String, Object?> settings) async {
    final newBitmapUrl = settings['logoBitmapUrl']?.toString();
    final cleanedBitmap = newBitmapUrl?.trim().isEmpty == true
        ? null
        : newBitmapUrl?.trim();
    if (cleanedBitmap != null && cleanedBitmap != serverConfig.logoBitmapUrl) {
      debugPrint(
        '[QB-LOGO] _applyOutletConfigUpdate logoBitmapUrl="$cleanedBitmap" (was "${serverConfig.logoBitmapUrl}")',
      );
      await setLogoBitmapUrl(cleanedBitmap);
    }
    final newLogoUrl = settings['logoUrl']?.toString();
    final cleanedLogo = newLogoUrl?.trim().isEmpty == true
        ? null
        : newLogoUrl?.trim();
    if (cleanedLogo != null && cleanedLogo != serverConfig.logoUrl) {
      await setLogoUrl(cleanedLogo);
    }
  }

  bool get hasAdminBlockingNotice => adminBlockingNotice?.isBlocking == true;

  /// Order-triggered printer side effects (auto-print + preflight + alerts).
  bool get orderPrinterSideEffectsEnabled => true;

  int get unreadNotificationCount =>
      notifications.where((notification) => !notification.isRead).length;

  Future<void> onResumed() async {
    isAppForeground = true;
    // Stop the foreground WebSocket service started by onPaused if FCM is
    // unavailable — the main isolate's WebSocket + periodic sync take over.
    unawaited(stopBackgroundWebSocket());
    // Resume the auto-sync cadence that onPaused() stopped; the immediate
    // catch-up sync below handles the gap while backgrounded.
    syncService.setForeground(true);
    debugPrint('[QB-NOTIF] lifecycle=resumed');
    // Resuming clears any stale OS notifications that the user has obviously
    // seen by virtue of opening the app.
    unawaited(systemNotifications.cancelAll());
    // Flag so the catch-up sync shows OS notifications for events that were
    // missed while the Dart isolate was frozen in background.
    _justResumedFromBackground = true;
    Future.delayed(const Duration(seconds: 5), () {
      _justResumedFromBackground = false;
    });
    // Re-check notification permission in case the user just granted it from
    // system settings while the app was backgrounded.
    unawaited(systemNotifications.ensurePermissionGranted());
    unawaited(refreshAdminBlockingNotice());
    if (!isCloudReady || !cloudConfig.canSync) return;
    final hasInternet = await connectivityService.hasInternetAccess();
    if (_lastInternetOnline == false && hasInternet) {
      _coalesceNextOrderAlertBatch = true;
    }
    _lastInternetOnline = hasInternet;
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
    // Stop the periodic sync wakeups while backgrounded to save battery; the
    // next onResumed() restarts the cadence and triggers a catch-up sync.
    syncService.setForeground(false);
    debugPrint('[QB-NOTIF] lifecycle=background');
    // Start foreground WebSocket service if FCM is unavailable (e.g. no Google
    // Play Services on Huawei).  This keeps the Dart isolate alive so the
    // WebSocket connection stays open and order events arrive in real time.
    if (!pushNotificationService.isFcmAvailable && cloudConfig.canSync) {
      _startForegroundWebSocket();
    }
  }

  void _startForegroundWebSocket() {
    final baseUrl = cloudConfig.baseUrl.trim();
    if (baseUrl.isEmpty) return;
    final wsUrl = baseUrl.startsWith('https://')
        ? 'wss://${baseUrl.substring(8)}'
        : baseUrl.startsWith('http://')
            ? 'ws://${baseUrl.substring(7)}'
            : baseUrl;
    unawaited(
      startBackgroundWebSocket(
        wsUrl: wsUrl,
        outletId: serverConfig.outletId.trim(),
        deviceToken: cloudConfig.deviceToken.trim(),
      ),
    );
    debugPrint('[QB-BG] started foreground WebSocket service wsUrl=$wsUrl');
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
      quickSellMenuItemIds =
          preferences.getStringList(_quickSellMenuItemIdsKey) ?? const [];
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
        outletPhone: preferences.getString(_outletPhoneKey) ?? '',
        tableCount: preferences.getInt(_tableCountKey) ?? 10,
        customerMenuTheme:
            preferences.getString(_customerMenuThemeKey) ?? 'sultans_hearth',
        deliveryCharge: preferences.getDouble(_deliveryChargeKey) ?? 0,
        logoUrl: preferences.getString(_logoUrlKey),
        logoBitmapUrl: preferences.getString(_logoBitmapUrlKey),
      );
      debugPrint(
        '[QB-LOGO] initialize loaded logoUrl="${serverConfig.logoUrl}" logoBitmapUrl="${serverConfig.logoBitmapUrl}"',
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
      await _loadCachedAdminBlockingNotice(preferences);
      await refreshAdminBlockingNotice();
      _startAdminBlockingNoticePolling();
      accountId = preferences.getString(_accountIdKey) ?? '';
      accountDisplayName = preferences.getString(_accountDisplayNameKey) ?? '';
      accountRole = AccountRole.parse(preferences.getString(_accountRoleKey));
      // Legacy migration: pre-3-role installs stored the tenant creator as
      // 'manager'. On a local-only device (no cloud token) the creator is the
      // owner, so upgrade the cached role. Cloud accounts refresh their real
      // role from the backend on next login.
      if (accountRole == AccountRole.manager &&
          (preferences.getString(_deviceTokenKey) ?? '').isEmpty) {
        accountRole = AccountRole.owner;
      }
      _ownerViewPreview =
          preferences.getBool(_ownerViewPreviewKey) ?? false;
      if (accountRole == AccountRole.owner) {
        _ownerViewPreview = true;
        accountRole = AccountRole.manager;
      }
      _settleAndSaveEnabled =
          preferences.getBool(_settleAndSaveKey) ?? false;
      notificationSoundEnabled =
          preferences.getBool(_notificationSoundEnabledKey) ?? true;
      notificationSoundPath =
          preferences.getString(_notificationSoundPathKey) ?? '';
      _dismissedAppUpdateVersionCode =
          preferences.getInt(_dismissedAppUpdateVersionCodeKey) ?? 0;
      isLoggedIn = preferences.getBool(_accountLoggedInKey) ?? isTenantReady;
      final unprinted = preferences.getStringList(_unprintedKotOrderIdsKey);
      if (unprinted != null) _unprintedKotOrderIds.addAll(unprinted);

      // The printer probe (USB/Bluetooth scan) is the heaviest startup step and
      // isn't needed before the first frame — it's deferred to a post-frame
      // callback below so the splash clears sooner. `printerState` keeps its
      // default (disconnected) value until the stateStream subscription
      // delivers the real state once the probe completes.
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
          // The printer stream emits a fresh state on every internal poke
          // (connection probe, busy toggle) — frequently with identical
          // values. Skip the app-wide notify when nothing actually changed.
          if (printerState == state) return;
          printerState = state;
          if (state.connected &&
              !_isInfrastructurePrintError(state.lastError)) {
            _autoPrintInfrastructureBlocked = null;
          }
          notifyListeners();
        }),
      );
      // Deferred printer probe (see note above): runs after the first frame so
      // it never delays startup. The subscription above is already registered,
      // so the post-probe connection state is delivered to the UI.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(printerService.initialize()),
      );
      _subscriptions.add(
        syncService.stateStream.listen((state) {
          if (state.isSyncing && _lastInternetOnline == false) {
            _coalesceNextOrderAlertBatch = true;
          }
          final error = state.lastError?.toLowerCase() ?? '';
          if (error.contains('internet unavailable')) {
            _lastInternetOnline = false;
          }
          final syncFinished = _lastIsSyncing && !state.isSyncing;
          _lastIsSyncing = state.isSyncing;
          final prev = syncState;
          syncState = state;
          // The sync stream also emits on every appended log line; repaint
          // only when a field the UI actually shows changed, not on log churn.
          final visibleChanged =
              prev.isSyncing != state.isSyncing ||
              prev.cloudConnected != state.cloudConnected ||
              prev.pendingCount != state.pendingCount ||
              prev.failedCount != state.failedCount ||
              prev.lastSyncAt != state.lastSyncAt ||
              prev.lastError != state.lastError;
          if (visibleChanged) {
            notifyListeners();
          }
          if (syncFinished) {
            unawaited(_syncChatEscalationNotifications({}));
          }
        }),
      );
      _subscriptions.add(
        connectivityService.onlineStream.listen((online) {
          if (_lastInternetOnline == false && online) {
            _coalesceNextOrderAlertBatch = true;
          }
          _lastInternetOnline = online;
        }),
      );

      // Open the per-tenant database file. Two restaurants on the same phone
      // (different Google accounts) must never see each other's menu, orders,
      // inventory, etc. — using outletId as the file scope keeps them
      // physically separated on disk.
      await database.initialize(tenantKey: serverConfig.outletId);
      // Reclaim old synced sync_events (full JSON payloads kept indefinitely);
      // fire-and-forget so it never delays startup.
      unawaited(database.pruneSyncedEvents());
      _lastInternetOnline = await connectivityService.hasInternetAccess();
      await syncService.initialize(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      unawaited(_startPushNotifications());
      // One-time heal for installs that copied another outlet's SQLite file
      // into this tenant's DB before the isolation fix shipped.
      await _healTenantDataIfNeeded(preferences);
      await reloadData();
      _knownOrderIds
        ..clear()
        ..addAll(orders.map((order) => order.id));
      _seedOrderAlertState();
      if (isCloudReady && cloudConfig.canSync) {
        _coalesceNextOrderAlertBatch = true;
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
      completedOrders: orders.where((order) => order.status.isCompleted).length,
      totalSales: todaysOrders
          .where((order) => !order.status.isRejected)
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
              !order.createdAt.isBefore(startAt) && !order.status.isRejected,
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
    final ends = DateTime.now().add(const Duration(days: 10));
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
    String? managerName,
    required int tableCount,
  }) async {
    final cleanRestaurantName = restaurantName.trim();
    final cleanManagerName = managerName?.trim() ?? '';
    final cleanOutletName = cleanRestaurantName;
    final cleanTableCount = tableCount.clamp(0, 200);
    if (cleanManagerName.isNotEmpty) {
      accountDisplayName = cleanManagerName;
    }
    if (phoneSignupToken != null && phoneSignupToken!.isNotEmpty) {
      final ok = await completeManagerPhoneSignup(
        restaurantName: cleanRestaurantName,
        managerName: cleanManagerName,
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
          managerName: cleanManagerName,
        );
        await startFreeTrial();
        await clearOnboardingPaymentRequired();
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
              : 'Owner');
    final resolvedEmail = (email?.trim().isNotEmpty == true)
        ? email!.trim()
        : 'manager@example.com';
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

  String _ordersDiagSummary(List<OrderModel> rows, {int sampleLimit = 5}) {
    final raw = <String, int>{};
    final admin = <String, int>{};
    for (final order in rows) {
      raw[order.status.name] = (raw[order.status.name] ?? 0) + 1;
      final adminStatus = order.status.adminStatus.name;
      admin[adminStatus] = (admin[adminStatus] ?? 0) + 1;
    }
    String format(Map<String, int> counts) {
      final keys = counts.keys.toList()..sort();
      return '{${keys.map((k) => '$k:${counts[k]}').join(', ')}}';
    }

    final sample = rows
        .take(sampleLimit)
        .map((order) {
          return '${order.id}#${order.sequenceNo}:'
              '${order.status.name}/${order.status.adminStatus.name} '
              '${order.source.name}/${order.serviceType?.name ?? 'none'} '
              '৳${order.total.toStringAsFixed(0)} '
              'c=${order.createdAt.toIso8601String()} '
              'u=${order.updatedAt.toIso8601String()}';
        })
        .join(' | ');
    return 'raw=${format(raw)} admin=${format(admin)} sample=$sample';
  }

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
    // Load a generous slice so open orders (pending/accepted) with low
    // sequence numbers are not cut off by kOrdersInitialPage.  The slice is
    // a single contiguous sort from the DB, so offset-based loadMoreOrders
    // still works correctly.
    final loadedOrders = await database.getOrders(limit: kOrdersMaxInMemory);
    orders = loadedOrders;
    _hasMoreOrders = loadedOrders.length >= kOrdersMaxInMemory;
    {
      final fbOrders = loadedOrders.where((o) => o.source.name == 'facebookMessenger').toList();
      if (fbOrders.isNotEmpty) {
        print(
          '[QB-ALWAYS] reloadData HAS ${fbOrders.length} facebookMessenger order(s): '
          '${fbOrders.map((o) => '${o.id}#${o.sequenceNo}:${o.status.name}').join(' | ')}',
        );
      } else {
        print(
          '[QB-ALWAYS] reloadData ZERO facebookMessenger orders in loaded list '
          '(total=${loadedOrders.length})',
        );
      }
    }
    if (kDebugMode) {
      final open = orders.where((o) => o.status.isOpen).length;
      final pending = orders
          .where((o) => o.status.adminStatus == OrderStatus.pending)
          .length;
      final accepted = orders
          .where((o) => o.status.adminStatus == OrderStatus.accepted)
          .length;
      final completed = orders.where((o) => o.status.isCompleted).length;
      final rejected = orders.where((o) => o.status.isRejected).length;
      debugPrint(
        '[QB-ORDERS-DIAG] reloadData orders=${orders.length} '
        'loaded=${loadedOrders.length} open=$open pending=$pending '
        'acceptedAdmin=$accepted completed=$completed rejected=$rejected '
        'hasMore=$_hasMoreOrders '
        '${_ordersDiagSummary(orders)}',
      );
    }
    syncEvents = await database.getSyncEvents(statuses: null, limit: 100);
    inventoryItems = await database.getInventoryItems();
    inventorySuppliers = await database.getInventorySuppliers();
    inventoryTodaySpend = await database.getInventoryPurchaseTotalForDate(
      DateTime.now(),
    );
    notifications = await database.getNotifications();
    // Kick off popularity fetch in the background — UI renders with local
    // data immediately, then re-sorts when the map arrives.
    _loadPopularity();
    notifyListeners();
  }

  /// Fetch all-time item popularity from the server and cache in [itemPopularity].
  /// Gracefully degrades (empty map, no sort change) when offline or on error.
  Future<void> _loadPopularity() async {
    try {
      itemPopularity = await cloudApiService.fetchMenuPopularity();
      notifyListeners();
    } catch (_) {
      // Stay with current map (empty or stale) — null-safe, no crash.
    }
  }

  /// Append the next page of older orders to [orders] for scroll-to-load-more.
  /// Idempotent while a load is in flight or after the tail has been reached.
  Future<void> loadMoreOrders() async {
    if (!_hasMoreOrders || _loadingMoreOrders) return;
    if (orders.length >= kOrdersMaxInMemory) {
      // Resident list is full; stop paging so memory stays bounded.
      _hasMoreOrders = false;
      notifyListeners();
      return;
    }
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
    _alertedPrintFailureReasons.clear();
  }

  Future<void> _addUnprintedKotOrderId(String id) async {
    if (id.isEmpty) return;
    _unprintedKotOrderIds.add(id);
    await _persistUnprintedKotOrderIds();
  }

  Future<void> _persistUnprintedKotOrderIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _unprintedKotOrderIdsKey,
      _unprintedKotOrderIds.toList(),
    );
  }

  bool needsKotPrint(OrderModel order) =>
      order.status.adminStatus == OrderStatus.accepted &&
      !printerService.hasPrintedOrder(order.id);

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
      _unprintedKotOrderIds.length +
      _alertedPrintFailureReasons.length;
  int get diagSubscriptionCount => _subscriptions.length;

  Future<void> refreshInventory() async {
    inventoryItems = await database.getInventoryItems();
    inventorySuppliers = await database.getInventorySuppliers();
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

  Future<void> refreshInventorySummary({String? start, String? end}) async {
    if (!isCloudReady) {
      inventorySummaryError = 'Cloud sync not configured.';
      notifyListeners();
      return;
    }
    inventorySummaryLoading = true;
    inventorySummaryError = null;
    notifyListeners();
    try {
      inventorySummary = await cloudApiService.fetchInventorySummary(
        start: start,
        end: end,
      );
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

  Future<StockScanResult> scanInventoryStock(
    List<MenuScanPageUpload> pages, {
    StockScanCategory? category,
  }) {
    if (!isCloudReady) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.scanInventoryStock(pages, category: category);
  }

  Future<List<AuditEntry>> fetchAuditEvents({int days = 30}) {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.fetchPosAuditEvents(days: days);
  }

  Future<List<ChatThread>> fetchChats() {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.fetchChats();
  }

  Future<Map<String, Object?>> fetchAnalytics({
    String range = 'today',
    String? start,
    String? end,
    String channel = 'all',
    String daypart = 'all',
  }) {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.fetchAnalytics(
      range: range,
      start: start,
      end: end,
      channel: channel,
      daypart: daypart,
    );
  }

  /// QuicklyServices-style plain analytics (spec Part B).
  Future<Map<String, Object?>> fetchAnalyticsSummary({
    String range = 'today',
    String? start,
    String? end,
    String? service,
    String? paymentMethod,
    String? shiftId,
    String? user,
  }) {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.fetchAnalyticsSummary(
      range: range,
      start: start,
      end: end,
      service: service,
      paymentMethod: paymentMethod,
      shiftId: shiftId,
      user: user,
    );
  }

  Future<Map<String, Object?>> fetchItemAnalytics({
    required String menuItemId,
    String range = 'month',
    String? start,
    String? end,
  }) {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.fetchItemAnalytics(
      menuItemId: menuItemId,
      range: range,
      start: start,
      end: end,
    );
  }

  Future<Map<String, Object?>> fetchPerformanceReport({
    String granularity = 'daily',
    String? category,
    String? start,
    int days = 30,
  }) {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.fetchPerformanceReport(
      granularity: granularity,
      category: category,
      start: start,
      days: days,
    );
  }

  Future<Map<String, Object?>> fetchOrderBuckets({
    String range = 'today',
    String? start,
    String? end,
  }) {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.fetchOrderBuckets(
      range: range,
      start: start,
      end: end,
    );
  }

  Future<Map<String, Object?>> fetchSalesTable({
    String range = 'today',
    String? start,
    String? end,
    String channel = 'all',
  }) {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.fetchSalesTable(
      range: range,
      start: start,
      end: end,
      channel: channel,
    );
  }

  Future<ChatThread> replyToChat(String conversationId, String text) {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.replyToChat(conversationId, text);
  }

  Future<ChatThread> handBackChat(String conversationId) {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.handBackChat(conversationId);
  }

  Future<List<StaffMember>> fetchStaff() {
    if (!isCloudReady || !cloudConfig.canSync) {
      return Future.error(CloudApiException('Cloud sync not configured.'));
    }
    return cloudApiService.fetchStaff();
  }

  Future<void> inviteStaff({
    String? phone,
    String? email,
    String? displayName,
    String role = 'waiter',
  }) async {
    if (!isCloudReady || !cloudConfig.canSync) {
      throw CloudApiException('Cloud sync not configured.');
    }
    await cloudApiService.addStaffAccount(
      phone: phone,
      email: email,
      displayName: displayName,
      role: role,
    );
  }

  Future<void> setStaffActive(String staffId, bool isActive) async {
    if (!isCloudReady || !cloudConfig.canSync) {
      throw CloudApiException('Cloud sync not configured.');
    }
    await cloudApiService.updateStaffAccount(
      staffId: staffId,
      isActive: isActive,
    );
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
      if (status == OrderStatus.accepted || status == OrderStatus.completed) {
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
    print('[QB-ALWAYS] dbChanged fired (preOrders=${orders.length})');
    try {
      do {
        _databaseChangePending = false;
        final previousOrderIds = Set<String>.from(_knownOrderIds);
        final previousStatusById = <String, OrderStatus>{
          for (final order in orders) order.id: order.status.adminStatus,
        };
        await reloadData();
        if (kDebugMode) {
          final added = orders
              .map((o) => o.id)
              .where((id) => !previousOrderIds.contains(id))
              .toList();
          final removed = previousOrderIds
              .where((id) => orders.every((o) => o.id != id))
              .toList();
          final statusChanges = <String>[];
          for (final order in orders) {
            final previous = previousStatusById[order.id];
            final next = order.status.adminStatus;
            if (previous != null && previous != next) {
              statusChanges.add('${order.id}:${previous.name}->${next.name}');
            }
          }
          debugPrint(
            '[QB-ORDERS-DIAG] dbChanged prev=${previousOrderIds.length} '
            'now=${orders.length} added=$added removed=$removed '
            'statusChanges=$statusChanges notifyListenersAlreadyFired=true '
            '${_ordersDiagSummary(orders)}',
          );
        }
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

  /// Updates the restaurant's display name and/or its customer-facing contact
  /// phone (distinct from the account holder's own phone). Either argument can
  /// be omitted to leave that field untouched.
  Future<bool> updateRestaurantProfile({
    String? restaurantName,
    String? phone,
  }) async {
    return _runBusy(() async {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      final data = await cloudApiService.updateOutletProfile(
        restaurantName: restaurantName,
        phone: phone,
      );
      serverConfig = serverConfig.copyWith(
        restaurantName:
            data['restaurantName']?.toString().trim().isNotEmpty == true
            ? data['restaurantName'].toString().trim()
            : serverConfig.restaurantName,
        outletPhone:
            data['outletPhone']?.toString() ?? serverConfig.outletPhone,
      );
      await _persistSettings();
    });
  }

  /// Self-edit of the account holder's own display name (shown in More/Settings
  /// as "Name"). Distinct from `updateRestaurantProfile`'s restaurant name.
  Future<bool> updateAccountDisplayName(String displayName) async {
    return _runBusy(() async {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      final data = await cloudApiService.updateAccountDisplayName(displayName);
      final account = data['account'] is Map
          ? Map<String, Object?>.from(data['account'] as Map)
          : <String, Object?>{};
      accountDisplayName =
          account['displayName']?.toString().trim().isNotEmpty == true
          ? account['displayName'].toString().trim()
          : displayName.trim();
      await _persistAccountAuth();
    });
  }

  Future<void> loadFacebookChatbotConfig() async {
    if (!cloudConfig.canSync) return;
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

  Future<FacebookChatbotOAuthStart?> startFacebookChatbotOAuth() async {
    if (!cloudConfig.canSync) {
      lastError = 'Cloud sync must be connected before configuring Messenger.';
      notifyListeners();
      return null;
    }
    try {
      facebookChatbotLoading = true;
      facebookChatbotError = null;
      notifyListeners();
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      return await cloudApiService.startFacebookChatbotOAuth();
    } catch (error) {
      final message = _userVisibleError(error);
      facebookChatbotError = message;
      lastError = message;
      return null;
    } finally {
      facebookChatbotLoading = false;
      notifyListeners();
    }
  }

  Future<FacebookChatbotOAuthPages?> loadFacebookChatbotOAuthPages(
    String sessionId,
  ) async {
    try {
      facebookChatbotLoading = true;
      facebookChatbotError = null;
      notifyListeners();
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      return await cloudApiService.fetchFacebookChatbotOAuthPages(
        sessionId: sessionId,
      );
    } catch (error) {
      facebookChatbotError = _userVisibleError(error);
      return null;
    } finally {
      facebookChatbotLoading = false;
      notifyListeners();
    }
  }

  Future<bool> completeFacebookChatbotOAuth({
    required String sessionId,
    required String pageId,
  }) async {
    return _runBusy(() async {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      facebookChatbotConfig = await cloudApiService
          .completeFacebookChatbotOAuth(sessionId: sessionId, pageId: pageId);
      facebookChatbotError = null;
    });
  }

  Future<bool> saveFacebookChatbotConfig({
    required String pageAccessToken,
    required bool isEnabled,
    required bool orderingEnabled,
  }) async {
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
      phoneOtpMode = data['phoneOtpMode']?.toString() ?? 'unconfigured';
      showDevOtpHint =
          phoneOtpMode == 'dev_bypass' || phoneOtpMode == 'dev_fallback';
    } catch (_) {
      phoneOtpMode = 'unconfigured';
      showDevOtpHint = false;
    }
    notifyListeners();
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
          role: result.role,
          invitedBy: result.invitedBy,
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
    _applyAdminLoginResult(result);
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
    String? managerName,
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
        managerName: managerName,
        tableCount: tableCount,
        outletName: outletName,
        serverId: serverConfig.serverId,
        outletId: serverConfig.outletId,
      );
      phoneSignupToken = null;
      await _finishPhoneAuthenticatedLogin(result);
      await startFreeTrial();
      await clearOnboardingPaymentRequired();
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

  /// Called by the hero-media step when the manager finishes uploads (or
  /// taps "I'll do this later"). Clears the flag so the parent shell can
  /// finally mount MainShell.
  void completeHeroMediaSetup() {
    if (!pendingHeroMediaSetup) return;
    pendingHeroMediaSetup = false;
    notifyListeners();
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

  void _handleRemoteSyncEvent(Map<String, Object?> event) {
    final type = event['type']?.toString() ?? '';
    final data = event['data'];
    if (type == 'outlet_config_updated' && data is Map) {
      unawaited(_applyOutletConfigUpdate(data.cast<String, Object?>()));
      return;
    }
    if (type == 'chat_updated') {
      _chatEventController.add(event);
      unawaited(_syncChatEscalationNotifications(event));
      return;
    }
    if (type == 'admin_blocking_notice_changed' && data is Map) {
      unawaited(
        _applyAdminBlockingNotice(
          AdminBlockingNotice.fromJson(Map<String, Object?>.from(data)),
        ),
      );
      return;
    }
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

  String? _chatConversationIdFromEvent(Map<String, Object?> event) {
    final data = event['data'];
    if (data is! Map) return null;
    final value =
        data['conversationId'] ??
        data['conversation_id'] ??
        data['chatId'] ??
        data['id'];
    final id = value?.toString().trim() ?? '';
    return id.isEmpty ? null : id;
  }

  Future<void> _syncChatEscalationNotifications(
    Map<String, Object?> event,
  ) async {
    if (!canMessages || !isCloudReady || !cloudConfig.canSync) return;
    final changedConversationId = _chatConversationIdFromEvent(event);

    // Fast path: extract escalation info directly from the WS event payload
    // so the notification fires instantly without waiting on an HTTP fetchChats
    // call that could race with the backend's DB commit.
    if (changedConversationId != null &&
        !_alertedNeedsHelpChatIds.contains(changedConversationId)) {
      final eventData = event['data'];
      if (eventData is Map) {
        final status = (eventData['status'] as String?)?.trim().toLowerCase();
        if (status == 'needs') {
          _alertedNeedsHelpChatIds.add(changedConversationId);
          final name =
              (eventData['name'] as String?)?.trim() ?? 'Messenger customer';
          final reason = (eventData['reason'] as String?)?.trim();
          final lastMsg = (eventData['lastUserMessage'] as String?)?.trim();
          final detail = (reason?.isNotEmpty ?? false)
              ? reason!
              : (lastMsg ?? '');
          final body = detail.isNotEmpty
              ? '$name: $detail'
              : '$name needs help in Messenger.';
          await addNotification(
            type: PosNotificationType.system,
            title: 'Chatbot needs you',
            body: body,
            actionTarget: 'messages',
            orderId: changedConversationId,
          );
        }
      }
    }

    // Fallback: fetch all chats and process (handles cleanup and catches
    // any escalated chats not covered by the fast path, e.g. periodic sync).
    try {
      final chats = await fetchChats();
      final activeNeedsIds = <String>{};
      for (final chat in chats) {
        final chatId = chat.id.trim();
        if (chatId.isEmpty) continue;
        if (chat.needsAttention) {
          activeNeedsIds.add(chatId);
          if (changedConversationId != null &&
              changedConversationId != chatId) {
            continue;
          }
          if (_alertedNeedsHelpChatIds.contains(chatId)) continue;
          _alertedNeedsHelpChatIds.add(chatId);
          await addNotification(
            type: PosNotificationType.system,
            title: 'Chatbot needs you',
            body: _chatEscalationNotificationBody(chat),
            actionTarget: 'messages',
            orderId: chatId,
          );
        }
      }
      final alertedIds = _alertedNeedsHelpChatIds.toList(growable: false);
      for (final id in alertedIds) {
        if (!activeNeedsIds.contains(id)) {
          _alertedNeedsHelpChatIds.remove(id);
        }
      }
    } catch (error) {
      debugPrint('[QB-CHAT] escalation notification sync failed: $error');
    }
  }

  String _chatEscalationNotificationBody(ChatThread chat) {
    final name = chat.name.trim().isNotEmpty
        ? chat.name.trim()
        : 'Messenger customer';
    final detail = (chat.reason ?? '').trim().isNotEmpty
        ? chat.reason!.trim()
        : (chat.lastUserMessage ?? '').trim();
    if (detail.isNotEmpty) return '$name: $detail';
    return '$name needs help in Messenger.';
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

  Future<void> refreshAdminBlockingNotice({bool quiet = true}) async {
    if (_checkingAdminBlockingNotice || !cloudConfig.hasValidBaseUrl) return;
    _checkingAdminBlockingNotice = true;
    adminBlockingNoticeRefreshing = true;
    if (hasAdminBlockingNotice) notifyListeners();
    try {
      cloudApiService.configure(
        cloudConfig: cloudConfig.copyWith(enabled: true),
        serverConfig: serverConfig,
      );
      final notice = await cloudApiService.fetchAdminBlockingNotice();
      await _applyAdminBlockingNotice(notice);
    } catch (error) {
      if (hasAdminBlockingNotice) {
        adminBlockingNoticeError = strings.adminBlockingNoticeRefreshFailed;
        notifyListeners();
      }
      if (!quiet) rethrow;
      debugPrint('[QB-BLOCKING-NOTICE] refresh failed: $error');
    } finally {
      _checkingAdminBlockingNotice = false;
      adminBlockingNoticeRefreshing = false;
      // The refreshing flag is only visible while a blocking notice is shown;
      // otherwise (the common case) the 30s poll repaints nothing.
      if (hasAdminBlockingNotice) notifyListeners();
    }
  }

  Future<void> respondToBlockingNotice(String response) async {
    try {
      await cloudApiService.respondToBlockingNotice(response);
    } catch (e) {
      debugPrint('[QB-BLOCKING-NOTICE] respond failed: $e');
    }
  }

  void _startAdminBlockingNoticePolling() {
    _adminBlockingNoticePollTimer?.cancel();
    if (!cloudConfig.hasValidBaseUrl) return;
    _adminBlockingNoticePollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(refreshAdminBlockingNotice()),
    );
  }

  Future<void> _loadCachedAdminBlockingNotice(
    SharedPreferences preferences,
  ) async {
    final raw = preferences.getString(_adminBlockingNoticeKey);
    if (raw == null || raw.trim().isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await preferences.remove(_adminBlockingNoticeKey);
        return;
      }
      final notice = AdminBlockingNotice.fromJson(
        Map<String, Object?>.from(decoded),
      );
      if (notice.isBlocking) {
        adminBlockingNotice = notice;
      } else {
        await preferences.remove(_adminBlockingNoticeKey);
      }
    } catch (_) {
      await preferences.remove(_adminBlockingNoticeKey);
    }
  }

  Future<void> _applyAdminBlockingNotice(AdminBlockingNotice notice) async {
    // Polled every 30s — bail out (no disk write, no notify) when the notice
    // is unchanged, which is the steady state for nearly every outlet.
    final nextNotice = notice.isBlocking ? notice : null;
    final prevKey = adminBlockingNotice == null
        ? ''
        : jsonEncode(adminBlockingNotice!.toJson());
    final nextKey = nextNotice == null ? '' : jsonEncode(nextNotice.toJson());
    if (prevKey == nextKey && adminBlockingNoticeError == null) return;

    final preferences = await SharedPreferences.getInstance();
    if (nextNotice != null) {
      adminBlockingNotice = nextNotice;
      await preferences.setString(_adminBlockingNoticeKey, nextKey);
    } else {
      adminBlockingNotice = null;
      await preferences.remove(_adminBlockingNoticeKey);
    }
    adminBlockingNoticeError = null;
    notifyListeners();
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

  void _applyAdminLoginResult(AdminLoginResult result) {
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
      outletPhone: result.outletPhone ?? serverConfig.outletPhone,
      tableCount: result.tableCount,
      logoUrl: result.logoUrl,
      logoBitmapUrl: result.logoBitmapUrl,
    );
    debugPrint(
      '[QB-LOGO] _applyAdminLoginResult logoUrl="${result.logoUrl}" logoBitmapUrl="${result.logoBitmapUrl}"',
    );
    cloudConfig = cloudConfig.copyWith(
      baseUrl: resolvedBase,
      enabled: true,
      deviceToken: result.deviceToken,
    );
    accountId = result.accountId;
    accountDisplayName = result.displayName ?? '';
    if (result.role == AccountRole.owner) {
      _ownerViewPreview = true;
      accountRole = AccountRole.manager;
    } else {
      accountRole = result.role;
    }
    isLoggedIn = true;
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
    _registeredFcmToken = null;
    _registeredPushOutletId = null;
    _clearOrderAlertTracking();
    // Stop the notification sound if it is mid-playback so the audio buffer
    // is released along with the rest of the per-session state.
    final notificationPlayer = _notificationPlayer;
    if (notificationPlayer != null) {
      unawaited(notificationPlayer.stop());
    }
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
    // Drop any owner "view as manager" preview so the next session's switch
    // visibility is derived solely from the freshly authenticated role.
    _ownerViewPreview = false;
    await preferences.remove(_ownerViewPreviewKey);
    selectedSubscriptionPlan = '';
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
    int? shortCode,
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
      shortCode: shortCode,
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
      for (final variant in candidate.sizeVariants) {
        final delta = variant.price - candidate.price;
        final deltaStr = delta == delta.roundToDouble()
            ? delta.toInt().toString()
            : delta.toStringAsFixed(2);
        tags.add('option:${variant.nameEn.trim()}:$deltaStr');
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

  /// Outlet-wide favourite toggle. Optimistically updates the in-memory
  /// [menuItems] so the picker re-sorts (favourites first) immediately, then
  /// persists + syncs.
  Future<void> setMenuItemFavorite(String id, bool isFavorite) async {
    final index = menuItems.indexWhere((item) => item.id == id);
    if (index >= 0) {
      menuItems = [...menuItems]
        ..[index] = menuItems[index].copyWith(isFavorite: isFavorite);
      notifyListeners();
    }
    await database.toggleMenuFavorite(id, isFavorite);
    await _syncWithFreshTenantToken();
  }

  /// Assigns (or clears, when [code] is null) the quick-pick short code for a
  /// menu item. Mirrors [setMenuItemFavorite]: optimistic in-memory update,
  /// persist via upsert, then push to cloud.
  Future<void> setMenuItemShortCode(String id, int? code) async {
    final index = menuItems.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final updated = menuItems[index].copyWith(
      shortCode: code,
      clearShortCode: code == null,
      updatedAt: DateTime.now(),
    );
    menuItems = [...menuItems]..[index] = updated;
    notifyListeners();
    await database.upsertMenuItem(updated);
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
    if (!isManager) throw Exception('Only managers can edit inventory items.');
    final normalized = item.copyWith(
      unit: InventoryUnits.normalize(item.unit),
      updatedAt: DateTime.now(),
    );
    await database.upsertInventoryItem(normalized);
    await refreshInventory();
    await _pushInventoryItemToCloud(normalized);
  }

  Future<void> deleteInventoryItem(String id) async {
    if (!isManager) {
      throw Exception('Only managers can delete inventory items.');
    }
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
    String? supplierId,
    String supplierName = '',
    String billRef = '',
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
      supplierId: supplierId,
      supplierName: supplierName,
      billRef: billRef,
      createdByAccountId: accountId.isEmpty ? null : accountId,
      createdByRole: accountRole.value,
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
    String reason = 'kitchen',
  }) async {
    if (quantity <= 0) {
      throw Exception('Enter a quantity greater than zero.');
    }
    final updated = await database.adjustStock(
      inventoryItemId: inventoryItemId,
      delta: -quantity,
      type: AdjustmentType.usage.value,
      note: note,
      reason: reason,
      createdByAccountId: accountId.isEmpty ? null : accountId,
      createdByRole: accountRole.value,
    );
    await refreshInventory();
    await _pushLatestInventoryAdjustment(inventoryItemId);
    await _pushInventoryItemToCloud(updated);
    return updated;
  }

  Future<void> recordInventoryUsageBatch(
    Map<String, double> quantities, {
    required String reason,
    String note = '',
  }) async {
    final rows = <StockAdjustment>[];
    final updatedItems = <InventoryItem>[];
    for (final entry in quantities.entries) {
      if (entry.value <= 0) continue;
      updatedItems.add(
        await database.adjustStock(
          inventoryItemId: entry.key,
          delta: -entry.value,
          type: reason == 'spoiled'
              ? AdjustmentType.waste.value
              : AdjustmentType.usage.value,
          note: note,
          reason: reason,
          createdByAccountId: accountId.isEmpty ? null : accountId,
          createdByRole: accountRole.value,
        ),
      );
      rows.add((await database.getStockAdjustments(entry.key, limit: 1)).first);
    }
    await refreshInventory();
    if (cloudConfig.canSync && rows.isNotEmpty) {
      try {
        await cloudApiService.pushInventoryAdjustments(rows);
        for (final item in updatedItems) {
          await cloudApiService.pushInventoryItem(item);
        }
      } catch (_) {}
    }
  }

  Future<void> saveInventorySupplier(InventorySupplier supplier) async {
    if (!isManager) throw Exception('Only managers can edit suppliers.');
    var saved = supplier;
    if (cloudConfig.canSync) {
      saved = await cloudApiService.saveInventorySupplier(supplier);
    }
    await database.upsertInventorySupplier(saved);
    inventorySuppliers = await database.getInventorySuppliers();
    notifyListeners();
  }

  Future<InventoryItem> setInventoryEndOfDayCount({
    required String inventoryItemId,
    required double quantity,
  }) async {
    final updated = await database.setDailyStockCount(
      inventoryItemId: inventoryItemId,
      quantity: quantity,
      createdByAccountId: accountId.isEmpty ? null : accountId,
      createdByRole: accountRole.value,
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
    String? discountLabel,
    double discountAmount = 0,
  }) async {
    final order = await database.createOrder(
      requestedItems: requestedItems,
      customerName: customerName,
      tableNo: tableNo,
      note: note,
      serviceType: serviceType,
      covers: covers,
      paymentMethod: paymentMethod,
      discountLabel: discountLabel,
      discountAmount: discountAmount,
      deliveryCharge: serviceType == OrderServiceType.delivery
          ? serverConfig.deliveryCharge
          : 0,
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

  Future<OrderModel> createDesktopOrder({
    required List<OrderRequestItem> requestedItems,
    required PosShift shift,
    required DesktopPosSettings settings,
    OrderServiceType? serviceType,
    String? tableNo,
    String? customerName,
    String? note,
    int? covers,
  }) async {
    final current = await database.getCurrentPosShift();
    if (current == null || current.id != shift.id) {
      throw Exception('Open the outlet register shift before creating a sale.');
    }
    final order = await database.createOrder(
      requestedItems: requestedItems,
      customerName: customerName,
      tableNo: tableNo,
      note: note,
      serviceType: serviceType,
      covers: covers,
      source: OrderSource.desktopPos,
      shiftId: shift.id,
      vatRatePercent: settings.vatRatePercent,
      createdByAccountId: accountId.isEmpty ? null : accountId,
      createdByRole: accountRole.value,
      initialStatus: OrderStatus.accepted,
    );
    unawaited(syncService.syncNow());
    return order;
  }

  Future<DesktopPosSettings> loadDesktopPosSettings() {
    return database.getDesktopPosSettings(
      fallbackTableCount: serverConfig.tableCount,
    );
  }

  Future<void> refreshDesktopPosFromCloud() async {
    if (!cloudConfig.canSync) return;
    try {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      final settingsJson = await cloudApiService.pullDesktopPosSettings();
      if (settingsJson != null) {
        await database.applyRemoteDesktopPosSettings(
          DesktopPosSettings.fromJson(
            settingsJson,
            fallbackTableCount: serverConfig.tableCount,
          ),
        );
      }
      final shiftJson = await cloudApiService.pullDesktopCurrentShift();
      if (shiftJson != null) {
        await database.applyRemotePosShift(PosShift.fromJson(shiftJson));
      } else {
        await database.clearRemoteClosedPosShift();
      }
      final reportJson = await cloudApiService.pullDesktopPosReport();
      if (reportJson != null) {
        await database.saveCachedDesktopPosReport(
          PosReportSnapshot.fromJson(reportJson),
        );
      }
    } catch (error) {
      debugPrint('[QB-DESKTOP] POS bootstrap refresh skipped: $error');
    }
  }

  Future<void> saveDesktopPosSettings(DesktopPosSettings settings) async {
    if (!isManager) throw Exception('Only managers can change POS settings.');
    await database.saveDesktopPosSettings(settings);
    await updateTableCount(settings.tableCount);
    unawaited(syncService.syncNow());
  }

  Future<PosShift?> currentDesktopShift() => database.getCurrentPosShift();

  Future<PosShift> openDesktopShift({
    required double openingCash,
    required Map<String, int> denominations,
  }) async {
    final shift = await database.openPosShift(
      openingCash: openingCash,
      denominations: denominations,
      openedByAccountId: accountId,
    );
    unawaited(syncService.syncNow());
    return shift;
  }

  Future<PosShift> closeDesktopShift({
    required PosShift shift,
    required double countedCash,
    required Map<String, int> denominations,
  }) async {
    if (!isManager) throw Exception('Only managers can close a shift.');
    final result = await database.closePosShift(
      shiftId: shift.id,
      countedCash: countedCash,
      denominations: denominations,
      closedByAccountId: accountId,
    );
    unawaited(syncService.syncNow());
    return result;
  }

  Future<OrderModel> sendDesktopKot(OrderModel order, {String? note}) async {
    final unsent = order.items
        .where((item) => item.kotSentAt == null)
        .map((item) => item.id)
        .toList(growable: false);
    if (unsent.isEmpty) return order;
    final updated = await database.markDesktopKotSent(
      orderId: order.id,
      itemIds: unsent,
      note: note,
    );
    unawaited(syncService.syncNow());
    return updated;
  }

  Future<OrderModel> settleDesktopOrder({
    required OrderModel order,
    required PosShift shift,
    required List<PosSettlementLine> settlements,
    required double discountAmount,
    required double serviceChargeRatePercent,
    required double serviceChargeAmount,
    String? discountPresetId,
    String? discountLabel,
  }) async {
    final settled = await database.settleDesktopOrder(
      orderId: order.id,
      shift: shift,
      settlements: settlements,
      discountAmount: discountAmount,
      serviceChargeRatePercent: serviceChargeRatePercent,
      serviceChargeAmount: serviceChargeAmount,
      discountPresetId: discountPresetId,
      discountLabel: discountLabel,
    );
    unawaited(syncService.syncNow());
    return settled;
  }

  Future<PosReportSnapshot> desktopPosReport({int days = 1}) async {
    final local = await database.desktopPosReport(days: days);
    if (!syncState.cloudConnected) return local;
    return await database.getCachedDesktopPosReport() ?? local;
  }

  Future<void> auditDesktopOrder({
    required OrderModel order,
    required String action,
    required String reason,
    double? amount,
    String? paymentMethod,
  }) async {
    if (!isManager) throw Exception('Only managers can perform this action.');
    await database.queueDesktopAudit(
      orderId: order.id,
      action: action,
      reason: reason,
      shiftId: order.shiftId,
      amount: amount,
      paymentMethod: paymentMethod,
    );
    if (action == 'void' && !order.status.isCompleted) {
      await database.updateOrderStatus(order.id, OrderStatus.rejected);
    }
    unawaited(syncService.syncNow());
  }

  Future<void> auditOrderAction({
    required String orderId,
    required String action,
    required String reason,
    String? shiftId,
    double? amount,
    String? paymentMethod,
  }) async {
    if (!isManager) throw Exception('Only managers can perform this action.');
    await database.queueDesktopAudit(
      orderId: orderId,
      action: action,
      reason: reason,
      shiftId: shiftId,
      amount: amount,
      paymentMethod: paymentMethod,
    );
    unawaited(syncService.syncNow());
  }

  Future<void> updateOrderStatus(String id, OrderStatus status) async {
    await database.updateOrderStatus(id, status);
    // Auto-print runs from [_processOrderAlerts] on database change — no second call here.
    unawaited(syncService.syncNow());
  }

  Future<void> updateOrderDetails(
    String id, {
    required OrderServiceType serviceType,
    String? tableNo,
    String? note,
    String? customerName,
    String? deliveryAddress,
    String? mobileNumber,
  }) async {
    await database.updateOrderDetails(
      id,
      serviceType: serviceType,
      tableNo: tableNo,
      note: note,
      customerName: customerName,
      deliveryAddress: deliveryAddress,
      mobileNumber: mobileNumber,
    );
    unawaited(syncService.syncNow());
  }

  Future<void> updateOrderItems(String id, List<OrderRequestItem> items) async {
    await database.updateOrderItems(id, items);
    unawaited(syncService.syncNow());
  }

  Future<void> deleteOrder(String id) async {
    await database.queueDesktopAudit(
      orderId: id,
      action: 'void',
      reason: 'Order deleted',
    );
    await database.updateOrderStatus(id, OrderStatus.rejected);
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

  Future<void> updateQuickSellMenuItemIds(List<String> ids) async {
    final cleaned = <String>[];
    for (final id in ids) {
      final clean = id.trim();
      if (clean.isNotEmpty && !cleaned.contains(clean)) cleaned.add(clean);
      if (cleaned.length >= 12) break;
    }
    if (listEquals(quickSellMenuItemIds, cleaned)) return;
    quickSellMenuItemIds = cleaned;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(_quickSellMenuItemIdsKey, cleaned);
  }

  Future<void> updateTableCount(int count) async {
    final clamped = count.clamp(0, 200);
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
        await cloudApiService.registerDevice(
          fcmToken: _lastFcmToken,
          pushPlatform: _lastPushPlatform,
        );
      } catch (error) {
        debugPrint('[QB-TABLES] could not sync table count: $error');
      }
    }
  }

  Future<void> _startPushNotifications() async {
    if (_pushNotificationsStarted) return;
    _pushNotificationsStarted = true;
    debugPrint('[QB-NOTIF] starting FCM diagnostics');
    await pushNotificationService.initialize(
      systemNotifications: systemNotifications,
      onToken: _registerPushToken,
      onNotificationTap: _handleFcmNotificationTap,
    );
  }

  Future<void> _handleFcmNotificationTap(Map<String, String> data) async {
    pendingFcmNavigation = data;
    notifyListeners();
  }

  Future<void> _registerPushToken(String token, String platform) async {
    _lastFcmToken = token;
    _lastPushPlatform = platform;
    await _retryPushRegistrationIfReady();
  }

  Future<void> _retryPushRegistrationIfReady() async {
    final token =
        (_lastFcmToken ?? pushNotificationService.token)?.trim() ?? '';
    if (token.isEmpty) return;
    final outletId = serverConfig.outletId.trim();
    if (!cloudConfig.canSync || outletId.isEmpty) {
      debugPrint(
        '[QB-NOTIF] FCM token registration deferred '
        'cloudReady=${cloudConfig.canSync} outlet=$outletId',
      );
      return;
    }
    if (_registeredFcmToken == token && _registeredPushOutletId == outletId) {
      return;
    }
    try {
      cloudApiService.configure(
        cloudConfig: cloudConfig,
        serverConfig: serverConfig,
      );
      final response = await cloudApiService.registerDevice(
        fcmToken: token,
        pushPlatform: _lastPushPlatform,
      );
      _registeredFcmToken = token;
      _registeredPushOutletId = outletId;
      debugPrint(
        '[QB-NOTIF] FCM token registered outlet=$outletId '
        'response=$response',
      );
    } catch (error) {
      debugPrint('[QB-NOTIF] FCM token registration failed: $error');
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

  Future<void> updateDeliveryCharge(double value) async {
    final clean = value.clamp(0, 100000).toDouble();
    if (serverConfig.deliveryCharge == clean) return;
    serverConfig = serverConfig.copyWith(deliveryCharge: clean);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_deliveryChargeKey, clean);
    if (serverConfig.outletId.trim().isNotEmpty && cloudConfig.canSync) {
      try {
        cloudApiService.configure(
          cloudConfig: cloudConfig,
          serverConfig: serverConfig,
        );
        await cloudApiService.updateOutletDeliveryCharge(clean);
      } catch (error) {
        debugPrint('[QB-MENU] could not sync delivery charge: $error');
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

  Future<List<String>> listSystemPrinterQueues() {
    return printerService.listSystemPrinterQueues();
  }

  bool get supportsDirectBluetoothPrinting {
    return printerService.supportsDirectBluetoothPrinting;
  }

  Future<void> selectSystemPrinterQueue(
    String queueName, {
    int paperWidthMm = 58,
  }) async {
    await printerService.selectSystemPrinterQueue(
      queueName,
      paperWidthMm: paperWidthMm,
    );
    printerState = printerService.state;
    notifyListeners();
  }

  Future<bool> connectLocalUsbPrinterAuto() async {
    final ok = await printerService.connectLocalUsbPrinterAuto();
    printerState = printerService.state;
    notifyListeners();
    return ok;
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

  Future<bool> testPrinter() async {
    final ok = await printerService.testPrint(
      restaurantName: restaurantName,
      outletName: outletName,
    );
    printerState = printerService.state;
    notifyListeners();
    return ok;
  }

  Future<String> readPrinterDiagnostics() {
    return printerService.readPrinterDiagnostics();
  }

  Future<void> clearPrinterDiagnostics() {
    return printerService.clearPrinterDiagnostics();
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
          orderDetailsUrl: _orderDetailsUrl(order),
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
            await _addUnprintedKotOrderId(order.id);
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
      orderDetailsUrl: _orderDetailsUrl(order),
      serverRole: accountDisplayName.isNotEmpty ? accountDisplayName : null,
    );
    printerState = printerService.state;
    if (ok && order.status.adminStatus == OrderStatus.accepted) {
      await updateOrderStatus(order.id, OrderStatus.completed);
    }
    if (ok) unawaited(playBillCompleteSound());
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
    if (type == PosNotificationType.printFailed) {
      debugPrint('[QB-NOTIF] printer failure notification suppressed');
      return;
    }
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
    final bulkCutoff = DateTime.now().subtract(const Duration(minutes: 2));
    final bulkCount =
        notifications
            .where(
              (n) =>
                  n.type == type &&
                  n.actionTarget == actionTarget &&
                  n.createdAt.isAfter(bulkCutoff),
            )
            .length +
        1;
    final displayTitle = bulkCount > 1
        ? _bulkNotificationTitle(type, bulkCount)
        : title;
    final displayBody = body;
    if (bulkCount > 1) {
      debugPrint(
        '[QB-NOTIF] bulk notification type=${type.name} count=$bulkCount '
        'title=$displayTitle',
      );
    }
    final notification = PosNotification(
      id: _uuid.v4(),
      type: type,
      title: displayTitle,
      body: displayBody,
      orderId: orderId,
      actionTarget: actionTarget,
      createdAt: DateTime.now(),
    );
    await database.upsertNotification(notification);
    notifications = await database.getNotifications();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final inForeground =
        lifecycle == AppLifecycleState.resumed && isAppForeground;
    final showOsNotification =
        // True background: always show OS notification.
        !inForeground ||
        // Just resumed from background: show OS notification for alerts that
        // arrived via the catch-up sync while the Dart isolate was frozen.
        (inForeground && _justResumedFromBackground);
    final soundOn = playSound && notificationSoundEnabled;
    debugPrint(
      '[QB-NOTIF] add type=${type.name} foreground=$inForeground '
      'showOs=$showOsNotification justResumed=$_justResumedFromBackground '
      'sound=$soundOn order=${orderId ?? ''} title=$displayTitle',
    );

    if (showOsNotification) {
      _justResumedFromBackground = false;
      // Background / screen off: OS notification + channel sound.
      // Stable id per order+type replaces the previous alert instead of stacking.
      final notificationId = orderId != null
          ? Object.hash(orderId, type.name).abs() & 0x7fffffff
          : notification.id.hashCode & 0x7fffffff;
      unawaited(
        systemNotifications.show(
          id: notificationId,
          title: displayTitle,
          body: displayBody,
          payload: actionTarget,
          type: type,
          playSound: soundOn,
          actionTarget: actionTarget,
        ),
      );
    } else if (soundOn) {
      // Foreground normal: in-app toast + asset sound (no system notification).
      unawaited(playNotificationSound(type: type));
    }
    notifyListeners();
  }

  String _bulkNotificationTitle(PosNotificationType type, int count) {
    final number = count.toString();
    final orderWord = count == 1 ? 'order' : 'orders';
    switch (type) {
      case PosNotificationType.acceptedOrder:
        return '$number $orderWord accepted';
      case PosNotificationType.pendingOrder:
        return count == 1 ? '$number new order' : '$number new orders';
      default:
        return '$number notifications';
    }
  }

  String? _orderDetailsUrl(OrderModel order) {
    final base = cloudConfig.baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (base.isEmpty || order.id.trim().isEmpty) return null;
    return '$base/customer/orders/${order.id}';
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

  Future<void> setSettleAndSaveEnabled(bool value) async {
    _settleAndSaveEnabled = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_settleAndSaveKey, value);
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
    await _playAsset(_assetSoundForType(type));
  }

  /// Chime for a successfully printed bill (order marked completed).
  Future<void> playBillCompleteSound() async {
    if (!notificationSoundEnabled) return;
    await _playAsset('sounds/bill_printed_order_complete.wav');
  }

  /// Chime for reaching the new-order wizard's success/token screen.
  Future<void> playWizardSuccessSound() async {
    if (!notificationSoundEnabled) return;
    await _playAsset('sounds/order_wizard_created_success.wav');
  }

  /// Plays [assetPath] via the shared notification player, falling back to
  /// the system default notification sound / alert tone on any failure or
  /// when [assetPath] is null (types without a dedicated asset).
  Future<void> _playAsset(String? assetPath) async {
    try {
      final player = _notificationPlayer ??= AudioPlayer();
      await player.stop();
      if (assetPath != null) {
        await player.play(AssetSource(assetPath));
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
        return 'sounds/order_pending_request.wav';
      case PosNotificationType.acceptedOrder:
        return 'sounds/general_notification.wav';
      case PosNotificationType.system:
        return 'sounds/chatbot_needs_you.wav';
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

  Future<void> _markAcceptedOrdersPrintAlerted() async {
    for (final order in orders) {
      final status = order.status.adminStatus;
      if (status == OrderStatus.accepted) {
        _alertedPrintOrderIds.add(order.id);
        await _addUnprintedKotOrderId(order.id);
      }
    }
  }

  Future<void> _processOrderAlerts({
    required Set<String> previousOrderIds,
    required Map<String, OrderStatus> previousStatusById,
  }) async {
    final sorted = List<OrderModel>.from(orders)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final orderNotifications = <_QueuedPosNotification>[];
    final acceptedOrdersToPrint = <OrderModel>[];

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

      final isCurrentUserCreator =
          order.createdByAccountId != null &&
          order.createdByAccountId == accountId;

      if (status == OrderStatus.pending) {
        final becamePending =
            !wasKnown ||
            (previousStatus != null && previousStatus != OrderStatus.pending);
        if (becamePending &&
            !_alertedPendingOrderIds.contains(id) &&
            !isCurrentUserCreator) {
          _alertedPendingOrderIds.add(id);
          orderNotifications.add(
            _QueuedPosNotification(
              type: PosNotificationType.pendingOrder,
              title: strings.isBn ? 'নতুন পেন্ডিং অর্ডার' : 'New pending order',
              body: _localizedNotificationOrderBody(order),
              orderId: id,
              actionTarget: 'pending_orders',
            ),
          );
        }
      }

      final isAcceptedNow = status == OrderStatus.accepted;
      // [_alertedAcceptedOrderIds] is seeded at startup with every order that
      // was already accepted, and is also added-to whenever we fire an
      // "order accepted" alert. So treating membership as "we've already
      // handled this acceptance" gives us a single dedup signal that survives
      // both app restarts (via the seed) and intra-session reloads (via the
      // notification-side add below).
      final alreadyHandled = _alertedAcceptedOrderIds.contains(id);

      if (isAcceptedNow) {
        final becameAccepted =
            !wasKnown ||
            previousStatus == OrderStatus.pending ||
            (previousStatus != null && previousStatus != OrderStatus.accepted);
        if (becameAccepted && !alreadyHandled && !isCurrentUserCreator) {
          _alertedAcceptedOrderIds.add(id);
          orderNotifications.add(
            _QueuedPosNotification(
              type: PosNotificationType.acceptedOrder,
              title: strings.isBn
                  ? 'অর্ডার অ্যাকসেপ্ট হয়েছে'
                  : 'Order accepted',
              body: _localizedNotificationOrderBody(order),
              orderId: id,
              actionTarget: 'orders',
            ),
          );
        }
      }

      // Auto-print only when this acceptance is new — i.e. the order was not
      // in accepted status at startup, and we haven't already fired an
      // alert for this acceptance during this session. That excludes:
      //   - historical orders that were already accepted when the app opened,
      //   - reloads / debounced re-runs of the same accepted order.
      // [printerService.hasPrintedOrder] gives a second-layer dedup inside
      // [_printAcceptedOrderIfNeeded] for the same-tick case.
      if (orderPrinterSideEffectsEnabled && isAcceptedNow && !alreadyHandled) {
        acceptedOrdersToPrint.add(order);
      }
    }

    await _flushOrderAlertNotifications(orderNotifications);
    for (final order in acceptedOrdersToPrint) {
      await _printAcceptedOrderIfNeeded(order);
    }
  }

  Future<void> _flushOrderAlertNotifications(
    List<_QueuedPosNotification> queued,
  ) async {
    if (queued.isEmpty) {
      _coalesceNextOrderAlertBatch = false;
      return;
    }
    final coalesce = _coalesceNextOrderAlertBatch && queued.length > 1;
    _coalesceNextOrderAlertBatch = false;

    if (!coalesce) {
      for (final notification in queued) {
        await addNotification(
          type: notification.type,
          title: notification.title,
          body: notification.body,
          orderId: notification.orderId,
          actionTarget: notification.actionTarget,
        );
      }
      return;
    }

    final now = DateTime.now();
    for (final item in queued) {
      await database.upsertNotification(
        PosNotification(
          id: _uuid.v4(),
          type: item.type,
          title: item.title,
          body: item.body,
          orderId: item.orderId,
          actionTarget: item.actionTarget,
          createdAt: now,
        ),
      );
    }
    notifications = await database.getNotifications();

    final lifecycle = WidgetsBinding.instance.lifecycleState;
    final inForeground =
        lifecycle == AppLifecycleState.resumed && isAppForeground;
    final soundOn = notificationSoundEnabled;
    final title = strings.notificationSummaryTitle(queued.length);
    final body = strings.notificationSummaryBody;
    debugPrint(
      '[QB-NOTIF] coalesced order alerts count=${queued.length} '
      'foreground=$inForeground sound=$soundOn',
    );

    if (inForeground) {
      if (soundOn) {
        unawaited(
          playNotificationSound(type: PosNotificationType.pendingOrder),
        );
      }
    } else {
      unawaited(
        systemNotifications.show(
          id: 991001,
          title: title,
          body: body,
          payload: 'orders',
          type: PosNotificationType.pendingOrder,
          playSound: soundOn,
        ),
      );
    }
    notifyListeners();
  }

  Future<void> _printAcceptedOrderIfNeeded(OrderModel order) async {
    if (!orderPrinterSideEffectsEnabled) return;
    // Only the manager device auto-prints. Staff devices forward to manager
    // via cloud sync; the manager app then receives the order and prints.
    if (!isManager) return;
    if (_autoPrintInfrastructureBlocked != null) {
      await _addUnprintedKotOrderId(order.id);
      return;
    }
    final status = order.status.adminStatus;
    final isAccepted = status == OrderStatus.accepted;
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
        _unprintedKotOrderIds.contains(order.id) ||
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
    if (status == null && source == null) {
      if (kDebugMode) {
        final identity = identityHashCode(orders);
        final signature =
            '$identity/${orders.length}/${orders.map((o) => '${o.id}:${o.status.name}:${o.updatedAt.microsecondsSinceEpoch}').join('|')}';
        if (_lastOrdersForIdentityHash != identity ||
            _lastOrdersForDiagSignature != signature) {
          _lastOrdersForIdentityHash = identity;
          _lastOrdersForDiagSignature = signature;
          debugPrint(
            '[QB-ORDERS-DIAG] controller ordersFor unfiltered '
            'identity=$identity count=${orders.length} '
            '${_ordersDiagSummary(orders)}',
          );
        }
      }
      return orders;
    }
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
    _adminBlockingNoticePollTimer?.cancel();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(syncService.dispose());
    unawaited(printerService.dispose());
    unawaited(pushNotificationService.dispose());
    final notificationPlayer = _notificationPlayer;
    if (notificationPlayer != null) {
      unawaited(notificationPlayer.dispose());
    }
    appUpdateInstaller.close();
    cloudApiService.close();
    unawaited(_chatEventController.close());
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
    await preferences.setString(_outletPhoneKey, serverConfig.outletPhone);
    await preferences.setString(_cloudApiUrlKey, cloudConfig.baseUrl);
    await preferences.setBool(_cloudSyncEnabledKey, cloudConfig.enabled);
    await preferences.setString(_deviceTokenKey, cloudConfig.deviceToken);
    await preferences.setString(_languageKey, language.code);
    await preferences.setString(_themePreferenceKey, themePreference.code);
    await preferences.setInt(
      _autoSyncIntervalKey,
      cloudConfig.autoSyncIntervalSeconds,
    );
    await preferences.setInt(_tableCountKey, serverConfig.tableCount);
    await preferences.setString(
      _customerMenuThemeKey,
      serverConfig.customerMenuTheme,
    );
    await preferences.setDouble(
      _deliveryChargeKey,
      serverConfig.deliveryCharge,
    );
    _startAdminBlockingNoticePolling();
    unawaited(_retryPushRegistrationIfReady());
  }

  Future<void> _persistAccountAuth() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_accountIdKey, accountId);
    await preferences.setString(_accountDisplayNameKey, accountDisplayName);
    await preferences.setString(_accountRoleKey, accountRole.value);
    await preferences.setBool(_accountLoggedInKey, isLoggedIn);
  }

  Future<void> _provisionTenantInternal({
    required String restaurantName,
    required String outletName,
    String? managerName,
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
      managerName: managerName,
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
      logoUrl: tenant.logoUrl,
      logoBitmapUrl: tenant.logoBitmapUrl,
    );
    debugPrint(
      '[QB-LOGO] bootstrap logoUrl="${tenant.logoUrl}" logoBitmapUrl="${tenant.logoBitmapUrl}"',
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

  static final String _seenIntroKey = 'local_pos_seen_intro';
  static final String _restaurantNameKey = 'local_pos_restaurant_name';
  static final String _outletNameKey = 'local_pos_outlet_name';
  static final String _serverIdKey = 'local_pos_server_id';
  static final String _publicSlugKey = 'local_pos_public_slug';
  static final String _outletPhoneKey = 'local_pos_outlet_phone';
  static final String _restaurantIdKey = 'local_pos_restaurant_id';
  static final String _outletIdKey = 'local_pos_outlet_id';
  static final String _cloudApiUrlKey = 'local_pos_cloud_api_url';
  static final String _deviceTokenKey = 'local_pos_device_token';
  static final String _cloudSyncEnabledKey = 'local_pos_cloud_sync_enabled';
  static final String _autoSyncIntervalKey = 'local_pos_auto_sync_interval';
  static final String _quickSellMenuItemIdsKey =
      'local_pos_quick_sell_menu_item_ids';
  static final String _languageKey = 'local_pos_language';
  static final String _languagePreferenceSetKey =
      'local_pos_language_preference_set';
  static final String _themePreferenceKey = 'local_pos_theme_preference';
  static final String _bkashPaymentVerifiedKey =
      'local_pos_bkash_payment_verified';
  static final String _bkashPaymentIdKey = 'local_pos_bkash_payment_id';
  static final String _bkashTransactionIdKey = 'local_pos_bkash_transaction_id';
  static final String _accountIdKey = 'local_pos_account_id';
  static final String _accountDisplayNameKey = 'local_pos_account_display_name';
  static final String _accountRoleKey = 'local_pos_account_role';
  static final String _ownerViewPreviewKey = 'local_pos_owner_view_preview';
  static final String _accountLoggedInKey = 'local_pos_account_logged_in';
  static final String _notificationSoundEnabledKey =
      'local_pos_notification_sound_enabled';
  static final String _notificationSoundPathKey =
      'local_pos_notification_sound_path';
  static final String _dismissedAppUpdateVersionCodeKey =
      'local_pos_dismissed_app_update_version_code';
  static final String _adminBlockingNoticeKey =
      'local_pos_admin_blocking_notice';
  static final String _tableCountKey = 'local_pos_table_count';
  static final String _customerMenuThemeKey = 'local_pos_customer_menu_theme';
  static final String _deliveryChargeKey = 'local_pos_delivery_charge';
  static final String _logoUrlKey = 'local_pos_logo_url';
  static final String _logoBitmapUrlKey = 'local_pos_logo_bitmap_url';
  static final String _subscriptionStateKey = 'local_pos_subscription_state';
  static final String _needsOnboardingPaymentKey =
      'local_pos_needs_onboarding_payment';
  static final String _selectedPlanKey = 'local_pos_selected_subscription_plan';
  static final String _trialEndsAtKey = 'local_pos_trial_ends_at';
  static final String _unprintedKotOrderIdsKey =
      'local_pos_unprinted_kot_order_ids';
  static final String _settleAndSaveKey =
      'local_pos_settle_and_save_enabled';
}
