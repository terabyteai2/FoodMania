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
    return builtInPrinterAvailable ||
        usbPrinterAvailable ||
        selectedWindowsQueueName?.trim().isNotEmpty == true ||
        selectedPrinterAddress != null &&
            selectedPrinterAddress!.trim().isNotEmpty;
  }

  String get selectedPrinterLabel {
    if (activeTransport == PrinterTransport.builtIn ||
        activeTransport == PrinterTransport.none && builtInPrinterAvailable) {
      return 'Built-in printer';
    }
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
}

/// Localised receipt labels — switches between English and Bangla.
class _ReceiptLabels {
  _ReceiptLabels(this.language) : _bn = language == AppLanguage.bn;

  final AppLanguage language;
  final bool _bn;

  String get managerCopy => _bn ? 'ম্যানেজার কপি' : 'Manager Copy';
  String get customerCopy => _bn ? 'কাস্টমার কপি' : 'Customer Copy';
  String orderNo(String seq) => digits(seq);
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

  String get _locale => _bn ? 'bn_BD' : 'en_US';
  String qtyText(int qty) => '${digits('$qty')}x';
  String itemName(OrderItem item) {
    final value = item.localizedName(language);
    return value.trim().isEmpty ? emptyItemName : value.trim();
  }

  String money(num amount) {
    final rounded = amount.roundToDouble();
    final value = (amount - rounded).abs() < 0.005
        ? rounded.toInt().toString()
        : NumberFormat.decimalPatternDigits(
            locale: _locale,
            decimalDigits: 2,
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
  static const MethodChannel _builtInPrinterChannel = MethodChannel(
    'com.terabyteai.foodmania/built_in_printer',
  );
  static const MethodChannel _usbPrinterChannel = MethodChannel(
    'com.terabyteai.foodmania/usb_printer',
  );
  static const MethodChannel _windowsPrinterChannel = MethodChannel(
    'com.terabyteai.foodmania/windows_printer',
  );

  static const String _autoPrintKey = 'printer_auto_print_enabled';
  static const String _printerNameKey = 'printer_selected_name';
  static const String _printerAddressKey = 'printer_selected_address';
  static const String _printedOrderIdsKey = 'printer_printed_order_ids';
  static const String _windowsQueueKey = 'printer_windows_queue';
  static const String _windowsPaperWidthKey = 'printer_windows_paper_width_mm';
  static const int _ticketWidth = 32;

  final StreamController<PrinterRuntimeState> _stateController =
      StreamController<PrinterRuntimeState>.broadcast();

  PrinterRuntimeState _state = PrinterRuntimeState(
    autoPrintEnabled: true,
    connected: false,
    busy: false,
  );
  final Set<String> _printedOrderIds = <String>{};

  PrinterRuntimeState get state => _state;
  Stream<PrinterRuntimeState> get stateStream => _stateController.stream;

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
        '[QB-PRINTER] initialize builtInAvailable=${local.builtIn} '
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
    _emit(
      _state.copyWith(
        autoPrintEnabled: preferences.getBool(_autoPrintKey) ?? true,
        selectedPrinterName: preferences.getString(_printerNameKey),
        selectedPrinterAddress: preferences.getString(_printerAddressKey),
        selectedWindowsQueueName: selectedSystemQueue,
        windowsPaperWidthMm: preferences.getInt(_windowsPaperWidthKey) ?? 58,
        activeTransport: hasSystemQueue
            ? PrinterTransport.windowsUsb
            : local.preferred,
        builtInPrinterAvailable: local.builtIn,
        usbPrinterAvailable: local.usb,
        connected: local.preferred != PrinterTransport.none || hasSystemQueue,
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
    return _withBusyBool(() async {
      if (_hasSelectedSystemPrinter) {
        final selected = _state.selectedWindowsQueueName?.trim() ?? '';
        final queues = await listSystemPrinterQueues();
        if (selected.isNotEmpty && queues.contains(selected)) {
          _emit(
            _state.copyWith(
              activeTransport: PrinterTransport.windowsUsb,
              connected: true,
              clearLastError: true,
            ),
          );
          return true;
        }
        throw PrinterException(
          'The selected USB/system printer is unavailable.',
        );
      }

      if (_supportsSystemPrinterQueues) {
        final queues = await listSystemPrinterQueues();
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

      final local = await _probeLocalPrinters();
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
        return true;
      }

      throw PrinterException(
        'No USB printer found. Plug in a USB printer or use Bluetooth.',
      );
    });
  }

  Future<bool> printWindowsPdfFallback(
    OrderModel order, {
    String? restaurantName,
    String? outletName,
    AppLanguage language = AppLanguage.en,
    bool isManagerCopy = false,
  }) async {
    return printSystemPdfFallback(
      order,
      restaurantName: restaurantName,
      outletName: outletName,
      language: language,
      isManagerCopy: isManagerCopy,
    );
  }

  Future<bool> printSystemPdfFallback(
    OrderModel order, {
    String? restaurantName,
    String? outletName,
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
        outletName: outletName ?? '',
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

  /// Lists paired Bluetooth printers without starting location-sensitive
  /// Android discovery. Pairing remains a system-settings responsibility.
  Future<List<BluetoothPrinterDevice>> refreshPairedPrinters() async {
    _emit(_state.copyWith(busy: true, clearLastError: true));
    try {
      await _ensureBluetoothReady();

      final devices = await PrintBluetoothThermal.pairedBluetooths;
      return devices
          .map(
            (d) => BluetoothPrinterDevice(name: d.name, address: d.macAdress),
          )
          .toList(growable: false);
    } catch (error) {
      _emit(_state.copyWith(lastError: _friendlyError(error)));
      return [];
    } finally {
      final local = await _probeLocalPrinters();
      final bluetoothConnected = await _readBluetoothConnectionStatus();
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
    }
  }

  Future<bool> connect(BluetoothPrinterDevice printer) async {
    return _withBusyBool(() async {
      await _ensureBluetoothReady();
      final connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: printer.address,
      );
      if (!connected) {
        throw PrinterException('Could not connect to the selected printer.');
      }
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_printerNameKey, printer.name);
      await preferences.setString(_printerAddressKey, printer.address);
      _emit(
        _state.copyWith(
          activeTransport: PrinterTransport.bluetooth,
          selectedPrinterName: printer.name,
          selectedPrinterAddress: printer.address,
          connected: true,
          clearLastError: true,
        ),
      );
      return true;
    });
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
  }) async {
    return _withBusyBool(() async {
      await _ensureAnyPrinterReady();
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
        outletName: outletName,
      );
      var ok = await _writeBytes(bytes);
      if (!ok && _hasSelectedSystemPrinter) {
        ok = await printSystemPdfFallback(
          testOrder,
          restaurantName: restaurantName,
          outletName: outletName,
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
      return true;
    });
  }

  Future<bool> printOrderTicket(
    OrderModel order, {
    required String restaurantName,
    required String outletName,
    AppLanguage language = AppLanguage.en,
    bool markAsPrinted = true,
    String? orderDetailsUrl,
  }) async {
    return _withBusyBool(() async {
      await _ensureAnyPrinterReady();
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      final labels = _ReceiptLabels(language);

      final managerCopyBytes = await _buildBitmapCopyBytes(
        generator,
        order,
        labels: labels,
        isManagerCopy: true,
        restaurantName: restaurantName,
        outletName: outletName,
        orderDetailsUrl: orderDetailsUrl,
      );
      var okManager = await _writeBytes(managerCopyBytes);
      if (!okManager && _hasSelectedSystemPrinter) {
        okManager = await printSystemPdfFallback(
          order,
          restaurantName: restaurantName,
          outletName: outletName,
          language: language,
          isManagerCopy: true,
        );
      }
      _debugPrintWriteResult(
        order,
        copyKind: 'manager',
        byteCount: managerCopyBytes.length,
        ok: okManager,
      );
      if (!okManager) {
        throw PrinterException(
          'Printing manager copy of ${order.orderNo} failed.',
        );
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
      return true;
    });
  }

  Future<bool> printCustomerInvoice(
    OrderModel order, {
    required String restaurantName,
    required String outletName,
    AppLanguage language = AppLanguage.en,
    String? orderDetailsUrl,
  }) async {
    return _withBusyBool(() async {
      await _ensureAnyPrinterReady();
      final profile = await CapabilityProfile.load();
      final generator = Generator(_paperSize, profile);
      final labels = _ReceiptLabels(language);
      final customerCopyBytes = await _buildBitmapCopyBytes(
        generator,
        order,
        labels: labels,
        isManagerCopy: false,
        restaurantName: restaurantName,
        outletName: outletName,
        orderDetailsUrl: orderDetailsUrl,
      );
      var ok = await _writeBytes(customerCopyBytes);
      if (!ok && _hasSelectedSystemPrinter) {
        ok = await printSystemPdfFallback(
          order,
          restaurantName: restaurantName,
          outletName: outletName,
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
      return true;
    });
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
    String outletName = '',
    String? orderDetailsUrl,
  }) async {
    final tableRaw = order.tableNo ?? labels.takeaway;
    final dateText = labels.formatDate(order.createdAt);
    final effectiveTotal = _orderTotalFor(order);

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
      orderNumberDisplay: labels.orderNo(order.displaySequence),
      orderTypeLabel: _orderTypeLabel(order, labels),
      copyLabel: isManagerCopy ? labels.managerCopy : labels.customerCopy,
      dateLine: dateText,
      tableLine: labels.tableLabel(tableRaw),
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
    String outletName = '',
    String? orderDetailsUrl,
  }) async {
    final pngBytes = await _buildBitmapCopyPng(
      order,
      labels: labels,
      isManagerCopy: isManagerCopy,
      restaurantName: restaurantName,
      outletName: outletName,
      orderDetailsUrl: orderDetailsUrl,
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
    // Convert to grayscale before rasterisation so the ESC/POS driver gets
    // clean luminance values instead of antialiased RGBA noise.
    final raster = Platform.isWindows && _state.windowsPaperWidthMm == 80
        ? img.copyResize(decoded, width: 576)
        : decoded;
    final grayscale = img.grayscale(raster);

    // The QR code is rendered inline into the receipt bitmap (top-right
    // corner) by [TicketBitmapRenderer]. We deliberately do NOT use the
    // ESC/POS `qrcode` command here because many thermal printers ignore the
    // size byte and render a huge QR regardless of [QRSize.size1].
    final bytes = <int>[
      ...generator.reset(),
      ...generator.imageRaster(grayscale, align: PosAlign.center),
    ];
    _debugPrintRasterResult(
      order,
      copyKind: isManagerCopy ? 'manager' : 'customer',
      byteCount: bytes.length,
    );
    return bytes;
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
    AppLanguage language = AppLanguage.en,
  }) async {
    final labels = _ReceiptLabels(language);
    final buffer = StringBuffer();
    _writePreviewCopy(
      buffer,
      order,
      labels: labels,
      isManagerCopy: true,
      restaurantName: restaurantName ?? 'HYBRID POS',
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
    );
    return buffer.toString();
  }

  void _writePreviewCopy(
    StringBuffer buffer,
    OrderModel order, {
    required _ReceiptLabels labels,
    required bool isManagerCopy,
    required String restaurantName,
  }) {
    final tableRaw = order.tableNo ?? labels.takeaway;
    buffer
      ..writeln(labels.orderNo(order.displaySequence))
      ..writeln('[${_orderTypeLabel(order, labels).toUpperCase()}]')
      ..writeln(labels.formatDate(order.createdAt))
      ..writeln(_separator('='))
      ..writeln(_shortText(restaurantName, _ticketWidth))
      ..writeln(labels.tableLabel(tableRaw))
      ..writeln(_separator('-'));
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      buffer.writeln(
        '${labels.digits('${i + 1}')}. ${_shortText(labels.itemName(item), 18)} '
        '${labels.qtyText(item.qty)} ${labels.money(_lineTotalFor(item))}',
      );
    }
    buffer
      ..writeln(_separator('-'))
      ..writeln(
        _twoCol(labels.totalVatIncluded, labels.money(_orderTotalFor(order))),
      )
      ..writeln('SCAN FOR LIVE ORDER DETAILS');
  }

  double _lineTotalFor(OrderItem item) {
    final computed = item.price * item.qty;
    if (item.lineTotal > 0 || computed <= 0) return item.lineTotal;
    return computed;
  }

  double _orderTotalFor(OrderModel order) {
    final itemTotal = order.items.fold<double>(
      0,
      (total, item) => total + _lineTotalFor(item),
    );
    if (itemTotal > 0) return itemTotal;
    if (order.total > 0) return order.total;
    if (order.subtotal > 0 || order.vatAmount > 0) {
      return order.subtotal + order.vatAmount;
    }
    return 0;
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
    if (_hasSelectedSystemPrinter) {
      return null;
    }
    final local = await _probeLocalPrinters();
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
      return null;
    }
    if (!_state.hasSelectedPrinter) {
      return 'Use a built-in printer, connect a USB printer, or select a Bluetooth printer first.';
    }
    try {
      await _ensureBluetoothReady();
    } catch (error) {
      return _friendlyError(error);
    }
    final connected = await _readBluetoothConnectionStatus();
    if (!connected) {
      return 'Printer is not connected.';
    }
    return null;
  }

  Future<void> _ensureBluetoothReady() async {
    if (!Platform.isAndroid &&
        !Platform.isIOS &&
        !Platform.isMacOS &&
        !Platform.isWindows) {
      throw PrinterException('Bluetooth printing is not supported here.');
    }
    if (Platform.isAndroid) {
      final alreadyGranted =
          await PrintBluetoothThermal.isPermissionBluetoothGranted;
      if (!alreadyGranted) {
        final statuses = await [
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
        ].request();
        final granted = statuses.values.every((status) => status.isGranted);
        if (!granted) {
          throw PrinterException('Bluetooth permission is required.');
        }
      }
    }
    final enabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!enabled) {
      throw PrinterException('Turn on Bluetooth first.');
    }
  }

  Future<void> _ensureAnyPrinterReady() async {
    if (_hasSelectedSystemPrinter) {
      return;
    }
    final local = await _probeLocalPrinters();
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
    await _ensureBluetoothConnected();
  }

  Future<void> _ensureBluetoothConnected() async {
    await _ensureBluetoothReady();
    var connected = await _readBluetoothConnectionStatus();
    if (!connected) {
      final address = _state.selectedPrinterAddress;
      if (address == null || address.trim().isEmpty) {
        throw PrinterException(
          'Use a built-in printer, connect a USB printer, or select a Bluetooth printer first.',
        );
      }
      connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: address,
      );
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

  Future<bool> _writeBytes(List<int> bytes) async {
    if (Platform.isWindows &&
        (_state.selectedWindowsQueueName?.trim().isNotEmpty ?? false)) {
      return _writeWindowsRawBytes(bytes);
    }
    if (_hasSelectedSystemPrinter) {
      return false;
    }
    final local = await _probeLocalPrinters();
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER] write start bytes=${bytes.length} '
        'builtInAvailable=${local.builtIn} '
        'usbAvailable=${local.usb} '
        'btSelected=${_state.selectedPrinterAddress?.isNotEmpty == true}',
      );
    }
    var localWriteError = '';
    if (local.builtIn) {
      final builtInOk = await _writeBuiltInBytes(bytes);
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
        debugPrint('[QB-PRINTER] built-in write failed; trying USB fallback.');
      }
    }
    if (local.usb) {
      final usbOk = await _writeUsbBytes(bytes);
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
        debugPrint('[QB-PRINTER] USB write failed; trying Bluetooth fallback.');
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
        return false;
      }
    }

    await _ensureBluetoothConnected();
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
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
  _probeLocalPrinters() async {
    final builtIn = await _hasBuiltInPrinter();
    final usb = await _hasUsbPrinter();
    return (
      builtIn: builtIn,
      usb: usb,
      preferred: builtIn
          ? PrinterTransport.builtIn
          : usb
          ? PrinterTransport.usb
          : PrinterTransport.none,
    );
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

  Future<bool> _hasBuiltInPrinter() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _builtInPrinterChannel
              .invokeMethod<bool>('hasPrinter')
              .timeout(const Duration(milliseconds: 1500)) ??
          false;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[QB-PRINTER] built-in probe error: $error');
      }
      return false;
    }
  }

  Future<bool> _writeBuiltInBytes(List<int> bytes) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok =
          await _builtInPrinterChannel
              .invokeMethod<bool>('printBytes', {
                'bytes': Uint8List.fromList(bytes),
              })
              .timeout(const Duration(seconds: 60)) ??
          false;
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER] built-in write result ok=$ok bytes=${bytes.length}',
        );
      }
      return ok;
    } catch (error) {
      if (kDebugMode) debugPrint('[QB-PRINTER] built-in write error: $error');
      return false;
    }
  }

  Future<bool> _hasUsbPrinter() async {
    if (!Platform.isAndroid) return false;
    // Retry once with a longer window — Android USB host can take >700 ms to
    // enumerate a freshly-plugged Type-C printer on some devices.
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final result =
            await _usbPrinterChannel
                .invokeMethod<bool>('hasPrinter')
                .timeout(const Duration(milliseconds: 1500)) ??
            false;
        if (result) return true;
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      } catch (error) {
        if (kDebugMode) {
          debugPrint('[QB-PRINTER] USB probe attempt=$attempt error: $error');
        }
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
    }
    return false;
  }

  Future<bool> _writeUsbBytes(List<int> bytes) async {
    if (!Platform.isAndroid) return false;
    try {
      final ok =
          await _usbPrinterChannel
              .invokeMethod<bool>('printBytes', {
                'bytes': Uint8List.fromList(bytes),
              })
              .timeout(const Duration(seconds: 60)) ??
          false;
      if (kDebugMode) {
        debugPrint(
          '[QB-PRINTER] USB write result ok=$ok bytes=${bytes.length}',
        );
      }
      return ok;
    } catch (error) {
      if (kDebugMode) debugPrint('[QB-PRINTER] USB write error: $error');
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

  Future<bool> _readBluetoothConnectionStatus() async {
    try {
      return await PrintBluetoothThermal.connectionStatus.timeout(
        Duration(milliseconds: 900),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> _withBusyBool(Future<bool> Function() action) async {
    _emit(_state.copyWith(busy: true, clearLastError: true));
    try {
      return await action();
    } catch (error) {
      final local = await _probeLocalPrinters();
      final bluetoothConnected = await _readBluetoothConnectionStatus();
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
      if (kDebugMode) debugPrint('[QB-PRINTER] error: $error');
      return false;
    } finally {
      final local = await _probeLocalPrinters();
      final bluetoothConnected = await _readBluetoothConnectionStatus();
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
    if (error is PrinterException) return error.message;
    final value = error.toString();
    if (value.contains('permission')) {
      return 'Printer permission is required.';
    }
    if (value.contains('built-in')) return 'Built-in printer is not ready.';
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
