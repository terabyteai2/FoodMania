import 'package:flutter/material.dart';

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

  String get appTitle => 'REs Admin';
  String get cloudSuite => isBn ? 'ক্লাউড POS স্যুট' : 'Cloud POS Suite';
  String get cloudRestaurantSuite =>
      isBn ? 'ক্লাউড রেস্টুরেন্ট স্যুট' : 'Cloud Restaurant Suite';

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
      ? 'Android Bluetooth settings থেকে ES421 pair করে এখানে connect করুন।'
      : 'Pair the ES421 in Android Bluetooth settings, then connect here.';
  String get autoPrintNewOrders =>
      isBn ? 'নতুন অর্ডার অটো প্রিন্ট' : 'Auto print new orders';
  String get autoPrintNewOrdersSubtitle => isBn
      ? 'Cloud/manual order এই ডিভাইসে আসলে kitchen ticket অটোমেটিক প্রিন্ট হবে।'
      : 'When a cloud/manual order reaches this admin device, the kitchen ticket prints automatically.';
  String get refreshPairedPrinters =>
      isBn ? 'Paired printer refresh' : 'Refresh paired printers';
  String get testPrint => isBn ? 'টেস্ট প্রিন্ট' : 'Test print';
  String get noPairedPrintersFound => isBn
      ? 'কোনো paired Bluetooth printer পাওয়া যায়নি'
      : 'No paired Bluetooth printers found';
  String pairedPrinterFound(int count) => isBn
      ? '$count টি paired printer পাওয়া গেছে'
      : '$count paired printer found';
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
  String get inventorySubtitle =>
      isBn ? 'স্টক ট্র্যাক করুন এবং সামগ্রী পরিচালনা করুন।' : 'Track stock levels and manage ingredients.';
  String get addInventoryItem =>
      isBn ? 'আইটেম যোগ করুন' : 'Add Item';
  String get editInventoryItem =>
      isBn ? 'আইটেম সম্পাদনা করুন' : 'Edit Item';
  String get deleteInventoryItem =>
      isBn ? 'আইটেম মুছুন' : 'Delete Item';
  String get deleteInventoryConfirm =>
      isBn ? 'এই আইটেমটি মুছে ফেলবেন?' : 'Delete this item?';
  String get itemName => isBn ? 'আইটেমের নাম' : 'Item name';
  String get itemCategory => isBn ? 'ক্যাটাগরি' : 'Category';
  String get unit => isBn ? 'একক' : 'Unit';
  String get currentStock => isBn ? 'বর্তমান স্টক' : 'Current stock';
  String get minThreshold => isBn ? 'সর্বনিম্ন পরিমাণ' : 'Min threshold';
  String get costPerUnit => isBn ? 'প্রতি একক মূল্য' : 'Cost per unit';
  String get notes => isBn ? 'নোট' : 'Notes';
  String get adjustStock => isBn ? 'স্টক সামঞ্জস্য করুন' : 'Adjust Stock';
  String get addStock => isBn ? 'স্টক যোগ করুন' : 'Add Stock';
  String get removeStock => isBn ? 'স্টক কমান' : 'Remove Stock';
  String get amount => isBn ? 'পরিমাণ' : 'Amount';
  String get reason => isBn ? 'কারণ' : 'Reason';
  String get adjustmentHistory => isBn ? 'সামঞ্জস্যের ইতিহাস' : 'Adjustment History';
  String get noHistory => isBn ? 'কোনো ইতিহাস নেই' : 'No history yet';
  String get lowStock => isBn ? 'কম স্টক' : 'Low stock';
  String get outOfStock => isBn ? 'স্টক শেষ' : 'Out of stock';
  String get noInventoryItems =>
      isBn ? 'কোনো ইনভেন্টরি আইটেম নেই' : 'No inventory items yet';
  String get noInventoryMessage =>
      isBn ? 'কাঁচামাল, উপকরণ বা সরবরাহ ট্র্যাক করতে প্রথম আইটেম যোগ করুন।'
           : 'Add your first item to track raw ingredients, supplies, or materials.';
  String get inStock => isBn ? 'স্টক আছে' : 'In stock';
  String get stockAlerts => isBn ? 'স্টক সতর্কতা' : 'Stock alerts';
  String get allCategories => isBn ? 'সব' : 'All';
  String lowStockCount(int count) =>
      isBn ? '$count টি কম স্টক' : '$count low stock';

  String get tables => isBn ? 'টেবিল' : 'Tables';
  String get tablesSubtitle =>
      isBn ? 'রেস্টুরেন্টের টেবিলের সংখ্যা সেট করুন।' : 'Set the number of tables in your restaurant.';
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
}
