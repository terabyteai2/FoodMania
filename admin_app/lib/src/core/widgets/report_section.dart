import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'tf_design_system.dart';

/// Shared column metrics for item-wise report tables so the column header,
/// the data rows, and the analytics-tab rows line up identically. The
/// inter-column gap is [PosSpacing.sp2]; [kReportRowChevron] reserves the
/// trailing chevron gutter on rows so the header labels sit over their numbers.
const double kReportAvgColWidth = 72; // Avg. Unit Price column
const double kReportTotalColWidth = 84; // Total Price column
const double kReportRowChevron = 18; // trailing chevron gutter

/// One row in a [ReportSection]: label on the left, value on the right.
///
/// - [bold] renders a total row (heavier label + value, ink text).
/// - [deduction] colours the value muted (use with [parenCurrency] for
///   parenthesised deductions, e.g. `(৳1,156.00)`).
/// - [indent] left-pads the label for sub-items under a parent figure.
/// - [positive] colours the value success-green (e.g. positive profit).
class ReportRow {
  ReportRow(
    this.label,
    this.value, {
    this.bold = false,
    this.deduction = false,
    this.indent = false,
    this.positive = false,
  });
  final String label;
  final String value;
  final bool bold;
  final bool deduction;
  final bool indent;
  final bool positive;
}

/// Collapsible report-section card (spec §5 accordion): white card, bold header
/// with a collapse chevron, then label-left / value-right rows separated by
/// hairlines, deductions in parentheses, bold total row.
class ReportSection extends StatefulWidget {
  const ReportSection({required this.title, required this.rows, super.key});
  final String title;
  final List<ReportRow> rows;

  @override
  State<ReportSection> createState() => _ReportSectionState();
}

class _ReportSectionState extends State<ReportSection> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    return TfCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                PosSpacing.sp4 - 2,
                PosSpacing.sp4 - 2,
                PosSpacing.sp3,
                PosSpacing.sp4 - 2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TfText(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: PosColors.text,
                      ),
                    ),
                  ),
                  Icon(
                    _open
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: PosColors.muted,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                PosSpacing.sp4 - 2,
                0,
                PosSpacing.sp4 - 2,
                PosSpacing.sp2 - 2,
              ),
              child: Column(
                children: [for (final row in widget.rows) _buildRow(row)],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(ReportRow row) {
    final valueColor = row.positive
        ? PosColors.success
        : row.deduction
        ? PosColors.muted
        : PosColors.text;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PosColors.line)),
      ),
      padding: EdgeInsets.fromLTRB(
        row.indent ? PosSpacing.sp4 - 2 : 0,
        PosSpacing.sp3 - 1,
        0,
        PosSpacing.sp3 - 1,
      ),
      child: Row(
        children: [
          Expanded(
            child: TfText(
              row.label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: row.bold ? FontWeight.w700 : FontWeight.w500,
                color: row.bold ? PosColors.text : PosColors.ink2,
              ),
            ),
          ),
          TfText(
            row.value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: row.bold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Formats a deduction value in parentheses, e.g. `(৳1,156.00)`.
String parenCurrency(BuildContext context, double value) =>
    '(${tfFormatCurrency(context, value)})';
