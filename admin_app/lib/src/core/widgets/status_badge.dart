import 'package:flutter/material.dart';

import '../../models/order_source.dart';
import '../../models/order_status.dart';
import '../../models/sync_status.dart';
import '../theme/app_theme.dart';
import 'tf_design_system.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
    super.key,
  });

  factory StatusBadge.order(OrderStatus status) {
    return StatusBadge(
      label: status.label,
      color: _colorForOrderStatus(status),
      icon: _iconForOrderStatus(status),
    );
  }

  factory StatusBadge.sync(SyncStatus status) {
    return StatusBadge(
      label: status.label,
      color: _colorForSyncStatus(status),
      icon: _iconForSyncStatus(status),
    );
  }

  factory StatusBadge.source(OrderSource source) {
    return StatusBadge(
      label: source.label,
      color: source == OrderSource.cloud
          ? PosColors.info
          : source == OrderSource.manual
          ? PosColors.warning
          : PosColors.primary,
      icon: source == OrderSource.cloud
          ? Icons.cloud_outlined
          : source == OrderSource.manual
          ? Icons.edit_note
          : Icons.router_outlined,
    );
  }

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final foreground = _foregroundFor(color);
    final background = _backgroundFor(color);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: foreground.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 13.5, color: foreground),
            SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontFamily: tfFontFamily(context),
              fontWeight: FontWeight.w500,
              fontSize: dense ? 10.5 : 11,
              letterSpacing: tfIsBn(context) ? 0 : 0.2,
            ),
          ),
        ],
      ),
    );
  }

  static Color _backgroundFor(Color color) {
    if (color == PosColors.success) return PosColors.successSoft;
    if (color == PosColors.warning) return PosColors.warningSoft;
    if (color == PosColors.primary) return PosColors.primarySoft;
    if (color == PosColors.danger) return PosColors.dangerSoft;
    return PosColors.background;
  }

  static Color _foregroundFor(Color color) {
    if (color == PosColors.primary) return PosColors.primaryDark;
    if (color == PosColors.info) return PosColors.muted;
    return color;
  }

  static Color _colorForOrderStatus(OrderStatus status) {
    switch (status.adminStatus) {
      case OrderStatus.pending:
        return PosColors.warning;
      case OrderStatus.accepted:
        return PosColors.primaryDark;
      case OrderStatus.preparing:
        return PosColors.primaryDark;
      case OrderStatus.ready:
        return PosColors.primaryDark;
      case OrderStatus.served:
        return PosColors.success;
      case OrderStatus.cancelled:
        return PosColors.danger;
    }
  }

  static IconData _iconForOrderStatus(OrderStatus status) {
    switch (status.adminStatus) {
      case OrderStatus.pending:
        return Icons.pending_actions_outlined;
      case OrderStatus.accepted:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.check_circle_outline;
      case OrderStatus.ready:
        return Icons.check_circle_outline;
      case OrderStatus.served:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  static Color _colorForSyncStatus(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return PosColors.success;
      case SyncStatus.pending:
        return PosColors.warning;
      case SyncStatus.failed:
        return PosColors.danger;
    }
  }

  static IconData _iconForSyncStatus(SyncStatus status) {
    switch (status) {
      case SyncStatus.synced:
        return Icons.cloud_done_outlined;
      case SyncStatus.pending:
        return Icons.sync_outlined;
      case SyncStatus.failed:
        return Icons.cloud_off_outlined;
    }
  }
}
