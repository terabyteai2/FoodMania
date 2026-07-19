import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    _future ??= AppScope.read(context).fetchAuditEvents();
  }

  void _reload() {
    setState(() {
      _future = AppScope.read(context).fetchAuditEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.selectMany(
      context,
      const [AppAspect.language],
    ).strings;
    return AppScaffold(
      title: text.auditTrail,
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
    return GestureDetector(
      onTap: () => _showAuditDetail(context, entry, text),
      child: TfCard(
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
                        : (text.isBn
                              ? entry.action.labelBn
                              : entry.action.label),
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
                  if (entry.items.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    for (final item in entry.items)
                      TfText(
                        '${item.qty}× ${item.name}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: PosColors.muted,
                          height: 1.4,
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
        return const _Tone(PosColors.neutralInk, PosColors.neutralSoft);
      case AuditAction.unknown:
        return const _Tone(PosColors.muted, PosColors.surfaceSunk);
    }
  }
}

void _showAuditDetail(BuildContext context, AuditEntry entry, AppStrings text) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _AuditDetailSheet(entry: entry, text: text),
  );
}

class _AuditDetailSheet extends StatelessWidget {
  const _AuditDetailSheet({required this.entry, required this.text});

  final AuditEntry entry;
  final AppStrings text;

  @override
  Widget build(BuildContext context) {
    final tone = _tone(entry.action);
    final who = (entry.who ?? '').trim().isEmpty
        ? text.auditUnknownWho
        : entry.who!.trim();
    final roleLabel = (entry.role ?? '').trim();
    final ts = DateFormat('MMM d, yyyy · h:mm a').format(entry.createdAt);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: PosColors.lineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: tone.soft,
                      borderRadius: BorderRadius.circular(PosRadii.tag),
                    ),
                    child: TfText(
                      text.isBn ? entry.action.labelBn : entry.action.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tone.fg,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TfText(
                    entry.orderSerial != null
                        ? text.auditOrderRef(entry.orderSerial!)
                        : (text.isBn
                              ? entry.action.labelBn
                              : entry.action.label),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: PosColors.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _DetailSection(
                label: text.isBn ? 'কে' : 'Who',
                children: [
                  _DetailRow(label: text.isBn ? 'নাম' : 'Name', value: who),
                  if (roleLabel.isNotEmpty)
                    _DetailRow(label: 'Role', value: roleLabel),
                  _DetailRow(label: text.isBn ? 'সময়' : 'Time', value: ts),
                ],
              ),
              if (entry.amount != null ||
                  (entry.reason ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                _DetailSection(
                  label: text.isBn ? 'বিবরণ' : 'Details',
                  children: [
                    if (entry.amount != null)
                      _DetailRow(
                        label: 'Amount',
                        value: tfFormatCurrency(context, entry.amount!),
                      ),
                    if ((entry.reason ?? '').trim().isNotEmpty)
                      _DetailRow(
                        label: text.isBn ? 'কারণ' : 'Reason',
                        value: entry.reason!.trim(),
                      ),
                  ],
                ),
              ],
              if (entry.items.isNotEmpty) ...[
                const SizedBox(height: 16),
                _DetailSection(
                  label: text.isBn ? 'আইটেম' : 'Items',
                  children: entry.items
                      .map(
                        (item) =>
                            _DetailRow(label: item.name, value: '×${item.qty}'),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static _Tone _tone(AuditAction a) {
    switch (a) {
      case AuditAction.void_:
        return const _Tone(PosColors.danger, PosColors.dangerSoft);
      case AuditAction.refund:
        return const _Tone(PosColors.warning, PosColors.warningSoft);
      case AuditAction.comp:
        return const _Tone(PosColors.info, PosColors.infoSoft);
      case AuditAction.discount:
        return const _Tone(PosColors.neutralInk, PosColors.neutralSoft);
      case AuditAction.unknown:
        return const _Tone(PosColors.muted, PosColors.surfaceSunk);
    }
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TfText(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: PosColors.muted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PosColors.surfaceSunk,
            borderRadius: BorderRadius.circular(PosRadii.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: TfText(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: PosColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TfText(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PosColors.text,
              ),
            ),
          ),
        ],
      ),
    );
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
