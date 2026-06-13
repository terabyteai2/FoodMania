// QuickBytes Desktop — shell chrome: the 1280×800 scaling stage, the 92px nav
// rail, the screen header, and the notification / account-role popovers + toast.
// Faithful to `desktop-shell.jsx` + `desktop.css`. Role and language come from
// the global [PosAppController]; tab/popover/toast from [DeskController].

import 'package:flutter/material.dart';

import '../../../app_controller.dart';
import '../../../core/localization/app_strings.dart';
import '../../../models/account_role.dart';
import '../../../models/order_status.dart';
import '../../../models/pos_notification.dart';
import '../desk_controller.dart';
import 'dk_icons.dart';
import 'dk_kit.dart';

bool _isBn(PosAppController app) => app.language == AppLanguage.bn;

String _pick(PosAppController app, String en, String bn) => _isBn(app) ? bn : en;

String dkInitials(String? name, AccountRole role) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return role.label.substring(0, 1).toUpperCase();
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

/// `.dk-viewport` + `.dk-stage` — fixed 1280×800 canvas scaled to fit, centered
/// on the dark radial backdrop.
class DkStage extends StatelessWidget {
  const DkStage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.2),
          radius: 1.25,
          colors: [Color(0xFF2A3122), Color(0xFF11140D)],
          stops: [0, 0.7],
        ),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Container(
            width: 1280,
            height: 800,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Dk.bg,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0xB3000000), blurRadius: 120, spreadRadius: -30, offset: Offset(0, 40)),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// `.dk-rail` — 92px icon nav rail with brand, role nav, and footer actions.
class DkNavRail extends StatelessWidget {
  const DkNavRail({required this.app, required this.desk, this.escalations = 0, super.key});

  final PosAppController app;
  final DeskController desk;
  final int escalations;

  @override
  Widget build(BuildContext context) {
    final role = app.accountRole;
    final nav = deskNavForRole(role);
    final pending = app.orders.where((o) => o.status.adminStatus == OrderStatus.pending).length;
    final unread = app.notifications.where((n) => !n.isRead).length;
    final initials = dkInitials(app.accountDisplayName, role);

    return Container(
      width: 92,
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 14),
      decoration: const BoxDecoration(
        color: Dk.surface,
        border: Border(right: BorderSide(color: Dk.line)),
      ),
      child: Column(
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 18), child: DkMark(size: 40)),
          Expanded(
            child: Column(
              children: [
                for (final item in nav)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _NavBtn(
                      item: item,
                      active: desk.tab == item.tab,
                      label: _isBn(app) ? item.labelBn : item.labelEn,
                      badge: item.tab == DeskTab.orders ? pending : 0,
                      onTap: () => desk.setTab(item.tab),
                    ),
                  ),
              ],
            ),
          ),
          _RailBtn(
            icon: 'chat',
            tooltip: 'Messages',
            badge: escalations,
            onTap: () => desk.setMsgOpen(true),
          ),
          const SizedBox(height: 8),
          _RailBtn(
            icon: 'bell',
            tooltip: 'Notifications',
            badge: unread,
            onTap: () => desk.togglePop(DeskPop.notif),
          ),
          const SizedBox(height: 8),
          Container(width: 28, height: 1, color: Dk.line, margin: const EdgeInsets.symmetric(vertical: 2)),
          const SizedBox(height: 8),
          _LangBtn(
            label: _isBn(app) ? 'বাং' : 'EN',
            onTap: () => app.updateLanguage(_isBn(app) ? AppLanguage.en : AppLanguage.bn),
          ),
          const SizedBox(height: 8),
          _Avatar(initials: initials, onTap: () => desk.togglePop(DeskPop.account)),
        ],
      ),
    );
  }
}

class _NavBtn extends StatefulWidget {
  const _NavBtn({required this.item, required this.active, required this.label, required this.badge, required this.onTap});

  final DeskNavItem item;
  final bool active;
  final String label;
  final int badge;
  final VoidCallback onTap;

  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final chipBg = active ? Dk.accent : (_hover ? Dk.surface2 : Colors.transparent);
    final iconColor = active ? Dk.accentInk : (_hover ? Dk.ink2 : Dk.muted);
    final labelColor = active ? Dk.ink : (_hover ? Dk.ink2 : Dk.muted);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 68,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 9, 0, 7),
                child: Column(
                  children: [
                    Container(
                      width: 46,
                      height: 34,
                      decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(9)),
                      child: Center(child: DkIcon(widget.item.icon, size: 22, color: iconColor)),
                    ),
                    const SizedBox(height: 5),
                    Text(widget.label,
                        style: dkText(11, weight: active ? FontWeight.w700 : FontWeight.w600, color: labelColor)),
                  ],
                ),
              ),
              if (widget.badge > 0)
                Positioned(top: 5, right: 9, child: _CountBadge(widget.badge)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 17),
      height: 17,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Dk.danger,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Dk.surface, width: 2),
      ),
      alignment: Alignment.center,
      child: Text('$count', style: dkNum(10, weight: FontWeight.w800, color: Colors.white)),
    );
  }
}

class _RailBtn extends StatefulWidget {
  const _RailBtn({required this.icon, required this.onTap, this.badge = 0, this.tooltip});
  final String icon;
  final VoidCallback onTap;
  final int badge;
  final String? tooltip;

  @override
  State<_RailBtn> createState() => _RailBtnState();
}

class _RailBtnState extends State<_RailBtn> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) {
    Widget btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _hover ? Dk.surface2 : Dk.surface,
                borderRadius: BorderRadius.circular(Dk.rLg),
                border: Border.all(color: Dk.line2),
              ),
              child: Center(child: DkIcon(widget.icon, size: 21, color: Dk.ink2)),
            ),
            if (widget.badge > 0) Positioned(top: -5, right: -5, child: _CountBadge(widget.badge)),
          ],
        ),
      ),
    );
    return widget.tooltip != null ? Tooltip(message: widget.tooltip!, child: btn) : btn;
  }
}

class _LangBtn extends StatelessWidget {
  const _LangBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 46,
          height: 32,
          decoration: BoxDecoration(
            color: Dk.surface,
            borderRadius: BorderRadius.circular(Dk.rMd),
            border: Border.all(color: Dk.line2),
          ),
          alignment: Alignment.center,
          child: Text(label, style: dkText(12, weight: FontWeight.w800, color: Dk.ink2, letterSpacing: 0.3)),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.onTap});
  final String initials;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: Dk.accentTint2, borderRadius: BorderRadius.circular(Dk.rLg)),
          alignment: Alignment.center,
          child: Text(initials, style: dkText(14, weight: FontWeight.w800, color: Dk.accentInk)),
        ),
      ),
    );
  }
}

/// `.dk-topbar` — screen header (title + sub + right slot).
class DkHead extends StatelessWidget {
  const DkHead({required this.title, this.sub, this.right, super.key});

  final String title;
  final String? sub;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Dk.surface,
        border: Border(bottom: BorderSide(color: Dk.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: dkText(22, weight: FontWeight.w700, color: Dk.ink, letterSpacing: -0.4)),
                if (sub != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dkText(13, weight: FontWeight.w500, color: Dk.muted)),
                  ),
              ],
            ),
          ),
          ?right,
        ],
      ),
    );
  }
}

/// Notification popover panel (`.dk-pop`) — positioned by the shell at left:80,
/// bottom:64.
class DkNotifPanel extends StatelessWidget {
  const DkNotifPanel({required this.app, required this.desk, super.key});

  final PosAppController app;
  final DeskController desk;

  static const Map<PosNotificationTarget, List<dynamic>> _meta = {
    PosNotificationTarget.orders: ['receipt', Dk.accentStrong, Dk.accentTint],
    PosNotificationTarget.messages: ['chat', Dk.warning, Dk.warningSoft],
    PosNotificationTarget.inventory: ['box', Dk.danger, Dk.dangerSoft],
    PosNotificationTarget.menu: ['table', Dk.info, Dk.infoSoft],
  };

  String _ago(DateTime t) {
    final m = DateTime.now().difference(t).inMinutes;
    if (m < 60) return '${m < 0 ? 0 : m}m';
    return '${(m / 60).round()}h';
  }

  @override
  Widget build(BuildContext context) {
    final notifs = app.notifications;
    final unread = notifs.where((n) => !n.isRead).length;
    return Container(
      width: 348,
      decoration: BoxDecoration(
        color: Dk.surface,
        borderRadius: BorderRadius.circular(Dk.rLg),
        border: Border.all(color: Dk.line2),
        boxShadow: Dk.e3,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Dk.line))),
            child: Row(
              children: [
                Expanded(child: Text(_pick(app, 'Notifications', 'নোটিফিকেশন'), style: dkText(15, weight: FontWeight.w700))),
                if (unread > 0)
                  GestureDetector(
                    onTap: () => app.markAllNotificationsRead(),
                    child: Text(_pick(app, 'Mark all read', 'সব পঠিত'),
                        style: dkText(12.5, weight: FontWeight.w600, color: Dk.accentStrong)),
                  ),
              ],
            ),
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: notifs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(28),
                      child: Text(_pick(app, 'No notifications', 'কোনো নোটিফিকেশন নেই'),
                          style: dkText(13.5, color: Dk.muted)),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: notifs.length,
                      itemBuilder: (_, i) => _row(notifs[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(PosNotification n) {
    final meta = _meta[n.target] ?? ['clock', Dk.ink2, Dk.surface2];
    return GestureDetector(
      onTap: () {
        app.markNotificationRead(n.id);
        desk.closePop();
        switch (n.target) {
          case PosNotificationTarget.messages:
            desk.setMsgOpen(true);
            break;
          case PosNotificationTarget.inventory:
            desk.setTab(DeskTab.inventory);
            break;
          case PosNotificationTarget.orders:
            desk.setTab(DeskTab.orders);
            break;
          default:
            break;
        }
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: n.isRead ? Dk.surface : Dk.bg,
            border: const Border(bottom: BorderSide(color: Dk.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: meta[2] as Color, borderRadius: BorderRadius.circular(9)),
                child: Center(child: DkIcon(meta[0] as String, size: 18, color: meta[1] as Color)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: dkText(13.5, weight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Text(_ago(n.createdAt), style: dkText(11, color: Dk.placeholder)),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(n.body, maxLines: 1, overflow: TextOverflow.ellipsis, style: dkText(12.5, color: Dk.muted)),
                  ],
                ),
              ),
              if (!n.isRead)
                Container(
                  margin: const EdgeInsets.only(left: 8, top: 6),
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(color: Dk.accentStrong, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Account / role popover (`desktop-shell.jsx` AccountPop) — demo role switch.
class DkAccountPanel extends StatelessWidget {
  const DkAccountPanel({required this.app, required this.desk, super.key});

  final PosAppController app;
  final DeskController desk;

  static const _roles = [AccountRole.owner, AccountRole.manager, AccountRole.waiter];

  @override
  Widget build(BuildContext context) {
    final initials = dkInitials(app.accountDisplayName, app.accountRole);
    final name = (app.accountDisplayName).trim().isNotEmpty ? app.accountDisplayName : app.accountRole.label;
    return Container(
      width: 268,
      decoration: BoxDecoration(
        color: Dk.surface,
        borderRadius: BorderRadius.circular(Dk.rLg),
        border: Border.all(color: Dk.line2),
        boxShadow: Dk.e3,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Dk.line))),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: Dk.accentTint2, borderRadius: BorderRadius.circular(Dk.rLg)),
                  alignment: Alignment.center,
                  child: Text(initials, style: dkText(14, weight: FontWeight.w800, color: Dk.accentInk)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: dkText(14.5, weight: FontWeight.w700)),
                      Text(
                        app.restaurantName.trim().isNotEmpty ? app.restaurantName : 'QuickBytes',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: dkText(12, color: Dk.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: dkEyebrow(_pick(app, 'Switch role (demo)', 'ভূমিকা (ডেমো)')),
                ),
                for (final role in _roles)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _roleBtn(role),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleBtn(AccountRole role) {
    final on = app.accountRole == role;
    return GestureDetector(
      onTap: () async {
        await app.setAccountRoleDemo(role);
        desk.clampToRole(role);
        desk.closePop();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: on ? Dk.accentTint : Dk.surface,
            borderRadius: BorderRadius.circular(Dk.rMd),
            border: Border.all(color: on ? Dk.accent : Dk.line2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(_isBn(app) ? role.labelBn : role.label,
                    style: dkText(14, weight: FontWeight.w600, color: on ? Dk.accentStrong : Dk.ink)),
              ),
              if (on) const DkIcon('check', size: 18, color: Dk.accentStrong),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-centered toast (`desktop-app.jsx` toast).
class DkToast extends StatelessWidget {
  const DkToast({required this.message, super.key});
  final String message;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      decoration: BoxDecoration(color: Dk.ink, borderRadius: BorderRadius.circular(Dk.rMd), boxShadow: Dk.e3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DkIcon('check2', size: 17, color: Dk.accent),
          const SizedBox(width: 8),
          Text(message, style: dkText(14, weight: FontWeight.w600, color: Colors.white)),
        ],
      ),
    );
  }
}
