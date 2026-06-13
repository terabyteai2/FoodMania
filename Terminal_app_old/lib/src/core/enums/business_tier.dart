/// The four Complexity Dial positions.
/// Each tier progressively reveals more UI and features.
enum BusinessTier {
  /// Juice bars, tea stalls, counter-only — single operator, no floor maps.
  simple,

  /// Small dine-in (5–10 tables), 2–3 staff — floor management begins.
  standard,

  /// Full-service (11–20 tables), 5–8 staff — margin tracking, staff metrics.
  advanced,

  /// Multi-location fleets (2–10 outlets) — cross-outlet analytics.
  enterprise;

  static BusinessTier fromString(String? value) {
    return switch (value) {
      'simple' => simple,
      'standard' => standard,
      'advanced' => advanced,
      'enterprise' => enterprise,
      _ => standard,
    };
  }

  String get key => name;

  String get displayName => switch (this) {
    simple => 'FoodCart',
    standard => 'Cafe',
    advanced => 'Restaurant',
    enterprise => 'Enterprise',
  };

  String displayNameFor({required bool isBn}) {
    if (!isBn) return displayName;
    return switch (this) {
      simple => 'ফুডকার্ট',
      standard => 'ক্যাফে',
      advanced => 'রেস্টুরেন্ট',
      enterprise => 'এন্টারপ্রাইজ',
    };
  }

  String get description => switch (this) {
    simple => 'Counter-only · no floor map · receipt printing',
    standard => 'Dine-in · table floor · kitchen send',
    advanced => 'Full-service · food cost % · staff metrics',
    enterprise => 'Multi-outlet fleet · cross-location analytics',
  };
}
