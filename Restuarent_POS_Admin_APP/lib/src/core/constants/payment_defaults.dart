class PaymentDefaults {
  PaymentDefaults._();

  static bool requireBkashGate = bool.fromEnvironment(
    'POS_REQUIRE_BKASH_GATE',
    defaultValue: true,
  );

  static String sandboxAmountText = String.fromEnvironment(
    'POS_BKASH_SANDBOX_AMOUNT',
    defaultValue: '10',
  );

  static double get sandboxAmount {
    final parsed = double.tryParse(sandboxAmountText);
    if (parsed == null || parsed <= 0) return 10;
    return parsed;
  }

  static String bkashSandboxWallet = '01770618575';
  static String bkashSandboxOtp = '123456';
  static String bkashSandboxPin = '12121';

  static const double monthlyPlanAmount = 800;
  static const double annualPlanAmount = 9600;

  /// When true, skips real gateway and uses the built-in demo dialog.
  static bool useDemoBkashGateway = bool.fromEnvironment(
    'POS_BKASH_DEMO_MODE',
    defaultValue: false,
  );

  /// Use UddoktaPay checkout (sandbox by default on backend).
  static bool useUddoktaPay = bool.fromEnvironment(
    'POS_USE_UDDOKTAPAY',
    defaultValue: true,
  );
}
