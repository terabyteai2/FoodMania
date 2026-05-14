class BkashPaymentSession {
  BkashPaymentSession({
    required this.paymentId,
    required this.checkoutUrl,
    required this.status,
    required this.amount,
    required this.currency,
    this.transactionId,
    this.merchantInvoiceNumber,
    this.lastError,
  });

  final String paymentId;
  final String checkoutUrl;
  final String status;
  final double amount;
  final String currency;
  final String? transactionId;
  final String? merchantInvoiceNumber;
  final String? lastError;

  bool get paid => status == 'paid' || transactionId?.trim().isNotEmpty == true;

  static BkashPaymentSession fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map
        ? Map<String, Object?>.from(json['data'] as Map)
        : json;
    return BkashPaymentSession(
      paymentId: _required(data, 'paymentId'),
      checkoutUrl: _string(data['checkoutUrl']),
      status: _required(data, 'status'),
      amount: _number(data['amount']),
      currency: _string(data['currency']).isEmpty
          ? 'BDT'
          : _string(data['currency']),
      transactionId: _nullable(data['transactionId']),
      merchantInvoiceNumber: _nullable(data['merchantInvoiceNumber']),
      lastError: _nullable(data['lastError']),
    );
  }

  static String _required(Map<String, Object?> json, String key) {
    final value = _string(json[key]);
    if (value.isEmpty) {
      throw FormatException('bKash response is missing $key.');
    }
    return value;
  }

  static String _string(Object? value) => value?.toString().trim() ?? '';

  static String? _nullable(Object? value) {
    final text = _string(value);
    return text.isEmpty ? null : text;
  }

  static double _number(Object? value) {
    final parsed = double.tryParse(value?.toString() ?? '');
    return parsed ?? 0;
  }
}
