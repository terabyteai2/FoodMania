import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_page_header.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/account_role.dart';
import '../../models/pos_notification.dart';
import '../audit/audit_screen.dart';
import '../messaging/messages_screen.dart';
import '../staff/staff_screen.dart';
import '../menu/menu_management_screen.dart';
import '../settings/settings_screen.dart';

/// QuickBytes "More" hub — shared secondary navigation across all roles
/// (spec §14). Profile + demo role switcher, messaging link, role-gated manage
/// group, service-mode toggle and the language quick toggle.
class MoreScreen extends StatelessWidget {
  const MoreScreen({
    required this.onNavigateToOrders,
    this.onNavigateToTarget,
    super.key,
  });

  final VoidCallback onNavigateToOrders;
  final ValueChanged<PosNotificationTarget>? onNavigateToTarget;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return AppScaffold(
      title: text.moreTab,
      headerWidget: AppPageHeader(
        title: text.moreTab,
        onNavigateToOrders: onNavigateToOrders,
        onNavigateToTarget: onNavigateToTarget,
      ),
      showDatePill: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ProfileCard(app: app, text: text),
          if (app.canMessages) ...[
            const SizedBox(height: 16),
            _NavRow(
              icon: Icons.forum_outlined,
              label: text.messages,
              onTap: () => _push(context, const MessagesScreen()),
            ),
          ],
          const SizedBox(height: 20),
          TfSectionHeader(label: text.manageSection),
          _ManageGroup(
            app: app,
            text: text,
            onNavigateToOrders: onNavigateToOrders,
            push: (w) => _push(context, w),
          ),
          if (app.canMessages) ...[
            const SizedBox(height: 20),
            _ServiceModeCard(app: app, text: text),
          ],
          const SizedBox(height: 20),
          _LanguageCard(app: app, text: text),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.app, required this.text});

  final PosAppController app;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final name = app.accountDisplayName.trim().isNotEmpty
        ? app.accountDisplayName.trim()
        : (app.accountUsername.trim().isNotEmpty
              ? app.accountUsername.trim()
              : app.outletName);
    return TfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: PosColors.primarySoft,
                  borderRadius: BorderRadius.circular(PosRadii.md),
                  border: Border.all(color: PosColors.line),
                ),
                alignment: Alignment.center,
                child: TfText(
                  _initials(name),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: PosColors.accentStrong,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TfText(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: PosColors.slate,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _RoleBadge(role: app.accountRole, isBn: text.isBn),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TfMicroLabel(text.switchRoleDemo),
          const SizedBox(height: 8),
          _RoleSwitcher(app: app, isBn: text.isBn),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.isBn});

  final AccountRole role;
  final bool isBn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: PosColors.primarySoft,
        borderRadius: BorderRadius.circular(PosRadii.tag),
        border: Border.all(color: PosColors.line),
      ),
      child: TfText(
        isBn ? role.labelBn : role.label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: PosColors.accentStrong,
          letterSpacing: 0.02 * 11,
        ),
      ),
    );
  }
}

/// Three-segment demo role switcher (Owner / Manager / Waiter).
class _RoleSwitcher extends StatelessWidget {
  const _RoleSwitcher({required this.app, required this.isBn});

  final PosAppController app;
  final bool isBn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.input),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          for (final role in AccountRole.values)
            Expanded(
              child: _seg(role, app.accountRole == role),
            ),
        ],
      ),
    );
  }

  Widget _seg(AccountRole role, bool on) {
    return GestureDetector(
      onTap: () => app.setAccountRoleDemo(role),
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? PosColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(PosRadii.tag),
          border: on
              ? Border.all(color: PosColors.lineStrong)
              : Border.all(color: Colors.transparent),
        ),
        child: TfText(
          isBn ? role.labelBn : role.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: on ? PosColors.text : PosColors.textSec,
          ),
        ),
      ),
    );
  }
}

class _ManageGroup extends StatelessWidget {
  const _ManageGroup({
    required this.app,
    required this.text,
    required this.onNavigateToOrders,
    required this.push,
  });

  final PosAppController app;
  final AppStrings text;
  final VoidCallback onNavigateToOrders;
  final void Function(Widget) push;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    void add(IconData icon, String label, Widget screen) {
      if (rows.isNotEmpty) rows.add(const _RowDivider());
      rows.add(_NavRow(icon: icon, label: label, onTap: () => push(screen)));
    }

    if (app.canManageStock) {
      add(
        Icons.restaurant_menu_outlined,
        text.menu,
        MenuManagementScreen(onNavigateToOrders: onNavigateToOrders),
      );
      add(Icons.groups_outlined, text.staff, const StaffScreen());
      add(
        Icons.fact_check_outlined,
        text.auditTrail,
        const AuditScreen(),
      );
    }
    if (app.canManageSettings) {
      add(
        Icons.settings_outlined,
        text.settings,
        SettingsScreen(onNavigateToOrders: onNavigateToOrders),
      );
    }

    if (rows.isEmpty) {
      return TfCard(
        child: TfText(
          text.comingSoon,
          style: const TextStyle(color: PosColors.muted),
        ),
      );
    }
    return TfListCard(child: Column(children: rows));
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: PosColors.slate),
              const SizedBox(width: 14),
              Expanded(
                child: TfText(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PosColors.slate,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: PosColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, indent: 48);
  }
}

class _ServiceModeCard extends StatelessWidget {
  const _ServiceModeCard({required this.app, required this.text});

  final PosAppController app;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final counter = app.counterModeEnabled;
    return TfCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  text.serviceMode,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: PosColors.slate,
                  ),
                ),
                const SizedBox(height: 2),
                TfText(
                  counter ? text.counterService : text.fullService,
                  style: const TextStyle(fontSize: 13, color: PosColors.muted),
                ),
              ],
            ),
          ),
          TfToggle(
            value: counter,
            onChanged: app.setCounterModeEnabled,
            semanticLabel: text.serviceMode,
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({required this.app, required this.text});

  final PosAppController app;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      child: Row(
        children: [
          const Icon(Icons.translate_rounded, size: 20, color: PosColors.slate),
          const SizedBox(width: 14),
          Expanded(
            child: TfText(
              text.languageLabel,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: PosColors.slate,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: PosColors.surfaceSunk,
              borderRadius: BorderRadius.circular(PosRadii.input),
              border: Border.all(color: PosColors.line),
            ),
            child: Row(
              children: [
                for (final lang in AppLanguage.values)
                  _langSeg(lang, app.language == lang, () {
                    app.updateLanguage(lang);
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _langSeg(AppLanguage lang, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: on ? PosColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(PosRadii.tag),
          border: on
              ? Border.all(color: PosColors.lineStrong)
              : Border.all(color: Colors.transparent),
        ),
        child: TfText(
          lang == AppLanguage.bn ? 'বাংলা' : 'EN',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: on ? PosColors.text : PosColors.textSec,
          ),
        ),
      ),
    );
  }
}
