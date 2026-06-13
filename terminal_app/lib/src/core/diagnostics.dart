import 'package:flutter/foundation.dart';

/// Emits a diagnostic line only in debug builds.
///
/// The [message] closure is **not** invoked in profile/release builds, so the
/// (often multi-KB) interpolated strings these call sites build — e.g. dumping
/// the full order list on every sync tick — are never allocated on hot paths.
/// This matters on low-RAM POS terminals (e.g. Sunmi VS2, 878MB) where GC churn
/// from transient strings adds avoidable memory pressure.
///
/// `debugPrint` itself is *not* stripped in profile/release; only this guard
/// avoids both the print and the string construction.
void qbDiag(String Function() message) {
  if (kDebugMode) {
    debugPrint(message());
  }
}
