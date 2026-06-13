import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/audit_entry.dart';

/// Audit trail (spec §4.10) — owner/manager view of every void / refund /
/// comp / discount override, with who · role · time · amount · reason, and
/// type-filter chips. Reads `GET /outlets/{id}/pos/audit`.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  AuditAction? _filter; // null = all
  Future<List<AuditEntry>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).fetchAuditEvents();
  }

  void _reload() {
    setState(() {
      _future = AppScope.of(context).fetchAuditEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return AppScaffold(
      title: text.auditTrail,
      showDatePill: false,
      showBackButton: true,
      pinHeader: true,
      fillBody: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterChips(
            text: text,
            selected: _filter,
            onSelected: (a) => setState(() => _filter = a),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: FutureBuilder<List<AuditEntry>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _ErrorState(text: text, onRetry: _reload);
                }
                final all = snap.data ?? const <AuditEntry>[];
                final rows = _filter == null
                    ? all
                    : all
                          .where((e) => e.action == _filter)
                          .toList(growable: false);
                if (rows.isEmpty) {
                  return Center(
                    child: TfEmptyState(
                      icon: Icons.verified_user_outlined,
                      title: text.noAuditEntries,
                      message:
                          'Voids, refunds, comps & discount overrides appear here.',
                      messageBn: text.auditEmptyHint,
                    ),
                  );
                }
                return RefreshIndicator(
                  color: PosColors.primaryDark,
                  backgroundColor: PosColors.primary,
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        _AuditRow(text: text, entry: rows[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.text,
    required this.selected,
    required this.onSelected,
  });

  final AppStrings text;
  final AuditAction? selected;
  final ValueChanged<AuditAction?> onSelected;

  @override
  Widget build(BuildContext context) {
    const actions = [
      AuditAction.void_,
      AuditAction.refund,
      AuditAction.comp,
      AuditAction.discount,
    ];
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          TfChip(
            label: text.auditAllFilter,
            active: selected == null,
            small: true,
            onTap: () => onSelected(null),
          ),
          for (final a in actions) ...[
            const SizedBox(width: 8),
            TfChip(
              label: a.label,
              labelBn: a.labelBn,
              active: selected == a,
              small: true,
              onTap: () => onSelected(a),
            ),
          ],
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.text, required this.entry});

  final AppStrings text;
  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final tone = _toneFor(entry.action);
    final mins = DateTime.now().difference(entry.createdAt).inMinutes;
    final who = (entry.who ?? '').trim().isEmpty
        ? text.auditUnknownWho
        : entry.who!.trim();
    final roleLabel = (entry.role ?? '').trim();
    final metaParts = <String>[
      who,
      if (roleLabel.isNotEmpty) roleLabel,
      text.agoMinutes(mins < 0 ? 0 : mins),
    ];
    return TfCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: tone.soft,
              borderRadius: BorderRadius.circular(PosRadii.tag),
            ),
            child: TfText(
              text.isBn ? entry.action.labelBn : entry.action.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tone.fg,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TfText(
                  entry.orderSerial != null
                      ? text.auditOrderRef(entry.orderSerial!)
                      : (text.isBn ? entry.action.labelBn : entry.action.label),
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: PosColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                TfText(
                  metaParts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: PosColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if ((entry.reason ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  TfText(
                    entry.reason!.trim(),
                    style: const TextStyle(
                      fontSize: 13,
                      color: PosColors.textSec,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (entry.amount != null) ...[
            const SizedBox(width: 10),
            TfText(
              tfFormatCurrency(context, entry.amount!),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: PosColors.text,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }

  _Tone _toneFor(AuditAction a) {
    switch (a) {
      case AuditAction.void_:
        return const _Tone(PosColors.danger, PosColors.dangerSoft);
      case AuditAction.refund:
        return const _Tone(PosColors.warning, PosColors.warningSoft);
      case AuditAction.comp:
        return const _Tone(PosColors.info, PosColors.infoSoft);
      case AuditAction.discount:
        return const _Tone(PosColors.accentStrong, PosColors.accentSoft);
      case AuditAction.unknown:
        return const _Tone(PosColors.muted, PosColors.surfaceSunk);
    }
  }
}

class _Tone {
  const _Tone(this.fg, this.soft);
  final Color fg;
  final Color soft;
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
            text.auditLoadFailed,
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
