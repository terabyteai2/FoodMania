import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../features/messaging/messages_screen.dart';
import '../../models/pos_notification.dart';
import '../theme/app_theme.dart';
import 'notification_center.dart';
import 'tf_design_system.dart';

/// Shared primary-tab header used on every bottom-nav root screen.
///
/// Renders the lime bolt mark + [title] + outlet name on the left; on the
/// right, an optional **Advanced** toggle (Stock / Analytics / Live), the
/// Messages icon (manager+ roles only), and the notification bell.
///
/// Pushed / detail screens keep their own [AppScaffold] with a back button.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.title,
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    this.brand = false,
    this.showAdvanced = false,
    this.advancedValue = false,
    this.onAdvancedChanged,
    super.key,
  });

  final String title;
  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final bool brand;
  final bool showAdvanced;
  final bool advancedValue;
  final ValueChanged<bool>? onAdvancedChanged;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final outletName = app.outletName.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: brand
                ? TfBrandHeader(
                    title: 'QuickBytes',
                    subtitle: outletName.isEmpty ? null : outletName,
                  )
                : _SourceTitleHeader(title: title),
          ),
          const SizedBox(width: 10),
          if (showAdvanced) ...[
            TfText(
              text.advanced,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: advancedValue ? PosColors.text : PosColors.muted,
              ),
            ),
            const SizedBox(width: 6),
            TfToggle(
              value: advancedValue,
              onChanged: onAdvancedChanged ?? (_) {},
              semanticLabel: text.advanced,
            ),
            const SizedBox(width: 10),
          ],
          if (app.canMessages) ...[
            TfBarButton(
              icon: TfSourceIconName.chat,
              tooltip: text.messages,
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
            ),
            const SizedBox(width: 8),
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
