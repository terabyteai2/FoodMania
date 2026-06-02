import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pc_theme.dart';

/// Tiny sparkline (CustomPaint). `points` are 0..1 fractions.
class PcSpark extends StatelessWidget {
  const PcSpark({
    required this.points,
    this.height = 40,
    this.color,
    this.fill = false,
    super.key,
  });
  final List<double> points;
  final double height;
  final Color? color;
  final bool fill;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _SparkPainter(points, color ?? Pc.accent, fill),
        ),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.points, this.color, this.fill);
  final List<double> points;
  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    const padY = 4.0;
    final innerH = size.height - padY * 2;
    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = dx * i;
      final y = padY + innerH - points[i].clamp(0, 1) * innerH;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = dx * (i - 1);
        final cx = px + dx / 2;
        final py = padY +
            innerH - points[i - 1].clamp(0, 1) * innerH;
        path.cubicTo(cx, py, cx, y, x, y);
      }
    }
    if (fill) {
      final area = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: 0.10));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    final last = Offset(
      size.width,
      padY + innerH - points.last.clamp(0, 1) * innerH,
    );
    canvas.drawCircle(last, 3, Paint()..color = Pc.surface);
    canvas.drawCircle(
      last,
      3,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.points != points || old.color != color || old.fill != fill;
}

/// One bar: today [value] with optional comparison [vs] band behind it.
class PcBar {
  const PcBar(this.label, this.value, {this.vs});
  final String label;
  final double value;
  final double? vs;
}

/// Grouped hourly bar chart (today vs comparison band). Peak bar paints in ink.
class PcBarChart extends StatelessWidget {
  const PcBarChart({
    required this.bars,
    this.height = 220,
    this.accent,
    this.peakIndex,
    this.peakLabel,
    this.yAxis,
    super.key,
  });
  final List<PcBar> bars;
  final double height;
  final Color? accent;
  final int? peakIndex;
  final String? peakLabel;
  final String Function(double)? yAxis;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BarPainter(
            bars: bars,
            accent: accent ?? Pc.accent,
            peakIndex: peakIndex,
            peakLabel: peakLabel,
            yAxis: yAxis,
          ),
        ),
      );
}

class _BarPainter extends CustomPainter {
  _BarPainter({
    required this.bars,
    required this.accent,
    this.peakIndex,
    this.peakLabel,
    this.yAxis,
  });
  final List<PcBar> bars;
  final Color accent;
  final int? peakIndex;
  final String? peakLabel;
  final String Function(double)? yAxis;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    const padL = 44.0, padR = 12.0, padT = 14.0, padB = 26.0;
    final innerW = size.width - padL - padR;
    final innerH = size.height - padT - padB;
    final maxV = math.max(
      1.0,
      bars
              .map((b) => math.max(b.value, b.vs ?? 0))
              .fold<double>(0, math.max) *
          1.1,
    );
    const ticks = 4;
    final grid = Paint()
      ..color = Pc.border
      ..strokeWidth = 1;
    final label = Paint();
    label.isAntiAlias = true;
    // y grid + labels
    for (var i = 0; i <= ticks; i++) {
      final y = padT + innerH * i / ticks;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), grid);
      if (yAxis != null) {
        final value = maxV * (1 - i / ticks);
        _text(canvas, yAxis!(value), Offset(padL - 6, y),
            align: TextAlign.right, color: Pc.textTer, mono: true, size: 10);
      }
    }
    final slot = innerW / bars.length;
    final barW = slot * 0.55;
    for (var i = 0; i < bars.length; i++) {
      final cx = padL + slot * i + slot / 2;
      final b = bars[i];
      // comparison band
      if (b.vs != null && b.vs! > 0) {
        final vsH = b.vs! / maxV * innerH;
        final rect = Rect.fromLTWH(
            cx - barW / 2 - 2, padT + innerH - vsH, barW + 4, vsH);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = Pc.borderStrong.withValues(alpha: 0.5),
        );
      }
      final h = b.value / maxV * innerH;
      final isPeak = i == peakIndex;
      final rect = Rect.fromLTWH(cx - barW / 2, padT + innerH - h, barW, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        Paint()..color = isPeak ? Pc.ink : accent,
      );
      _text(canvas, b.label, Offset(cx, size.height - padB + 14),
          align: TextAlign.center, color: Pc.textSec, mono: true, size: 10);
      if (isPeak && peakLabel != null) {
        final top = padT + innerH - h - 20;
        final badge = Rect.fromCenter(
            center: Offset(cx, top + 9), width: 74, height: 18);
        canvas.drawRRect(
          RRect.fromRectAndRadius(badge, const Radius.circular(3)),
          Paint()..color = Pc.ink,
        );
        _text(canvas, peakLabel!, Offset(cx, top + 3),
            align: TextAlign.center, color: Colors.white, mono: true, size: 9);
      }
    }
  }

  void _text(Canvas canvas, String text, Offset at,
      {required TextAlign align,
      required Color color,
      bool mono = false,
      double size = 10}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w700,
          fontFamily: mono ? Pc.monoFamily : 'Inter',
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      TextAlign.center => at.dx - tp.width / 2,
      TextAlign.right => at.dx - tp.width,
      _ => at.dx,
    };
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.bars != bars || old.peakIndex != peakIndex;
}

/// Donut slice.
class PcSlice {
  const PcSlice(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// Donut chart + legend (used for the payment-method split).
class PcDonut extends StatelessWidget {
  const PcDonut({required this.slices, super.key});
  final List<PcSlice> slices;

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (s, x) => s + x.value);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _DonutPainter(slices, total),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('TOTAL', style: Pc.mono(10, color: Pc.textSec)),
                  Text(pcMoney(total), style: Pc.num(15)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            children: [
              for (final s in slices)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.label,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        '${total == 0 ? 0 : (s.value / total * 100).round()}%',
                        style: Pc.num(12,
                            weight: FontWeight.w400, color: Pc.textSec),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 56,
                        child: Text(pcMoney(s.value),
                            textAlign: TextAlign.right, style: Pc.num(12.5)),
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
  _DonutPainter(this.slices, this.total);
  final List<PcSlice> slices;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 7;
    const stroke = 14.0;
    final track = Paint()
      ..color = Pc.surfaceAlt
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, track);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final s in slices) {
      final sweep = (s.value / total) * 2 * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        Paint()
          ..color = s.color
          ..strokeWidth = stroke
          ..style = PaintingStyle.stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.slices != slices || old.total != total;
}
