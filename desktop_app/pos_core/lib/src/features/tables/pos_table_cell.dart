import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/tf_design_system.dart';
import '../../models/order_model.dart';

/// Tile state → (fill, ink, line) — the single lookup for the FOH grid, the
/// order-wizard table picker, and any other occupied-table surface (v4 §5.3):
/// white vacant, saturated Petpooja yellow occupied, blue selection.
({Color fill, Color ink, Color line}) tableStateStyle({
  required bool occupied,
  bool selected = false,
}) {
  if (selected) {
    return (
      fill: PosColors.primarySoft,
      ink: PosColors.accentStrong,
      line: PosColors.primary,
    );
  }
  return occupied
      ? (
          fill: PosColors.stateOccupied,
          ink: PosColors.stateOccupiedInk,
          line: PosColors.stateOccupiedLine,
        )
      : (fill: PosColors.surface, ink: PosColors.text, line: PosColors.line);
}

/// FOH table tile — Petpooja state anatomy (v4 §5.3, target10): occupied tiles
/// carry elapsed time (top-left), centered number, running amount
/// (bottom-left), ⋮ overflow (bottom-right), mint kitchen dot (top-right) once
/// a KOT is sent. No Spacer() air — the tile is a packed data cell.
///
/// Shared by the Tables page and the order wizard's dine-in picker
/// ([selected] = wizard selection; [showOverflow] hides the ⋮ there).
class PosTableCell extends StatelessWidget {
  const PosTableCell({
    required this.label,
    required this.order,
    required this.onTap,
    this.selected = false,
    this.showOverflow = true,
    super.key,
  });

  final String label;
  final OrderModel? order;
  final VoidCallback? onTap;
  final bool selected;
  final bool showOverflow;

  @override
  Widget build(BuildContext context) {
    final text = AppScope.select(context, AppAspect.language).strings;
    final occupied = order != null;
    final hasKot = occupied && order!.kotBatches.isNotEmpty;
    final mins = occupied
        ? DateTime.now().difference(order!.createdAt.toLocal()).inMinutes
        : 0;

    final style = tableStateStyle(occupied: occupied, selected: selected);
    final fill = style.fill;
    final ink = style.ink;
    final line = style.line;

    // Bare table number, Petpooja-style ("T3" → "3").
    final number = label.startsWith('T') ? label.substring(1) : label;

    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(PosRadii.tile),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(PosSpacing.sp2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosRadii.tile),
            border: Border.all(color: line, width: selected ? 2 : 1),
          ),
          child: Stack(
            children: [
              Center(
                child: TfText(
                  number,
                  style: TfTextStyles.tileNumber.copyWith(color: ink),
                ),
              ),
              if (occupied) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: ink),
                      const SizedBox(width: 3),
                      TfText(
                        text.agoMinutes(mins),
                        maxLines: 1,
                        style: TfTextStyles.label.copyWith(color: ink),
                      ),
                    ],
                  ),
                ),
                if (hasKot)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: PosColors.stateKitchen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: PosColors.stateKitchenInk,
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  child: TfText(
                    tfFormatCurrency(context, order!.total),
                    style: TfTextStyles.label.copyWith(
                      fontWeight: FontWeight.w800,
                      color: ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (showOverflow)
                  Positioned(
                    bottom: -PosSpacing.sp1,
                    right: -PosSpacing.sp1,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(PosRadii.pill),
                      child: Padding(
                        padding: const EdgeInsets.all(PosSpacing.sp1),
                        child: Icon(
                          Icons.more_vert_rounded,
                          size: 16,
                          color: ink,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
