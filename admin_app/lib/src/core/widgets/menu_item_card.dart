import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/menu_item.dart';
import '../theme/app_theme.dart';
import 'menu_image_view.dart';
import 'status_badge.dart';
import 'tf_design_system.dart';

class MenuItemCard extends StatefulWidget {
  const MenuItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
    required this.onAvailabilityChanged,
    super.key,
  });

  final MenuItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onAvailabilityChanged;

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final available = widget.item.isAvailable;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(PosRadii.lg),
          boxShadow: _hovering ? PosShadows.glow : PosShadows.card,
        ),
        child: TfCard(
          color: PosColors.surface,
          padded: false,
          clip: true,
          child: Padding(
            padding: EdgeInsets.all(7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PosRadii.sm),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedScale(
                          scale: _hovering ? 1.04 : 1.0,
                          duration: Duration(milliseconds: 320),
                          curve: Curves.easeOut,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              available
                                  ? Colors.transparent
                                  : Colors.black.withValues(alpha: 0.18),
                              BlendMode.darken,
                            ),
                            child: MenuImageView(
                              imageUrl: widget.item.imageUrl,
                              iconKey: resolveMenuIconKey(
                                iconKey: widget.item.extras.iconKey,
                                name: widget.item.name,
                                category: widget.item.category,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.36),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          bottom: 7,
                          child: StatusBadge(
                            label: available ? 'Available' : 'Paused',
                            color: available
                                ? PosColors.success
                                : PosColors.danger,
                            icon: available
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 7,
                          child: Container(
                            decoration: BoxDecoration(
                              color: PosColors.surface,
                              borderRadius: BorderRadius.circular(
                                PosRadii.pill,
                              ),
                              border: Border.all(color: PosColors.line),
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: TfText(
                                currency.format(widget.item.price),
                                style: TextStyle(
                                  color: PosColors.primaryDark,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 10.8,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 6),
                TfText(
                  widget.item.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                    height: 1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                TfText(
                  widget.item.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w400,
                    height: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: _SmallPill(
                        icon: Icons.category_outlined,
                        label: widget.item.category,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Divider(height: 1),
                Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Transform.scale(
                            scale: 0.72,
                            alignment: Alignment.centerLeft,
                            child: Switch.adaptive(
                              value: widget.item.isAvailable,
                              onChanged: widget.onAvailabilityChanged,
                            ),
                          ),
                          Expanded(
                            child: TfText(
                              widget.item.isAvailable ? 'Active' : 'Paused',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: widget.item.isAvailable
                                    ? PosColors.success
                                    : PosColors.muted,
                                fontSize: 10.5,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _IconAction(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit menu item',
                      onPressed: widget.onEdit,
                      color: PosColors.slate,
                    ),
                    SizedBox(width: 5),
                    _IconAction(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete menu item',
                      onPressed: widget.onDelete,
                      color: PosColors.danger,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: PosColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PosRadii.sm),
          side: BorderSide(color: PosColors.lineStrong.withValues(alpha: 0.36)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(PosRadii.sm),
          child: Padding(
            padding: EdgeInsets.all(6),
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.lineStrong.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: PosColors.muted),
          SizedBox(width: 4),
          TfText(
            label,
            style: TextStyle(
              color: PosColors.slateSoft,
              fontWeight: FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
