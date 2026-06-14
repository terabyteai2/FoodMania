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
        return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PosRadii.lg),
                boxShadow: PosShadows.card,
              ),
              child: Material(
                color: Colors.transparent,
                child: TfCard(
                  color: PosColors.surface,
                  padded: false,
                  clip: true,
                  child: InkWell(
                    onTap: widget.onTap,
                    splashColor: PosColors.slate.withValues(alpha: 0.08),
                    highlightColor: PosColors.slate.withValues(alpha: 0.04),
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              _IconBox(icon: widget.icon, compact: compact),
                              Spacer(),
                              if (widget.onTap != null)
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: PosColors.slate,
                                  size: compact ? 16 : 18,
                                ),
                            ],
                          ),
                          SizedBox(height: compact ? 8 : 12),
                          TfText(
                            widget.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                (compact
                                        ? TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: PosColors.slate,
                                            letterSpacing: -0.01 * 18,
                                          )
                                        : Theme.of(
                                            context,
                                          ).textTheme.headlineMedium)
                                    ?.copyWith(
                                      fontSize: compact ? 18 : 28,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: compact
                                          ? -0.01 * 18
                                          : -0.02 * 28,
                                    ),
                          ),
                          SizedBox(height: 4),
                          TfText(
                            widget.title,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: compact
                                ? TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: PosColors.textTer,
                                    letterSpacing: 0.04 * 12,
                                    height: 1.3,
                                  )
                                : TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: PosColors.textTer,
                                    letterSpacing: 0.04 * 12,
                                    height: 1.3,
                                  ),
                          ),
                          if (widget.caption != null && !compact) ...[
                            SizedBox(height: 4),
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
            ),
        );
      },
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.compact});

  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? 32 : 36,
      height: compact ? 32 : 36,
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.tile),
        border: Border.all(color: PosColors.slate),
      ),
      child: Icon(icon, color: PosColors.slate, size: compact ? 16 : 18),
    );
  }
}
