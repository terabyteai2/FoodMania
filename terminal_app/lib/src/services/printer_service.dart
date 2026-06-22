import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization/app_strings.dart';
import '../core/utils/bounded_string_set.dart';
import '../models/desktop_pos.dart';
import '../models/order_item.dart';
import '../models/order_model.dart';
import '../models/order_service_type.dart';
import '../models/order_source.dart';
import '../models/order_status.dart';
import 'printer/built_in_printer_adapter.dart';
import 'printer/printer_vendor.dart';
import 'printer/printer_vendor_detector.dart';
import 'ticket_bitmap.dart';

class PrinterRuntimeState {
  PrinterRuntimeState({
    required this.autoPrintEnabled,
    required this.connected,
    required this.busy,
    this.detectedVendor = PrinterVendor.none,
    this.lastError,
    this.lastPrintedOrderNo,
    this.lastPrintedAt,
  });

  final bool autoPrintEnabled;
  final bool connected;
  final bool busy;
  final PrinterVendor detectedVendor;
  final String? lastError;
  final String? lastPrintedOrderNo;
  final DateTime? lastPrintedAt;

  bool get hasDetectedPrinter => detectedVendor != PrinterVendor.none;

  String get selectedPrinterLabel =>
      hasDetectedPrinter ? '${detectedVendor.label} printer' : 'No printer detected';

  PrinterRuntimeState copyWith({
    bool? autoPrintEnabled,
    bool? connected,
    bool? busy,
    PrinterVendor? detectedVendor,
    String? lastError,
    String? lastPrintedOrderNo,
    DateTime? lastPrintedAt,
    bool clearLastError = false,
  }) {
    return PrinterRuntimeState(
      autoPrintEnabled: autoPrintEnabled ?? this.autoPrintEnabled,
      connected: connected ?? this.connected,
      busy: busy ?? this.busy,
      detectedVendor: detectedVendor ?? this.detectedVendor,
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
  String get orderNoLabel => _bn ? 'অর্ডার নং:' : 'Order No:';
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
      case OrderSource.manual:
        return _bn ? 'ম্যানুয়াল' : 'Manual';
      case OrderSource.desktopPos:
        return _bn ? 'ডেস্কটপ POS' : 'Desktop POS';
      case OrderSource.localLan:
        return _bn ? 'লিগ্যাসি LAN' : 'Legacy LAN';
    }
  }

  String formatReceiptDateTime(DateTime dt) {
    final local = dt.toLocal();
    final date = DateFormat('yyyy-MM-dd').format(local);
    final time = DateFormat('HH:mm').format(local);
    if (!_bn) return 'Date: $date   Time: $time';
    return digits('তারিখ: $date   সময়: $time');
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
  static const String _printedOrderIdsKey = 'printer_printed_order_ids';
  // Orphaned keys from the removed USB/Bluetooth/Windows-RAW transport
  // layer. Kept only so [initialize] can actively clear them once on
  // upgrade — see the migration note there.
  static const String _legacyPrinterNameKey = 'printer_selected_name';
  static const String _legacyPrinterAddressKey = 'printer_selected_address';
  static const String _legacyWindowsQueueKey = 'printer_windows_queue';
  static const String _legacyWindowsPaperWidthKey =
      'printer_windows_paper_width_mm';
  static const int _ticketWidth = 32;

  final PrinterVendorDetector _detector = PrinterVendorDetector();
  late final Map<PrinterVendor, BuiltInPrinterAdapter> _adaptersByVendor =
      _detector.adaptersByVendor;
  PrinterVendor? _detectedVendor;

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
  String? _cachedLogoUrl;
  Uint8List? _cachedLogoBytes;

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
    return 'vendor=${_state.detectedVendor.label} '
        'auto=${_state.autoPrintEnabled} busy=${_state.busy} '
        'connected=${_state.connected} '
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

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _printedOrderIds
      ..clear()
      ..addAll(preferences.getStringList(_printedOrderIdsKey) ?? []);
    // One-time migration: actively clear orphaned USB/Bluetooth/Windows-RAW
    // selection keys from the old transport layer so no future code can
    // accidentally resurrect a stale BT MAC address or Windows queue name.
    await preferences.remove(_legacyPrinterNameKey);
    await preferences.remove(_legacyPrinterAddressKey);
    await preferences.remove(_legacyWindowsQueueKey);
    await preferences.remove(_legacyWindowsPaperWidthKey);

    _detectedVendor = await _detector.detect();
    if (kDebugMode) {
      debugPrint(
        '[QB-PRINTER-DIAG] initialize detectedVendor=${_detectedVendor!.label}',
      );
    }
    _emit(
      _state.copyWith(
        autoPrintEnabled: preferences.getBool(_autoPrintKey) ?? true,
        detectedVendor: _detectedVendor!,
        connected: _detectedVendor != PrinterVendor.none,
        clearLastError: true,
      ),
    );
  }

  /// Re-runs vendor detection on demand (e.g. a "Re-scan printer" action in
  /// settings). Detection otherwise only happens once, in [initialize].
  Future<bool> redetectPrinter() async {
    final attemptId = _nextPrinterAttempt('redetect');
    return _withBusyBool(() async {
      _detectedVendor = await _detector.detect();
      _emit(
        _state.copyWith(
          detectedVendor: _detectedVendor!,
          connected: _detectedVendor != PrinterVendor.none,
          clearLastError: true,
        ),
      );
      _logPrinterEnd(attemptId, 'redetect-vendor=${_detectedVendor!.label}');
      return _detectedVendor != PrinterVendor.none;
    }, diagId: attemptId);
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
      final pngBytes = await _buildBitmapCopyPng(
        testOrder,
        labels: _ReceiptLabels(AppLanguage.en),
        isManagerCopy: true,
        restaurantName: restaurantName.trim().isEmpty
            ? 'HYBRID POS'
            : restaurantName,
        restaurantAddress: restaurantAddress,
        restaurantPhone: restaurantPhone,
      );
      _logPrinterDiag(attemptId, 'testPrint pngBytes=${pngBytes.length}');
      final ok = await _dispatchPrint(pngBytes, attemptId: attemptId);
      _debugPrintWriteResult(
        testOrder,
        copyKind: 'diagnostic',
        byteCount: pngBytes.length,
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
      final labels = _ReceiptLabels(language);
      final pngBytes = await _buildKotBitmapPng(
        order,
        labels: labels,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
        restaurantPhone: restaurantPhone,
        serverName: serverName,
      );
      _logPrinterDiag(
        attemptId,
        'printOrderTicket pngBytes=${pngBytes.length}',
      );
      final okKot = await _dispatchPrint(pngBytes, attemptId: attemptId);
      _debugPrintWriteResult(
        order,
        copyKind: 'kot',
        byteCount: pngBytes.length,
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
    String? logoUrl,
  }) async {
    final attemptId = _nextPrinterAttempt('print-bill-${order.id}');
    debugPrint('[QB-LOGO] printCustomerInvoice called logoUrl="$logoUrl"');
    return _withBusyBool(() async {
      final labels = _ReceiptLabels(language);
      final logoImageBytes = await _fetchLogoBytes(logoUrl);
      final pngBytes = await _buildBitmapCopyPng(
        order,
        labels: labels,
        isManagerCopy: false,
        restaurantName: restaurantName,
        restaurantAddress: restaurantAddress,
        restaurantPhone: restaurantPhone,
        orderDetailsUrl: orderDetailsUrl,
        serverRole: serverRole,
        logoImageBytes: logoImageBytes,
      );
      _logPrinterDiag(
        attemptId,
        'printCustomerInvoice pngBytes=${pngBytes.length}',
      );
      final ok = await _dispatchPrint(pngBytes, attemptId: attemptId);
      _debugPrintWriteResult(
        order,
        copyKind: 'customer',
        byteCount: pngBytes.length,
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
      final labels = _ReceiptLabels(language);
      final data = _buildDispatchTicketData(
        order,
        labels: labels,
        driverNote: driverNote,
      );
      final pngBytes = await TicketBitmapRenderer.renderUtility(data);
      final ok = await _dispatchPrint(pngBytes, attemptId: attemptId);
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
      final labels = _ReceiptLabels(language);
      final data = _buildVoidWasteTicketData(
        order,
        labels: labels,
        action: action,
        reason: reason,
        cashierName: cashierName,
        value: value,
      );
      final pngBytes = await TicketBitmapRenderer.renderUtility(data);
      final ok = await _dispatchPrint(pngBytes, attemptId: attemptId);
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
      final labels = _ReceiptLabels(language);
      final data = _buildEndOfDayTicketData(
        report: report,
        shift: shift,
        labels: labels,
        restaurantName: restaurantName,
        outletName: outletName,
        managerName: managerName,
      );
      final pngBytes = await TicketBitmapRenderer.renderUtility(data);
      final ok = await _dispatchPrint(pngBytes, attemptId: attemptId);
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

  Future<Uint8List?> _fetchLogoBytes(String? logoUrl) async {
    if (logoUrl == null || logoUrl.trim().isEmpty) {
      debugPrint('[QB-LOGO] _fetchLogoBytes logoUrl=null|empty -> skip');
      return null;
    }
    if (logoUrl == _cachedLogoUrl && _cachedLogoBytes != null) {
      debugPrint('[QB-LOGO] _fetchLogoBytes cache HIT url="$logoUrl" bytes=${_cachedLogoBytes!.length}');
      return _cachedLogoBytes;
    }
    debugPrint('[QB-LOGO] _fetchLogoBytes downloading url="$logoUrl"');
    try {
      final res = await http.get(Uri.parse(logoUrl)).timeout(const Duration(seconds: 5));
      debugPrint('[QB-LOGO] _fetchLogoBytes status=${res.statusCode} contentLength=${res.bodyBytes.length}');
      if (res.statusCode == 200) {
        _cachedLogoUrl = logoUrl;
        _cachedLogoBytes = res.bodyBytes;
        debugPrint('[QB-LOGO] _fetchLogoBytes cached url="$logoUrl" bytes=${_cachedLogoBytes!.length}');
        return _cachedLogoBytes;
      }
    } catch (e) {
      debugPrint('[QB-LOGO] _fetchLogoBytes error="$e"');
    }
    return null;
  }

  /// Build one printable copy entirely as a bitmap (PNG). The bitmap path
  /// keeps the on-paper layout pixel-identical to the in-app preview
  /// regardless of which vendor printer library ends up rendering it.
  Future<Uint8List> _buildBitmapCopyPng(
    OrderModel order, {
    required _ReceiptLabels labels,
    required bool isManagerCopy,
    required String restaurantName,
    String restaurantAddress = '',
    String restaurantPhone = '',
    String? orderDetailsUrl,
    String? serverRole,
    Uint8List? logoImageBytes,
  }) async {
    final tableRaw = order.serviceType == OrderServiceType.delivery
        ? ''
        : order.tableNo ?? labels.takeaway;
    final dateText = labels.formatReceiptDateTime(order.createdAt);
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
      restaurantSubtitle: _restaurantSubtitle(
        labels: labels,
        address: restaurantAddress,
        phone: restaurantPhone,
      ),
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
      summaryRows: _receiptSummaryRows(order, labels: labels),
      paymentLine: _paymentLine(order, labels),
      qrCaption: isDelivery
          ? labels.pick('Track your delivery', 'ডেলিভারি ট্র্যাক করুন')
          : labels.pick('Scan to track / rate us', 'ট্র্যাক / রেট করতে স্ক্যান করুন'),
      footerText: isDelivery
          ? null
          : labels.pick('Thank you for dining!', 'ধন্যবাদ!'),
      logoImageBytes: logoImageBytes,
      serverRole: serverRole,
    );

    final pngBytes = await TicketBitmapRenderer.render(data);
    return pngBytes;
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
      rows.add(
        TicketSummaryRow(
          label: labels.pick('Discount', 'ডিসকাউন্ট'),
          value: '-${labels.money(discount)}',
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
    rows
      ..add(
        TicketSummaryRow(
          label: labels.total,
          value: labels.money(total),
          emphasis: true,
        ),
      )
      ..add(
        TicketSummaryRow(
          label: _vatIncludedLabel(order, labels),
          value: labels.money(_includedVatFor(order, total)),
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
      warning: labels.pick(
        'DO NOT SHOW TO CUSTOMER',
        'কাস্টমারকে দেখাবেন না',
      ),
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
          value: labels.digits(DateFormat('HH:mm').format(order.createdAt.toLocal())),
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
        TicketSummaryRow(
          label: labels.pick('Reason', 'কারণ'),
          value: reason,
        ),
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
    );
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
      ..writeln('KITCHEN ORDER')
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
    return buffer.toString();
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
      serialLabel: labels.pick('Serial #', 'সিরিয়াল #'),
      serialValue: labels.orderNo(order.displaySequence),
      dateLabel: labels.pick('Date', 'তারিখ'),
      dateValue: labels.digits(DateFormat('yyyy-MM-dd').format(order.createdAt.toLocal())),
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

  void _writePreviewCopy(
    StringBuffer buffer,
    OrderModel order, {
    required _ReceiptLabels labels,
    required bool isManagerCopy,
    required String restaurantName,
    required String restaurantAddress,
    required String restaurantPhone,
  }) {
    final tableRaw = order.serviceType == OrderServiceType.delivery
        ? ''
        : order.tableNo ?? labels.takeaway;
    buffer
      ..writeln(labels.orderNo(order.displaySequence))
      ..writeln('[${_orderTypeLabel(order, labels).toUpperCase()}]')
      ..writeln(labels.formatDate(order.createdAt))
      ..writeln(_separator('='))
      ..writeln(_shortText(restaurantName, _ticketWidth));
    final subtitle = _restaurantSubtitle(
      labels: labels,
      address: restaurantAddress,
      phone: restaurantPhone,
    );
    if (subtitle != null) {
      buffer.writeln(_shortText(subtitle, _ticketWidth));
    }
    if (tableRaw.trim().isNotEmpty) {
      buffer.writeln(labels.tableLabel(tableRaw));
    }
    if (order.customerName?.trim().isNotEmpty == true) {
      buffer.writeln('${labels.nameLabel}: ${order.customerName!.trim()}');
    }
    if (order.deliveryAddress?.trim().isNotEmpty == true) {
      buffer.writeln('${labels.addressLabel}: ${order.deliveryAddress!.trim()}');
    }
    if (order.mobileNumber?.trim().isNotEmpty == true) {
      buffer.writeln('${labels.phoneLabel}: ${order.mobileNumber!.trim()}');
    }
    buffer.writeln(_separator('-'));
    for (var i = 0; i < order.items.length; i++) {
      final item = order.items[i];
      buffer.writeln(
        '${labels.digits('${i + 1}')}. ${_shortText(labels.itemName(item), 18)} '
        '${labels.qtyText(item.qty)} ${labels.money(_lineTotalFor(item))}',
      );
    }
    buffer
      ..writeln(_separator('-'))
      ..write(_previewSummary(order, labels))
      ..writeln(_paymentLine(order, labels))
      ..writeln('SCAN FOR LIVE ORDER DETAILS');
  }

  String _previewSummary(OrderModel order, _ReceiptLabels labels) {
    final buffer = StringBuffer();
    for (final row in _receiptSummaryRows(order, labels: labels)) {
      buffer.writeln(_twoCol(row.label, row.value));
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
    if (order.total > 0) return order.total;
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
    final seq = order.sequenceNo > 0 ? order.sequenceNo : order.orderNo.hashCode.abs();
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

  void _debugPrintWriteResult(
    OrderModel order, {
    required String copyKind,
    required int byteCount,
    required bool ok,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[QB-PRINTER] write copy=$copyKind orderId=${order.id} '
      'pngBytes=$byteCount ok=$ok',
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
    _detectedVendor ??= await _detector.detect();
    if (_detectedVendor != PrinterVendor.none) {
      _emit(
        _state.copyWith(
          detectedVendor: _detectedVendor!,
          connected: true,
          clearLastError: true,
        ),
      );
      _logPrinterEnd(attemptId, 'local-ready');
      return null;
    }
    const reason = 'No supported printer detected on this device.';
    _logPrinterEnd(attemptId, reason);
    return reason;
  }

  Future<void> _ensurePrinterReady({String? diagId}) async {
    final attemptId = diagId ?? _nextPrinterAttempt('ensure-ready');
    _detectedVendor ??= await _detector.detect();
    _logPrinterDiag(attemptId, 'detectedVendor=${_detectedVendor!.label}');
    if (_detectedVendor == PrinterVendor.none) {
      throw PrinterException('No supported printer detected on this device.');
    }
    _emit(
      _state.copyWith(
        detectedVendor: _detectedVendor!,
        connected: true,
        clearLastError: true,
      ),
    );
  }

  /// The single, non-fallback dispatch point: ensures a vendor is detected
  /// (cached after the first call), then hands the rendered ticket straight
  /// to that vendor's adapter. There is no probing across other vendors —
  /// either the detected adapter prints, or this returns false.
  Future<bool> _dispatchPrint(
    Uint8List pngBytes, {
    required String attemptId,
  }) async {
    await _ensurePrinterReady(diagId: attemptId);
    final adapter = _adaptersByVendor[_detectedVendor];
    if (adapter == null) return false;
    final ok = await adapter.printTicketBitmap(pngBytes);
    _emit(
      _state.copyWith(
        connected: ok,
        lastError: ok
            ? null
            : 'Print failed on ${_detectedVendor!.label} printer.',
        clearLastError: ok,
      ),
    );
    return ok;
  }

  Future<bool> _withBusyBool(
    Future<bool> Function() action, {
    String? diagId,
  }) async {
    _emit(_state.copyWith(busy: true, clearLastError: true));
    try {
      return await action();
    } catch (error) {
      _emit(
        _state.copyWith(
          connected: _detectedVendor != null &&
              _detectedVendor != PrinterVendor.none,
          lastError: _friendlyError(error),
        ),
      );
      if (kDebugMode) {
        debugPrint('[QB-PRINTER-DIAG] ${diagId ?? 'no-attempt'} error: $error');
      }
      if (diagId != null) _logPrinterEnd(diagId, 'error=$error');
      return false;
    } finally {
      _emit(_state.copyWith(busy: false));
    }
  }

  String _friendlyError(Object error) {
    if (error is PrinterException) return error.message;
    return 'Printer action failed. Check the printer is powered on and has paper.';
  }

  String _ticketText(String value, {String fallback = '-'}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    // Keep receipt text ASCII-safe so vendor text-mode rendering does not
    // choke on unsupported glyphs.
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
