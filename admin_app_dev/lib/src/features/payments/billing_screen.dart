import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import 'subscription_checkout_flow.dart';

/// Billing page — shows the app user their current package, plan, status and
/// subscription end date, plus renew/upgrade options.
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  bool _checking = false;
  bool _payingMonthly = false;
  bool _payingAnnual = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;

    return Scaffold(
      backgroundColor: PosColors.background,
      appBar: AppBar(
        backgroundColor: PosColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: TfText(
          text.billingTitle,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 17,
            color: PosColors.slate,
          ),
        ),
        iconTheme: IconThemeData(color: PosColors.slate),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: _checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 22),
              color: PosColors.slate,
              tooltip: text.checkNow,
              onPressed: _checking ? null : _checkNow,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TfText(
            text.billingSubtitle,
            style: const TextStyle(
              fontSize: 13,
              color: PosColors.muted,
            ),
          ),
          const SizedBox(height: 14),
          _buildStatusBanner(app),
          const SizedBox(height: 14),
          TfSectionHeader(label: text.currentPackageLabel),
          const SizedBox(height: 7),
          _buildCurrentPackageCard(app),
          const SizedBox(height: 14),
          TfSectionHeader(label: text.subscriptionPlanOptions),
          const SizedBox(height: 7),
          _buildPlansCard(app),
          const SizedBox(height: 14),
          TfButton(
            label: _checking ? text.checkingNow : text.checkNow,
            icon: Icons.sync_rounded,
            variant: TfButtonVariant.paper,
            busy: _checking,
            onPressed: _checking ? null : _checkNow,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(PosAppController app) {
    final text = app.strings;
    final expired = app.isSubscriptionExpiredLocally;
    final (label, color, icon) = switch (app.subscriptionState) {
      'paid' when expired => (
        text.subscriptionExpired,
        PosColors.danger,
        Icons.error_outline_rounded,
      ),
      'paid' => (
        text.subscriptionActive,
        PosColors.success,
        Icons.check_circle_outline_rounded,
      ),
      'trial' when expired => (
        text.subscriptionExpired,
        PosColors.danger,
        Icons.error_outline_rounded,
      ),
      'trial' => (
        text.subscriptionTrial,
        PosColors.warning,
        Icons.hourglass_top_rounded,
      ),
      _ => (
        text.subscriptionInactive,
        PosColors.danger,
        Icons.error_outline_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.all(PosSpacing.sp4),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 26, color: color),
          const SizedBox(width: PosSpacing.sp3),
          Expanded(
            child: TfText(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
          if (app.subscriptionState != 'none')
            TfText(
              _formatDate(_endDate(app)) ?? '—',
              style: const TextStyle(
                fontSize: 12,
                color: PosColors.muted,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentPackageCard(PosAppController app) {
    final text = app.strings;
    return TfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _InfoRow(label: text.packageLabel, value: _packageName(app)),
          const SizedBox(height: 10),
          _InfoRow(label: text.planLabel, value: _planName(app)),
          const SizedBox(height: 10),
          _InfoRow(
            label: text.statusLabel,
            value: _statusName(app),
            valueColor: _statusColor(app),
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: text.endDateLabel,
            value: _formatDate(_endDate(app)) ?? '—',
          ),
        ],
      ),
    );
  }

  Widget _buildPlansCard(PosAppController app) {
    final text = app.strings;
    final prices = app.subscriptionPrices;
    final monthlyAmount = (prices['standard'] ?? 800).toDouble();
    final annualAmount = monthlyAmount * 12;
    final currentPlan = app.selectedSubscriptionPlan;

    return TfCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TfText(
                text.monthly,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PosColors.slate,
                ),
              ),
              TfText(
                '৳${monthlyAmount.toStringAsFixed(0)}/mo',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PosColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TfButton(
            label: currentPlan == 'monthly' ? text.renewNow : text.upgradeNow,
            busy: _payingMonthly,
            onPressed: _payingMonthly || _payingAnnual
                ? null
                : () => _pay(context, plan: 'monthly', amount: monthlyAmount),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TfText(
                text.annual,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: PosColors.slate,
                ),
              ),
              TfText(
                '৳${annualAmount.toStringAsFixed(0)}/yr',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: PosColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TfButton(
            label: currentPlan == 'annual' ? text.renewNow : text.upgradeNow,
            variant: TfButtonVariant.paper,
            busy: _payingAnnual,
            onPressed: _payingMonthly || _payingAnnual
                ? null
                : () => _pay(context, plan: 'annual', amount: annualAmount),
          ),
        ],
      ),
    );
  }

  Future<void> _pay(
    BuildContext context, {
    required String plan,
    required double amount,
  }) async {
    if (plan == 'monthly') {
      setState(() => _payingMonthly = true);
    } else {
      setState(() => _payingAnnual = true);
    }
    try {
      final paid = await SubscriptionCheckoutFlow.run(
        context,
        amount: amount,
        plan: plan,
      );
      if (paid && mounted) await _checkNow();
    } finally {
      if (mounted) {
        setState(() {
          _payingMonthly = false;
          _payingAnnual = false;
        });
      }
    }
  }

  Future<void> _checkNow() async {
    if (_checking) return;
    final app = AppScope.of(context);
    final text = app.strings;
    setState(() => _checking = true);
    try {
      await app.syncSubscriptionAccessFromCloud(quiet: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.billingCheckedNow)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(text.billingSyncFailed)),
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  DateTime? _endDate(PosAppController app) {
    if (app.subscriptionState == 'trial') return app.trialEndsAt;
    final raw = app.subscriptionExpiresAt;
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    return DateFormat('d MMMM, yyyy').format(date);
  }

  String _packageName(PosAppController app) {
    final pkg = app.subscriptionPackage?.trim() ?? '';
    if (pkg.isEmpty) return '—';
    return pkg[0].toUpperCase() + pkg.substring(1);
  }

  String _planName(PosAppController app) {
    final text = app.strings;
    return switch (app.selectedSubscriptionPlan) {
      'monthly' => text.monthly,
      'annual' => text.annual,
      _ => '—',
    };
  }

  String _statusName(PosAppController app) {
    final text = app.strings;
    final status = app.subscriptionStatus?.toLowerCase() ?? '';
    return switch (app.subscriptionState) {
      'paid' => status == 'trial' ? text.subscriptionTrial : text.subscriptionPaid,
      'trial' => text.subscriptionTrial,
      _ => status == 'trial' ? text.subscriptionTrial : text.subscriptionNone,
    };
  }

  Color _statusColor(PosAppController app) {
    if (app.isSubscriptionExpiredLocally) return PosColors.danger;
    if (app.subscriptionState == 'trial') return PosColors.warning;
    if (app.subscriptionState == 'paid') return PosColors.success;
    return PosColors.danger;
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: TfText(
            label,
            style: const TextStyle(fontSize: 13, color: PosColors.muted),
          ),
        ),
        Expanded(
          child: TfText(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? PosColors.slate,
            ),
          ),
        ),
      ],
    );
  }
}