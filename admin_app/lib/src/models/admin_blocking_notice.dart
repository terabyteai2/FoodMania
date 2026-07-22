enum BlockingNoticeType { adminNotice, announcement, subscription, paymentLink }

class AdminBlockingNotice {
  const AdminBlockingNotice({
    required this.enabled,
    required this.title,
    required this.message,
    this.imageUrl,
    this.inputField = false,
    this.inputLabel,
    required this.updatedAt,
    this.type = BlockingNoticeType.adminNotice,
    this.ctaLabel,
    this.ctaUrl,
    this.dismissible = false,
  });

  final bool enabled;
  final String title;
  final String message;
  final String? imageUrl;
  final bool inputField;
  final String? inputLabel;
  final DateTime? updatedAt;
  final BlockingNoticeType type;
  final String? ctaLabel;
  final String? ctaUrl;
  final bool dismissible;

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
      type: switch (data['type']?.toString().trim()) {
        'announcement' => BlockingNoticeType.announcement,
        'subscription' => BlockingNoticeType.subscription,
        'paymentLink' => BlockingNoticeType.paymentLink,
        _ => BlockingNoticeType.adminNotice,
      },
      ctaLabel: () {
        final v = data['ctaLabel']?.toString().trim();
        return (v != null && v.isNotEmpty) ? v : null;
      }(),
      ctaUrl: () {
        final v = data['ctaUrl']?.toString().trim();
        return (v != null && v.isNotEmpty) ? v : null;
      }(),
      dismissible: data['dismissible'] == true,
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
      'type': type.name,
      if (ctaLabel != null) 'ctaLabel': ctaLabel,
      if (ctaUrl != null) 'ctaUrl': ctaUrl,
      'dismissible': dismissible,
    };
  }
}
