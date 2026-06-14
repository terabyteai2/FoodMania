import 'package:flutter/material.dart';

import 'pc_theme.dart';

/// Lucide-equivalent icon resolver. The JSX `NavIcon kind="..."` maps onto the
/// Material outlined set already shipped with the app.
IconData pcIconData(String kind) => switch (kind) {
  'counter' || 'shop' => Icons.point_of_sale_outlined,
  'people' => Icons.groups_outlined,
  'orders' => Icons.receipt_long_outlined,
  'menu' => Icons.restaurant_menu_outlined,
  'inventory' => Icons.inventory_2_outlined,
  'chart' => Icons.bar_chart_outlined,
  'bell' => Icons.notifications_outlined,
  'settings' => Icons.settings_outlined,
  'search' => Icons.search,
  'printer' => Icons.print_outlined,
  'upload' => Icons.upload_file_outlined,
  'wifi' => Icons.wifi,
  'cloud' => Icons.cloud_done_outlined,
  'cloudOff' => Icons.cloud_off_outlined,
  'clock' => Icons.schedule,
  'drawer' => Icons.savings_outlined,
  'plus' => Icons.add,
  'minus' => Icons.remove,
  'close' => Icons.close,
  'check' => Icons.check,
  'back' => Icons.arrow_back,
  'kitchen' => Icons.soup_kitchen_outlined,
  'split' => Icons.call_split,
  'edit' => Icons.edit_outlined,
  'swap' => Icons.swap_horiz,
  'table' => Icons.table_restaurant_outlined,
  _ => Icons.circle_outlined,
};

class PcIcon extends StatelessWidget {
  const PcIcon(this.kind, {this.size = 18, this.color, super.key});
  final String kind;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      Icon(pcIconData(kind), size: size, color: color ?? Pc.textSec);
}

enum PcVariant { primary, dark, ghost, surface, good, danger }

enum PcSize { sm, md, lg, xl }

class PcBtn extends StatelessWidget {
  const PcBtn({
    required this.label,
    this.onTap,
    this.variant = PcVariant.primary,
    this.size = PcSize.md,
    this.icon,
    this.sk,
    this.full = false,
    super.key,
  });

  final String label;
  final VoidCallback? onTap;
  final PcVariant variant;
  final PcSize size;
  final String? icon;
  final String? sk; // keyboard shortcut hint
  final bool full;

  @override
  Widget build(BuildContext context) {
    final (h, fs, px, r) = switch (size) {
      PcSize.sm => (28.0, 12.0, 10.0, 6.0),
      PcSize.md => (36.0, 13.0, 14.0, 7.0),
      PcSize.lg => (44.0, 14.5, 18.0, 8.0),
      PcSize.xl => (56.0, 16.0, 22.0, 10.0),
    };
    final (bg, fg, bd) = switch (variant) {
      PcVariant.primary => (Pc.accent, Pc.accentInk, Pc.accent),
      PcVariant.dark => (Pc.ink, Pc.onInk, Pc.ink),
      PcVariant.ghost => (Colors.transparent, Pc.text, Pc.borderStrong),
      PcVariant.surface => (Pc.surface, Pc.text, Pc.border),
      PcVariant.good => (Pc.good, Colors.white, Pc.good),
      PcVariant.danger => (Pc.danger, Colors.white, Pc.danger),
    };
    final onDark =
        variant == PcVariant.primary ||
        variant == PcVariant.dark ||
        variant == PcVariant.good ||
        variant == PcVariant.danger;
    final disabled = onTap == null;
    final child = Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        height: h,
        width: full ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: px),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: bd),
          borderRadius: BorderRadius.circular(r),
        ),
        child: Row(
          mainAxisSize: full ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              PcIcon(icon!, size: fs + 4, color: fg),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: fs,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            if (sk != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: onDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Pc.surfaceAlt,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  sk!,
                  style: Pc.mono(
                    10,
                    color: onDark
                        ? Colors.white.withValues(alpha: 0.95)
                        : Pc.textSec,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    return _Hoverable(onTap: onTap, borderRadius: r, child: child);
  }
}

/// Adds a pointer cursor + subtle hover tint per the desktop layout adapter.
class _Hoverable extends StatefulWidget {
  const _Hoverable({
    required this.child,
    required this.borderRadius,
    this.onTap,
  });
  final Widget child;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.child,
      ),
    );
  }
}

class PcCard extends StatelessWidget {
  const PcCard({required this.child, this.pad = 16, this.color, super.key});
  final Widget child;
  final double pad;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(pad),
    decoration: BoxDecoration(
      color: color ?? Pc.surface,
      border: Border.all(color: Pc.border),
      borderRadius: BorderRadius.circular(Pc.rMd),
      boxShadow: Pc.shadowSoft,
    ),
    child: child,
  );
}

class PcEyebrow extends StatelessWidget {
  const PcEyebrow(this.text, {this.color, super.key});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Pc.mono(10.5, color: color ?? Pc.textSec, letterSpacing: 0.7),
  );
}

class PcSectionHead extends StatelessWidget {
  const PcSectionHead({required this.title, this.sub, this.right, super.key});
  final String title;
  final String? sub;
  final Widget? right;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Pc.text,
                  letterSpacing: -0.2,
                ),
              ),
              if (sub != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    sub!,
                    style: const TextStyle(fontSize: 11.5, color: Pc.textSec),
                  ),
                ),
            ],
          ),
        ),
        ?right,
      ],
    ),
  );
}

enum PcTone { good, warn, bad, muted, accent }

class PcPill extends StatelessWidget {
  const PcPill({
    required this.label,
    this.tone = PcTone.muted,
    this.dot = false,
    this.icon,
    super.key,
  });
  final String label;
  final PcTone tone;
  final bool dot;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, dotc) = switch (tone) {
      PcTone.good => (Pc.goodSoft, Pc.good, Pc.good),
      PcTone.warn => (Pc.warnSoft, Pc.warn, Pc.warn),
      PcTone.bad => (Pc.dangerSoft, Pc.danger, Pc.danger),
      PcTone.muted => (Pc.surfaceAlt, Pc.text, Pc.textTer),
      PcTone.accent => (Pc.accentSoft, Pc.accent, Pc.accent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Pc.rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dotc, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          if (icon != null) ...[
            PcIcon(icon!, size: 13, color: fg),
            const SizedBox(width: 6),
          ],
          Text(label, style: Pc.mono(11.5, color: fg, letterSpacing: 0.1)),
        ],
      ),
    );
  }
}

class PcQtyStep extends StatelessWidget {
  const PcQtyStep({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
    super.key,
  });
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    decoration: BoxDecoration(
      color: Pc.surface,
      border: Border.all(color: Pc.border),
      borderRadius: BorderRadius.circular(Pc.rXs),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _step(Icons.remove, onMinus),
        Container(
          constraints: const BoxConstraints(minWidth: 26),
          alignment: Alignment.center,
          child: Text('$qty', style: Pc.num(12)),
        ),
        _step(Icons.add, onPlus),
      ],
    ),
  );

  Widget _step(IconData icon, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: SizedBox(
      width: 24,
      height: 26,
      child: Icon(icon, size: 15, color: Pc.textSec),
    ),
  );
}

/// KPI tile used on day-open / analytics. Hero numeric anchors the card.
class PcKpi extends StatelessWidget {
  const PcKpi({
    required this.label,
    required this.value,
    this.sub,
    this.delta,
    this.deltaUp = false,
    this.tone,
    super.key,
  });
  final String label;
  final String value;
  final String? sub;
  final String? delta;
  final bool deltaUp;
  final Color? tone;

  @override
  Widget build(BuildContext context) => PcCard(
    pad: 14,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: PcEyebrow(label)),
            if (delta != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: deltaUp ? Pc.goodSoft : Pc.dangerSoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${deltaUp ? '▲' : '▼'} ${delta!}',
                  style: Pc.num(11, color: deltaUp ? Pc.good : Pc.danger),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          value,
          style: Pc.num(
            30,
            color: tone ?? Pc.ink,
            letterSpacing: -0.5,
            height: 1,
          ),
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              sub!,
              style: Pc.num(11.5, weight: FontWeight.w400, color: Pc.textSec),
            ),
          ),
      ],
    ),
  );
}
