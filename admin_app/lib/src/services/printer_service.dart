import 'dart:async';
import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_strings.dart';
import '../core/utils/bounded_string_set.dart';
import '../models/desktop_pos.dart';
import '../models/order_item.dart';
import '../models/order_model.dart';
import '../models/order_service_type.dart';
import '../models/order_source.dart';
import '../models/order_status.dart';
import 'ticket_bitmap.dart';

class BluetoothPrinterDevice {
  BluetoothPrinterDevice({required this.name, required this.address});

  final String name;
  final String address;

  String get label => name.trim().isEmpty ? address : name.trim();
}

enum PrinterTransport { none, builtIn, usb, windowsUsb, bluetooth }

class PrinterRuntimeState {
  PrinterRuntimeState({
    required this.autoPrintEnabled,
    required this.connected,
    required this.busy,
    this.activeTransport = PrinterTransport.none,
    this.builtInPrinterAvailable = false,
    this.usbPrinterAvailable = false,
    this.selectedPrinterName,
    this.selectedPrinterAddress,
    this.selectedWindowsQueueName,
    this.windowsPaperWidthMm = 58,
    this.lastError,
    this.lastPrintedOrderNo,
    this.lastPrintedAt,
  });

  final bool autoPrintEnabled;
  final bool connected;
  final bool busy;
  final PrinterTransport activeTransport;
  final bool builtInPrinterAvailable;
  final bool usbPrinterAvailable;
  final String? selectedPrinterName;
  final String? selectedPrinterAddress;
  final String? selectedWindowsQueueName;
  final int windowsPaperWidthMm;
  final String? lastError;
  final String? lastPrintedOrderNo;
  final DateTime? lastPrintedAt;

  bool get hasSelectedPrinter {
    return usbPrinterAvailable ||
        selectedWindowsQueueName?.trim().isNotEmpty == true ||
        selectedPrinterAddress != null &&
            selectedPrinterAddress!.trim().isNotEmpty;
  }

  String get selectedPrinterLabel {
    if (activeTransport == PrinterTransport.usb ||
        activeTransport == PrinterTransport.none && usbPrinterAvailable) {
      return 'USB printer (type-C)';
    }
    if (activeTransport == PrinterTransport.windowsUsb ||
        selectedWindowsQueueName?.trim().isNotEmpty == true) {
      return selectedWindowsQueueName!;
    }
    final name = selectedPrinterName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return selectedPrinterAddress ?? 'No printer selected';
  }

  PrinterRuntimeState copyWith({
    bool? autoPrintEnabled,
    bool? connected,
    bool? busy,
    PrinterTransport? activeTransport,
    bool? builtInPrinterAvailable,
    bool? usbPrinterAvailable,
    String? selectedPrinterName,
    String? selectedPrinterAddress,
    String? selectedWindowsQueueName,
    int? windowsPaperWidthMm,
    String? lastError,
    String? lastPrintedOrderNo,
    DateTime? lastPrintedAt,
    bool clearLastError = false,
    bool clearPrinter = false,
  }) {
    return PrinterRuntimeState(
      autoPrintEnabled: autoPrintEnabled ?? this.autoPrintEnabled,
      connected: connected ?? this.connected,
      busy: busy ?? this.busy,
      activeTransport: activeTransport ?? this.activeTransport,
      builtInPrinterAvailable:
          builtInPrinterAvailable ?? this.builtInPrinterAvailable,
      usbPrinterAvailable: usbPrinterAvailable ?? this.usbPrinterAvailable,
      selectedPrinterName: clearPrinter
          ? null
          : selectedPrinterName ?? this.selectedPrinterName,
      selectedPrinterAddress: clearPrinter
          ? null
          : selectedPrinterAddress ?? this.selectedPrinterAddress,
      selectedWindowsQueueName: clearPrinter
          ? null
          : selectedWindowsQueueName ?? this.selectedWindowsQueueName,
      windowsPaperWidthMm: windowsPaperWidthMm ?? this.windowsPaperWidthMm,
      lastError: clearLastError ? null : lastError ?? this.lastError,
      lastPrintedOrderNo: lastPrintedOrderNo ?? this.lastPrintedOrderNo,
      lastPrintedAt: lastPrintedAt ?? this.lastPrintedAt,
    );
  }

  // Value equality so the controller can skip notifyListeners() on no-op
  // emits, and so the AppModel printer-aspect diff doesn't rebuild printer
  // widgets when nothing actually changed. The stream emits a fresh instance
  // on every internal poke (connection probe, busy toggle), many identical.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterRuntimeState &&
          autoPrintEnabled == other.autoPrintEnabled &&
          connected == other.connected &&
          busy == other.busy &&
          activeTransport == other.activeTransport &&
          builtInPrinterAvailable == other.builtInPrinterAvailable &&
          usbPrinterAvailable == other.usbPrinterAvailable &&
          selectedPrinterName == other.selectedPrinterName &&
          selectedPrinterAddress == other.selectedPrinterAddress &&
          selectedWindowsQueueName == other.selectedWindowsQueueName &&
          windowsPaperWidthMm == other.windowsPaperWidthMm &&
          lastError == other.lastError &&
          lastPrintedOrderNo == other.lastPrintedOrderNo &&
          lastPrintedAt == other.lastPrintedAt;

  @override
  int get hashCode => Object.hash(
    autoPrintEnabled,
    connected,
    busy,
    activeTransport,
    builtInPrinterAvailable,
    usbPrinterAvailable,
    selectedPrinterName,
    selectedPrinterAddress,
    selectedWindowsQueueName,
    windowsPaperWidthMm,
    lastError,
    lastPrintedOrderNo,
    lastPrintedAt,
  );
}

/// Localised receipt labels — switches between English and Bangla.
class _ReceiptLabels {
  _ReceiptLabels(this.language) : _bn = language == AppLanguage.bn;

  final AppLanguage language;
  final bool _bn;

  String get managerCopy => _bn ? 'ম্যানেজার কপি' : 'Manager Copy';
  String get customerCopy => _bn ? 'কাস্টমার কপি' : 'Customer Copy';
  String get orderNoLabel => _bn ? 'অর্ডার নং:' : 'Order No:';
  String get orderLabel => _bn ? 'অর্ডার:' : 'Order:';
  String get dateLabel => _bn ? 'তারিখ:' : 'Date:';
  String get staffLabel => _bn ? 'স্টাফ:' : 'Staff:';
  String get sourceHeading => _bn ? 'সোর্স:' : 'Source:';
  String get scanQrLabel => _bn ? 'লাইভ অর্ডার দেখুন' : 'SCAN FOR LIVE ORDER DETAILS';
  String get indexHeader => _bn ? 'ইনডেক্স' : 'INDEX';
  String get qtyHeader => _bn ? 'পরিমাণ' : 'QTY';
  String get descriptionHeader => _bn ? 'বিবরণ' : 'DESCRIPTION';
  String get priceHeader => _bn ? 'মূল্য' : 'PRICE';
  String orderNo(String seq) => '$orderNoLabel ${digits(seq)}';
  String tableLabel(String t) => _bn ? 'টেবিল ${digits(t)}' : 'Table $t';
  String get takeaway => _bn ? 'টেকওয়ে' : 'Takeaway';
  String get nameLabel => _bn ? 'নাম' : 'Name';
  String get noteLabel => _bn ? 'নোট' : 'Note';
  String get addressLabel => _bn ? 'ঠিকানা' : 'Address';
  String get phoneLabel => _bn ? 'মোবাইল' : 'Phone';
  String get total => _bn ? 'মোট' : 'Total';
  String get vatIncluded => _bn ? 'ভ্যাটসহ' : 'VAT included';
  String get totalVatIncluded =>
      _bn ? '$total ($vatIncluded)' : '$total ($vatIncluded)';
  String get emptyItemName => _bn ? 'আইটেম' : 'Item';
  String get defaultRestaurantName => _bn ? 'রেস্টুরেন্ট' : 'Restaurant';
  String get kotLabel => _bn ? 'কিচেন অর্ডার' : 'KITCHEN ORDER';
  String qrCaption(bool isDelivery) => isDelivery
      ? _bn ? 'ডেলিভারি ট্র্যাক করুন' : 'Track your delivery'
      : _bn ? 'আপনার অর্ডার ট্র্যাক করুন' : 'Scan to track your order';

  String get _locale => _bn ? 'bn_BD' : 'en_US';
  String pick(String en, String bn) => _bn ? bn : en;
  String qtyText(int qty) => '${digits('$qty')}x';
  String itemName(OrderItem item) {
    final value = item.localizedName(language);
    return value.trim().isEmpty ? emptyItemName : value.trim();
  }

  String money(num amount) {
    final rounded = amount.roundToDouble();
    final value = NumberFormat.decimalPatternDigits(
      locale: _locale,
      decimalDigits: (amount - rounded).abs() < 0.005 ? 0 : 2,
    ).format(amount);
    return digits('$value/-');
  }

  String digits(String value) {
    if (!_bn) return value;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    var output = value;
    for (var i = 0; i < en.length; i++) {
      output = output.replaceAll(en[i], bn[i]);
    }
    return output;
  }

  String sourceLabel(OrderSource source) {
    switch (source) {
      case OrderSource.cloud:
        return _bn ? 'ক্লাউড / ওয়েব' : 'Cloud / web';
      case OrderSource.facebookMessenger:
        return 'Messenger';
      case OrderSource.whatsapp:
        return 'WhatsApp';
      case OrderSource.manual:
        return _bn ? 'ম্যানুয়াল' : 'Manual';
      case OrderSource.desktopPos:
        return _bn ? 'ডেস্কটপ POS' : 'Desktop POS';
      case OrderSource.localLan:
        return _bn ? 'লিগ্যাসি LAN' : 'Legacy LAN';
    }
  }

  String formatDate(DateTime dt) {
    if (!_bn) {
      return DateFormat(
        'dd MMM yyyy - h.mm a',
      ).format(dt.toLocal()).replaceAll('AM', 'am').replaceAll('PM', 'pm');
    }
    const months = [
      'জানু',
      'ফেব্রু',
      'মার্চ',
      'এপ্রি',
      'মে',
      'জুন',
      'জুলাই',
      'আগ',
      'সেপ্ট',
      'অক্টো',
      'নভে',
      'ডিসে',
    ];
    final local = dt.toLocal();
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'অপরাহ্ন' : 'সকাল';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return digits(
      '${local.day} ${months[local.month - 1]} ${local.year} - '
      '$h12.$minute $period',
    );
  }
}

class PrinterService {
  // SUNMI / built-in printer support is intentionally disabled for this mobile
  // app. Keep the native Android bridge in place for the future terminal app,
  // but do not invoke it from this Dart service.
  // static const MethodChannel _builtInPrinterChannel = MethodChannel(
  //   'com.terabyteai.foodmania/built_in_printer',
  // );
  static const MethodChannel _usbPrinterChannel = MethodChannel(
    'com.terabyteai.foodmania/usb_printer',
  );
  static const MethodChannel _windowsPrinterChannel = MethodChannel(
    'com.terabyteai.foodmania/windows_printer',
  );

  static const String _autoPrintKey = 'printer_auto_print_enabled';
  static const String _printerNameKey = 'printer_selected_name';
  static const String _printerAddressKey = 'printer_selected_address';
  static const String _printerTransportKey = 'printer_selected_transport';
  static const String _printedOrderIdsKey = 'printer_printed_order_ids';
  static const String _windowsQueueKey = 'printer_windows_queue';
  static const String _windowsPaperWidthKey = 'printer_windows_paper_width_mm';
  static const int _ticketWidth = 32;
  // Print-speed target: 90 mm/sec (GS ( E density/speed command).
  static const int debugTargetPrintSpeedMmPerSecond = 180;
  // Extra line feeds after the last printed pixel so the tear-off point clears
  // the printer housing. ESC d n feeds n lines (≈1 mm each on 58 mm paper).
  // We bypass esc_pos_utils Generator.cut(), which prepends 5 raw newlines,
  // so this is the exact trailing gap before the full cut (GS V 0).
  static const int _trailingFeedLines = 4;

  // Full cut (GS V 0) with an explicit feed instead of Generator.cut(),
  // whose built-in emptyLines(5) added ~5 mm of blank paper per ticket.
  static List<int> _trailingFeedAndCut(
    Generator generator, {
    int feedLines = _trailingFeedLines,
  }) =>
      <int>[...generator.feed(feedLines), 0x1D, 0x56, 0x30];

  static const List<int> _targetPrintSpeed90MmPerSecond = [
    0x1D,
    0x28,
    0x45,
    0x04,
    0x00,
    0x05,
    0x05,
    debugTargetPrintSpeedMmPerSecond,
    0x00,
  ];

  final StreamController<PrinterRuntimeState> _stateController =
      StreamController<PrinterRuntimeState>.broadcast();

  PrinterRuntimeState _state = PrinterRuntimeState(
    autoPrintEnabled: true,
    connected: false,
    busy: false,
  );
  // Bounded so a long-running session that prints thousands of tickets never
  // grows this set (and its persisted copy) without limit.
  final BoundedStringSet _printedOrderIds = BoundedStringSet(cap: 2000);
  int _printerAttemptSeq = 0;


  PrinterRuntimeState get state => _state;
  Stream<PrinterRuntimeState> get stateStream => _stateController.stream;

  String _nextPrinterAttempt(String action) {
    final id = 'printer-${++_printerAttemptSeq}-$action';
    if (kDebugMode) {
      debugPrint('[QB-PRINTER-DIAG] $id START ${_printerStateSummary()}');
    }
    return id;
  }

  String _printerStateSummary() {
    return 'platform android=${Platform.isAndroid} ios=${Platform.isIOS} '
        'macos=${Platform.isMacOS} windows=${Platform.isWindows} '
        'linux=${Platform.isLinux} transport=${_state.activeTransport.name} '
        'auto=${_state.autoPrintEnabled} busy=${_state.busy} '
        'connected=${_state.connected} usb=${_state.usbPrinterAvailable} '
        'btName="${_state.selectedPrinterName ?? ''}" '
        'btAddress=${_state.selectedPrinterAddress ?? ''} '
        'systemQueue="${_state.selectedWindowsQueueName ?? ''}" '
        'lastError="${_state.lastError ?? ''}"';
  }

  void _logPrinterDiag(String attemptId, String message) {
    if (!kDebugMode) return;
    debugPrint('[QB-PRINTER-DIAG] $attemptId $message');
  }

  void _logPrinterEnd(String attemptId, String result) {
    if (!kDebugMode) return;
    debugPrint(
      '[QB-PRINTER-DIAG] $attemptId END result=$result ${_printerStateSummary()}',
    );
  }

  bool get _supportsSystemPrinterQueues =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool get supportsDirectBluetoothPrinting =>
      Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isWindows;

  bool get _hasSelectedSystemPrinter =>
      _supportsSystemPrinterQueues &&
      (_state.selectedWindowsQueueName?.trim().isNotEmpty ?? false);

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final local = await _probeLocalPrinters();
    final selectedSystemQueue = preferences.getString(_windowsQueueKey);
    final hasSystemQueue =
        _supportsSystemPrinterQueues &&
        (selectedSystemQueue?.trim().isNotEmpty ?? false);
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] initialize builtInAvailable=${local.builtIn} '
        'usbAvailable=${local.usb}',
      );
    }
    _printedOrderIds
      ..clear()
      ..addAll(preferences.getStringList(_printedOrderIdsKey) ?? []);
    // Do not touch the Bluetooth plugin during app boot. Some Android devices
    // wait on the native connection-status call until Bluetooth permission/state
    // is ready, which can keep the splash screen open. We check live status only
    // when the user opens printer actions or when printing.
    final savedTransport = preferences.getString(_printerTransportKey);
    final activeTransport = hasSystemQueue
        ? PrinterTransport.windowsUsb
        : savedTransport != null &&
              (preferences.getString(_printerAddressKey)?.trim().isNotEmpty ==
                      true ||
                  local.preferred != PrinterTransport.none)
        ? PrinterTransport.values.firstWhere(
            (t) => t.name == savedTransport,
            orElse: () => local.preferred,
          )
        : local.preferred;
    _emit(
      _state.copyWith(
        autoPrintEnabled: preferences.getBool(_autoPrintKey) ?? true,
        selectedPrinterName: preferences.getString(_printerNameKey),
        selectedPrinterAddress: preferences.getString(_printerAddressKey),
        selectedWindowsQueueName: selectedSystemQueue,
        windowsPaperWidthMm: preferences.getInt(_windowsPaperWidthKey) ?? 58,
        activeTransport: activeTransport,
        builtInPrinterAvailable: local.builtIn,
        usbPrinterAvailable: local.usb,
        connected:
            local.preferred != PrinterTransport.none ||
            hasSystemQueue ||
            preferences.getString(_printerAddressKey)?.trim().isNotEmpty ==
                true,
        clearLastError: true,
      ),
    );
  }

  Future<List<String>> listWindowsPrinterQueues() async {
    return listSystemPrinterQueues();
  }

  Future<List<String>> listSystemPrinterQueues() async {
    if (!_supportsSystemPrinterQueues) return const [];
    final names = <String>{};
    if (Platform.isWindows) {
      try {
        final windowsPrinters =
            await _windowsPrinterChannel.invokeListMethod<String>(
              'listPrinters',
            ) ??
            const [];
        names.addAll(
          windowsPrinters
              .map((name) => name.trim())
              .where((name) => name.isNotEmpty),
        );
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[QB-PRINTER] Windows queue list failed: $error');
        }
      }
    }
    try {
      final printers = await Printing.listPrinters();
      names.addAll(
        printers
            .map((printer) => printer.name.trim())
            .where((name) => name.isNotEmpty),
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] System queue list failed: $error');
      }
    }
    final sorted = names.toList()..sort();
    return sorted;
  }

  Future<void> selectWindowsPrinterQueue(
    String queueName, {
    int paperWidthMm = 58,
  }) async {
    return selectSystemPrinterQueue(queueName, paperWidthMm: paperWidthMm);
  }

  Future<void> selectSystemPrinterQueue(
    String queueName, {
    int paperWidthMm = 58,
  }) async {
    if (!_supportsSystemPrinterQueues) {
      throw PrinterException(
        'USB/system printer selection is supported on desktop only.',
      );
    }
    final clean = queueName.trim();
    if (clean.isEmpty) {
      throw PrinterException('Select a USB/system printer first.');
    }
    final width = paperWidthMm == 80 ? 80 : 58;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_windowsQueueKey, clean);
    await preferences.setInt(_windowsPaperWidthKey, width);
    await preferences.setString(
      _printerTransportKey,
      PrinterTransport.windowsUsb.name,
    );
    _emit(
      _state.copyWith(
        activeTransport: PrinterTransport.windowsUsb,
        selectedWindowsQueueName: clean,
        windowsPaperWidthMm: width,
        connected: true,
        clearLastError: true,
      ),
    );
  }

  Future<bool> connectLocalUsbPrinterAuto() async {
    final attemptId = _nextPrinterAttempt('connect-usb');
    return _withBusyBool(() async {
      _logPrinterDiag(attemptId, 'connectLocalUsbPrinterAuto enter');
      if (_hasSelectedSystemPrinter) {
        final selected = _state.selectedWindowsQueueName?.trim() ?? '';
        final queues = await listSystemPrinterQueues();
        _logPrinterDiag(
          attemptId,
          'systemQueue selected="$selected" available=${queues.length}',
        );
        if (selected.isNotEmpty && queues.contains(selected)) {
          _emit(
            _state.copyWith(
              activeTransport: PrinterTransport.windowsUsb,
              connected: true,
              clearLastError: true,
            ),
          );
          _logPrinterEnd(attemptId, 'selected-system-queue-ok');
          return true;
        }
        throw PrinterException(
          'The selected USB/system printer is unavailable.',
        );
      }

      if (_supportsSystemPrinterQueues) {
        final queues = await listSystemPrinterQueues();
        _logPrinterDiag(attemptId, 'systemQueue available=${queues.length}');
        if (queues.length == 1) {
          await selectSystemPrinterQueue(
            queues.single,
            paperWidthMm: _state.windowsPaperWidthMm,
          );
          return true;
        }
        if (queues.length > 1) {
          throw PrinterException('Choose a USB/system printer from the list.');
        }
      }

      final local = await _probeLocalPrinters(diagId: attemptId);
      _logPrinterDiag(
        attemptId,
        'localProbe builtIn=${local.builtIn} usb=${local.usb} '
        'preferred=${local.preferred.name}',
      );
      if (local.preferred != PrinterTransport.none) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString(_printerTransportKey, local.preferred.name);
        _emit(
          _state.copyWith(
            activeTransport: local.preferred,
            builtInPrinterAvailable: local.builtIn,
            usbPrinterAvailable: local.usb,
            connected: true,
            clearLastError: true,
          ),
        );
        _logPrinterEnd(attemptId, 'local-usb-ok');
        return true;
      }

      throw PrinterException(
        'No USB printer found. Plug in a USB printer or use Bluetooth.',
      );
    }, diagId: attemptId);
  }

  Future<bool> printWindowsPdfFallback(
    OrderModel order, {
    String? restaurantName,
    String? outletName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    AppLanguage language = AppLanguage.en,
    bool isManagerCopy = false,
  }) async {
    return printSystemPdfFallback(
      order,
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      restaurantPhone: restaurantPhone,
      language: language,
      isManagerCopy: isManagerCopy,
    );
  }

  Future<bool> printSystemPdfFallback(
    OrderModel order, {
    String? restaurantName,
    String? outletName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    AppLanguage language = AppLanguage.en,
    bool isManagerCopy = false,
  }) async {
    if (!_hasSelectedSystemPrinter) return false;
    final selected = _state.selectedWindowsQueueName?.trim() ?? '';
    if (selected.isEmpty) return false;
    try {
      final printers = await Printing.listPrinters();
      Printer? printer;
      for (final item in printers) {
        if (item.name == selected) {
          printer = item;
          break;
        }
      }
      if (printer == null) {
        throw PrinterException(
          'The selected USB/system printer is unavailable.',
        );
      }
      final pngBytes = await _buildBitmapCopyPng(
        order,
        labels: _ReceiptLabels(language),
        isManagerCopy: isManagerCopy,
        restaurantName: restaurantName ?? 'HYBRID POS',
        restaurantAddress: restaurantAddress,
        restaurantPhone: restaurantPhone,
      );
      final bitmap = img.decodePng(pngBytes);
      if (bitmap == null) {
        throw PrinterException('Could not decode rendered ticket bitmap.');
      }
      final document = pw.Document();
      final width = _state.windowsPaperWidthMm.toDouble();
      final receiptHeight = width * bitmap.height / bitmap.width;
      final pageFormat = PdfPageFormat(
        width * PdfPageFormat.mm,
        receiptHeight * PdfPageFormat.mm,
      );
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.fitWidth),
        ),
      );
      final ok = await Printing.directPrintPdf(
        printer: printer,
        name: 'Receipt ${order.displaySequence}',
        format: pageFormat,
        usePrinterSettings: true,
        onLayout: (_) => document.save(),
      );
      _emit(
        _state.copyWith(
          activeTransport: ok
              ? PrinterTransport.windowsUsb
              : PrinterTransport.none,
          connected: ok,
          clearLastError: ok,
        ),
      );
      return ok;
    } catch (error) {
      _emit(
        _state.copyWith(lastError: _friendlyError(error), connected: false),
      );
      return false;
    }
  }

  Future<bool> printSystemKotPdfFallback(
    OrderModel order, {
    String? restaurantName,
    AppLanguage language = AppLanguage.en,
    String? serverName,
  }) async {
    if (!_hasSelectedSystemPrinter) return false;
    final selected = _state.selectedWindowsQueueName?.trim() ?? '';
    if (selected.isEmpty) return false;
    try {
      final printers = await Printing.listPrinters();
      Printer? printer;
      for (final item in printers) {
        if (item.name == selected) {
          printer = item;
          break;
        }
      }
      if (printer == null) {
        throw PrinterException(
          'The selected USB/system printer is unavailable.',
        );
      }
      final pngBytes = await _buildKotBitmapPng(
        order,
        labels: _ReceiptLabels(language),
        restaurantName: restaurantName ?? 'HYBRID POS',
        serverName: serverName,
      );
      final bitmap = img.decodePng(pngBytes);
      if (bitmap == null) {
        throw PrinterException('Could not decode rendered KOT bitmap.');
      }
      final document = pw.Document();
      final width = _state.windowsPaperWidthMm.toDouble();
      final receiptHeight = width * bitmap.height / bitmap.width;
      final pageFormat = PdfPageFormat(
        width * PdfPageFormat.mm,
        receiptHeight * PdfPageFormat.mm,
      );
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.fitWidth),
        ),
      );
      final ok = await Printing.directPrintPdf(
        printer: printer,
        name: 'KOT ${order.displaySequence}',
        format: pageFormat,
        usePrinterSettings: true,
        onLayout: (_) => document.save(),
      );
      _emit(
        _state.copyWith(
          activeTransport: ok
              ? PrinterTransport.windowsUsb
              : PrinterTransport.none,
          connected: ok,
          clearLastError: ok,
        ),
      );
      return ok;
    } catch (error) {
      _emit(
        _state.copyWith(lastError: _friendlyError(error), connected: false),
      );
      return false;
    }
  }

  /// Lists paired Bluetooth printers without starting location-sensitive
  /// Android discovery. Pairing remains a system-settings responsibility.
  Future<List<BluetoothPrinterDevice>> refreshPairedPrinters() async {
    final attemptId = _nextPrinterAttempt('refresh-bluetooth');
    _emit(_state.copyWith(busy: true, clearLastError: true));
    try {
      await _ensureBluetoothReady(diagId: attemptId);

      final devices = await PrintBluetoothThermal.pairedBluetooths;
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] refreshPairedPrinters paired=${devices.length}',
        );
      }
      return devices
          .map(
            (d) => BluetoothPrinterDevice(name: d.name, address: d.macAdress),
          )
          .toList(growable: false);
    } catch (error) {
      final friendly = _friendlyError(error);
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] refreshPairedPrinters caught: $error '
          '(${error.runtimeType}) '
          'friendly="$friendly"',
        );
      }
      _emit(_state.copyWith(lastError: friendly));
      return [];
    } finally {
      final local = await _probeLocalPrinters(diagId: attemptId);
      final bluetoothConnected = await _readBluetoothConnectionStatus(
        diagId: attemptId,
      );
      _emit(
        _state.copyWith(
          busy: false,
          activeTransport: _activeTransport(local, bluetoothConnected),
          builtInPrinterAvailable: local.builtIn,
          usbPrinterAvailable: local.usb,
          connected:
              local.preferred != PrinterTransport.none || bluetoothConnected,
        ),
      );
      _logPrinterEnd(attemptId, 'paired-refresh-finally');
    }
  }

  Future<bool> connect(BluetoothPrinterDevice printer) async {
    final attemptId = _nextPrinterAttempt('connect-bluetooth');
    return _withBusyBool(() async {
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] connect requested name="${printer.name}" '
          'address=${printer.address}',
        );
      }
      await _ensureBluetoothReady(diagId: attemptId);
      final before = await _readBluetoothConnectionStatus(diagId: attemptId);
      _logPrinterDiag(attemptId, 'btConnectionBefore=$before');
      final connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.address,
      );
      final after = await _readBluetoothConnectionStatus(diagId: attemptId);
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] connect result=$connected '
          'connectionAfter=$after',
        );
      }
      if (!connected) {
        throw PrinterException('Could not connect to the selected printer.');
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_printerNameKey, printer.name);
      await preferences.setString(_printerAddressKey, printer.address);
      await preferences.setString(
        _printerTransportKey,
        PrinterTransport.bluetooth.name,
      );
      _emit(
        _state.copyWith(
          activeTransport: PrinterTransport.bluetooth,
          selectedPrinterName: printer.name,
          selectedPrinterAddress: printer.address,
          connected: true,
          clearLastError: true,
        ),
      );
      _logPrinterEnd(attemptId, 'bluetooth-connected');
      return true;
    }, diagId: attemptId);
  }

  Future<bool> disconnect() async {
    return _withBusyBool(() async {
      final disconnected = await PrintBluetoothThermal.disconnect;
      final local = await _probeLocalPrinters();
      _emit(
        _state.copyWith(
          activeTransport: local.preferred,
          builtInPrinterAvailable: local.builtIn,
          usbPrinterAvailable: local.usb,
          connected: local.preferred != PrinterTransport.none || !disconnected,
          clearLastError: true,
        ),
      );
      return disconnected;
    });
  }

  Future<void> setAutoPrintEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_autoPrintKey, value);
    _emit(_state.copyWith(autoPrintEnabled: value, clearLastError: true));
  }

  Future<bool> testPrint({
    required String restaurantName,
    required String outletName,
    String restaurantAddress = '',
    String restaurantPhone = '',
  }) async {
    final attemptId = _nextPrinterAttempt('test-print');
    return _withBusyBool(() async {
      await _ensureAnyPrinterReady(diagId: attemptId);
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      final now = DateTime.now();
      final testOrder = OrderModel(
        id: 'printer-diagnostic',
        orderNo: 'PRINTER-DIAGNOSTIC',
        sequenceNo: 101,
        status: OrderStatus.accepted,
        source: OrderSource.manual,
        subtotal: 325,
        vatRatePercent: 0,
        vatAmount: 0,
        total: 325,
        createdAt: now,
        updatedAt: now,
        items: [
          OrderItem(
            id: 'printer-diagnostic-line-1',
            orderId: 'printer-diagnostic',
            menuItemId: 'diagnostic-tea',
            name: 'Diagnostic Tea',
            nameEn: 'Diagnostic Tea',
            qty: 1,
            price: 125,
            lineTotal: 125,
          ),
          OrderItem(
            id: 'printer-diagnostic-line-2',
            orderId: 'printer-diagnostic',
            menuItemId: 'diagnostic-rice',
            name: 'Diagnostic Rice Bowl',
            nameEn: 'Diagnostic Rice Bowl',
            qty: 2,
            price: 100,
            lineTotal: 200,
          ),
        ],
      );
      final bytes = await _buildBitmapCopyBytes(
        generator,
        testOrder,
        labels: _ReceiptLabels(AppLanguage.en),
        isManagerCopy: true,
        restaurantName: restaurantName.trim().isEmpty
            ? 'HYBRID POS'
            : restaurantName,
        restaurantAddress: restaurantAddress,
        restaurantPhone: restaurantPhone,
      );
      _logPrinterDiag(attemptId, 'testPrint bytes=${bytes.length}');
      var ok = await _writeBytes(bytes, diagId: attemptId);
      if (!ok && _hasSelectedSystemPrinter) {
        _logPrinterDiag(attemptId, 'trying system PDF fallback');
        ok = await printSystemPdfFallback(
          testOrder,
          restaurantName: restaurantName,
          restaurantAddress: restaurantAddress,
          restaurantPhone: restaurantPhone,
          language: AppLanguage.en,
          isManagerCopy: true,
        );
      }
      _debugPrintWriteResult(
        testOrder,
        copyKind: 'diagnostic',
        byteCount: bytes.length,
        ok: ok,
      );
      if (!ok) throw PrinterException('Test print failed.');
      _emit(_state.copyWith(clearLastError: true));
      _logPrinterEnd(attemptId, 'test-print-ok');
      return true;
    }, diagId: attemptId);
  }

  Future<bool> printOrderTicket(
    OrderModel order, {
    required String restaurantName,
    required String outletName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    AppLanguage language = AppLanguage.en,
    bool markAsPrinted = true,
    String? orderDetailsUrl,
    String? serverName,
  }) async {
    final attemptId = _nextPrinterAttempt('print-kot-${order.id}');
    return _withBusyBool(() async {
      await _ensureAnyPrinterReady(diagId: attemptId);
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      final labels = _ReceiptLabels(language);

      final kotBytes = await _buildKotBitmapBytes(
        generator,
        order,
        labels: labels,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
        restaurantPhone: restaurantPhone,
        serverName: serverName,
      );
      _logPrinterDiag(
        attemptId,
        'printOrderTicket kotBytes=${kotBytes.length}',
      );
      var okKot = await _writeBytes(kotBytes, diagId: attemptId);
      if (!okKot && _hasSelectedSystemPrinter) {
        _logPrinterDiag(attemptId, 'trying system PDF fallback KOT');
        okKot = await printSystemKotPdfFallback(
          order,
          restaurantName: restaurantName,
          language: language,
          serverName: serverName,
        );
      }
      _debugPrintWriteResult(
        order,
        copyKind: 'kot',
        byteCount: kotBytes.length,
        ok: okKot,
      );
      if (!okKot) {
        throw PrinterException('Printing KOT of ${order.orderNo} failed.');
      }

      if (markAsPrinted) {
        await markOrderPrinted(order);
      }
      _emit(
        _state.copyWith(
          lastPrintedOrderNo: order.orderNo,
          lastPrintedAt: DateTime.now(),
          clearLastError: true,
        ),
      );
      _logPrinterEnd(attemptId, 'print-kot-ok');
      return true;
    }, diagId: attemptId);
  }

  Future<bool> printCustomerInvoice(
    OrderModel order, {
    required String restaurantName,
    required String outletName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    AppLanguage language = AppLanguage.en,
    String? orderDetailsUrl,
    String? serverRole,
  }) async {
    final attemptId = _nextPrinterAttempt('print-bill-${order.id}');
    return _withBusyBool(() async {
      await _ensureAnyPrinterReady(diagId: attemptId);
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      final labels = _ReceiptLabels(language);
      final customerCopyBytes = await _buildBitmapCopyBytes(
        generator,
        order,
        labels: labels,
        isManagerCopy: false,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
        restaurantPhone: restaurantPhone,
        orderDetailsUrl: orderDetailsUrl,
        serverRole: serverRole,
      );
      _logPrinterDiag(
        attemptId,
        'printCustomerInvoice bytes=${customerCopyBytes.length}',
      );
      var ok = await _writeBytes(customerCopyBytes, diagId: attemptId);
      if (!ok && _hasSelectedSystemPrinter) {
        _logPrinterDiag(attemptId, 'trying system PDF fallback customer copy');
        ok = await printSystemPdfFallback(
          order,
          restaurantName: restaurantName,
          restaurantAddress: restaurantAddress,
          restaurantPhone: restaurantPhone,
          language: language,
        );
      }
      _debugPrintWriteResult(
        order,
        copyKind: 'customer',
        byteCount: customerCopyBytes.length,
        ok: ok,
      );
      if (!ok) {
        throw PrinterException(
          'Printing customer invoice of ${order.orderNo} failed.',
        );
      }
      _emit(
        _state.copyWith(
          lastPrintedOrderNo: order.orderNo,
          lastPrintedAt: DateTime.now(),
          clearLastError: true,
        ),
      );
      _logPrinterEnd(attemptId, 'print-bill-ok');
      return true;
    }, diagId: attemptId);
  }

  Future<bool> printDeliveryDispatchCopy(
    OrderModel order, {
    required String restaurantName,
    required String outletName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    AppLanguage language = AppLanguage.en,
    String? driverNote,
  }) async {
    final attemptId = _nextPrinterAttempt('print-dispatch-${order.id}');
    return _withBusyBool(() async {
      await _ensureAnyPrinterReady(diagId: attemptId);
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      final labels = _ReceiptLabels(language);
      final data = _buildDispatchTicketData(
        order,
        labels: labels,
        driverNote: driverNote,
      );
      final bytes = await _buildUtilityBitmapBytes(generator, data);
      var ok = await _writeBytes(bytes, diagId: attemptId);
      if (!ok && _hasSelectedSystemPrinter) {
        ok = await _printSystemUtilityPdfFallback(
          data,
          name: 'Dispatch ${order.displaySequence}',
        );
      }
      if (!ok) {
        throw PrinterException(
          'Printing dispatch copy of ${order.orderNo} failed.',
        );
      }
      _emit(
        _state.copyWith(
          lastPrintedOrderNo: order.orderNo,
          lastPrintedAt: DateTime.now(),
          clearLastError: true,
        ),
      );
      _logPrinterEnd(attemptId, 'print-dispatch-ok');
      return true;
    }, diagId: attemptId);
  }

  Future<bool> printVoidWasteTicket(
    OrderModel order, {
    required String action,
    required String reason,
    required String restaurantName,
    required String outletName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    AppLanguage language = AppLanguage.en,
    String? cashierName,
    double? value,
  }) async {
    final attemptId = _nextPrinterAttempt('print-void-${order.id}');
    return _withBusyBool(() async {
      await _ensureAnyPrinterReady(diagId: attemptId);
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      final labels = _ReceiptLabels(language);
      final data = _buildVoidWasteTicketData(
        order,
        labels: labels,
        action: action,
        reason: reason,
        cashierName: cashierName,
        value: value,
      );
      final bytes = await _buildUtilityBitmapBytes(generator, data);
      var ok = await _writeBytes(bytes, diagId: attemptId);
      if (!ok && _hasSelectedSystemPrinter) {
        ok = await _printSystemUtilityPdfFallback(
          data,
          name: 'Void ${order.displaySequence}',
        );
      }
      if (!ok) {
        throw PrinterException(
          'Printing void/waste ticket of ${order.orderNo} failed.',
        );
      }
      _emit(
        _state.copyWith(
          lastPrintedOrderNo: order.orderNo,
          lastPrintedAt: DateTime.now(),
          clearLastError: true,
        ),
      );
      _logPrinterEnd(attemptId, 'print-void-ok');
      return true;
    }, diagId: attemptId);
  }

  Future<bool> printEndOfDayReport({
    required PosReportSnapshot report,
    PosShift? shift,
    required String restaurantName,
    required String outletName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    AppLanguage language = AppLanguage.en,
    String? managerName,
  }) async {
    final attemptId = _nextPrinterAttempt('print-end-of-day');
    return _withBusyBool(() async {
      await _ensureAnyPrinterReady(diagId: attemptId);
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      final labels = _ReceiptLabels(language);
      final data = _buildEndOfDayTicketData(
        report: report,
        shift: shift,
        labels: labels,
        restaurantName: restaurantName,
        outletName: outletName,
        managerName: managerName,
      );
      final bytes = await _buildUtilityBitmapBytes(generator, data);
      var ok = await _writeBytes(bytes, diagId: attemptId);
      if (!ok && _hasSelectedSystemPrinter) {
        ok = await _printSystemUtilityPdfFallback(
          data,
          name: labels.pick('End of day report', 'দিন শেষ রিপোর্ট'),
        );
      }
      if (!ok) {
        throw PrinterException('Printing end of day report failed.');
      }
      _emit(
        _state.copyWith(
          lastPrintedOrderNo: labels.pick('End of day', 'দিন শেষ'),
          lastPrintedAt: DateTime.now(),
          clearLastError: true,
        ),
      );
      _logPrinterEnd(attemptId, 'print-end-of-day-ok');
      return true;
    }, diagId: attemptId);
  }

  Future<bool> printTableQrLabel({
    required String tableLabel,
    required String qrUrl,
    String? restaurantName,
  }) async {
    final attemptId = _nextPrinterAttempt('print-table-qr-$tableLabel');
    return _withBusyBool(() async {
      await _ensureAnyPrinterReady(diagId: attemptId);
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      final bytes = await _buildTableQrLabelBytes(
        generator,
        tableLabel,
        qrUrl,
        restaurantName: restaurantName,
      );
      var ok = await _writeBytes(bytes, diagId: attemptId);
      if (!ok && _hasSelectedSystemPrinter) {
        ok = await _printSystemTableQrPdfFallback(
          tableLabel,
          qrUrl,
          restaurantName: restaurantName,
        );
      }
      if (!ok) {
        throw PrinterException('Printing QR label for $tableLabel failed.');
      }
      _emit(
        _state.copyWith(
          lastPrintedOrderNo: tableLabel,
          lastPrintedAt: DateTime.now(),
          clearLastError: true,
        ),
      );
      _logPrinterEnd(attemptId, 'print-table-qr-ok');
      return true;
    }, diagId: attemptId);
  }

  Future<List<int>> _buildTableQrLabelBytes(
    Generator generator,
    String tableLabel,
    String qrUrl, {
    String? restaurantName,
  }) async {
    final paperWidthPx = (_paperSize == PaperSize.mm80 ? 576 : 384).toDouble();
    debugPrint(
      '[QB-PRINTER-DIAG] _buildTableQrLabelBytes tableLabel="$tableLabel" paperWidthPx=$paperWidthPx',
    );
    final pngBytes = await TicketBitmapRenderer.renderTableQrLabel(
      tableLabel: tableLabel,
      qrUrl: qrUrl,
      restaurantName: restaurantName,
      paperWidthPx: paperWidthPx,
    );
    debugPrint(
      '[QB-PRINTER-DIAG] _buildTableQrLabelBytes pngBytes=${pngBytes.length}',
    );

    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      throw PrinterException('Could not decode table QR label bitmap.');
    }
    debugPrint(
      '[QB-PRINTER-DIAG] _buildTableQrLabelBytes decoded width=${decoded.width} height=${decoded.height}',
    );

    final raster = Platform.isWindows && _state.windowsPaperWidthMm == 80
        ? img.copyResize(decoded, width: 576)
        : decoded;
    final bytes = <int>[
      ...generator.reset(),
      ..._targetPrintSpeed90MmPerSecond,
      ...generator.imageRaster(raster, align: PosAlign.left),
      ..._trailingFeedAndCut(generator, feedLines: 4),
    ];
    debugPrint(
      '[QB-PRINTER-DIAG] _buildTableQrLabelBytes escPosBytes=${bytes.length}',
    );
    return bytes;
  }

  Future<bool> _printSystemTableQrPdfFallback(
    String tableLabel,
    String qrUrl, {
    String? restaurantName,
  }) async {
    if (!_hasSelectedSystemPrinter) return false;
    final selected = _state.selectedWindowsQueueName?.trim() ?? '';
    if (selected.isEmpty) return false;
    try {
      final printers = await Printing.listPrinters();
      Printer? printer;
      for (final item in printers) {
        if (item.name == selected) {
          printer = item;
          break;
        }
      }
      if (printer == null) return false;
      final pngBytes = await TicketBitmapRenderer.renderTableQrLabel(
        tableLabel: tableLabel,
        qrUrl: qrUrl,
        restaurantName: restaurantName,
        paperWidthPx: _state.windowsPaperWidthMm == 80 ? 576 : 384,
      );
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            _state.windowsPaperWidthMm == 80 ? 80 : 58,
            120,
            marginAll: 4,
          ),
          build: (_) => pw.Center(child: pw.Image(pw.MemoryImage(pngBytes))),
        ),
      );
      final pageFormat = PdfPageFormat(
        _state.windowsPaperWidthMm == 80 ? 80 : 58,
        120,
        marginAll: 4,
      );
      await Printing.directPrintPdf(
        printer: printer,
        name: 'Table-QR-$tableLabel',
        format: pageFormat,
        usePrinterSettings: true,
        onLayout: (_) => doc.save(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Uint8List> _buildKotBitmapPng(
    OrderModel order, {
    required _ReceiptLabels labels,
    required String restaurantName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    String? serverName,
  }) async {
    final cleanRestaurant = restaurantName.trim();
    final resolvedRestaurant = cleanRestaurant.isEmpty
        ? labels.defaultRestaurantName
        : cleanRestaurant;
    final data = _buildKotTicketData(
      order,
      labels: labels,
      restaurantName: resolvedRestaurant,
      restaurantSubtitle: _restaurantSubtitle(
        labels: labels,
        address: restaurantAddress,
        phone: restaurantPhone,
      ),
      serverName: serverName,
    );
    return TicketBitmapRenderer.renderKot(data);
  }

  Future<List<int>> _buildKotBitmapBytes(
    Generator generator,
    OrderModel order, {
    required _ReceiptLabels labels,
    required String restaurantName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    String? serverName,
  }) async {
    final pngBytes = await _buildKotBitmapPng(
      order,
      labels: labels,
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      restaurantPhone: restaurantPhone,
      serverName: serverName,
    );
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      throw PrinterException('Could not decode rendered KOT bitmap.');
    }
    _debugPrintBitmapResult(
      order,
      copyKind: 'kot',
      pngByteCount: pngBytes.length,
      width: decoded.width,
      height: decoded.height,
    );
    final raster = Platform.isWindows && _state.windowsPaperWidthMm == 80
        ? img.copyResize(decoded, width: 576)
        : decoded;
    final bytes = <int>[
      ...generator.reset(),
      ..._targetPrintSpeed90MmPerSecond,
      ...generator.imageRaster(raster, align: PosAlign.left),
      ..._trailingFeedAndCut(generator),
    ];
    _debugPrintRasterResult(order, copyKind: 'kot', byteCount: bytes.length);
    return bytes;
  }

  /// Build one printable copy entirely as a bitmap and wrap it in ESC/POS
  /// reset / feed / cut commands. The bitmap path keeps the on-paper layout
  /// pixel-identical to the in-app preview regardless of printer firmware
  /// language support.
  Future<Uint8List> _buildBitmapCopyPng(
    OrderModel order, {
    required _ReceiptLabels labels,
    required bool isManagerCopy,
    required String restaurantName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    String? orderDetailsUrl,
    String? serverRole,
  }) async {
    final tableRaw = order.serviceType == OrderServiceType.delivery
        ? ''
        : order.tableNo ?? labels.takeaway;
    final dateText = labels.formatDate(order.createdAt);
    final effectiveTotal = _orderTotalFor(order);
    final isDelivery = order.serviceType == OrderServiceType.delivery;

    final items = <TicketLineItem>[
      for (var i = 0; i < order.items.length; i++)
        TicketLineItem(
          index: i + 1,
          name: labels.itemName(order.items[i]),
          qtyText: labels.qtyText(order.items[i].qty),
          lineTotalText: labels.money(_lineTotalFor(order.items[i])),
        ),
    ];

    final cleanRestaurant = restaurantName.trim();
    final resolvedRestaurant = cleanRestaurant.isEmpty
        ? labels.defaultRestaurantName
        : cleanRestaurant;
    _debugPrintTicketData(
      order,
      copyKind: isManagerCopy ? 'manager' : 'customer',
      restaurantName: resolvedRestaurant,
      sourceRestaurantName: restaurantName,
      effectiveTotal: effectiveTotal,
      labels: labels,
    );
    final data = TicketCopyData(
      restaurantName: resolvedRestaurant,
      outletName: null,
      restaurantSubtitle: null,
      orderNumberDisplay: order.displaySequence,
      orderTypeLabel: _orderTypeLabel(order, labels),
      orderLabel: labels.orderLabel,
      dateLine: dateText,
      dateLabel: labels.dateLabel,
      tableLine: labels.tableLabel(tableRaw),
      staffLabel: labels.staffLabel,
      sourceLine: labels.sourceLabel(order.source),
      items: items,
      totalLabel: labels.totalVatIncluded,
      totalAmount: labels.money(effectiveTotal),
      totalNote: '',
      isManagerCopy: isManagerCopy,
      customerName: order.customerName,
      customerNameLabel: labels.nameLabel,
      note: isManagerCopy ? order.note : null,
      noteLabel: labels.noteLabel,
      orderDetailsUrl: orderDetailsUrl,
      deliveryAddress: order.deliveryAddress,
      deliveryAddressLabel: labels.addressLabel,
      mobileNumber: order.mobileNumber,
      mobileNumberLabel: labels.phoneLabel,
      summaryRows: _receiptSummaryRows(order, labels: labels),
      paymentLine: _paymentLine(order, labels),
      qrCaption: labels.qrCaption(isDelivery),
      footerText: isDelivery
          ? null
          : labels.pick('Thank you for dining!', 'ধন্যবাদ!'),
      serverRole: serverRole,
    );

    final pngBytes = await TicketBitmapRenderer.render(data);
    return pngBytes;
  }

  Future<List<int>> _buildBitmapCopyBytes(
    Generator generator,
    OrderModel order, {
    required _ReceiptLabels labels,
    required bool isManagerCopy,
    required String restaurantName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    String? orderDetailsUrl,
    String? serverRole,
  }) async {
    final pngBytes = await _buildBitmapCopyPng(
      order,
      labels: labels,
      isManagerCopy: isManagerCopy,
      restaurantName: restaurantName,
      restaurantAddress: restaurantAddress,
      restaurantPhone: restaurantPhone,
      orderDetailsUrl: orderDetailsUrl,
      serverRole: serverRole,
    );
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      throw PrinterException('Could not decode rendered ticket bitmap.');
    }
    _debugPrintBitmapResult(
      order,
      copyKind: isManagerCopy ? 'manager' : 'customer',
      pngByteCount: pngBytes.length,
      width: decoded.width,
      height: decoded.height,
    );
    // Resize for 80 mm paper on Windows; otherwise use as-rendered.
    final raster = Platform.isWindows && _state.windowsPaperWidthMm == 80
        ? img.copyResize(decoded, width: 576)
        : decoded;

    // The QR code is rendered inline into the receipt bitmap (top-right
    // corner) by [TicketBitmapRenderer]. We deliberately do NOT use the
    // ESC/POS `qrcode` command here because many thermal printers ignore the
    // size byte and render a huge QR regardless of [QRSize.size1].
    final bytes = <int>[
      ...generator.reset(),
      ..._targetPrintSpeed90MmPerSecond,
      ...generator.imageRaster(raster, align: PosAlign.left),
      ..._trailingFeedAndCut(generator),
    ];
    _debugPrintRasterResult(
      order,
      copyKind: isManagerCopy ? 'manager' : 'customer',
      byteCount: bytes.length,
    );
    return bytes;
  }

  Future<List<int>> _buildUtilityBitmapBytes(
    Generator generator,
    UtilityTicketData data,
  ) async {
    final pngBytes = await TicketBitmapRenderer.renderUtility(data);
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      throw PrinterException('Could not decode rendered utility ticket.');
    }
    final raster = Platform.isWindows && _state.windowsPaperWidthMm == 80
        ? img.copyResize(decoded, width: 576)
        : decoded;
    return <int>[
      ...generator.reset(),
      ..._targetPrintSpeed90MmPerSecond,
      ...generator.imageRaster(raster, align: PosAlign.left),
      ..._trailingFeedAndCut(generator),
    ];
  }

  Future<bool> _printSystemUtilityPdfFallback(
    UtilityTicketData data, {
    required String name,
  }) async {
    if (!_hasSelectedSystemPrinter) return false;
    final selected = _state.selectedWindowsQueueName?.trim() ?? '';
    if (selected.isEmpty) return false;
    try {
      final printers = await Printing.listPrinters();
      Printer? printer;
      for (final item in printers) {
        if (item.name == selected) {
          printer = item;
          break;
        }
      }
      if (printer == null) {
        throw PrinterException(
          'The selected USB/system printer is unavailable.',
        );
      }
      final pngBytes = await TicketBitmapRenderer.renderUtility(data);
      final bitmap = img.decodePng(pngBytes);
      if (bitmap == null) {
        throw PrinterException('Could not decode rendered utility ticket.');
      }
      final document = pw.Document();
      final width = _state.windowsPaperWidthMm.toDouble();
      final receiptHeight = width * bitmap.height / bitmap.width;
      final pageFormat = PdfPageFormat(
        width * PdfPageFormat.mm,
        receiptHeight * PdfPageFormat.mm,
      );
      document.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (_) =>
              pw.Image(pw.MemoryImage(pngBytes), fit: pw.BoxFit.fitWidth),
        ),
      );
      final ok = await Printing.directPrintPdf(
        printer: printer,
        name: name,
        format: pageFormat,
        usePrinterSettings: true,
        onLayout: (_) => document.save(),
      );
      _emit(
        _state.copyWith(
          activeTransport: ok
              ? PrinterTransport.windowsUsb
              : PrinterTransport.none,
          connected: ok,
          clearLastError: ok,
        ),
      );
      return ok;
    } catch (error) {
      _emit(
        _state.copyWith(lastError: _friendlyError(error), connected: false),
      );
      return false;
    }
  }

  List<TicketSummaryRow> _receiptSummaryRows(
    OrderModel order, {
    required _ReceiptLabels labels,
  }) {
    final subtotal = _orderSubtotalFor(order);
    final discount = order.discountAmount.abs();
    final service = order.serviceChargeAmount;
    final delivery = order.deliveryCharge;
    final total = _orderTotalFor(order);
    final rows = <TicketSummaryRow>[
      TicketSummaryRow(
        label: labels.pick('Subtotal', 'সাবটোটাল'),
        value: labels.money(subtotal),
      ),
    ];
    if (discount > 0) {
      final discountSuffix = order.discountLabel?.trim().isNotEmpty == true
          ? ' (${order.discountLabel!.trim()})'
          : '';
      rows.add(
        TicketSummaryRow(
          label: labels.pick('Discount', 'ডিসকাউন্ট'),
          value: '-${labels.money(discount)}$discountSuffix',
        ),
      );
    }
    if (service > 0) {
      rows.add(
        TicketSummaryRow(
          label: labels.pick('Service charge', 'সার্ভিস চার্জ'),
          value: labels.money(service),
        ),
      );
    }
    if (delivery > 0) {
      rows.add(
        TicketSummaryRow(
          label: labels.pick('Delivery fee', 'ডেলিভারি ফি'),
          value: labels.money(delivery),
        ),
      );
    }
    rows.add(
      TicketSummaryRow(
        label: labels.total,
        value: labels.money(total),
        emphasis: true,
      ),
    );
    return rows;
  }

  UtilityTicketData _buildDispatchTicketData(
    OrderModel order, {
    required _ReceiptLabels labels,
    String? driverNote,
  }) {
    final customer = order.customerName?.trim();
    final phone = order.mobileNumber?.trim();
    final address = order.deliveryAddress?.trim();
    final note = driverNote?.trim();
    return UtilityTicketData(
      title: labels.pick('DELIVERY COPY', 'ডেলিভারি কপি'),
      warning: labels.pick('DO NOT SHOW TO CUSTOMER', 'কাস্টমারকে দেখাবেন না'),
      headerRows: [
        TicketSummaryRow(
          label: labels.pick('Order #', 'অর্ডার #'),
          value: labels.orderNo(order.displaySequence),
          emphasis: true,
        ),
        TicketSummaryRow(
          label: labels.pick('Token', 'টোকেন'),
          value: _tokenFor(order, labels),
        ),
        TicketSummaryRow(
          label: labels.pick('Placed', 'সময়'),
          value: labels.digits(
            DateFormat('HH:mm').format(order.createdAt.toLocal()),
          ),
        ),
      ],
      sections: [
        UtilityTicketSection(
          title: labels.pick('CUSTOMER', 'কাস্টমার'),
          lines: [if (customer != null && customer.isNotEmpty) customer],
        ),
        UtilityTicketSection(
          title: labels.pick('PHONE (CALL IF LOST)', 'ফোন'),
          lines: [if (phone != null && phone.isNotEmpty) labels.digits(phone)],
        ),
        UtilityTicketSection(
          title: labels.pick('ADDRESS', 'ঠিকানা'),
          lines: [if (address != null && address.isNotEmpty) address],
        ),
        UtilityTicketSection(
          title: labels.pick('ITEMS TO DELIVER', 'ডেলিভারি আইটেম'),
          lines: [
            for (final item in order.items)
              '[${labels.digits('${item.qty}')}] ${labels.itemName(item)}',
          ],
        ),
        if (note != null && note.isNotEmpty)
          UtilityTicketSection(
            title: labels.pick('NOTES FOR DRIVER', 'ড্রাইভার নোট'),
            lines: [note],
          ),
      ],
      footerLines: [
        labels.pick('Customer Signature:', 'কাস্টমার সিগনেচার:'),
        '',
        '____________________________',
      ],
    );
  }

  UtilityTicketData _buildVoidWasteTicketData(
    OrderModel order, {
    required _ReceiptLabels labels,
    required String action,
    required String reason,
    String? cashierName,
    double? value,
  }) {
    final total = value ?? _orderSubtotalFor(order);
    return UtilityTicketData(
      title: labels.pick('VOID / WASTE TICKET', 'ভয়েড / ওয়েস্ট টিকেট'),
      headerRows: [
        TicketSummaryRow(
          label: labels.pick('Time', 'সময়'),
          value: labels.digits(DateFormat('HH:mm').format(DateTime.now())),
        ),
        if (cashierName?.trim().isNotEmpty == true)
          TicketSummaryRow(
            label: labels.pick('Cashier', 'ক্যাশিয়ার'),
            value: cashierName!.trim(),
          ),
        TicketSummaryRow(
          label: labels.pick('Action', 'অ্যাকশন'),
          value: action.toUpperCase(),
        ),
        TicketSummaryRow(label: labels.pick('Reason', 'কারণ'), value: reason),
      ],
      sections: [
        UtilityTicketSection(
          title: labels.pick('VOIDED ITEMS', 'ভয়েড আইটেম'),
          lines: [
            for (final item in order.items)
              '[${labels.digits('${item.qty}')}] ${labels.itemName(item)}',
          ],
        ),
      ],
      totalRows: [
        TicketSummaryRow(
          label: labels.pick('Original order', 'মূল অর্ডার'),
          value: labels.orderNo(order.displaySequence),
        ),
        TicketSummaryRow(
          label: labels.pick('Value', 'মূল্য'),
          value: labels.money(total),
          emphasis: true,
        ),
        TicketSummaryRow(
          label: _vatIncludedLabel(order, labels),
          value: labels.money(_includedVatFor(order, total)),
        ),
      ],
      footerLines: ['Built by QuickBytes POS'],
    );
  }

  UtilityTicketData _buildEndOfDayTicketData({
    required PosReportSnapshot report,
    PosShift? shift,
    required _ReceiptLabels labels,
    required String restaurantName,
    String outletName = '',
    String restaurantAddress = '',
    String restaurantPhone = '',
    String? managerName,
  }) {
    final now = DateTime.now();
    final grossSales = report.sales + report.discounts;
    final cashSales = report.paymentSplit['cash'] ?? 0;
    final shiftText = shift == null
        ? labels.pick('Today', 'আজ')
        : '${labels.digits(DateFormat('h:mm a').format(shift.openedAt.toLocal()))} - '
              '${labels.digits(DateFormat('h:mm a').format((shift.closedAt ?? now).toLocal()))}';
    return UtilityTicketData(
      title: labels.pick('END OF DAY REPORT', 'দিন শেষ রিপোর্ট'),
      subtitle: restaurantName.trim().isEmpty ? outletName : restaurantName,
      headerRows: [
        TicketSummaryRow(
          label: labels.pick('Date', 'তারিখ'),
          value: labels.digits(DateFormat('yyyy-MM-dd').format(now)),
        ),
        TicketSummaryRow(label: labels.pick('Shift', 'শিফট'), value: shiftText),
        if (managerName?.trim().isNotEmpty == true)
          TicketSummaryRow(
            label: labels.pick('Manager', 'ম্যানেজার'),
            value: managerName!.trim(),
          ),
      ],
      totalRows: [
        TicketSummaryRow(
          label: labels.pick('GROSS SALES', 'গ্রস সেলস'),
          value: labels.money(grossSales),
        ),
        TicketSummaryRow(
          label: labels.pick('DISCOUNTS', 'ডিসকাউন্ট'),
          value: '-${labels.money(report.discounts)}',
        ),
        TicketSummaryRow(
          label: labels.pick('NET SALES', 'নিট সেলস'),
          value: labels.money(report.sales),
          emphasis: true,
        ),
        TicketSummaryRow(
          label: labels.pick('VAT Included', 'ভ্যাট অন্তর্ভুক্ত'),
          value: labels.money(report.vatIncluded),
        ),
        TicketSummaryRow(
          label: labels.pick('DELIVERY FEES', 'ডেলিভারি ফি'),
          value: labels.money(report.deliveryFees),
        ),
        TicketSummaryRow(
          label: labels.pick('TOTAL REVENUE', 'মোট রেভিনিউ'),
          value: labels.money(report.sales + report.deliveryFees),
          emphasis: true,
        ),
        TicketSummaryRow(
          label: labels.pick('Cash', 'ক্যাশ'),
          value: labels.money(cashSales),
        ),
        TicketSummaryRow(
          label: labels.pick('TOTAL ORDERS', 'মোট অর্ডার'),
          value: labels.digits('${report.orders}'),
        ),
      ],
      sections: [
        UtilityTicketSection(
          title: labels.pick('SERVICE SPLIT', 'সার্ভিস বিভাজন'),
          lines: [
            '${labels.pick('Dine-in', 'ডাইন ইন')}: ${labels.digits('${report.serviceSplit['dine_in'] ?? 0}')}',
            '${labels.pick('Parcel', 'পার্সেল')}: ${labels.digits('${report.serviceSplit['takeaway'] ?? 0}')}',
            '${labels.pick('Delivery', 'ডেলিভারি')}: ${labels.digits('${report.serviceSplit['delivery'] ?? 0}')}',
          ],
        ),
      ],
      footerLines: [
        '${labels.pick('Printed', 'প্রিন্ট')}: ${labels.digits(DateFormat('HH:mm:ss').format(now))}',
        'Built by QuickBytes POS',
      ],
    );
  }

  Future<void> markOrderPrinted(OrderModel order) async {
    _printedOrderIds.add(order.id);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _printedOrderIdsKey,
      _printedOrderIds.toList(),
    );
  }

  bool hasPrintedOrder(String orderId) => _printedOrderIds.contains(orderId);

  Future<String> previewTicket(
    OrderModel order, {
    String? restaurantName,
    String? outletName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    AppLanguage language = AppLanguage.en,
    String? serverRole,
  }) async {
    final labels = _ReceiptLabels(language);
    final buffer = StringBuffer();
    _writePreviewCopy(
      buffer,
      order,
      labels: labels,
      isManagerCopy: true,
      restaurantName: restaurantName ?? 'HYBRID POS',
      restaurantAddress: restaurantAddress,
      restaurantPhone: restaurantPhone,
      serverRole: serverRole,
    );
    buffer.writeln();
    buffer.writeln(_separator('*'));
    buffer.writeln(_separator('*'));
    buffer.writeln();
    _writePreviewCopy(
      buffer,
      order,
      labels: labels,
      isManagerCopy: false,
      restaurantName: restaurantName ?? 'HYBRID POS',
      restaurantAddress: restaurantAddress,
      restaurantPhone: restaurantPhone,
      serverRole: serverRole,
    );
    return buffer.toString();
  }

  void _writePreviewCopy(
    StringBuffer buffer,
    OrderModel order, {
    required _ReceiptLabels labels,
    required bool isManagerCopy,
    required String restaurantName,
    required String restaurantAddress,
    required String restaurantPhone,
    String? serverRole,
  }) {
    final isDelivery = order.serviceType == OrderServiceType.delivery;
    final tableRaw = isDelivery
        ? ''
        : order.tableNo ?? labels.takeaway;
    final name = restaurantName.trim();
    buffer.writeln(_separator('='));
    buffer.writeln(_shortText(name.length > 24 ? name.substring(0, 24) : name, _ticketWidth));
    buffer.writeln(_orderTypeLabel(order, labels).toUpperCase());
    buffer.writeln('${labels.orderLabel} ${order.displaySequence}');
    buffer.writeln('${labels.dateLabel} ${labels.formatDate(order.createdAt)}');
    if (serverRole?.trim().isNotEmpty == true) {
      buffer.writeln('${labels.staffLabel} ${serverRole!.trim()}');
    } else {
      buffer.writeln('${labels.sourceHeading} ${labels.sourceLabel(order.source)}');
    }
    buffer.writeln(_separator('-'));
    buffer.writeln('${labels.indexHeader} ${labels.qtyHeader} ${labels.descriptionHeader}                      ${labels.priceHeader}');
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      final index = labels.digits((i + 1).toString().padLeft(3, '0'));
      final qty = labels.qtyText(item.qty);
      final desc = _shortText(labels.itemName(item), 20);
      final amount = labels.money(_lineTotalFor(item));
      buffer.writeln('$index $qty $desc $amount');
    }
    buffer.writeln(_separator('-'));
    buffer.write(_previewSummary(order, labels));
    buffer.writeln(_paymentLine(order, labels));
    if (order.customerName?.trim().isNotEmpty == true) {
      buffer.writeln('${labels.nameLabel}: ${order.customerName!.trim()}');
    }
    if (isDelivery) {
      if (order.deliveryAddress?.trim().isNotEmpty == true) {
        buffer.writeln('${labels.addressLabel}: ${order.deliveryAddress!.trim()}');
      }
      if (order.mobileNumber?.trim().isNotEmpty == true) {
        buffer.writeln('${labels.phoneLabel}: ${order.mobileNumber!.trim()}');
      }
    } else {
      if (tableRaw.trim().isNotEmpty) {
        buffer.writeln(labels.tableLabel(tableRaw));
      }
    }
    buffer.writeln(labels.scanQrLabel);
    buffer.writeln(_separator('='));
  }

  String _previewSummary(OrderModel order, _ReceiptLabels labels) {
    final buffer = StringBuffer();
    for (final row in _receiptSummaryRows(order, labels: labels)) {
      buffer.writeln(_twoCol(row.label, row.value));
    }
    return buffer.toString();
  }

  Future<String> previewKot(
    OrderModel order, {
    String? restaurantName,
    String? serverName,
    AppLanguage language = AppLanguage.en,
  }) async {
    final labels = _ReceiptLabels(language);
    final cleanRestaurant = (restaurantName ?? 'HYBRID POS').trim();
    final data = _buildKotTicketData(
      order,
      labels: labels,
      restaurantName: cleanRestaurant.isEmpty
          ? labels.defaultRestaurantName
          : cleanRestaurant,
      serverName: serverName,
    );
    final buffer = StringBuffer()
      ..writeln(data.title)
      ..writeln('${data.serialLabel}: ${data.serialValue}')
      ..writeln('${data.timeLabel}: ${data.timeValue}')
      ..writeln('${data.typeLabel}: ${data.typeValue}');
    if (data.tableLabel?.trim().isNotEmpty == true &&
        data.tableValue?.trim().isNotEmpty == true) {
      buffer.writeln('${data.tableLabel}: ${data.tableValue}');
    }
    buffer.writeln(data.itemsLabel);
    for (final item in data.items) {
      final mods = item.modifiers.trim();
      buffer.writeln(
        '${item.qtyText} x ${item.name}${mods.isEmpty ? '' : ' $mods'}',
      );
    }
    final notedItems = data.items
        .where((item) => item.note?.trim().isNotEmpty == true)
        .toList(growable: false);
    if (notedItems.isNotEmpty) {
      buffer.writeln(data.noteLabel);
      for (final item in notedItems) {
        buffer.writeln(item.note!.trim());
      }
    }
    final server = data.serverName?.trim();
    if (server != null && server.isNotEmpty) {
      buffer.writeln('${data.serverLabel}: $server');
    }
    return buffer.toString();
  }

  Future<String> previewDeliveryDispatchCopy(
    OrderModel order, {
    AppLanguage language = AppLanguage.en,
    String? driverNote,
  }) async {
    final labels = _ReceiptLabels(language);
    return _previewUtility(
      _buildDispatchTicketData(order, labels: labels, driverNote: driverNote),
    );
  }

  Future<String> previewVoidWasteTicket(
    OrderModel order, {
    required String action,
    required String reason,
    AppLanguage language = AppLanguage.en,
    String? cashierName,
    double? value,
  }) async {
    final labels = _ReceiptLabels(language);
    return _previewUtility(
      _buildVoidWasteTicketData(
        order,
        labels: labels,
        action: action,
        reason: reason,
        cashierName: cashierName,
        value: value,
      ),
    );
  }

  Future<String> previewEndOfDayReport({
    required PosReportSnapshot report,
    PosShift? shift,
    AppLanguage language = AppLanguage.en,
    String restaurantName = '',
    String outletName = '',
    String restaurantAddress = '',
    String restaurantPhone = '',
    String? managerName,
  }) async {
    final labels = _ReceiptLabels(language);
    return _previewUtility(
      _buildEndOfDayTicketData(
        report: report,
        shift: shift,
        labels: labels,
        restaurantName: restaurantName,
        outletName: outletName,
        restaurantAddress: restaurantAddress,
        restaurantPhone: restaurantPhone,
        managerName: managerName,
      ),
    );
  }

  String _previewUtility(UtilityTicketData data) {
    final buffer = StringBuffer();
    if (data.warning?.trim().isNotEmpty == true) {
      buffer.writeln(data.warning!.trim());
    }
    buffer.writeln(data.title);
    if (data.subtitle?.trim().isNotEmpty == true) {
      buffer.writeln(data.subtitle!.trim());
    }
    for (final row in data.headerRows) {
      buffer.writeln('${row.label}: ${row.value}');
    }
    for (final section in data.sections) {
      buffer.writeln(section.title);
      for (final line in section.lines) {
        buffer.writeln(line);
      }
    }
    for (final row in data.totalRows) {
      buffer.writeln('${row.label}: ${row.value}');
    }
    for (final line in data.footerLines) {
      buffer.writeln(line);
    }
    return buffer.toString();
  }

  double _lineTotalFor(OrderItem item) {
    final computed = item.price * item.qty;
    if (item.lineTotal > 0 || computed <= 0) return item.lineTotal;
    return computed;
  }

  double _orderSubtotalFor(OrderModel order) {
    final itemTotal = order.items.fold<double>(
      0,
      (total, item) => total + _lineTotalFor(item),
    );
    if (order.subtotal > 0) return order.subtotal;
    return itemTotal;
  }

  double _orderTotalFor(OrderModel order) {
    final itemTotal = order.items.fold<double>(
      0,
      (total, item) => total + _lineTotalFor(item),
    );
    if (order.total > 0) return order.totalAfterDiscount;
    if (order.subtotal > 0 || order.vatAmount > 0) {
      return order.subtotal +
          order.vatAmount +
          order.deliveryCharge +
          order.serviceChargeAmount -
          order.discountAmount;
    }
    if (itemTotal > 0) return itemTotal;
    return 0;
  }

  double _includedVatFor(OrderModel order, double total) {
    if (order.vatAmount > 0) return order.vatAmount;
    final rate = order.vatRatePercent;
    if (rate <= 0) return 0;
    return total * rate / (100 + rate);
  }

  String _vatIncludedLabel(OrderModel order, _ReceiptLabels labels) {
    final rate = order.vatRatePercent;
    final rateText = rate <= 0
        ? ''
        : ' (${labels.digits(rate.toStringAsFixed(rate == rate.roundToDouble() ? 0 : 2))}%)';
    return labels.pick('VAT$rateText Included', 'ভ্যাট$rateText অন্তর্ভুক্ত');
  }

  String _paymentLine(OrderModel order, _ReceiptLabels labels) {
    final method = order.paymentMethod;
    final label = method == null
        ? labels.pick('Cash', 'ক্যাশ')
        : labels.language == AppLanguage.bn
        ? method.banglaLabel
        : method.label;
    return '${labels.pick('PAYMENT', 'পেমেন্ট')}: ${labels.digits(label.toUpperCase())}';
  }

  String _tokenFor(OrderModel order, _ReceiptLabels labels) {
    final seq = order.sequenceNo > 0
        ? order.sequenceNo
        : order.orderNo.hashCode.abs();
    final token = 2000 + (seq % 8000);
    return labels.digits('$token');
  }

  String _orderTypeLabel(OrderModel order, _ReceiptLabels labels) {
    switch (order.serviceType ?? OrderServiceType.dineIn) {
      case OrderServiceType.delivery:
        return labels._bn ? 'ডেলিভারি' : 'Delivery';
      case OrderServiceType.takeaway:
        return labels._bn ? 'পার্সেল' : 'Takeaway';
      case OrderServiceType.dineIn:
        return labels._bn ? 'ডাইন ইন' : 'Dine in';
    }
  }

  // Restaurant address/phone shown under the restaurant name on receipts/KOT.
  String? _restaurantSubtitle({
    required _ReceiptLabels labels,
    required String address,
    required String phone,
  }) {
    final parts = <String>[];
    if (address.trim().isNotEmpty) parts.add(address.trim());
    if (phone.trim().isNotEmpty) parts.add(phone.trim());
    if (parts.isEmpty) return null;
    return parts.join('  •  ');
  }

  KotTicketData _buildKotTicketData(
    OrderModel order, {
    required _ReceiptLabels labels,
    required String restaurantName,
    String? restaurantSubtitle,
    String? serverName,
  }) {
    final serviceType = order.serviceType ?? OrderServiceType.dineIn;
    final table = order.tableNo?.trim();
    return KotTicketData(
      restaurantName: restaurantName,
      restaurantSubtitle: restaurantSubtitle,
      title: labels.kotLabel,
      serialLabel: labels.pick('Serial #', 'সিরিয়াল #'),
      serialValue: labels.orderNo(order.displaySequence),
      dateLabel: labels.pick('Date', 'তারিখ'),
      dateValue: labels.digits(
        DateFormat('dd MMM yyyy').format(order.createdAt.toLocal()).toUpperCase(),
      ),
      timeLabel: labels.pick('Time', 'সময়'),
      timeValue: labels.digits(_formatKotTime(order.createdAt)),
      typeLabel: labels.pick('Type', 'ধরন'),
      typeValue: _kotTypeLabel(serviceType, labels),
      tableLabel:
          serviceType == OrderServiceType.dineIn &&
              table != null &&
              table.isNotEmpty
          ? labels.pick('Table', 'টেবিল')
          : null,
      tableValue:
          serviceType == OrderServiceType.dineIn &&
              table != null &&
              table.isNotEmpty
          ? table
          : null,
      items: [
        for (final item in order.items) _kotLineItem(item, labels: labels),
      ],
      itemsLabel: labels.pick('Items', 'আইটেম'),
      noteLabel: labels.pick('Note', 'নোট'),
      serverLabel: labels.pick('Server', 'সার্ভার'),
      serverName: serverName,
    );
  }

  KotLineItem _kotLineItem(OrderItem item, {required _ReceiptLabels labels}) {
    final split = _splitKotModifiers(labels.itemName(item));
    return KotLineItem(
      qtyText: labels.digits('${item.qty}'),
      name: split.$1,
      modifiers: split.$2,
      note: item.note,
    );
  }

  (String, String) _splitKotModifiers(String rawName) {
    final name = rawName.trim();
    final match = RegExp(r'^(.*?)\s+(\([^)]+\))$').firstMatch(name);
    if (match == null) return (name, '');
    final base = match.group(1)?.trim() ?? name;
    final modifiers = match.group(2)?.trim() ?? '';
    if (base.isEmpty || modifiers.isEmpty) return (name, '');
    return (base, modifiers);
  }

  String _formatKotTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime.toLocal());
  }

  String _kotTypeLabel(OrderServiceType serviceType, _ReceiptLabels labels) {
    switch (serviceType) {
      case OrderServiceType.dineIn:
        return labels.pick('Dine-in', 'ডাইন ইন');
      case OrderServiceType.takeaway:
        return labels.pick('Parcel', 'পার্সেল');
      case OrderServiceType.delivery:
        return labels.pick('Delivery', 'ডেলিভারি');
    }
  }

  void _debugPrintTicketData(
    OrderModel order, {
    required String copyKind,
    required String restaurantName,
    required String sourceRestaurantName,
    required double effectiveTotal,
    required _ReceiptLabels labels,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[QB-PRINTER] build copy=$copyKind orderId=${order.id} '
      'display=${order.displaySequence} restaurant="${_logText(restaurantName)}" '
      'sourceRestaurant="${_logText(sourceRestaurantName)}" '
      'items=${order.items.length} rawTotal=${order.total} '
      'subtotal=${order.subtotal} vat=${order.vatAmount} '
      'printedTotal=${labels.money(effectiveTotal)}',
    );
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      final lineTotal = _lineTotalFor(item);
      debugPrint(
        '[QB-PRINTER] item[$i] name="${_logText(labels.itemName(item))}" '
        'qty=${item.qty} price=${item.price} rawLineTotal=${item.lineTotal} '
        'printedLineTotal=${labels.money(lineTotal)}',
      );
    }
  }

  void _debugPrintBitmapResult(
    OrderModel order, {
    required String copyKind,
    required int pngByteCount,
    required int width,
    required int height,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[QB-PRINTER] bitmap copy=$copyKind orderId=${order.id} '
      'size=${width}x$height pngBytes=$pngByteCount targetPaper=58mm',
    );
  }

  void _debugPrintRasterResult(
    OrderModel order, {
    required String copyKind,
    required int byteCount,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[QB-PRINTER] raster copy=$copyKind orderId=${order.id} '
      'escposBytes=$byteCount',
    );
  }

  void _debugPrintWriteResult(
    OrderModel order, {
    required String copyKind,
    required int byteCount,
    required bool ok,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[QB-PRINTER] write copy=$copyKind orderId=${order.id} '
      'escposBytes=$byteCount ok=$ok',
    );
  }

  String _logText(String value) {
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 48) return clean;
    return '${clean.substring(0, 45)}...';
  }

  String _shortText(String value, int maxChars) {
    final clean = _ticketText(value).replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= maxChars) return clean;
    if (maxChars <= 1) return clean.substring(0, maxChars);
    return clean.substring(0, maxChars - 1).trimRight();
  }

  String _separator(String ch) => ch * _ticketWidth;

  String _twoCol(String left, String right) {
    final cleanRight = _shortText(right, 14);
    final leftWidth = _ticketWidth - cleanRight.length - 1;
    final cleanLeft = _shortText(left, leftWidth);
    final gap = _ticketWidth - cleanLeft.length - cleanRight.length;
    return '$cleanLeft${' ' * gap}$cleanRight';
  }

  /// Lightweight check before auto-printing a batch of orders (no print, no busy).
  Future<String?> preflightBlockReason() async {
    final attemptId = _nextPrinterAttempt('preflight');
    if (_hasSelectedSystemPrinter) {
      _logPrinterEnd(attemptId, 'system-queue-ready');
      return null;
    }
    final local = await _probeLocalPrinters(diagId: attemptId);
    if (local.preferred != PrinterTransport.none) {
      _emit(
        _state.copyWith(
          activeTransport: local.preferred,
          builtInPrinterAvailable: local.builtIn,
          usbPrinterAvailable: local.usb,
          connected: true,
          clearLastError: true,
        ),
      );
      _logPrinterEnd(attemptId, 'local-ready');
      return null;
    }
    if (!_state.hasSelectedPrinter) {
      const reason =
          'Connect a USB printer or select a Bluetooth printer first.';
      _logPrinterEnd(attemptId, reason);
      return reason;
    }
    try {
      await _ensureBluetoothReady(diagId: attemptId);
    } catch (error) {
      final reason = _friendlyError(error);
      _logPrinterEnd(attemptId, reason);
      return reason;
    }
    final connected = await _readBluetoothConnectionStatus(diagId: attemptId);
    if (!connected) {
      _logPrinterEnd(attemptId, 'Printer is not connected.');
      return 'Printer is not connected.';
    }
    _logPrinterEnd(attemptId, 'ready');
    return null;
  }

  Future<void> _ensureBluetoothReady({String? diagId}) async {
    final attemptId = diagId ?? _nextPrinterAttempt('ensure-bluetooth-ready');
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] $attemptId _ensureBluetoothReady enter '
        'android=${Platform.isAndroid} ios=${Platform.isIOS} '
        'macos=${Platform.isMacOS} windows=${Platform.isWindows} '
        'osVersion=${Platform.operatingSystemVersion}',
      );
    }
    if (!Platform.isAndroid &&
        !Platform.isIOS &&
        !Platform.isMacOS &&
        !Platform.isWindows) {
      throw PrinterException('Bluetooth printing is not supported here.');
    }
    if (Platform.isAndroid) {
      await _requestBluetoothPermission(attemptId: attemptId);
    }
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (kDebugMode) {
      debugPrint('[QB-PRINTER-DIAG] $attemptId bluetoothEnabled=$enabled');
    }
    if (!enabled) {
      throw PrinterException('Turn on Bluetooth first.');
    }
  }

  Future<void> _requestBluetoothPermission({String? attemptId}) async {
    final id = attemptId ?? _nextPrinterAttempt('request-bt-permission');
    void log(String message) {
      if (kDebugMode) {
        debugPrint('[QB-PRINTER-DIAG] $id $message');
      }
    }

    var connectStatus = await Permission.bluetoothConnect.status;
    var scanStatus = await Permission.bluetoothScan.status;

    log('initial: connect=$connectStatus scan=$scanStatus');

    if (connectStatus.isGranted && scanStatus.isGranted) return;

    if (connectStatus.isPermanentlyDenied || scanStatus.isPermanentlyDenied) {
      log('permanently denied — redirecting to app settings');
      await openAppSettings();
      throw PrinterException(
        'Bluetooth permission was denied permanently. '
        'Please enable it in Settings > Apps > QuickBytes > Permissions.',
      );
    }

    log('requesting…');
    final statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    connectStatus = statuses[Permission.bluetoothConnect] ?? connectStatus;
    scanStatus = statuses[Permission.bluetoothScan] ?? scanStatus;
    log('result: connect=$connectStatus scan=$scanStatus');

    if (connectStatus.isGranted && scanStatus.isGranted) return;

    final connectRationale =
        await Permission.bluetoothConnect.shouldShowRequestRationale;
    final scanRationale =
        await Permission.bluetoothScan.shouldShowRequestRationale;

    if (connectRationale || scanRationale) {
      throw PrinterException(
        'Bluetooth permission is needed for printing. '
        'Please allow it when prompted.',
      );
    }

    log('permanently denied post-request — redirecting to app settings');
    await openAppSettings();
    throw PrinterException(
      'Bluetooth permission was denied permanently. '
      'Please enable it in Settings > Apps > QuickBytes > Permissions.',
    );
  }

  Future<void> _ensureAnyPrinterReady({String? diagId}) async {
    final attemptId = diagId ?? _nextPrinterAttempt('ensure-any-ready');
    _logPrinterDiag(attemptId, '_ensureAnyPrinterReady enter');
    if (_hasSelectedSystemPrinter) {
      _logPrinterDiag(attemptId, 'system queue selected; ready');
      return;
    }
    final local = await _probeLocalPrinters(diagId: attemptId);
    _logPrinterDiag(
      attemptId,
      'local readiness builtIn=${local.builtIn} usb=${local.usb} '
      'preferred=${local.preferred.name}',
    );
    if (local.preferred != PrinterTransport.none) {
      _emit(
        _state.copyWith(
          activeTransport: local.preferred,
          builtInPrinterAvailable: local.builtIn,
          usbPrinterAvailable: local.usb,
          connected: true,
          clearLastError: true,
        ),
      );
      return;
    }
    await _ensureBluetoothConnected(diagId: attemptId);
  }

  Future<void> _ensureBluetoothConnected({String? diagId}) async {
    final attemptId = diagId ?? _nextPrinterAttempt('ensure-bt-connected');
    await _ensureBluetoothReady(diagId: attemptId);
    var connected = await _readBluetoothConnectionStatus(diagId: attemptId);
    _logPrinterDiag(attemptId, 'bt connected before auto-connect=$connected');
    if (!connected) {
      final address = _state.selectedPrinterAddress;
      if (address == null || address.trim().isEmpty) {
        throw PrinterException(
          'Connect a USB printer or select a Bluetooth printer first.',
        );
      }
      _logPrinterDiag(attemptId, 'bt auto-connect address=$address');
      connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: address,
      );
      if (connected) {
        _logPrinterDiag(attemptId, 'bt auto-connect SUCCEEDED');
      }
    }
    if (!connected) {
      throw PrinterException('Printer is not connected.');
    }
    _emit(
      _state.copyWith(
        activeTransport: PrinterTransport.bluetooth,
        connected: true,
        clearLastError: true,
      ),
    );
  }

  Future<bool> _writeBytes(List<int> bytes, {String? diagId}) async {
    final attemptId = diagId ?? _nextPrinterAttempt('write-bytes');
    _logPrinterDiag(attemptId, '_writeBytes bytes=${bytes.length}');
    if (Platform.isWindows &&
        (_state.selectedWindowsQueueName?.trim().isNotEmpty ?? false)) {
      _logPrinterDiag(attemptId, 'routing to Windows RAW queue');
      return _writeWindowsRawBytes(bytes);
    }
    if (_hasSelectedSystemPrinter) {
      _logPrinterDiag(attemptId, 'selected system printer; raw write skipped');
      return false;
    }
    final local = await _probeLocalPrinters(diagId: attemptId);
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] $attemptId write start bytes=${bytes.length} '
        'builtInAvailable=${local.builtIn} '
        'usbAvailable=${local.usb} '
        'btSelected=${_state.selectedPrinterAddress?.isNotEmpty == true}',
      );
    }
    var localWriteError = '';
    if (local.builtIn) {
      final builtInOk = await _writeBuiltInBytes(bytes, diagId: attemptId);
      if (builtInOk) {
        _emit(
          _state.copyWith(
            activeTransport: PrinterTransport.builtIn,
            builtInPrinterAvailable: true,
            usbPrinterAvailable: local.usb,
            connected: true,
            clearLastError: true,
          ),
        );
        return true;
      }
      localWriteError = 'Built-in printer write failed.';
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] $attemptId '
          'built-in write failed; trying USB fallback.',
        );
      }
    }
    if (local.usb) {
      final usbOk = await _writeUsbBytes(bytes, diagId: attemptId);
      if (usbOk) {
        _emit(
          _state.copyWith(
            activeTransport: PrinterTransport.usb,
            builtInPrinterAvailable: local.builtIn,
            usbPrinterAvailable: true,
            connected: true,
            clearLastError: true,
          ),
        );
        return true;
      }
      localWriteError =
          'USB printer was detected, but the Type-C write failed. Replug the printer and retry the test print.';
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] $attemptId '
          'USB write failed; trying Bluetooth fallback.',
        );
      }
    }
    if (_state.selectedPrinterAddress?.trim().isEmpty ?? true) {
      if (localWriteError.isNotEmpty) {
        _emit(
          _state.copyWith(
            activeTransport: PrinterTransport.none,
            builtInPrinterAvailable: local.builtIn,
            usbPrinterAvailable: local.usb,
            connected: false,
            lastError: localWriteError,
          ),
        );
        _logPrinterEnd(attemptId, 'local-write-failed-no-bt');
        return false;
      }
    }

    await _ensureBluetoothConnected(diagId: attemptId);
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    _logPrinterDiag(attemptId, 'bt write result=$ok bytes=${bytes.length}');
    _emit(
      _state.copyWith(
        activeTransport: ok
            ? PrinterTransport.bluetooth
            : PrinterTransport.none,
        builtInPrinterAvailable: local.builtIn,
        usbPrinterAvailable: local.usb,
        connected: ok,
        clearLastError: ok,
      ),
    );
    return ok;
  }

  Future<bool> _writeWindowsRawBytes(List<int> bytes) async {
    final queueName = _state.selectedWindowsQueueName?.trim() ?? '';
    if (!Platform.isWindows || queueName.isEmpty) return false;
    try {
      final ok =
          await _windowsPrinterChannel.invokeMethod<bool>('printBytes', {
            'printerName': queueName,
            'bytes': Uint8List.fromList(bytes),
          }) ??
          false;
      _emit(
        _state.copyWith(
          activeTransport: ok
              ? PrinterTransport.windowsUsb
              : PrinterTransport.none,
          connected: ok,
          clearLastError: ok,
        ),
      );
      return ok;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] Windows RAW write failed: $error');
      }
      _emit(
        _state.copyWith(lastError: _friendlyError(error), connected: false),
      );
      return false;
    }
  }

  PaperSize get _paperSize =>
      _state.windowsPaperWidthMm == 80 ? PaperSize.mm80 : PaperSize.mm58;

  Future<({bool builtIn, bool usb, PrinterTransport preferred})>
  _probeLocalPrinters({String? diagId}) async {
    final attemptId = diagId ?? _nextPrinterAttempt('probe-local');
    _logPrinterDiag(attemptId, 'probe local printers start');
    final builtIn = await _hasBuiltInPrinter(diagId: attemptId);
    final usb = await _hasUsbPrinter(diagId: attemptId);
    final preferred = builtIn
        ? PrinterTransport.builtIn
        : usb
        ? PrinterTransport.usb
        : PrinterTransport.none;
    _logPrinterDiag(
      attemptId,
      'probe local printers result builtIn=$builtIn usb=$usb '
      'preferred=${preferred.name}',
    );
    return (builtIn: builtIn, usb: usb, preferred: preferred);
  }

  PrinterTransport _activeTransport(
    ({bool builtIn, bool usb, PrinterTransport preferred}) local,
    bool bluetoothConnected,
  ) {
    if (_hasSelectedSystemPrinter) return PrinterTransport.windowsUsb;
    if (local.preferred != PrinterTransport.none) return local.preferred;
    return bluetoothConnected
        ? PrinterTransport.bluetooth
        : PrinterTransport.none;
  }

  Future<bool> _hasBuiltInPrinter({String? diagId}) async {
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] ${diagId ?? 'no-attempt'} '
        'builtIn disabled for mobile app; SUNMI bridge not invoked',
      );
    }
    return false;
  }

  Future<bool> _writeBuiltInBytes(List<int> bytes, {String? diagId}) async {
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] ${diagId ?? 'no-attempt'} '
        'builtIn write disabled for mobile app bytes=${bytes.length}',
      );
    }
    return false;
  }

  Future<bool> _hasUsbPrinter({String? diagId}) async {
    if (!Platform.isAndroid) return false;
    // Retry once with a longer window — Android USB host can take >700 ms to
    // enumerate a freshly-plugged Type-C printer on some devices.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        _logPrinterDiag(diagId ?? 'no-attempt', 'USB probe attempt=$attempt');
        final result =
            await _usbPrinterChannel
                .invokeMethod<bool>('hasPrinter')
                .timeout(const Duration(milliseconds: 1500)) ??
            false;
        _logPrinterDiag(
          diagId ?? 'no-attempt',
          'USB probe attempt=$attempt result=$result',
        );
        if (result) return true;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            '[QB-PRINTER-DIAG] ${diagId ?? 'no-attempt'} '
            'USB probe attempt=$attempt error: $error',
          );
        }
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    return false;
  }

  Future<bool> _writeUsbBytes(List<int> bytes, {String? diagId}) async {
    if (!Platform.isAndroid) return false;
    try {
      _logPrinterDiag(
        diagId ?? 'no-attempt',
        'USB write attempt bytes=${bytes.length}',
      );
      final ok =
          await _usbPrinterChannel
              .invokeMethod<bool>('printBytes', {
                'bytes': Uint8List.fromList(bytes),
              })
              .timeout(const Duration(seconds: 60)) ??
          false;
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] ${diagId ?? 'no-attempt'} '
          'USB write result ok=$ok bytes=${bytes.length}',
        );
      }
      return ok;
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER-DIAG] ${diagId ?? 'no-attempt'} '
          'USB write error: $error',
        );
      }
      return false;
    }
  }

  Future<String> readPrinterDiagnostics() async {
    if (!Platform.isAndroid) {
      return 'Printer diagnostics are only available on Android.';
    }
    try {
      return await _usbPrinterChannel.invokeMethod<String>('getDiagnostics') ??
          'No printer diagnostics recorded yet.';
    } catch (error) {
      return 'Could not read printer diagnostics: $error';
    }
  }

  Future<void> clearPrinterDiagnostics() async {
    if (!Platform.isAndroid) return;
    await _usbPrinterChannel.invokeMethod<bool>('clearDiagnostics');
  }

  Future<bool> _readBluetoothConnectionStatus({String? diagId}) async {
    try {
      final connected = await PrintBluetoothThermal.connectionStatus.timeout(
        Duration(milliseconds: 900),
      );
      _logPrinterDiag(diagId ?? 'no-attempt', 'bt connectionStatus=$connected');
      return connected;
    } catch (_) {
      _logPrinterDiag(diagId ?? 'no-attempt', 'bt connectionStatus timeout');
      return false;
    }
  }

  Future<bool> _withBusyBool(
    Future<bool> Function() action, {
    String? diagId,
  }) async {
    _emit(_state.copyWith(busy: true, clearLastError: true));
    try {
      return await action();
    } catch (error) {
      final local = await _probeLocalPrinters(diagId: diagId);
      final bluetoothConnected = await _readBluetoothConnectionStatus(
        diagId: diagId,
      );
      _emit(
        _state.copyWith(
          activeTransport: _activeTransport(local, bluetoothConnected),
          builtInPrinterAvailable: local.builtIn,
          usbPrinterAvailable: local.usb,
          connected:
              local.preferred != PrinterTransport.none ||
              bluetoothConnected ||
              _hasSelectedSystemPrinter,
          lastError: _friendlyError(error),
        ),
      );
      if (kDebugMode) {
        debugPrint('[QB-PRINTER-DIAG] ${diagId ?? 'no-attempt'} error: $error');
      }
      if (diagId != null) _logPrinterEnd(diagId, 'error=$error');
      return false;
    } finally {
      final local = await _probeLocalPrinters(diagId: diagId);
      final bluetoothConnected = await _readBluetoothConnectionStatus(
        diagId: diagId,
      );
      _emit(
        _state.copyWith(
          busy: false,
          activeTransport: _activeTransport(local, bluetoothConnected),
          builtInPrinterAvailable: local.builtIn,
          usbPrinterAvailable: local.usb,
          connected:
              local.preferred != PrinterTransport.none ||
              bluetoothConnected ||
              _hasSelectedSystemPrinter,
        ),
      );
    }
  }

  String _friendlyError(Object error) {
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] _friendlyError raw="$error" '
        'type=${error.runtimeType} '
        'isPrinterException=${error is PrinterException}'
        '${error is PrinterException ? " msg=${error.message}" : ""}',
      );
    }
    if (error is PrinterException) return error.message;
    final value = error.toString();
    if (value.contains('permission')) {
      return 'Printer permission is required.';
    }
    if (value.contains('bluetooth')) return 'Bluetooth is not ready.';
    if (value.contains('usb')) return 'USB printer is not ready.';
    return 'Printer action failed. Check printer power, cable, or Bluetooth pairing.';
  }

  String _ticketText(String value, {String fallback = '-'}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    // ES421 lists English/Chinese language support. Keep receipts ASCII-safe
    // so Bluetooth ESC/POS text mode does not crash on unsupported glyphs.
    return trimmed
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '?')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  void _emit(PrinterRuntimeState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  Future<void> dispose() async {
    await _stateController.close();
  }
}

class PrinterException implements Exception {
  PrinterException(this.message);

  final String message;

  @override
  String toString() => message;
}
