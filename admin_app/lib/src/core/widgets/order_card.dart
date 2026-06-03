import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_scope.dart';
import '../../models/order_model.dart';
import '../../models/order_service_type.dart';
import '../../models/order_status.dart';
import '../theme/app_theme.dart';
import 'status_badge.dart';
import 'tf_design_system.dart';

const _adminOrderStatusOptions = <OrderStatus>[
  OrderStatus.pending,
  OrderStatus.accepted,
  OrderStatus.served,
  OrderStatus.cancelled,
];

class OrderCard extends StatelessWidget {
  const OrderCard({
    required this.order,
    required this.onStatusChanged,
    required this.onPrintTicket,
    super.key,
  });

  final OrderModel order;
  final ValueChanged<OrderStatus> onStatusChanged;
  final VoidCallback onPrintTicket;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 2);
    final createdTime = DateFormat('MMM d, h:mm a').format(order.createdAt);
    final accent = _accentForStatus(order.status);

    return TfCard(
      color: PosColors.surface,
      padded: false,
      clip: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [accent, accent.withValues(alpha: 0.5)],
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(16, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: PosColors.background,
                      border: Border(
                        bottom: BorderSide(
                          color: PosColors.lineStrong.withValues(alpha: 0.36),
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _OrderMark(status: order.status),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _SequencePill(label: order.displaySequence),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: TfText(
                                      order.orderNo,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleLarge,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _MetaPill(
                                    icon: Icons.person_outline,
                                    label: order.customerName ?? 'Walk-in',
                                  ),
                                  if (order.serviceType ==
                                      OrderServiceType.delivery) ...[
                                    if ((order.deliveryAddress ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      _MetaPill(
                                        icon: Icons.location_on_outlined,
                                        label: order.deliveryAddress!.trim(),
                                      ),
                                    if ((order.mobileNumber ?? '')
                                        .trim()
                                        .isNotEmpty)
                                      _MetaPill(
                                        icon: Icons.phone_outlined,
                                        label: order.mobileNumber!.trim(),
                                      ),
                                  ] else
                                    _MetaPill(
                                      icon: Icons.table_restaurant_outlined,
                                      label: 'Table ${order.tableNo ?? 'N/A'}',
                                    ),
                                  _MetaPill(
                                    icon: Icons.schedule,
                                    label: createdTime,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            alignment: WrapAlignment.end,
                            children: [
                              StatusBadge.source(order.source),
                              StatusBadge.sync(order.syncStatus),
                              StatusBadge.order(order.status),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: PosColors.background,
                            borderRadius: BorderRadius.circular(PosRadii.md),
                            border: Border.all(
                              color: PosColors.lineStrong.withValues(
                                alpha: 0.36,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Column(
                              children: order.items
                                  .map(
                                    (item) => Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: PosColors.background,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: PosColors.lineStrong
                                                    .withValues(alpha: 0.36),
                                              ),
                                            ),
                                            child: TfText(
                                              '${item.qty}×',
                                              style: TextStyle(
                                                color: PosColors.primaryDark,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Expanded(
                                            child: TfText(
                                              item.localizedName(app.language),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          TfText(
                                            currency.format(item.lineTotal),
                                            style: TextStyle(
                                              color: PosColors.slate,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ),
                        if (order.note != null) ...[
                          SizedBox(height: 10),
                          Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: PosColors.accentSoft,
                              borderRadius: BorderRadius.circular(PosRadii.md),
                              border: Border.all(
                                color: PosColors.accent.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.sticky_note_2_outlined,
                                  size: 18,
                                  color: PosColors.warning,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: TfText(
                                    order.note!,
                                    style: TextStyle(
                                      color: PosColors.slateSoft,
                                      fontWeight: FontWeight.w500,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 14),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 520;
                            final total = Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: PosColors.background,
                                borderRadius: BorderRadius.circular(
                                  PosRadii.md,
                                ),
                                border: Border.all(
                                  color: PosColors.lineStrong.withValues(
                                    alpha: 0.36,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TfText(
                                    'TOTAL',
                                    style: TextStyle(
                                      color: PosColors.muted,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 10.6,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  TfText(
                                    currency.format(order.total),
                                    style: TextStyle(
                                      color: PosColors.primaryDark,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ],
                              ),
                            );
                            final actions = Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                TfButton(
                                  onPressed: onPrintTicket,
                                  icon: Icons.print_outlined,
                                  label: 'Print Ticket',
                                  variant: TfButtonVariant.paper,
                                  fullWidth: false,
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: PosColors.background,
                                    borderRadius: BorderRadius.circular(
                                      PosRadii.sm + 2,
                                    ),
                                    border: Border.all(
                                      color: PosColors.lineStrong.withValues(
                                        alpha: 0.36,
                                      ),
                                    ),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<OrderStatus>(
                                      value: order.status.adminStatus,
                                      borderRadius: BorderRadius.circular(
                                        PosRadii.md,
                                      ),
                                      icon: Icon(
                                        Icons.expand_more_rounded,
                                        color: PosColors.slate,
                                      ),
                                      style: TextStyle(
                                        color: PosColors.slate,
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                      items: _adminOrderStatusOptions
                                          .map(
                                            (status) => DropdownMenuItem(
                                              value: status,
                                              child: Text(status.label),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: (status) {
                                        if (status != null &&
                                            status !=
                                                order.status.adminStatus &&
                                            order.status.canTransitionTo(
                                              status,
                                            )) {
                                          onStatusChanged(status);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  total,
                                  SizedBox(height: 12),
                                  actions,
                                ],
                              );
                            }
                            return Row(children: [total, Spacer(), actions]);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _accentForStatus(OrderStatus status) {
    switch (status.adminStatus) {
      case OrderStatus.pending:
        return PosColors.warning;
      case OrderStatus.accepted:
        return PosColors.primaryDark;
      case OrderStatus.preparing:
        return PosColors.primaryDark;
      case OrderStatus.ready:
        return PosColors.primaryDark;
      case OrderStatus.served:
        return PosColors.success;
      case OrderStatus.cancelled:
        return PosColors.danger;
    }
  }
}

class _SequencePill extends StatelessWidget {
  const _SequencePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: PosColors.primary,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.primaryDark.withValues(alpha: 0.2)),
      ),
      child: TfText(
        label,
        style: TextStyle(
          color: PosColors.slate,
          fontWeight: FontWeight.w500,
          fontSize: 12,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _OrderMark extends StatelessWidget {
  const _OrderMark({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status.adminStatus) {
      OrderStatus.pending => PosColors.warning,
      OrderStatus.accepted => PosColors.primaryDark,
      OrderStatus.preparing => PosColors.primaryDark,
      OrderStatus.ready => PosColors.primaryDark,
      OrderStatus.served => PosColors.success,
      OrderStatus.cancelled => PosColors.danger,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color == PosColors.danger
            ? PosColors.dangerSoft
            : color == PosColors.success
            ? PosColors.successSoft
            : PosColors.primarySoft,
        borderRadius: BorderRadius.circular(PosRadii.md),
        border: Border.all(color: PosColors.line),
      ),
      child: Icon(Icons.receipt_long_outlined, color: color, size: 22),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: PosColors.background,
        borderRadius: BorderRadius.circular(PosRadii.pill),
        border: Border.all(color: PosColors.lineStrong.withValues(alpha: 0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: PosColors.muted),
          SizedBox(width: 5),
          TfText(
            label,
            style: TextStyle(
              color: PosColors.slateSoft,
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
