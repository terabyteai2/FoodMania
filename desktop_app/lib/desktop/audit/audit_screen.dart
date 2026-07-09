import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:local_pos/src/app_scope.dart';
import 'package:local_pos/src/models/audit_entry.dart';

import '../theme/desk_format.dart';
import '../theme/desk_theme.dart';
import '../theme/desk_widgets.dart';

/// Audit trail — void / refund / comp / discount events (last 30 days).
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  Future<List<AuditEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _future = AppScope.read(context).fetchAuditEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        Expanded(
          child: FutureBuilder<List<AuditEntry>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                    child: Text(
                        snap.error.toString().replaceFirst('Exception: ', ''),
                        style: TextStyle(color: PosColors.muted)));
              }
              final entries = snap.data ?? const [];
              if (entries.isEmpty) {
                return Center(
                    child: Text('No audit events',
                        style: TextStyle(color: PosColors.muted)));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _row(entries[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: PosColors.surface,
        border: Border(bottom: BorderSide(color: PosColors.line)),
      ),
      child: const Text('Audit',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
    );
  }

  Widget _row(AuditEntry entry) {
    final (label, color) = _action(entry.action);
    final when = DateFormat('d MMM · h:mm a').format(entry.createdAt.toLocal());
    final who = [
      if ((entry.who ?? '').isNotEmpty) entry.who!,
      if ((entry.role ?? '').isNotEmpty) entry.role!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: deskCardDecoration(radius: DeskMetrics.tileRadius),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(PosRadii.sm),
            ),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text([
                  if (entry.orderSerial != null) '#${entry.orderSerial}',
                  if ((entry.reason ?? '').isNotEmpty) entry.reason!,
                ].join('  ·  '),
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text([when, if (who.isNotEmpty) who].join('  ·  '),
                    style: TextStyle(fontSize: 12, color: PosColors.muted)),
              ],
            ),
          ),
          if (entry.amount != null)
            Text(money(context, entry.amount!),
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  (String, Color) _action(AuditAction action) {
    switch (action) {
      case AuditAction.void_:
        return ('VOID', PosColors.danger);
      case AuditAction.refund:
        return ('REFUND', PosColors.warning);
      case AuditAction.comp:
        return ('COMP', PosColors.primary);
      case AuditAction.discount:
        return ('DISCOUNT', PosColors.success);
      case AuditAction.unknown:
        return ('EVENT', PosColors.muted);
    }
  }
}
