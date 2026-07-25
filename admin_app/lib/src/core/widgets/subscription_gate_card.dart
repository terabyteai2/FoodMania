import 'package:flutter/material.dart';
import '../../app_controller.dart';
import '../../app_scope.dart';
import '../theme/app_theme.dart';
import 'screen_blocker.dart';
import 'tf_design_system.dart';

class SubscriptionGateCard extends StatefulWidget {
  const SubscriptionGateCard({super.key, this.feature, this.child});

  final String? feature;
  final Widget? child;

  @override
  State<SubscriptionGateCard> createState() => _SubscriptionGateCardState();
}

class _SubscriptionGateCardState extends State<SubscriptionGateCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (widget.feature != null) {
      if (app.hasFeature(widget.feature!)) return widget.child ?? const SizedBox.shrink();
    } else {
      if (app.subscriptionState == 'paid') return widget.child ?? const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PosSpacing.sp4),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.card),
        border: Border.all(color: PosColors.warningSoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.lock_outline_rounded,
              size: 20,
              color: PosColors.warning,
            ),
          ),
          const SizedBox(width: PosSpacing.sp3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  app.strings.isBn
                      ? 'সাবস্ক্রিপশন প্রয়োজন'
                      : 'Subscription required',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: PosColors.slate,
                  ),
                ),
                const SizedBox(height: 4),
                TfText(
                  app.strings.isBn
                      ? 'এই ফিচারটি ব্যবহার করতে সক্রিয় সাবস্ক্রিপশন প্রয়োজন'
                      : 'An active subscription is needed to use this feature.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: PosColors.muted,
                  ),
                ),
                const SizedBox(height: PosSpacing.sp3),
                TfButton(
                  label: app.strings.isBn
                      ? 'আপগ্রেড করুন'
                      : 'Upgrade subscription',
                  icon: Icons.arrow_upward_rounded,
                  busy: _busy,
                  onPressed: _busy ? null : _handleUpgrade,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpgrade() async {
    final app = AppScope.of(context);
    setState(() => _busy = true);
    await app.requestSubscriptionUpgrade(feature: widget.feature);
    if (!mounted) return;
    setState(() => _busy = false);

    if (app.upgradeInfo != null) {
      await _showUpgradeDialog(app);
    }
  }

  Future<void> _showUpgradeDialog(PosAppController app) async {
    final checked = <String>{};
    final inputController = TextEditingController();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _UpgradeScreenBlocker(
          app: app,
          feature: widget.feature,
          checked: checked,
          inputController: inputController,
        );
      },
    );
  }
}

class _UpgradeScreenBlocker extends StatefulWidget {
  const _UpgradeScreenBlocker({
    required this.app,
    required this.feature,
    required this.checked,
    required this.inputController,
  });

  final PosAppController app;
  final String? feature;
  final Set<String> checked;
  final TextEditingController inputController;

  @override
  State<_UpgradeScreenBlocker> createState() => _UpgradeScreenBlockerState();
}

class _UpgradeScreenBlockerState extends State<_UpgradeScreenBlocker> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final info = widget.app.upgradeInfo;
    debugPrint('[UpgradeBlocker] info=$info');
    if (info == null) {
      debugPrint('[UpgradeBlocker] info is null — showing spinner');
      return Scaffold(
        backgroundColor: PosColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final addonOptions = (info['addonOptions'] as List<dynamic>?) ?? [];
    final message = info['message'] as String? ?? '';
    final title = info['title'] as String? ?? 'Subscription';
    final inputField = info['inputField'] as bool? ?? false;
    final inputLabel = info['inputLabel'] as String? ?? '';
    debugPrint('[UpgradeBlocker] title=$title msg=$message addonOptions=$addonOptions');

    return PopScope(
      canPop: !_checking,
      child: ScreenBlocker(
        dismissible: false,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: PosColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(PosRadii.sm),
          ),
          child: const Icon(
            Icons.card_membership_outlined,
            color: PosColors.warning,
            size: 24,
          ),
        ),
        inputLabel: inputField ? inputLabel : null,
        inputController: inputField ? widget.inputController : null,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TfText(
              'SUBSCRIPTION',
              style: const TextStyle(
                color: PosColors.warning,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.77,
              ),
            ),
            const SizedBox(height: PosSpacing.sp3),
            TfText(
              title,
              style: const TextStyle(
                color: PosColors.primaryDark,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            const SizedBox(height: PosSpacing.sp3),
            TfText(
              message,
              style: const TextStyle(
                color: PosColors.inkSoft,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                height: 1.55,
              ),
            ),
            if (addonOptions.isNotEmpty) ...[
              const SizedBox(height: PosSpacing.sp4),
              TfText(
                'Add-ons',
                style: const TextStyle(
                  color: PosColors.primaryDark,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: PosSpacing.sp2),
              ...addonOptions.map((opt) {
                final key = opt['key'] as String;
                final label = opt['label'] as String? ?? key;
                final price = opt['price'] as num? ?? 0;
                final owned = opt['owned'] as bool? ?? false;
                return CheckboxListTile(
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  value: owned || widget.checked.contains(key),
                  onChanged: owned
                      ? null
                      : (checked) {
                          setState(() {
                            if (checked == true) {
                              widget.checked.add(key);
                            } else {
                              widget.checked.remove(key);
                            }
                          });
                        },
                  title: TfText(
                    '$label (৳${price.toInt()}/mo)',
                    style: const TextStyle(
                      fontSize: 14,
                      color: PosColors.slate,
                    ),
                  ),
                  subtitle: owned
                      ? TfText(
                          'Already owned',
                          style: const TextStyle(
                            fontSize: 12,
                            color: PosColors.success,
                          ),
                        )
                      : null,
                );
              }),
            ],
          ],
        ),
        actions: [
          ScreenBlockerAction(
            label: 'Check now',
            icon: Icons.refresh_rounded,
            busy: _checking,
            onPressed: _checking ? null : _checkNow,
          ),
          ScreenBlockerAction(
            label: 'Cancel',
            icon: Icons.close_rounded,
            variant: TfButtonVariant.paper,
            onPressed: _checking
                ? null
                : () {
                    widget.app.clearUpgradeInfo();
                    Navigator.of(context).pop();
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _checkNow() async {
    debugPrint('[UpgradeBlocker] checkNow — feature=${widget.feature}');
    setState(() => _checking = true);
    try {
      await widget.app.syncSubscriptionAccessFromCloud(quiet: false);

      final hasAccess = widget.feature != null
          ? widget.app.hasFeature(widget.feature!)
          : widget.app.subscriptionState == 'paid';

      debugPrint('[UpgradeBlocker] checkNow — hasAccess=$hasAccess subState=${widget.app.subscriptionState}');

      if (hasAccess) {
        widget.app.clearUpgradeInfo();
        if (mounted) Navigator.of(context).pop();
        return;
      }

      await widget.app.requestSubscriptionUpgrade(feature: widget.feature);
    } catch (e) {
      debugPrint('[UpgradeBlocker] checkNow error: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }
}
