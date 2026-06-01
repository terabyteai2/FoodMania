import 'package:flutter/widgets.dart';

import 'app_controller.dart';
import 'core/enums/business_tier.dart';

class AppScope extends InheritedNotifier<PosAppController> {
  const AppScope({
    required PosAppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static PosAppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree.');
    return scope!.notifier!;
  }
}

/// Provides the active [BusinessTier] to the subtree.
/// Rebuilt whenever the tier changes via [AppScope].
class TierScope extends StatelessWidget {
  const TierScope({required this.child, super.key});

  final Widget child;

  static BusinessTier of(BuildContext context) {
    final app = context.dependOnInheritedWidgetOfExactType<AppScope>();
    return app?.notifier?.businessTier ?? BusinessTier.standard;
  }

  @override
  Widget build(BuildContext context) => child;
}
