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

  /// The app now offers only two operating modes — Simple and Advanced. The
  /// original four tiers are kept as enum values (for stored data / future
  /// use), but `simple`/`standard` collapse to "Simple" and
  /// `advanced`/`enterprise` collapse to "Advanced" for display.
  bool get isAdvanced => this == advanced || this == enterprise;

  /// The canonical mode this tier maps to for the two-mode picker.
  BusinessTier get canonicalMode => isAdvanced ? advanced : simple;

  String get displayName => isAdvanced ? 'Advanced' : 'Simple';

  String displayNameFor({required bool isBn}) {
    if (!isBn) return displayName;
    return isAdvanced ? 'অ্যাডভান্সড' : 'সিম্পল';
  }

  String get description => isAdvanced
      ? 'Full-service · margins · staff metrics · analytics'
      : 'Counter-first · simple ordering · receipt printing';
}
