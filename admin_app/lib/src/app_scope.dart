import 'package:flutter/widgets.dart';

import 'app_controller.dart';

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
