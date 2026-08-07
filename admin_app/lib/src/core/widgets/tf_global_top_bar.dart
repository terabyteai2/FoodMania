import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../models/pos_notification.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';
import 'guided_tour.dart';
import 'notification_center.dart';
import 'shell_nav_scope.dart';
import 'tf_design_system.dart';

/// Unified app chrome shared across every primary tab.
///
/// Renders the slim Petpooja bar (DESIGN.md v4 §5.1): page [title] on the
/// left and, on the right, any [extraActions], the notification bell, and the
/// account avatar dropdown (settings, sign out). A [subtitle] is only
/// rendered when explicitly passed — the outlet name lives in the drawer
/// header, never in the bar.
///
/// [extraActions] is reserved for per-screen VIEW controls (e.g. Stock's
/// simple/advanced toggle) — navigation and feature actions belong in the
/// drawer, not the bar.
class TfGlobalTopBar extends StatelessWidget {
  const TfGlobalTopBar({
    required this.title,
    this.titleBn,
    this.subtitle,
    this.subtitleBn,
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    this.extraActions = const [],
    this.padding = _defaultPadding,
    this.showTrailing = true,
    this.color,
    super.key,
  }) : _isLeaf = false,
       _onBack = null;

  /// Leaf / pushed-screen variant: a back arrow in the leading slot and no
  /// notification bell or avatar dropdown (those belong on tab roots only).
  /// [onBack] defaults to popping the current route.
  const TfGlobalTopBar.leaf({
    required this.title,
    this.titleBn,
    this.subtitle,
    this.subtitleBn,
    this.extraActions = const [],
    this.padding = _defaultPadding,
    VoidCallback? onBack,
    super.key,
  }) : onNavigateToOrders = null,
       onNavigateToTarget = null,
       showTrailing = false,
       color = null,
       _isLeaf = true,
       _onBack = onBack;

  static const EdgeInsetsGeometry _defaultPadding = EdgeInsets.fromLTRB(
    PosSpacing.sp4,
    PosSpacing.sp2,
    PosSpacing.sp4,
    PosSpacing.sp2,
  );

  final String title;
  final String? titleBn;

  /// Small contextual subtitle (e.g. "3 of 13 counted"). Rendered only when
  /// explicitly passed — never the outlet name (v4 §5.1).
  final String? subtitle;
  final String? subtitleBn;

  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  /// Page-specific trailing actions placed before the bell + avatar.
  final List<Widget> extraActions;

  final EdgeInsetsGeometry padding;

  /// Whether to render the notification bell + account-avatar dropdown.
  /// Defaults to true; set false for screens (e.g. Settings) that already
  /// surface those controls inline and don't need them duplicated up top.
  final bool showTrailing;

  /// Optional background color. When set, text and icons render white.
  final Color? color;

  /// True for the [TfGlobalTopBar.leaf] variant — renders a back arrow instead
  /// of the hamburger and suppresses the trailing cluster.
  final bool _isLeaf;
  final VoidCallback? _onBack;

  @override
  Widget build(BuildContext context) {
    final isBn = tfIsBn(context);
    final t = isBn && (titleBn?.isNotEmpty ?? false) ? titleBn! : title;

    String? s;
    if (subtitle != null) {
      s = isBn && (subtitleBn?.isNotEmpty ?? false) ? subtitleBn! : subtitle;
    }

    final shellNav = ShellNavScope.maybeOf(context);

    final isBlue = color != null;

    final Widget? leading;
    if (_isLeaf) {
      leading = GestureDetector(
        onTap: _onBack ?? () => Navigator.of(context).maybePop(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            TfNavIcon.back,
            size: 24,
            color: isBlue ? PosColors.accentInk : PosColors.slate,
          ),
        ),
      );
    } else if (shellNav != null) {
      // 54px hit box (+10 over the 44px visual box) — icon stays 24px.
      leading = TourSpot(
        name: 'header.menu',
        child: GestureDetector(
          onTap: shellNav.openDrawer,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 54,
            height: 54,
            child: Center(
              child: Icon(
                Icons.menu_rounded,
                size: 24,
                color: isBlue ? PosColors.accentInk : PosColors.slate,
              ),
            ),
          ),
        ),
      );
    } else {
      leading = null;
    }

    return Container(
      color: color,
      child: TfUnifiedTopNav(
        leading: leading,
        title: t,
        subtitle: s,
        padding: padding,
        color: color,
        trailing: [
          ...extraActions,
          if (showTrailing) ...[
            TourSpot(
              name: 'header.bell',
              child: HeaderNotificationBell(
                onNavigateToOrders: onNavigateToOrders ?? () {},
                onNavigateToTarget: onNavigateToTarget,
                color: isBlue ? PosColors.accentInk : null,
              ),
            ),
            TourSpot(
              name: 'header.avatar',
              child: _AvatarDropdown(
                onNavigateToTarget: onNavigateToTarget,
                color: isBlue ? PosColors.accentInk : null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _TopAction { language, printer, settings, signOut }

class _AvatarDropdown extends StatelessWidget {
  const _AvatarDropdown({this.onNavigateToTarget, this.color});

  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final Color? color;

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '👤';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final initials = _initials(app.accountDisplayName);
    final canOpenSettings = onNavigateToTarget != null;

    return PopupMenuButton<_TopAction>(
      tooltip: '',
      offset: const Offset(0, 52),
      color: PosColors.surface,
      elevation: 8,
      shadowColor: const Color(0x1A141928),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.xl),
        side: BorderSide(color: PosColors.line),
      ),
      constraints: const BoxConstraints(minWidth: 224, maxWidth: 280),
      onSelected: (action) {
        switch (action) {
          case _TopAction.language:
            app.updateLanguage(
              app.language == AppLanguage.bn ? AppLanguage.en : AppLanguage.bn,
            );
          case _TopAction.printer:
            onNavigateToTarget?.call(PosNotificationTarget.receiptPrinter);
          case _TopAction.settings:
            onNavigateToTarget?.call(PosNotificationTarget.settings);
          case _TopAction.signOut:
            app.logOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<_TopAction>(
          value: _TopAction.language,
          height: 42,
          child: Row(
            children: [
              const Icon(Icons.translate_rounded, size: 18, color: PosColors.ink2),
              const SizedBox(width: 10),
              TfText(
                tfPick(context, en: 'Language', bn: 'ভাষা'),
                style: const TextStyle(color: PosColors.text, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TfText(
                app.language == AppLanguage.bn ? 'বাংলা' : 'English',
                style: const TextStyle(color: PosColors.muted, fontSize: 14, fontWeight: FontWeight.w400),
              ),
            ],
          ),
        ),
        PopupMenuItem<_TopAction>(
          value: _TopAction.printer,
          height: 42,
          child: Row(
            children: [
              const Icon(Icons.print_outlined, size: 18, color: PosColors.ink2),
              const SizedBox(width: 10),
              TfText(
                tfPick(context, en: 'Printer', bn: 'প্রিন্টার'),
                style: const TextStyle(color: PosColors.text, fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              TfText(
                app.printerState.connected
                    ? tfPick(context, en: 'Connected', bn: 'কানেক্টেড')
                    : tfPick(context, en: 'Connect', bn: 'কানেক্ট'),
                style: TextStyle(
                  color: app.printerState.connected ? PosColors.success : PosColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (canOpenSettings)
          PopupMenuItem<_TopAction>(
            value: _TopAction.settings,
            height: 42,
            child: Row(
              children: [
                const Icon(Icons.settings_outlined, size: 18, color: PosColors.ink2),
                const SizedBox(width: 10),
                TfText(
                  tfPick(context, en: 'Settings', bn: 'সেটিংস'),
                  style: const TextStyle(color: PosColors.text, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<_TopAction>(
          value: _TopAction.signOut,
          height: 42,
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 18, color: PosColors.danger),
              const SizedBox(width: 10),
              TfText(
                tfPick(context, en: 'Sign out', bn: 'সাইন আউট'),
                style: const TextStyle(color: PosColors.danger, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color != null ? PosColors.accentInk : PosColors.neutralSoft,
          shape: BoxShape.circle,
          border: Border.all(
            color: color != null
                ? PosColors.accentInk.withValues(alpha: 0.3)
                : PosColors.neutralWash,
          ),
        ),
        child: TfText(
          initials,
          style: TextStyle(
            color: color != null ? PosColors.primary : PosColors.neutralInk,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}
