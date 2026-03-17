import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_event.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category/presentation/widgets/category_form_sheet.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';

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
  String? _selectedCategoryId;
  String? _selectedPocketId;
  late int _selectedYear;
  late int _selectedMonth;
  late String _budgetPeriod;
  Budget? _budget;
  bool _initialized = false;
  bool _isSubmitting = false;
  int _dropdownResetKey = 0;

  bool get isEditing => widget.budgetId != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _weeklyAmountController = TextEditingController();
    _selectedYear = widget.year;
    _selectedMonth = widget.month;
    _budgetPeriod = 'MONTHLY';
  }

  void _initializeFromBudget(Budget budget) {
    if (_initialized) return;
    _initialized = true;
    _budget = budget;
    _amountController.text = budget.amount.toString();
    _weeklyAmountController.text =
        budget.weeklyAmount != null ? budget.weeklyAmount.toString() : '';
    _selectedCategoryId = budget.category?.id;
    _selectedPocketId = budget.pocketId;
    _budgetPeriod = budget.budgetPeriod;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _weeklyAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '예산 수정' : '예산 추가'),
      ),
      body: BlocConsumer<BudgetBloc, BudgetState>(
        listener: (context, state) {
          if (state is BudgetLoaded && state.operationError != null) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is BudgetLoaded && _isSubmitting) {
            // After successful create or update, pop back to budget list
            context.pop();
          } else if (state is BudgetError) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
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
            // Year/Month display
            _buildMonthSelector(context),
            const SizedBox(height: 24),
            // Category selector (optional)
            if (!isEditing) ...[
              _buildCategoryPicker(context),
              const SizedBox(height: 16),
            ],
            if (isEditing) ...[
              ListTile(
                leading: const Icon(Icons.category),
                title: Text(
                    _budget?.category?.name ?? '전체 예산'),
                subtitle: const Text('카테고리는 수정할 수 없습니다'),
                tileColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
            ],
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
            // Budget period selector
            DropdownButtonFormField<String>(
              initialValue: _budgetPeriod,
              decoration: const InputDecoration(
                labelText: '예산 기간',
                prefixIcon: Icon(Icons.schedule),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'MONTHLY', child: Text('월간')),
                DropdownMenuItem(
                    value: 'WEEKLY', child: Text('주간')),
              ],
              onChanged: isEditing
                  ? null
                  : (value) {
                      setState(() {
                        _budgetPeriod = value ?? 'MONTHLY';
                      });
                    },
            ),
            const SizedBox(height: 16),
            // Amount input - show different field based on period
            if (_budgetPeriod == 'WEEKLY')
              TextFormField(
                controller: _weeklyAmountController,
                decoration: const InputDecoration(
                  labelText: '주간 예산 금액',
                  suffixText: '원',
                  prefixIcon: Icon(Icons.date_range),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '주간 예산 금액을 입력하세요';
                  }
                  final amount = int.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return '0보다 큰 금액을 입력하세요';
                  }
                  return null;
                },
              )
            else
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: '예산 금액',
                  suffixText: '원',
                  prefixIcon: Icon(Icons.payments),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '금액을 입력하세요';
                  }
                  final amount = int.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return '0보다 큰 금액을 입력하세요';
                  }
                  return null;
                },
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
                  : Text(isEditing ? '수정' : '추가'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    final dateStr =
        DateFormat('yyyy년 M월').format(DateTime(_selectedYear, _selectedMonth));

    if (isEditing) {
      return ListTile(
        leading: const Icon(Icons.calendar_month),
        title: Text(dateStr),
        subtitle: const Text('기간은 수정할 수 없습니다'),
        tileColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      );
    }

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime(_selectedYear, _selectedMonth),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030, 12, 31),
        );
        if (picked != null) {
          setState(() {
            _selectedYear = picked.year;
            _selectedMonth = picked.month;
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '기간',
          prefixIcon: Icon(Icons.calendar_month),
        ),
        child: Text(dateStr),
      ),
    );
  }

  Widget _buildCategoryPicker(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, catState) {
        final categories = catState is CategoryLoaded
            ? catState.expenseCategories
            : <Category>[];

        return DropdownButtonFormField<String?>(
          key: ValueKey('budget_cat_$_dropdownResetKey'),
          initialValue: _selectedCategoryId,
          decoration: const InputDecoration(
            labelText: '카테고리 (선택)',
            prefixIcon: Icon(Icons.category),
          ),
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('전체 예산 (카테고리 없음)'),
            ),
            ...categories.map((c) {
              return DropdownMenuItem<String?>(
                value: c.id,
                child: Text(c.name),
              );
            }),
            const DropdownMenuItem<String?>(
              value: '__create__',
              child: Text('+ 새 카테고리'),
            ),
          ],
          onChanged: (value) {
            if (value == '__create__') {
              setState(() => _dropdownResetKey++);
              _showCreateCategorySheet(context);
              return;
            }
            setState(() {
              _selectedCategoryId = value;
            });
          },
        );
      },
    );
  }

  Future<void> _showCreateCategorySheet(BuildContext context) async {
    final bloc = context.read<CategoryBloc>();
    final oldIds = (bloc.state is CategoryLoaded)
        ? (bloc.state as CategoryLoaded).categories.map((c) => c.id).toSet()
        : <String>{};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryFormSheet(
        onSubmit: (name, type, icon, color, groupId) {
          bloc.add(CreateCategory(
            name: name,
            type: type,
            icon: icon,
            color: color,
            groupId: groupId,
          ));
        },
      ),
    );

    if (!mounted) return;
    // Check if already updated
    final currentState = bloc.state;
    if (currentState is CategoryLoaded) {
      final currentIds = currentState.categories.map((c) => c.id).toSet();
      final diff = currentIds.difference(oldIds);
      if (diff.isNotEmpty) {
        setState(() {
          _selectedCategoryId = diff.first;
          _dropdownResetKey++;
        });
        return;
      }
    }

    // Wait for next state with new item
    try {
      await for (final state
          in bloc.stream.timeout(const Duration(seconds: 10))) {
        if (state is CategoryLoaded) {
          final newIds = state.categories.map((c) => c.id).toSet();
          final diff = newIds.difference(oldIds);
          if (diff.isNotEmpty) {
            if (mounted) {
              setState(() {
                _selectedCategoryId = diff.first;
                _dropdownResetKey++;
              });
            }
            return;
          }
        }
      }
    } catch (_) {
      // Timeout
    }
  }

  void _showPocketSelectorSheet(BuildContext context, List<MoneyPocket> pockets) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSubmitting = true);
      final int amount;
      final int? weeklyAmount;
      if (_budgetPeriod == 'WEEKLY') {
        final weekly = int.parse(_weeklyAmountController.text.trim());
        weeklyAmount = weekly;
        // Monthly amount = weekly * 4 (approximate)
        amount = _amountController.text.trim().isNotEmpty
            ? int.parse(_amountController.text.trim())
            : weekly * 4;
      } else {
        amount = int.parse(_amountController.text.trim());
        weeklyAmount = null;
      }
      final yearMonth =
          '$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}';
      final bloc = context.read<BudgetBloc>();

      if (isEditing) {
        bloc.add(UpdateBudget(
          id: widget.budgetId!,
          amount: amount,
          budgetPeriod: _budgetPeriod,
          weeklyAmount: weeklyAmount,
          pocketId: _selectedPocketId,
        ));
      } else {
        bloc.add(CreateBudget(
          categoryId: _selectedCategoryId,
          yearMonth: yearMonth,
          amount: amount,
          budgetPeriod: _budgetPeriod,
          weeklyAmount: weeklyAmount,
          pocketId: _selectedPocketId,
        ));
      }
    }
  }
}
