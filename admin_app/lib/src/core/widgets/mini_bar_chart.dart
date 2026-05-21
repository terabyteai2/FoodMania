import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MiniBarChart extends StatelessWidget {
  const MiniBarChart({
    required this.values,
    required this.labels,
    this.color,
    this.height = 86,
    this.formatValue,
    this.highlightLast = true,
    super.key,
  });

  final List<double> values;
  final List<String> labels;
  final Color? color;
  final double height;
  final String Function(double)? formatValue;
  final bool highlightLast;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? PosColors.primary;
    if (values.isEmpty) return SizedBox.shrink();
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    final safeMax = maxValue == 0 ? 1 : maxValue;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final spacing = constraints.maxWidth < 160 ? 4.0 : 6.0;
          final reserveTopLabel =
              highlightLast &&
              formatValue != null &&
              values.isNotEmpty &&
              values.last > 0;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) SizedBox(width: spacing),
                Expanded(
                  child: _Bar(
                    height: height,
                    ratio: values[i] / safeMax,
                    label: labels[i],
                    highlight: highlightLast && i == values.length - 1,
                    color: color,
                    reserveTopLabel: reserveTopLabel,
                    topLabel: values[i] > 0 && i == values.length - 1
                        ? formatValue?.call(values[i])
                        : null,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.height,
    required this.ratio,
    required this.label,
    required this.highlight,
    required this.color,
    required this.reserveTopLabel,
    this.topLabel,
  });

  final double height;
  final double ratio;
  final String label;
  final bool highlight;
  final Color color;
  final bool reserveTopLabel;
  final String? topLabel;

  @override
  Widget build(BuildContext context) {
    final barColor = highlight ? color : color.withValues(alpha: 0.4);
    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth.clamp(4.0, 40.0).toDouble();
        return SizedBox(
          height: height,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (reserveTopLabel)
                SizedBox(
                  height: 14,
                  child: topLabel == null
                      ? null
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            topLabel!,
                            maxLines: 1,
                            style: TextStyle(
                              color: barColor,
                              fontWeight: FontWeight.w900,
                              fontSize: 9.6,
                            ),
                          ),
                        ),
                ),
              if (reserveTopLabel) SizedBox(height: 3),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, barConstraints) {
                    final maxHeight = barConstraints.maxHeight;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: ratio.clamp(0, 1).toDouble(),
                        ),
                        duration: Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) {
                          return Container(
                            width: barWidth,
                            height: (maxHeight * value)
                                .clamp(2.0, maxHeight)
                                .toDouble(),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  barColor,
                                  barColor.withValues(alpha: 0.55),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: highlight
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.32),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 6),
              SizedBox(
                height: 12,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: highlight ? PosColors.slate : PosColors.muted,
                      fontWeight: highlight ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 9.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
