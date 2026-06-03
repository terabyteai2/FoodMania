import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/order_status.dart';
import '../../models/pos_notification.dart';
import '../orders/orders_screen.dart';

class TerminalHomeScreen extends StatelessWidget {
  const TerminalHomeScreen({
    required this.onNavigateToOrders,
    required this.onNavigateToMenu,
    required this.onNavigateToSettings,
    this.onNavigateToTarget,
    super.key,
  });

  final VoidCallback onNavigateToOrders;
  final VoidCallback onNavigateToMenu;
  final VoidCallback onNavigateToSettings;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final metrics = app.metrics;
    final pending = app.orders
        .where((order) => order.status.adminStatus == OrderStatus.pending)
        .length;
    final accepted = app.orders
        .where((order) => order.status.adminStatus == OrderStatus.accepted)
        .length;
    final printerReady = app.printerState.hasSelectedPrinter;
    final syncLabel = app.syncState.cloudConnected
        ? (text.isBn ? 'ক্লাউড চালু' : 'Cloud online')
        : (text.isBn ? 'অফলাইন মোড' : 'Offline mode');

    return Scaffold(
      backgroundColor: PosColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TfAppBar(
                      title: text.isBn ? 'টার্মিনাল' : 'Terminal',
                      subtitle: _homeSubtitle(context),
                      trailing: [
                        const HeaderModeButton(),
                        HeaderNotificationBell(
                          onNavigateToOrders: onNavigateToOrders,
                          onNavigateToTarget: onNavigateToTarget,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _StatusStrip(
                      printerReady: printerReady,
                      syncLabel: syncLabel,
                      pendingSync: app.syncState.pendingCount,
                    ),
                    const SizedBox(height: 12),
                    _MetricGrid(
                      cards: [
                        _MetricCardData(
                          label: text.isBn ? 'আজকের বিক্রি' : 'Today sales',
                          value: _money(metrics.totalSales, text.isBn),
                          icon: Icons.payments_outlined,
                          tone: PosColors.success,
                        ),
                        _MetricCardData(
                          label: text.isBn ? 'আজকের অর্ডার' : 'Today orders',
                          value: _digits(metrics.todayOrders, text.isBn),
                          icon: Icons.receipt_long_outlined,
                          tone: PosColors.primary,
                        ),
                        _MetricCardData(
                          label: text.isBn ? 'পেন্ডিং' : 'Pending',
                          value: _digits(pending, text.isBn),
                          icon: Icons.timelapse_rounded,
                          tone: pending > 0
                              ? PosColors.warning
                              : PosColors.success,
                        ),
                        _MetricCardData(
                          label: text.isBn ? 'চলমান' : 'Accepted',
                          value: _digits(accepted, text.isBn),
                          icon: Icons.room_service_outlined,
                          tone: PosColors.info,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TfSectionHeader(
                      label: text.isBn ? 'দ্রুত কাজ' : 'Quick actions',
                    ),
                    _QuickActionGrid(
                      actions: [
                        _QuickActionData(
                          label: text.isBn ? 'নতুন অর্ডার' : 'New order',
                          icon: Icons.add_rounded,
                          primary: true,
                          onTap: () => unawaited(
                            openNewOrderForm(
                              context,
                              onCreated: onNavigateToOrders,
                            ),
                          ),
                        ),
                        _QuickActionData(
                          label: text.isBn ? 'অর্ডার' : 'Orders',
                          icon: Icons.receipt_long_outlined,
                          onTap: onNavigateToOrders,
                        ),
                        _QuickActionData(
                          label: text.isBn ? 'মেনু' : 'Menu',
                          icon: Icons.restaurant_menu_outlined,
                          onTap: onNavigateToMenu,
                        ),
                        _QuickActionData(
                          label: text.isBn ? 'সিঙ্ক' : 'Sync',
                          icon: Icons.sync_rounded,
                          onTap: app.busy
                              ? null
                              : () => unawaited(app.syncNow()),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TfSectionHeader(
                      label: text.isBn ? 'টার্মিনাল অবস্থা' : 'Terminal status',
                    ),
                    _TerminalStatusCard(onOpenSettings: onNavigateToSettings),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _homeSubtitle(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateFormat('EEE, h:mm a').format(DateTime.now());
    final outlet = app.outletName.trim().isEmpty ? 'POS' : app.outletName;
    return '$outlet · $now';
  }

  static String _digits(num value, bool isBn) {
    final raw = NumberFormat.decimalPattern().format(value);
    if (!isBn) return raw;
    const en = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const bn = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];
    var out = raw;
    for (var i = 0; i < en.length; i++) {
      out = out.replaceAll(en[i], bn[i]);
    }
    return out;
  }

  static String _money(double value, bool isBn) {
    return '৳${_digits(value.round(), isBn)}';
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.printerReady,
    required this.syncLabel,
    required this.pendingSync,
  });

  final bool printerReady;
  final String syncLabel;
  final int pendingSync;

  @override
  Widget build(BuildContext context) {
    final isBn = AppScope.of(context).strings.isBn;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatusPill(
          icon: Icons.print_outlined,
          label: printerReady
              ? (isBn ? 'প্রিন্টার প্রস্তুত' : 'Printer ready')
              : (isBn ? 'বিল্ট-ইন প্রিন্টার নেই' : 'Built-in printer offline'),
          ok: printerReady,
        ),
        _StatusPill(
          icon: Icons.cloud_done_outlined,
          label: syncLabel,
          ok: true,
        ),
        if (pendingSync > 0)
          _StatusPill(
            icon: Icons.pending_actions_outlined,
            label: isBn
                ? 'সিঙ্ক বাকি $pendingSync'
                : '$pendingSync pending sync',
            ok: false,
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.ok,
  });

  final IconData icon;
  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? PosColors.success : PosColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          TfText(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.cards});

  final List<_MetricCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final card in cards)
              SizedBox(width: width, child: _MetricCard(card)),
          ],
        );
      },
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color tone;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.data);

  final _MetricCardData data;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 18, color: data.tone),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: data.tone,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TfText(
            data.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PosColors.slate,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          TfText(
            data.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PosColors.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.actions});

  final List<_QuickActionData> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 4 : 2;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final action in actions)
              SizedBox(width: width, child: _QuickAction(action)),
          ],
        );
      },
    );
  }
}

class _QuickActionData {
  const _QuickActionData({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(this.data);

  final _QuickActionData data;

  @override
  Widget build(BuildContext context) {
    return TfButton(
      label: data.label,
      icon: data.icon,
      fullWidth: true,
      variant: data.primary ? TfButtonVariant.primary : TfButtonVariant.paper,
      onPressed: data.onTap,
    );
  }
}

class _TerminalStatusCard extends StatelessWidget {
  const _TerminalStatusCard({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final printerLabel = app.printerState.selectedPrinterLabel;
    return TfCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _StatusRow(
            icon: Icons.storefront_outlined,
            label: text.isBn ? 'আউটলেট' : 'Outlet',
            value: app.outletName.trim().isEmpty ? '-' : app.outletName,
          ),
          const Divider(height: 20, color: PosColors.line),
          _StatusRow(
            icon: Icons.print_outlined,
            label: text.isBn ? 'প্রিন্টার' : 'Printer',
            value: printerLabel,
          ),
          const Divider(height: 20, color: PosColors.line),
          _StatusRow(
            icon: Icons.restaurant_menu_outlined,
            label: text.isBn ? 'মেনু আইটেম' : 'Menu items',
            value: '${app.menuItems.length}',
          ),
          const SizedBox(height: 12),
          TfButton(
            label: text.isBn ? 'আরও' : 'More',
            icon: Icons.settings_outlined,
            variant: TfButtonVariant.ghost,
            onPressed: onOpenSettings,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PosColors.muted),
        const SizedBox(width: 10),
        Expanded(
          child: TfText(
            label,
            style: const TextStyle(
              color: PosColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Flexible(
          child: TfText(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: PosColors.slate,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
