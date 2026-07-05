import 'package:flutter/widgets.dart';
import 'package:local_pos/src/core/widgets/tf_design_system.dart'
    show tfFormatCurrency;

/// ৳ money formatter that reuses the app's locale-aware currency formatting
/// (Bangla numerals when the active locale is বাংলা). Whole amounts show no
/// decimals (৳250); fractional amounts show two (৳428.57) — matching the
/// Petpooja register.
String money(BuildContext context, num amount) {
  final whole = amount == amount.roundToDouble();
  return tfFormatCurrency(context, amount, decimalDigits: whole ? 0 : 2);
}
