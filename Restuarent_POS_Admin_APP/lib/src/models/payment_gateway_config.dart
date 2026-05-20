class PaymentGatewayConfig {
  PaymentGatewayConfig({
    required this.uddoktaPayEnabled,
    required this.uddoktaPaySandbox,
    required this.uddoktaPayBaseUrl,
    required this.callbackBaseUrl,
    this.redirectUrlWarning,
  });

  final bool uddoktaPayEnabled;
  final bool uddoktaPaySandbox;
  final String uddoktaPayBaseUrl;
  final String callbackBaseUrl;
  final String? redirectUrlWarning;

  static PaymentGatewayConfig? fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    return PaymentGatewayConfig(
      uddoktaPayEnabled: data['uddoktaPayEnabled'] == true,
      uddoktaPaySandbox: data['uddoktaPaySandbox'] == true,
      uddoktaPayBaseUrl: data['uddoktaPayBaseUrl']?.toString().trim() ?? '',
      callbackBaseUrl: data['callbackBaseUrl']?.toString().trim() ?? '',
      redirectUrlWarning: _nullable(data['redirectUrlWarning']),
    );
  }

  static String? _nullable(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
