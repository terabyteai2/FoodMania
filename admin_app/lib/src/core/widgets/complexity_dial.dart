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
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 84, maxWidth: 90),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: PosColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: PosColors.line, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _tierIcon(selectedTier),
                color: PosColors.primaryDark,
                size: 20,
              ),
              const SizedBox(width: 6),
              _HeatCircle(tier: selectedTier),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down_rounded,
                color: PosColors.muted,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _tierIcon(BusinessTier tier) {
    return switch (tier) {
      BusinessTier.simple => Icons.storefront_outlined,
      BusinessTier.standard => Icons.local_cafe_outlined,
      BusinessTier.advanced => Icons.restaurant_outlined,
      BusinessTier.enterprise => Icons.account_tree_outlined,
    };
  }
}

class _HeatCircle extends StatelessWidget {
  const _HeatCircle({required this.tier});

  final BusinessTier tier;

  @override
  Widget build(BuildContext context) {
    final heat = switch (tier) {
      BusinessTier.simple => PosColors.success,
      BusinessTier.standard => PosColors.primary,
      BusinessTier.advanced => PosColors.warning,
      BusinessTier.enterprise => PosColors.urgent,
    };
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: heat.withValues(alpha: 0.16),
        border: Border.all(color: PosColors.lineStrong, width: 1),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: heat, shape: BoxShape.circle),
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
