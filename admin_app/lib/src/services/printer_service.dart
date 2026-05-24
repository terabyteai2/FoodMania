import 'dart:async';
import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart'
    as bt_serial;
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_strings.dart';
import '../models/order_item.dart';
import '../models/order_model.dart';
import '../models/order_source.dart';
import '../models/order_status.dart';
import 'ticket_bitmap.dart';

class BluetoothPrinterDevice {
  BluetoothPrinterDevice({required this.name, required this.address});

  final String name;
  final String address;

  String get label => name.trim().isEmpty ? address : name.trim();
}

class PrinterRuntimeState {
  PrinterRuntimeState({
    required this.autoPrintEnabled,
    required this.connected,
    required this.busy,
    this.selectedPrinterName,
    this.selectedPrinterAddress,
    this.lastError,
    this.lastPrintedOrderNo,
    this.lastPrintedAt,
  });

  final bool autoPrintEnabled;
  final bool connected;
  final bool busy;
  final String? selectedPrinterName;
  final String? selectedPrinterAddress;
  final String? lastError;
  final String? lastPrintedOrderNo;
  final DateTime? lastPrintedAt;

  bool get hasSelectedPrinter {
    return selectedPrinterAddress != null &&
        selectedPrinterAddress!.trim().isNotEmpty;
  }

  String get selectedPrinterLabel {
    final name = selectedPrinterName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return selectedPrinterAddress ?? 'No printer selected';
  }

  PrinterRuntimeState copyWith({
    bool? autoPrintEnabled,
    bool? connected,
    bool? busy,
    String? selectedPrinterName,
    String? selectedPrinterAddress,
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
      selectedPrinterName: clearPrinter
          ? null
          : selectedPrinterName ?? this.selectedPrinterName,
      selectedPrinterAddress: clearPrinter
          ? null
          : selectedPrinterAddress ?? this.selectedPrinterAddress,
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
      case OrderSource.manual:
        return _bn ? 'ম্যানুয়াল' : 'Manual';
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
  static const String _autoPrintKey = 'printer_auto_print_enabled';
  static const String _printerNameKey = 'printer_selected_name';
  static const String _printerAddressKey = 'printer_selected_address';
  static const String _printedOrderIdsKey = 'printer_printed_order_ids';
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

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
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
        connected: false,
        clearLastError: true,
      ),
    );
  }

  /// Scans for available Bluetooth devices nearby (not just paired ones).
  /// On Android uses live discovery; on other platforms falls back to paired list.
  Future<List<BluetoothPrinterDevice>> refreshPairedPrinters() async {
    _emit(_state.copyWith(busy: true, clearLastError: true));
    try {
      await _ensureBluetoothReady();

      if (Platform.isAndroid) {
        return await _scanAvailableAndroid();
      }

      // iOS / other: paired list only
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
      _emit(
        _state.copyWith(busy: false, connected: await _readConnectionStatus()),
      );
    }
  }

  /// Runs a 10-second Bluetooth Classic discovery on Android and returns
  /// all discovered devices (both paired and new ones in range).
  Future<List<BluetoothPrinterDevice>> _scanAvailableAndroid() async {
    final seen = <String, BluetoothPrinterDevice>{};

    // Seed with already-paired devices so they always appear in the list.
    try {
      final paired = await PrintBluetoothThermal.pairedBluetooths;
      for (final d in paired) {
        seen[d.macAdress] = BluetoothPrinterDevice(
          name: d.name,
          address: d.macAdress,
        );
      }
    } catch (_) {}

    try {
      final sub = bt_serial.FlutterBluetoothSerial.instance
          .startDiscovery()
          .listen((result) {
            seen[result.device.address] = BluetoothPrinterDevice(
              name: result.device.name ?? '',
              address: result.device.address,
            );
          });

      // Wait for discovery to complete naturally or cut it off after 10 s.
      await Future.any<void>([
        sub.asFuture<void>(),
        Future<void>.delayed(const Duration(seconds: 10)),
      ]);
      await sub.cancel();
    } catch (_) {
      // Discovery may fail on emulators or when BT adapter is busy — the
      // paired list already populated above is still returned.
    }

    return seen.values.toList(growable: false);
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
      _emit(_state.copyWith(connected: !disconnected, clearLastError: true));
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
      await _ensureConnected();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
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
      final ok = await PrintBluetoothThermal.writeBytes(bytes);
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
  }) async {
    return _withBusyBool(() async {
      await _ensureConnected();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final labels = _ReceiptLabels(language);

      // Render the kitchen/manager ticket as a bitmap, then ship raster bytes
      // to the printer. The customer invoice is printed separately from the
      // accepted order card when the bill is requested.
      final managerCopyBytes = await _buildBitmapCopyBytes(
        generator,
        order,
        labels: labels,
        isManagerCopy: true,
        restaurantName: restaurantName,
        outletName: outletName,
      );
      final okManager = await PrintBluetoothThermal.writeBytes(
        managerCopyBytes,
      );
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
  }) async {
    return _withBusyBool(() async {
      await _ensureConnected();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final labels = _ReceiptLabels(language);
      final customerCopyBytes = await _buildBitmapCopyBytes(
        generator,
        order,
        labels: labels,
        isManagerCopy: false,
        restaurantName: restaurantName,
        outletName: outletName,
      );
      final ok = await PrintBluetoothThermal.writeBytes(customerCopyBytes);
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
  Future<List<int>> _buildBitmapCopyBytes(
    Generator generator,
    OrderModel order, {
    required _ReceiptLabels labels,
    required bool isManagerCopy,
    required String restaurantName,
    String outletName = '',
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
    );

    final pngBytes = await TicketBitmapRenderer.render(data);
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
    final grayscale = img.grayscale(decoded);

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
    final copyLabel = isManagerCopy ? labels.managerCopy : labels.customerCopy;
    buffer
      ..writeln(
        _twoCol(
          labels.orderNo(order.displaySequence),
          _shortText(restaurantName, 18),
        ),
      )
      ..writeln(copyLabel)
      ..writeln(labels.formatDate(order.createdAt))
      ..writeln(_separator('-'));
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      buffer.writeln(
        _itemLine(
          '${labels.digits('${i + 1}')}. ${labels.itemName(item)}',
          labels.qtyText(item.qty),
          labels.money(_lineTotalFor(item)),
        ),
      );
    }
    buffer
      ..writeln(_separator('-'))
      ..writeln(
        _twoCol(
          '${labels.totalVatIncluded} -',
          labels.money(_orderTotalFor(order)),
        ),
      );
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

  String _itemLine(String name, String qty, String total) {
    final cleanTotal = _shortText(total, 8);
    final cleanQty = _shortText(qty, 3);
    final nameWidth = _ticketWidth - cleanQty.length - cleanTotal.length - 7;
    final cleanName = _shortText(name, nameWidth);
    final used = cleanName.length + cleanQty.length + cleanTotal.length + 7;
    final gap = _ticketWidth - used;
    final leftGap = gap >= 2 ? 2 : gap;
    final rightGap = gap - leftGap;
    return '$cleanName${' ' * leftGap}- $cleanQty - ${' ' * rightGap}$cleanTotal';
  }

  /// Lightweight check before auto-printing a batch of orders (no print, no busy).
  Future<String?> preflightBlockReason() async {
    if (!_state.hasSelectedPrinter) {
      return 'Select a Bluetooth printer first.';
    }
    try {
      await _ensureBluetoothReady();
    } catch (error) {
      return _friendlyError(error);
    }
    final connected = await _readConnectionStatus();
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

  Future<void> _ensureConnected() async {
    await _ensureBluetoothReady();
    var connected = await _readConnectionStatus();
    if (!connected) {
      final address = _state.selectedPrinterAddress;
      if (address == null || address.trim().isEmpty) {
        throw PrinterException('Select a Bluetooth printer first.');
      }
      connected = await PrintBluetoothThermal.connect(
        macPrinterAddress: address,
      );
    }
    if (!connected) {
      throw PrinterException('Printer is not connected.');
    }
    _emit(_state.copyWith(connected: true, clearLastError: true));
  }

  Future<bool> _readConnectionStatus() async {
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
      _emit(
        _state.copyWith(
          connected: await _readConnectionStatus(),
          lastError: _friendlyError(error),
        ),
      );
      if (kDebugMode) debugPrint('Printer error: $error');
      return false;
    } finally {
      _emit(
        _state.copyWith(busy: false, connected: await _readConnectionStatus()),
      );
    }
  }

  String _friendlyError(Object error) {
    if (error is PrinterException) return error.message;
    final value = error.toString();
    if (value.contains('permission')) {
      return 'Bluetooth permission is required.';
    }
    if (value.contains('bluetooth')) return 'Bluetooth is not ready.';
    return 'Printer action failed. Check printer power and Bluetooth pairing.';
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
