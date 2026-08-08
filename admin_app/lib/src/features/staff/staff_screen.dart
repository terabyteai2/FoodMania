import 'package:flutter/material.dart';

import '../../app_controller.dart';
import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/account_role.dart';
import '../../models/staff_member.dart';

/// Staff management (spec §4.10) — member list with role badges + active
/// toggle, and a bottom-bar Invite flow with role gating (owner=any,
/// manager=waiter-only). Reads `GET /admin/staff`, writes `POST/PATCH`.
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  Future<List<StaffMember>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).fetchStaff();
  }

  void _reload() {
    setState(() => _future = AppScope.of(context).fetchStaff());
  }

  Future<void> _toggleActive(StaffMember m, bool value) async {
    final app = AppScope.of(context);
    try {
      await app.setStaffActive(m.id, value);
      _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: TfText(app.strings.inviteFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = app.strings;
    return AppScaffold(
      title: text.staff,
      showBackButton: true,
      pinHeader: true,
      fillBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: FutureBuilder<List<StaffMember>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorState(text: text, onRetry: _reload);
                }
                final members = snap.data ?? const <StaffMember>[];
                if (members.isEmpty) {
                  return Center(
                    child: TfEmptyState(
                      icon: Icons.groups_outlined,
                      title: text.noStaffYet,
                      message: 'Invite your team with the button below.',
                      messageBn: text.noStaffHint,
                    ),
                  );
                }
                final activeCount = members.where((m) => m.isActive).length;
                return RefreshIndicator(
                  color: PosColors.primaryDark,
                  backgroundColor: PosColors.primary,
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: members.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: TfText(
                            text.staffActiveCount(activeCount, members.length),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PosColors.textSec,
                            ),
                          ),
                        );
                      }
                      final m = members[i - 1];
                      final canToggle =
                          !(m.role == AccountRole.manager && !app.isOwner);
                      return _StaffCard(
                        text: text,
                        member: m,
                        canToggle: canToggle,
                        onToggle: (v) => _toggleActive(m, v),
                        onDelete: () => _confirmDelete(context, app, m),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
            child: TfButton(
              label: text.inviteStaffCta,
              icon: Icons.person_add_alt_1_outlined,
              variant: TfButtonVariant.primary,
              size: TfButtonSize.lg,
              onPressed: () => _openInvite(context, app),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, PosAppController app, StaffMember m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: TfText(app.strings.deleteStaff),
        content: TfText(app.strings.deleteStaffConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: TfText(app.strings.cancel)),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: TfText(app.strings.deleteAction, style: const TextStyle(color: PosColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await app.removeStaffAccount(m.id);
        if (!context.mounted) return;
        _reload();
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: TfText(app.strings.inviteFailed)));
      }
    }
  }

  Future<void> _openInvite(BuildContext context, PosAppController app) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _InviteSheet(text: app.strings, canInviteManager: app.isOwner),
    );
    if (sent == true) _reload();
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({
    required this.text,
    required this.member,
    required this.canToggle,
    required this.onToggle,
    required this.onDelete,
  });

  final AppStrings text;
  final StaffMember member;
  final bool canToggle;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: member.isActive
                  ? PosColors.neutralWash
                  : PosColors.surfaceSunk,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: TfText(
              member.initials,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: member.isActive
                    ? PosColors.neutralInk
                    : PosColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: TfText(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: PosColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(text: text, role: member.role),
                  ],
                ),
                const SizedBox(height: 2),
                TfText(
                  member.isPending
                      ? text.invitePending
                      : ((member.phone ?? '').trim().isNotEmpty
                            ? member.phone!.trim()
                            : (member.isActive
                                  ? text.staffActive
                                  : text.staffInactive)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: member.isPending
                        ? PosColors.warning
                        : PosColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<_StaffAction>(
            icon: const Icon(Icons.more_vert, size: 20, color: PosColors.muted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (action) {
              if (action == _StaffAction.delete) onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _StaffAction.delete,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: PosColors.danger),
                    const SizedBox(width: 8),
                    TfText(text.deleteStaff, style: const TextStyle(color: PosColors.danger)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          TfToggle(
            value: member.isActive,
            enabled: canToggle,
            onChanged: canToggle ? onToggle : (_) {},
            semanticLabel: text.staffActive,
          ),
        ],
      ),
    );
  }
}

enum _StaffAction { delete }

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.text, required this.role});

  final AppStrings text;
  final AccountRole role;

  @override
  Widget build(BuildContext context) {
    final isManager = role == AccountRole.manager || role == AccountRole.owner;
    final fg = PosColors.neutralInk;
    final bg = isManager ? PosColors.neutralWash : PosColors.neutralSoft;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(PosRadii.tag),
      ),
      child: TfText(
        text.isBn ? role.labelBn : role.label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          color: fg,
        ),
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.text, required this.canInviteManager});

  final AppStrings text;
  final bool canInviteManager;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  AccountRole _role = AccountRole.waiter;
  bool _busy = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty || _busy) return;
    setState(() => _busy = true);
    final app = AppScope.of(context);
    try {
      await app.inviteStaff(
        phone: phone,
        displayName: _nameCtrl.text.trim(),
        role: _role == AccountRole.manager ? 'manager' : 'waiter',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: TfText(app.strings.inviteFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final roles = <AccountRole>[
      AccountRole.waiter,
      if (widget.canInviteManager) AccountRole.manager,
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: PosColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TfText(
                  text.inviteStaffTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                if (roles.length > 1) ...[
                  TfText(
                    text.inviteAsRole,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PosColors.textSec,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final r in roles)
                        TfChip(
                          label: r.label,
                          labelBn: r.labelBn,
                          active: _role == r,
                          onTap: () => setState(() => _role = r),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                TfField(label: text.staffNameLabel, controller: _nameCtrl),
                TfField(
                  label: text.staffPhoneLabel,
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 8),
                TfButton(
                  label: text.sendInvite,
                  size: TfButtonSize.lg,
                  busy: _busy,
                  onPressed: _busy ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.text, required this.onRetry});

  final AppStrings text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: PosColors.muted,
          ),
          const SizedBox(height: 12),
          TfText(
            text.staffLoadFailed,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: PosColors.text,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            child: TfButton(
              label: text.isBn ? 'আবার চেষ্টা' : 'Retry',
              variant: TfButtonVariant.dark,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}
