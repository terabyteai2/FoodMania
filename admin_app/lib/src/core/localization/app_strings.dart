import 'package:flutter/material.dart';

import '../../models/order_source.dart';

enum AppLanguage {
  bn('bn', 'বাংলা'),
  en('en', 'English');

  const AppLanguage(this.code, this.label);

  final String code;
  final String label;

  Locale get locale => Locale(code);

  static AppLanguage parse(String? value, {AppLanguage? fallback}) {
    final normalized = value?.trim().toLowerCase();
    for (final language in AppLanguage.values) {
      if (language.code == normalized || language.name == normalized) {
        return language;
      }
    }
    return fallback ?? AppLanguage.bn;
  }

  static AppLanguage fromLocale(Locale locale) {
    final code = locale.languageCode.toLowerCase();
    if (code == AppLanguage.bn.code) return AppLanguage.bn;
    return AppLanguage.en;
  }
}

class AppStrings {
  AppStrings._(this.language);

  final AppLanguage language;

  static AppStrings of(AppLanguage language) => AppStrings._(language);

  bool get isBn => language == AppLanguage.bn;

  String get appTitle => 'Terafoods';
  String get cloudSuite => isBn ? 'রেস্টুরেন্ট POS' : 'Restaurant POS';
  String get cloudRestaurantSuite => isBn ? 'টেরাফুডস POS' : 'Terafoods POS';

  String get dashboard => isBn ? 'ড্যাশবোর্ড' : 'Dashboard';
  String get home => isBn ? 'হোম' : 'Home';
  String get menu => isBn ? 'মেনু' : 'Menu';
  String get orders => isBn ? 'অর্ডার' : 'Orders';
  String get reports => isBn ? 'রিপোর্ট' : 'Reports';
  String get sync => isBn ? 'সিঙ্ক' : 'Sync';
  String get settings => isBn ? 'সেটিংস' : 'Settings';
  String get save => isBn ? 'সেভ' : 'Save';
  String get cancel => isBn ? 'বাতিল' : 'Cancel';
  String get requiredField => isBn ? 'প্রয়োজনীয়' : 'Required';
  String get connected => isBn ? 'কানেক্টেড' : 'Connected';
  String get connect => isBn ? 'কানেক্ট' : 'Connect';
  String get reconnect => isBn ? 'রীকানেক্ট' : 'Reconnect';
  String get disconnect => isBn ? 'ডিসকানেক্ট' : 'Disconnect';

  String get secureTenant => isBn ? 'সুরক্ষিত টেন্যান্ট' : 'Secure tenant';
  String get tokenVerified => isBn ? 'টোকেন ভেরিফাইড' : 'Token verified';

  String get compact => isBn ? 'কমপ্যাক্ট' : 'Compact';
  String get comfortable => isBn ? 'কমফোর্টেবল' : 'Comfortable';
  String get large => isBn ? 'বড়' : 'Large';

  String get settingsSubtitle => isBn
      ? 'রেস্টুরেন্ট প্রোফাইল, ক্লাউড আইডেন্টিটি ও সিঙ্ক সেটিংস।'
      : 'Restaurant profile, cloud identity, and sync settings.';
  String get languageLabel => isBn ? 'ভাষা' : 'Language';
  String get languageSubtitle =>
      isBn ? 'অ্যাপের ভাষা নির্বাচন করুন।' : 'Choose app display language.';
  String get themeMode => isBn ? 'থিম মোড' : 'Theme mode';
  String get themeModeSubtitle => isBn
      ? 'পুরো অ্যাপ Black, White বা Device mode-এ দেখান।'
      : 'Use Black, White, or Device mode for the whole app.';
  String get blackMode => isBn ? 'Black' : 'Black';
  String get whiteMode => isBn ? 'White' : 'White';
  String get deviceMode => isBn ? 'Device' : 'Device';
  String get appLanguage => isBn ? 'অ্যাপ ভাষা' : 'App language';
  String get bangla => 'বাংলা';
  String get english => 'English';
  String get displaySize => isBn ? 'ডিসপ্লে সাইজ' : 'Display Size';
  String get displaySizeSubtitle => isBn
      ? 'কাউন্টার, ট্যাবলেট বা বড় লেখার জন্য পুরো অ্যাপ ছোট-বড় করুন।'
      : 'Adjust the whole app for compact counters, tablets, or large text comfort.';
  String scaleLabel(String label, int percent) => '$label - $percent%';

  String get restaurantSection => isBn ? 'রেস্টুরেন্ট' : 'Restaurant';
  String get restaurantSubtitle =>
      isBn ? 'এই আউটলেটের পাবলিক পরিচয়।' : 'Public identity for this outlet.';
  String get restaurantName => isBn ? 'রেস্টুরেন্টের নাম' : 'Restaurant name';
  String get outletName => isBn ? 'আউটলেটের নাম' : 'Outlet name';
  String get restaurantId => isBn ? 'রেস্টুরেন্ট ID' : 'Restaurant ID';
  String get outletId => isBn ? 'আউটলেট ID' : 'Outlet ID';
  String get restaurantIdHelper => isBn
      ? 'ক্লাউড থেকে অটো তৈরি হয়।'
      : 'Created automatically by the cloud.';
  String get outletIdHelper => isBn
      ? 'কাস্টমার ওয়েব অ্যাপের সাথে এই ID শেয়ার করুন।'
      : 'Share this ID with the customer web app.';

  String get tableQrCodes => isBn ? 'টেবিল QR কোড' : 'Table QR Codes';
  String get tableQrSubtitle => isBn
      ? 'প্রতিটি টেবিলের জন্য QR কোড PDF প্রিন্ট করুন।'
      : 'Print a QR code PDF for each table.';
  String get orderingUrl => isBn ? 'অর্ডারিং URL' : 'Ordering URL';
  String get orderingUrlHint => isBn
      ? 'যেমন: https://order.myrestaurant.com'
      : 'e.g. https://order.myrestaurant.com';
  String get numberOfTables => isBn ? 'টেবিলের সংখ্যা' : 'Number of Tables';
  String get generateQrPdf => isBn ? 'PDF তৈরি করুন' : 'Generate PDF';
  String get scanToOrder => isBn ? 'অর্ডার করতে স্ক্যান করুন' : 'Scan to Order';
  String tableLabel(int n) => isBn ? 'টেবিল $n' : 'Table $n';

  String get cloudSync => isBn ? 'ক্লাউড সিঙ্ক' : 'Cloud Sync';
  String get cloudSyncSubtitle => isBn
      ? 'স্টাফদের জন্য ক্লাউড কানেকশন অটোমেটিক থাকবে।'
      : 'Cloud connection stays automatic for staff.';
  String get cloudApiUrlOverride =>
      isBn ? 'Cloud API URL override' : 'Cloud API URL override';
  String get cloudApiUrlHelper => isBn
      ? 'APK-তে Supabase URL build করা থাকলে এটা default রাখুন।'
      : 'Leave as default after the Supabase URL is built into the APK.';
  String get noManualApiKey =>
      isBn ? 'ম্যানুয়াল API key লাগবে না' : 'No manual API key required';
  String get noManualApiKeyMessage => isBn
      ? 'Supabase secret Edge Function-এর ভিতরে থাকে। অ্যাপে শুধু রেস্টুরেন্ট ডিভাইস টোকেন থাকে।'
      : 'Supabase secrets stay inside the Edge Function. This app stores only its private restaurant device token.';
  String get deviceAuthorized => isBn
      ? 'এই ডিভাইসটি বর্তমান রেস্টুরেন্ট/আউটলেটের জন্য authorized। টোকেন hidden ও auto-managed।'
      : 'This device is authorized for the current restaurant/outlet. The token is hidden and managed automatically.';
  String get supabaseUrlMissing =>
      isBn ? 'Supabase URL build করা হয়নি' : 'Supabase URL not built in yet';
  String get supabaseUrlMissingMessage => isBn
      ? 'Admin যেন field edit না করে, APK build করার সময় POS_CLOUD_API_URL দিন।'
      : 'Build the APK with POS_CLOUD_API_URL so admins do not need to edit this field.';
  String get autoSyncInterval =>
      isBn ? 'অটো সিঙ্ক ইন্টারভাল' : 'Auto sync interval';
  String get seconds => isBn ? 'সেকেন্ড' : 'Seconds';
  String get minTenSeconds =>
      isBn ? 'কমপক্ষে ১০ সেকেন্ড দিন' : 'Use at least 10 seconds';
  String get enableCloudSync =>
      isBn ? 'ক্লাউড সিঙ্ক চালু করুন' : 'Enable cloud sync';
  String get cloudQueueSafe => isBn
      ? 'ক্লাউড সাময়িক unavailable হলেও changes queue থাকবে।'
      : 'Changes queue safely when the cloud is temporarily unavailable.';
  String get settingsSaved => isBn ? 'সেটিংস সেভ হয়েছে' : 'Settings saved';
  String get saveFailed => isBn ? 'সেভ ব্যর্থ হয়েছে' : 'Save failed';

  String get receiptPrinter => isBn ? 'রিসিট প্রিন্টার' : 'Receipt Printer';
  String get receiptPrinterSubtitle => isBn
      ? 'নতুন অর্ডারের জন্য Deli ES421 Bluetooth ticket printing।'
      : 'Deli ES421 Bluetooth ticket printing for new orders.';
  String get noPrinterSelected =>
      isBn ? 'কোনো প্রিন্টার সিলেক্ট করা নেই' : 'No printer selected';
  String get printerConnectedAuto => isBn
      ? 'কানেক্টেড। নতুন অর্ডার অটোমেটিক প্রিন্ট হবে।'
      : 'Connected. New orders will print automatically.';
  String get pairPrinterInstruction => isBn
      ? 'Scan করুন — কাছের সব Bluetooth ডিভাইস দেখাবে, তারপর connect করুন।'
      : 'Scan to find nearby Bluetooth devices, then tap to connect.';
  String get autoPrintNewOrders => isBn
      ? 'অটো-অ্যাকসেপ্ট ও অটো-প্রিন্ট নতুন অর্ডার'
      : 'Auto-accept & auto-print new orders';
  String get autoPrintNewOrdersSubtitle => isBn
      ? 'Cloud/manual order আসলে kitchen ticket অটোমেটিক প্রিন্ট হবে এবং কনফার্মেশন মডাল স্কিপ হবে — fast-paced cafe-র জন্য আদর্শ।'
      : 'When a cloud/manual order arrives, the kitchen ticket prints automatically and the confirmation modal is skipped — ideal for fast-paced cafes.';
  String get refreshPairedPrinters =>
      isBn ? 'কাছের ডিভাইস স্ক্যান' : 'Scan for devices';
  String get testPrint => isBn ? 'টেস্ট প্রিন্ট' : 'Test print';
  String get printFailed => isBn ? 'প্রিন্ট ব্যর্থ হয়েছে' : 'Print failed';
  String get printerNotConnectedHint => isBn
      ? 'প্রিন্টার কানেক্ট নেই — Settings থেকে পেয়ার করুন।'
      : 'Printer not connected — go to Settings to pair one.';
  String ticketPrinted(String seq) =>
      isBn ? '$seq-এর টিকেট প্রিন্ট হয়েছে' : 'Ticket printed for $seq';
  String billPrinted(String seq) =>
      isBn ? '$seq-এর বিল প্রিন্ট হয়েছে' : 'Bill printed for $seq';
  String get noPairedPrintersFound => isBn
      ? 'কাছে কোনো Bluetooth ডিভাইস পাওয়া যায়নি'
      : 'No Bluetooth devices found nearby';
  String pairedPrinterFound(int count) =>
      isBn ? '$count টি ডিভাইস পাওয়া গেছে' : '$count device(s) found';
  String connectedTo(String name) =>
      isBn ? '$name কানেক্টেড হয়েছে' : 'Connected to $name';
  String get printerConnectionFailed =>
      isBn ? 'Printer connection failed' : 'Printer connection failed';
  String get printerDisconnected =>
      isBn ? 'Printer disconnected' : 'Printer disconnected';
  String get disconnectFailed =>
      isBn ? 'Disconnect failed' : 'Disconnect failed';
  String get testTicketSent => isBn ? 'Test ticket sent' : 'Test ticket sent';
  String get testFailed => isBn ? 'Test failed' : 'Test failed';

  String get appCache => isBn ? 'অ্যাপ ক্যাশ' : 'App cache';
  String get clearCache => isBn ? 'ক্যাশ ক্লিয়ার' : 'Clear cache';
  String get clearCachedData =>
      isBn ? 'ক্যাশড ডেটা ক্লিয়ার করবেন?' : 'Clear cached data?';
  String get clearCachedDataMessage => isBn
      ? 'এই ডিভাইস থেকে orders, menu items ও sync events মুছে যাবে। Demo menu আবার add হবে না।'
      : 'Orders, menu items, and sync events will be cleared from this device. No demo menu will be added again.';
  String get clearData => isBn ? 'ডেটা ক্লিয়ার' : 'Clear Data';
  String get cachedDataCleared =>
      isBn ? 'Cached data cleared' : 'Cached data cleared';
  String get clearCacheSubtitle => isBn
      ? 'এই ডিভাইসের cached menu, orders ও sync queue ক্লিয়ার করুন।'
      : 'Clear cached menu, orders, and sync queue from this device.';
  String get yourRestaurantInfo =>
      isBn ? 'আপনার রেস্টুরেন্ট তথ্য' : 'Your Restaurant Info';
  String get yourRestaurantInfoSubtitle => isBn
      ? 'পাবলিক যোগাযোগ তথ্য cloud-এ sync করুন।'
      : 'Sync public restaurant contact details to cloud.';
  String get aboutUs => isBn ? 'আমাদের সম্পর্কে' : 'About Us';
  String get privacyPolicy => isBn ? 'প্রাইভেসি পলিসি' : 'Privacy Policy';
  String get logOut => isBn ? 'লগ আউট' : 'Log out';
  String get logOutSubtitle => isBn
      ? 'এই ডিভাইসে লগইন স্ক্রিনে ফিরে যান।'
      : 'Return to the login screen on this device.';
  String get staffAccounts => isBn ? 'স্টাফ অ্যাকাউন্ট' : 'Staff accounts';
  String get staffAccountsSubtitle => isBn
      ? 'স্টাফের মোবাইল নম্বর যোগ করুন। তারা OTP দিয়ে যোগ দেবে।'
      : 'Add staff mobile numbers. They join via phone OTP.';
  String get storeGroup => isBn ? 'স্টোর · Store' : 'Store · স্টোর';
  String get deviceGroup => isBn ? 'ডিভাইস · Device' : 'Device · ডিভাইস';
  String get adminGroup => isBn ? 'অ্যাডমিন · Admin' : 'Admin · অ্যাডমিন';

  // Orders
  String get newOrder => isBn ? 'নতুন অর্ডার' : 'New order';
  String get createNewOrder =>
      isBn ? '+ নতুন অর্ডার তৈরি করুন' : '+ Create New Order';
  String get noPendingOrders =>
      isBn ? 'কোনো পেন্ডিং অর্ডার নেই' : 'No pending orders';
  String get noAcceptedOrders =>
      isBn ? 'কোনো অ্যাকসেপ্টেড অর্ডার নেই' : 'No accepted orders';
  String get noActiveOrdersRightNow =>
      isBn ? 'এখন কোনো সক্রিয় অর্ডার নেই।' : 'No active orders right now.';
  String get noAcceptedOrdersRightNow => isBn
      ? 'এখন কোনো অ্যাকসেপ্টেড অর্ডার নেই।'
      : 'No accepted orders right now.';
  String get quietForNow => isBn ? 'এখন শান্ত' : 'Quiet for now';
  String get quietOrdersMessage => isBn
      ? 'নতুন অর্ডার এখানে আসবে — অনলাইন অর্ডার নিজে থেকেই পিং করবে।\nআপনি চাইলে নিজেও অর্ডার শুরু করতে পারেন।'
      : 'New orders show up here — online orders ping automatically.\nYou can also start one yourself.';
  String get addMenuItemsBeforeOrders => isBn
      ? 'অর্ডার তৈরির আগে উপলভ্য মেনু আইটেম যোগ করুন।'
      : 'Add available menu items before creating orders.';
  String get systemOnlineConnected =>
      isBn ? 'সিস্টেম অনলাইন ও কানেক্টেড' : 'System Online & Connected';
  String get systemNotConnected => isBn
      ? 'সিস্টেম কানেকশন চেক করা দরকার'
      : 'System connection needs attention';
  String get customerMenuLinkActive =>
      isBn ? 'কাস্টমার মেনু লিংক: সক্রিয়' : 'Customer Menu Link: Active';
  String get customerMenuLinkNotReady => isBn
      ? 'কাস্টমার মেনু লিংক: প্রস্তুত নয়'
      : 'Customer Menu Link: Not ready';
  String get clearFiltersShortcut =>
      isBn ? 'ফিল্টার পরিষ্কার করুন' : 'Clear filters';
  String viewOtherOrdersInstead(String label) => isBn
      ? '$label অর্ডার দেখুন'
      : 'View ${label.toLowerCase()} orders instead';
  String get viewTodaysDashboard => isBn
      ? 'আজকের পারফরম্যান্স ড্যাশবোর্ড দেখুন →'
      : "View Today's Performance Dashboard →";
  String get appUpdateAvailableTitle =>
      isBn ? 'অ্যাপ আপডেট প্রস্তুত' : 'App update ready';
  String appUpdateAvailableMessage(String version) => isBn
      ? 'Terafoods $version ইনস্টল করার জন্য প্রস্তুত।'
      : 'Terafoods $version is ready to install.';
  String get appUpdateRequired =>
      isBn ? 'প্রয়োজনীয় আপডেট' : 'Required update';
  String get appUpdateReleaseNotes => isBn ? 'এই আপডেটে' : 'What changed';
  String get updateNow => isBn ? 'এখন আপডেট করুন' : 'Update now';
  String get later => isBn ? 'পরে' : 'Later';
  String get appUpdatePreparing =>
      isBn ? 'আপডেট প্রস্তুত হচ্ছে...' : 'Preparing update...';
  String get appUpdatePermissionRequired => isBn
      ? 'ইনস্টল পারমিশন দিন। অনুমতি দিলে অ্যাপে ফিরে আপডেট শুরু হবে।'
      : 'Allow install permission. The app will continue when you return.';
  String get appUpdatePermissionStillNeeded => isBn
      ? 'আপডেট ইনস্টল করতে Install unknown apps permission দরকার।'
      : 'Install unknown apps permission is required to update.';
  String get appUpdateDownloading =>
      isBn ? 'APK ডাউনলোড হচ্ছে...' : 'Downloading APK...';
  String get appUpdateOpeningInstaller =>
      isBn ? 'ইনস্টলার খোলা হচ্ছে...' : 'Opening installer...';
  String get appUpdateAndroidNotice => isBn
      ? 'Android নিরাপত্তার কারণে শেষ ধাপে সিস্টেম ইনস্টলার থেকে নিশ্চিত করতে হবে।'
      : 'Android requires final confirmation in the system installer.';
  String get pendingTab => isBn ? 'পেন্ডিং' : 'Pending';
  String get acceptedTab => isBn ? 'অ্যাকসেপ্টেড' : 'Accepted';
  String get ordersTitle => isBn ? 'অর্ডার' : 'Orders';
  String get ordersEmptySubtitle => isBn
      ? 'এখনো অর্ডার নেই — প্রথম অর্ডার নিন'
      : 'No orders yet — take your first one';
  String pendingSubtitle(int pending, int accepted) => isBn
      ? '$pending পেন্ডিং · $accepted রান্নাঘরে'
      : '$pending pending · $accepted in kitchen';
  String ordersFilteredSubtitle(int pending, int accepted, int total) => isBn
      ? '$pending পেন্ডিং · $accepted রান্নাঘরে · $total মোট (ফিল্টার)'
      : '$pending pending · $accepted in kitchen · $total filtered';
  String get rejectOrderAction => isBn ? 'রিজেক্ট' : 'Reject';
  String get acceptAndSendToKitchen =>
      isBn ? 'অ্যাকসেপ্ট · রান্নাঘরে পাঠান' : 'Accept · send to kitchen';
  String get reprintAction => isBn ? 'রিপ্রিন্ট' : 'Reprint';
  String get printBillAction => isBn ? 'বিল প্রিন্ট' : 'Print bill';
  String get servedAction => isBn ? 'পরিবেশিত' : 'Served';
  String get orderStatusPending => isBn ? 'পেন্ডিং' : 'Pending';
  String get orderStatusInKitchen => isBn ? 'রান্নাঘরে' : 'In kitchen';
  String orderStatusLate(int minutes) =>
      isBn ? 'দেরি · $minutes মিনিট' : 'Late · $minutes min';
  String orderItemsCount(int count) => isBn ? '$count আইটেম' : '$count items';
  String orderPlacedAgo(String time, String ago) =>
      isBn ? '$time · $ago আগে' : 'placed $time · $ago';
  String orderInKitchenForMinutes(int minutes) =>
      isBn ? '$minutes মিনিট ধরে রান্নাঘরে' : '$minutes min in kitchen';
  String agoMinutes(int minutes) {
    if (minutes < 1) return isBn ? 'এখনই' : 'now';
    if (minutes < 60) return isBn ? '$minutes মিনিট' : '$minutes min';
    final hours = (minutes / 60).floor();
    return isBn ? '$hours ঘণ্টা' : '$hours hr';
  }

  String get applyFilters => isBn ? 'প্রয়োগ করুন' : 'Apply';
  String get resetFilters => isBn ? 'রিসেট' : 'Reset';
  String get filterByDate => isBn ? 'সময়' : 'Time';
  String get filterBySource => isBn ? 'চ্যানেল' : 'Channel';
  String get allTime => isBn ? 'সব সময়' : 'All time';
  String get yesterday => isBn ? 'গতকাল' : 'Yesterday';
  String get last7Days => isBn ? 'গত ৭ দিন' : 'Last 7 days';
  String get last30Days => isBn ? 'গত ৩০ দিন' : 'Last 30 days';
  String get last3Months => isBn ? 'গত ৩ মাস' : 'Last 3 months';
  String get last6Months => isBn ? 'গত ৬ মাস' : 'Last 6 months';
  String get last12Months => isBn ? 'গত ১২ মাস' : 'Last 12 months';
  String get allChannels => isBn ? 'সব চ্যানেল' : 'All channels';
  String orderSourceLabel(OrderSource source) {
    switch (source) {
      case OrderSource.cloud:
        return isBn ? 'ক্লাউড / ওয়েব' : 'Cloud / web';
      case OrderSource.manual:
        return isBn ? 'ম্যানুয়াল' : 'Manual';
      case OrderSource.localLan:
        return isBn ? 'লিগ্যাসি LAN' : 'Legacy LAN';
    }
  }

  // Dashboard
  String get recentOrders => isBn ? 'সাম্প্রতিক অর্ডার' : 'Recent orders';
  String get noOrdersYetToday =>
      isBn ? 'আজকে কোনো অর্ডার নেই।' : 'No orders yet today.';

  // Staff management
  String get deleteStaff => isBn ? 'স্টাফ মুছুন' : 'Remove staff';
  String get deleteStaffConfirm =>
      isBn ? 'এই স্টাফকে সরাতে চান?' : 'Remove this staff member?';
  String get staffAdded => isBn ? 'স্টাফ যোগ হয়েছে।' : 'Staff added.';
  String get staffRemoved => isBn ? 'স্টাফ সরানো হয়েছে।' : 'Staff removed.';
  String get noStaffYet =>
      isBn ? 'এখনো কোনো স্টাফ নেই।' : 'No staff added yet.';
  String get addStaffPhone => isBn ? 'স্টাফ যোগ করুন' : 'Add staff';
  String get staffPhoneNumber =>
      isBn ? 'স্টাফের মোবাইল নম্বর' : 'Staff mobile number';
  String get inviteStatusPending => isBn ? 'অপেক্ষমান' : 'Pending';
  String get inviteStatusDeclined => isBn ? 'প্রত্যাখ্যাত' : 'Declined';
  String get nameOptional => isBn ? 'নাম (ঐচ্ছিক)' : 'Name (optional)';
  String get activeStatus => isBn ? 'সক্রিয়' : 'Active';
  String get disabledStatus => isBn ? 'অক্ষম' : 'Disabled';
  String get pushToCloud => isBn ? 'ক্লাউডে পাঠান' : 'Push To Cloud';
  String get contactPhone => isBn ? 'ফোন' : 'Phone';
  String get contactEmail => isBn ? 'ইমেইল' : 'Email';
  String get contactAddress => isBn ? 'ঠিকানা' : 'Address';
  String get website => isBn ? 'ওয়েবসাইট' : 'Website';
  String get description => isBn ? 'বর্ণনা' : 'Description';
  String get detailsPushed => isBn
      ? 'রেস্টুরেন্ট তথ্য sync queue-তে যোগ হয়েছে'
      : 'Restaurant info added to sync queue';

  String get payWithBkash => isBn
      ? 'এই অ্যাপ ব্যবহার করতে bKash দিয়ে পেমেন্ট করুন'
      : 'To use this App Pay with Bkash';
  String get monthly => isBn ? 'মাসিক' : 'Monthly';
  String get annual => isBn ? 'বার্ষিক' : 'Annual';
  String get bkashCheckoutLoadFailed => isBn
      ? 'bKash checkout load হয়নি। ইন্টারনেট চেক করে আবার চেষ্টা করুন।'
      : 'bKash checkout could not load. Check internet and try again.';
  String get bkashSessionCreateFailed => isBn
      ? 'নতুন bKash payment session তৈরি হয়নি। Internet/backend setup চেক করুন।'
      : 'Could not create a fresh bKash payment session. Check internet and bKash backend setup.';
  String get bkashNotCompleted => isBn
      ? 'bKash payment complete হয়নি। আবার চেষ্টা করুন।'
      : 'bKash payment is not completed yet. Please retry.';
  String get bkashDemoPayment =>
      isBn ? 'bKash Demo Payment' : 'bKash Demo Payment';
  String planLine(String plan, String amount) =>
      isBn ? '$plan প্ল্যান $amount' : '$plan plan $amount';
  String get wallet => isBn ? 'Wallet' : 'Wallet';
  String get otp => isBn ? 'OTP' : 'OTP';
  String get pin => isBn ? 'PIN' : 'PIN';
  String get completeDemoPayment =>
      isBn ? 'Demo Payment Complete করুন' : 'Complete Demo Payment';

  // ── Inventory ──────────────────────────────────────────────────────────────

  String get inventory => isBn ? 'ইনভেন্টরি' : 'Inventory';
  String get inventorySubtitle => isBn
      ? 'আজ কত স্টক আছে ও খরচ দেখুন।'
      : "See what's left today and today's spending.";
  String get inventoryAddItem => isBn ? 'আইটেম যোগ' : 'Add item';
  String get inventoryToday => isBn ? 'আজ' : 'Today';
  String get inventoryItemsTab => isBn ? 'আইটেম' : 'Items';
  String get todaySpend => isBn ? 'আজকের কেনাকাটা' : "Today's purchases";
  String get boughtStock => isBn ? 'কেনা স্টক' : 'Bought stock';
  String get endOfDayCount => isBn ? 'দিন শেষ গণনা' : 'End of day count';
  String get setCount => isBn ? 'গণনা' : 'Count';
  String get usedToday => isBn ? 'ব্যবহৃত' : 'Used';
  String get leftNow => isBn ? 'অবশিষ্ট' : 'Left';
  String get yesterdayLeft => isBn ? 'গতকাল শেষে' : 'Yesterday close';
  String get totalPaid => isBn ? 'মোট খরচ (৳)' : 'Total paid (৳)';
  String get quantityLabel => isBn ? 'পরিমাণ' : 'Quantity';
  String get saveCount => isBn ? 'সংরক্ষণ' : 'Save';
  String get countAllItems => isBn
      ? 'সব আইটেমের আজকের অবশিষ্ট স্টক লিখুন'
      : "Enter what's left for each item";
  String get addInventoryItem => isBn ? 'আইটেম যোগ করুন' : 'Add Item';
  String get editInventoryItem => isBn ? 'আইটেম সম্পাদনা করুন' : 'Edit Item';
  String get deleteInventoryItem => isBn ? 'আইটেম মুছুন' : 'Delete Item';
  String get deleteInventoryConfirm =>
      isBn ? 'এই আইটেমটি মুছে ফেলবেন?' : 'Delete this item?';
  String get itemName => isBn ? 'আইটেমের নাম' : 'Item name';
  String get itemCategory => isBn ? 'ক্যাটাগরি' : 'Category';
  String get unit => isBn ? 'একক' : 'Unit';
  String get currentStock => isBn ? 'বর্তমান স্টক' : 'Current stock';
  String get minThreshold => isBn ? 'সর্বনিম্ন পরিমাণ' : 'Min threshold';
  String get lowStockAlert => isBn ? 'কম স্টক সতর্কতা' : 'Low stock alert';
  String get costPerUnit => isBn ? 'প্রতি একক মূল্য' : 'Cost per unit';
  String get unitPrice => isBn ? 'দাম (প্রতি একক)' : 'Price (per unit)';
  String get openingStock => isBn ? 'বর্তমান স্টক' : 'Current stock';
  String get notes => isBn ? 'নোট' : 'Notes';
  String get adjustStock => isBn ? 'স্টক সামঞ্জস্য করুন' : 'Adjust Stock';
  String get addStock => isBn ? 'স্টক যোগ করুন' : 'Add Stock';
  String get removeStock => isBn ? 'স্টক কমান' : 'Remove Stock';
  String get amount => isBn ? 'পরিমাণ' : 'Amount';
  String get reason => isBn ? 'কারণ' : 'Reason';
  String get adjustmentHistory =>
      isBn ? 'সামঞ্জস্যের ইতিহাস' : 'Adjustment History';
  String get noHistory => isBn ? 'কোনো ইতিহাস নেই' : 'No history yet';
  String get lowStock => isBn ? 'কম স্টক' : 'Low stock';
  String get outOfStock => isBn ? 'স্টক শেষ' : 'Out of stock';
  String get noInventoryItems =>
      isBn ? 'কোনো ইনভেন্টরি আইটেম নেই' : 'No inventory items yet';
  String get noInventoryMessage => isBn
      ? 'কাঁচামাল, উপকরণ বা সরবরাহ ট্র্যাক করতে প্রথম আইটেম যোগ করুন।'
      : 'Add your first item to track raw ingredients, supplies, or materials.';
  String get inStock => isBn ? 'স্টক আছে' : 'In stock';
  String get stockAlerts => isBn ? 'স্টক সতর্কতা' : 'Stock alerts';
  String get allCategories => isBn ? 'সব' : 'All';
  String lowStockCount(int count) =>
      isBn ? '$count টি কম স্টক' : '$count low stock';

  String get tables => isBn ? 'টেবিল' : 'Tables';
  String get tablesSubtitle => isBn
      ? 'রেস্টুরেন্টের টেবিলের সংখ্যা সেট করুন।'
      : 'Set the number of tables in your restaurant.';
  String tableCountLabel(int n) => isBn ? '$n টি টেবিল' : '$n tables';

  String get createRestaurantCloud =>
      isBn ? 'রেস্টুরেন্ট ক্লাউড তৈরি করুন' : 'Create Restaurant Cloud';
  String get oneTimeSecureSetup =>
      isBn ? 'ONE-TIME SECURE SETUP' : 'ONE-TIME SECURE SETUP';
  String get setupRestaurantDescription => isBn
      ? 'একবার রেস্টুরেন্ট সেটআপ করুন। অ্যাপ cloud-এ private restaurant/outlet identity অটোমেটিক তৈরি করবে।'
      : 'Set up this restaurant once. The app will create a private restaurant/outlet identity in the cloud automatically.';
  String get restaurantNameHint =>
      isBn ? 'যেমন: Moon Bistro' : 'Example: Moon Bistro';
  String get outletNameHint =>
      isBn ? 'যেমন: Dhanmondi Branch' : 'Example: Dhanmondi Branch';
  String get cloudSetupFailed =>
      isBn ? 'Cloud setup failed' : 'Cloud setup failed';
  String get deviceHasPrivateToken => isBn
      ? 'এই ডিভাইসে ইতিমধ্যে private cloud token আছে।'
      : 'This device already has a private cloud token.';
  String get noApiKeySetupNeeded => isBn
      ? 'API key setup দরকার নেই। Private device token issue হয়ে app-এর ভিতরে save হবে।'
      : 'No API key setup is needed. A private device token will be issued and stored inside this app.';
  String get configureCloudAdmin =>
      isBn ? 'Cloud Admin কনফিগার করুন' : 'Configure Cloud Admin';
  String get cloudAdmin => isBn ? '✦  CLOUD ADMIN' : '✦  CLOUD ADMIN';
  String get runRestaurantCloud => isBn
      ? 'ক্লাউড থেকে\nরেস্টুরেন্ট চালান।'
      : 'Run your restaurant\nfrom the cloud.';
  String get modeIntroDescription => isBn
      ? 'একটি secure cloud API দিয়ে menu, orders ও status updates manage করুন।'
      : 'Manage menu, orders, and status updates through a secure cloud API with realtime sync across customer websites.';

  // ── Dashboard ──────────────────────────────────────────────────────────────
  String get preparingCloudWorkspace => isBn
      ? 'ক্লাউড ওয়ার্কস্পেস প্রস্তুত হচ্ছে...'
      : 'Preparing cloud workspace...';
  String get restaurantDashboard =>
      isBn ? 'রেস্টুরেন্ট ড্যাশবোর্ড' : 'Restaurant dashboard';
  String get syncNow => isBn ? 'এখনই সিঙ্ক করুন' : 'Sync now';
  String get todayLabel => isBn ? 'আজকে · Today' : 'Today · আজকের';
  String get quickActions => isBn ? 'দ্রুত কাজ' : 'Quick actions';
  String get goodMorning => isBn ? 'শুভ সকাল' : 'Good morning';
  String get goodAfternoon => isBn ? 'শুভ বিকেল' : 'Good afternoon';
  String get goodEvening => isBn ? 'শুভ সন্ধ্যা' : 'Good evening';
  String get noRushYet => isBn ? 'এখনো ব্যস্ততা নেই' : 'No rush yet';
  String get shiftCommand => isBn ? 'শিফট কমান্ড' : 'Shift command';
  String get pendingLabel => isBn ? 'পেন্ডিং' : 'Pending';
  String get kitchenLabel => isBn ? 'রান্নাঘর' : 'Kitchen';
  String get servedLabel => isBn ? 'পরিবেশিত' : 'Served';
  String get cancelledLabel => isBn ? 'বাতিল' : 'Cancelled';
  String get orderChannels => isBn ? 'অর্ডার চ্যানেল' : 'Order channels';
  String get hourlyDemand => isBn ? 'ঘণ্টাভিত্তিক চাহিদা' : 'Hourly demand';
  String get bestSellers => isBn ? 'বেস্ট সেলার' : 'Best sellers';
  String get noItem => isBn ? 'কোনো আইটেম নেই' : 'No item';
  String get noOrdersByChannel => isBn
      ? 'এখনো চ্যানেল অনুযায়ী কোনো অর্ডার নেই।'
      : 'No orders by channel yet.';
  String get noSalesMixToday =>
      isBn ? 'আজকের জন্য কোনো বিক্রয় মিক্স নেই।' : 'No sales mix for today.';
  String tablesLabel(int active, int total) =>
      isBn ? '$active/$total টেবিল' : '$active/$total tables';
  String get newTickets => isBn
      ? 'নতুন টিকেট এখানে স্বয়ংক্রিয়ভাবে আসবে।'
      : 'New tickets will appear here automatically.';
  String get filterOrders => isBn ? 'অর্ডার ফিল্টার করুন' : 'Filter orders';
  String get printTicket => isBn ? 'টিকেট প্রিন্ট করুন' : 'Print ticket';
  String get ticketSentToPrinter =>
      isBn ? 'টিকেট প্রিন্টারে পাঠানো হয়েছে' : 'Ticket sent to printer';
  String get orderNote => isBn
      ? 'অর্ডার নোট (যেমন: পেঁয়াজ ছাড়া, বেশি ঝাল)'
      : 'Order note (e.g. no onion, extra spicy)';
  String get addNote => isBn ? 'নোট যোগ করুন' : 'Add note';
  String get tapItemsToAdd =>
      isBn ? 'অর্ডারে যোগ করতে আইটেমে ট্যাপ করুন' : 'Tap items to add to order';
  String get whereIsOrderFor =>
      isBn ? 'অর্ডার কোথায় যাবে?' : "Where's this order for?";
  String get pickATable => isBn ? 'টেবিল বাছুন' : 'Pick a table';
  String get coversLabel => isBn ? 'অতিথি সংখ্যা' : 'Covers';
  String get howManyPeople => isBn ? 'কতজন অতিথি?' : 'How many people?';
  String get continueAction => isBn ? 'চালিয়ে যান' : 'Continue';
  String get reviewAction => isBn ? 'রিভিউ' : 'Review';
  String get sendToKitchen => isBn ? 'রান্নাঘরে পাঠান' : 'Send to kitchen';
  String get printOnly => isBn ? 'শুধু প্রিন্ট' : 'Print only';
  String get kitchenNote => isBn ? 'রান্নাঘরের নোট' : 'Kitchen note';
  String get kitchenNoteOptional => isBn ? 'ঐচ্ছিক' : '(optional)';
  String get kitchenNoteHint =>
      isBn ? 'যেমন: পেঁয়াজ ছাড়া, কম ঝাল' : 'e.g. no onion, less spicy';
  String get totalLabel => isBn ? 'মোট' : 'Total';
  String get subtotalLabel => isBn ? 'সাবটোটাল' : 'Subtotal';
  String get vatLabel => isBn ? 'ভ্যাট' : 'VAT';
  String get paymentLabel => isBn ? 'পেমেন্ট' : 'Payment';
  String get orderCreatedTitle => isBn ? 'অর্ডার তৈরি হয়েছে' : 'Order created';
  String get sentToKitchenTitle =>
      isBn ? 'রান্নাঘরে পাঠানো হয়েছে' : 'Sent to kitchen';
  String get editItemsAction => isBn ? 'আইটেম সম্পাদনা' : 'Edit items';
  String get searchMenuItems => isBn ? 'আইটেম খুঁজুন' : 'Search menu items…';
  String get categoryAll => isBn ? 'সব' : 'All';
  String get tableBusyBadge => isBn ? 'বসা' : 'Busy';
  String get tableFreeBadge => isBn ? 'খালি' : 'Free';
  String tableNumberLabel(int n) => isBn ? 'T$n' : 'T$n';
  String get takeAnotherOrder =>
      isBn ? 'আরেকটি অর্ডার নিন' : 'Take another order';
  String get backToOrders => isBn ? 'অর্ডারে ফিরুন' : 'Back to Orders';
  String get sourceLabel => isBn ? 'উৎস' : 'Source';
  String get orderLabel => isBn ? 'অর্ডার' : 'Order';
  String orderItemsLine(int qty, int lines) {
    final itemWord = isBn ? 'আইটেম' : (qty == 1 ? 'item' : 'items');
    final lineWord = isBn ? 'লাইন' : (lines == 1 ? 'line' : 'lines');
    return '$qty $itemWord · $lines $lineWord';
  }

  String get noItemsInCategory =>
      isBn ? 'এই ক্যাটাগরিতে কোনো আইটেম নেই' : 'No items in this category';
  String get scanToViewMenu =>
      isBn ? 'মেনু দেখতে স্ক্যান করুন' : 'Scan to view our menu';

  // ── Dashboard (more) ──────────────────────────────────────────────────────
  String get todaysSales => isBn ? 'আজকের বিক্রি' : "TODAY'S SALES";
  String get todaysSalesBn => 'আজকের বিক্রি';
  String get vsYesterday => isBn ? 'গতকালের তুলনায়' : 'vs yesterday';
  String get serviceMix => isBn ? 'সেবার মিক্স' : 'Service mix';
  String get today => isBn ? 'আজকে' : 'today';
  String get dineIn => isBn ? 'ডাইন ইন' : 'Dine-in';
  String get takeaway => isBn ? 'টেকওয়ে' : 'Takeaway';
  String get operations => isBn ? 'অপারেশন' : 'Operations';
  String get pendingOrders => isBn ? 'পেন্ডিং অর্ডার' : 'Pending orders';
  String get inPreparation => isBn ? 'প্রস্তুত হচ্ছে' : 'In preparation';
  String get staleOver15 => isBn ? 'স্থবির (>১৫ মিনিট)' : 'Stale (>15 min)';
  String get lowStockAlerts => isBn ? 'কম স্টক সতর্কতা' : 'Low stock alerts';
  String get unavailableMenuItems =>
      isBn ? 'অনুপলব্ধ মেনু আইটেম' : 'Unavailable menu items';
  String get waitingToSync => isBn ? 'সিঙ্কের অপেক্ষায়' : 'Waiting to sync';
  String get printer => isBn ? 'প্রিন্টার' : 'Printer';
  String get printerReady => isBn ? 'প্রস্তুত' : 'Ready';
  String get printerNotReady => isBn ? 'প্রস্তুত নয়' : 'Not ready';
  String get staffLeaderboard =>
      isBn ? 'স্টাফ লিডারবোর্ড' : 'Staff leaderboard';
  String get salesToday => isBn ? 'আজকের বিক্রি' : 'sales today';
  String get noTrackedOrdersYetToday => isBn
      ? 'আজকে এখনো কোনো ট্র্যাকড অর্ডার নেই।'
      : 'No tracked orders yet today.';
  String get inventoryWatchlist =>
      isBn ? 'ইনভেন্টরি ওয়াচলিস্ট' : 'Inventory watchlist';
  String get stockHealthy => isBn
      ? 'স্টক ভালো। কম স্টকের কোনো সতর্কতা নেই।'
      : 'Stock is healthy. No low-stock alerts.';
  String get report => isBn ? 'রিপোর্ট' : 'Report';
  String get order => isBn ? 'অর্ডার' : 'Order';

  // ── Account Identity ───────────────────────────────────────────────────────
  String get accountIdentity =>
      isBn ? 'অ্যাকাউন্ট আইডেন্টিটি' : 'Account Identity';
  String get accountIdentitySubtitle => isBn
      ? 'এই রেস্টুরেন্টের ক্লাউড পরিচয় ও মালিকের তথ্য।'
      : 'Cloud identity and owner details for this restaurant.';
  String get managerEmail => isBn ? 'ম্যানেজার ইমেইল' : 'Manager email';
  String get accountRole => isBn ? 'অ্যাকাউন্ট রোল' : 'Account role';

  // ── Notifications ──────────────────────────────────────────────────────────
  String get notificationsTitle => isBn ? 'নোটিফিকেশন' : 'Notifications';
  String get markAllRead => isBn ? 'সব পড়া হয়েছে' : 'Mark all read';
  String get noNotificationsYet =>
      isBn ? 'এখনো কোনো নোটিফিকেশন নেই।' : 'No notifications yet.';
  String get openAction => isBn ? 'খুলুন' : 'Open';
  String get dismiss => isBn ? 'বন্ধ' : 'Dismiss';

  // ── Menu management ────────────────────────────────────────────────────────
  String menuItemsSubtitle(int total, int pausedOut) =>
      isBn ? '$total আইটেম · $pausedOut বন্ধ' : '$total items · $pausedOut out';
  String get menuSearchHint => isBn ? 'আইটেম খুঁজুন' : 'Search items';
  String get menuEmptyTitle => isBn ? 'মেনু খালি' : 'Your menu is empty';
  String get menuEmptyMessage =>
      isBn ? '+ চাপুন প্রথম আইটেম যোগ করতে।' : 'Tap + to add your first item.';
  String get menuNoResultsTitle =>
      isBn ? 'কোনো আইটেম পাওয়া যায়নি' : 'No items found';
  String get menuNoResultsMessage => isBn
      ? 'অন্য সার্চ বা ক্যাটাগরি চেষ্টা করুন।'
      : 'Try another search or category.';
  String get menuNewButton => isBn ? 'আইটেম যোগ' : 'Add Item';
  String get menuScan => isBn ? 'মেনু স্ক্যান' : 'Scan Menu';
  String get menuScanning => isBn ? 'স্ক্যান হচ্ছে...' : 'Scanning...';
  String get menuScanPickPages => isBn
      ? 'এক বা একাধিক মেনু পেজ বেছে নিন।'
      : 'Choose one or more menu pages.';
  String get menuScanTakePhotos =>
      isBn ? 'ক্যামেরা দিয়ে ছবি তুলুন' : 'Take menu photos';
  String get menuScanTakePhotosSubtitle => isBn
      ? 'এক বা একাধিক পেজ ক্যামেরায় তুলুন।'
      : 'Use the camera for one or more menu pages.';
  String get menuScanChooseGallery =>
      isBn ? 'গ্যালারি থেকে বেছে নিন' : 'Choose from gallery';
  String get menuScanChooseGallerySubtitle => isBn
      ? 'আগে তোলা মেনু ছবিগুলো আপলোড করুন।'
      : 'Upload menu photos you already captured.';
  String get menuScanAddAnotherTitle =>
      isBn ? 'আরেকটি পেজ তুলবেন?' : 'Add another page?';
  String menuScanAddAnotherMessage(int count) => isBn
      ? '$count টি পেজ নেওয়া হয়েছে। আরেকটি পেজ যোগ করবেন?'
      : '$count page${count == 1 ? '' : 's'} captured. Add another page?';
  String get menuScanUsePhotos =>
      isBn ? 'এই ছবিগুলো ব্যবহার করুন' : 'Use these photos';
  String get menuScanAddPage => isBn ? 'পেজ যোগ করুন' : 'Add page';
  String get menuScanFailed =>
      isBn ? 'মেনু স্ক্যান করা যায়নি' : 'Could not scan menu';
  String menuScanImported(int created, int skipped) => isBn
      ? '$created টি আইটেম যোগ হয়েছে, $skipped টি ডুপ্লিকেট বাদ গেছে।'
      : '$created items added, $skipped duplicates skipped.';
  String categoryCountLabel(String category, int count) {
    final label = category == 'All' ? allCategories : category;
    return '$label $count';
  }

  String get addMenuItem => isBn ? 'মেনু আইটেম যোগ করুন' : 'Add Menu Item';
  String get editMenuItem => isBn ? 'মেনু আইটেম সম্পাদনা' : 'Edit Menu Item';
  String get menuItemName => isBn ? 'আইটেমের নাম' : 'Item name';
  String get menuItemNameRequired =>
      isBn ? 'আইটেমের নাম প্রয়োজন' : 'Item name is required';
  String get menuDescriptionOptional =>
      isBn ? 'বর্ণনা (ঐচ্ছিক)' : 'Description (optional)';
  String get menuCategory => isBn ? 'ক্যাটাগরি' : 'Category';
  String get menuCategoryRequired =>
      isBn ? 'ক্যাটাগরি প্রয়োজন' : 'Category is required';
  String get menuCategoryHint =>
      isBn ? 'নির্বাচন করুন বা নতুন লিখুন' : 'Select or type a category';
  String get menuPrice => isBn ? 'দাম' : 'Price';
  String get menuPriceInvalid =>
      isBn ? 'সঠিক দাম লিখুন' : 'Enter a valid price';
  String get menuPrepTime => isBn ? 'প্রস্তুতির সময়' : 'Preparation time';
  String get menuPrepTimeHint => isBn ? 'মিনিট, ঐচ্ছিক' : 'Minutes, optional';
  String get menuAvailableForOrder =>
      isBn ? 'অর্ডারের জন্য উপলব্ধ' : 'Available for ordering';
  String get menuCreateItem => isBn ? 'আইটেম তৈরি করুন' : 'Create Item';
  String get menuSaveItem => isBn ? 'আইটেম সেভ করুন' : 'Save Item';
  String get menuDeleteTitle =>
      isBn ? 'মেনু আইটেম মুছবেন?' : 'Delete menu item?';
  String get deleteAction => isBn ? 'মুছুন' : 'Delete';
  String get menuDeleted =>
      isBn ? 'মেনু আইটেম মুছে ফেলা হয়েছে' : 'Menu item deleted';
  String get menuChooseGallery =>
      isBn ? 'গ্যালারি থেকে বেছে নিন' : 'Choose from gallery';
  String get menuClearImage => isBn ? 'ছবি সরান' : 'Clear image';
  String get menuImageUploadWarning => isBn
      ? 'ছবি লোকালি রাখা হয়েছে। ইন্টারনেটে আপলোডের জন্য সংযোগ দরকার।'
      : 'Image kept locally. Cloud upload needs internet.';
  String get menuImageUploaded =>
      isBn ? 'ছবি ক্লাউডে আপলোড হয়েছে' : 'Image uploaded to cloud';
  String get menuImageSavedLocal => isBn
      ? 'ছবি লোকালি সেভ হয়েছে। ক্লাউড প্রস্তুত হলে সিঙ্ক হবে।'
      : 'Image saved locally. It will sync when cloud is ready.';

  // ── Hero media ─────────────────────────────────────────────────────────────
  String get heroMediaTitle => isBn ? 'হিরো মিডিয়া' : 'Hero Media';
  String get heroMediaSubtitle => isBn
      ? 'কাস্টমার মেনু পেজের ফটো ও ভিডিও'
      : 'Photos & video on the customer menu page';
  String get heroPhotosTitle => isBn ? 'হিরো ফটো' : 'Hero Photos';
  String get heroPhotosSubtitle => isBn
      ? 'মেনু পেজের ক্যারোসেলে সর্বোচ্চ ৫টি ফটো দেখাবে।'
      : 'Up to 5 photos shown as a sliding carousel on the menu page hero.';
  String get heroMaxImages => isBn
      ? 'সর্বোচ্চ ৫টি হিরো ছবি যোগ করা যায়।'
      : 'Maximum 5 hero images allowed.';
  String get heroRemoveImageTitle => isBn ? 'ছবি সরাবেন?' : 'Remove image?';
  String get remove => isBn ? 'সরান' : 'Remove';
  String get retry => isBn ? 'আবার চেষ্টা' : 'Retry';
  String get heroVideoTitle => isBn ? 'স্বাগত ভিডিও' : 'Welcome Video';
  String get heroVideoSubtitle => isBn
      ? 'কাস্টমার স্বাগত স্ক্রিনে চলে (সর্বোচ্চ ৩০ সেকেন্ড, ৫০ MB)।'
      : 'Short clip (up to 30 s, 50 MB) played on the customer welcome screen.';
  String get heroVideoSet => isBn ? 'ভিডিও সেট করা আছে' : 'Video set';
  String get heroReplaceVideo => isBn ? 'ভিডিও পরিবর্তন করুন' : 'Replace Video';
  String get heroPickVideo =>
      isBn ? 'গ্যালারি থেকে ভিডিও বেছে নিন' : 'Pick Video from Gallery';
  String get heroVideoTooLarge => isBn
      ? 'ভিডিও অনেক বড়। ৫০ MB-এর নিচে একটি ক্লিপ ব্যবহার করুন।'
      : 'Video is too large. Please use a clip under 50 MB.';
  String get heroVideoUploaded =>
      isBn ? 'ভিডিও আপলোড হয়েছে!' : 'Video uploaded!';
  String get heroAddPhoto => isBn ? 'ফটো যোগ করুন' : 'Add photo';
  String get heroAddVideo => isBn ? 'ভিডিও যোগ করুন' : 'Add video';
  String get heroClearVideo => isBn ? 'ভিডিও সরান' : 'Remove video';
  String get noCategoryDataToday => isBn
      ? 'আজকের জন্য কোনো ক্যাটাগরি ডেটা নেই।'
      : 'No category data yet today.';
  String get stockValueTitle => isBn ? 'স্টক মূল্য' : 'Stock value';
  String get stockValueHint => isBn
      ? 'বর্তমান একক মূল্যে আনুমানিক ইনভেন্টরি।'
      : 'Estimated inventory at current unit cost.';
  String get categorySalesTitle => isBn ? 'ক্যাটাগরি বিক্রি' : 'Category sales';

  // Owner dashboard
  String get totalOrders => isBn ? 'মোট অর্ডার' : 'Orders';
  String get openOrders => isBn ? 'চলমান' : 'Open';
  String get needsAction => isBn ? 'কাজ বাকি' : 'Needs action';
  String get allClear => isBn ? 'সব ক্লিয়ার' : 'All clear';
  String get avgTicket => isBn ? 'গড় বিল' : 'Avg ticket';
  String get perOrder => isBn ? 'প্রতি অর্ডার' : 'per order';
  String get cancelRateLabel => isBn ? 'বাতিল রেট' : 'Cancel rate';
  String get tooHigh => isBn ? 'বেশি' : 'too high';
  String get healthy => isBn ? 'ঠিক আছে' : 'healthy';
  String get needsAttention => isBn ? 'এখনই দরকার' : 'Needs attention';
  String get lastSevenDays => isBn ? 'গত ৭ দিন' : 'Last 7 days';

  // Inventory enhancements
  String get inventoryHealth => isBn ? 'ইনভেন্টরি অবস্থা' : 'Inventory health';
  String get itemsTotal => isBn ? 'মোট আইটেম' : 'Items';
  String get itemsOut => isBn ? 'শেষ' : 'Out';
  String get itemsLow => isBn ? 'কম' : 'Low';
  String get itemsOk => isBn ? 'ঠিক আছে' : 'OK';
  String get searchInventory => isBn ? 'আইটেম খুঁজুন...' : 'Search items...';
  String get filterAll => isBn ? 'সব' : 'All';
  String get noMatchingItems =>
      isBn ? 'কোনো মিল পাওয়া যায়নি' : 'No matching items';
  String get tryDifferentFilter => isBn
      ? 'অন্য সার্চ বা ফিল্টার চেষ্টা করুন।'
      : 'Try a different search or filter.';
  String get stockValueShort => isBn ? 'স্টক মূল্য' : 'Stock value';
  String itemsWithCount(int count) => isBn ? '$count টি আইটেম' : '$count items';
  String get lastUpdated => isBn ? 'শেষ আপডেট' : 'Last updated';
  String get reorderSoon => isBn ? 'শীঘ্রই কিনুন' : 'reorder soon';
  String get outOfStockNow => isBn ? 'এখনই কিনুন' : 'buy now';

  // Dashboard — money first
  String get earnedToday => isBn ? 'আজকের আয়' : 'Earned today';
  String get topMoversToday => isBn ? 'আজকের শীর্ষ মুভার' : 'Top movers today';
  String get seeAll => isBn ? 'সব দেখুন' : 'See all';
  String get readyWhenYouAre => isBn ? 'প্রস্তুত হলে' : 'Ready when you are';
  String get closeToday => isBn ? 'আজকের দিন শেষ করুন' : 'Close today';
  String get kpiOrders => isBn ? 'অর্ডার' : 'Orders';
  String get kpiOpen => isBn ? 'খোলা' : 'Open';
  String get kpiAvg => isBn ? 'গড়' : 'Avg';
  String get kpiProfit => isBn ? 'লাভ' : 'Profit';

  // Dashboard — right now
  String get rightNow => isBn ? 'এই মুহূর্তে' : 'Right now';
  String get tablesSeated => isBn ? 'টেবিল বসা' : 'Tables seated';
  String get ordersInKitchen => isBn ? 'কিচেনে অর্ডার' : 'Orders in kitchen';
  String lateOverMinutes(int minutes) =>
      isBn ? '$minutes মিনিটের বেশি দেরি' : 'Late over $minutes min';
  String get needsYourEye => isBn ? 'আপনার দৃষ্টি দরকার' : 'Needs your eye';
  String get qaNewOrder => isBn ? 'নতুন অর্ডার' : 'New order';
  String get qaPrintBill => isBn ? 'বিল প্রিন্ট' : 'Print bill';
  String get qaCallWaiter => isBn ? 'ওয়েটার ডাকুন' : 'Call waiter';
  String get qaShiftReport => isBn ? 'শিফট রিপোর্ট' : 'Shift report';
  String get todaySoFar => isBn ? 'আজ এ পর্যন্ত' : 'Today so far';
  String get attentionLate => isBn ? 'দেরি' : 'LATE';
  String get attentionLow => isBn ? 'কম স্টক' : 'LOW';
  String get attentionCheck => isBn ? 'দেখুন' : 'Check';
  String get attentionReorder => isBn ? 'অর্ডার' : 'Reorder';

  // Inventory home
  String get stockValueNow => isBn ? 'বর্তমান স্টক মূল্য' : 'Stock value now';
  String get varianceToday => isBn ? 'আজকের ভ্যারিয়েন্স' : 'Variance today';
  String varianceItems(int count) => isBn ? '$count টি আইটেম' : '$count items';
  String alertsCount(int count) => isBn ? '$count টি সতর্কতা' : '$count alerts';
  String get categoryRaw => isBn ? 'কাঁচা' : 'Raw';
  String get categoryDry => isBn ? 'শুকনা' : 'Dry';
  String get categoryPackaged => isBn ? 'প্যাকেট' : 'Packaged';
  String get categoryOther => isBn ? 'অন্যান্য' : 'Other';
  String get colItem => isBn ? 'আইটেম' : 'ITEM';
  String get colOnHand => isBn ? 'বর্তমান' : 'ON HAND';
  String get colInOut => isBn ? 'ইন/আউট' : 'IN/OUT';
  String get colVar => isBn ? 'ভ্যার' : 'VAR';
  String get statusOk => isBn ? 'ঠিক' : 'OK';
  String get statusLow => isBn ? 'কম' : 'LOW';
  String get statusOut => isBn ? 'শেষ' : 'OUT';
  String get stockIn => isBn ? 'স্টক ইন' : 'Stock in';
  String get startCount => isBn ? 'গণনা শুরু' : 'Start count';
  String get aiScanCount => isBn ? 'AI দিয়ে স্ক্যান' : 'AI scan';
  String get aiScanCountHint => isBn
      ? 'স্টক কাউন্ট শিট বা তাকের ছবি স্ক্যান করে পরিমাণ বসান।'
      : 'Scan a count sheet or shelf photo to fill quantities.';
  String get aiCountScanApplied => isBn
      ? 'AI স্ক্যান থেকে পরিমাণ বসানো হয়েছে'
      : 'AI scan filled matching counts';
  String get dailyReport => isBn ? 'দৈনিক রিপোর্ট' : 'Daily report';

  // Stock in flow
  String get stockInTitle => isBn ? 'স্টক ইন' : 'Stock in';
  String stepXofY(int step, int total) =>
      isBn ? 'ধাপ $step এর $total' : 'Step $step of $total';
  String get dateLabel => isBn ? 'তারিখ' : 'Date';
  String get scanSupplierBill =>
      isBn ? 'সরবরাহকারীর বিল স্ক্যান করুন' : 'Scan supplier bill';
  String get aiReadsItemsQtyPrices =>
      isBn ? 'AI আইটেম, পরিমাণ এবং দাম পড়ে' : 'AI reads items, qty, prices';
  String get addManually => isBn ? 'হাতে যোগ করুন' : 'add manually';
  String get saveAndAddToStock =>
      isBn ? 'সেভ করুন ও স্টকে যোগ করুন' : 'Save & add to stock';
  String get qtyLabel => isBn ? 'পরিমাণ' : 'QTY';
  String pricePerUnit(String unit) => isBn ? 'মূল্য / $unit' : 'PRICE / $unit';
  String get newStockLabel => isBn ? 'নতুন স্টক' : 'NEW STOCK';
  String get scanningReceipt =>
      isBn ? 'রিসিট স্ক্যান হচ্ছে…' : 'Scanning receipt…';
  String get receiptScanFailed =>
      isBn ? 'রিসিট স্ক্যান ব্যর্থ হয়েছে' : 'Receipt scan failed';

  // Daily report
  String get unexplainedVariance =>
      isBn ? 'ব্যাখ্যাহীন ভ্যারিয়েন্স' : 'Unexplained variance';
  String get varianceBreakdown =>
      isBn ? 'ভ্যারিয়েন্স বিশ্লেষণ' : 'Variance breakdown';
  String acrossItems(int count) =>
      isBn ? '$count টি আইটেমে' : 'across $count items';
  String recurringWeeks(int weeks) =>
      isBn ? '$weeks সপ্তাহ ধরে' : '$weeks wks in a row';
  String get expectedCountedLabel =>
      isBn ? 'প্রত্যাশিত vs গণনাকৃত' : 'expected vs counted';
  String get reorderSuggestion => isBn ? 'অর্ডার সাজেশন' : 'Reorder suggestion';
  String get share => isBn ? 'শেয়ার' : 'Share';

  // Generic loading + offline banners
  String get liveMetricsOffline =>
      isBn ? 'লাইভ মেট্রিক্স অফলাইন' : 'Live metrics offline';
  String get pullToRefresh => isBn ? 'রিফ্রেশ করতে টানুন' : 'Pull to refresh';
}
