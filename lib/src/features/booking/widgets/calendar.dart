// lib/src/features/booking/widgets/calendar.dart — the month calendar. Dart port
// of the RN app's `Calendar.tsx`.
//
// A PRESENTATIONAL month-grid calendar, built from our own design-system tokens (no
// third-party calendar dependency). One month at a time with ‹ › navigation, a
// weekday header, and a 7-column grid of day cells.
//
// PROPS-IN, EVENTS-OUT: the component owns only WHICH MONTH is visible (navigation
// state). The selection is the caller's — it passes [selectedDate] (to highlight)
// and [onSelectDate] (the tapped day). Disabled days don't fire the callback.
//
// DATES AS "YYYY-MM-DD": every date crossing this component's edges is a plain
// calendar-date string. Handy property we lean on: "YYYY-MM-DD" strings compare
// LEXICOGRAPHICALLY the same as chronologically, so the min/max bounds are simple
// string comparisons — no Date math, no timezone traps. The only [DateTime]s we
// build are local ones for laying out the grid.

import 'package:flutter/material.dart';

import '../../../core/format/date_time.dart';
import '../../../core/theme/theme.dart';
import '../../../core/widgets/widgets.dart';

/// Two-letter weekday headers, Sunday-first (column 0 = Sunday).
const List<String> _weekdays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];

class Calendar extends StatefulWidget {
  /// The selected day ("YYYY-MM-DD"), highlighted when it's in the visible month.
  final String? selectedDate;

  /// Called with the tapped day ("YYYY-MM-DD"). Disabled days don't fire it.
  final ValueChanged<String>? onSelectDate;

  /// Earliest selectable day; earlier days render disabled. Defaults to today.
  final String? minDate;

  /// Latest selectable day; later days render disabled. Null = no upper bound.
  final String? maxDate;

  /// Which month to open on ("YYYY-MM-DD", any day in it). Defaults to the selected
  /// day's month, else the min day's month.
  final String? initialMonth;

  const Calendar({
    super.key,
    this.selectedDate,
    this.onSelectDate,
    this.minDate,
    this.maxDate,
    this.initialMonth,
  });

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  late DateTime _visibleMonth;

  String get _today => isoDateToString(DateTime.now());
  String get _min => widget.minDate ?? _today;

  @override
  void initState() {
    super.initState();
    _visibleMonth = _startOfMonth(
      _parseIsoDate(widget.initialMonth ?? widget.selectedDate ?? _min),
    );
  }

  static DateTime _parseIsoDate(String iso) {
    final p = iso.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  static DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime _addMonths(DateTime d, int n) =>
      DateTime(d.year, d.month + n, 1);

  /// The month laid out as weeks of 7 cells; each cell is an ISO date or null (pad).
  List<List<String?>> _buildGrid(DateTime month) {
    final first = _startOfMonth(month);
    final leading = first.weekday % 7; // Sun(7)→0, Mon(1)→1 … Sat(6)→6
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final cells = <String?>[];
    for (var i = 0; i < leading; i++) {
      cells.add(null);
    }
    for (var day = 1; day <= daysInMonth; day++) {
      cells.add(isoDateToString(DateTime(month.year, month.month, day)));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return [for (var i = 0; i < cells.length; i += 7) cells.sublist(i, i + 7)];
  }

  @override
  Widget build(BuildContext context) {
    final weeks = _buildGrid(_visibleMonth);
    final visibleIso = isoDateToString(_visibleMonth);
    final maxDate = widget.maxDate;

    // Can't page earlier than the month containing `min`; `maxDate` caps forward.
    final prevDisabled =
        visibleIso.compareTo(isoDateToString(_startOfMonth(_parseIsoDate(_min)))) <=
            0;
    final nextDisabled = maxDate != null &&
        visibleIso.compareTo(
              isoDateToString(_startOfMonth(_parseIsoDate(maxDate))),
            ) >=
            0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header: month + year with month navigation.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _NavButton(
              label: '‹',
              semanticLabel: 'Previous month',
              disabled: prevDisabled,
              onPressed: () =>
                  setState(() => _visibleMonth = _addMonths(_visibleMonth, -1)),
            ),
            AppText(formatMonthLabel(_visibleMonth),
                variant: AppTextVariant.subheading),
            _NavButton(
              label: '›',
              semanticLabel: 'Next month',
              disabled: nextDisabled,
              onPressed: () =>
                  setState(() => _visibleMonth = _addMonths(_visibleMonth, 1)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // Weekday header row.
        Row(
          children: [
            for (final d in _weekdays)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: AppText(d,
                      variant: AppTextVariant.caption,
                      color: AppTextColor.subtle,
                      textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
        // Day grid.
        for (final week in weeks) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (final iso in week)
                Expanded(
                  child: iso == null
                      ? const SizedBox(height: 40)
                      : _DayCell(
                          iso: iso,
                          selected: iso == widget.selectedDate,
                          isToday: iso == _today,
                          disabled: iso.compareTo(_min) < 0 ||
                              (maxDate != null && iso.compareTo(maxDate) > 0),
                          onPressed: () => widget.onSelectDate?.call(iso),
                        ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// One selectable day. Highlighted when selected; ringed when it's today; dimmed and
/// non-pressable when out of bounds.
class _DayCell extends StatelessWidget {
  final String iso;
  final bool selected;
  final bool isToday;
  final bool disabled;
  final VoidCallback onPressed;

  const _DayCell({
    required this.iso,
    required this.selected,
    required this.isToday,
    required this.disabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dayNumber = int.parse(iso.split('-')[2]).toString();

    return Semantics(
      button: true,
      selected: selected,
      enabled: !disabled,
      child: GestureDetector(
        onTap: disabled ? null : onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.transparent,
            borderRadius: AppRadii.mdAll,
            border: !selected && isToday
                ? Border.all(color: AppColors.primary)
                : null,
          ),
          child: AppText(
            dayNumber,
            variant: selected || isToday
                ? AppTextVariant.bodyStrong
                : AppTextVariant.body,
            color: selected
                ? AppTextColor.inverse
                : disabled
                    ? AppTextColor.subtle
                    : AppTextColor.normal,
          ),
        ),
      ),
    );
  }
}

/// A ‹ / › month-paging button.
class _NavButton extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final bool disabled;
  final VoidCallback onPressed;

  const _NavButton({
    required this.label,
    required this.semanticLabel,
    required this.disabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: !disabled,
      label: semanticLabel,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: GestureDetector(
          onTap: disabled ? null : onPressed,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.mdAll,
              border: Border.all(color: AppColors.border),
            ),
            child: AppText(label,
                variant: AppTextVariant.subheading,
                color: disabled ? AppTextColor.subtle : AppTextColor.primary),
          ),
        ),
      ),
    );
  }
}
