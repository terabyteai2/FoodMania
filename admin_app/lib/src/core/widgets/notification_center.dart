import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';

/// Opens the global notifications panel. Rendered as a slide-down shade
/// anchored to the top of the screen (similar to a phone's notification
/// shade) so it never covers the main interaction cards below. Tapping
/// outside the panel — or any item — dismisses it. `onNavigateToOrders` is
/// invoked when the user taps a notification whose actionTarget is
/// `pending_orders` / `orders`.
void showNotificationCenter(
  BuildContext context, {
  required VoidCallback onNavigateToOrders,
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

class _NotificationShade extends StatelessWidget {
  const _NotificationShade({required this.onNavigateToOrders});

  final VoidCallback onNavigateToOrders;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final items = app.notifications;
    final mediaHeight = MediaQuery.sizeOf(context).height;
    // Cap the shade at ~52% of the screen so the main interface stays visible
    // underneath and the panel reads as a transient banner stack, not a
    // takeover sheet.
    final maxHeight = mediaHeight * 0.52;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 520),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: PosColors.lineStrong),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      size: 18,
                      color: PosColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        text.notificationsTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: PosColors.slate,
                        ),
                      ),
                    ),
                    if (items.any((n) => !n.isRead))
                      TextButton(
                        onPressed: () => app.markAllNotificationsRead(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 32),
                          visualDensity: VisualDensity.compact,
                          foregroundColor: PosColors.primary,
                        ),
                        child: Text(
                          text.markAllRead,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: PosColors.muted,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
                  child: Text(
                    text.noNotificationsYet,
                    style: TextStyle(
                      color: PosColors.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _NotificationBanner(
                        title: item.title,
                        body: item.body,
                        time: DateFormat('HH:mm').format(item.createdAt),
                        isRead: item.isRead,
                        onTap: () {
                          app.markNotificationRead(item.id);
                          Navigator.of(context).pop();
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
      ),
    );
  }
}

class _NotificationBanner extends StatelessWidget {
  const _NotificationBanner({
    required this.title,
    required this.body,
    required this.time,
    required this.isRead,
    required this.onTap,
  });

  final String title;
  final String body;
  final String time;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isRead
          ? PosColors.background
          : PosColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(
                  isRead
                      ? Icons.notifications_none_rounded
                      : Icons.notifications_active_rounded,
                  color: isRead ? PosColors.muted : PosColors.primary,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: PosColors.slate,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
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
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PosColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
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
            openLabel: text.openAction,
            dismissLabel: text.dismiss,
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
    required this.openLabel,
    required this.dismissLabel,
    required this.onOpen,
    required this.onClose,
  });

  final String title;
  final String body;
  final String openLabel;
  final String dismissLabel;
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
              child: Text(
                openLabel,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 16),
            color: PosColors.muted,
            visualDensity: VisualDensity.compact,
            tooltip: dismissLabel,
          ),
        ],
      ),
    );
  }
}

/// Drop-in bell button for any page header.
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

/// Compact language-toggle button for page header action rows.
class HeaderLanguageButton extends StatelessWidget {
  const HeaderLanguageButton({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isBn = app.language == AppLanguage.bn;
    final label = isBn ? 'বাং' : 'EN';
    return SizedBox(
      height: 36,
      width: 36,
      child: Material(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(9),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => app.updateLanguage(
            isBn ? AppLanguage.en : AppLanguage.bn,
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: PosColors.line, width: 1),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: PosColors.slate,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
