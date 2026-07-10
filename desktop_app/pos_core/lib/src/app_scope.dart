import 'package:flutter/widgets.dart';

import 'app_controller.dart';

/// Reactive "slices" of [PosAppController] that a widget can subscribe to.
///
/// The controller is a single [ChangeNotifier]; subscribing to it as a whole
/// (via [AppScope.of]) rebuilds a widget on *every* `notifyListeners()` — a
/// printer heartbeat, a sync tick, a busy toggle. [AppModel] lets a widget
/// depend on just the aspects it reads, so unrelated notifications no longer
/// rebuild it. See [AppScope.select].
enum AppAspect {
  orders,
  menu,
  inventory,
  suppliers,
  notifications,
  sync,
  printer,
  dashboard,
  account,
  settings,
  language,
  appUpdate,
  chatbot,
}

class AppScope extends InheritedNotifier<PosAppController> {
  const AppScope({
    required PosAppController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// Subscribe to the whole controller — rebuilds on any change.
  /// Prefer [select]/[selectMany] for hot screens, or [read] for pure
  /// method calls that don't need to rebuild.
  static PosAppController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree.');
    return scope!.notifier!;
  }

  /// Get the controller WITHOUT registering a dependency — use in event
  /// handlers / for mutations & method calls where no rebuild is needed.
  static PosAppController read(BuildContext context) {
    final model = context.getInheritedWidgetOfExactType<AppModel>();
    if (model != null) return model.controller;
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree.');
    return scope!.notifier!;
  }

  /// Subscribe to a single [aspect]: the widget rebuilds only when that
  /// aspect's underlying state changes.
  ///
  /// Falls back to [of] (whole-controller subscription) when no [AppModel]
  /// ancestor is present — e.g. a widget test that wraps a screen in [AppScope]
  /// directly. Production always has [AppModel], so granularity is preserved.
  static PosAppController select(BuildContext context, AppAspect aspect) {
    final model = InheritedModel.inheritFrom<AppModel>(context, aspect: aspect);
    if (model != null) return model.controller;
    return of(context);
  }

  /// Subscribe to several [aspects] at once. Falls back to [of] when no
  /// [AppModel] ancestor is present (see [select]).
  static PosAppController selectMany(
    BuildContext context,
    List<AppAspect> aspects,
  ) {
    AppModel? model;
    for (final aspect in aspects) {
      model = InheritedModel.inheritFrom<AppModel>(context, aspect: aspect);
    }
    if (model != null) return model.controller;
    return of(context);
  }
}

/// Aspect-scoped view over [PosAppController]. Rebuilt on every controller
/// notification (it sits inside the top-level `AnimatedBuilder`), but only
/// notifies a dependent when one of *its* subscribed aspects actually changed.
///
/// Each aspect snapshot is compared with `==`: list/object aspects compare by
/// identity (the controller replaces collections wholesale on reload), and
/// value aspects (enums, records of scalars) compare by value.
class AppModel extends InheritedModel<AppAspect> {
  AppModel({required this.controller, required super.child, super.key})
    : _snapshot = _snap(controller);

  final PosAppController controller;
  final Map<AppAspect, Object?> _snapshot;

  static Map<AppAspect, Object?> _snap(PosAppController c) =>
      <AppAspect, Object?>{
        AppAspect.orders: (c.orders, c.hasMoreOrders, c.loadingMoreOrders),
        AppAspect.menu: c.menuItems,
        AppAspect.inventory: (c.inventoryItems, c.inventorySummary),
        AppAspect.suppliers: c.inventorySuppliers,
        AppAspect.notifications: c.notifications,
        AppAspect.sync: c.syncState,
        AppAspect.printer: c.printerState,
        AppAspect.dashboard: c.dashboardSummary,
        AppAspect.account: (c.isLoggedIn, c.accountRole, c.accountId),
        AppAspect.settings: c.serverConfig,
        AppAspect.language: c.language,
        AppAspect.appUpdate: c.pendingAppUpdate,
        AppAspect.chatbot: c.facebookChatbotConfig,
      };

  @override
  bool updateShouldNotify(AppModel old) {
    if (!identical(controller, old.controller)) return true;
    for (final aspect in AppAspect.values) {
      if (_snapshot[aspect] != old._snapshot[aspect]) return true;
    }
    return false;
  }

  @override
  bool updateShouldNotifyDependent(AppModel old, Set<AppAspect> dependencies) {
    for (final aspect in dependencies) {
      if (_snapshot[aspect] != old._snapshot[aspect]) return true;
    }
    return false;
  }
}
