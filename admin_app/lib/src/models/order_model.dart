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
  }) : subtotal = subtotal ?? total,
       vatRatePercent = vatRatePercent ?? 0,
       vatAmount = vatAmount ?? 0;

  final String id;
  final String orderNo;
  final String? customerName;
  final String? tableNo;
  final String? note;
  final String? deliveryAddress;
  final String? mobileNumber;
  final String? createdByAccountId;
  final String? createdByRole;
  final OrderServiceType? serviceType;
  final int? covers;
  final OrderPaymentMethod? paymentMethod;
  final OrderSource source;
  final OrderStatus status;
  final double subtotal;
  final double vatRatePercent;
  final double vatAmount;
  final double total;
  final List<OrderItem> items;
  final SyncStatus syncStatus;
  final int version;
  final int sequenceNo;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displaySequence => sequenceNo > 0 ? '#$sequenceNo' : '#-';

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
    OrderServiceType? serviceType,
    int? covers,
    OrderPaymentMethod? paymentMethod,
    OrderSource? source,
    OrderStatus? status,
    double? subtotal,
    double? vatRatePercent,
    double? vatAmount,
    double? total,
    List<OrderItem>? items,
    SyncStatus? syncStatus,
    int? version,
    int? sequenceNo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCustomerName = false,
    bool clearTableNo = false,
    bool clearNote = false,
    bool clearDeliveryAddress = false,
    bool clearMobileNumber = false,
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
      serviceType: serviceType ?? this.serviceType,
      covers: covers ?? this.covers,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      source: source ?? this.source,
      status: status ?? this.status,
      subtotal: subtotal ?? this.subtotal,
      vatRatePercent: vatRatePercent ?? this.vatRatePercent,
      vatAmount: vatAmount ?? this.vatAmount,
      total: total ?? this.total,
      items: items ?? this.items,
      syncStatus: syncStatus ?? this.syncStatus,
      version: version ?? this.version,
      sequenceNo: sequenceNo ?? this.sequenceNo,
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
      'serviceType': serviceType?.value,
      'covers': covers,
      'paymentMethod': paymentMethod?.value,
      'source': source.value,
      'status': status.value,
      'subtotal': subtotal,
      'vatRatePercent': vatRatePercent,
      'vatAmount': vatAmount,
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
}
