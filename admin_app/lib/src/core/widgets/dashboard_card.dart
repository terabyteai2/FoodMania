import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tf_design_system.dart';

class DashboardCard extends StatefulWidget {
  const DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.caption,
    this.onTap,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final VoidCallback? onTap;

  @override
  State<DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<DashboardCard> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 190;
        return Material(
          color: Colors.transparent,
          child: TfCard(
            color: PosColors.surface,
            padded: false,
            clip: true,
            child: InkWell(
              onTap: widget.onTap,
              splashColor: PosColors.primary.withValues(alpha: 0.08),
              highlightColor: PosColors.primary.withValues(alpha: 0.04),
              child: Padding(
                padding: EdgeInsets.all(
                  compact ? PosSpacing.sp3 : PosSpacing.sp4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        _IconBox(
                          icon: widget.icon,
                          compact: compact,
                          color: widget.color,
                        ),
                        const Spacer(),
                        if (widget.onTap != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            color: PosColors.muted,
                            size: compact ? 18 : 20,
                          ),
                      ],
                    ),
                    SizedBox(height: compact ? PosSpacing.sp2 : PosSpacing.sp3),
                    TfText(
                      widget.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          (compact
                                  ? const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: PosColors.slate,
                                      letterSpacing: -0.18,
                                    )
                                  : Theme.of(context).textTheme.headlineMedium)
                              ?.copyWith(
                                fontSize: compact ? 18 : 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: compact ? -0.18 : -0.56,
                              ),
                    ),
                    const SizedBox(height: PosSpacing.sp1),
                    TfText(
                      widget.title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: PosColors.textTer,
                        letterSpacing: 0.48,
                        height: 1.3,
                      ),
                    ),
                    if (widget.caption != null && !compact) ...[
                      const SizedBox(height: PosSpacing.sp1),
                      TfText(
                        widget.caption!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({
    required this.icon,
    required this.compact,
    required this.color,
  });

  final IconData icon;
  final bool compact;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tint = color == PosColors.success
        ? PosColors.successSoft
        : color == PosColors.warning
        ? PosColors.warningSoft
        : color == PosColors.danger
        ? PosColors.dangerSoft
        : PosColors.primarySoft;
    final ink = color == PosColors.success
        ? PosColors.success
        : color == PosColors.warning
        ? PosColors.warning
        : color == PosColors.danger
        ? PosColors.danger
        : PosColors.accentStrong;
    return Container(
      width: compact ? 34 : 38,
      height: compact ? 34 : 38,
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(PosRadii.lg),
        border: Border.all(color: PosColors.line),
      ),
      child: Icon(icon, color: ink, size: compact ? 16 : 18),
    );
  }
}
