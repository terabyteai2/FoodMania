import 'dart:convert';

import 'sync_status.dart';

class SyncEvent {
  SyncEvent({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payloadJson,
    required this.status,
    required this.retryCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastError,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String action;
  final String payloadJson;
  final SyncStatus status;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> get payload {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, Object?>) return decoded;
    if (decoded is Map) return Map<String, Object?>.from(decoded);
    return {'value': decoded};
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      'payloadJson': payloadJson,
      'status': status.value,
      'retryCount': retryCount,
      'lastError': lastError,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'action': action,
      'payload': payload,
      'status': status.value,
      'retryCount': retryCount,
      'lastError': lastError,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory SyncEvent.fromMap(Map<String, Object?> map) {
    return SyncEvent(
      id: map['id'] as String,
      entityType: map['entityType'] as String,
      entityId: map['entityId'] as String,
      action: map['action'] as String,
      payloadJson: map['payloadJson'] as String,
      status: SyncStatus.parse(
        map['status'] as String?,
        fallback: SyncStatus.pending,
      ),
      retryCount: map['retryCount'] as int? ?? 0,
      lastError: map['lastError'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}

class SyncSummary {
  SyncSummary({
    required this.pendingCount,
    required this.failedCount,
    this.lastSyncAt,
  });

  final int pendingCount;
  final int failedCount;
  final DateTime? lastSyncAt;

  Map<String, Object?> toJson() {
    return {
      'pendingSyncCount': pendingCount,
      'failedSyncCount': failedCount,
      'lastSyncTime': lastSyncAt?.toIso8601String(),
    };
  }
}
