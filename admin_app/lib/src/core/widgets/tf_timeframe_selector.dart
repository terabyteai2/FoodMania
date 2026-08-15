import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import './tf_design_system.dart';

enum TfTimeframe { today, week, month, custom }

class TfCalendarRangePicker extends StatefulWidget {
  const TfCalendarRangePicker({
    required this.start,
    required this.end,
    required this.onRangeChanged,
    super.key,
  });

  final DateTime? start;
  final DateTime? end;
  final void Function(DateTime? start, DateTime? end) onRangeChanged;

  @override
  State<TfCalendarRangePicker> createState() => _TfCalendarRangePickerState();
}

class _TfCalendarRangePickerState extends State<TfCalendarRangePicker> {
  late DateTime _viewMonth;

  @override
  void initState() {
    super.initState();
    _viewMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  void _prev() => setState(() {
    _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1);
  });

  void _next() => setState(() {
    _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1);
  });

  void _tapDay(DateTime day) {
    final s = widget.start;
    final e = widget.end;
    if (s == null) {
      widget.onRangeChanged(day, null);
    } else if (e == null) {
      if (day.isBefore(s)) {
        widget.onRangeChanged(day, s);
      } else {
        widget.onRangeChanged(s, day);
      }
    } else {
      widget.onRangeChanged(day, null);
    }
  }

  bool _inRange(DateTime d) {
    final s = widget.start;
    final e = widget.end;
    if (s == null || e == null) return false;
    return !d.isBefore(s) && !d.isAfter(e);
  }

  String _fmtDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthLabel = '${months[_viewMonth.month - 1]} ${_viewMonth.year}';
    final daysInMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final firstDOW = DateTime(_viewMonth.year, _viewMonth.month, 1).weekday;
    // weekday: Monday=1 ... Sunday=7 -> shift to Mon-start (0-indexed)
    final lead = firstDOW - 1;

    final s = widget.start;
    final e = widget.end;
    final summary = (s != null && e != null)
        ? '${_fmtDate(s)} – ${_fmtDate(e)}'
        : (s != null
              ? '${tfPick(context, en: 'Start', bn: 'শুরু')}: ${_fmtDate(s)}'
              : tfPick(
                  context,
                  en: 'Tap a date to start',
                  bn: 'তারিখ নির্বাচন করুন',
                ));

    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);

    return Container(
      decoration: BoxDecoration(
        color: PosColors.surface,
        borderRadius: BorderRadius.circular(PosRadii.lg),
        border: Border.all(color: PosColors.line, width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month navigation
          Row(
            children: [
              TfIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: tfPick(
                  context,
                  en: 'Previous month',
                  bn: 'পূর্ববর্তী মাস',
                ),
                onPressed: _prev,
              ),
              Expanded(
                child: Center(
                  child: TfText(
                    monthLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PosColors.text,
                    ),
                  ),
                ),
              ),
              TfIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: tfPick(context, en: 'Next month', bn: 'পরবর্তী মাস'),
                onPressed: _next,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // DOW header
          Row(
            children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: TfText(
                        d,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: PosColors.muted,
                          letterSpacing: 0.04,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 4),
          // Day grid
          ...List.generate(_gridRows(daysInMonth, lead), (ri) {
            final cells = <Widget>[];
            for (int ci = 0; ci < 7; ci++) {
              final idx = ri * 7 + ci - lead;
              final day = idx + 1;
              if (idx < 0 || idx >= daysInMonth) {
                cells.add(const Expanded(child: SizedBox.shrink()));
              } else {
                final date = DateTime(_viewMonth.year, _viewMonth.month, day);
                final isStart = s != null && date == s;
                final isEnd = e != null && date == e;
                final inRange = _inRange(date);
                final isToday = date == todayNormalized;

                Color bg;
                Color fg;
                FontWeight fw;
                if (isStart || isEnd) {
                  bg = PosColors.primary;
                  fg = PosColors.accentInk;
                  fw = FontWeight.w700;
                } else if (inRange) {
                  bg = PosColors.primarySoft;
                  fg = PosColors.accentStrong;
                  fw = FontWeight.w600;
                } else {
                  bg = Colors.transparent;
                  fg = PosColors.inkSoft;
                  fw = FontWeight.w400;
                }

                cells.add(
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _tapDay(date),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(PosRadii.sm),
                          border: isToday && !isStart && !isEnd
                              ? Border.all(
                                  color: PosColors.lineStrong,
                                  width: 1,
                                )
                              : null,
                        ),
                        child: TfText(
                          '$day',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: fw,
                            color: fg,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(children: cells),
            );
          }),
          const SizedBox(height: 6),
          // Summary bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: PosColors.surfaceSunk,
              borderRadius: BorderRadius.circular(PosRadii.sm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: PosColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TfText(
                    summary,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: s != null ? PosColors.text : PosColors.muted,
                    ),
                  ),
                ),
                if (s != null && e != null)
                  GestureDetector(
                    onTap: () => widget.onRangeChanged(null, null),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: PosColors.mutedSoft,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _gridRows(int daysInMonth, int lead) => ((lead + daysInMonth + 6) ~/ 7);
}

// ---------------------------------------------------------------------------
// TfPeriodWithCalendar — the canonical period control with a custom range.
// ---------------------------------------------------------------------------
/// [TfPeriodSelector] plus the calendar-icon custom-range segment (DESIGN.md:
/// every time-range filter carries the calendar custom picker; its label IS
/// the calendar icon). Owns the inline [TfCalendarRangePicker] reveal and the
/// pending start/end while the user picks; fires [onChanged] with
/// ('custom', start, end) once both ends are chosen, or (preset, null, null)
/// for preset taps.
class TfPeriodWithCalendar extends StatefulWidget {
  const TfPeriodWithCalendar({
    required this.options,
    required this.value,
    required this.onChanged,
    this.start,
    this.end,
    this.compact = false,
    super.key,
  });

  /// Marks the custom-range selection in [value].
  static const String customValue = 'custom';

  /// Preset segments only — the custom segment is appended automatically.
  final List<(String, String)> options;
  final String value;
  final void Function(String value, DateTime? start, DateTime? end) onChanged;

  /// Current custom range (shown when reopening the calendar).
  final DateTime? start;
  final DateTime? end;

  /// Passed through to [TfPeriodSelector] for tight rows.
  final bool compact;

  @override
  State<TfPeriodWithCalendar> createState() => _TfPeriodWithCalendarState();
}

class _TfPeriodWithCalendarState extends State<TfPeriodWithCalendar> {
  bool _calendarOpen = false;
  DateTime? _pendingStart;
  DateTime? _pendingEnd;
  final GlobalKey _anchorKey = GlobalKey();
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  void _closeCalendar() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _calendarOpen = false);
  }

  void _openCalendarOverlay() {
    final anchor = _anchorKey.currentContext;
    if (anchor == null) return;
    final box = anchor.findRenderObject() as RenderBox?;
    if (box == null) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    _overlayEntry = OverlayEntry(
      builder: (_) => _CalendarOverlay(
        anchorRect: rect,
        start: _pendingStart,
        end: _pendingEnd,
        onRangeChanged: _onRangeChanged,
        onDismiss: _closeCalendar,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _onSegment(String value) {
    if (value == TfPeriodWithCalendar.customValue) {
      if (_calendarOpen) {
        _closeCalendar();
      } else {
        setState(() {
          _calendarOpen = true;
          _pendingStart = widget.start;
          _pendingEnd = widget.end;
        });
        _openCalendarOverlay();
      }
      return;
    }
    _closeCalendar();
    widget.onChanged(value, null, null);
  }

  void _onRangeChanged(DateTime? start, DateTime? end) {
    setState(() {
      _pendingStart = start;
      _pendingEnd = end;
    });
    if (start != null && end != null) {
      _closeCalendar();
      widget.onChanged(TfPeriodWithCalendar.customValue, start, end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCustomActive =
        _calendarOpen || widget.value == TfPeriodWithCalendar.customValue;
    return KeyedSubtree(
      key: _anchorKey,
      child: TfPeriodSelector(
        options: widget.options,
        value: showCustomActive
            ? TfPeriodWithCalendar.customValue
            : widget.value,
        onChanged: _onSegment,
        customValue: TfPeriodWithCalendar.customValue,
        customIcon: Icons.calendar_month_rounded,
        compact: widget.compact,
      ),
    );
  }
}

/// Full-screen barrier + anchored calendar card rendered in the app Overlay,
/// so the picker floats over the page instead of pushing content down.
class _CalendarOverlay extends StatelessWidget {
  const _CalendarOverlay({
    required this.anchorRect,
    required this.start,
    required this.end,
    required this.onRangeChanged,
    required this.onDismiss,
  });

  final Rect anchorRect;
  final DateTime? start;
  final DateTime? end;
  final void Function(DateTime? start, DateTime? end) onRangeChanged;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    const w = 360.0;
    const h = 390.0;
    final below = anchorRect.bottom + 6 + h <= screen.height - 8;
    final top = below
        ? anchorRect.bottom + 6
        : math.max(8.0, anchorRect.top - 6 - h);
    final left = ((screen.width - w) / 2).clamp(8.0, screen.width - w - 8);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onDismiss,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: w,
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: PosColors.surface,
                borderRadius: BorderRadius.circular(PosRadii.lg),
                border: Border.all(color: PosColors.line, width: 1),
                boxShadow: PosShadows.soft,
              ),
              child: TfCalendarRangePicker(
                start: start,
                end: end,
                onRangeChanged: onRangeChanged,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
