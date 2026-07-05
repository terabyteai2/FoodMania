import 'package:flutter/widgets.dart';
import 'package:local_pos/src/models/order_service_type.dart';

/// Intent to open the billing screen pre-set for a particular table / service.
class BillingSeed {
  const BillingSeed({
    this.tableLabel,
    this.serviceType = OrderServiceType.dineIn,
  });

  final String? tableLabel;
  final OrderServiceType serviceType;
}

/// Lightweight in-shell navigation exposed to descendant screens (Tables,
/// Overview) so they can jump to a rail destination or start an order for a
/// specific table without threading callbacks through every widget.
class DeskNav extends InheritedWidget {
  const DeskNav({
    required this.goToIndex,
    required this.startOrder,
    required super.child,
    super.key,
  });

  final void Function(int index) goToIndex;
  final void Function(BillingSeed seed) startOrder;

  static DeskNav of(BuildContext context) {
    final nav = context.dependOnInheritedWidgetOfExactType<DeskNav>();
    assert(nav != null, 'DeskNav was not found in the widget tree.');
    return nav!;
  }

  @override
  bool updateShouldNotify(DeskNav oldWidget) => false;
}
