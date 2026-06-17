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

  String _n(num value) => isBn ? _bnDigits(value.toString()) : value.toString();
  String _digits(String value) => isBn ? _bnDigits(value) : value;

  static String _bnDigits(String input) {
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    var out = input;
    for (var i = 0; i < en.length; i++) {
      out = out.replaceAll(en[i], bn[i]);
    }
    return out;
  }

  String get appTitle => 'Terafoods';
  String get cloudSuite => isBn ? 'রেস্টুরেন্ট POS' : 'Restaurant POS';
  String get cloudRestaurantSuite => isBn ? 'টেরাফুডস POS' : 'Terafoods POS';

  String get dashboard => isBn ? 'ড্যাশবোর্ড' : 'Dashboard';
  String get home => isBn ? 'হোম' : 'Home';
  String get menu => isBn ? 'মেনু' : 'Menu';
  String get orders => isBn ? 'অর্ডার' : 'Orders';
  String get reports => isBn ? 'রিপোর্ট' : 'Reports';
  String get sync => isBn ? 'সিঙ্ক' : 'Sync';

  // ── QuickBytes navigation + More hub ──────────────────────────────────────
  String get settingsTab => isBn ? 'সেটিংস' : 'Settings';
  String get liveTab => isBn ? 'লাইভ' : 'Live';
  String get analyticsTab => isBn ? 'অ্যানালিটিক্স' : 'Analytics';
  String get stockTab => isBn ? 'স্টক' : 'Stock';
  String get manageSection => isBn ? 'ম্যানেজ' : 'Manage';
  String get messages => isBn ? 'মেসেজ' : 'Messages';
  String get staff => isBn ? 'স্টাফ' : 'Staff';
  String get auditTrail => isBn ? 'অডিট ট্রেইল' : 'Audit trail';
  String get serviceMode => isBn ? 'সার্ভিস মোড' : 'Service mode';
  String get fullService => isBn ? 'ফুল' : 'Full';
  String get counterService => isBn ? 'কাউন্টার' : 'Counter';
  String get switchRoleDemo =>
      isBn ? 'রোল পরিবর্তন (ডেমো)' : 'Switch role (demo)';
  String get comingSoon => isBn ? 'শীঘ্রই আসছে' : 'Coming soon';
  String get onTheFloor => isBn ? 'অন দ্য ফ্লোর' : 'On the floor';
  String get tableVacant => isBn ? 'খালি' : 'Vacant';
  String tablesOccupiedFree(int occupied, int free) => isBn
      ? '● ${_n(occupied)} টি ব্যস্ত · ○ ${_n(free)} টি খালি'
      : '● $occupied occupied · ○ $free free';
  String get newDineInOrder =>
      isBn ? '+ নতুন ডাইন-ইন অর্ডার' : '+ New dine-in order';
  String get newParcelOrder =>
      isBn ? '+ নতুন পার্সেল অর্ডার' : '+ New parcel order';
  String get newDeliveryOrder =>
      isBn ? '+ নতুন ডেলিভারি অর্ডার' : '+ New delivery order';
  String get quickSell => isBn ? 'কুইক সেল' : 'Quick sell';
  String get noOpenParcels =>
      isBn ? 'কোনো খোলা পার্সেল নেই' : 'No open parcel orders';
  String get noOpenDeliveries =>
      isBn ? 'কোনো খোলা ডেলিভারি নেই' : 'No open delivery orders';
  String toAcceptCount(int n) =>
      isBn ? '${_n(n)} টি গ্রহণ বাকি' : '$n to accept';
  String get toAcceptLabel => isBn ? 'গ্রহণ বাকি' : 'to accept';
  String ongoingCount(int n) => isBn ? '${_n(n)} টি চলমান' : '$n ongoing';

  String get save => isBn ? 'সেভ' : 'Save';
  String get cancel => isBn ? 'বাতিল' : 'Cancel';
  String get requiredField => isBn ? 'প্রয়োজনীয়' : 'Required';
  String get connected => isBn ? 'কানেক্টেড' : 'Connected';
  String get connect => isBn ? 'কানেক্ট' : 'Connect';
  String get reconnect => isBn ? 'রীকানেক্ট' : 'Reconnect';
  String get disconnect => isBn ? 'ডিসকানেক্ট' : 'Disconnect';
  String get ok => isBn ? 'ঠিক আছে' : 'OK';
  String get somethingWentWrong =>
      isBn ? 'কিছু ভুল হয়েছে' : 'Something went wrong';
  String get search => isBn ? 'খুঁজুন' : 'Search';

  String get secureTenant => isBn ? 'সুরক্ষিত টেন্যান্ট' : 'Secure tenant';
  String get tokenVerified => isBn ? 'টোকেন ভেরিফাইড' : 'Token verified';

  String get languageLabel => isBn ? 'ভাষা' : 'Language';
  String get themeMode => isBn ? 'থিম মোড' : 'Theme mode';
  String get themeModeSubtitle => isBn
      ? 'পুরো অ্যাপ কালো, সাদা বা ডিভাইস মোডে দেখান।'
      : 'Use Black, White, or Device mode for the whole app.';
  String get blackMode => isBn ? 'কালো' : 'Black';
  String get whiteMode => isBn ? 'সাদা' : 'White';
  String get deviceMode => isBn ? 'ডিভাইস' : 'Device';
  String get appLanguage => isBn ? 'অ্যাপ ভাষা' : 'App language';
  String get bangla => 'বাংলা';
  String get english => 'English';
  String get customerMenuTheme =>
      isBn ? 'কাস্টমার মেনু থিম' : 'Customer Menu Theme';
  String get customerMenuThemeSubtitle => isBn
      ? 'পাবলিক অর্ডার পেজের লুক বেছে নিন।'
      : 'Pick the look of your public ordering page.';
  String get customerMenuThemePreviewLabel => isBn ? 'প্রিভিউ' : 'Preview';
  String get facebookMessengerBot =>
      isBn ? 'Facebook Messenger bot' : 'Facebook Messenger bot';
  String get facebookMessengerBotSubtitle => isBn
      ? 'Messenger থেকে মেনু প্রশ্ন ও ডেলিভারি অর্ডার নিন।'
      : 'Answer menu questions and take delivery orders from Messenger.';
  String get facebookPageAccessToken =>
      isBn ? 'Page access token' : 'Page access token';
  String get facebookPageAccessTokenHint =>
      isBn ? 'নতুন পেজ টোকেন পেস্ট করুন' : 'Paste a new Page token';
  String get facebookPageAccessTokenHelper => isBn
      ? 'সেভ করার পর টোকেন ব্যাকএন্ডে গোপন থাকবে।'
      : 'After saving, the token stays hidden on the backend.';
  String get connectFacebookPage =>
      isBn ? 'Facebook দিয়ে কানেক্ট করুন' : 'Connect with Facebook';
  String get reconnectFacebookPage =>
      isBn ? 'Facebook পেজ আবার কানেক্ট করুন' : 'Reconnect Facebook Page';
  String get facebookLoginTitle => isBn ? 'Facebook Login' : 'Facebook Login';
  String get facebookLoginComplete =>
      isBn ? 'Facebook পেজ কানেক্ট হয়েছে' : 'Facebook Page connected';
  String get facebookLoginFailed => isBn
      ? 'Facebook Login সম্পন্ন হয়নি'
      : 'Facebook Login was not completed';
  String get facebookLoginCancelled =>
      isBn ? 'Facebook Login বাতিল করা হয়েছে' : 'Facebook Login was cancelled';
  String get selectFacebookPage =>
      isBn ? 'Facebook পেজ বেছে নিন' : 'Choose a Facebook Page';
  String get selectFacebookPageSubtitle => isBn
      ? 'এই আউটলেটের Messenger বটের সাথে যে পেজ যুক্ত হবে সেটি নিশ্চিত করুন।'
      : 'Confirm which Page should be connected to this outlet Messenger bot.';
  String get confirmFacebookPage =>
      isBn ? 'পেজ কানেক্ট করুন' : 'Connect selected Page';
  String get facebookBotEnabled => isBn ? 'বট চালু' : 'Bot enabled';
  String get facebookOrderingEnabled =>
      isBn ? 'ডেলিভারি অর্ডার চালু' : 'Delivery ordering enabled';
  String get facebookWebhookUrl =>
      isBn ? 'Webhook callback URL' : 'Webhook callback URL';
  String get facebookPageId => isBn ? 'Page ID' : 'Page ID';
  String get facebookPageName => isBn ? 'Page name' : 'Page name';
  String get facebookTokenSavedAs => isBn ? 'Saved token' : 'Saved token';
  String get facebookBotConnected => isBn ? 'Connected' : 'Connected';
  String get facebookBotNotConnected => isBn ? 'Setup needed' : 'Setup needed';
  String get facebookBotDisabled => isBn ? 'Disabled' : 'Disabled';
  String get saveMessengerSettings =>
      isBn ? 'Messenger সেটিংস সেভ করুন' : 'Save Messenger settings';
  String get messengerSettingsSaved =>
      isBn ? 'Messenger সেটিংস সেভ হয়েছে' : 'Messenger settings saved';

  String get restaurantName => isBn ? 'রেস্টুরেন্টের নাম' : 'Restaurant name';
  String get outletName => isBn ? 'আউটলেটের নাম' : 'Outlet name';

  String get tableQrCodes => isBn ? 'সব QR কোড' : 'All QR Codes';
  String get tableQrSubtitle => isBn
      ? 'রেস্টুরেন্ট মেনু ও প্রতিটি টেবিলের QR কোড PDF প্রিন্ট করুন।'
      : 'Print restaurant-menu and table QR codes as a PDF.';
  String get tableQrLabels => isBn ? 'টেবিল QR লেবেল' : 'Table QR Labels';
  String get tableQrLabelsSubtitle => isBn
      ? 'প্রিন্টার দিয়ে আলাদা টেবিল QR স্টিকার প্রিন্ট করুন।'
      : 'Print individual table QR stickers via Bluetooth/USB printer.';
  String get tableLabelPrinted => isBn ? 'এর লেবেল প্রিন্ট হয়েছে' : 'label printed';
  String get noTablesConfigured => isBn
      ? 'কোনো টেবিল কনফিগার করা নেই'
      : 'No tables configured';
  String get orderingUrl => isBn ? 'অর্ডারিং URL' : 'Ordering URL';
  String get orderingUrlHint => isBn
      ? 'যেমন: https://order.myrestaurant.com'
      : 'e.g. https://order.myrestaurant.com';
  String get numberOfTables => isBn ? 'টেবিলের সংখ্যা' : 'Number of Tables';
  String get generateQrPdf => isBn ? 'PDF তৈরি করুন' : 'Generate PDF';
  String get scanToOrder => isBn ? 'অর্ডার করতে স্ক্যান করুন' : 'Scan to Order';
  String tableLabel(int n) => isBn ? 'টেবিল ${_n(n)}' : 'Table $n';
  String get restaurantMenuQr => isBn ? 'রেস্টুরেন্ট মেনু' : 'Restaurant menu';
  String get publicSlugRequired =>
      isBn ? 'পাবলিক URL প্রয়োজন' : 'Public URL required';
  String get print => isBn ? 'প্রিন্ট' : 'Print';
  String get savePdf => isBn ? 'PDF সেভ করুন' : 'Save PDF';
  String qrCodeSummary(int tableCount, String slug) => isBn
      ? 'মূল মেনু ও ${_n(tableCount)} টি টেবিল কোড: $slug.quickbytes.buzz'
      : 'Main menu and $tableCount table codes use $slug.quickbytes.buzz';
  String get qrUrlSetupRequired => isBn
      ? 'QR কোড তৈরির জন্য পাবলিক মেনু URL সেট করুন।'
      : 'Set the public menu URL to generate QR codes.';
  String get qrUrlSetupHelp => isBn
      ? 'প্রথমে Public URL সেটিংসে একটি slug সেভ করুন।'
      : 'Open Public URL settings and save a slug first.';
  String get qrLinksHelp => isBn
      ? 'মূল QR মেনু খুলবে; টেবিল QR সরাসরি টেবিল অর্ডার পেজ খুলবে।'
      : 'The main QR opens the menu; table QRs open their table order pages.';

  String get cloudSync => isBn ? 'ক্লাউড সিঙ্ক' : 'Cloud Sync';
  String get cloudSyncSubtitle => isBn
      ? 'স্টাফদের জন্য ক্লাউড কানেকশন অটোমেটিক থাকবে।'
      : 'Cloud connection stays automatic for staff.';
  String get cloudApiUrlOverride =>
      isBn ? 'Cloud API URL override' : 'Cloud API URL override';
  String get cloudApiUrlHelper => isBn
      ? 'APK-তে Supabase URL যোগ করা থাকলে এটি ডিফল্ট রাখুন।'
      : 'Leave as default after the Supabase URL is built into the APK.';
  String get noManualApiKey =>
      isBn ? 'ম্যানুয়াল API key লাগবে না' : 'No manual API key required';
  String get noManualApiKeyMessage => isBn
      ? 'Supabase secret Edge Function-এর ভিতরে থাকে। অ্যাপে শুধু রেস্টুরেন্ট ডিভাইস টোকেন থাকে।'
      : 'Supabase secrets stay inside the Edge Function. This app stores only its private restaurant device token.';
  String get deviceAuthorized => isBn
      ? 'এই ডিভাইসটি বর্তমান রেস্টুরেন্ট/আউটলেটের জন্য অনুমোদিত। টোকেন গোপন থাকবে এবং স্বয়ংক্রিয়ভাবে পরিচালিত হবে।'
      : 'This device is authorized for the current restaurant/outlet. The token is hidden and managed automatically.';
  String get supabaseUrlMissing =>
      isBn ? 'Supabase URL যোগ করা হয়নি' : 'Supabase URL not built in yet';
  String get supabaseUrlMissingMessage => isBn
      ? 'অ্যাডমিনকে যেন ফিল্ড সম্পাদনা করতে না হয়, APK তৈরির সময় POS_CLOUD_API_URL দিন।'
      : 'Build the APK with POS_CLOUD_API_URL so admins do not need to edit this field.';
  String get autoSyncInterval =>
      isBn ? 'অটো সিঙ্ক ইন্টারভাল' : 'Auto sync interval';
  String get seconds => isBn ? 'সেকেন্ড' : 'Seconds';
  String get minTenSeconds =>
      isBn ? 'কমপক্ষে ১০ সেকেন্ড দিন' : 'Use at least 10 seconds';
  String get enableCloudSync =>
      isBn ? 'ক্লাউড সিঙ্ক চালু করুন' : 'Enable cloud sync';
  String get cloudQueueSafe => isBn
      ? 'ক্লাউড সাময়িক অনুপলব্ধ হলেও পরিবর্তনগুলো তালিকায় থাকবে।'
      : 'Changes queue safely when the cloud is temporarily unavailable.';
  String get settingsSaved => isBn ? 'সেটিংস সেভ হয়েছে' : 'Settings saved';
  String get saveFailed => isBn ? 'সেভ ব্যর্থ হয়েছে' : 'Save failed';
  String get searchSettingsHint => isBn ? 'সেটিংস খুঁজুন' : 'Search settings';
  String get noSettingsFound =>
      isBn ? 'কোনো সেটিংস পাওয়া যায়নি' : 'No settings found';
  String get tryDifferentSearch =>
      isBn ? 'অন্য সার্চ চেষ্টা করুন।' : 'Try a different search.';
  String get settingsChatBot => isBn ? 'চ্যাটবট' : 'ChatBot';
  String get settingsConnectPrinter =>
      isBn ? 'প্রিন্টার কানেক্ট করুন' : 'Connect Printer';
  String get settingsAllQrCodes => isBn ? 'সব QR কোড' : 'All QR Codes';
  String get settingsWebsiteTheme => isBn ? 'ওয়েবসাইট থিম' : 'Website Theme';
  String get settingsSetTableNumbers =>
      isBn ? 'টেবিল সংখ্যা সেট করুন' : 'Set Table Numbers';
  String get settingsLogOut => isBn ? 'লগ আউট' : 'Log Out';
  String get accountGroup => isBn ? 'অ্যাকাউন্ট' : 'Account';

  String get receiptPrinter => isBn ? 'রিসিট প্রিন্টার' : 'Receipt Printer';
  String get receiptPrinterSubtitle => isBn
      ? 'Type-C USB অথবা Bluetooth প্রিন্টিং ব্যবহার করে।'
      : 'Uses type-C USB or Bluetooth printing.';
  String get noPrinterSelected =>
      isBn ? 'কোনো প্রিন্টার সিলেক্ট করা নেই' : 'No printer selected';
  String get printerConnectedAuto => isBn
      ? 'কানেক্টেড। নতুন অর্ডার অটোমেটিক প্রিন্ট হবে।'
      : 'Connected. New orders will print automatically.';
  String get pairPrinterInstruction => isBn
      ? 'Type-C কেবল লাগান অথবা কাছের Bluetooth ডিভাইস স্ক্যান করে কানেক্ট করুন।'
      : 'Plug in type-C USB or scan nearby Bluetooth devices.';
  String get autoPrintNewOrders => isBn
      ? 'অটো-অ্যাকসেপ্ট ও অটো-প্রিন্ট নতুন অর্ডার'
      : 'Auto-accept & auto-print new orders';
  String get autoPrintNewOrdersSubtitle => isBn
      ? 'ক্লাউড বা ম্যানুয়াল অর্ডার এলে রান্নাঘরের টিকেট স্বয়ংক্রিয়ভাবে প্রিন্ট হবে এবং নিশ্চিতকরণ মডাল বাদ যাবে।'
      : 'When a cloud/manual order arrives, the kitchen ticket prints automatically and the confirmation modal is skipped — ideal for fast-paced cafes.';
  String get refreshPairedPrinters =>
      isBn ? 'কাছের ডিভাইস স্ক্যান' : 'Scan for devices';
  String get refresh => isBn ? 'রিফ্রেশ' : 'Refresh';
  String get testPrint => isBn ? 'টেস্ট প্রিন্ট' : 'Test print';
  String get printerDiagnostics =>
      isBn ? 'প্রিন্টার ডায়াগনস্টিকস' : 'Printer diagnostics';
  String get clearPrinterDiagnostics =>
      isBn ? 'প্রিন্টার ডায়াগনস্টিকস মুছুন' : 'Clear printer diagnostics';
  String get copyDiagnostics => isBn ? 'কপি করুন' : 'Copy';
  String get close => isBn ? 'বন্ধ করুন' : 'Close';
  String get printFailed => isBn ? 'প্রিন্ট ব্যর্থ হয়েছে' : 'Print failed';
  String get printerNotConnectedHint => isBn
      ? 'প্রিন্টার কানেক্ট নেই। Type-C কেবল লাগান বা সেটিংস থেকে Bluetooth পেয়ার করুন।'
      : 'Printer not connected — plug in type-C USB or pair Bluetooth in Settings.';
  String ticketPrinted(String seq) => isBn
      ? '${_digits(seq)}-এর টিকেট প্রিন্ট হয়েছে'
      : 'Ticket printed for $seq';
  String billPrinted(String seq) =>
      isBn ? '${_digits(seq)}-এর বিল প্রিন্ট হয়েছে' : 'Bill printed for $seq';
  String get noPairedPrintersFound => isBn
      ? 'কাছে কোনো Bluetooth ডিভাইস পাওয়া যায়নি'
      : 'No Bluetooth devices found nearby';
  String pairedPrinterFound(int count) =>
      isBn ? '${_n(count)} টি ডিভাইস পাওয়া গেছে' : '$count device(s) found';
  String connectedTo(String name) =>
      isBn ? '$name কানেক্টেড হয়েছে' : 'Connected to $name';
  String get printerConnectionFailed =>
      isBn ? 'প্রিন্টার কানেকশন ব্যর্থ হয়েছে' : 'Printer connection failed';
  String get printerDisconnected =>
      isBn ? 'প্রিন্টার ডিসকানেক্ট হয়েছে' : 'Printer disconnected';
  String get disconnectFailed =>
      isBn ? 'ডিসকানেক্ট ব্যর্থ হয়েছে' : 'Disconnect failed';
  String get testTicketSent =>
      isBn ? 'টেস্ট টিকেট পাঠানো হয়েছে' : 'Test ticket sent';
  String get testFailed => isBn ? 'টেস্ট ব্যর্থ হয়েছে' : 'Test failed';

  String get appCache => isBn ? 'অ্যাপ ক্যাশ' : 'App cache';
  String get clearCache => isBn ? 'ক্যাশ ক্লিয়ার' : 'Clear cache';
  String get clearCachedData =>
      isBn ? 'ক্যাশড ডেটা ক্লিয়ার করবেন?' : 'Clear cached data?';
  String get clearCachedDataMessage => isBn
      ? 'এই ডিভাইস থেকে অর্ডার, মেনু আইটেম ও সিঙ্ক ইভেন্ট মুছে যাবে। ডেমো মেনু আবার যোগ হবে না।'
      : 'Orders, menu items, and sync events will be cleared from this device. No demo menu will be added again.';
  String get clearData => isBn ? 'ডেটা ক্লিয়ার' : 'Clear Data';
  String get cachedDataCleared =>
      isBn ? 'ক্যাশড ডেটা মুছে ফেলা হয়েছে' : 'Cached data cleared';
  String get clearCacheSubtitle => isBn
      ? 'এই ডিভাইসের ক্যাশড মেনু, অর্ডার ও সিঙ্ক তালিকা ক্লিয়ার করুন।'
      : 'Clear cached menu, orders, and sync queue from this device.';
  String get aboutUs => isBn ? 'আমাদের সম্পর্কে' : 'About Us';
  String get privacyPolicy => isBn ? 'প্রাইভেসি পলিসি' : 'Privacy Policy';
  String get logOut => isBn ? 'লগ আউট' : 'Log out';
  String get logOutSubtitle => isBn
      ? 'এই ডিভাইসে লগইন স্ক্রিনে ফিরে যান।'
      : 'Return to the login screen on this device.';
  String get deviceGroup => isBn ? 'ডিভাইস' : 'Device';
  String get adminGroup => isBn ? 'অ্যাডমিন' : 'Admin';
  String get dangerZoneGroup => isBn ? 'ডেঞ্জার জোন' : 'Danger Zone';
  String get myRestaurantDetailsGroup =>
      isBn ? 'আমার রেস্টুরেন্টের তথ্য' : 'My restaurant details';
  String get accountHolderName => isBn ? 'নাম' : 'Name';
  String get accountHolderNameSubtitle =>
      isBn ? 'অ্যাকাউন্ট হোল্ডারের নাম' : 'Account holder name';
  String get restaurantNameFieldSubtitle =>
      isBn ? 'গ্রাহকদের কাছে দেখানো নাম' : 'Shown to customers';
  String get restaurantPhoneLabel =>
      isBn ? 'রেস্টুরেন্টের ফোন' : 'Restaurant phone';
  String get restaurantPhoneSubtitle => isBn
      ? 'গ্রাহকদের জন্য যোগাযোগের নম্বর (আপনার নিজের নম্বর নয়)'
      : 'Customer-facing contact number (not your own phone)';
  String get websiteUrlLabel => isBn ? 'ওয়েবসাইট URL' : 'Website URL';
  String get websiteUrlSubtitle =>
      isBn ? 'আপনার গ্রাহক মেনু লিংক' : 'Your customer menu link';
  String get websiteImageVideoTitle =>
      isBn ? 'ওয়েবসাইটের ছবি/ভিডিও' : 'Website image/video';
  String get setUpLabel => isBn ? 'সেট আপ করুন' : 'Set up';
  String get urlNameTooShort =>
      isBn ? 'URL নাম কমপক্ষে ৩ অক্ষরের হতে হবে।' : 'URL name must be at least 3 characters.';
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
  String get orderSearchHint =>
      isBn ? 'অর্ডার, আইটেম বা টেবিল খুঁজুন' : 'Search order, item, or table';
  String get clearSearch => isBn ? 'সার্চ পরিষ্কার করুন' : 'Clear search';
  String get noOrderSearchResultsTitle =>
      isBn ? 'কোনো অর্ডার মেলেনি' : 'No matching orders';
  String noOrderSearchResultsMessage(String query) => isBn
      ? '"${_digits(query)}" দিয়ে কোনো অর্ডার পাওয়া যায়নি।'
      : 'No orders found for "$query".';
  String couldNotCreateOrder(Object error) => isBn
      ? 'অর্ডার তৈরি করা যায়নি: $error'
      : 'Could not create order: $error';
  String viewOtherOrdersInstead(String label) => isBn
      ? '$label অর্ডার দেখুন'
      : 'View ${label.toLowerCase()} orders instead';
  String get viewTodaysDashboard => isBn
      ? 'আজকের পারফরম্যান্স ড্যাশবোর্ড দেখুন →'
      : "View Today's Performance Dashboard →";
  String get appUpdateAvailableTitle =>
      isBn ? 'অ্যাপ আপডেট প্রস্তুত' : 'App update ready';
  String appUpdateAvailableMessage(String version) => isBn
      ? 'QuickBytes ${_digits(version)} ইনস্টল করার জন্য প্রস্তুত।'
      : 'QuickBytes $version is ready to install.';
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
      ? 'আপডেট ইনস্টল করতে অজানা অ্যাপ ইনস্টলের অনুমতি দরকার।'
      : 'Install unknown apps permission is required to update.';
  String get appUpdateDownloading =>
      isBn ? 'APK ডাউনলোড হচ্ছে...' : 'Downloading APK...';
  String get appUpdateOpeningInstaller =>
      isBn ? 'ইনস্টলার খোলা হচ্ছে...' : 'Opening installer...';
  String get appUpdateAndroidNotice => isBn
      ? 'Android নিরাপত্তার কারণে শেষ ধাপে সিস্টেম ইনস্টলার থেকে নিশ্চিত করতে হবে।'
      : 'Android requires final confirmation in the system installer.';
  String get adminBlockingNoticeEyebrow =>
      isBn ? 'অ্যাপ সাময়িকভাবে বন্ধ' : 'APP TEMPORARILY LOCKED';
  String get adminBlockingNoticeDefaultTitle =>
      isBn ? 'টেরাফুডস থেকে জরুরি বার্তা' : 'Important message from Terafoods';
  String get adminBlockingNoticeHelper => isBn
      ? 'এই বার্তাটি শুধু টেরাফুডস সাপোর্ট সরাতে পারবে। অনুমতি ফিরলে অ্যাপ স্বয়ংক্রিয়ভাবে খুলে যাবে।'
      : 'Only Terafoods support can remove this message. The app will unlock automatically when access is restored.';
  String get adminBlockingNoticeCheckAgain =>
      isBn ? 'আবার যাচাই করুন' : 'Check again';
  String get adminBlockingNoticeRefreshFailed => isBn
      ? 'সার্ভারে পৌঁছানো যায়নি। সংযোগ ঠিক হলে আবার যাচাই করুন।'
      : 'Could not reach the server. Check again when the connection is available.';
  String get pendingTab => isBn ? 'পেন্ডিং' : 'Pending';
  String get acceptedTab => isBn ? 'অ্যাকসেপ্টেড' : 'Accepted';
  String get ongoingTab => isBn ? 'চলমান' : 'Ongoing';
  String get completedTab => isBn ? 'সম্পন্ন' : 'Completed';
  String get onTheFloorNow => isBn ? 'এখন ফ্লোরে' : 'On the floor now';
  String get completedPaid => isBn ? 'সম্পন্ন · পেইড' : 'Completed · paid';
  String get printKotAction => isBn ? 'KOT প্রিন্ট' : 'Print KOT';
  String kotPrinted(String seq) =>
      isBn ? '${_digits(seq)}-এর KOT প্রিন্ট হয়েছে' : 'KOT printed for $seq';
  String get noOngoingOrders =>
      isBn ? 'কোনো চলমান অর্ডার নেই।' : 'No ongoing orders.';
  String get noCompletedOrders =>
      isBn ? 'এখনো কোনো সম্পন্ন অর্ডার নেই।' : 'No completed orders yet.';
  // Compact relative age for order cards: "5m ago" / "2h ago".
  String orderAgeAgo(int minutes) {
    if (minutes < 1) return isBn ? 'এইমাত্র' : 'just now';
    if (minutes < 60) {
      return isBn ? '${_n(minutes)} মিনিট আগে' : '${minutes}m ago';
    }
    final hours = (minutes / 60).floor();
    return isBn ? '${_n(hours)} ঘণ্টা আগে' : '${hours}h ago';
  }

  String get ordersTitle => isBn ? 'অর্ডার' : 'Orders';
  String get ordersEmptySubtitle => isBn
      ? 'এখনো অর্ডার নেই — প্রথম অর্ডার নিন'
      : 'No orders yet — take your first one';
  String pendingSubtitle(int pending, int accepted) => isBn
      ? '${_n(pending)} পেন্ডিং · ${_n(accepted)} রান্নাঘরে'
      : '$pending pending · $accepted in kitchen';
  String ordersFilteredSubtitle(int pending, int accepted, int total) => isBn
      ? '${_n(pending)} পেন্ডিং · ${_n(accepted)} রান্নাঘরে · ${_n(total)} মোট (ফিল্টার)'
      : '$pending pending · $accepted in kitchen · $total filtered';
  String get rejectOrderAction => isBn ? 'রিজেক্ট' : 'Reject';
  String get acceptAndSendToKitchen => isBn ? 'অ্যাকসেপ্ট' : 'Accept';
  String get reprintAction => isBn ? 'রিপ্রিন্ট' : 'Reprint';
  String get printBillAction => isBn ? 'বিল প্রিন্ট' : 'Print bill';
  String get printReceiptAction => isBn ? 'রিসিট প্রিন্ট' : 'Print receipt';
  String get servedAction => isBn ? 'পরিবেশিত' : 'Served';
  String get orderStatusPending => isBn ? 'পেন্ডিং' : 'Pending';
  String get orderStatusInKitchen => isBn ? 'রান্নাঘরে' : 'In kitchen';
  String orderStatusLate(int minutes) =>
      isBn ? 'দেরি · ${_n(minutes)} মিনিট' : 'Late · $minutes min';
  String orderItemsCount(int count) =>
      isBn ? '${_n(count)} আইটেম' : '$count items';
  String orderPlacedAgo(String time, String ago) =>
      isBn ? '${_digits(time)} · ${_digits(ago)} আগে' : 'placed $time · $ago';
  String orderInKitchenForMinutes(int minutes) =>
      isBn ? '${_n(minutes)} মিনিট ধরে রান্নাঘরে' : '$minutes min in kitchen';
  String agoMinutes(int minutes) {
    if (minutes < 1) return isBn ? 'এখনই' : 'now';
    if (minutes < 60) return isBn ? '${_n(minutes)} মিনিট' : '$minutes min';
    final hours = (minutes / 60).floor();
    return isBn ? '${_n(hours)} ঘণ্টা' : '$hours hr';
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
      case OrderSource.facebookMessenger:
        return isBn ? 'Messenger' : 'Messenger';
      case OrderSource.desktopPos:
        return isBn ? 'ডেস্কটপ POS' : 'Desktop POS';
      case OrderSource.manual:
        return isBn ? 'ম্যানুয়াল' : 'Manual';
      case OrderSource.localLan:
        return isBn ? 'লিগ্যাসি LAN' : 'Legacy LAN';
    }
  }

  // Short channel name for order cards, keyed by the 6 prototype channels
  // (storefront/chatbot/qr/waiter/counter/manager). See CHANNELS in bytes-shared.jsx.
  String channelLabel(String key) {
    switch (key) {
      case 'storefront':
        return isBn ? 'ওয়েবসাইট' : 'Website';
      case 'chatbot':
        return isBn ? 'মেসেঞ্জার' : 'Messenger';
      case 'qr':
        return isBn ? 'টেবিল QR' : 'Table QR';
      case 'waiter':
        return isBn ? 'ওয়েটার' : 'Waiter';
      case 'counter':
        return isBn ? 'কাউন্টার' : 'Counter';
      case 'manager':
      default:
        return isBn ? 'ম্যানেজার' : 'Manager';
    }
  }

  // Dashboard
  String get recentOrders => isBn ? 'সাম্প্রতিক অর্ডার' : 'Recent orders';
  String get noOrdersYetToday =>
      isBn ? 'আজকে কোনো অর্ডার নেই।' : 'No orders yet today.';

  // Staff management
  String get noStaffYet =>
      isBn ? 'এখনো কোনো স্টাফ নেই।' : 'No staff added yet.';
  String get description => isBn ? 'বর্ণনা' : 'Description';
  String get detailsPushed => isBn
      ? 'রেস্টুরেন্ট তথ্য সিঙ্ক তালিকায় যোগ হয়েছে'
      : 'Restaurant info added to sync queue';

  String get payWithBkash => isBn
      ? 'এই অ্যাপ ব্যবহার করতে bKash দিয়ে পেমেন্ট করুন'
      : 'To use this App Pay with Bkash';
  String get monthly => isBn ? 'মাসিক' : 'Monthly';
  String get annual => isBn ? 'বার্ষিক' : 'Annual';
  String get bkashCheckoutLoadFailed => isBn
      ? 'bKash চেকআউট লোড হয়নি। ইন্টারনেট পরীক্ষা করে আবার চেষ্টা করুন।'
      : 'bKash checkout could not load. Check internet and try again.';
  String get bkashSessionCreateFailed => isBn
      ? 'নতুন bKash পেমেন্ট সেশন তৈরি হয়নি। ইন্টারনেট ও ব্যাকএন্ড সেটআপ পরীক্ষা করুন।'
      : 'Could not create a fresh bKash payment session. Check internet and bKash backend setup.';
  String get bkashNotCompleted => isBn
      ? 'bKash পেমেন্ট সম্পন্ন হয়নি। আবার চেষ্টা করুন।'
      : 'bKash payment is not completed yet. Please retry.';
  String get bkashDemoPayment =>
      isBn ? 'bKash Demo Payment' : 'bKash Demo Payment';
  String planLine(String plan, String amount) =>
      isBn ? '$plan প্ল্যান ${_digits(amount)}' : '$plan plan $amount';
  String get wallet => isBn ? 'Wallet' : 'Wallet';
  String get otp => isBn ? 'OTP' : 'OTP';
  String get pin => isBn ? 'PIN' : 'PIN';
  String get completeDemoPayment =>
      isBn ? 'ডেমো পেমেন্ট সম্পন্ন করুন' : 'Complete Demo Payment';

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
      isBn ? '${_n(count)} টি কম স্টক' : '$count low stock';

  String get tables => isBn ? 'টেবিল' : 'Tables';
  String get tablesSubtitle => isBn
      ? 'রেস্টুরেন্টের টেবিলের সংখ্যা সেট করুন।'
      : 'Set the number of tables in your restaurant.';
  String tableCountLabel(int n) => isBn ? '${_n(n)} টি টেবিল' : '$n tables';

  String get createRestaurantCloud =>
      isBn ? 'রেস্টুরেন্ট ক্লাউড তৈরি করুন' : 'Create Restaurant Cloud';
  String get oneTimeSecureSetup =>
      isBn ? 'ONE-TIME SECURE SETUP' : 'ONE-TIME SECURE SETUP';
  String get setupRestaurantDescription => isBn
      ? 'একবার রেস্টুরেন্ট সেটআপ করুন। অ্যাপ ক্লাউডে ব্যক্তিগত রেস্টুরেন্ট ও আউটলেট পরিচয় স্বয়ংক্রিয়ভাবে তৈরি করবে।'
      : 'Set up this restaurant once. The app will create a private restaurant/outlet identity in the cloud automatically.';
  String get restaurantNameHint =>
      isBn ? 'যেমন: Moon Bistro' : 'Example: Moon Bistro';
  String get outletNameHint =>
      isBn ? 'যেমন: Dhanmondi Branch' : 'Example: Dhanmondi Branch';
  String get cloudSetupFailed =>
      isBn ? 'ক্লাউড সেটআপ ব্যর্থ হয়েছে' : 'Cloud setup failed';
  String get deviceHasPrivateToken => isBn
      ? 'এই ডিভাইসে ইতিমধ্যে ব্যক্তিগত ক্লাউড টোকেন আছে।'
      : 'This device already has a private cloud token.';
  String get noApiKeySetupNeeded => isBn
      ? 'API কী সেটআপ দরকার নেই। ব্যক্তিগত ডিভাইস টোকেন তৈরি হয়ে অ্যাপের ভিতরে সেভ হবে।'
      : 'No API key setup is needed. A private device token will be issued and stored inside this app.';
  String get configureCloudAdmin =>
      isBn ? 'ক্লাউড অ্যাডমিন কনফিগার করুন' : 'Configure Cloud Admin';
  String get cloudAdmin => isBn ? '✦  CLOUD ADMIN' : '✦  CLOUD ADMIN';
  String get runRestaurantCloud => isBn
      ? 'ক্লাউড থেকে\nরেস্টুরেন্ট চালান।'
      : 'Run your restaurant\nfrom the cloud.';
  String get modeIntroDescription => isBn
      ? 'নিরাপদ ক্লাউড API দিয়ে মেনু, অর্ডার ও অবস্থার আপডেট পরিচালনা করুন।'
      : 'Manage menu, orders, and status updates through a secure cloud API with realtime sync across customer websites.';

  // ── Dashboard ──────────────────────────────────────────────────────────────
  String get preparingCloudWorkspace => isBn
      ? 'ক্লাউড ওয়ার্কস্পেস প্রস্তুত হচ্ছে...'
      : 'Preparing cloud workspace...';
  String get restaurantDashboard =>
      isBn ? 'রেস্টুরেন্ট ড্যাশবোর্ড' : 'Restaurant dashboard';
  String get syncNow => isBn ? 'এখনই সিঙ্ক করুন' : 'Sync now';
  String get todayLabel => isBn ? 'আজকে' : 'Today';
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
      isBn ? '${_n(active)}/${_n(total)} টেবিল' : '$active/$total tables';
  String get newTickets => isBn
      ? 'নতুন টিকেট এখানে স্বয়ংক্রিয়ভাবে আসবে।'
      : 'New tickets will appear here automatically.';
  String get filterOrders => isBn ? 'অর্ডার ফিল্টার করুন' : 'Filter orders';
  String get printTicket => isBn ? 'টিকেট প্রিন্ট করুন' : 'Print ticket';
  String get ticketSentToPrinter =>
      isBn ? 'টিকেট প্রিন্টারে পাঠানো হয়েছে' : 'Ticket sent to printer';
  String get testNotificationTitle =>
      isBn ? 'টেস্ট নোটিফিকেশন' : 'Test notification';
  String get testNotificationBody => isBn
      ? 'এই শব্দ শুনতে পেলে সতর্কতা ঠিকভাবে কাজ করছে।'
      : 'If you can hear this, alerts are wired up correctly.';
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
  String get reviewOrder => isBn ? 'অর্ডার পর্যালোচনা' : 'Review order';
  String get sendToKitchen => isBn ? 'অর্ডার তৈরি করুন' : 'Create order';
  String get printOnly => isBn ? 'শুধু প্রিন্ট' : 'Print only';
  String get kitchenNote => isBn ? 'রান্নাঘরের নোট' : 'Kitchen note';
  String get kitchenNoteOptional => isBn ? 'ঐচ্ছিক' : '(optional)';
  String get kitchenNoteHint =>
      isBn ? 'যেমন: পেঁয়াজ ছাড়া, কম ঝাল' : 'e.g. no onion, less spicy';
  String get totalLabel => isBn ? 'মোট' : 'Total';
  String get subtotalLabel => isBn ? 'সাবটোটাল' : 'Subtotal';
  String get vatLabel => isBn ? 'ভ্যাট' : 'VAT';
  String vatLabelWithPercent(double percent) {
    if (percent <= 0) return vatLabel;
    final isWhole = percent == percent.roundToDouble();
    if (isWhole) {
      return isBn
          ? '$vatLabel (${_n(percent.toInt())}%)'
          : '$vatLabel (${percent.toInt()}%)';
    }
    final formatted = percent.toStringAsFixed(1);
    return isBn
        ? '$vatLabel (${_bnDigits(formatted)}%)'
        : '$vatLabel ($formatted%)';
  }

  String get paymentLabel => isBn ? 'পেমেন্ট' : 'Payment';
  String get orderCreatedTitle => isBn ? 'অর্ডার তৈরি হয়েছে' : 'Order created';
  String get sentToKitchenTitle => orderCreatedTitle;
  String get editItemsAction => isBn ? 'আইটেম সম্পাদনা' : 'Edit items';
  String get searchMenuItems => isBn ? 'আইটেম খুঁজুন' : 'Search menu items…';
  String get categoryAll => isBn ? 'সব' : 'All';
  String get tableBusyBadge => isBn ? 'বসা' : 'Busy';
  String get tableFreeBadge => isBn ? 'খালি' : 'Free';
  String tableNumberLabel(int n) => isBn ? 'T${_n(n)}' : 'T$n';
  String get takeAnotherOrder =>
      isBn ? 'আরেকটি অর্ডার নিন' : 'Take another order';
  String get backToOrders => isBn ? 'অর্ডারে ফিরুন' : 'Back to Orders';
  String get sourceLabel => isBn ? 'উৎস' : 'Source';
  String get orderLabel => isBn ? 'অর্ডার' : 'Order';
  String orderItemsLine(int qty, int lines) {
    final itemWord = isBn ? 'আইটেম' : (qty == 1 ? 'item' : 'items');
    final lineWord = isBn ? 'লাইন' : (lines == 1 ? 'line' : 'lines');
    return isBn
        ? '${_n(qty)} $itemWord · ${_n(lines)} $lineWord'
        : '$qty $itemWord · $lines $lineWord';
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
  String get takeaway => isBn ? 'পার্সেল' : 'Parcel';
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
  String get viewAction => isBn ? 'দেখুন' : 'View';
  String get acceptAction => isBn ? 'গ্রহণ' : 'Accept';
  String get laterAction => isBn ? 'পরে' : 'Later';
  String get notifTabAll => isBn ? 'সব' : 'All';
  String get notifTabOrders => isBn ? 'অর্ডার' : 'Orders';
  String get notifTabStock => isBn ? 'স্টক' : 'Stock';
  String get notifTabOnline => isBn ? 'অনলাইন' : 'Online';
  String get notifTabStaff => isBn ? 'স্টাফ' : 'Staff';
  String get notifSectionToday => isBn ? 'আজ' : 'TODAY';
  String get notifSectionEarlier => isBn ? 'আগের' : 'EARLIER';
  String unreadCountLabel(int n) => isBn ? '${_n(n)} অপঠিত' : '$n unread';
  String notificationSummaryTitle(int n) =>
      isBn ? '${_n(n)} টি নোটিফিকেশন' : 'You have $n notifications';
  String get notificationSummaryBody => isBn
      ? 'সব নোটিফিকেশন একসাথে দেখতে খুলুন।'
      : 'Open to review them together.';
  String pendingOrdersGroupTitle(int n) =>
      isBn ? '${_n(n)} টি পেন্ডিং অর্ডার' : 'You have $n pending orders';
  String get pendingOrdersGroupBody => isBn
      ? 'গ্রহণ করার অপেক্ষায়। ট্যাপ করে অর্ডার তালিকা খুলুন।'
      : 'Awaiting acceptance. Tap to open the orders list.';

  // ── Menu management ────────────────────────────────────────────────────────
  String menuItemsSubtitle(int total, int pausedOut) => isBn
      ? '${_n(total)} আইটেম · ${_n(pausedOut)} বন্ধ'
      : '$total items · $pausedOut out';
  String menuItemsCategorySubtitle(int total, int categories) => isBn
      ? '${_n(total)} আইটেম · ${_n(categories)} ক্যাটাগরি'
      : '$total items · $categories categories';
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
  String get menuAddActionShort => isBn ? 'আইটেম' : 'Item';
  String get menuActionDelivery => isBn ? 'ডেলিভারি' : 'Delivery';
  String get menuActionScan => isBn ? 'স্ক্যান' : 'Scan';
  String get menuActionDiscounts => isBn ? 'ডিসকাউন্ট' : 'Discounts';
  String get menuActionSettings => isBn ? 'সেটিংস' : 'Settings';
  String get menuDeliveryOn => isBn ? 'ডেলিভারি চালু' : 'Delivery on';
  String get menuDeliveryOff => isBn ? 'ডেলিভারি বন্ধ' : 'Delivery off';
  String get menuScan => isBn ? 'AI স্ক্যান' : 'AI scan';
  String get menuScanning => isBn ? 'স্ক্যান হচ্ছে...' : 'Scanning...';
  String get menuScanningShort => isBn ? 'স্ক্যান...' : 'Scanning...';
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
      ? '${_n(count)} টি পেজ নেওয়া হয়েছে। আরেকটি পেজ যোগ করবেন?'
      : '$count page${count == 1 ? '' : 's'} captured. Add another page?';
  String get menuScanUsePhotos =>
      isBn ? 'এই ছবিগুলো ব্যবহার করুন' : 'Use these photos';
  String get menuScanAddPage => isBn ? 'পেজ যোগ করুন' : 'Add page';
  String get menuScanFailed =>
      isBn ? 'মেনু স্ক্যান করা যায়নি' : 'Could not scan menu';
  String menuScanImported(int created, int skipped) => isBn
      ? '${_n(created)} টি আইটেম যোগ হয়েছে, ${_n(skipped)} টি ডুপ্লিকেট বাদ গেছে।'
      : '$created items added, $skipped duplicates skipped.';
  String categoryCountLabel(String category, int count) {
    final label = category == 'All' ? allCategories : category;
    return '$label ${_n(count)}';
  }

  String get addMenuItem => isBn ? 'মেনু আইটেম যোগ করুন' : 'Add Menu Item';
  String get editMenuItem => isBn ? 'মেনু আইটেম সম্পাদনা' : 'Edit Menu Item';
  String get menuNewItemTitle => isBn ? 'নতুন আইটেম' : 'New item';
  String get menuEditItemTitle => isBn ? 'আইটেম সম্পাদনা' : 'Edit item';
  String get menuAddPhoto => isBn ? 'ছবি যোগ করুন' : 'Add photo';
  String get menuItemAdded =>
      isBn ? 'মেনু আইটেম যোগ হয়েছে' : 'Menu item added';
  String get menuItemUpdated =>
      isBn ? 'মেনু আইটেম আপডেট হয়েছে' : 'Menu item updated';
  String get cropMenuPhoto => isBn ? 'মেনু ছবি ক্রপ করুন' : 'Crop menu photo';
  String get usePhoto => isBn ? 'ব্যবহার করুন' : 'Use';
  String get menuPhotoReadFailed => isBn
      ? 'ছবিটি পড়া যায়নি। অন্য ছবি বেছে নিন।'
      : 'Could not read the selected image.';
  String get menuPhotoTooLarge => isBn
      ? 'ছবিটি বড়। অন্য ছবি বেছে নিন বা আবার ক্রপ করুন।'
      : 'Photo is too large. Choose another photo or crop again.';
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
  String menuDeleteDescription(String itemName) => isBn
      ? '$itemName মেনু থেকে সরানো হবে এবং ভবিষ্যৎ API রেসপন্সে থাকবে না।'
      : '$itemName will be removed from the admin app and future API responses.';
  String get deleteAction => isBn ? 'মুছুন' : 'Delete';
  String get menuDeleted =>
      isBn ? 'মেনু আইটেম মুছে ফেলা হয়েছে' : 'Menu item deleted';
  String get menuChooseGallery =>
      isBn ? 'গ্যালারি থেকে বেছে নিন' : 'Choose from gallery';
  String get menuClearImage => isBn ? 'ছবি সরান' : 'Clear image';
  String get menuAvailable => isBn ? 'উপলব্ধ' : 'Available';
  String get menuPaused => isBn ? 'বিরতি' : 'Paused';
  String get menuHidden => isBn ? 'লুকানো' : 'Hidden';
  String get menuLowStock => isBn ? 'স্টক কম' : 'Low stock';
  String get menuDiscountTitle =>
      isBn ? 'ডিসকাউন্ট (ঐচ্ছিক)' : 'Discount (optional)';
  String get menuDiscountNone => isBn ? 'কোনো ছাড় নেই' : 'No discount';
  String get menuDiscountPercent => isBn ? 'শতকরা ছাড়' : 'Percent off';
  String get menuDiscountFlat =>
      isBn ? 'নির্দিষ্ট টাকা ছাড়' : 'Flat amount off';
  String get menuDiscountValue => isBn ? 'মান' : 'Value';
  String get menuOptionsTitle => isBn ? 'অপশন' : 'Options';
  String get menuVariationsAddOns =>
      isBn ? 'ভ্যারিয়েশন ও অ্যাড-অন' : 'Variations & add-ons';
  String get menuOptionsSubtitle => isBn
      ? 'সাইজ/ভ্যারিয়েন্ট, ডিসকাউন্ট, সেট-মিল এবং অ্যাড-অন'
      : 'Sizes/variants, discount, set meal, and add-ons';
  String get menuSizeOptionsTitle =>
      isBn ? 'সাইজ / ভ্যারিয়েন্ট (ঐচ্ছিক)' : 'Size / variants (optional)';
  String get menuSizeOptionsHint => isBn
      ? 'প্রতি লাইন: নাম : বাড়তি দাম, যেমন Large : 50'
      : 'One per line: name : extra price, for example Large : 50';
  String get menuIncludesTitle =>
      isBn ? 'সেট-মিল আইটেম (ঐচ্ছিক)' : 'Included items (set meal)';
  String get menuIncludesHint =>
      isBn ? 'প্রতি লাইনে একটি আইটেম' : 'One item per line';
  String get menuAddOnsTitle =>
      isBn ? 'অ্যাড-অন (ঐচ্ছিক)' : 'Add-ons (optional)';
  String get menuAddOnsHint =>
      isBn ? 'প্রতি লাইন: নাম : দাম' : 'One per line: name : price';
  String get menuDiscountSummary => isBn ? 'ছাড়' : 'Discount';
  String get menuDeliveryCharge => isBn ? 'ডেলিভারি চার্জ' : 'Delivery charge';
  String get menuDeliveryChargeSubtitle => isBn
      ? 'ডেলিভারি অর্ডারে যোগ হওয়া নির্দিষ্ট চার্জ'
      : 'Flat charge added to delivery orders';
  String get menuDeliveryChargeHint => isBn ? 'যেমন ৬০' : 'For example, 60';
  String get menuDeliveryChargeInvalid =>
      isBn ? 'সঠিক চার্জ লিখুন' : 'Enter a valid charge';
  String get menuDeliveryChargeSaved =>
      isBn ? 'ডেলিভারি চার্জ সেভ হয়েছে' : 'Delivery charge saved';
  String get menuImageUploadWarning => isBn
      ? 'ছবি লোকালি রাখা হয়েছে। ইন্টারনেটে আপলোডের জন্য সংযোগ দরকার।'
      : 'Image kept locally. Cloud upload needs internet.';
  String get menuImageUploaded =>
      isBn ? 'ছবি ক্লাউডে আপলোড হয়েছে' : 'Image uploaded to cloud';
  String get menuImageSavedLocal => isBn
      ? 'ছবি লোকালি সেভ হয়েছে। ক্লাউড প্রস্তুত হলে সিঙ্ক হবে।'
      : 'Image saved locally. It will sync when cloud is ready.';

  // ── Hero media ─────────────────────────────────────────────────────────────
  String get heroMediaSubtitle => isBn
      ? 'কাস্টমার মেনু পেজের ফটো ও ভিডিও'
      : 'Photos & video on the customer menu page';
  String get heroPhotosTitle => isBn ? 'হিরো ফটো' : 'Hero Photos';
  String get heroPhotosSubtitle => isBn
      ? 'মেনু পেজের ক্যারোসেলে সর্বোচ্চ ৫টি ফটো দেখাবে।'
      : 'Up to 5 photos shown as a sliding carousel on the menu page hero.';
  String get heroLogoTitle => isBn ? 'রেস্টুরেন্ট লোগো' : 'Restaurant Logo';
  String get heroLogoSubtitle => isBn
      ? 'কাস্টমার মেনু হিরোতে রেস্টুরেন্টের লোগো দেখাবে।'
      : 'Shown as the restaurant mark on the customer menu hero.';
  String get heroAddLogo =>
      isBn ? 'রেস্টুরেন্ট লোগো যোগ করুন' : 'Add Restaurant Logo';
  String get heroReplaceLogo => isBn ? 'লোগো পরিবর্তন করুন' : 'Replace Logo';
  String get heroLogoUploaded => isBn ? 'লোগো আপলোড হয়েছে!' : 'Logo uploaded!';
  String get heroLogoSet => isBn ? 'লোগো সেট করা আছে' : 'Logo set';
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
  String itemsWithCount(int count) =>
      isBn ? '${_n(count)} টি আইটেম' : '$count items';
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

  // Ordering settings (spec §4.10)
  String get orderingSettings => isBn ? 'অর্ডারিং' : 'Ordering';
  String get orderingSettingsSubtitle =>
      isBn ? 'ভ্যাট, ডিসকাউন্ট ও চার্জ' : 'VAT, discounts & charges';
  String get vatRateLabel => isBn ? 'ভ্যাট হার (%)' : 'VAT rate (%)';
  String get serviceChargeLabel =>
      isBn ? 'সার্ভিস চার্জ (%)' : 'Service charge (%)';
  String get dailyTargetLabel =>
      isBn ? 'দৈনিক বিক্রির টার্গেট (৳)' : 'Daily sales target (৳)';
  String get dailyTargetHint => isBn
      ? 'লাইভ ট্যাবের পেস কার্ডে ব্যবহৃত। খালি রাখলে ডিফল্ট।'
      : 'Used by the Live tab pace card. Leave blank for default.';
  String get discountPresetsTitle =>
      isBn ? 'ডিসকাউন্ট প্রিসেট' : 'Discount presets';
  String get discountPresetsHint => isBn
      ? 'রিভিউ স্ক্রিনে দ্রুত ডিসকাউন্টের জন্য।'
      : 'Quick discounts on the Review screen.';
  String get addDiscountPreset => isBn ? 'প্রিসেট যোগ' : 'Add preset';
  String get presetLabelHint => isBn ? 'লেবেল' : 'Label';
  String get presetPercent => isBn ? '%' : '%';
  String get presetFlat => isBn ? '৳' : '৳';
  String get noDiscountPresets =>
      isBn ? 'কোনো প্রিসেট নেই' : 'No discount presets yet';
  String get orderingSaved =>
      isBn ? 'অর্ডারিং সেটিংস সেভ হয়েছে' : 'Ordering settings saved';
  String get orderingSaveFailed =>
      isBn ? 'সেভ করা যায়নি' : "Couldn't save settings";

  // Staff (spec §4.10)
  String staffActiveCount(int active, int total) => isBn
      ? '${_n(active)}/${_n(total)} জন সক্রিয়'
      : '$active of $total active';
  String get inviteStaffTitle => isBn ? 'স্টাফ আমন্ত্রণ' : 'Invite staff';
  String get inviteStaffCta => isBn ? 'স্টাফ যোগ করুন' : 'Invite staff';
  String get inviteAsRole => isBn ? 'যে রোলে আমন্ত্রণ' : 'Invite as';
  String get staffNameLabel => isBn ? 'নাম' : 'Name';
  String get staffPhoneLabel => isBn ? 'ফোন' : 'Phone';
  String get sendInvite => isBn ? 'আমন্ত্রণ পাঠান' : 'Send invite';
  String get inviteSent => isBn ? 'আমন্ত্রণ পাঠানো হয়েছে' : 'Invite sent';
  String get inviteFailed =>
      isBn ? 'আমন্ত্রণ পাঠানো যায়নি' : "Couldn't send invite";
  String get invitePending => isBn ? 'আমন্ত্রণ অপেক্ষমাণ' : 'Invite pending';
  String get staffActive => isBn ? 'সক্রিয়' : 'Active';
  String get staffInactive => isBn ? 'নিষ্ক্রিয়' : 'Inactive';
  String get noStaffHint => isBn
      ? 'নিচের আমন্ত্রণ বোতাম দিয়ে টিম যোগ করুন।'
      : 'Invite your team with the button below.';
  String get staffLoadFailed =>
      isBn ? 'স্টাফ লোড করা যায়নি' : "Couldn't load staff";
  String get managerOwnerOnly => isBn
      ? 'শুধু মালিক ম্যানেজার যোগ করতে পারেন'
      : 'Only an owner can add a manager';

  // Messages — Messenger takeover (spec §4.6)
  String get botLive => isBn ? 'বট চালু' : 'Bot live';
  String needsYouCount(int n) => isBn ? 'আপনার দরকার ${_n(n)}' : 'Needs you $n';
  String get allChats => isBn ? 'সব চ্যাট' : 'All chats';
  String get viaMessenger => isBn ? 'মেসেঞ্জারে' : 'via Messenger';
  String get chatbotNeedsHelp =>
      isBn ? 'চ্যাটবটের আপনার সাহায্য দরকার' : 'Chatbot needs your help';
  String get bytesBot => isBn ? 'বট' : 'BYTES BOT';
  String get writeReplyHint => isBn ? 'একটি উত্তর লিখুন…' : 'Write a reply…';
  String get handBackToBot => isBn ? 'বটের কাছে ফেরত' : 'Hand back to bot';
  String get handedBackToBot =>
      isBn ? 'বটের কাছে ফেরত দেওয়া হয়েছে' : 'Handed back to the bot';
  String get handedBackToYou =>
      isBn ? 'আপনার কাছে হস্তান্তর করা হয়েছে' : 'Handed back to you';
  String get noConversations =>
      isBn ? 'কোনো কথোপকথন নেই' : 'No conversations yet';
  String get noConversationsHint => isBn
      ? 'গ্রাহকদের মেসেঞ্জার চ্যাট এখানে দেখা যাবে।'
      : 'Customer Messenger chats will appear here.';
  String get chatsLoadFailed =>
      isBn ? 'চ্যাট লোড করা যায়নি' : "Couldn't load chats";
  String get replyFailed =>
      isBn ? 'উত্তর পাঠানো যায়নি' : "Couldn't send reply";
  String get sendImageComingSoon =>
      isBn ? 'ছবি পাঠানো শীঘ্রই আসছে' : 'Image send coming soon';
  String get imageMessage => isBn ? '📷 ছবি' : '📷 Image';
  String get noChatsNeedYou =>
      isBn ? 'কোনো চ্যাটে আপনার দরকার নেই' : 'No chats need you';

  // Audit trail (spec §4.10)
  String get auditAllFilter => isBn ? 'সব' : 'All';
  String get noAuditEntries =>
      isBn ? 'কোনো অডিট এন্ট্রি নেই' : 'No audit entries yet';
  String get auditEmptyHint => isBn
      ? 'ভয়েড, রিফান্ড, কম্প ও ডিসকাউন্ট ওভাররাইড এখানে দেখা যাবে।'
      : 'Voids, refunds, comps & discount overrides appear here.';
  String get auditLoadFailed =>
      isBn ? 'অডিট ট্রেইল লোড করা যায়নি' : "Couldn't load the audit trail";
  String auditOrderRef(int serial) =>
      isBn ? 'অর্ডার #${_n(serial)}' : 'Order #$serial';
  String get auditUnknownWho => isBn ? 'অজানা' : 'Unknown';

  // Control Tower (spec §4.9)
  String get liveOperations => isBn ? 'লাইভ অপারেশন' : 'Live operations';
  String get openOrdersStat => isBn ? 'চলমান অর্ডার' : 'Open orders';
  String get avgWaitStat => isBn ? 'গড় অপেক্ষা' : 'Avg wait';
  String pendingCountLabel(int n) =>
      isBn ? '${_n(n)} টি অপেক্ষমাণ' : '$n pending';
  String get orderChannelsNow =>
      isBn ? 'অর্ডার চ্যানেল · এখন' : 'Order channels · now';
  String orderWaitingMinutes(String serial, int mins) => isBn
      ? 'অর্ডার $serial · ${_n(mins)} মিনিট অপেক্ষায়'
      : 'Order $serial waiting ${mins}m';
  String get needsAccepting => isBn ? 'গ্রহণ করা দরকার' : 'needs accepting';
  String itemsBelowParAlert(int n) =>
      isBn ? '${_n(n)} টি আইটেম পার-এর নিচে' : '$n items below par';
  String get paceToTarget => isBn ? 'টার্গেটের দিকে গতি' : 'Pace to target';
  String get targetLabel => isBn ? 'টার্গেট' : 'target';
  String get expectedPaceNote => isBn
      ? 'এখনকার প্রত্যাশিত গতির সাপেক্ষে (মার্কার)'
      : 'vs. expected pace right now (marker)';
  String get ordersByStaff =>
      isBn ? 'স্টাফ অনুযায়ী অর্ডার' : 'Orders by staff';
  String get noStaffActivity =>
      isBn ? 'এখনো কোনো স্টাফ কার্যকলাপ নেই' : 'No staff activity yet';
  String get allClearLiveOps => isBn
      ? 'সব ঠিক আছে — কোনো সতর্কতা নেই'
      : 'All clear — no alerts right now';
  String get liveBadge => isBn ? 'লাইভ' : 'Live';

  // Dashboard — right now
  String get rightNow => isBn ? 'এই মুহূর্তে' : 'Right now';
  String get tablesSeated => isBn ? 'টেবিল বসা' : 'Tables seated';
  String get ordersInKitchen => isBn ? 'কিচেনে অর্ডার' : 'Orders in kitchen';
  String lateOverMinutes(int minutes) =>
      isBn ? '${_n(minutes)} মিনিটের বেশি দেরি' : 'Late over $minutes min';
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
  String varianceItems(int count) =>
      isBn ? '${_n(count)} টি আইটেম' : '$count items';
  String alertsCount(int count) =>
      isBn ? '${_n(count)} টি সতর্কতা' : '$count alerts';
  String get categoryRaw => isBn ? 'কাঁচা' : 'Raw';
  String get categoryDry => isBn ? 'শুকনা' : 'Dry';
  String get categoryPackaged => isBn ? 'প্যাকেট' : 'Packaged';
  String get categoryOther => isBn ? 'অন্যান্য' : 'Other';
  String get colItem => isBn ? 'আইটেম' : 'ITEM';
  String get colOnHand => isBn ? 'বর্তমান' : 'ON HAND';
  String get colNet => isBn ? 'নিট' : 'NET';
  String get colInOut => isBn ? 'ইন/আউট' : 'IN/OUT';
  String get colVar => isBn ? 'ভ্যার' : 'VAR';
  String get statusOk => isBn ? 'ঠিক' : 'OK';
  String get statusLow => isBn ? 'কম' : 'LOW';
  String get statusOut => isBn ? 'শেষ' : 'OUT';
  String get stockIn => isBn ? 'স্টক ইন' : 'Stock in';
  String get startCount => isBn ? 'গণনা শুরু' : 'Start count';
  // Stock (spec §4.7 ranked table)
  String get stockValue => isBn ? 'স্টক মূল্য' : 'Stock value';
  String get belowPar => isBn ? 'পার-এর নিচে' : 'Below par';
  String belowParItems(int count) =>
      isBn ? '${_n(count)} টি আইটেম' : '$count items';
  // Stock over time (spec §4.7 advanced)
  String get stockOverTime => isBn ? 'সময়ের সাথে স্টক' : 'Stock over time';
  String get wholeInventoryHealth =>
      isBn ? 'সম্পূর্ণ ইনভেন্টরির অবস্থা' : 'Whole-inventory health';
  String get allMeasures => isBn ? 'সব পরিমাপ' : 'All measures';
  String get daysOfCover => isBn ? 'কভারের দিন' : 'Days of cover';
  String get noTrendData => isBn
      ? 'প্রবণতা দেখানোর মতো যথেষ্ট ইতিহাস এখনও নেই।'
      : 'Not enough history yet to show a trend.';
  String get endOfDaySnapshots =>
      isBn ? 'দিনশেষের স্ন্যাপশট' : 'End-of-day snapshots';
  String get advanced => isBn ? 'অ্যাডভান্সড' : 'Advanced';
  String get advancedSection => isBn ? 'অ্যাডভান্সড' : 'Advanced';
  String get colValue => isBn ? 'মূল্য' : 'VALUE';
  String get colQty => isBn ? 'পরিমাণ' : 'QTY';
  String get colCover => isBn ? 'কভার' : 'COVER';
  String get countAction => isBn ? 'গণনা' : 'Count';
  String get stockItemDetailHint => isBn
      ? 'ব্যবহার ও সমন্বয়ের ইতিহাস দেখতে যেকোনো আইটেমে ট্যাপ করুন।'
      : 'Tap any item above for usage & adjustment history.';
  String get noStockItems =>
      isBn ? 'কোনো স্টক আইটেম নেই' : 'No stock items yet';
  String get addFirstStockItem => isBn
      ? 'প্রথম আইটেম যোগ করতে স্টক ইন ব্যবহার করুন।'
      : 'Use Stock in to add your first item.';
  // Variance drill-down
  String get dailyVariance => isBn ? 'দৈনিক ভ্যারিয়েন্স' : 'Daily variance';
  String get expectedVsCounted =>
      isBn ? 'প্রত্যাশিত বনাম গণনাকৃত · আজ' : 'Expected vs counted · today';
  String get varianceLoss => isBn ? 'ভ্যারিয়েন্স ক্ষতি' : 'Variance loss';
  String get itemsOff => isBn ? 'গরমিল আইটেম' : 'Items off';
  String get colSystem => isBn ? 'সিস্টেম' : 'SYSTEM';
  String get colCounted => isBn ? 'গণনাকৃত' : 'COUNTED';
  String get colDiff => isBn ? 'পার্থক্য' : 'DIFF';
  String get noVarianceToday =>
      isBn ? 'আজ কোনো ভ্যারিয়েন্স নেই।' : 'No variance recorded today.';
  String get shareVarianceReport =>
      isBn ? 'ভ্যারিয়েন্স রিপোর্ট শেয়ার' : 'Share variance report';
  // Suppliers drill-down
  String get suppliers => isBn ? 'সাপ্লায়ার' : 'Suppliers';
  String suppliersCount(int count) =>
      isBn ? '${_n(count)} টি সাপ্লায়ার' : '$count suppliers';
  String get addSupplier => isBn ? 'সাপ্লায়ার যোগ করুন' : 'Add supplier';
  String get noSuppliers => isBn ? 'কোনো সাপ্লায়ার নেই' : 'No suppliers yet';
  String get aiScanCount => isBn ? 'AI দিয়ে স্ক্যান' : 'AI scan';
  String get aiScanCountHint => isBn
      ? 'স্টক কাউন্ট শিট বা তাকের ছবি স্ক্যান করে পরিমাণ বসান।'
      : 'Scan a count sheet or shelf photo to fill quantities.';
  String get aiCountScanApplied => isBn
      ? 'AI স্ক্যান থেকে পরিমাণ বসানো হয়েছে'
      : 'AI scan filled matching counts';
  String get dailyReport => isBn ? 'দৈনিক রিপোর্ট' : 'Daily report';
  String get colTodayIn => isBn ? 'আজ ইন' : 'IN TODAY';
  String get colTodayOut => isBn ? 'আজ আউট' : 'OUT TODAY';
  String get usedTodayValue => isBn ? 'আজকের ব্যবহার' : 'Used today';
  String get unexplainedLossToday =>
      isBn ? 'আজকের অব্যাখ্যাত ক্ষতি' : 'Unexplained loss today';

  // Stock in flow
  String get stockInTitle => isBn ? 'স্টক ইন' : 'Stock in';
  String get stockInSubtitle =>
      isBn ? 'প্রাপ্ত স্টক যোগ করুন' : 'Add received stock';
  String get stockInConfirmTitle =>
      isBn ? 'স্টক ইন নিশ্চিত করুন' : 'Confirm stock-in';
  String get stockInScanSubtitle =>
      isBn ? 'স্ক্যান করা বিল থেকে' : 'From scanned bill';
  String get stockInScanReadHint => isBn
      ? 'বিল থেকে লাইন পড়া হয়েছে · যেকোনো মান ঠিক করুন'
      : 'lines read from the bill · tweak any value';
  String get totalStockInValue =>
      isBn ? 'মোট স্টক-ইন মূল্য' : 'Total stock-in value';
  String get addAnotherLine =>
      isBn ? 'আরেকটি লাইন যোগ করুন' : 'Add another line';
  String get addToInventory =>
      isBn ? 'ইনভেন্টরিতে যোগ করুন' : 'Add to inventory';
  String get scanBill => isBn ? 'বিল স্ক্যান করুন' : 'Scan bill';
  String get stockInQuantityLabel => isBn ? 'পরিমাণ' : 'Quantity';
  String stockInCostPerUnit(String unit) =>
      isBn ? 'খরচ / $unit' : 'Cost / $unit';
  String stepXofY(int step, int total) =>
      isBn ? 'ধাপ ${_n(step)} এর ${_n(total)}' : 'Step $step of $total';
  String get dateLabel => isBn ? 'তারিখ' : 'Date';
  String get scanSupplierBill =>
      isBn ? 'সরবরাহকারীর বিল স্ক্যান করুন' : 'Scan supplier bill';
  String get aiReadsItemsQtyPrices =>
      isBn ? 'AI আইটেম, পরিমাণ এবং দাম পড়ে' : 'AI reads items, qty, prices';
  String get addManually => isBn ? 'হাতে যোগ করুন' : 'add manually';
  String get addItem => isBn ? 'আইটেম যোগ করুন' : 'Add Item';
  String get stockInInventoryTitle =>
      isBn ? 'ইনভেন্টরি থেকে যোগ করুন' : 'Add from inventory';
  String get stockInInventoryHint =>
      isBn ? 'আইটেম খুঁজুন' : 'Search inventory items';
  String get stockInAlreadyAdded => isBn ? 'যোগ হয়েছে' : 'Added';
  String get stockInNoSavedItems =>
      isBn ? 'কোনো সংরক্ষিত আইটেম নেই' : 'No saved inventory items';
  String get stockInNoMatches =>
      isBn ? 'মিল পাওয়া যায়নি' : 'No matching inventory items';
  String get noSavedPrice => isBn ? 'দাম সেভ নেই' : 'No saved price';
  String get saveAndAddToStock =>
      isBn ? 'সেভ করুন ও স্টকে যোগ করুন' : 'Save & add to stock';
  String get qtyLabel => isBn ? 'পরিমাণ' : 'QTY';
  String pricePerUnit(String unit) => isBn ? 'মূল্য / $unit' : 'PRICE / $unit';
  String get newStockLabel => isBn ? 'নতুন স্টক' : 'NEW STOCK';
  String get stockInTotalCostLabel => isBn ? 'মোট খরচ' : 'TOTAL COST';
  String get scanningReceipt =>
      isBn ? 'রিসিট স্ক্যান হচ্ছে…' : 'Scanning receipt…';
  String get receiptScanFailed =>
      isBn ? 'রিসিট স্ক্যান ব্যর্থ হয়েছে' : 'Receipt scan failed';

  // Unified inventory scan (bill OR count sheet → auto-routed)
  String get scanStock => isBn ? 'স্ক্যান' : 'Scan';
  String get scanStockHint =>
      isBn ? 'বিল বা গণনার শিট' : 'Bill or count sheet';
  String get scanningStock => isBn ? 'স্ক্যান হচ্ছে…' : 'Scanning…';
  String get countScanUnmatched =>
      isBn ? 'মেলানো যায়নি' : 'Couldn\'t match';

  // Daily report
  String get unexplainedVariance =>
      isBn ? 'ব্যাখ্যাহীন ভ্যারিয়েন্স' : 'Unexplained variance';
  String get varianceBreakdown =>
      isBn ? 'ভ্যারিয়েন্স বিশ্লেষণ' : 'Variance breakdown';
  String acrossItems(int count) =>
      isBn ? '${_n(count)} টি আইটেমে' : 'across $count items';
  String recurringWeeks(int weeks) =>
      isBn ? '${_n(weeks)} সপ্তাহ ধরে' : '$weeks wks in a row';
  String get expectedCountedLabel =>
      isBn ? 'প্রত্যাশিত বনাম গণনাকৃত' : 'expected vs counted';
  String get reorderSuggestion => isBn ? 'অর্ডার সাজেশন' : 'Reorder suggestion';
  String get share => isBn ? 'শেয়ার' : 'Share';

  // Reports + sync
  String get reportsSubtitle => isBn
      ? 'বিক্রি, অর্ডার এবং PDF এক্সপোর্ট।'
      : 'Sales, orders, and PDF export.';
  String get exportPdf => isBn ? 'PDF এক্সপোর্ট' : 'Export PDF';
  String get pdfExportFailed =>
      isBn ? 'PDF এক্সপোর্ট ব্যর্থ হয়েছে' : 'PDF export failed';
  String get noOrdersInThisPeriod =>
      isBn ? 'এই সময়ে কোনো অর্ডার নেই' : 'No orders in this period';
  String get ordersAppearInReports => isBn
      ? 'কাস্টমার বা স্টাফ অর্ডার তৈরি করলে এখানে দেখাবে।'
      : 'Orders will appear here after customers or staff create them.';
  String get oneDay => isBn ? '১ দিন' : '1 Day';
  String get sevenDays => isBn ? '৭ দিন' : '7 Days';
  String get thirtyDays => isBn ? '৩০ দিন' : '30 Days';
  String get totalSales => isBn ? 'মোট বিক্রি' : 'Total sales';
  String get avgOrder => isBn ? 'গড় অর্ডার' : 'Avg order';
  String get itemsSold => isBn ? 'বিক্রি আইটেম' : 'Items sold';
  String get completed => isBn ? 'সম্পন্ন' : 'Completed';
  String get dailyBreakdown => isBn ? 'দৈনিক বিশ্লেষণ' : 'Daily breakdown';
  String get topSellingItems =>
      isBn ? 'শীর্ষ বিক্রি আইটেম' : 'Top selling items';
  String get syncStatusTitle => isBn ? 'সিঙ্ক অবস্থা' : 'Sync Status';
  String get syncStatusSubtitle => isBn
      ? 'ক্লাউড তালিকা, ব্যর্থ ইভেন্ট, পুনরায় চেষ্টা এবং স্বাস্থ্য পরীক্ষা।'
      : 'Cloud queue, failed events, retries, and health checks.';
  String get noSyncEvents => isBn ? 'কোনো সিঙ্ক ইভেন্ট নেই' : 'No sync events';
  String get queuedChangesWillAppear => isBn
      ? 'ক্লাউডে পাঠানোর আগে অপেক্ষমাণ পরিবর্তনগুলো এখানে দেখাবে।'
      : 'Queued changes will appear here before cloud delivery.';

  // Generic loading + offline banners
  String get liveMetricsOffline =>
      isBn ? 'লাইভ মেট্রিক্স অফলাইন' : 'Live metrics offline';
  String get pullToRefresh => isBn ? 'রিফ্রেশ করতে টানুন' : 'Pull to refresh';
}
