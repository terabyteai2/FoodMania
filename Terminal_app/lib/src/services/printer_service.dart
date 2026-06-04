import 'dart:async';
import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_strings.dart';
import '../core/utils/bounded_string_set.dart';
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

  bool get hasSelectedPrinter => builtInPrinterAvailable;

  String get selectedPrinterLabel {
    if (builtInPrinterAvailable ||
        activeTransport == PrinterTransport.builtIn) {
      return 'Built-in printer';
    }
    return 'Built-in printer unavailable';
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

  static const String _autoPrintKey = 'printer_auto_print_enabled';
  static const String _printedOrderIdsKey = 'printer_printed_order_ids';
  static const int _ticketWidth = 32;

  final StreamController<PrinterRuntimeState> _stateController =
      StreamController<PrinterRuntimeState>.broadcast();

  PrinterRuntimeState _state = PrinterRuntimeState(
    autoPrintEnabled: true,
    connected: false,
    busy: false,
  );
  // Bounded so an always-on terminal that prints thousands of tickets never
  // grows this set (and its persisted copy) without limit.
  final BoundedStringSet _printedOrderIds = BoundedStringSet(cap: 2000);

  PrinterRuntimeState get state => _state;
  Stream<PrinterRuntimeState> get stateStream => _stateController.stream;

  bool get supportsDirectBluetoothPrinting => false;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final builtIn = await _hasBuiltInPrinter();
    _printedOrderIds
      ..clear()
      ..addAll(preferences.getStringList(_printedOrderIdsKey) ?? []);
    _emit(
      _state.copyWith(
        autoPrintEnabled: preferences.getBool(_autoPrintKey) ?? true,
        activeTransport: builtIn
            ? PrinterTransport.builtIn
            : PrinterTransport.none,
        builtInPrinterAvailable: builtIn,
        usbPrinterAvailable: false,
        connected: builtIn,
        clearLastError: true,
        clearPrinter: true,
      ),
    );
  }

  Future<List<BluetoothPrinterDevice>> refreshPairedPrinters() async {
    return const <BluetoothPrinterDevice>[];
  }

  Future<List<String>> listSystemPrinterQueues() async => const <String>[];

  Future<void> selectSystemPrinterQueue(
    String queueName, {
    int paperWidthMm = 58,
  }) async {
    throw PrinterException('Terminal app supports built-in printing only.');
  }

  Future<bool> connectLocalUsbPrinterAuto() async {
    return _withBusyBool(() async {
      await _ensureBuiltInPrinterReady();
      return true;
    });
  }

  Future<bool> connect(BluetoothPrinterDevice printer) async {
    _emit(
      _state.copyWith(
        lastError: 'Terminal app supports built-in printing only.',
      ),
    );
    return false;
  }

  Future<bool> disconnect() async => false;

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
      await _ensureBuiltInPrinterReady();
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
      final ok = await _writeBuiltInBytes(bytes);
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
      await _ensureBuiltInPrinterReady();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = await _buildBitmapCopyBytes(
        generator,
        order,
        labels: _ReceiptLabels(language),
        isManagerCopy: true,
        restaurantName: restaurantName,
        outletName: outletName,
        orderDetailsUrl: orderDetailsUrl,
      );
      final ok = await _writeBuiltInBytes(bytes);
      _debugPrintWriteResult(
        order,
        copyKind: 'manager',
        byteCount: bytes.length,
        ok: ok,
      );
      if (!ok) {
        throw PrinterException(
          'Printing manager copy of ${order.orderNo} failed.',
        );
      }
      if (markAsPrinted) {
        await markOrderPrinted(order);
      }
      _emit(
        _state.copyWith(
          activeTransport: PrinterTransport.builtIn,
          builtInPrinterAvailable: true,
          connected: true,
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
      await _ensureBuiltInPrinterReady();
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      final bytes = await _buildBitmapCopyBytes(
        generator,
        order,
        labels: _ReceiptLabels(language),
        isManagerCopy: false,
        restaurantName: restaurantName,
        outletName: outletName,
        orderDetailsUrl: orderDetailsUrl,
      );
      final ok = await _writeBuiltInBytes(bytes);
      _debugPrintWriteResult(
        order,
        copyKind: 'customer',
        byteCount: bytes.length,
        ok: ok,
      );
      if (!ok) {
        throw PrinterException(
          'Printing customer invoice of ${order.orderNo} failed.',
        );
      }
      _emit(
        _state.copyWith(
          activeTransport: PrinterTransport.builtIn,
          builtInPrinterAvailable: true,
          connected: true,
          lastPrintedOrderNo: order.orderNo,
          lastPrintedAt: DateTime.now(),
          clearLastError: true,
        ),
      );
      return true;
    });
  }

  Future<Uint8List> _buildBitmapCopyPng(
    OrderModel order, {
    required _ReceiptLabels labels,
    required bool isManagerCopy,
    required String restaurantName,
    String outletName = '',
    String? orderDetailsUrl,
  }) async {
    final tableRaw = order.tableNo ?? labels.takeaway;
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
      dateLine: labels.formatDate(order.createdAt),
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

    return TicketBitmapRenderer.render(data);
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

  Future<String?> preflightBlockReason() async {
    final builtIn = await _hasBuiltInPrinter();
    _emit(
      _state.copyWith(
        activeTransport: builtIn
            ? PrinterTransport.builtIn
            : PrinterTransport.none,
        builtInPrinterAvailable: builtIn,
        connected: builtIn,
        clearLastError: builtIn,
      ),
    );
    return builtIn ? null : 'Built-in printer is not ready.';
  }

  Future<void> _ensureBuiltInPrinterReady() async {
    final builtIn = await _hasBuiltInPrinter();
    _emit(
      _state.copyWith(
        activeTransport: builtIn
            ? PrinterTransport.builtIn
            : PrinterTransport.none,
        builtInPrinterAvailable: builtIn,
        connected: builtIn,
        clearLastError: builtIn,
      ),
    );
    if (!builtIn) {
      throw PrinterException('Built-in printer is not ready.');
    }
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

  Future<String> readPrinterDiagnostics() async {
    if (!Platform.isAndroid) {
      return 'Printer diagnostics are only available on Android.';
    }
    try {
      return await _builtInPrinterChannel.invokeMethod<String>(
            'getDiagnostics',
          ) ??
          'No printer diagnostics recorded yet.';
    } catch (error) {
      return 'Could not read printer diagnostics: $error';
    }
  }

  Future<void> clearPrinterDiagnostics() async {
    if (!Platform.isAndroid) return;
    await _builtInPrinterChannel.invokeMethod<bool>('clearDiagnostics');
  }

  Future<bool> _withBusyBool(Future<bool> Function() action) async {
    _emit(_state.copyWith(busy: true, clearLastError: true));
    try {
      return await action();
    } catch (error) {
      final builtIn = await _hasBuiltInPrinter();
      _emit(
        _state.copyWith(
          activeTransport: builtIn
              ? PrinterTransport.builtIn
              : PrinterTransport.none,
          builtInPrinterAvailable: builtIn,
          connected: builtIn,
          lastError: _friendlyError(error),
        ),
      );
      if (kDebugMode) debugPrint('[QB-PRINTER] error: $error');
      return false;
    } finally {
      final builtIn = await _hasBuiltInPrinter();
      _emit(
        _state.copyWith(
          busy: false,
          activeTransport: builtIn
              ? PrinterTransport.builtIn
              : PrinterTransport.none,
          builtInPrinterAvailable: builtIn,
          connected: builtIn,
        ),
      );
    }
  }

  String _friendlyError(Object error) {
    if (error is PrinterException) return error.message;
    final value = error.toString().toLowerCase();
    if (value.contains('permission')) {
      return 'Printer permission is required.';
    }
    if (value.contains('built-in') || value.contains('sunmi')) {
      return 'Built-in printer is not ready.';
    }
    return 'Built-in printer action failed. Check terminal printer paper and power.';
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
      'printedTotal=${labels.money(effectiveTotal)}',
    );
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
    final clean = value.replaceAll(RegExp(r'\s+'), ' ').trim();
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
