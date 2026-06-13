class AdminBlockingNotice {
  const AdminBlockingNotice({
    required this.enabled,
    required this.title,
    required this.message,
    this.imageUrl,
    this.inputField = false,
    this.inputLabel,
    required this.updatedAt,
  });

  final bool enabled;
  final String title;
  final String message;
  final String? imageUrl;
  final bool inputField;
  final String? inputLabel;
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
      imageUrl: () {
            final v = data['imageUrl']?.toString().trim();
            return (v != null && v.isNotEmpty) ? v : null;
          }(),
      inputField: data['inputField'] == true,
      inputLabel: () {
            final v = data['inputLabel']?.toString().trim();
            return (v != null && v.isNotEmpty) ? v : null;
          }(),
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
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (inputField) 'inputField': inputField,
      if (inputLabel != null) 'inputLabel': inputLabel,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
