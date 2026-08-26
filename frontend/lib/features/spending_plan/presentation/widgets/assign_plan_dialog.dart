import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';
import '../../../../core/theme/bb_scale.dart';

/// Result returned from the assign plan dialog.
class AssignResult {
  final String targetDate;
  final int? weekNumber;
  final String? budgetId;

  const AssignResult({
    required this.targetDate,
    this.weekNumber,
    this.budgetId,
  });
}

/// Shows a dialog to assign a wishlist plan to a specific date.
Future<AssignResult?> showAssignPlanDialog(
  BuildContext context,
  SpendingPlan plan,
) {
  return showDialog<AssignResult>(
    context: context,
    builder: (ctx) => _AssignPlanDialog(plan: plan),
  );
}

class _AssignPlanDialog extends StatefulWidget {
  final SpendingPlan plan;

  const _AssignPlanDialog({required this.plan});

  @override
  State<_AssignPlanDialog> createState() => _AssignPlanDialogState();
}

class _AssignPlanDialogState extends State<_AssignPlanDialog> {
  DateTime? _selectedDate;
  String? _budgetId;

  @override
  void initState() {
    super.initState();
    // Ensure budgets are loaded for the budget selector
    final budgetBloc = getIt<BudgetBloc>();
    if (budgetBloc.state is! BudgetLoaded) {
      final now = DateTime.now();
      budgetBloc.add(LoadBudgets(year: now.year, month: now.month));
    }
  }

  List<Budget> get _budgets {
    final budgetState = getIt<BudgetBloc>().state;
    return budgetState is BudgetLoaded ? budgetState.budgets : [];
  }

  /// Calculate week number (1-based) for a given date within its month.
  int _weekNumber(DateTime date) {
    return ((date.day - 1) ~/ 7) + 1;
  }

  void _selectQuickOption(int daysOffset) {
    final now = DateTime.now();
    // "This week" = next occurrence of the same weekday or today
    DateTime target;
    if (daysOffset == 0) {
      // This week: find next Sunday (end of this week) or just use today + remaining days
      final daysUntilSunday = DateTime.sunday - now.weekday;
      target = now.add(Duration(days: daysUntilSunday <= 0 ? 0 : 0));
      // Just use today for "this week"
      target = now;
    } else {
      target = now.add(Duration(days: daysOffset));
    }
    setState(() => _selectedDate = target);
  }

  Future<void> _selectCustomDate() async {
    final picked = await showCalendarPickerDialog(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    if (_selectedDate == null) return;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
    Navigator.of(context).pop(AssignResult(
      targetDate: dateStr,
      weekNumber: _weekNumber(_selectedDate!),
      budgetId: _budgetId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    return AlertDialog(
      title: const Text('언제 구매할 예정인가요?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.plan.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.plan.priceRangeText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),

            // Quick options
            Text(
              '빠른 선택',
              style: theme.textTheme.labelMedium,
            ),
            context.bbSpace.gapV(BbSpaceToken.lg),
            Wrap(
              spacing: 8,
              children: [
                _QuickChip(
                  label: '이번 주',
                  selected: _selectedDate != null &&
                      _selectedDate!.difference(now).inDays <= (7 - now.weekday),
                  onTap: () => _selectQuickOption(0),
                ),
                _QuickChip(
                  label: '다음 주',
                  selected: false,
                  onTap: () {
                    final daysUntilNextMonday = (DateTime.monday - now.weekday + 7) % 7;
                    final target = daysUntilNextMonday == 0 ? 7 : daysUntilNextMonday;
                    setState(() => _selectedDate = now.add(Duration(days: target)));
                  },
                ),
                _QuickChip(
                  label: '2주 후',
                  selected: false,
                  onTap: () {
                    setState(() => _selectedDate = now.add(const Duration(days: 14)));
                  },
                ),
              ],
            ),
            context.bbSpace.gapV(BbSpaceToken.xl),

            // Custom date picker
            OutlinedButton.icon(
              onPressed: _selectCustomDate,
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(_selectedDate != null
                  ? DateFormat('yyyy년 M월 d일', 'ko').format(_selectedDate!)
                  : '날짜 직접 선택'),
            ),
            context.bbSpace.gapV(BbSpaceToken.xxl),

            // Budget selection
            if (_budgets.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: _budgetId,
                decoration: const InputDecoration(
                  labelText: '예산 연결 (선택)',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                  isDense: true,
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('선택 안 함'),
                  ),
                  ..._budgets.map((b) => DropdownMenuItem(
                        value: b.id,
                        child: Text(
                          b.category?.name != null
                              ? '${b.category!.name} (${CurrencyFormatter.format(b.amount)}원)'
                              : '${b.yearMonth} (${CurrencyFormatter.format(b.amount)}원)',
                        ),
                      )),
                ],
                onChanged: (value) => setState(() => _budgetId = value),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _selectedDate != null ? _submit : null,
          child: const Text('배정하기'),
        ),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _QuickChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : null,
    );
  }
}
