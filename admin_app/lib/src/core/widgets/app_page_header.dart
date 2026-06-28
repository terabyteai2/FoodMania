import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../features/messaging/messages_screen.dart';
import '../../models/pos_notification.dart';
import '../theme/app_theme.dart';
import 'notification_center.dart';
import 'shell_nav_scope.dart';
import 'tf_design_system.dart';

/// Shared primary-tab header used on every root admin screen.
///
/// Renders the blue bolt mark + [title] + outlet name on the left; on the
/// right, the Messages icon (manager+ roles only), and the notification bell.
///
/// Pushed / detail screens keep their own [AppScaffold] with a back button.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    this.brand = false,
    super.key,
  });

  final String title;
  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final bool brand;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final outletName = app.outletName.trim();
    // Present only on the phone shell (MainShell narrow layout). On the wide
    // NavigationRail layout and on pushed detail routes the scope is absent, so
    // no hamburger shows there.
    final shellNav = ShellNavScope.maybeOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosSpacing.sp4,
        PosSpacing.sp2,
        PosSpacing.sp4,
        PosSpacing.sp3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (shellNav != null) ...[
            TfIconButton(
              icon: Icons.menu_rounded,
              tooltip: text.menu,
              onPressed: shellNav.openDrawer,
            ),
            const SizedBox(width: PosSpacing.sp2),
          ],
          Expanded(
            child: brand
                ? TfBrandHeader(
                    title: 'QuickBytes',
                    subtitle: outletName.isEmpty ? null : outletName,
                  )
                : _SourceTitleHeader(title: title),
          ),
          if (app.canMessages) ...[
            TfBarButton(
              icon: TfSourceIconName.chat,
              tooltip: text.messages,
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
            ),
            const SizedBox(width: PosSpacing.sp2),
          ],
          HeaderNotificationBell(
            onNavigateToOrders: onNavigateToOrders ?? () {},
            onNavigateToTarget: onNavigateToTarget,
          ),
        ],
      ),
    );
  }
}

class _SourceTitleHeader extends StatelessWidget {
  const _SourceTitleHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return TfText(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: tfFontFamily(context),
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: PosColors.primaryDark,
        height: 1.15,
        letterSpacing: 0,
      ),
    );
  }
}
