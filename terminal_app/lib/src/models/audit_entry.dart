/// A single POS audit-trail event (spec §4.10 Audit / data model `AuditEntry`).
/// Mirrors `GET /outlets/{id}/pos/audit` — a void / refund / comp / discount
/// override with who, role, time, amount and reason.
enum AuditAction { void_, refund, comp, discount, unknown }

extension AuditActionX on AuditAction {
  String get key {
    switch (this) {
      case AuditAction.void_:
        return 'void';
      case AuditAction.refund:
        return 'refund';
      case AuditAction.comp:
        return 'comp';
      case AuditAction.discount:
        return 'override_discount';
      case AuditAction.unknown:
        return 'unknown';
    }
  }

  String get label {
    switch (this) {
      case AuditAction.void_:
        return 'Void';
      case AuditAction.refund:
        return 'Refund';
      case AuditAction.comp:
        return 'Comp';
      case AuditAction.discount:
        return 'Discount';
      case AuditAction.unknown:
        return 'Other';
    }
  }

  String get labelBn {
    switch (this) {
      case AuditAction.void_:
        return 'ভয়েড';
      case AuditAction.refund:
        return 'রিফান্ড';
      case AuditAction.comp:
        return 'কম্প';
      case AuditAction.discount:
        return 'ডিসকাউন্ট';
      case AuditAction.unknown:
        return 'অন্যান্য';
    }
  }

  static AuditAction parse(String? value) {
    switch ((value ?? '').trim().toLowerCase()) {
      case 'void':
        return AuditAction.void_;
      case 'refund':
        return AuditAction.refund;
      case 'comp':
        return AuditAction.comp;
      case 'override_discount':
      case 'discount':
        return AuditAction.discount;
      default:
        return AuditAction.unknown;
    }
  }
}

class AuditEntry {
  AuditEntry({
    required this.id,
    required this.action,
    required this.createdAt,
    this.reason,
    this.amount,
    this.orderSerial,
    this.who,
    this.role,
  });

  final String id;
  final AuditAction action;
  final DateTime createdAt;
  final String? reason;
  final double? amount;
  final int? orderSerial;
  final String? who;
  final String? role;

  factory AuditEntry.fromJson(Map<String, Object?> json) {
    return AuditEntry(
      id: (json['id'] as String?) ?? '',
      action: AuditActionX.parse(json['action'] as String?),
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
      reason: (json['reason'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['reason'] as String?),
      amount: (json['amount'] as num?)?.toDouble(),
      orderSerial: (json['orderSerial'] as num?)?.toInt(),
      who: (json['who'] as String?),
      role: (json['role'] as String?),
    );
  }
}
