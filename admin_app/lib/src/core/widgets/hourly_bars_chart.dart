import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Revenue-by-hour chart for the Review tab. Draws two overlaid series:
/// today as solid ink bars (peak hour in accent) over a lighter "ghost" of the
/// 7-day average. Hour ticks render below. Single custom-paint pass keeps it
/// cheap on budget hardware (no per-bar widgets, no charting dependency).
class HourlyBarsChart extends StatelessWidget {
  const HourlyBarsChart({
    required this.today,
    required this.avg7,
    required this.startHour,
    this.peakIndex = -1,
    this.showGhost = true,
    this.height = 96,
    super.key,
  });

  final List<double> today;
  final List<double> avg7;
  final int startHour;
  final int peakIndex;
  final bool showGhost;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (today.isEmpty) return const SizedBox.shrink();
    final maxValue = [
      ...today,
      if (showGhost) ...avg7,
    ].fold<double>(0, (m, v) => v > m ? v : m);
    final safeMax = maxValue == 0 ? 1.0 : maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              return CustomPaint(
                size: Size.infinite,
                painter: _HourlyPainter(
                  today: today,
                  avg7: avg7,
                  safeMax: safeMax,
                  peakIndex: peakIndex,
                  showGhost: showGhost,
                  progress: t,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        _TickRow(count: today.length, startHour: startHour),
      ],
    );
  }
}

class _TickRow extends StatelessWidget {
  const _TickRow({required this.count, required this.startHour});

  final int count;
  final int startHour;

  String _hourLabel(int index) {
    final hour = startHour + index;
    final suffix = hour < 12 ? 'AM' : 'PM';
    final h12 = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12$suffix';
  }

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final ticks = <int>{
      0,
      count ~/ 4,
      count ~/ 2,
      (count * 3) ~/ 4,
      count - 1,
    };
    return Row(
      children: [
        for (var i = 0; i < count; i++)
          Expanded(
            child: Center(
              child: Text(
                ticks.contains(i) ? _hourLabel(i) : '',
                maxLines: 1,
                style: const TextStyle(
                  color: PosColors.mutedSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 8.5,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _HourlyPainter extends CustomPainter {
  _HourlyPainter({
    required this.today,
    required this.avg7,
    required this.safeMax,
    required this.peakIndex,
    required this.showGhost,
    required this.progress,
  });

  final List<double> today;
  final List<double> avg7;
  final double safeMax;
  final int peakIndex;
  final bool showGhost;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final n = today.length;
    if (n == 0) return;

    final baselineY = size.height;
    canvas.drawLine(
      Offset(0, baselineY - 0.5),
      Offset(size.width, baselineY - 0.5),
      Paint()
        ..color = PosColors.line
        ..strokeWidth = 0.5,
    );

    final slot = size.width / n;
    final ghostWidth = slot * 0.72;
    final todayWidth = ghostWidth * 0.6;
    const radius = Radius.circular(1.5);

    final ghostFill = Paint()..color = PosColors.surfaceSunk;
    final ghostStroke = Paint()
      ..color = PosColors.lineStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    final todayFill = Paint()..color = PosColors.primaryDark;
    final peakFill = Paint()..color = PosColors.primary;

    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;

      if (showGhost && i < avg7.length) {
        final gh = (avg7[i] / safeMax) * size.height * progress;
        if (gh > 0.5) {
          final rect = RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - ghostWidth / 2, baselineY - gh, ghostWidth, gh),
            topLeft: radius,
            topRight: radius,
          );
          canvas.drawRRect(rect, ghostFill);
          canvas.drawRRect(rect, ghostStroke);
        }
      }

      final th = (today[i] / safeMax) * size.height * progress;
      if (th > 0.5) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - todayWidth / 2, baselineY - th, todayWidth, th),
          topLeft: radius,
          topRight: radius,
        );
        canvas.drawRRect(rect, i == peakIndex ? peakFill : todayFill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyPainter old) {
    return old.progress != progress ||
        old.today != today ||
        old.avg7 != avg7 ||
        old.peakIndex != peakIndex ||
        old.showGhost != showGhost;
  }
}
