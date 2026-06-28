import 'package:flutter/widgets.dart';

/// Provided by the phone [MainShell] around its body so the shared
/// [AppPageHeader] can surface a top-left hamburger that opens the nav drawer.
///
/// It is intentionally absent on the wide (NavigationRail) layout and on pushed
/// detail routes, so the hamburger only appears where a drawer actually exists —
/// pushed/detail screens keep their own back button instead.
class ShellNavScope extends InheritedWidget {
  const ShellNavScope({
    required this.openDrawer,
    required super.child,
    super.key,
  });

  /// Opens the [MainShell]'s navigation drawer.
  final VoidCallback openDrawer;

  static ShellNavScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNavScope>();

  @override
  bool updateShouldNotify(ShellNavScope oldWidget) =>
      openDrawer != oldWidget.openDrawer;
}
