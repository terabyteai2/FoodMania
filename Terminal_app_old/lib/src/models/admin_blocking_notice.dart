class AdminBlockingNotice {
  const AdminBlockingNotice({
    required this.enabled,
    required this.title,
    required this.message,
    required this.updatedAt,
  });

  final bool enabled;
  final String title;
  final String message;
  final DateTime? updatedAt;

  bool get isBlocking => enabled && message.trim().isNotEmpty;

  static AdminBlockingNotice disabled() {
    return const AdminBlockingNotice(
      enabled: false,
      title: '',
      message: '',
      updatedAt: null,
    );
  }

  factory AdminBlockingNotice.fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    final rawUpdatedAt = data['updatedAt']?.toString();
    return AdminBlockingNotice(
      enabled: data['enabled'] == true,
      title: data['title']?.toString().trim() ?? '',
      message: data['message']?.toString().trim() ?? '',
      updatedAt: rawUpdatedAt == null || rawUpdatedAt.isEmpty
          ? null
          : DateTime.tryParse(rawUpdatedAt),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'title': title,
      'message': message,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
