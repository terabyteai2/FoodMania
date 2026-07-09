import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'desk_theme.dart';

/// Shared visual vocabulary for the desktop design reset
/// (DESIGN_RESET_REFERENCE.md). Screens compose these instead of re-deriving
/// card decorations or hand-rolling charts, so the surfaces read as one system:
/// soft rounded cards, tinted stat tiles, a pill segmented control, and
/// dataviz-compliant chart primitives (fixed-order categorical hues from
/// [DeskChart], thin marks, rounded data-ends, a legend for ≥2 series).

/// The soft rounded-card surface used by every reset panel.
BoxDecoration deskCardDecoration({double? radius}) => BoxDecoration(
      color: PosColors.surface,
      borderRadius: BorderRadius.circular(radius ?? DeskMetrics.cardRadius),
      border: Border.all(color: PosColors.line),
      boxShadow: PosShadows.soft,
    );

/// A titled soft card. [trailing] sits opposite the title (e.g. a control).
class DeskCard extends StatelessWidget {
  const DeskCard({
    required this.child,
    this.title,
    this.trailing,
    this.width,
    this.padding,
    super.key,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final double? width;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding ?? const EdgeInsets.all(DeskMetrics.cardPad),
      decoration: deskCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// A KPI tile: a tinted icon chip over a big value + label. [accent] recolors
/// the icon chip and value (defaults to primary blue).
class DeskStatTile extends StatelessWidget {
  const DeskStatTile({
    required this.label,
    required this.value,
    this.icon,
    this.accent,
    this.tint,
    this.width = 200,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? accent;
  final Color? tint;
  final double width;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? PosColors.primary;
    return Container(
      width: width,
      padding: const EdgeInsets.all(DeskMetrics.cardPad),
      decoration: deskCardDecoration(radius: DeskMetrics.tileRadius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tint ?? PosColors.primarySoft,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: PosColors.primaryDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12.5, color: PosColors.muted)),
        ],
      ),
    );
  }
}

/// A pill segmented control (range picker, tab strip). Selected = primary fill.
class DeskSegment<T> extends StatelessWidget {
  const DeskSegment({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<(T value, String label)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: PosColors.surfaceSunk,
        borderRadius: BorderRadius.circular(PosRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (v, label) in options)
            GestureDetector(
              onTap: () => onChanged(v),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: v == value ? PosColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(PosRadii.pill),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: v == value ? Colors.white : PosColors.ink2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One categorical datum for the chart primitives. Colour is assigned by the
/// chart from [DeskChart] in fixed order — never carried on the datum — so a
/// filtered series never repaints survivors. [valueLabel] is pre-formatted
/// (e.g. ৳ money) to keep these widgets format-agnostic.
class DeskDatum {
  const DeskDatum(this.label, this.value, this.valueLabel);
  final String label;
  final double value;
  final String valueLabel;
}

/// Donut split with a centered total and a labelled legend (identity is never
/// colour-alone — every slice is named + valued in the legend).
class DeskDonut extends StatelessWidget {
  const DeskDonut({
    required this.data,
    required this.centerValue,
    required this.centerLabel,
    this.size = 132,
    this.stroke = 20,
    super.key,
  });

  final List<DeskDatum> data;
  final String centerValue;
  final String centerLabel;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _DonutPainter(
              [for (final d in data) d.value],
              [for (var i = 0; i < data.length; i++) DeskChart.hue(i)],
              stroke,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerValue,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    centerLabel,
                    style: TextStyle(fontSize: 11, color: PosColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < data.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: DeskChart.hue(i),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          data[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: PosColors.ink2),
                        ),
                      ),
                      Text(
                        data[i].valueLabel,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.colors, this.stroke);
  final List<double> values;
  final List<Color> colors;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final radius = rect.width / 2;

    // Recessive background track.
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = PosColors.surfaceSunk,
    );
    if (total <= 0) return;

    // 2px surface gap between adjacent segments (mark spec).
    final gap = values.length > 1 ? (2 / radius) : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      final drawn = sweep - gap;
      if (drawn > 0) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          drawn,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.butt
            ..color = colors[i],
        );
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values != values || old.colors != colors || old.stroke != stroke;
}

/// Horizontal labelled bars (magnitude by category). Rounded data-ends, a
/// recessive track, direct value labels; hue by fixed categorical order.
class DeskBars extends StatelessWidget {
  const DeskBars({
    required this.data,
    this.labelWidth = 116,
    this.barHeight = 10,
    super.key,
  });

  final List<DeskDatum> data;
  final double labelWidth;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final maxV = data.fold<double>(
        0, (m, d) => math.max(m, d.value.abs()));
    return Column(
      children: [
        for (var i = 0; i < data.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    data[i].label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: PosColors.ink2),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final frac = maxV <= 0 ? 0.0 : data[i].value.abs() / maxV;
                      return Stack(
                        children: [
                          Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: PosColors.surfaceSunk,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Container(
                            height: barHeight,
                            width: (c.maxWidth * frac).clamp(
                                frac > 0 ? 4.0 : 0.0, c.maxWidth),
                            decoration: BoxDecoration(
                              color: DeskChart.hue(i),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 76,
                  child: Text(
                    data[i].valueLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A single-series area+line trend (change over time). One hue (primary), 2px
/// line, recessive gridlines, a marker on the latest point — no legend (the
/// card title names the series).
class DeskTrendChart extends StatelessWidget {
  const DeskTrendChart({
    required this.values,
    this.height = 150,
    super.key,
  });

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrendPainter(values),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    // Recessive gridlines.
    final grid = Paint()
      ..color = DeskChart.grid
      ..strokeWidth = 1;
    for (final f in const [0.0, 0.5, 1.0]) {
      final y = size.height * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) return;

    final maxV = values.fold<double>(0, (m, v) => math.max(m, v));
    final n = values.length;
    double px(int i) => n == 1 ? size.width / 2 : (i / (n - 1)) * size.width;
    double py(double v) =>
        maxV <= 0 ? size.height : size.height - (v / maxV) * (size.height - 6);

    final line = Path();
    final area = Path();
    for (var i = 0; i < n; i++) {
      final p = Offset(px(i), py(values[i]));
      if (i == 0) {
        line.moveTo(p.dx, p.dy);
        area
          ..moveTo(p.dx, size.height)
          ..lineTo(p.dx, p.dy);
      } else {
        line.lineTo(p.dx, p.dy);
        area.lineTo(p.dx, p.dy);
      }
    }
    area
      ..lineTo(px(n - 1), size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            PosColors.primary.withValues(alpha: 0.18),
            PosColors.primary.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = PosColors.primary
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Marker on the latest point (≥8px), ringed with the surface.
    final last = Offset(px(n - 1), py(values.last));
    canvas.drawCircle(last, 4, Paint()..color = PosColors.primary);
    canvas.drawCircle(
      last,
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = PosColors.surface,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.values != values;
}
