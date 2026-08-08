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
      padding: const EdgeInsets.all(PosSpacing.sp4),
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
              borderRadius: BorderRadius.circular(PosRadii.lg),
              border: Border.all(color: PosColors.line),
            ),
            child: Icon(Icons.sync_alt, color: accent, size: 20),
          ),
          const SizedBox(width: PosSpacing.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: PosSpacing.sp2,
                  runSpacing: PosSpacing.sp2 - 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TfText(
                      '${event.entityType} / ${event.action}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    StatusBadge.sync(event.status),
                  ],
                ),
                const SizedBox(height: PosSpacing.sp1 + 1),
                TfText(
                  event.entityId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: tfFontFamily(context),
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: PosColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (event.lastError != null) ...[
                  const SizedBox(height: PosSpacing.sp2 - 2),
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
          const SizedBox(width: PosSpacing.sp2),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TfText(
                DateFormat('h:mm a').format(event.updatedAt),
                style: TextStyle(
                  color: PosColors.textTer,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: PosSpacing.sp1),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PosSpacing.sp2,
                  vertical: PosSpacing.sp1 - 1,
                ),
                decoration: BoxDecoration(
                  color: PosColors.background,
                  borderRadius: BorderRadius.circular(PosRadii.pill),
                  border: Border.all(color: PosColors.lineStrong),
                ),
                child: TfText(
                  'Retry ${event.retryCount}',
                  style: TextStyle(
                    color: PosColors.slate,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
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
