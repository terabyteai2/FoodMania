import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../models/pos_notification.dart';
import '../enums/business_tier.dart';
import '../localization/app_strings.dart';
import '../theme/app_theme.dart';
import 'notification_center.dart';
import 'tf_design_system.dart';

/// Unified app chrome shared across every primary tab.
///
/// Renders the page [title] + [subtitle] on the left (subtitle defaults to the
/// restaurant name) and, on the right, any [extraActions], the notification
/// bell, and the account avatar dropdown (mode switch, language, sign out).
class TfGlobalTopBar extends StatelessWidget {
  const TfGlobalTopBar({
    required this.title,
    this.titleBn,
    this.subtitle,
    this.subtitleBn,
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    this.extraActions = const [],
    this.padding = const EdgeInsets.fromLTRB(
      PosSpacing.sp4,
      PosSpacing.sp3,
      PosSpacing.sp4,
      PosSpacing.sp3 - 2,
    ),
    this.showTrailing = true,
    super.key,
  });

  final String title;
  final String? titleBn;

  /// Left-side subtitle. When null, falls back to the restaurant name so the
  /// outlet identity is always visible.
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

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final isBn = tfIsBn(context);
    final t = isBn && (titleBn?.isNotEmpty ?? false) ? titleBn! : title;

    String? s;
    if (subtitle != null) {
      s = isBn && (subtitleBn?.isNotEmpty ?? false) ? subtitleBn! : subtitle;
    } else {
      final name = app.restaurantName.trim();
      if (name.isNotEmpty) s = name;
    }

    return TfUnifiedTopNav(
      title: t,
      subtitle: s,
      padding: padding,
      trailing: [
        ...extraActions,
        if (showTrailing) ...[
          HeaderNotificationBell(
            onNavigateToOrders: onNavigateToOrders ?? () {},
            onNavigateToTarget: onNavigateToTarget,
          ),
          const _AvatarDropdown(),
        ],
      ],
    );
  }
}

enum _TopAction { modeSimple, modeAdvanced, langEn, langBn, signOut }

class _AvatarDropdown extends StatelessWidget {
  const _AvatarDropdown();

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
    final isAdvanced = app.businessTier.isAdvanced;
    final language = app.language;
    final initials = _initials(app.accountDisplayName);

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
          case _TopAction.modeSimple:
            app.setBusinessTier(BusinessTier.simple);
          case _TopAction.modeAdvanced:
            app.setBusinessTier(BusinessTier.advanced);
          case _TopAction.langEn:
            app.updateLanguage(AppLanguage.en);
          case _TopAction.langBn:
            app.updateLanguage(AppLanguage.bn);
          case _TopAction.signOut:
            app.logOut();
        }
      },
      itemBuilder: (context) => [
        _eyebrowItem(context, tfPick(context, en: 'Mode', bn: 'মোড')),
        _choiceItem(
          context,
          value: _TopAction.modeSimple,
          label: tfPick(context, en: 'Simple', bn: 'সিম্পল'),
          active: !isAdvanced,
        ),
        _choiceItem(
          context,
          value: _TopAction.modeAdvanced,
          label: tfPick(context, en: 'Advanced', bn: 'অ্যাডভান্সড'),
          active: isAdvanced,
        ),
        const PopupMenuDivider(),
        _eyebrowItem(context, tfPick(context, en: 'Language', bn: 'ভাষা')),
        _choiceItem(
          context,
          value: _TopAction.langEn,
          label: 'English',
          active: language == AppLanguage.en,
        ),
        _choiceItem(
          context,
          value: _TopAction.langBn,
          label: 'বাংলা',
          active: language == AppLanguage.bn,
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_TopAction>(
          value: _TopAction.signOut,
          height: 42,
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 18,
                color: PosColors.danger,
              ),
              const SizedBox(width: 10),
              TfText(
                tfPick(context, en: 'Sign out', bn: 'সাইন আউট'),
                style: const TextStyle(
                  color: PosColors.danger,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
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
          color: PosColors.primarySoft,
          shape: BoxShape.circle,
          border: Border.all(color: PosColors.primaryWash),
        ),
        child: TfText(
          initials,
          style: const TextStyle(
            color: PosColors.accentStrong,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  PopupMenuItem<_TopAction> _eyebrowItem(BuildContext context, String label) {
    return PopupMenuItem<_TopAction>(
      enabled: false,
      height: 30,
      child: TfMicroLabel(label.toUpperCase()),
    );
  }

  PopupMenuItem<_TopAction> _choiceItem(
    BuildContext context, {
    required _TopAction value,
    required String label,
    required bool active,
  }) {
    return PopupMenuItem<_TopAction>(
      value: value,
      height: 42,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: active
            ? BoxDecoration(
                color: PosColors.primarySoft,
                borderRadius: BorderRadius.circular(PosRadii.sm),
                border: Border.all(color: PosColors.primaryWash),
              )
            : null,
        child: Row(
          children: [
            Expanded(
              child: TfText(
                label,
                style: TextStyle(
                  color: active ? PosColors.accentStrong : PosColors.text,
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (active)
              const Icon(
                Icons.check_rounded,
                size: 17,
                color: PosColors.accentStrong,
              ),
          ],
        ),
      ),
    );
  }
}
