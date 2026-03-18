import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Period type enum for budget period selection.
enum PeriodType { none, daily, weekly, monthly }

/// Represents a selected period with type and optional date range.
class PeriodSelection {
  final PeriodType type;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? year;
  final int? month;

  const PeriodSelection({
    required this.type,
    this.startDate,
    this.endDate,
    this.year,
    this.month,
  });

  /// Converts PeriodType to the API string value.
  String get periodTypeString => switch (type) {
        PeriodType.none => 'NONE',
        PeriodType.daily => 'DAILY',
        PeriodType.weekly => 'WEEKLY',
        PeriodType.monthly => 'MONTHLY',
      };

  /// Creates a PeriodSelection from API string values.
  factory PeriodSelection.fromApiValues({
    required String periodType,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final type = switch (periodType) {
      'NONE' => PeriodType.none,
      'DAILY' => PeriodType.daily,
      'WEEKLY' => PeriodType.weekly,
      _ => PeriodType.monthly,
    };
    return PeriodSelection(
      type: type,
      startDate: startDate,
      endDate: endDate,
      year: startDate?.year,
      month: startDate?.month,
    );
  }
}

/// Calculates week ranges for a given year and month.
/// Week 1: 1~7, Week 2: 8~14, Week 3: 15~21, Week 4: 22~28, Week 5: 29~lastDay.
List<(DateTime, DateTime)> calculateWeekRanges(int year, int month) {
  final lastDay = DateTime(year, month + 1, 0).day;
  const weekStarts = [1, 8, 15, 22, 29];
  final ranges = <(DateTime, DateTime)>[];
  for (final start in weekStarts) {
    if (start > lastDay) break;
    final end = (start + 6 <= lastDay) ? start + 6 : lastDay;
    ranges.add((DateTime(year, month, start), DateTime(year, month, end)));
  }
  return ranges;
}

/// Shared period selector widget with type toggle and date range inputs.
/// Used in budget form and any feature needing period selection.
class PeriodSelector extends StatefulWidget {
  final PeriodSelection initialSelection;
  final ValueChanged<PeriodSelection> onChanged;
  final bool enabled;

  const PeriodSelector({
    super.key,
    required this.initialSelection,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  late PeriodType _selectedType;
  DateTime? _startDate;
  DateTime? _endDate;
  late int _weekYear;
  late int _weekMonth;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialSelection.type;
    _startDate = widget.initialSelection.startDate;
    _endDate = widget.initialSelection.endDate;
    _weekYear = widget.initialSelection.year ?? DateTime.now().year;
    _weekMonth = widget.initialSelection.month ?? DateTime.now().month;
  }

  void _emitChange() {
    widget.onChanged(PeriodSelection(
      type: _selectedType,
      startDate: _startDate,
      endDate: _endDate,
      year: _selectedType == PeriodType.weekly ? _weekYear : null,
      month: _selectedType == PeriodType.weekly ? _weekMonth : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Period type segmented button
        _buildTypeSelector(context),
        const SizedBox(height: 16),
        // Conditional UI based on selected type
        _buildTypeSpecificUI(context),
      ],
    );
  }

  Widget _buildTypeSelector(BuildContext context) {
    return SegmentedButton<PeriodType>(
      segments: const [
        ButtonSegment(
          value: PeriodType.none,
          label: Text('없음'),
          icon: Icon(Icons.block, size: 16),
        ),
        ButtonSegment(
          value: PeriodType.daily,
          label: Text('일별'),
          icon: Icon(Icons.today, size: 16),
        ),
        ButtonSegment(
          value: PeriodType.weekly,
          label: Text('주간'),
          icon: Icon(Icons.date_range, size: 16),
        ),
        ButtonSegment(
          value: PeriodType.monthly,
          label: Text('월별'),
          icon: Icon(Icons.calendar_month, size: 16),
        ),
      ],
      selected: {_selectedType},
      onSelectionChanged: widget.enabled
          ? (selection) {
              setState(() {
                _selectedType = selection.first;
                // Reset dates when switching types
                _startDate = null;
                _endDate = null;
              });
              _emitChange();
            }
          : null,
    );
  }

  Widget _buildTypeSpecificUI(BuildContext context) {
    return switch (_selectedType) {
      PeriodType.none => _buildNoneUI(context),
      PeriodType.daily => _buildDailyUI(context),
      PeriodType.weekly => _buildWeeklyUI(context),
      PeriodType.monthly => _buildMonthlyUI(context),
    };
  }

  Widget _buildNoneUI(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              '기간 미지정',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyUI(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return Column(
      children: [
        // Start date
        _buildDateTile(
          context,
          label: '시작일',
          icon: Icons.event,
          date: _startDate,
          dateFormat: dateFormat,
          onTap: widget.enabled
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030, 12, 31),
                  );
                  if (picked != null) {
                    setState(() => _startDate = picked);
                    _emitChange();
                  }
                }
              : null,
        ),
        const SizedBox(height: 8),
        // End date
        _buildDateTile(
          context,
          label: '종료일',
          icon: Icons.event,
          date: _endDate,
          dateFormat: dateFormat,
          onTap: widget.enabled
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        _endDate ?? _startDate ?? DateTime.now(),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime(2030, 12, 31),
                  );
                  if (picked != null) {
                    setState(() => _endDate = picked);
                    _emitChange();
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildWeeklyUI(BuildContext context) {
    final monthStr = DateFormat('yyyy년 M월')
        .format(DateTime(_weekYear, _weekMonth));
    final weekRanges = calculateWeekRanges(_weekYear, _weekMonth);
    final dayFormat = DateFormat('M/d');

    return Column(
      children: [
        // Month navigator for weekly
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: widget.enabled
                  ? () {
                      setState(() {
                        if (_weekMonth == 1) {
                          _weekYear--;
                          _weekMonth = 12;
                        } else {
                          _weekMonth--;
                        }
                      });
                      _emitChange();
                    }
                  : null,
              tooltip: '이전 달',
            ),
            TextButton(
              onPressed: widget.enabled
                  ? () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime(_weekYear, _weekMonth),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030, 12, 31),
                      );
                      if (picked != null) {
                        setState(() {
                          _weekYear = picked.year;
                          _weekMonth = picked.month;
                        });
                        _emitChange();
                      }
                    }
                  : null,
              child: Text(
                monthStr,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: widget.enabled
                  ? () {
                      setState(() {
                        if (_weekMonth == 12) {
                          _weekYear++;
                          _weekMonth = 1;
                        } else {
                          _weekMonth++;
                        }
                      });
                      _emitChange();
                    }
                  : null,
              tooltip: '다음 달',
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Week breakdown preview
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '주차별 기간',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                ...weekRanges.asMap().entries.map((entry) {
                  final weekNum = entry.key + 1;
                  final (start, end) = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            '$weekNum주차:',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Text(
                          '${dayFormat.format(start)} ~ ${dayFormat.format(end)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyUI(BuildContext context) {
    final dateFormat = DateFormat('yyyy년 M월');
    return Column(
      children: [
        // Start month
        _buildDateTile(
          context,
          label: '시작월',
          icon: Icons.calendar_month,
          date: _startDate,
          dateFormat: dateFormat,
          onTap: widget.enabled
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030, 12, 31),
                  );
                  if (picked != null) {
                    setState(() {
                      _startDate =
                          DateTime(picked.year, picked.month);
                    });
                    _emitChange();
                  }
                }
              : null,
        ),
        const SizedBox(height: 8),
        // End month
        _buildDateTile(
          context,
          label: '종료월',
          icon: Icons.calendar_month,
          date: _endDate,
          dateFormat: dateFormat,
          onTap: widget.enabled
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate ??
                        _startDate ??
                        DateTime.now(),
                    firstDate: _startDate ?? DateTime(2020),
                    lastDate: DateTime(2030, 12, 31),
                  );
                  if (picked != null) {
                    setState(() {
                      _endDate =
                          DateTime(picked.year, picked.month);
                    });
                    _emitChange();
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildDateTile(
    BuildContext context, {
    required String label,
    required IconData icon,
    required DateTime? date,
    required DateFormat dateFormat,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          date != null ? dateFormat.format(date) : '선택하세요',
          style: date == null
              ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )
              : null,
        ),
      ),
    );
  }
}
