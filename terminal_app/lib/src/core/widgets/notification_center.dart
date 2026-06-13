import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../app_controller.dart';
import '../../models/pos_notification.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';
import 'tf_design_system.dart';

/// Opens the global notifications panel. Rendered as a slide-down shade
/// anchored to the top of the screen (similar to a phone's notification
/// shade) so it never covers the main interaction cards below. Tapping
/// outside the panel — or any item — dismisses it. `onNavigateToOrders` is
/// invoked when the user taps a notification with a related app target.
void showNotificationCenter(
  BuildContext context, {
  required VoidCallback onNavigateToOrders,
  ValueChanged<PosNotificationTarget>? onNavigateToTarget,
}) {
  final app = AppScope.of(context);
  final text = app.strings;
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: text.notificationsTitle,
    barrierColor: Colors.black.withValues(alpha: 0.25),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, _, _) {
      return Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: Material(
              type: MaterialType.transparency,
              child: _NotificationShade(
                onNavigateToOrders: onNavigateToOrders,
                onNavigateToTarget: onNavigateToTarget,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: curved, child: child),
      );
    },
  );
}

enum _NotifCategory { all, orders, stock, online, staff }

_NotifCategory _categoryOf(PosNotification n) {
  switch (n.type) {
    case PosNotificationType.pendingOrder:
      final body = '${n.title} ${n.body}'.toLowerCase();
      if (body.contains('foodpanda') ||
          body.contains('pathao') ||
          body.contains('uber') ||
          body.contains('online')) {
        return _NotifCategory.online;
      }
      return _NotifCategory.orders;
    case PosNotificationType.acceptedOrder:
    case PosNotificationType.printSuccess:
    case PosNotificationType.printFailed:
      return _NotifCategory.orders;
    case PosNotificationType.system:
      final body = '${n.title} ${n.body}'.toLowerCase();
      if (body.contains('stock') ||
          body.contains('inventory') ||
          body.contains('স্টক') ||
          body.contains('ইনভেন্টরি')) {
        return _NotifCategory.stock;
      }
      if (body.contains('staff') ||
          body.contains('signed in') ||
          body.contains('waiter') ||
          body.contains('স্টাফ')) {
        return _NotifCategory.staff;
      }
      return _NotifCategory.orders;
  }
}

class _NotificationShade extends StatefulWidget {
  const _NotificationShade({
    required this.onNavigateToOrders,
    required this.onNavigateToTarget,
  });

  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  State<_NotificationShade> createState() => _NotificationShadeState();
}

class _NotificationShadeState extends State<_NotificationShade> {
  _NotifCategory _filter = _NotifCategory.all;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final items = app.notifications;
    final mediaHeight = MediaQuery.sizeOf(context).height;
    // Cap the shade at ~70% of the screen so the main interface stays visible
    // underneath, but the inbox has room for tabs + grouped sections.
    final maxHeight = mediaHeight * 0.70;
    final unread = items.where((n) => !n.isRead).length;

    final counts = <_NotifCategory, int>{
      for (final c in _NotifCategory.values) c: 0,
    };
    for (final n in items) {
      counts[_NotifCategory.all] = counts[_NotifCategory.all]! + 1;
      counts[_categoryOf(n)] = counts[_categoryOf(n)]! + 1;
    }

    final filtered = _filter == _NotifCategory.all
        ? items
        : items.where((n) => _categoryOf(n) == _filter).toList();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.tile),
          border: Border.all(color: PosColors.lineStrong, width: 1),
          boxShadow: PosShadows.glow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PosRadii.tile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShadeHeader(
                title: text.notificationsTitle,
                unreadLabel: unread > 0 ? text.unreadCountLabel(unread) : null,
                onMarkAllRead: unread > 0
                    ? () => app.markAllNotificationsRead()
                    : null,
                onClose: () => Navigator.of(context).pop(),
                markAllLabel: text.markAllRead,
              ),
              _CategoryTabs(
                active: _filter,
                counts: counts,
                onSelect: (c) => setState(() => _filter = c),
                labels: {
                  _NotifCategory.all: text.notifTabAll,
                  _NotifCategory.orders: text.notifTabOrders,
                  _NotifCategory.stock: text.notifTabStock,
                  _NotifCategory.online: text.notifTabOnline,
                  _NotifCategory.staff: text.notifTabStaff,
                },
              ),
              const Divider(height: 1, thickness: 1, color: PosColors.line),
              if (filtered.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
                  child: Text(
                    text.noNotificationsYet,
                    style: TextStyle(
                      color: PosColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Flexible(
                  child: _InboxList(
                    items: filtered,
                    app: app,
                    text: text,
                    onNavigateToOrders: widget.onNavigateToOrders,
                    onNavigateToTarget: widget.onNavigateToTarget,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShadeHeader extends StatelessWidget {
  const _ShadeHeader({
    required this.title,
    required this.unreadLabel,
    required this.onMarkAllRead,
    required this.onClose,
    required this.markAllLabel,
  });

  final String title;
  final String? unreadLabel;
  final VoidCallback? onMarkAllRead;
  final VoidCallback onClose;
  final String markAllLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: PosColors.slate,
                    height: 1.2,
                  ),
                ),
                if (unreadLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    unreadLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PosColors.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onMarkAllRead != null)
            TextButton(
              onPressed: onMarkAllRead,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                visualDensity: VisualDensity.compact,
                foregroundColor: PosColors.primaryDark,
              ),
              child: Text(
                markAllLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: PosColors.muted,
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.active,
    required this.counts,
    required this.onSelect,
    required this.labels,
  });

  final _NotifCategory active;
  final Map<_NotifCategory, int> counts;
  final ValueChanged<_NotifCategory> onSelect;
  final Map<_NotifCategory, String> labels;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        children: [
          for (final c in _NotifCategory.values) ...[
            _TabPill(
              label: labels[c]!,
              count: counts[c] ?? 0,
              active: active == c,
              onTap: () => onSelect(c),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? PosColors.primaryDark : PosColors.surface,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: active ? PosColors.primaryDark : PosColors.line,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TfText(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : PosColors.slate,
                  height: 1,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 5),
                TfText(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? Colors.white.withValues(alpha: 0.85)
                        : PosColors.muted,
                    height: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxList extends StatelessWidget {
  const _InboxList({
    required this.items,
    required this.app,
    required this.text,
    required this.onNavigateToOrders,
    required this.onNavigateToTarget,
  });

  final List<PosNotification> items;
  final PosAppController app;
  final AppStrings text;
  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final today = <PosNotification>[];
    final earlier = <PosNotification>[];
    for (final n in items) {
      if (n.createdAt.isAfter(startOfToday)) {
        today.add(n);
      } else {
        earlier.add(n);
      }
    }

    final blocks = <Widget>[];
    if (today.isNotEmpty) {
      blocks.add(_SectionLabel(text.notifSectionToday));
      blocks.addAll(_buildGroupedBlocks(context, today));
    }

    if (earlier.isNotEmpty) {
      if (blocks.isNotEmpty) blocks.add(const SizedBox(height: 6));
      blocks.add(_SectionLabel(text.notifSectionEarlier));
      blocks.addAll(_buildGroupedBlocks(context, earlier));
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
      children: blocks,
    );
  }

  Widget _buildBanner(BuildContext context, PosNotification item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _NotificationBanner(
        item: item,
        time: tfIsBn(context)
            ? tfToBnNumbers(DateFormat('HH:mm', 'bn_BD').format(item.createdAt))
            : DateFormat('HH:mm', 'en_US').format(item.createdAt),
        viewLabel: text.viewAction,
        acceptLabel: text.acceptAction,
        onTap: () {
          app.markNotificationRead(item.id);
          Navigator.of(context).pop();
          _navigate(item.target);
        },
      ),
    );
  }

  List<Widget> _buildGroupedBlocks(
    BuildContext context,
    List<PosNotification> source,
  ) {
    final groupedIds = <String>{};
    final entries = <_NotificationListEntry>[];
    for (final type in PosNotificationType.values) {
      final group = source
          .where((n) => !n.isRead && n.type == type)
          .toList(growable: false);
      if (group.length <= 1) continue;
      groupedIds.addAll(group.map((n) => n.id));
      group.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      entries.add(_NotificationListEntry.group(group));
    }
    for (final item in source.where((n) => !groupedIds.contains(n.id))) {
      entries.add(_NotificationListEntry.single(item));
    }
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return [
      for (final entry in entries)
        if (entry.group == null)
          _buildBanner(context, entry.single!)
        else
          _buildGroupTile(context, entry.group!),
    ];
  }

  Widget _buildGroupTile(BuildContext context, List<PosNotification> group) {
    final first = group.first;
    final target = first.target;
    return _PendingOrdersGroupTile(
      count: group.length,
      latestTime: first.createdAt,
      onTap: () {
        for (final n in group) {
          app.markNotificationRead(n.id);
        }
        Navigator.of(context).pop();
        _navigate(target);
      },
      title: _groupTitle(first.type, group.length),
      body: _groupBody(first.type),
      viewLabel: text.viewAction,
    );
  }

  String _groupTitle(PosNotificationType type, int count) {
    final n = text.isBn ? tfToBnNumbers('$count') : '$count';
    switch (type) {
      case PosNotificationType.pendingOrder:
        return text.isBn ? '$n টি পেন্ডিং অর্ডার' : '$n pending orders';
      case PosNotificationType.acceptedOrder:
        return text.isBn
            ? '$n টি অর্ডার অ্যাকসেপ্ট হয়েছে'
            : '$n orders accepted';
      case PosNotificationType.printSuccess:
        return text.isBn ? '$n টি টিকেট প্রিন্ট হয়েছে' : '$n tickets printed';
      case PosNotificationType.printFailed:
        return text.isBn ? '$n টি প্রিন্টার অ্যালার্ট' : '$n printer alerts';
      case PosNotificationType.system:
        return text.isBn
            ? '$n টি সিস্টেম নোটিফিকেশন'
            : '$n system notifications';
    }
  }

  String _groupBody(PosNotificationType type) {
    switch (type) {
      case PosNotificationType.pendingOrder:
        return text.pendingOrdersGroupBody;
      case PosNotificationType.acceptedOrder:
        return text.isBn
            ? 'অর্ডার তালিকা খুলতে ট্যাপ করুন।'
            : 'Tap to open the orders list.';
      case PosNotificationType.printFailed:
        return text.isBn
            ? 'প্রিন্টার সেটিংস খুলতে ট্যাপ করুন।'
            : 'Tap to open printer settings.';
      case PosNotificationType.printSuccess:
        return text.isBn
            ? 'প্রিন্টেড অর্ডার দেখতে ট্যাপ করুন।'
            : 'Tap to view printed orders.';
      case PosNotificationType.system:
        return text.isBn
            ? 'বিস্তারিত দেখতে ট্যাপ করুন।'
            : 'Tap to view details.';
    }
  }

  void _navigate(PosNotificationTarget target) {
    if (target == PosNotificationTarget.orders) {
      onNavigateToOrders();
      return;
    }
    if (target != PosNotificationTarget.none) {
      onNavigateToTarget?.call(target);
    }
  }
}

class _NotificationListEntry {
  const _NotificationListEntry.single(this.single) : group = null;
  const _NotificationListEntry.group(this.group) : single = null;

  final PosNotification? single;
  final List<PosNotification>? group;

  DateTime get createdAt => single?.createdAt ?? group!.first.createdAt;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: PosColors.muted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _PendingOrdersGroupTile extends StatelessWidget {
  const _PendingOrdersGroupTile({
    required this.count,
    required this.latestTime,
    required this.onTap,
    required this.title,
    required this.body,
    required this.viewLabel,
  });

  final int count;
  final DateTime latestTime;
  final VoidCallback onTap;
  final String title;
  final String body;
  final String viewLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: PosColors.primarySoft,
        borderRadius: BorderRadius.circular(PosRadii.tile),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: PosColors.primary,
                    borderRadius: BorderRadius.circular(PosRadii.tag),
                  ),
                  alignment: Alignment.center,
                  child: TfText(
                    '$count',
                    style: const TextStyle(
                      color: PosColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TfText(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PosColors.slate,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      TfText(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: PosColors.slate.withValues(alpha: 0.75),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _MiniActionButton(label: viewLabel, onTap: onTap, filled: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({
    required this.item,
    required this.time,
    required this.viewLabel,
    required this.acceptLabel,
    required this.onTap,
  });

  final PosNotification item;
  final String time;
  final String viewLabel;
  final String acceptLabel;
  final VoidCallback onTap;

  Color _iconBg() {
    switch (item.type) {
      case PosNotificationType.pendingOrder:
        return PosColors.primary;
      case PosNotificationType.acceptedOrder:
        return PosColors.success;
      case PosNotificationType.printFailed:
        return PosColors.danger;
      case PosNotificationType.printSuccess:
        return PosColors.successSoft;
      case PosNotificationType.system:
        return PosColors.mutedSoft;
    }
  }

  IconData _iconFor() {
    switch (item.type) {
      case PosNotificationType.pendingOrder:
        return Icons.receipt_long_rounded;
      case PosNotificationType.acceptedOrder:
        return Icons.check_circle_rounded;
      case PosNotificationType.printSuccess:
        return Icons.print_rounded;
      case PosNotificationType.printFailed:
        return Icons.print_disabled_rounded;
      case PosNotificationType.system:
        return Icons.info_rounded;
    }
  }

  Color _iconFg() {
    switch (item.type) {
      case PosNotificationType.pendingOrder:
        return PosColors.primaryDark;
      case PosNotificationType.acceptedOrder:
      case PosNotificationType.printFailed:
        return Colors.white;
      case PosNotificationType.printSuccess:
        return PosColors.success;
      case PosNotificationType.system:
        return PosColors.slate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRead = item.isRead;
    final bg = isRead ? PosColors.surface : PosColors.surface;
    final showAccept = !isRead && item.type == PosNotificationType.pendingOrder;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(PosRadii.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.tile),
            border: Border.all(
              color: isRead ? PosColors.line : PosColors.primary,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _iconBg(),
                  borderRadius: BorderRadius.circular(PosRadii.tag),
                ),
                alignment: Alignment.center,
                child: Icon(_iconFor(), color: _iconFg(), size: 16),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: PosColors.slate,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          time,
                          style: TextStyle(
                            color: PosColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PosColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                    if (showAccept) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _MiniActionButton(
                            label: acceptLabel,
                            onTap: onTap,
                            filled: true,
                          ),
                          const SizedBox(width: 6),
                          _MiniActionButton(
                            label: viewLabel,
                            onTap: onTap,
                            filled: false,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniActionButton extends StatelessWidget {
  const _MiniActionButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? PosColors.primary : PosColors.surface;
    final fg = filled ? PosColors.primaryDark : PosColors.slate;
    final border = filled ? PosColors.primary : PosColors.line;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border, width: 0.5),
          ),
          child: TfText(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Show a non-blocking notification banner at the TOP of the screen.
void showTopNotificationToast(
  BuildContext context, {
  required String title,
  required String body,
  VoidCallback? onOpen,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final text = AppScope.of(context).strings;
  late OverlayEntry entry;
  Timer? dismissTimer;
  var closed = false;
  void close() {
    if (closed) return;
    closed = true;
    dismissTimer?.cancel();
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      return Positioned(
        top: media.padding.top + 8,
        left: 12,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) {
              if (details.delta.dy < -6 || details.delta.dx.abs() > 8) {
                close();
              }
            },
            onPanEnd: (details) {
              final velocity = details.velocity.pixelsPerSecond;
              if (velocity.dy < -40 || velocity.dx.abs() > 40) close();
            },
            child: _TopToastCard(
              title: title,
              body: body,
              acceptLabel: text.openAction,
              onAccept: onOpen == null
                  ? null
                  : () {
                      close();
                      onOpen();
                    },
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  dismissTimer = Timer(duration, close);
}

class _TopToastCard extends StatelessWidget {
  const _TopToastCard({
    required this.title,
    required this.body,
    required this.acceptLabel,
    required this.onAccept,
  });

  final String title;
  final String body;
  final String acceptLabel;
  final VoidCallback? onAccept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: PosColors.primaryDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.primary, width: 1),
        boxShadow: PosShadows.glow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: PosColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long_rounded,
              color: PosColors.primaryDark,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onAccept != null)
            _ToastButton(label: acceptLabel, onTap: onAccept!, filled: true),
        ],
      ),
    );
  }
}

class _ToastButton extends StatelessWidget {
  const _ToastButton({
    required this.label,
    required this.onTap,
    required this.filled,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? PosColors.primary : Colors.transparent;
    final fg = filled ? PosColors.primaryDark : Colors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          constraints: const BoxConstraints(minWidth: 64),
          alignment: Alignment.center,
          child: TfText(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w500,
              fontSize: 11.5,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Drop-in bell button for any page header.
class HeaderNotificationBell extends StatelessWidget {
  const HeaderNotificationBell({
    required this.onNavigateToOrders,
    this.onNavigateToTarget,
    super.key,
  });

  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final unread = app.unreadNotificationCount;
    return TfBarButton(
      icon: TfSourceIconName.bell,
      tooltip: app.strings.notificationsTitle,
      badge: unread,
      onPressed: () => showNotificationCenter(
        context,
        onNavigateToOrders: onNavigateToOrders,
        onNavigateToTarget: onNavigateToTarget,
      ),
    );
  }
}

/// A floating bell button with unread badge.
class NotificationOverlayButton extends StatelessWidget {
  const NotificationOverlayButton({
    required this.onTap,
    required this.unreadCount,
    super.key,
  });

  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: PosColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: PosColors.line, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: PosColors.slate,
                size: 20,
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: PosColors.danger,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
