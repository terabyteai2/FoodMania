import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_global_top_bar.dart';
import '../../models/pos_notification.dart';
import '../settings/settings_screen.dart';

/// QuickBytes "More" hub — shared secondary navigation across all roles
/// (spec §14). Profile + demo role switcher, messaging link, role-gated manage
/// group, service-mode toggle and the language quick toggle.
class MoreScreen extends StatelessWidget {
  const MoreScreen({
    required this.onNavigateToOrders,
    this.onNavigateToTarget,
    this.receiptPrinterOpenRequest = 0,
    super.key,
  });

  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;
  final int receiptPrinterOpenRequest;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.selectMany(
      context,
      const [AppAspect.account, AppAspect.language, AppAspect.settings],
    );
    final text = app.strings;
    return AppScaffold(
      title: text.settingsTab,
      headerWidget: TfGlobalTopBar(
        title: text.settingsTab,
        onNavigateToOrders: onNavigateToOrders,
        onNavigateToTarget: onNavigateToTarget,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SettingsScreen(
            onNavigateToOrders: onNavigateToOrders,
            onNavigateToTarget: onNavigateToTarget,
            receiptPrinterOpenRequest: receiptPrinterOpenRequest,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

}

