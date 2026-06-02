import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../enums/business_tier.dart';
import '../theme/app_theme.dart';
import 'tf_design_system.dart';

/// Compact header dropdown for progressively revealing restaurant features.
class HeaderComplexityDial extends StatelessWidget {
  const HeaderComplexityDial({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final selectedTier = app.businessTier;
    final isBn = tfIsBn(context);

    return PopupMenuButton<BusinessTier>(
      key: const ValueKey('complexity-dial-dropdown'),
      tooltip: isBn ? 'জটিলতার মাত্রা' : 'Complexity level',
      initialValue: selectedTier,
      onSelected: app.setBusinessTier,
      position: PopupMenuPosition.under,
      color: PosColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.sm),
        side: const BorderSide(color: PosColors.line, width: 0.5),
      ),
      itemBuilder: (context) {
        return [
          for (final tier in BusinessTier.values)
            PopupMenuItem<BusinessTier>(
              key: ValueKey('complexity-dial-${tier.key}'),
              value: tier,
              child: _TierMenuItem(tier: tier, selected: tier == selectedTier),
            ),
        ];
      },
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: PosSpacing.sp2),
        decoration: BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.circular(PosRadii.sm),
          border: Border.all(color: PosColors.line, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TfText(
              selectedTier.displayNameFor(isBn: isBn),
              style: const TextStyle(
                color: PosColors.primaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: PosSpacing.sp1),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: PosColors.muted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _TierMenuItem extends StatelessWidget {
  const _TierMenuItem({required this.tier, required this.selected});

  final BusinessTier tier;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PosSpacing.sp2,
        vertical: PosSpacing.sp2,
      ),
      decoration: BoxDecoration(
        color: selected ? PosColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(PosRadii.sm),
      ),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: selected ? PosColors.surface : PosColors.surfaceSunk,
              shape: BoxShape.circle,
              border: Border.all(color: PosColors.line, width: 0.5),
            ),
            alignment: Alignment.center,
            child: TfText(
              '${tier.index + 1}',
              style: const TextStyle(
                color: PosColors.primaryDark,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: PosSpacing.sp3),
          Expanded(
            child: TfText(
              tier.displayNameFor(isBn: tfIsBn(context)),
              style: const TextStyle(
                color: PosColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (selected)
            const Icon(
              Icons.check_rounded,
              color: PosColors.primaryDark,
              size: 18,
            ),
        ],
      ),
    );
  }
}
