import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../app_scope.dart';
import '../../core/localization/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/desktop_pos.dart';

/// Ordering settings (spec §4.10) — VAT + service-charge steppers and a
/// discount-presets editor (%/flat) that feeds the Review screen. Reads/writes
/// the existing POS settings (`DesktopPosSettings`); no schema change.
///
/// NOTE: the spec's delivery-areas editor (area↔charge) is a separate follow-up
/// — it needs a new `pos_delivery_areas` column + migration threaded through the
/// local SQLite settings serialization, so it is intentionally not included here.
class OrderingSettingsScreen extends StatefulWidget {
  const OrderingSettingsScreen({super.key});

  @override
  State<OrderingSettingsScreen> createState() => _OrderingSettingsScreenState();
}

class _PresetDraft {
  _PresetDraft({
    required this.id,
    required this.label,
    required this.percent,
    required this.value,
  });

  final String id;
  final TextEditingController label;
  bool percent;
  final TextEditingController value;
}

class _OrderingSettingsScreenState extends State<OrderingSettingsScreen> {
  static const _uuid = Uuid();

  DesktopPosSettings? _loaded;
  final _vatCtrl = TextEditingController();
  final _serviceCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  final List<_PresetDraft> _presets = [];
  bool _ready = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_ready) {
      _ready = true;
      _load();
    }
  }

  Future<void> _load() async {
    final settings = await AppScope.of(context).loadDesktopPosSettings();
    if (!mounted) return;
    setState(() {
      _loaded = settings;
      _vatCtrl.text = _trimNum(settings.vatRatePercent);
      _serviceCtrl.text = _trimNum(settings.serviceChargePercent);
      _targetCtrl.text = settings.dailySalesTarget != null
          ? _trimNum(settings.dailySalesTarget!)
          : '';
      _presets
        ..clear()
        ..addAll(
          settings.discountPresets.map(
            (p) => _PresetDraft(
              id: p.id.isEmpty ? _uuid.v4() : p.id,
              label: TextEditingController(text: p.label),
              percent: p.kind != 'flat',
              value: TextEditingController(text: _trimNum(p.value)),
            ),
          ),
        );
    });
  }

  @override
  void dispose() {
    _vatCtrl.dispose();
    _serviceCtrl.dispose();
    _targetCtrl.dispose();
    for (final p in _presets) {
      p.label.dispose();
      p.value.dispose();
    }
    super.dispose();
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _addPreset() {
    setState(() {
      _presets.add(
        _PresetDraft(
          id: _uuid.v4(),
          label: TextEditingController(),
          percent: true,
          value: TextEditingController(),
        ),
      );
    });
  }

  Future<void> _save() async {
    final loaded = _loaded;
    if (loaded == null || _saving) return;
    setState(() => _saving = true);
    final app = AppScope.of(context);
    final presets = <PosDiscountPreset>[];
    for (final p in _presets) {
      final label = p.label.text.trim();
      final value = double.tryParse(p.value.text.trim()) ?? 0;
      if (label.isEmpty || value <= 0) continue;
      presets.add(
        PosDiscountPreset(
          id: p.id,
          label: label,
          kind: p.percent ? 'percent' : 'flat',
          value: value,
        ),
      );
    }
    // Blank or non-positive target => leave unconfigured (null), so Control
    // Tower keeps its own default (null-safe invariant).
    final parsedTarget = double.tryParse(_targetCtrl.text.trim());
    final dailyTarget = (parsedTarget != null && parsedTarget > 0)
        ? parsedTarget
        : null;
    final updated = DesktopPosSettings(
      floorLayout: loaded.floorLayout,
      vatRatePercent: (double.tryParse(_vatCtrl.text.trim()) ?? 0).clamp(
        0,
        100,
      ),
      serviceChargePercent: (double.tryParse(_serviceCtrl.text.trim()) ?? 0)
          .clamp(0, 100),
      discountPresets: presets,
      dailySalesTarget: dailyTarget,
    );
    try {
      await app.saveDesktopPosSettings(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: TfText(app.strings.orderingSaved)));
      Navigator.of(context).maybePop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: TfText(app.strings.orderingSaveFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = AppScope.of(context).strings;
    return AppScaffold(
      title: text.orderingSettings,
      subtitle: text.orderingSettingsSubtitle,
      showDatePill: false,
      showBackButton: true,
      pinHeader: true,
      fillBody: true,
      child: _loaded == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: PosSpacing.s12),
                    children: [
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TfField(
                              label: text.vatRateLabel,
                              controller: _vatCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'),
                                ),
                              ],
                            ),
                            TfField(
                              label: text.serviceChargeLabel,
                              controller: _serviceCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'),
                                ),
                              ],
                            ),
                            TfField(
                              label: text.dailyTargetLabel,
                              hint: text.dailyTargetHint,
                              controller: _targetCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d.]'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: PosSpacing.s16),
                      Padding(
                        padding: const EdgeInsets.only(left: PosSpacing.s2, bottom: PosSpacing.s8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TfText(
                              text.discountPresetsTitle,
                              style: const TextStyle(
                                fontSize: PosFont.f15,
                                fontWeight: FontWeight.w700,
                                color: PosColors.primaryDark,
                              ),
                            ),
                            const SizedBox(height: PosSpacing.s2),
                            TfText(
                              text.discountPresetsHint,
                              style: const TextStyle(
                                fontSize: PosFont.f12_5,
                                color: PosColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_presets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: PosSpacing.s12),
                          child: TfText(
                            text.noDiscountPresets,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: PosFont.f13,
                              color: PosColors.muted,
                            ),
                          ),
                        )
                      else
                        for (var i = 0; i < _presets.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: PosSpacing.s10),
                            child: _PresetRow(
                              text: text,
                              draft: _presets[i],
                              onKind: (pct) =>
                                  setState(() => _presets[i].percent = pct),
                              onRemove: () {
                                final removed = _presets.removeAt(i);
                                removed.label.dispose();
                                removed.value.dispose();
                                setState(() {});
                              },
                            ),
                          ),
                      const SizedBox(height: PosSpacing.s4),
                      _AddPresetButton(text: text, onPressed: _addPreset),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: PosSpacing.s10, bottom: PosSpacing.s8),
                  child: TfButton(
                    label: text.save,
                    variant: TfButtonVariant.primary,
                    size: TfButtonSize.lg,
                    busy: _saving,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(PosSpacing.s14, PosSpacing.s12, PosSpacing.s14, PosSpacing.s4),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line),
      ),
      child: child,
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({
    required this.text,
    required this.draft,
    required this.onKind,
    required this.onRemove,
  });

  final AppStrings text;
  final _PresetDraft draft;
  final ValueChanged<bool> onKind;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(PosSpacing.s12, PosSpacing.s10, PosSpacing.s8, PosSpacing.s10),
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: TextField(
              controller: draft.label,
              decoration: InputDecoration(
                hintText: text.presetLabelHint,
                isDense: true,
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: PosFont.f14,
                fontWeight: FontWeight.w600,
                color: PosColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: PosSpacing.s8),
          _KindToggle(text: text, percent: draft.percent, onChanged: onKind),
          const SizedBox(width: PosSpacing.s8),
          SizedBox(
            width: 58,
            child: TextField(
              controller: draft.value,
              textAlign: TextAlign.right,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
              ],
              decoration: const InputDecoration(
                hintText: '0',
                isDense: true,
                border: InputBorder.none,
              ),
              style: const TextStyle(
                fontSize: PosFont.f14_5,
                fontWeight: FontWeight.w700,
                color: PosColors.primaryDark,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            color: PosColors.muted,
            onPressed: onRemove,
            tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          ),
        ],
      ),
    );
  }
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({
    required this.text,
    required this.percent,
    required this.onChanged,
  });

  final AppStrings text;
  final bool percent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool isPct) {
      final on = isPct == percent;
      return GestureDetector(
        onTap: () => onChanged(isPct),
        child: Container(
          width: 30,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? PosColors.primaryDark : Colors.transparent,
            borderRadius: BorderRadius.circular(PosRadii.md),
          ),
          child: TfText(
            label,
            style: TextStyle(
              fontSize: PosFont.f13,
              fontWeight: FontWeight.w700,
              color: on ? PosColors.onInk : PosColors.muted,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(PosSpacing.s2),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.lg),
        border: Border.all(color: PosColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg(text.presetPercent, true), seg(text.presetFlat, false)],
      ),
    );
  }
}

class _AddPresetButton extends StatelessWidget {
  const _AddPresetButton({required this.text, required this.onPressed});

  final AppStrings text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(PosRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: PosSpacing.s12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PosRadii.md),
          border: Border.all(color: PosColors.lineStrong),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_rounded,
              size: 18,
              color: PosColors.accentStrong,
            ),
            const SizedBox(width: PosSpacing.s8),
            TfText(
              text.addDiscountPreset,
              style: const TextStyle(
                fontSize: PosFont.f14,
                fontWeight: FontWeight.w600,
                color: PosColors.accentStrong,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
