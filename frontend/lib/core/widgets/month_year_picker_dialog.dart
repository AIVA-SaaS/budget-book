/// Unified year+month picker (with optional day grid) used by `MonthNavigator`.
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
/// ## 왜 프레임워크 위젯을 하나도 쓰지 않는가 (2026-08-11, 2차)
///
/// 1차 버전은 일 단계에서 `CalendarDatePicker` 를 그대로 썼다. 그 위젯의 헤더
/// (`2026년 8월 ▾`)는 **Material 이 소유**하고 눌리면 내부 연도 목록을 연다 — 숨기거나
/// 탭을 가로챌 공개 API 가 없다. 우리가 그 옆에 `월 선택으로` 버튼을 하나 더 붙였더니
/// **어포던스가 둘로 갈라져** 사용자가 내장 헤더를 먼저 눌렀고, "월 선택이 나와야 하는데
/// 연도 설정이 나온다" 는 결함이 됐다.
///
/// 그래서 이 파일은 **연·월·일 세 축을 전부 자체 위젯으로 그린다**. "우리가 개선한 경로
/// 옆에 프레임워크가 만든 다른 경로가 열려 있는" 상태 자체를 없앤 것이 구조적 수정이고,
/// `month_navigator_single_source_guard_test.dart` 가 *이 파일에 `CalendarDatePicker` 가
/// 없다* 를 소스 스캔으로 고정한다(하네스 `navigation_state`, STRUCTURAL_FIX_REQUIRED).
///
/// **이 파일의 함수를 직접 호출하는 파일은 `month_navigator.dart` 하나여야 한다** —
/// 월 이동 UI 가 다시 페이지별로 갈라지는 것을 같은 가드가 막는다.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../core/theme/bb_scale.dart';

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

/// 연/월(선택적으로 일) 피커를 띄운다.
///
/// 연도와 월은 **한 화면**에 있다 — 왼쪽 휠로 연도를 돌리면 오른쪽 12개월 그리드가
/// 즉시 그 연도 기준으로 바뀌고, 달을 한 번 누르면 확정된다(단계 전환 없음).
///
/// [allowDaySelection] 이 true 면 **일 그리드로 진입**하고(기존 사용감 유지),
/// 헤더의 `YYYY년 M월` 을 눌러 연/월 화면으로 올라갈 수 있다. false 면 연/월 화면으로
/// 진입해 달 선택이 1탭으로 끝난다.
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

/// 단계는 둘뿐이다. 연도는 월과 같은 화면에 있으므로 "연도 단계" 가 존재하지 않는다.
enum _PickerStage { monthYear, day }

/// 그리드 한 칸의 높이(칸 44 + 상하 여백 4).
const double _cellExtent = 52;

/// 월 그리드는 3열 × 4행이다. 연도 휠 높이를 여기에 맞춰 나란히 세운다.
const double _monthGridHeight = _cellExtent * 4;

/// 연도 휠 열의 폭.
const double _yearWheelWidth = 92;

const List<String> _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

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

  late FixedExtentScrollController _yearController;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
    _month = widget.initialMonth;
    _stage =
        widget.allowDaySelection ? _PickerStage.day : _PickerStage.monthYear;
    _yearController = FixedExtentScrollController(initialItem: _yearIndex);
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  int get _firstYear => widget.firstDate.year;
  int get _lastYear => widget.lastDate.year;

  List<int> get _years => [for (var y = _firstYear; y <= _lastYear; y++) y];

  int get _yearIndex => (_year - _firstYear).clamp(0, _years.length - 1);

  bool _isMonthEnabled(int year, int month) {
    final monthStart = DateTime(year, month);
    final monthEnd = DateTime(year, month + 1, 0);
    return !monthEnd.isBefore(widget.firstDate) &&
        !monthStart.isAfter(widget.lastDate);
  }

  bool _isDayEnabled(int day) {
    final d = DateTime(_year, _month, day);
    return !d.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
        !d.isAfter(DateUtils.dateOnly(widget.lastDate));
  }

  void _pickMonth(int month) {
    if (widget.allowDaySelection) {
      setState(() {
        _month = month;
        _stage = _PickerStage.day;
      });
      return;
    }
    Navigator.pop(context, MonthPickerResult(year: _year, month: month));
  }

  /// 일 그리드에서 연/월 화면으로 올라간다.
  ///
  /// 일 그리드의 `‹ ›` 로 해가 바뀌었을 수 있으므로 휠 컨트롤러를 현재 연도에 맞춰
  /// 다시 만든다. 이 시점에 휠은 트리에 없어(=컨트롤러 detached) dispose 가 안전하다.
  void _openMonthYearStage() {
    setState(() {
      _stage = _PickerStage.monthYear;
      _yearController.dispose();
      _yearController = FixedExtentScrollController(initialItem: _yearIndex);
    });
  }

  void _shiftMonth(int delta) {
    final shifted = DateTime(_year, _month + delta);
    setState(() {
      _year = shifted.year;
      _month = shifted.month;
    });
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
              _PickerStage.monthYear => _buildMonthYearStage(context),
              _PickerStage.day => _buildDayStage(context),
            },
          ],
        ),
      ),
    );
  }

  String get _title => switch (_stage) {
        _PickerStage.monthYear => '연/월 선택',
        _PickerStage.day => '날짜 선택',
      };

  Widget _buildTitleBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      child: Row(
        children: [
          Text(
            _title,
            style: TextStyle(fontSize: context.bbType.title, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, size: context.bbType.iconMd),
            onPressed: () => Navigator.pop(context),
            tooltip: '닫기',
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────── 연/월 한 화면 ───────────────────────────────

  Widget _buildMonthYearStage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: SizedBox(
        height: _monthGridHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: _yearWheelWidth, child: _buildYearWheel(context)),
            Expanded(child: _buildMonthGrid(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildYearWheel(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final years = _years;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 가운데 밴드 — "지금 이 값" 을 드러낸다. 스크롤을 가로채면 안 되므로 IgnorePointer.
        IgnorePointer(
          child: Container(
            height: 44,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        ScrollConfiguration(
          // Flutter 웹 기본 동작은 마우스 드래그 스크롤을 제외한다 — 보정하지 않으면
          // PC 에서 연도 휠이 마우스로 안 돌아간다.
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: ListWheelScrollView.useDelegate(
            controller: _yearController,
            itemExtent: 44,
            diameterRatio: 1.8,
            perspective: 0.004,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (index) =>
                setState(() => _year = years[index]),
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: years.length,
              builder: (ctx, index) {
                final y = years[index];
                final selected = y == _year;
                return _YearWheelItem(
                  year: y,
                  selected: selected,
                  isThisYear: y == DateTime.now().year,
                  // 가운데가 아닌 연도를 눌러도 선택되게 한다 — 휠만으로는 정밀도가 낮다.
                  onTap: selected
                      ? null
                      : () => _yearController.animateToItem(
                            index,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthGrid(BuildContext context) {
    final now = DateTime.now();
    return _buildGrid(
      columns: 3,
      children: [
        for (var m = 1; m <= 12; m++)
          _GridCell(
            label: '$m월',
            selected: _year == widget.initialYear && m == widget.initialMonth,
            outlined: _year == now.year && m == now.month,
            onTap: _isMonthEnabled(_year, m) ? () => _pickMonth(m) : null,
          ),
      ],
    );
  }

  // ──────────────────────────────── 일 그리드 ────────────────────────────────

  Widget _buildDayStage(BuildContext context) {
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(_year, _month);
    // Dart 의 weekday 는 월=1 … 일=7. 일요일 시작 그리드라 7 을 0 으로 접는다.
    final leadingBlanks = DateTime(_year, _month).weekday % 7;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStageHeader(
          context,
          label: '$_year년 $_month월',
          onPrev: _isMonthEnabled(DateTime(_year, _month - 1).year,
                  DateTime(_year, _month - 1).month)
              ? () => _shiftMonth(-1)
              : null,
          onNext: _isMonthEnabled(DateTime(_year, _month + 1).year,
                  DateTime(_year, _month + 1).month)
              ? () => _shiftMonth(1)
              : null,
          onLabelTap: _openMonthYearStage,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final w in _weekdayLabels)
                Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: _buildGrid(
            columns: 7,
            children: [
              for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++)
                _GridCell(
                  label: '$d',
                  semanticLabel: '$_month월 $d일',
                  selected: false,
                  outlined:
                      now.year == _year && now.month == _month && now.day == d,
                  // 월과 마찬가지로 1탭이 곧 확정이다 — 별도 확인 버튼을 두지 않는다.
                  onTap: _isDayEnabled(d)
                      ? () => Navigator.pop(
                            context,
                            MonthPickerResult(
                                year: _year, month: _month, day: d),
                          )
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// `‹ 라벨 ›` 헤더. 가운데 라벨은 연/월 화면으로 올라가는 버튼이다.
  Widget _buildStageHeader(
    BuildContext context, {
    required String label,
    required VoidCallback? onPrev,
    required VoidCallback? onNext,
    required VoidCallback onLabelTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
            tooltip: '이전 달',
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
                  Icon(Icons.arrow_drop_up, size: context.bbType.iconSm),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
            tooltip: '다음 달',
          ),
        ],
      ),
    );
  }

  Widget _buildGrid({required int columns, required List<Widget> children}) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final slice = children.sublist(
        i,
        (i + columns) > children.length ? children.length : i + columns,
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
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }
}

/// 연도 휠의 한 항목.
class _YearWheelItem extends StatelessWidget {
  final int year;
  final bool selected;
  final bool isThisYear;
  final VoidCallback? onTap;

  const _YearWheelItem({
    required this.year,
    required this.selected,
    required this.isThisYear,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '$year',
            style: TextStyle(
              fontSize: selected ? 18 : 15,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.55),
              decoration:
                  isThisYear && !selected ? TextDecoration.underline : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// 월/일 그리드의 한 칸.
class _GridCell extends StatelessWidget {
  final String label;

  /// 현재 보고 있는 값 — 채워진 배경으로 표시.
  final bool selected;

  /// 오늘이 속한 값 — 테두리로 표시.
  final bool outlined;

  /// 스크린리더용 라벨. 일 그리드는 숫자만 나오므로 달을 붙여준다.
  final String? semanticLabel;

  final VoidCallback? onTap;

  const _GridCell({
    required this.label,
    required this.selected,
    required this.outlined,
    required this.onTap,
    this.semanticLabel,
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
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  semanticsLabel: semanticLabel,
                  style: TextStyle(
                    color: fg,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
