import 'package:flutter/material.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/staff_member.dart';

import '../theme/desk_theme.dart';
import '../theme/desk_widgets.dart';

/// Staff list with active toggle + invite (owner can invite managers, managers
/// invite waiters — the backend enforces the gate).
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  Future<List<StaffMember>>? _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() => setState(() => _future = AppScope.read(context).fetchStaff());

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? PosColors.danger : PosColors.secondary,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _invite() async {
    final app = AppScope.read(context);
    final result = await showDialog<_InviteData>(
      context: context,
      builder: (_) => _InviteDialog(canInviteManager: app.isOwner),
    );
    if (result == null) return;
    try {
      await app.inviteStaff(
        displayName: result.name,
        phone: result.phone.isEmpty ? null : result.phone,
        email: result.email.isEmpty ? null : result.email,
        role: result.role,
      );
      _toast('Invitation sent');
      _refresh();
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: deskCardDecoration(),
              child: FutureBuilder<List<StaffMember>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                        child: Text(
                            snap.error
                                .toString()
                                .replaceFirst('Exception: ', ''),
                            style: TextStyle(color: PosColors.muted)));
                  }
                  final staff = snap.data ?? const [];
                  if (staff.isEmpty) {
                    return Center(
                        child: Text('No staff yet',
                            style: TextStyle(color: PosColors.muted)));
                  }
                  return ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: staff.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: PosColors.line),
                    itemBuilder: (_, i) => _row(staff[i]),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: Row(
        children: [
          const Text('Staff',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: PosColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: _invite,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('Invite',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }

  Widget _row(StaffMember member) {
    final name = member.displayName?.trim().isNotEmpty == true
        ? member.displayName!
        : (member.email ?? member.phone ?? 'Staff');
    final contact = member.email ?? member.phone ?? '';
    return Container(
      color: PosColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (contact.isNotEmpty)
                  Text(contact,
                      style: TextStyle(fontSize: 12, color: PosColors.muted)),
              ],
            ),
          ),
          _rolePill(member.role.label),
          if (member.inviteStatus == 'pending') ...[
            const SizedBox(width: 8),
            _pill('Pending', PosColors.warning),
          ],
          const SizedBox(width: 12),
          Switch(
            value: member.isActive,
            activeThumbColor: PosColors.primary,
            onChanged: (v) => _setActive(member, v),
          ),
        ],
      ),
    );
  }

  Future<void> _setActive(StaffMember member, bool value) async {
    try {
      await AppScope.read(context).setStaffActive(member.id, value);
      _refresh();
    } catch (error) {
      _toast(error.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Widget _rolePill(String role) => _pill(role, PosColors.primary);

  Widget _pill(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(PosRadii.pill),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      );
}

class _InviteData {
  const _InviteData(this.name, this.phone, this.email, this.role);
  final String name;
  final String phone;
  final String email;
  final String role;
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.canInviteManager});
  final bool canInviteManager;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String _role = 'waiter';

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosRadii.xl),
      ),
      title: const Text('Invite staff',
          style: TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('Name', _name),
            const SizedBox(height: 10),
            _field('Phone', _phone),
            const SizedBox(height: 10),
            _field('Email', _email),
            const SizedBox(height: 12),
            Row(
              children: [
                _roleChip('waiter', 'Waiter'),
                if (widget.canInviteManager) ...[
                  const SizedBox(width: 8),
                  _roleChip('manager', 'Manager'),
                ],
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: TextStyle(color: PosColors.ink2)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PosColors.primary),
          onPressed: () => Navigator.pop(
            context,
            _InviteData(_name.text.trim(), _phone.text.trim(),
                _email.text.trim(), _role),
          ),
          child: const Text('Send invite'),
        ),
      ],
    );
  }

  Widget _roleChip(String value, String label) {
    final active = _role == value;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      selectedColor: PosColors.primary,
      labelStyle: TextStyle(
          color: active ? Colors.white : PosColors.primaryDark,
          fontWeight: FontWeight.w600),
      onSelected: (_) => setState(() => _role = value),
    );
  }

  Widget _field(String label, TextEditingController controller) => TextField(
        controller: controller,
        decoration: InputDecoration(
          isDense: true,
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(PosRadii.md),
          ),
        ),
      );
}
