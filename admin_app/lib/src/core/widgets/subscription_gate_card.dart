import 'package:flutter/material.dart';
import '../../app_scope.dart';
import '../theme/app_theme.dart';
import 'tf_design_system.dart';

class SubscriptionGateCard extends StatelessWidget {
  const SubscriptionGateCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.subscriptionState == 'paid') return const SizedBox.shrink();

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
                  onPressed: () => app.requestSubscriptionUpgrade(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
