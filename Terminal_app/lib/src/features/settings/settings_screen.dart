import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notification_center.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/pos_notification.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    this.onNavigateToOrders,
    this.onNavigateToTarget,
    super.key,
  });

  final VoidCallback? onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    final items = [
      _SettingActionData(
        title: text.languageLabel,
        subtitle: text.languageSubtitle,
        icon: Icons.translate_rounded,
        trailing: app.language.label,
        onTap: () => _openLanguageSettings(context),
      ),
      _SettingActionData(
        title: text.aboutUs,
        subtitle: text.isBn
            ? 'টার্মিনাল POS সম্পর্কে'
            : 'About the terminal POS',
        icon: Icons.info_outline_rounded,
        onTap: () => _openAboutUs(context),
      ),
      _SettingActionData(
        title: text.privacyPolicy,
        subtitle: text.isBn
            ? 'ডাটা, অর্ডার ও ক্লাউড সিঙ্ক নীতি'
            : 'Data, orders, and cloud sync policy',
        icon: Icons.privacy_tip_outlined,
        onTap: () => _openPrivacyPolicy(context),
      ),
      _SettingActionData(
        title: text.settingsLogOut,
        subtitle: text.logOutSubtitle,
        icon: Icons.logout_rounded,
        onTap: () => _confirmLogout(context),
        danger: true,
      ),
    ];

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
                      title: text.settings,
                      subtitle: text.isBn
                          ? 'টার্মিনাল সেটিংস'
                          : 'Terminal settings',
                      trailing: [
                        const HeaderModeButton(),
                        HeaderNotificationBell(
                          onNavigateToOrders: onNavigateToOrders ?? () {},
                          onNavigateToTarget: onNavigateToTarget,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TfSectionHeader(
                      label: text.isBn ? 'টার্মিনাল' : 'Terminal',
                    ),
                    _SettingsGroupCard(items: items),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openLanguageSettings(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const _LanguageSettingsPage()),
    );
  }

  Future<void> _openAboutUs(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _InfoPage(
          title: AppScope.of(context).strings.aboutUs,
          icon: Icons.info_outline_rounded,
          children: const [
            _InfoParagraph(
              en: 'QuickBites Terminal is the lightweight Android POS app for restaurant counters and POS terminals with built-in printers.',
              bn: 'QuickBites Terminal হলো রেস্টুরেন্ট কাউন্টার ও বিল্ট-ইন প্রিন্টারসহ POS টার্মিনালের জন্য হালকা Android POS অ্যাপ।',
            ),
            _InfoParagraph(
              en: 'It keeps the same cloud account, menu, order sync, notifications, activation checks, and in-app update system as the main admin app.',
              bn: 'এটি মেইন অ্যাডমিন অ্যাপের একই ক্লাউড অ্যাকাউন্ট, মেনু, অর্ডার সিঙ্ক, নোটিফিকেশন, অ্যাক্টিভেশন চেক এবং ইন-অ্যাপ আপডেট সিস্টেম ব্যবহার করে।',
            ),
            _InfoParagraph(
              en: 'Inventory, reports, staff management, Bluetooth printer pairing, and heavy manager dashboards are intentionally removed for faster use on low-memory devices.',
              bn: 'কম RAM ডিভাইসে দ্রুত ব্যবহারের জন্য ইনভেন্টরি, রিপোর্ট, স্টাফ ম্যানেজমেন্ট, Bluetooth প্রিন্টার পেয়ারিং এবং ভারী ম্যানেজার ড্যাশবোর্ড রাখা হয়নি।',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _InfoPage(
          title: AppScope.of(context).strings.privacyPolicy,
          icon: Icons.privacy_tip_outlined,
          children: const [
            _InfoParagraph(
              en: 'The terminal app stores the restaurant menu, orders, printer status, language preference, login state, sync queue, and troubleshooting data needed to run the POS.',
              bn: 'টার্মিনাল অ্যাপ POS চালানোর জন্য রেস্টুরেন্ট মেনু, অর্ডার, প্রিন্টার স্ট্যাটাস, ভাষা পছন্দ, লগইন অবস্থা, সিঙ্ক কিউ এবং ট্রাবলশুটিং ডাটা সংরক্ষণ করে।',
            ),
            _InfoParagraph(
              en: 'Cloud sync sends menu and order changes to the configured FoodMania backend so authorized restaurant devices and the online storefront stay updated.',
              bn: 'ক্লাউড সিঙ্ক মেনু ও অর্ডারের পরিবর্তন নির্ধারিত FoodMania backend-এ পাঠায়, যাতে অনুমোদিত রেস্টুরেন্ট ডিভাইস ও অনলাইন স্টোরফ্রন্ট আপডেট থাকে।',
            ),
            _InfoParagraph(
              en: 'Menu scan images are uploaded only when a user starts menu scanning. Built-in printing sends receipt bytes to the local terminal printer.',
              bn: 'ব্যবহারকারী মেনু স্ক্যান শুরু করলে শুধু তখনই মেনু ছবিগুলো আপলোড হয়। বিল্ট-ইন প্রিন্টিং লোকাল টার্মিনাল প্রিন্টারে রসিদের byte পাঠায়।',
            ),
            _InfoParagraph(
              en: 'Logging out removes the active session from this device, but synced restaurant data remains governed by the restaurant account and backend retention policy.',
              bn: 'লগ আউট করলে এই ডিভাইসের সক্রিয় সেশন সরানো হয়, কিন্তু সিঙ্ক হওয়া রেস্টুরেন্ট ডাটা রেস্টুরেন্ট অ্যাকাউন্ট ও backend retention policy অনুযায়ী থাকে।',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final app = AppScope.of(context);
    final text = app.strings;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: TfText(text.settingsLogOut),
        content: TfText(text.logOutSubtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(text.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(text.settingsLogOut),
          ),
        ],
      ),
    );
    if (ok == true) {
      await app.logOut();
    }
  }
}

class _SettingActionData {
  const _SettingActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.trailing,
    this.danger = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final String? trailing;
  final bool danger;
}

class _SettingsGroupCard extends StatelessWidget {
  const _SettingsGroupCard({required this.items});

  final List<_SettingActionData> items;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _SettingsActionTile(item: items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, color: PosColors.line),
          ],
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  const _SettingsActionTile({required this.item});

  final _SettingActionData item;

  @override
  Widget build(BuildContext context) {
    final color = item.danger ? PosColors.danger : PosColors.slate;
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: item.danger
                    ? PosColors.dangerSoft
                    : PosColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: PosColors.line),
              ),
              child: Icon(item.icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TfText(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  TfText(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PosColors.muted,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            if (item.trailing != null) ...[
              const SizedBox(width: 8),
              TfText(
                item.trailing!,
                style: const TextStyle(
                  color: PosColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: PosColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageSettingsPage extends StatelessWidget {
  const _LanguageSettingsPage();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return _InfoShell(
      title: text.languageLabel,
      icon: Icons.translate_rounded,
      child: Column(
        children: [
          for (final language in AppLanguage.values)
            _LanguageTile(
              language: language,
              selected: app.language == language,
              onTap: () => app.updateLanguage(language),
            ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TfCard(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: onTap,
          leading: Icon(
            selected ? Icons.check_circle_rounded : Icons.language_rounded,
            color: selected ? PosColors.success : PosColors.muted,
          ),
          title: TfText(
            language.label,
            style: const TextStyle(
              color: PosColors.slate,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoPage extends StatelessWidget {
  const _InfoPage({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<_InfoParagraph> children;

  @override
  Widget build(BuildContext context) {
    return _InfoShell(
      title: title,
      icon: icon,
      child: TfCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1) const SizedBox(height: 14),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoShell extends StatelessWidget {
  const _InfoShell({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
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
                      title: title,
                      leading: TfIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: PosColors.primarySoft,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: PosColors.line),
                          ),
                          child: Icon(icon, color: PosColors.primaryDark),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TfText(
                            title,
                            style: const TextStyle(
                              color: PosColors.slate,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    child,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoParagraph extends StatelessWidget {
  const _InfoParagraph({required this.en, required this.bn});

  final String en;
  final String bn;

  @override
  Widget build(BuildContext context) {
    final isBn = AppScope.of(context).strings.isBn;
    return TfText(
      isBn ? bn : en,
      style: const TextStyle(
        color: PosColors.slate,
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
