import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/sync_event.dart';
import '../../models/sync_status.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';
import 'tf_design_system.dart';

class SyncEventTile extends StatelessWidget {
  const SyncEventTile({required this.event, super.key});

  final SyncEvent event;

  @override
  Widget build(BuildContext context) {
    final accent = switch (event.status) {
      SyncStatus.synced => PosColors.success,
      SyncStatus.pending => PosColors.warning,
      SyncStatus.failed => PosColors.danger,
    };
    return TfCard(
      padding: EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: event.status == SyncStatus.failed
                  ? PosColors.dangerSoft
                  : event.status == SyncStatus.synced
                  ? PosColors.successSoft
                  : PosColors.warningSoft,
              borderRadius: BorderRadius.circular(PosRadii.md),
              border: Border.all(color: PosColors.line),
            ),
            child: Icon(Icons.sync_alt, color: accent, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TfText(
                      '${event.entityType} / ${event.action}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    StatusBadge.sync(event.status),
                  ],
                ),
                SizedBox(height: 5),
                TfText(
                  event.entityId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontFamily: 'monospace',
                    color: PosColors.muted,
                  ),
                ),
                if (event.lastError != null) ...[
                  SizedBox(height: 6),
                  TfText(
                    event.lastError!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: PosColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TfText(
                DateFormat('h:mm a').format(event.updatedAt),
                style: TextStyle(
                  color: PosColors.slateSoft,
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                ),
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: PosColors.background,
                  borderRadius: BorderRadius.circular(PosRadii.pill),
                  border: Border.all(color: PosColors.lineStrong),
                ),
                child: TfText(
                  'Retry ${event.retryCount}',
                  style: TextStyle(
                    color: PosColors.slate,
                    fontWeight: FontWeight.w500,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
