class WhatsAppChatbotConfig {
  const WhatsAppChatbotConfig({
    required this.isConfigured,
    required this.isEnabled,
    required this.orderingEnabled,
    this.phoneNumberId = '',
    this.displayPhoneNumber = '',
    this.tokenPreview = '',
    this.lastError = '',
  });

  final bool isConfigured;
  final bool isEnabled;
  final bool orderingEnabled;
  final String phoneNumberId;
  final String displayPhoneNumber;
  final String tokenPreview;
  final String lastError;

  bool get hasError => lastError.trim().isNotEmpty;

  static WhatsAppChatbotConfig fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    return WhatsAppChatbotConfig(
      isConfigured: data['isConfigured'] == true,
      isEnabled: data['isEnabled'] == true,
      orderingEnabled: data['orderingEnabled'] != false,
      phoneNumberId: data['phoneNumberId']?.toString().trim() ?? '',
      displayPhoneNumber: data['displayPhoneNumber']?.toString().trim() ?? '',
      tokenPreview: data['tokenPreview']?.toString().trim() ?? '',
      lastError: data['lastError']?.toString().trim() ?? '',
    );
  }
}
