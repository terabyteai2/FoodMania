import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/status_badge.dart';
import '../../core/widgets/sync_event_tile.dart';
import '../../models/sync_event.dart';
import '../../models/sync_status.dart';
import '../../services/sync_service.dart';

class SyncStatusScreen extends StatelessWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sync = app.syncState;
    final lastSync = sync.lastSyncAt == null
        ? 'Never'
        : DateFormat('MMM d, h:mm a').format(sync.lastSyncAt!);

    return AppScaffold(
      title: 'Sync Status',
      subtitle: 'Cloud queue, failed events, retries, and health checks.',
      actions: [
        StatusBadge(
          label: sync.cloudConnected ? 'Cloud Connected' : 'Cloud Disconnected',
          color: sync.cloudConnected ? PosColors.success : PosColors.warning,
          icon: sync.cloudConnected
              ? Icons.cloud_done_outlined
              : Icons.cloud_off_outlined,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SyncSummaryGrid(
            pending: sync.pendingCount,
            failed: sync.failedCount,
            lastSync: lastSync,
            cloudEnabled: app.cloudConfig.enabled,
          ),
          SizedBox(height: 12),
          _SyncActions(app: app),
          SizedBox(height: 12),
          _SyncLogs(logs: sync.logs),
          SizedBox(height: 12),
          if (app.syncEvents.isEmpty)
            EmptyState(
              title: 'No sync events',
              message: 'Queued changes will appear here before cloud delivery.',
              icon: Icons.cloud_sync_outlined,
            )
          else
            _EventsList(events: app.syncEvents),
        ],
      ),
    );
  }
}

class _SyncSummaryGrid extends StatelessWidget {
  const _SyncSummaryGrid({
    required this.pending,
    required this.failed,
    required this.lastSync,
    required this.cloudEnabled,
  });

  final int pending;
  final int failed;
  final String lastSync;
  final bool cloudEnabled;

  @override
  Widget build(BuildContext context) {
    final values = [
      _SummaryValue(
        'Pending',
        pending.toString(),
        Icons.sync,
        PosColors.warning,
      ),
      _SummaryValue(
        'Failed',
        failed.toString(),
        Icons.error_outline,
        PosColors.danger,
      ),
      _SummaryValue('Last sync', lastSync, Icons.history, PosColors.primary),
      _SummaryValue(
        'Cloud',
        cloudEnabled ? 'Enabled' : 'Disabled',
        Icons.cloud_outlined,
        cloudEnabled ? PosColors.success : PosColors.muted,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 860 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: constraints.maxWidth >= 860 ? 2.2 : 1.55,
          children: values
              .map(
                (value) => Card(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: PosGradients.cardTint(value.color),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    value.color.withValues(alpha: 0.22),
                                    value.color.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(
                                  PosRadii.md,
                                ),
                                border: Border.all(
                                  color: value.color.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Icon(
                                value.icon,
                                color: value.color,
                                size: 19,
                              ),
                            ),
                            Spacer(),
                            Text(
                              value.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            SizedBox(height: 3),
                            Text(
                              value.label.toUpperCase(),
                              style: TextStyle(
                                color: PosColors.muted,
                                fontWeight: FontWeight.w800,
                                fontSize: 10.4,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _SyncActions extends StatelessWidget {
  const _SyncActions({required this.app});

  final PosAppController app;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            PrimaryButton(
              label: 'Sync Now',
              icon: Icons.sync,
              busy: app.syncState.isSyncing,
              onPressed: app.busy
                  ? null
                  : () async {
                      final ok = await app.syncNow();
                      if (!context.mounted) return;
                      _snack(context, ok ? 'Sync completed' : 'Sync failed');
                    },
            ),
            PrimaryButton(
              label: 'Retry Failed',
              icon: Icons.restart_alt,
              secondary: true,
              onPressed: app.busy
                  ? null
                  : () async {
                      final ok = await app.retryFailedSync();
                      if (!context.mounted) return;
                      _snack(context, ok ? 'Retry queued' : 'Retry failed');
                    },
            ),
            PrimaryButton(
              label: 'Test Cloud',
              icon: Icons.health_and_safety_outlined,
              secondary: true,
              onPressed: app.busy
                  ? null
                  : () async {
                      final ok = await app.testCloud();
                      if (!context.mounted) return;
                      _snack(
                        context,
                        ok ? 'Cloud API reachable' : 'Cloud API failed',
                      );
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SyncLogs extends StatelessWidget {
  const _SyncLogs({required this.logs});

  final List<SyncLogEntry> logs;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sync logs', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 10),
            if (logs.isEmpty)
              Text(
                'No sync logs yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              ...logs
                  .take(6)
                  .map(
                    (log) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            log.isError
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: log.isError
                                ? PosColors.danger
                                : PosColors.success,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              log.message,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  const _EventsList({required this.events});

  final List<SyncEvent> events;

  @override
  Widget build(BuildContext context) {
    final activeEvents = events
        .where((event) => event.status != SyncStatus.synced)
        .toList(growable: false);
    final visibleEvents = activeEvents.isEmpty
        ? events.take(12).toList()
        : activeEvents;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sync events', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 10),
        ListView.separated(
          itemCount: visibleEvents.length,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) =>
              SyncEventTile(event: visibleEvents[index]),
          separatorBuilder: (context, index) => SizedBox(height: 8),
        ),
      ],
    );
  }
}

class _SummaryValue {
  _SummaryValue(this.label, this.value, this.icon, this.color);

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}
