class AppUpdateInfo {
  const AppUpdateInfo({
    required this.enabled,
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.releaseNotes,
    required this.required,
    required this.publishedAt,
  });

  final bool enabled;
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String releaseNotes;
  final bool required;
  final DateTime? publishedAt;

  bool get isUsable =>
      enabled &&
      versionName.trim().isNotEmpty &&
      versionCode > 0 &&
      apkUrl.trim().isNotEmpty;

  bool isNewerThan(int currentVersionCode) {
    return isUsable && versionCode > currentVersionCode;
  }

  static AppUpdateInfo disabled() {
    return AppUpdateInfo(
      enabled: false,
      versionName: '',
      versionCode: 0,
      apkUrl: '',
      releaseNotes: '',
      required: false,
      publishedAt: null,
    );
  }

  factory AppUpdateInfo.fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    final rawPublishedAt = data['publishedAt']?.toString();
    return AppUpdateInfo(
      enabled: data['enabled'] == true,
      versionName: data['versionName']?.toString().trim() ?? '',
      versionCode: _intValue(data['versionCode']),
      apkUrl: data['apkUrl']?.toString().trim() ?? '',
      releaseNotes: data['releaseNotes']?.toString().trim() ?? '',
      required: data['required'] == true,
      publishedAt: rawPublishedAt == null || rawPublishedAt.isEmpty
          ? null
          : DateTime.tryParse(rawPublishedAt),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'enabled': enabled,
      'versionName': versionName,
      'versionCode': versionCode,
      'apkUrl': apkUrl,
      'releaseNotes': releaseNotes,
      'required': required,
      'publishedAt': publishedAt?.toIso8601String(),
    };
  }

  static int _intValue(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
