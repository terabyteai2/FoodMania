import 'dart:convert';

import 'order_item.dart';
import 'order_payment_method.dart';
import 'order_service_type.dart';
import 'order_source.dart';
import 'order_status.dart';
import 'sync_status.dart';

class OrderModel {
  OrderModel({
    required this.id,
    required this.orderNo,
    required this.status,
    required this.total,
    required this.items,
    required this.createdAt,
    required this.updatedAt,
    double? subtotal,
    double? vatRatePercent,
    double? vatAmount,
    double? deliveryCharge,
    this.source = OrderSource.cloud,
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
    this.sequenceNo = 0,
    this.serviceType,
    this.covers,
    this.paymentMethod,
    this.customerName,
    this.tableNo,
    this.note,
    this.deliveryAddress,
    this.mobileNumber,
    this.createdByAccountId,
    this.createdByRole,
    this.shiftId,
    this.discountLabel,
    this.discountAmount = 0,
    this.serviceChargeRatePercent = 0,
    this.serviceChargeAmount = 0,
    this.billingSnapshot = const {},
    this.kotBatches = const [],
    this.orderDate,
    this.settledAt,
  }) : subtotal = subtotal ?? total,
       vatRatePercent = vatRatePercent ?? 0,
       vatAmount = vatAmount ?? 0,
       deliveryCharge = deliveryCharge ?? 0;

  final String id;
  final String orderNo;
  final String? customerName;
  final String? tableNo;
  final String? note;
  final String? deliveryAddress;
  final String? mobileNumber;
  final String? createdByAccountId;
  final String? createdByRole;
  final String? shiftId;
  final String? discountLabel;
  final double discountAmount;
  final double serviceChargeRatePercent;
  final double serviceChargeAmount;
  final Map<String, Object?> billingSnapshot;
  final List<Map<String, Object?>> kotBatches;
  final DateTime? settledAt;
  final OrderServiceType? serviceType;
  final int? covers;
  final OrderPaymentMethod? paymentMethod;
  final OrderSource source;
  final OrderStatus status;
  final double subtotal;
  final double vatRatePercent;
  final double vatAmount;
  final double deliveryCharge;
  final double total;
  final List<OrderItem> items;
  final SyncStatus syncStatus;
  final int version;
  final int sequenceNo;
  final DateTime? orderDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get _serialPrefix {
    switch (source) {
      case OrderSource.cloud:
        return 'W';
      case OrderSource.facebookMessenger:
        return 'M';
      case OrderSource.whatsapp:
        return 'WA';
      case OrderSource.manual:
      case OrderSource.desktopPos:
        final role = (createdByRole ?? '').trim().toLowerCase();
        if (role == 'waiter' || role == 'staff') return 'S';
        return '';
      case OrderSource.localLan:
        return '';
    }
  }

  String get displaySequence =>
      sequenceNo > 0 ? '#$_serialPrefix$sequenceNo' : '#-';

  /// Net payable for display. `total` already includes the discount only for
  /// desktop-POS settlements, which fold the discount into `total` and stamp
  /// [settledAt]; every other writer (mobile wizard, cloud, Bill-button
  /// completion) stores the discount separately, so it is subtracted here.
  double get totalAfterDiscount {
    if (discountAmount <= 0 || settledAt != null) return total;
    return double.parse((total - discountAmount).toStringAsFixed(2));
  }

  OrderModel copyWith({
    String? id,
    String? orderNo,
    String? customerName,
    String? tableNo,
    String? note,
    String? deliveryAddress,
    String? mobileNumber,
    String? createdByAccountId,
    String? createdByRole,
    String? shiftId,
    String? discountLabel,
    double? discountAmount,
    double? serviceChargeRatePercent,
    double? serviceChargeAmount,
    Map<String, Object?>? billingSnapshot,
    List<Map<String, Object?>>? kotBatches,
    DateTime? settledAt,
    OrderServiceType? serviceType,
    int? covers,
    OrderPaymentMethod? paymentMethod,
    OrderSource? source,
    OrderStatus? status,
    double? subtotal,
    double? vatRatePercent,
    double? vatAmount,
    double? deliveryCharge,
    double? total,
    List<OrderItem>? items,
    SyncStatus? syncStatus,
    int? version,
    int? sequenceNo,
    DateTime? orderDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCustomerName = false,
    bool clearTableNo = false,
    bool clearNote = false,
    bool clearDeliveryAddress = false,
    bool clearMobileNumber = false,
    bool clearDiscountLabel = false,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNo: orderNo ?? this.orderNo,
      customerName: clearCustomerName
          ? null
          : (customerName ?? this.customerName),
      tableNo: clearTableNo ? null : (tableNo ?? this.tableNo),
      note: clearNote ? null : (note ?? this.note),
      deliveryAddress: clearDeliveryAddress
          ? null
          : (deliveryAddress ?? this.deliveryAddress),
      mobileNumber: clearMobileNumber
          ? null
          : (mobileNumber ?? this.mobileNumber),
      createdByAccountId: createdByAccountId ?? this.createdByAccountId,
      createdByRole: createdByRole ?? this.createdByRole,
      shiftId: shiftId ?? this.shiftId,
      discountLabel: clearDiscountLabel ? null : (discountLabel ?? this.discountLabel),
      discountAmount: discountAmount ?? this.discountAmount,
      serviceChargeRatePercent:
          serviceChargeRatePercent ?? this.serviceChargeRatePercent,
      serviceChargeAmount: serviceChargeAmount ?? this.serviceChargeAmount,
      billingSnapshot: billingSnapshot ?? this.billingSnapshot,
      kotBatches: kotBatches ?? this.kotBatches,
      settledAt: settledAt ?? this.settledAt,
      serviceType: serviceType ?? this.serviceType,
      covers: covers ?? this.covers,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      source: source ?? this.source,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      vatRatePercent: vatRatePercent ?? this.vatRatePercent,
      vatAmount: vatAmount ?? this.vatAmount,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      total: total ?? this.total,
      items: items ?? this.items,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
      sequenceNo: sequenceNo ?? this.sequenceNo,
      orderDate: orderDate ?? this.orderDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'orderNo': orderNo,
      'customerName': customerName,
      'tableNo': tableNo,
      'note': note,
      'deliveryAddress': deliveryAddress,
      'mobileNumber': mobileNumber,
      'createdByAccountId': createdByAccountId,
      'createdByRole': createdByRole,
      'shiftId': shiftId,
      'discountLabel': discountLabel,
      'discountAmount': discountAmount,
      'serviceChargeRatePercent': serviceChargeRatePercent,
      'serviceChargeAmount': serviceChargeAmount,
      'billingSnapshot': jsonEncode(billingSnapshot),
      'kotBatches': jsonEncode(kotBatches),
      'settledAt': settledAt?.toIso8601String(),
      'orderDate': orderDate?.toIso8601String().substring(0, 10),
      'serviceType': serviceType?.value,
      'covers': covers,
      'paymentMethod': paymentMethod?.value,
      'source': source.value,
      'status': status.value,
      'subtotal': subtotal,
      'vatRatePercent': vatRatePercent,
      'vatAmount': vatAmount,
      'deliveryCharge': deliveryCharge,
      'total': total,
      'syncStatus': syncStatus.value,
      'version': version,
      'sequenceNo': sequenceNo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'orderNo': orderNo,
      'customerName': customerName,
      'tableNo': tableNo,
      'note': note,
      'deliveryAddress': deliveryAddress,
      'mobileNumber': mobileNumber,
      'createdByAccountId': createdByAccountId,
      'createdByRole': createdByRole,
      'shiftId': shiftId,
      'discountLabel': discountLabel,
      'discountAmount': discountAmount,
      'serviceChargeRatePercent': serviceChargeRatePercent,
      'serviceChargeAmount': serviceChargeAmount,
      'billingSnapshot': billingSnapshot,
      'kotBatches': kotBatches,
      'settledAt': settledAt?.toIso8601String(),
      'orderDate': orderDate?.toIso8601String().substring(0, 10),
      'serviceType': serviceType?.value,
      'covers': covers,
      'paymentMethod': paymentMethod?.value,
      'source': source.value,
      'sourceLabel': source.label,
      'status': status.value,
      'statusLabel': status.label,
      'subtotal': subtotal,
      'vatRatePercent': vatRatePercent,
      'vatAmount': vatAmount,
      'deliveryCharge': deliveryCharge,
      'total': total,
      'items': items.map((item) => item.toJson()).toList(growable: false),
      'syncStatus': syncStatus.value,
      'version': version,
      'sequenceNo': sequenceNo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory OrderModel.fromMap(
    Map<String, Object?> map, {
    List<OrderItem> items = const [],
  }) {
    return OrderModel(
      id: map['id'] as String,
      orderNo: map['orderNo'] as String,
      customerName: map['customerName'] as String?,
      tableNo: map['tableNo'] as String?,
      note: map['note'] as String?,
      deliveryAddress: map['deliveryAddress'] as String?,
      mobileNumber: map['mobileNumber'] as String?,
      createdByAccountId: map['createdByAccountId'] as String?,
      createdByRole: map['createdByRole'] as String?,
      shiftId: map['shiftId'] as String?,
      discountLabel: map['discountLabel'] as String?,
      discountAmount: _doubleOrNull(map['discountAmount']) ?? 0,
      serviceChargeRatePercent:
          _doubleOrNull(map['serviceChargeRatePercent']) ?? 0,
      serviceChargeAmount: _doubleOrNull(map['serviceChargeAmount']) ?? 0,
      billingSnapshot: _jsonMap(map['billingSnapshot']),
      kotBatches: _jsonMapList(map['kotBatches']),
      settledAt: DateTime.tryParse(map['settledAt']?.toString() ?? ''),
      orderDate: map['orderDate'] != null
          ? DateTime.tryParse(map['orderDate'] as String)
          : null,
      serviceType: OrderServiceType.tryParse(map['serviceType'] as String?),
      covers: _intOrNull(map['covers']),
      paymentMethod: OrderPaymentMethod.tryParse(
        map['paymentMethod'] as String?,
      ),
      source: OrderSource.parse(map['source'] as String?),
      status:
          OrderStatus.tryParse(map['status'] as String?) ?? OrderStatus.pending,
      subtotal: _doubleOrNull(map['subtotal']) ?? _double(map['total']),
      vatRatePercent: _doubleOrNull(map['vatRatePercent']) ?? 0,
      vatAmount: _doubleOrNull(map['vatAmount']) ?? 0,
      deliveryCharge: _doubleOrNull(map['deliveryCharge']) ?? 0,
      total: _double(map['total']),
      items: items,
      syncStatus: SyncStatus.parse(map['syncStatus'] as String?),
      version: map['version'] as int? ?? 1,
      sequenceNo: map['sequenceNo'] is num
          ? (map['sequenceNo'] as num).toInt()
          : 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  static double _double(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static double? _doubleOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static Map<String, Object?> _jsonMap(Object? value) {
    if (value is Map) return Map<String, Object?>.from(value);
    if (value is String && value.isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    }
    return const {};
  }

  static List<Map<String, Object?>> _jsonMapList(Object? value) {
    if (value is String && value.isNotEmpty) {
      return _jsonMapList(jsonDecode(value));
    }
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
  }
}
