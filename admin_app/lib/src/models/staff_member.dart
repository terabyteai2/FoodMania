import 'account_role.dart';

/// A staff member as returned by `GET /admin/staff` (spec §4.10 Staff).
class StaffMember {
  StaffMember({
    required this.id,
    required this.role,
    required this.isActive,
    this.displayName,
    this.phone,
    this.email,
    this.inviteStatus,
  });

  final String id;
  final AccountRole role;
  final bool isActive;
  final String? displayName;
  final String? phone;
  final String? email;
  final String? inviteStatus; // pending | accepted | declined | null

  bool get isPending => (inviteStatus ?? '').toLowerCase() == 'pending';

  String get name {
    final n = (displayName ?? '').trim();
    if (n.isNotEmpty) return n;
    final p = (phone ?? '').trim();
    if (p.isNotEmpty) return p;
    final e = (email ?? '').trim();
    return e.isNotEmpty ? e : 'Staff member';
  }

  String get initials {
    final source = name.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return parts
        .take(2)
        .map((w) => String.fromCharCode(w.runes.first))
        .join()
        .toUpperCase();
  }

  factory StaffMember.fromJson(Map<String, Object?> json) {
    return StaffMember(
      id: (json['id'] as String?) ?? '',
      role: AccountRole.parse(json['role'] as String?),
      isActive: (json['isActive'] as bool?) ?? false,
      displayName: (json['displayName'] as String?),
      phone: (json['phone'] as String?),
      email: (json['email'] as String?),
      inviteStatus: (json['inviteStatus'] as String?),
    );
  }
}
