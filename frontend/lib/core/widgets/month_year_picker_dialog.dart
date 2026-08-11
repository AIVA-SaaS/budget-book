/// Year → month → day drill-down picker used by `MonthNavigator`.
///
/// ## 왜 별도 다이얼로그인가 (2026-08-11)
///
/// 기존 `showCalendarPickerDialog` 의 `CalendarDatePicker` 는 연도 목록은 열리지만
/// **월 그리드가 없다** — 연도를 고르면 그 연도의 *같은 달* 일 그리드로 돌아오고,
/// 원하는 달까지 좌우로 넘겨야 한다. 그게 사용자가 지적한 결손 지점이다.
///
/// 그렇다고 `showCalendarPickerDialog` 를 고칠 수는 없다. 호출부 18곳 중 **17곳이
/// "특정 날짜 입력"이 본질**(거래·이체·보험·지출계획·카드정산 폼, 기간 필터 5곳, 포켓 시트 2곳)
/// 이라 월 우선으로 바꾸면 그쪽이 전부 퇴보한다. 그래서 월 이동 전용 피커를 따로 둔다.
///
/// **이 파일의 함수를 직접 호출하는 파일은 `month_navigator.dart` 하나여야 한다** —
/// 월 이동 UI 가 다시 페이지별로 갈라지는 것을 `month_navigator_single_source_guard_test.dart`
/// 가 막는다(하네스 `navigation_state`, 4회 재발).
library;

import 'package:flutter/material.dart';

/// 사용자가 피커에서 고른 값.
///
/// [day] 가 null 이면 **월까지만** 고른 것이다. 호출부가 "사용자가 실제로 일을 골랐는지"
/// 를 구분해야 하므로(거래 목록은 그때만 해당 날짜로 스크롤한다) `DateTime` 하나로
/// 뭉개지 않는다 — 1일 선택과 월 선택이 구별되지 않기 때문이다.
class MonthPickerResult {
  final int year;
  final int month;
  final int? day;

  const MonthPickerResult({
    required this.year,
    required this.month,
    this.day,
  });

  DateTime get date => DateTime(year, month, day ?? 1);
}

/// 연/월(선택적으로 일) 드릴다운 피커를 띄운다.
///
/// [allowDaySelection] 이 true 면 **일 그리드로 진입**하고(기존 사용감 유지),
/// 헤더를 눌러 월 → 연도로 올라갈 수 있다. false 면 **월 그리드로 진입**해
/// 달 선택이 1탭으로 끝난다.
Future<MonthPickerResult?> showMonthYearPickerDialog({
  required BuildContext context,
  required int initialYear,
  required int initialMonth,
  DateTime? firstDate,
  DateTime? lastDate,
  bool allowDaySelection = false,
}) {
  return showDialog<MonthPickerResult>(
    context: context,
    builder: (ctx) => _MonthYearPickerDialog(
      initialYear: initialYear,
      initialMonth: initialMonth,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: lastDate ?? DateTime(2030, 12, 31),
      allowDaySelection: allowDaySelection,
    ),
  );
}

enum _PickerStage { year, month, day }

/// 연도 그리드 한 페이지에 담는 연도 수 (3열 × 4행).
const int _yearsPerPage = 12;

class _MonthYearPickerDialog extends StatefulWidget {
  final int initialYear;
  final int initialMonth;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool allowDaySelection;

  const _MonthYearPickerDialog({
    required this.initialYear,
    required this.initialMonth,
    required this.firstDate,
    required this.lastDate,
    required this.allowDaySelection,
  });

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late _PickerStage _stage;

  /// 현재 화면이 다루는 연/월. 일 그리드에서는 표시 중인 달이기도 하다.
  late int _year;
  late int _month;

  /// 연도 그리드가 보여주는 12년 묶음의 첫 연도.
  late int _yearPageStart;

  /// 일 그리드에서 사용자가 마지막으로 고른 날짜.
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
    _selectedDay =
        _clampToRange(DateTime(widget.initialYear, widget.initialMonth));
    _yearPageStart = _pageStartFor(_year);
    _stage = widget.allowDaySelection ? _PickerStage.day : _PickerStage.month;
  }

  int get _firstYear => widget.firstDate.year;
  int get _lastYear => widget.lastDate.year;

  int _pageStartFor(int year) =>
      _firstYear + ((year - _firstYear) ~/ _yearsPerPage) * _yearsPerPage;

  DateTime _clampToRange(DateTime d) {
    if (d.isBefore(widget.firstDate)) return widget.firstDate;
    if (d.isAfter(widget.lastDate)) return widget.lastDate;
    return d;
  }

  bool _isMonthEnabled(int year, int month) {
    final monthStart = DateTime(year, month);
    final monthEnd = DateTime(year, month + 1, 0);
    return !monthEnd.isBefore(widget.firstDate) &&
        !monthStart.isAfter(widget.lastDate);
  }

  void _pickMonth(int year, int month) {
    if (widget.allowDaySelection) {
      setState(() {
        _year = year;
        _month = month;
        _selectedDay = _clampToRange(DateTime(year, month));
        _stage = _PickerStage.day;
      });
      return;
    }
    Navigator.pop(context, MonthPickerResult(year: year, month: month));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTitleBar(context),
            switch (_stage) {
              _PickerStage.year => _buildYearStage(context),
              _PickerStage.month => _buildMonthStage(context),
              _PickerStage.day => _buildDayStage(context),
            },
          ],
        ),
      ),
    );
  }

  String get _title => switch (_stage) {
        _PickerStage.year => '연도 선택',
        _PickerStage.month => '월 선택',
        _PickerStage.day => '날짜 선택',
      };

  Widget _buildTitleBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      child: Row(
        children: [
          Text(
            _title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => Navigator.pop(context),
            tooltip: '닫기',
          ),
        ],
      ),
    );
  }

  /// `‹ 라벨 ›` 헤더. 가운데 라벨은 상위 단계로 올라가는 버튼이다.
  Widget _buildStageHeader({
    required String label,
    required VoidCallback? onPrev,
    required VoidCallback? onNext,
    required VoidCallback? onLabelTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            tooltip: '이전',
          ),
          Expanded(
            child: TextButton(
              onPressed: onLabelTap,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (onLabelTap != null)
                    const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: '다음',
          ),
        ],
      ),
    );
  }

  Widget _buildYearStage(BuildContext context) {
    final pageEnd = _yearPageStart + _yearsPerPage - 1;
    final years = [
      for (var y = _yearPageStart; y <= pageEnd; y++)
        if (y >= _firstYear && y <= _lastYear) y,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStageHeader(
          label: '$_yearPageStart – $pageEnd',
          onPrev: _yearPageStart - _yearsPerPage >= _firstYear
              ? () => setState(() => _yearPageStart -= _yearsPerPage)
              : null,
          onNext: _yearPageStart + _yearsPerPage <= _lastYear
              ? () => setState(() => _yearPageStart += _yearsPerPage)
              : null,
          // 연도가 최상위 단계라 더 올라갈 곳이 없다.
          onLabelTap: null,
        ),
        _buildGrid(
          context,
          columns: 3,
          items: [
            for (final y in years)
              _GridCell(
                label: '$y년',
                selected: y == _year,
                outlined: y == DateTime.now().year,
                onTap: () => setState(() {
                  _year = y;
                  _stage = _PickerStage.month;
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthStage(BuildContext context) {
    final now = DateTime.now();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStageHeader(
          label: '$_year년',
          onPrev:
              _year - 1 >= _firstYear ? () => setState(() => _year -= 1) : null,
          onNext:
              _year + 1 <= _lastYear ? () => setState(() => _year += 1) : null,
          onLabelTap: () => setState(() {
            _yearPageStart = _pageStartFor(_year);
            _stage = _PickerStage.year;
          }),
        ),
        _buildGrid(
          context,
          columns: 3,
          items: [
            for (var m = 1; m <= 12; m++)
              _GridCell(
                label: '$m월',
                selected:
                    _year == widget.initialYear && m == widget.initialMonth,
                outlined: _year == now.year && m == now.month,
                onTap: _isMonthEnabled(_year, m)
                    ? () => _pickMonth(_year, m)
                    : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayStage(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextButton.icon(
              icon: const Icon(Icons.chevron_left, size: 20),
              label: const Text('월 선택으로'),
              onPressed: () => setState(() => _stage = _PickerStage.month),
            ),
          ),
        ),
        CalendarDatePicker(
          // 월 그리드에서 다른 달을 고르고 돌아오면 그 달로 다시 그려야 한다.
          key: ValueKey('$_year-$_month'),
          initialDate: _selectedDay,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          onDateChanged: (d) => _selectedDay = d,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                MonthPickerResult(
                  year: _selectedDay.year,
                  month: _selectedDay.month,
                  day: _selectedDay.day,
                ),
              ),
              child: const Text('선택'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(
    BuildContext context, {
    required int columns,
    required List<_GridCell> items,
  }) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += columns) {
      final slice = items.sublist(
        i,
        (i + columns) > items.length ? items.length : i + columns,
      );
      rows.add(Row(
        children: [
          for (final cell in slice) Expanded(child: cell),
          // 마지막 줄이 덜 찼을 때 칸 폭을 유지한다.
          for (var pad = slice.length; pad < columns; pad++)
            const Expanded(child: SizedBox.shrink()),
        ],
      ));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// 연도/월 그리드의 한 칸.
class _GridCell extends StatelessWidget {
  final String label;

  /// 현재 보고 있는 값 — 채워진 배경으로 표시.
  final bool selected;

  /// 오늘이 속한 값 — 테두리로 표시.
  final bool outlined;

  final VoidCallback? onTap;

  const _GridCell({
    required this.label,
    required this.selected,
    required this.outlined,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final disabled = onTap == null;

    final Color fg;
    if (disabled) {
      fg = scheme.onSurface.withValues(alpha: 0.38);
    } else if (selected) {
      fg = scheme.onPrimary;
    } else {
      fg = scheme.onSurface;
    }

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Material(
        color: selected ? scheme.primary : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: outlined && !selected
              ? BorderSide(color: scheme.primary, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
