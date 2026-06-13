// QuickBytes Desktop — shared kit: token aliases (bytes-tokens.css → PosColors),
// money/number helpers, channel + category visual maps, and the reusable
// primitives faithful to `desktop.css` (.field, .chip, .dk-seg, .toggle, .badge,
// .dk-xbtn, .dk-kpi, .qty, .btn). Built once, used by every desktop screen.

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import 'dk_icons.dart';

/// Token aliases mapping `bytes-tokens.css` variables onto the existing lime
/// [PosColors]. Keeps every widget reading from one source of truth.
class Dk {
  Dk._();

  static const Color accent = PosColors.primary; // --accent #99FF47
  static const Color accentPress = PosColors.primaryDeep; // --accent-press #84F02C
  static const Color accentStrong = PosColors.accentStrong; // --accent-strong #3E7E14
  static const Color accentInk = PosColors.accentInk; // --accent-ink #14180E
  static const Color accentTint = PosColors.primarySoft; // --accent-tint #F0FADF
  static const Color accentTint2 = PosColors.primaryWash; // --accent-tint-2 #D8F3AD

  static const Color bg = PosColors.background; // #F7F8F4
  static const Color surface = PosColors.surface; // #FFFFFF
  static const Color surface2 = PosColors.surfaceSunk; // #F2F3EE
  static const Color surface3 = PosColors.surface3; // #E9EBE3
  static const Color ink = PosColors.primaryDark; // #1A1E14
  static const Color ink2 = PosColors.inkSoft; // #565B4C
  static const Color muted = PosColors.muted; // #878C79
  static const Color placeholder = PosColors.mutedSoft; // #AEB2A2
  static const Color line = PosColors.line; // #EDEEE8
  static const Color line2 = PosColors.lineStrong; // #E0E2D8

  static const Color success = PosColors.success; // #498F18
  static const Color successSoft = PosColors.successSoft; // #E4FBC9
  static const Color warning = PosColors.warning; // #B0760A
  static const Color warningSoft = PosColors.warningSoft; // #FBEFCD
  static const Color danger = PosColors.danger; // #D43A3F
  static const Color dangerSoft = PosColors.dangerSoft; // #FBE3E2
  static const Color info = PosColors.info; // #3E6FE0
  static const Color infoSoft = PosColors.infoSoft; // #E3EAFC

  static const Color seatTint = PosColors.seatTint; // #EDF1F7
  static const Color seatLine = PosColors.seatLine; // #D5DEEC
  static const Color seatInk = PosColors.seatInk; // #4C679C

  // Radii (PosRadii mirror): xs3 sm5 md7 lg9 xl12 pill999.
  static const double rXs = PosRadii.xs;
  static const double rSm = PosRadii.sm;
  static const double rMd = PosRadii.md;
  static const double rLg = PosRadii.lg;
  static const double rXl = PosRadii.xl;
  static const double rPill = PosRadii.pill;

  // Elevation tokens.
  static const List<BoxShadow> e3 = [
    BoxShadow(color: Color(0x4D14180E), blurRadius: 44, spreadRadius: -12, offset: Offset(0, 18)),
    BoxShadow(color: Color(0x1A14180E), blurRadius: 12, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> eUp = [
    BoxShadow(color: Color(0x0D14180E), blurRadius: 16, offset: Offset(0, -4)),
  ];

  static const String fontFamily = 'Inter';
  static const List<String> fontFallback = ['Noto Sans Bengali', 'Hind Siliguri'];
}

const String kTk = '৳'; // ৳

/// Money like the jsx `money()` — `৳1,551`, en-US grouping, rounded integer.
String dkMoney(num n) {
  final neg = n < 0;
  final v = n.abs().round();
  final s = v.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '${neg ? '-' : ''}$kTk$buf';
}

/// Tabular-figure text style on Inter (money/qty), with Bengali fallback.
TextStyle dkNum(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = Dk.ink,
  double letterSpacing = 0,
  double? height,
}) =>
    TextStyle(
      fontFamily: Dk.fontFamily,
      fontFamilyFallback: Dk.fontFallback,
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

/// Plain text style on Inter (labels/titles), with Bengali fallback.
TextStyle dkText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = Dk.ink,
  double letterSpacing = 0,
  double? height,
}) =>
    TextStyle(
      fontFamily: Dk.fontFamily,
      fontFamilyFallback: Dk.fontFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

// ── Channel + category visual maps (bytes-shared.jsx CHANNELS / CAT_TINT) ────

class DkChannelMeta {
  const DkChannelMeta(this.icon, this.en, this.bn, this.color);
  final String icon;
  final String en;
  final String bn;
  final Color color;
}

const Map<String, DkChannelMeta> kDkChannels = {
  'storefront': DkChannelMeta('globe', 'Website', 'ওয়েবসাইট', Color(0xFF3E6FE0)),
  'chatbot': DkChannelMeta('chat', 'Messenger', 'মেসেঞ্জার', Color(0xFF3E6FE0)),
  'waiter': DkChannelMeta('users', 'Waiter', 'ওয়েটার', Color(0xFF7C8270)),
  'qr': DkChannelMeta('qr', 'Table QR', 'টেবিল QR', Color(0xFFB0760A)),
  'counter': DkChannelMeta('store', 'Counter', 'কাউন্টার', Color(0xFF498F18)),
  'manager': DkChannelMeta('user', 'Manager', 'ম্যানেজার', Color(0xFF14180E)),
};

DkChannelMeta dkChannel(String? key) => kDkChannels[key] ?? kDkChannels['counter']!;

class DkCatTint {
  const DkCatTint(this.bg, this.fg, this.icon);
  final Color bg;
  final Color fg;
  final String icon;
}

const Map<String, DkCatTint> kDkCatTint = {
  'Burgers': DkCatTint(Color(0xFFFBEFCD), Color(0xFFB0760A), 'burger'),
  'Pizza': DkCatTint(Color(0xFFFBE3E2), Color(0xFFD43A3F), 'pizza'),
  'Rice & Curry': DkCatTint(Color(0xFFE4FBC9), Color(0xFF498F18), 'rice'),
  'Kebab': DkCatTint(Color(0xFFFBE3E2), Color(0xFFB0760A), 'kebab'),
  'Sides': DkCatTint(Color(0xFFE3EAFC), Color(0xFF3E6FE0), 'fries'),
  'Salads': DkCatTint(Color(0xFFE4FBC9), Color(0xFF498F18), 'salad'),
  'Beverages': DkCatTint(Color(0xFFE3EAFC), Color(0xFF3E6FE0), 'drink'),
  'Desserts': DkCatTint(Color(0xFFFBEFCD), Color(0xFFB0760A), 'dessert'),
};

DkCatTint dkCatTint(String? cat) =>
    kDkCatTint[cat] ?? const DkCatTint(Color(0xFFECEFE4), Color(0xFF7C8270), 'bag');

// ── Reusable primitives ─────────────────────────────────────────────────────

/// `.field` — search / text input row with focus ring (`min-width:0` safe).
class DkField extends StatefulWidget {
  const DkField({
    this.controller,
    this.icon = 'search',
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.width,
    this.expand = true,
    this.keyboardType,
    this.showClear = false,
    super.key,
  });

  final TextEditingController? controller;
  final String? icon;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double? width;
  final bool expand;
  final TextInputType? keyboardType;
  final bool showClear;

  @override
  State<DkField> createState() => _DkFieldState();
}

class _DkFieldState extends State<DkField> {
  final FocusNode _node = FocusNode();
  late final TextEditingController _own = widget.controller ?? TextEditingController();

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _node.dispose();
    if (widget.controller == null) _own.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _node.hasFocus;
    final field = Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Dk.surface,
        borderRadius: BorderRadius.circular(Dk.rMd),
        border: Border.all(color: focused ? Dk.accentPress : Dk.line2),
        boxShadow: focused ? const [BoxShadow(color: Dk.accentTint, blurRadius: 0, spreadRadius: 3)] : null,
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            DkIcon(widget.icon!, size: 18, color: Dk.muted),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: _own,
              focusNode: _node,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              keyboardType: widget.keyboardType,
              style: dkText(15, color: Dk.ink),
              cursorColor: Dk.accentStrong,
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.placeholder,
                hintStyle: dkText(15, color: Dk.placeholder),
              ),
            ),
          ),
          if (widget.showClear && _own.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _own.clear();
                widget.onChanged?.call('');
              },
              child: const DkIcon('x', size: 15, color: Dk.muted),
            ),
        ],
      ),
    );
    if (widget.width != null) return SizedBox(width: widget.width, child: field);
    return widget.expand ? field : IntrinsicWidth(child: field);
  }
}

enum DkBtnVariant { primary, ghost, soft, dark, danger }

enum DkBtnSize { md, lg, sm }

/// `.btn` — primary lime / ghost / soft(accent-wash) / dark / danger.
class DkButton extends StatelessWidget {
  const DkButton({
    required this.label,
    this.onTap,
    this.icon,
    this.variant = DkBtnVariant.primary,
    this.size = DkBtnSize.md,
    this.expand = false,
    this.dangerText = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final String? icon;
  final DkBtnVariant variant;
  final DkBtnSize size;
  final bool expand;
  final bool dangerText;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final h = switch (size) { DkBtnSize.lg => 52.0, DkBtnSize.sm => 38.0, _ => 44.0 };
    final fs = switch (size) { DkBtnSize.lg => 16.0, DkBtnSize.sm => 13.5, _ => 15.0 };
    late Color bg, fg;
    Border? border;
    switch (variant) {
      case DkBtnVariant.primary:
        bg = Dk.accent;
        fg = Dk.accentInk;
        break;
      case DkBtnVariant.ghost:
        bg = Dk.surface;
        fg = dangerText ? Dk.danger : Dk.ink;
        border = Border.all(color: Dk.line2);
        break;
      case DkBtnVariant.soft:
        bg = Dk.accentTint;
        fg = Dk.accentStrong;
        break;
      case DkBtnVariant.dark:
        bg = Dk.ink;
        fg = Colors.white;
        break;
      case DkBtnVariant.danger:
        bg = Dk.dangerSoft;
        fg = Dk.danger;
        break;
    }
    final child = Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: size == DkBtnSize.sm ? 13 : 18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Dk.rMd),
        border: border,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            DkIcon(icon!, size: fs + 2, color: fg),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dkText(fs, weight: FontWeight.w600, color: fg),
            ),
          ),
        ],
      ),
    );
    return Opacity(
      opacity: disabled ? 0.42 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
          child: expand ? SizedBox(width: double.infinity, child: child) : child,
        ),
      ),
    );
  }
}

/// `.chip` — h36, active = lime+ink; `tint` active = accent-wash + accent-strong.
class DkChip extends StatelessWidget {
  const DkChip({
    required this.label,
    this.onTap,
    this.active = false,
    this.tint = false,
    this.height = 36,
    this.trailing,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool tint;
  final double height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    late Color bg, fg, border;
    if (active && tint) {
      bg = Dk.accentTint;
      fg = Dk.accentStrong;
      border = Dk.accentTint2;
    } else if (active) {
      bg = Dk.accent;
      fg = Dk.accentInk;
      border = Dk.accent;
    } else {
      bg = Dk.surface;
      fg = Dk.ink2;
      border = Dk.line2;
    }
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: height,
          padding: EdgeInsets.symmetric(horizontal: height >= 40 ? 16 : 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(Dk.rSm),
            border: Border.all(color: border),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: dkText(14, weight: active ? FontWeight.w600 : FontWeight.w500, color: fg)),
              if (trailing != null) ...[const SizedBox(width: 7), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// `.dk-seg` — desktop segmented control (active tab = white surface).
class DkSeg extends StatelessWidget {
  const DkSeg({required this.items, required this.selected, required this.onSelect, super.key});

  /// (id, label, optional icon, optional trailing widget).
  final List<DkSegItem> items;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Dk.surface2,
        borderRadius: BorderRadius.circular(Dk.rMd),
        border: Border.all(color: Dk.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final it in items)
            Padding(
              padding: EdgeInsets.only(right: it == items.last ? 0 : 4),
              child: _segBtn(it),
            ),
        ],
      ),
    );
  }

  Widget _segBtn(DkSegItem it) {
    final on = it.id == selected;
    return GestureDetector(
      onTap: () => onSelect(it.id),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: on ? Dk.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(Dk.rSm),
            boxShadow: on ? const [BoxShadow(color: Color(0x1214181E), blurRadius: 2, offset: Offset(0, 1))] : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (it.icon != null) ...[
                DkIcon(it.icon!, size: 17, color: on ? Dk.ink : Dk.muted),
                const SizedBox(width: 7),
              ],
              Text(it.label, style: dkText(14, weight: FontWeight.w600, color: on ? Dk.ink : Dk.muted)),
              if (it.trailing != null) ...[const SizedBox(width: 4), it.trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

class DkSegItem {
  const DkSegItem(this.id, this.label, {this.icon, this.trailing});
  final String id;
  final String label;
  final String? icon;
  final Widget? trailing;
}

/// `.toggle` — the only round control. On = lime.
class DkToggle extends StatelessWidget {
  const DkToggle({required this.on, this.onChanged, this.width = 46, this.height = 26, super.key});

  final bool on;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final knob = height - 6;
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!on),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: on ? Dk.accent : Dk.line2,
            borderRadius: BorderRadius.circular(Dk.rPill),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 150),
                top: 3,
                left: on ? width - knob - 3 : 3,
                child: Container(
                  width: knob,
                  height: knob,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x40000000), blurRadius: 2, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Minimal "Advanced" inline toggle (label + small switch) — Stock/Analytics.
class DkAdvToggle extends StatelessWidget {
  const DkAdvToggle({required this.on, required this.onChanged, this.label = 'Advanced', super.key});

  final bool on;
  final ValueChanged<bool> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 38,
          padding: const EdgeInsets.only(left: 14, right: 8),
          decoration: BoxDecoration(
            color: on ? Dk.accentTint : Dk.surface,
            borderRadius: BorderRadius.circular(Dk.rMd),
            border: Border.all(color: on ? Dk.accentTint2 : Dk.line2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: dkText(13, weight: FontWeight.w700, color: on ? Dk.accentStrong : Dk.ink2)),
              const SizedBox(width: 9),
              DkToggle(on: on, onChanged: onChanged, width: 40, height: 23),
            ],
          ),
        ),
      ),
    );
  }
}

enum DkBadgeVariant { accent, ink, success, warning, danger, info, neutral, tint }

/// `.badge` — radius xs, 12/600.
class DkBadge extends StatelessWidget {
  const DkBadge({required this.label, this.variant = DkBadgeVariant.neutral, this.icon, this.height = 22, super.key});

  final String label;
  final DkBadgeVariant variant;
  final String? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    late Color bg, fg;
    switch (variant) {
      case DkBadgeVariant.accent:
        bg = Dk.accent;
        fg = Dk.accentInk;
        break;
      case DkBadgeVariant.ink:
        bg = Dk.ink;
        fg = Colors.white;
        break;
      case DkBadgeVariant.success:
        bg = Dk.successSoft;
        fg = Dk.success;
        break;
      case DkBadgeVariant.warning:
        bg = Dk.warningSoft;
        fg = Dk.warning;
        break;
      case DkBadgeVariant.danger:
        bg = Dk.dangerSoft;
        fg = Dk.danger;
        break;
      case DkBadgeVariant.info:
        bg = Dk.infoSoft;
        fg = Dk.info;
        break;
      case DkBadgeVariant.tint:
        bg = Dk.accentTint;
        fg = Dk.accentStrong;
        break;
      case DkBadgeVariant.neutral:
        bg = Dk.surface2;
        fg = Dk.ink2;
        break;
    }
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Dk.rXs)),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[DkIcon(icon!, size: 12, color: fg), const SizedBox(width: 5)],
          Text(label, style: dkText(12, weight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }
}

/// `.dk-xbtn` — small square destructive-on-hover button.
class DkXBtn extends StatefulWidget {
  const DkXBtn({required this.icon, this.onTap, this.size = 26, this.tooltip, super.key});

  final String icon;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;

  @override
  State<DkXBtn> createState() => _DkXBtnState();
}

class _DkXBtnState extends State<DkXBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final btn = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: _hover ? Dk.dangerSoft : Dk.surface,
            borderRadius: BorderRadius.circular(Dk.rSm),
            border: Border.all(color: _hover ? Dk.dangerSoft : Dk.line2),
          ),
          child: Center(child: DkIcon(widget.icon, size: widget.size * 0.54, color: _hover ? Dk.danger : Dk.muted)),
        ),
      ),
    );
    return widget.tooltip != null ? Tooltip(message: widget.tooltip!, child: btn) : btn;
  }
}

/// `.dk-kpi` — labelled KPI card.
class DkKpi extends StatelessWidget {
  const DkKpi({required this.label, required this.value, this.valueColor, super.key});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Dk.surface,
        borderRadius: BorderRadius.circular(Dk.rLg),
        border: Border.all(color: Dk.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: dkText(12.5, weight: FontWeight.w600, color: Dk.muted)),
          const SizedBox(height: 4),
          Text(value, style: dkNum(26, weight: FontWeight.w700, color: valueColor ?? Dk.ink, letterSpacing: -0.4)),
        ],
      ),
    );
  }
}

/// `.qty` — stepper pill.
class DkQty extends StatelessWidget {
  const DkQty({required this.value, required this.onChanged, this.min = 1, this.scale = 1, super.key});

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final double scale;

  @override
  Widget build(BuildContext context) {
    Widget btn(String icon, VoidCallback onTap) => GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 32 * scale,
              height: 32 * scale,
              decoration: BoxDecoration(
                color: Dk.surface,
                borderRadius: BorderRadius.circular(Dk.rSm),
                border: Border.all(color: Dk.line2),
              ),
              child: Center(child: DkIcon(icon, size: 16 * scale, color: Dk.ink)),
            ),
          ),
        );
    return Container(
      padding: EdgeInsets.all(3 * scale),
      decoration: BoxDecoration(color: Dk.surface2, borderRadius: BorderRadius.circular(Dk.rMd)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn('minus', () => onChanged(value - 1 < min ? min : value - 1)),
          SizedBox(
            width: 30 * scale,
            child: Text('$value', textAlign: TextAlign.center, style: dkNum(14 * scale, weight: FontWeight.w700)),
          ),
          btn('plus', () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

/// `.status` — coloured dot + label (ok/low/no).
class DkStatusText extends StatelessWidget {
  const DkStatusText({required this.kind, required this.label, super.key});

  final String kind; // ok | low | no
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = kind == 'ok' ? Dk.success : kind == 'low' ? Dk.warning : Dk.danger;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: dkText(13, weight: FontWeight.w500, color: color)),
      ],
    );
  }
}

/// `.card` — flat surface + hairline border.
class DkCard extends StatelessWidget {
  const DkCard({required this.child, this.padding, this.color, this.borderColor, super.key});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Dk.surface,
        borderRadius: BorderRadius.circular(Dk.rLg),
        border: Border.all(color: borderColor ?? Dk.line),
      ),
      child: child,
    );
  }
}

/// Eyebrow label (11/700, 0.05em upper, muted).
Text dkEyebrow(String text, {Color color = Dk.muted}) =>
    Text(text.toUpperCase(), style: dkText(11, weight: FontWeight.w700, color: color, letterSpacing: 0.55));
