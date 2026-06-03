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
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 190;
        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedScale(
            scale: _pressed ? 0.985 : 1.0,
            duration: Duration(milliseconds: 110),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(PosRadii.lg),
                boxShadow: _hovering ? PosShadows.glow : PosShadows.card,
              ),
              child: Material(
                color: Colors.transparent,
                child: TfCard(
                  color: PosColors.surface,
                  padded: false,
                  clip: true,
                  child: InkWell(
                    onTap: widget.onTap,
                    onHighlightChanged: (v) => setState(() => _pressed = v),
                    splashColor: PosColors.slate.withValues(alpha: 0.08),
                    highlightColor: PosColors.slate.withValues(alpha: 0.04),
                    child: Padding(
                      padding: EdgeInsets.all(compact ? 8 : 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              _IconBox(icon: widget.icon, compact: compact),
                              Spacer(),
                              if (widget.onTap != null)
                                AnimatedSlide(
                                  duration: Duration(milliseconds: 220),
                                  offset: _hovering
                                      ? Offset(0.18, 0)
                                      : Offset.zero,
                                  child: Icon(
                                    Icons.arrow_forward_rounded,
                                    color: PosColors.slate,
                                    size: compact ? 16 : 18,
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: compact ? 6 : 8),
                          TfText(
                            widget.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                (compact
                                        ? TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: PosColors.slate,
                                            letterSpacing: 0,
                                          )
                                        : Theme.of(
                                            context,
                                          ).textTheme.headlineMedium)
                                    ?.copyWith(
                                      fontSize: compact ? 16 : 20,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0,
                                    ),
                          ),
                          SizedBox(height: 3),
                          TfText(
                            widget.title,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: compact
                                ? TextStyle(
                                    fontSize: 10.6,
                                    fontWeight: FontWeight.w500,
                                    color: PosColors.slate,
                                    height: 1.1,
                                  )
                                : TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: PosColors.slate,
                                    height: 1.1,
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
      width: compact ? 28 : 32,
      height: compact ? 28 : 32,
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(compact ? 11 : 13),
        border: Border.all(color: PosColors.slate),
      ),
      child: Icon(icon, color: PosColors.slate, size: compact ? 15 : 17),
    );
  }
}
