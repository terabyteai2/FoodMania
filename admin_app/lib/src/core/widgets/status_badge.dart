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
      color: switch (source) {
        OrderSource.cloud => PosColors.info,
        OrderSource.facebookMessenger => PosColors.success,
        OrderSource.whatsapp => const Color(0xFF128C7E),
        OrderSource.desktopPos => PosColors.primaryDark,
        OrderSource.manual => PosColors.warning,
        OrderSource.localLan => PosColors.primary,
      },
      icon: switch (source) {
        OrderSource.cloud => Icons.cloud_outlined,
        OrderSource.facebookMessenger => Icons.chat_bubble_outline_rounded,
        OrderSource.whatsapp => Icons.chat_outlined,
        OrderSource.desktopPos => Icons.desktop_windows_outlined,
        OrderSource.manual => Icons.edit_note,
        OrderSource.localLan => Icons.router_outlined,
      },
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
        horizontal: dense ? PosSpacing.sp2 : PosSpacing.sp2 + 1,
        vertical: dense ? PosSpacing.sp1 - 1 : PosSpacing.sp1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: foreground.withValues(alpha: 0.14), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 12 : 13.5, color: foreground),
            SizedBox(width: 5),
          ],
          TfText(
            label,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontSize: dense ? 12 : 13,
              letterSpacing: 0,
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
    if (color == PosColors.info) return PosColors.infoSoft;
    return PosColors.background;
  }

  static Color _foregroundFor(Color color) {
    if (color == PosColors.primary || color == PosColors.info) {
      return PosColors.accentStrong;
    }
    return color;
  }

  static Color _colorForOrderStatus(OrderStatus status) {
    switch (status.adminStatus) {
      case OrderStatus.pending:
        return PosColors.warning;
      case OrderStatus.accepted:
        return PosColors.primary;
      case OrderStatus.completed:
        return PosColors.success;
      case OrderStatus.rejected:
        return PosColors.danger;
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.served:
      case OrderStatus.cancelled:
        return _colorForOrderStatus(status.adminStatus);
    }
  }

  static IconData _iconForOrderStatus(OrderStatus status) {
    switch (status.adminStatus) {
      case OrderStatus.pending:
        return Icons.pending_actions_outlined;
      case OrderStatus.accepted:
        return Icons.check_circle_outline;
      case OrderStatus.completed:
        return Icons.done_all;
      case OrderStatus.rejected:
        return Icons.cancel_outlined;
      case OrderStatus.preparing:
      case OrderStatus.ready:
      case OrderStatus.served:
      case OrderStatus.cancelled:
        return _iconForOrderStatus(status.adminStatus);
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
