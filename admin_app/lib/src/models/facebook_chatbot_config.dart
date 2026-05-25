class FacebookChatbotConfig {
  const FacebookChatbotConfig({
    required this.isConfigured,
    required this.isEnabled,
    required this.orderingEnabled,
    this.pageId = '',
    this.pageName = '',
    this.tokenPreview = '',
    this.lastError = '',
  });

  final bool isConfigured;
  final bool isEnabled;
  final bool orderingEnabled;
  final String pageId;
  final String pageName;
  final String tokenPreview;
  final String lastError;

  bool get hasError => lastError.trim().isNotEmpty;

  static FacebookChatbotConfig fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    return FacebookChatbotConfig(
      isConfigured: data['isConfigured'] == true,
      isEnabled: data['isEnabled'] == true,
      orderingEnabled: data['orderingEnabled'] != false,
      pageId: data['pageId']?.toString().trim() ?? '',
      pageName: data['pageName']?.toString().trim() ?? '',
      tokenPreview: data['tokenPreview']?.toString().trim() ?? '',
      lastError: data['lastError']?.toString().trim() ?? '',
    );
  }
}

class FacebookChatbotOAuthStart {
  const FacebookChatbotOAuthStart({
    required this.authorizationUrl,
    required this.expiresInSeconds,
  });

  final String authorizationUrl;
  final int expiresInSeconds;

  static FacebookChatbotOAuthStart fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    return FacebookChatbotOAuthStart(
      authorizationUrl: data['authorizationUrl']?.toString().trim() ?? '',
      expiresInSeconds: data['expiresInSeconds'] is num
          ? (data['expiresInSeconds'] as num).toInt()
          : int.tryParse('${data['expiresInSeconds']}') ?? 0,
    );
  }
}
