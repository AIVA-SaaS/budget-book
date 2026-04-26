import 'package:flutter/material.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/calculator_amount_field.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category_group/domain/entities/category_group.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/ui_helpers.dart';
import 'package:budget_book/core/widgets/hierarchical_selector_sheet.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
import 'package:budget_book/core/widgets/period_selector.dart';

class BudgetFormPage extends StatefulWidget {
  /// If editing, pass the budget ID (from URL path parameter).
  /// The page will find the budget from the BudgetBloc's loaded state.
  final String? budgetId;
  final int year;
  final int month;

  const BudgetFormPage({
    super.key,
    this.budgetId,
    required this.year,
    required this.month,
  });

  @override
  State<BudgetFormPage> createState() => _BudgetFormPageState();
}

class _BudgetFormPageState extends State<BudgetFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _weeklyAmountController;
  String _amountHint = '';
  String _weeklyAmountHint = '';
  final _groupNameController = TextEditingController();
  final _categoryNameController = TextEditingController();
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _selectedGroupId;
  String? _selectedGroupName;
  String? _selectedPocketId;
  late int _selectedYear;
  late int _selectedMonth;
  late String _budgetPeriod;
  late PeriodSelection _periodSelection;
  bool _initialized = false;
  bool _isSubmitting = false;
  bool _isDeleting = false;
  bool _applyToFuture = false;

  bool get isEditing => widget.budgetId != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _amountController.addListener(_updateAmountHint);
    _weeklyAmountController = TextEditingController();
    _weeklyAmountController.addListener(_updateWeeklyAmountHint);
    _selectedYear = widget.year;
    _selectedMonth = widget.month;
    _budgetPeriod = 'MONTHLY';
    _periodSelection = const PeriodSelection(type: PeriodType.none);
    // Load category groups for the selector
    getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
  }

  void _initializeFromBudget(Budget budget) {
    if (_initialized) return;
    _initialized = true;
    _amountController.text = CurrencyFormatter.format(budget.amount);
    _weeklyAmountController.text =
        budget.weeklyAmount != null ? CurrencyFormatter.format(budget.weeklyAmount!) : '';
    _selectedCategoryId = budget.category?.id;
    _selectedCategoryName = budget.category != null && budget.groupName != null
        ? '${budget.groupName} > ${budget.category!.name}'
        : budget.category?.name;
    _selectedGroupId = budget.category != null ? null : budget.groupId;
    _selectedGroupName = budget.category != null ? null : budget.groupName;
    _selectedPocketId = budget.pocketId;
    _budgetPeriod = budget.budgetPeriod;
    _periodSelection = PeriodSelection.fromApiValues(
      periodType: budget.periodType,
      startDate: budget.startDate,
      endDate: budget.endDate,
    );
  }

  @override
  void dispose() {
    _amountController.removeListener(_updateAmountHint);
    _amountController.dispose();
    _weeklyAmountController.removeListener(_updateWeeklyAmountHint);
    _weeklyAmountController.dispose();
    _groupNameController.dispose();
    _categoryNameController.dispose();
    super.dispose();
  }

  void _updateAmountHint() {
    final parsed = CurrencyFormatter.parse(_amountController.text);
    final hint = (parsed != null && parsed >= 10000)
        ? CurrencyFormatter.toKoreanUnit(parsed)
        : '';
    if (hint != _amountHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _amountHint = hint);
      });
    }
  }

  void _updateWeeklyAmountHint() {
    final parsed = CurrencyFormatter.parse(_weeklyAmountController.text);
    final hint = (parsed != null && parsed >= 10000)
        ? CurrencyFormatter.toKoreanUnit(parsed)
        : '';
    if (hint != _weeklyAmountHint) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _weeklyAmountHint = hint);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '예산 수정' : '예산 추가'),
        actions: [
          if (isEditing)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              tooltip: '삭제',
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: BlocConsumer<BudgetBloc, BudgetState>(
        listener: (context, state) {
          if (state is BudgetLoaded && state.operationError != null) {
            setState(() {
              _isSubmitting = false;
              _isDeleting = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is BudgetLoaded && _isDeleting) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('삭제되었습니다')),
            );
            context.pop();
          } else if (state is BudgetLoaded && _isSubmitting) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isEditing ? '수정되었습니다' : '저장되었습니다')),
            );
            context.pop();
          } else if (state is BudgetError) {
            setState(() {
              _isSubmitting = false;
              _isDeleting = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        },
        builder: (context, state) {
          // For editing: find the budget from the loaded list
          if (isEditing && state is BudgetLoaded && !_initialized) {
            final found = state.budgets.where(
              (b) => b.id == widget.budgetId,
            );
            if (found.isNotEmpty) {
              _initializeFromBudget(found.first);
            } else {
              return Center(
                child: Text('예산을 찾을 수 없습니다 (ID: ${widget.budgetId})'),
              );
            }
          }

          if (isEditing && state is BudgetLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildForm(context);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Period selector (replaces old month selector + budget period dropdown)
            Text(
              '예산 기간',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            PeriodSelector(
              initialSelection: _periodSelection,
              enabled: true,
              onChanged: (selection) {
                setState(() {
                  _periodSelection = selection;
                  // Sync budgetPeriod for backward compatibility
                  _budgetPeriod = switch (selection.type) {
                    PeriodType.weekly => 'WEEKLY',
                    _ => 'MONTHLY',
                  };
                  // Update selected year/month based on period type
                  if (selection.type == PeriodType.weekly &&
                      selection.year != null &&
                      selection.month != null) {
                    _selectedYear = selection.year!;
                    _selectedMonth = selection.month!;
                  } else if (selection.startDate != null) {
                    _selectedYear = selection.startDate!.year;
                    _selectedMonth = selection.startDate!.month;
                  }
                });
              },
            ),
            const SizedBox(height: 24),
            // Category / Group selector (optional)
            _buildCategoryPicker(context),
            const SizedBox(height: 16),
            // Pocket selector (optional)
            BlocBuilder<PocketBloc, PocketState>(
              builder: (context, pocketState) {
                final pockets = pocketState is PocketLoaded
                    ? pocketState.pockets
                    : <MoneyPocket>[];

                final selectedName = _selectedPocketId != null
                    ? pockets
                        .where((p) => p.id == _selectedPocketId)
                        .map((p) => p.name)
                        .firstOrNull
                    : null;

                return ItemSelectorField(
                  label: '포켓 (선택)',
                  selectedLabel: selectedName,
                  prefixIcon: Icons.account_balance_wallet,
                  placeholder: '포켓 미지정',
                  onTap: () => _showPocketSelectorSheet(context, pockets),
                );
              },
            ),
            const SizedBox(height: 16),
            // Amount input - show different field based on period
            if (_budgetPeriod == 'WEEKLY')
              CalculatorAmountField(
                controller: _weeklyAmountController,
                decoration: const InputDecoration(
                  labelText: '주간 예산 금액',
                  suffixText: '원',
                  prefixIcon: Icon(Icons.date_range),
                ),
                helperText: _weeklyAmountHint.isNotEmpty ? _weeklyAmountHint : null,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '주간 예산 금액을 입력하세요';
                  }
                  final amount = CurrencyFormatter.parse(value);
                  if (amount == null || amount <= 0) {
                    return '0보다 큰 금액을 입력하세요';
                  }
                  return null;
                },
              )
            else
              CalculatorAmountField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: '예산 금액',
                  suffixText: '원',
                  prefixIcon: Icon(Icons.payments),
                ),
                helperText: _amountHint.isNotEmpty ? _amountHint : null,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '금액을 입력하세요';
                  }
                  final amount = CurrencyFormatter.parse(value);
                  if (amount == null || amount <= 0) {
                    return '0보다 큰 금액을 입력하세요';
                  }
                  return null;
                },
              ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: const Text('이후 모든 일정에 반영'),
              subtitle: Text(
                isEditing
                    ? '체크 안 함: 이번 달만 변경 (미래 일정 보존)\n체크 함: 이번 달부터 미래 모든 달에 적용'
                    : '체크 안 함: 이번 달만 적용\n체크 함: 이번 달부터 미래 모든 달 자동 적용',
                style: const TextStyle(fontSize: 12),
              ),
              value: _applyToFuture,
              onChanged: (v) => setState(() => _applyToFuture = v ?? false),
            ),
            const SizedBox(height: 32),
            // Submit button
            FilledButton(
              onPressed: _isSubmitting ? null : _onSubmit,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPicker(BuildContext context) {
    // Display selected target label
    final String? selectedLabel;
    if (_selectedGroupId != null && _selectedGroupName != null) {
      selectedLabel = '$_selectedGroupName (그룹)';
    } else if (_selectedCategoryId != null && _selectedCategoryName != null) {
      selectedLabel = _selectedCategoryName;
    } else if (_selectedCategoryId != null) {
      // Try to resolve name from CategoryBloc
      final catState = context.read<CategoryBloc>().state;
      if (catState is CategoryLoaded) {
        selectedLabel = catState.expenseCategories
            .where((c) => c.id == _selectedCategoryId)
            .map((c) => c.name)
            .firstOrNull;
      } else {
        selectedLabel = null;
      }
    } else {
      selectedLabel = null;
    }

    return ItemSelectorField(
      label: '카테고리 (선택)',
      selectedLabel: selectedLabel,
      prefixIcon: Icons.category,
      placeholder: '전체 예산 (카테고리/그룹 없음)',
      onTap: () => _showCategorySelectorSheet(context),
    );
  }

  void _showCategorySelectorSheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider<CategoryGroupBloc>.value(
            value: getIt<CategoryGroupBloc>(),
          ),
          BlocProvider<CategoryBloc>.value(
            value: getIt<CategoryBloc>(),
          ),
        ],
        child: BlocBuilder<CategoryGroupBloc, CategoryGroupState>(
          builder: (sheetContext, groupState) {
            if (groupState is! CategoryGroupLoaded) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return HierarchicalSelectorSheet<CategoryGroup, Category>(
              groups: groupState.groups,
              itemsOf: (g) =>
                  g.categories.where((c) => c.type == 'EXPENSE').toList(),
              groupLabel: (g) => g.name,
              itemLabel: (c) => c.name,
              groupColor: (g) => UIHelpers.parseColor(g.color),
              itemColor: (c) => UIHelpers.parseColor(c.color),
              groupId: (g) => g.id,
              itemId: (c) => c.id,
              groupSelectable: true,
              selectedGroupId: _selectedGroupId,
              selectedItemId: _selectedCategoryId,
              onGroupSelected: (group) {
                setState(() {
                  _selectedGroupId = group.id;
                  _selectedGroupName = group.name;
                  _selectedCategoryId = null;
                  _selectedCategoryName = null;
                });
              },
              onItemSelected: (category) {
                setState(() {
                  _selectedCategoryId = category.id;
                  _selectedCategoryName = category.name;
                  _selectedGroupId = null;
                  _selectedGroupName = null;
                });
              },
              onItemSelectedWithGroup: (category, group) {
                setState(() {
                  _selectedCategoryId = category.id;
                  _selectedCategoryName = '${group.name} > ${category.name}';
                  _selectedGroupId = null;
                  _selectedGroupName = null;
                });
              },
              onAddGroup: () => _showAddGroupDialog(sheetContext),
              onAddItem: (group) =>
                  _showAddCategoryDialog(sheetContext, group),
              onDeleteItem: (category) =>
                  _confirmDeleteCategory(sheetContext, category),
              title: '카테고리 선택',
            );
          },
        ),
      ),
    );
  }

  Future<void> _showAddGroupDialog(BuildContext context) async {
    _groupNameController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('그룹 추가'),
        content: TextField(
          controller: _groupNameController,
          decoration: const InputDecoration(hintText: '그룹 이름'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final text = _groupNameController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(dialogContext).pop(text);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (name != null) {
      getIt<CategoryGroupBloc>().add(CreateCategoryGroup(name: name));
    }
  }

  Future<void> _showAddCategoryDialog(
      BuildContext context, CategoryGroup group) async {
    _categoryNameController.clear();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${group.name} - 카테고리 추가'),
        content: TextField(
          controller: _categoryNameController,
          decoration: const InputDecoration(hintText: '카테고리 이름'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final text = _categoryNameController.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(dialogContext).pop(text);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (name != null) {
      getIt<CategoryBloc>().add(CreateCategory(
        name: name,
        type: 'EXPENSE',
        groupId: group.id,
      ));
      // Reload groups to reflect new category
      getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
    }
  }

  Future<void> _confirmDeleteCategory(
      BuildContext context, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('카테고리 삭제'),
        content: Text("'${category.name}'을(를) 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (_selectedCategoryId == category.id) {
        setState(() {
          _selectedCategoryId = null;
          _selectedCategoryName = null;
        });
      }
      getIt<CategoryBloc>().add(DeleteCategory(category.id));
      getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
    }
  }

  void _showPocketSelectorSheet(
      BuildContext context, List<MoneyPocket> pockets) {
    showDialog(
      context: context,
      builder: (_) => ItemSelectorSheet(
        title: '포켓 선택',
        items: pockets
            .map((p) => SelectorItem(
                  id: p.id,
                  label: p.name,
                  leadingIcon: Icons.account_balance_wallet,
                ))
            .toList(),
        selectedId: _selectedPocketId,
        nullLabel: '포켓 미지정',
        onSelected: (item) {
          setState(() => _selectedPocketId = item?.id);
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    bool applyToFutureInDialog = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('삭제'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('이 예산을 삭제하시겠습니까?'),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text('이후 모든 일정에 반영'),
                value: applyToFutureInDialog,
                onChanged: (v) => setStateDialog(() => applyToFutureInDialog = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _isDeleting = true);
                this.context.read<BudgetBloc>().add(
                      DeleteBudget(widget.budgetId!,
                          applyToFuture: applyToFutureInDialog),
                    );
              },
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('삭제'),
            ),
          ],
        ),
      ),
    );
  }

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSubmitting = true);
      final int amount;
      final int? weeklyAmount;
      if (_budgetPeriod == 'WEEKLY') {
        final weekly = CurrencyFormatter.parse(_weeklyAmountController.text.trim())!;
        weeklyAmount = weekly;
        // Monthly amount = weekly * 4 (approximate)
        amount = _amountController.text.trim().isNotEmpty
            ? CurrencyFormatter.parse(_amountController.text.trim())!
            : weekly * 4;
      } else {
        amount = CurrencyFormatter.parse(_amountController.text.trim())!;
        weeklyAmount = null;
      }

      // Derive yearMonth based on period type
      final String yearMonth;
      switch (_periodSelection.type) {
        case PeriodType.weekly:
          yearMonth =
              '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
        case PeriodType.daily:
        case PeriodType.monthly:
          if (_periodSelection.startDate != null) {
            final sd = _periodSelection.startDate!;
            yearMonth =
                '${sd.year}-${sd.month.toString().padLeft(2, '0')}';
          } else {
            yearMonth =
                '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
          }
        case PeriodType.none:
          yearMonth =
              '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      }

      final periodType = _periodSelection.periodTypeString;
      final bloc = context.read<BudgetBloc>();

      if (isEditing) {
        bloc.add(UpdateBudget(
          id: widget.budgetId!,
          amount: amount,
          budgetPeriod: _budgetPeriod,
          weeklyAmount: weeklyAmount,
          pocketId: _selectedPocketId,
          periodType: periodType,
          startDate: _periodSelection.startDate,
          endDate: _periodSelection.endDate,
          categoryId: _selectedCategoryId,
          groupId: _selectedGroupId,
          yearMonth: yearMonth,
          applyToFuture: _applyToFuture,
        ));
      } else {
        bloc.add(CreateBudget(
          categoryId: _selectedCategoryId,
          groupId: _selectedGroupId,
          yearMonth: yearMonth,
          amount: amount,
          budgetPeriod: _budgetPeriod,
          weeklyAmount: weeklyAmount,
          pocketId: _selectedPocketId,
          periodType: periodType,
          startDate: _periodSelection.startDate,
          endDate: _periodSelection.endDate,
          applyToFuture: _applyToFuture,
        ));
      }
    }
  }
}
