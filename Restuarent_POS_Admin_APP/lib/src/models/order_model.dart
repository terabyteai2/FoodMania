import 'order_item.dart';
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
    this.source = OrderSource.cloud,
    this.syncStatus = SyncStatus.synced,
    this.version = 1,
    this.sequenceNo = 0,
    this.customerName,
    this.tableNo,
    this.note,
  });

  final String id;
  final String orderNo;
  final String? customerName;
  final String? tableNo;
  final String? note;
  final OrderSource source;
  final OrderStatus status;
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
    OrderSource? source,
    OrderStatus? status,
    double? total,
    List<OrderItem>? items,
    SyncStatus? syncStatus,
    int? version,
    int? sequenceNo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNo: orderNo ?? this.orderNo,
      customerName: customerName ?? this.customerName,
      tableNo: tableNo ?? this.tableNo,
      note: note ?? this.note,
      source: source ?? this.source,
      status: status ?? this.status,
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
      'source': source.value,
      'status': status.value,
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
      'source': source.value,
      'sourceLabel': source.label,
      'status': status.value,
      'statusLabel': status.label,
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
      source: OrderSource.parse(map['source'] as String?),
      status:
          OrderStatus.tryParse(map['status'] as String?) ?? OrderStatus.pending,
      total: (map['total'] as num).toDouble(),
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
}
