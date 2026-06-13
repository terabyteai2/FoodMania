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

class FacebookChatbotPage {
  const FacebookChatbotPage({required this.pageId, required this.pageName});

  final String pageId;
  final String pageName;

  static FacebookChatbotPage fromJson(Map<String, Object?> json) {
    return FacebookChatbotPage(
      pageId: json['pageId']?.toString().trim() ?? '',
      pageName: json['pageName']?.toString().trim() ?? '',
    );
  }
}

class FacebookChatbotOAuthPages {
  const FacebookChatbotOAuthPages({
    required this.sessionId,
    required this.pages,
  });

  final String sessionId;
  final List<FacebookChatbotPage> pages;

  static FacebookChatbotOAuthPages fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    final rawPages = data['pages'] is List ? data['pages'] as List : const [];
    return FacebookChatbotOAuthPages(
      sessionId: data['sessionId']?.toString().trim() ?? '',
      pages: rawPages
          .whereType<Map>()
          .map(
            (page) =>
                FacebookChatbotPage.fromJson(Map<String, Object?>.from(page)),
          )
          .where((page) => page.pageId.isNotEmpty)
          .toList(growable: false),
    );
  }
}
