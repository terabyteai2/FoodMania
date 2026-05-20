import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../theme/app_theme.dart';

/// Opens the global notifications history sheet. `onNavigateToOrders` is
/// invoked when the user taps a notification whose actionTarget is
/// pending_orders / orders.
void showNotificationCenter(
  BuildContext context, {
  required VoidCallback onNavigateToOrders,
}) {
  final app = AppScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      final items = app.notifications;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => app.markAllNotificationsRead(),
                    child: const Text('Mark all read'),
                  ),
                ],
              ),
              SizedBox(
                height: 360,
                child: items.isEmpty
                    ? const Center(child: Text('No notifications yet.'))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return ListTile(
                            leading: Icon(
                              item.isRead
                                  ? Icons.notifications_none_rounded
                                  : Icons.notifications_active_rounded,
                              color: item.isRead
                                  ? PosColors.muted
                                  : PosColors.primary,
                            ),
                            title: Text(item.title),
                            subtitle: Text(item.body),
                            trailing: Text(
                              DateFormat('HH:mm').format(item.createdAt),
                            ),
                            onTap: () {
                              app.markNotificationRead(item.id);
                              Navigator.pop(sheetContext);
                              if (item.actionTarget == 'pending_orders' ||
                                  item.actionTarget == 'orders') {
                                onNavigateToOrders();
                              }
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Show a non-blocking notification banner at the TOP of the screen.
/// Auto-dismisses after [duration]. Tapping "Open" calls [onOpen] and
/// closes the banner early.
void showTopNotificationToast(
  BuildContext context, {
  required String title,
  required String body,
  VoidCallback? onOpen,
  Duration duration = const Duration(seconds: 4),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  Timer? dismissTimer;
  void close() {
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
          child: _TopToastCard(
            title: title,
            body: body,
            onOpen: onOpen == null
                ? null
                : () {
                    close();
                    onOpen();
                  },
            onClose: close,
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
    required this.onOpen,
    required this.onClose,
  });

  final String title;
  final String body;
  final VoidCallback? onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosColors.lineStrong, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_active_rounded,
            color: PosColors.primary,
            size: 22,
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
                  style: TextStyle(
                    color: PosColors.slate,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: PosColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          if (onOpen != null)
            TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(
                foregroundColor: PosColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text(
                'Open',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 16),
            color: PosColors.muted,
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}

/// Drop-in bell button for any page header — small enough to live next to
/// the "+" / "Sync" / etc. action buttons in a CompactHeader actions slot.
class HeaderNotificationBell extends StatelessWidget {
  const HeaderNotificationBell({required this.onNavigateToOrders, super.key});

  final VoidCallback onNavigateToOrders;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final unread = app.unreadNotificationCount;
    return SizedBox(
      height: 36,
      width: 36,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Material(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(9),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => showNotificationCenter(
                context,
                onNavigateToOrders: onNavigateToOrders,
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: PosColors.line, width: 1),
                ),
                child: Icon(
                  unread > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: unread > 0 ? PosColors.primary : PosColors.slate,
                  size: 18,
                ),
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: PosColors.danger,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A floating bell button with unread badge, intended to overlay any
/// screen (positioned at top-right by the caller).
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
        borderRadius: BorderRadius.circular(22),
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
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
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
