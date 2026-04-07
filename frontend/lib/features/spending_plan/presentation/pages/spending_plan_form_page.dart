import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/utils/date_helpers.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_state.dart';
import 'package:budget_book/core/utils/payment_method_helpers.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/payment_method/presentation/widgets/payment_method_form_sheet.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_bloc.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_event.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_state.dart';
import 'package:budget_book/features/spending_plan/presentation/widgets/assign_plan_dialog.dart';
import 'package:budget_book/features/spending_plan/presentation/widgets/complete_plan_dialog.dart';
import 'package:budget_book/features/spending_plan/presentation/widgets/spending_plan_card.dart';

class SpendingPlanFormPage extends StatefulWidget {
  final String? planId;
  final bool isWishlist;

  const SpendingPlanFormPage({
    super.key,
    this.planId,
    this.isWishlist = false,
  });

  @override
  State<SpendingPlanFormPage> createState() => _SpendingPlanFormPageState();
}

class _SpendingPlanFormPageState extends State<SpendingPlanFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _memoController;
  late final TextEditingController _estimatedMinController;
  late final TextEditingController _estimatedMaxController;
  late final TextEditingController _tagInputController;

  DateTime _targetDate = DateTime.now();
  String? _categoryId;
  String? _categoryDisplayName;
  String? _paymentMethodId;
  String? _budgetId;
  bool _isRecurring = false;
  String? _frequency;
  String _visibility = 'SHARED';
  bool _isSubmitting = false;
  SpendingPlan? _existingPlan;

  // Wishlist-specific fields
  late bool _isWishlistMode;
  String _priority = 'MEDIUM';
  List<String> _tags = [];

  bool get isEditing => widget.planId != null;

  static const _frequencyOptions = [
    ('WEEKLY', '매주'),
    ('MONTHLY', '매월'),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _amountController = TextEditingController();
    _memoController = TextEditingController();
    _estimatedMinController = TextEditingController();
    _estimatedMaxController = TextEditingController();
    _tagInputController = TextEditingController();

    _isWishlistMode = widget.isWishlist;

    // Ensure categories, payment methods, and budgets are loaded for selectors
    final cgBloc = getIt<CategoryGroupBloc>();
    if (cgBloc.state is! CategoryGroupLoaded) {
      cgBloc.add(const LoadCategoryGroups());
    }
    final pmBloc = getIt<PaymentMethodBloc>();
    if (pmBloc.state is PaymentMethodInitial) {
      pmBloc.add(const LoadPaymentMethods());
    }
    final budgetBloc = getIt<BudgetBloc>();
    if (budgetBloc.state is! BudgetLoaded) {
      final now = DateTime.now();
      budgetBloc.add(LoadBudgets(year: now.year, month: now.month));
    }

    if (isEditing) {
      _loadExistingPlan();
    }
  }

  void _loadExistingPlan() {
    final bloc = context.read<SpendingPlanBloc>();
    final state = bloc.state;
    if (state is SpendingPlanLoaded) {
      // Search in both plans and wishlist
      SpendingPlan? plan = state.plans
          .where((p) => p.id == widget.planId)
          .firstOrNull;
      plan ??= state.wishlist
          ?.where((p) => p.id == widget.planId)
          .firstOrNull;
      if (plan != null) {
        _populateForm(plan);
      }
    }
  }

  void _populateForm(SpendingPlan plan) {
    _existingPlan = plan;
    _nameController.text = plan.name;
    _amountController.text = plan.amount > 0
        ? CurrencyFormatter.format(plan.amount)
        : '';
    _memoController.text = plan.memo ?? '';
    _targetDate = plan.targetDate != null
        ? DateTime.tryParse(plan.targetDate!) ?? DateTime.now()
        : DateTime.now();
    _categoryId = plan.categoryId;
    _categoryDisplayName = plan.categoryName;
    _paymentMethodId = plan.paymentMethodId;
    _budgetId = plan.budgetId;
    _isRecurring = plan.isRecurring;
    _frequency = plan.frequency;
    _visibility = plan.visibility;
    _isWishlistMode = plan.isWishlist;
    _priority = plan.priority;
    _tags = List.from(plan.tags);
    if (plan.estimatedMin != null) {
      _estimatedMinController.text = CurrencyFormatter.format(plan.estimatedMin!);
    }
    if (plan.estimatedMax != null) {
      _estimatedMaxController.text = CurrencyFormatter.format(plan.estimatedMax!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _memoController.dispose();
    _estimatedMinController.dispose();
    _estimatedMaxController.dispose();
    _tagInputController.dispose();
    super.dispose();
  }

  Future<void> _selectTargetDate() async {
    final picked = await showCalendarPickerDialog(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2050),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _addTag() {
    final tag = _tagInputController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagInputController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final memo =
        _memoController.text.trim().isEmpty ? null : _memoController.text.trim();

    setState(() => _isSubmitting = true);

    final bloc = context.read<SpendingPlanBloc>();

    if (_isWishlistMode) {
      _submitWishlist(bloc, name, memo);
    } else {
      _submitPlan(bloc, name, memo);
    }
  }

  void _submitWishlist(SpendingPlanBloc bloc, String name, String? memo) {
    // For wishlist: amount can be 0 if only estimated range is provided
    final amount = CurrencyFormatter.parse(_amountController.text) ?? 0;
    final estimatedMin = CurrencyFormatter.parse(_estimatedMinController.text);
    final estimatedMax = CurrencyFormatter.parse(_estimatedMaxController.text);
    final tagsStr = _tags.isNotEmpty ? _tags.join(',') : null;

    if (isEditing) {
      final old = _existingPlan;
      bloc.add(UpdateSpendingPlan(
        id: widget.planId!,
        name: name,
        amount: amount,
        memo: memo,
        clearMemo: memo == null && old?.memo != null,
        categoryId: _categoryId,
        clearCategoryId: _categoryId == null && old?.categoryId != null,
        paymentMethodId: _paymentMethodId,
        clearPaymentMethodId: _paymentMethodId == null && old?.paymentMethodId != null,
        budgetId: _budgetId,
        clearBudgetId: _budgetId == null && old?.budgetId != null,
        visibility: _visibility,
      ));
    } else {
      bloc.add(CreateSpendingPlan(
        name: name,
        amount: amount,
        targetDate: '',
        status: 'WISHLIST',
        priority: _priority,
        estimatedMin: estimatedMin,
        estimatedMax: estimatedMax,
        tags: tagsStr,
        memo: memo,
        categoryId: _categoryId,
        paymentMethodId: _paymentMethodId,
        visibility: _visibility,
      ));
    }
  }

  void _submitPlan(SpendingPlanBloc bloc, String name, String? memo) {
    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final targetDateStr = DateFormat('yyyy-MM-dd').format(_targetDate);

    if (isEditing) {
      final old = _existingPlan;
      bloc.add(UpdateSpendingPlan(
        id: widget.planId!,
        name: name,
        amount: amount,
        targetDate: targetDateStr,
        memo: memo,
        clearMemo: memo == null && old?.memo != null,
        categoryId: _categoryId,
        clearCategoryId: _categoryId == null && old?.categoryId != null,
        paymentMethodId: _paymentMethodId,
        clearPaymentMethodId:
            _paymentMethodId == null && old?.paymentMethodId != null,
        budgetId: _budgetId,
        clearBudgetId: _budgetId == null && old?.budgetId != null,
        isRecurring: _isRecurring,
        frequency: _isRecurring ? _frequency : null,
        clearFrequency: !_isRecurring && old?.frequency != null,
        visibility: _visibility,
      ));
    } else {
      bloc.add(CreateSpendingPlan(
        name: name,
        amount: amount,
        targetDate: targetDateStr,
        memo: memo,
        categoryId: _categoryId,
        paymentMethodId: _paymentMethodId,
        budgetId: _budgetId,
        isRecurring: _isRecurring,
        frequency: _isRecurring ? _frequency : null,
        visibility: _visibility,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SpendingPlanBloc, SpendingPlanState>(
      listener: (context, state) {
        if (state is SpendingPlanLoaded && _isSubmitting) {
          if (state.operationError != null) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(isEditing ? '수정되었습니다' : '저장되었습니다')),
            );
            context.pop();
          }
        } else if (state is SpendingPlanError && _isSubmitting) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isWishlistMode
              ? (isEditing ? '구매 목록 수정' : '구매 목록 추가')
              : (isEditing ? '계획 수정' : '계획 추가')),
          actions: [
            if (isEditing)
              IconButton(
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                tooltip: '삭제',
                onPressed: () => _confirmDelete(context),
              ),
          ],
        ),
        body: _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final pmState = getIt<PaymentMethodBloc>().state;
    final methods = pmState is PaymentMethodLoaded
        ? pmState.activePaymentMethods
        : <PaymentMethod>[];

    final catState = getIt<CategoryBloc>().state;
    final categories = catState is CategoryLoaded
        ? catState.categories.where((c) => c.type == 'EXPENSE').toList()
        : <Category>[];

    final budgetState = getIt<BudgetBloc>().state;
    final budgets = budgetState is BudgetLoaded
        ? budgetState.budgets
        : <Budget>[];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isWishlistMode) ...[
            // WISHLIST mode order: 계획명 -> 예상금액(범위) -> 카테고리 -> 우선순위 -> 태그 -> 메모

            // 1. Plan name (required)
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '항목명 *',
                prefixIcon: Icon(Icons.shopping_cart),
                hintText: '예: 에어팟 프로',
              ),
              maxLength: 100,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '항목명을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // 2. Price range fields
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _estimatedMinController,
                    decoration: const InputDecoration(
                      labelText: '예상 최소 금액',
                      suffixText: '원',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('~'),
                ),
                Expanded(
                  child: TextFormField(
                    controller: _estimatedMaxController,
                    decoration: const InputDecoration(
                      labelText: '예상 최대 금액',
                      suffixText: '원',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      CurrencyInputFormatter(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Or single amount
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '예상 금액 (단일)',
                prefixIcon: Icon(Icons.attach_money),
                suffixText: '원',
                helperText: '최소/최대를 입력하면 생략 가능',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
            ),
            const SizedBox(height: 16),

            // 3. Category selector
            ItemSelectorField(
              label: '카테고리',
              selectedLabel: _categoryDisplayName ?? (_categoryId != null
                  ? categories.where((c) => c.id == _categoryId).map((c) => c.name).firstOrNull ?? '(삭제됨)'
                  : null),
              prefixIcon: Icons.category,
              placeholder: '선택 안 함',
              onTap: () => _showCategorySelectorSheet(context),
            ),
            const SizedBox(height: 16),

            // 4. Priority selector
            Text(
              '우선순위',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'HIGH', label: Text('높음')),
                ButtonSegment(value: 'MEDIUM', label: Text('보통')),
                ButtonSegment(value: 'LOW', label: Text('낮음')),
              ],
              selected: {_priority},
              onSelectionChanged: (selection) {
                setState(() => _priority = selection.first);
              },
            ),
            const SizedBox(height: 16),

            // 5. Tags input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tagInputController,
                    decoration: const InputDecoration(
                      labelText: '태그 추가',
                      prefixIcon: Icon(Icons.tag),
                      hintText: '태그 입력 후 추가',
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addTag,
                  icon: const Icon(Icons.add_circle),
                  tooltip: '태그 추가',
                ),
              ],
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: _tags.map((tag) => Chip(
                  label: Text(tag),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () => _removeTag(tag),
                )).toList(),
              ),
            ],
            const SizedBox(height: 16),

            // 6. Memo
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
          ] else ...[
            // Regular PLAN mode order: 목표일 -> 금액 -> 계획명 -> 카테고리 -> 결제수단 -> 예산연결 -> 메모

            // 1. Target date
            InkWell(
              onTap: _selectTargetDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '목표일 *',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  DateFormat('yyyy년 M월 d일', 'ko').format(_targetDate),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Amount (required)
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: '금액 *',
                prefixIcon: Icon(Icons.attach_money),
                suffixText: '원',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              validator: (value) {
                if (_isWishlistMode) return null;
                if (value == null || value.isEmpty) return '금액을 입력하세요';
                final amount = CurrencyFormatter.parse(value);
                if (amount == null || amount <= 0) return '유효한 금액을 입력하세요';
                if (amount > 999999999) return '최대 999,999,999원까지 입력 가능합니다';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 3. Plan name (required)
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '계획명 *',
                prefixIcon: Icon(Icons.event_note),
                hintText: '예: 코스트코 장보기',
              ),
              maxLength: 100,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '계획명을 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // 4. Category selector
            ItemSelectorField(
              label: '카테고리',
              selectedLabel: _categoryDisplayName ?? (_categoryId != null
                  ? categories.where((c) => c.id == _categoryId).map((c) => c.name).firstOrNull ?? '(삭제됨)'
                  : null),
              prefixIcon: Icons.category,
              placeholder: '선택 안 함',
              onTap: () => _showCategorySelectorSheet(context),
            ),
            const SizedBox(height: 16),

            // 5. Payment method selector
            ItemSelectorField(
              label: '결제수단',
              selectedLabel: _paymentMethodId != null
                  ? methods.where((pm) => pm.id == _paymentMethodId).map((pm) => pm.name).firstOrNull
                  : null,
              prefixIcon: Icons.credit_card,
              placeholder: '선택 안 함',
              onTap: () => _showPaymentMethodSelectorSheet(context, methods),
            ),
            const SizedBox(height: 16),

            // 6. Budget link dropdown — filter by target date's month
            // Weekly budgets are expanded into per-week items with pro-rata amounts
            Builder(builder: (context) {
              final targetMonth = '${_targetDate.year}-${_targetDate.month.toString().padLeft(2, '0')}';
              final filteredBudgets = budgets.where((b) => b.yearMonth == targetMonth).toList();
              final weekRanges = DateHelper.calculateWeekRanges(_targetDate.year, _targetDate.month);
              final dateFormat = DateFormat('M/d');

              // Build dropdown items: monthly budgets as-is, weekly budgets expanded per week
              final dropdownItems = <DropdownMenuItem<String>>[
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('선택 안 함'),
                ),
              ];

              for (final b in filteredBudgets) {
                if (b.budgetPeriod == 'WEEKLY' && b.weeklyAmount != null) {
                  // Expand weekly budget into per-week items
                  for (final week in weekRanges) {
                    final proRata = DateHelper.calculateProRataBudget(b.weeklyAmount!, week);
                    final startStr = dateFormat.format(week.start);
                    final endStr = dateFormat.format(week.end);
                    final isTargetWeek = DateHelper.isDateInWeekRange(_targetDate, week);
                    final label = '${b.targetLabel} — ${week.weekNumber}주차 ($startStr~$endStr) ${CurrencyFormatter.format(proRata)}원';

                    dropdownItems.add(DropdownMenuItem(
                      value: b.id,
                      enabled: isTargetWeek,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontWeight: isTargetWeek ? FontWeight.w600 : FontWeight.normal,
                          color: isTargetWeek ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ));
                  }
                } else {
                  final amount = CurrencyFormatter.format(b.effectiveMonthlyAmount);
                  dropdownItems.add(DropdownMenuItem(
                    value: b.id,
                    child: Text('${b.targetLabel} — $amount원'),
                  ));
                }
              }

              // Count only enabled weekly items for the target week
              final weeklyBudgetCount = filteredBudgets.where((b) => b.budgetPeriod == 'WEEKLY').length;
              final monthlyBudgetCount = filteredBudgets.length - weeklyBudgetCount;
              final targetWeek = weekRanges.where((w) => DateHelper.isDateInWeekRange(_targetDate, w)).firstOrNull;
              final weekLabel = targetWeek != null ? ' (${targetWeek.weekNumber}주차)' : '';

              return DropdownButtonFormField<String>(
                key: ValueKey('$targetMonth-${_targetDate.day}'),
                initialValue: filteredBudgets.any((b) => b.id == _budgetId) ? _budgetId : null,
                decoration: InputDecoration(
                  labelText: '예산 연결',
                  prefixIcon: const Icon(Icons.account_balance_wallet),
                  helperText: '${_targetDate.month}월$weekLabel 예산: 월간 $monthlyBudgetCount개, 주간 $weeklyBudgetCount개',
                ),
                isExpanded: true,
                items: dropdownItems,
                onChanged: (value) {
                  setState(() => _budgetId = value);
                },
              );
            }),
            const SizedBox(height: 16),

            // 7. Memo
            TextFormField(
              controller: _memoController,
              decoration: const InputDecoration(
                labelText: '메모',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // Recurring toggle
            SwitchListTile(
              title: const Text('반복 설정'),
              subtitle: const Text('주간 또는 월간 반복'),
              value: _isRecurring,
              onChanged: (value) {
                setState(() {
                  _isRecurring = value;
                  if (!value) _frequency = null;
                  if (value && _frequency == null) _frequency = 'MONTHLY';
                });
              },
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _frequency ?? 'MONTHLY',
                decoration: const InputDecoration(
                  labelText: '반복 주기',
                  prefixIcon: Icon(Icons.repeat),
                ),
                isExpanded: true,
                items: _frequencyOptions
                    .map((e) => DropdownMenuItem(
                          value: e.$1,
                          child: Text(e.$2),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _frequency = value);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],

          // Visibility (common to both modes)
          DropdownButtonFormField<String>(
            initialValue: _visibility,
            decoration: const InputDecoration(
              labelText: '공개 범위',
              prefixIcon: Icon(Icons.visibility),
            ),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'SHARED', child: Text('공유')),
              DropdownMenuItem(value: 'PRIVATE', child: Text('비공개')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _visibility = value);
            },
          ),
          const SizedBox(height: 24),
          // Submit button
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('저장'),
          ),
          // Status action buttons (edit mode only)
          if (isEditing && _existingPlan != null) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              '상태 변경',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            _buildStatusActions(context),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('삭제'),
        content: Text("'${_nameController.text}'을(를) 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              getIt<SpendingPlanBloc>().add(DeleteSpendingPlan(widget.planId!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('삭제되었습니다')),
              );
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusActions(BuildContext context) {
    final plan = _existingPlan!;
    final status = plan.status;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Current status display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: statusColor(status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(statusIcon(status), color: statusColor(status), size: 18),
              const SizedBox(width: 8),
              Text(
                '현재 상태: ${statusLabel(status)}',
                style: TextStyle(
                  color: statusColor(status),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // WISHLIST → assign (날짜 배정)
        if (status == 'WISHLIST')
          OutlinedButton.icon(
            onPressed: () async {
              final result = await showAssignPlanDialog(context, plan);
              if (result != null && context.mounted) {
                getIt<SpendingPlanBloc>().add(AssignPlan(
                  planId: plan.id,
                  targetDate: result.targetDate,
                  weekNumber: result.weekNumber,
                  budgetId: result.budgetId,
                ));
                context.pop();
              }
            },
            icon: const Icon(Icons.calendar_month),
            label: const Text('날짜 배정 (계획됨으로 전환)'),
          ),
        // PLANNED/OVERDUE → complete
        if (status == 'PLANNED' || status == 'OVERDUE') ...[
          OutlinedButton.icon(
            onPressed: () async {
              final result = await showCompletePlanDialog(context, plan);
              if (result != null && context.mounted) {
                getIt<SpendingPlanBloc>().add(CompleteWithTransaction(
                  planId: plan.id,
                  amount: result.actualAmount,
                  transactionDate: result.transactionDate,
                  description: result.description,
                  categoryId: result.categoryId,
                  paymentMethodId: result.paymentMethodId,
                ));
                if (context.mounted) context.pop();
              }
            },
            icon: const Icon(Icons.check_circle, color: Colors.green),
            label: const Text('완료 처리'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              getIt<SpendingPlanBloc>().add(SkipPlan(plan.id));
              context.pop();
            },
            icon: const Icon(Icons.skip_next, color: Colors.grey),
            label: const Text('건너뛰기'),
          ),
        ],
        // COMPLETED/SKIPPED → info only
        if (status == 'COMPLETED' || status == 'SKIPPED')
          Text(
            status == 'COMPLETED'
                ? '이미 완료된 계획입니다.'
                : '건너뛴 계획입니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        const SizedBox(height: 88), // FAB padding
      ],
    );
  }

  void _showCategorySelectorSheet(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CategoryGroupSelectorSheet(
        selectedCategoryId: _categoryId,
        categoryType: 'EXPENSE',
        onSelected: (category) {
          setState(() {
            _categoryId = category?.id;
            _categoryDisplayName = null;
          });
        },
        onSelectedWithGroupName: (category, groupName) {
          setState(() {
            _categoryId = category?.id;
            if (category != null && groupName != null && groupName.isNotEmpty) {
              _categoryDisplayName = '$groupName > ${category.name}';
            } else {
              _categoryDisplayName = category?.name;
            }
          });
        },
        onDelete: (id) {
          if (_categoryId == id) {
            setState(() {
              _categoryId = null;
              _categoryDisplayName = null;
            });
          }
        },
      ),
    );
  }

  void _showPaymentMethodSelectorSheet(BuildContext context, List<PaymentMethod> methods) {
    final pmBloc = getIt<PaymentMethodBloc>();
    showDialog(
      context: context,
      builder: (_) => BlocProvider<PaymentMethodBloc>.value(
        value: pmBloc,
        child: BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
          builder: (sheetContext, pmState) {
            final liveMethods = pmState is PaymentMethodLoaded
                ? pmState.activePaymentMethods
                : methods;
            return ItemSelectorSheet(
              title: '결제수단 선택',
              items: liveMethods
                  .indexed
                  .map((e) => SelectorItem(
                        id: e.$2.id,
                        label: e.$2.name,
                        leadingIcon: paymentMethodTypeIcon(e.$2.type),
                        leadingColor: paymentMethodTypeColor(e.$2.type),
                        isDeletable: true,
                        displayOrder: e.$1,
                        group: e.$2.type,
                      ))
                  .toList(),
              selectedId: _paymentMethodId,
              nullLabel: '선택 안 함',
              favoriteType: 'PAYMENT_METHOD',
              reorderRoute: '/asset-management',
              groupLabels: paymentMethodGroupLabels,
              onSelected: (item) {
                setState(() {
                  _paymentMethodId = item?.id;
                });
              },
              onEdit: (item) {
                final pm = liveMethods.where((m) => m.id == item.id).firstOrNull;
                if (pm != null) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BlocProvider<PaymentMethodBloc>.value(
                      value: pmBloc,
                      child: PaymentMethodFormSheet(
                        paymentMethod: pm,
                        onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
                          pmBloc.add(UpdatePaymentMethod(
                            id: pm.id,
                            name: name,
                            settlementDay: settlementDay,
                            closingDay: closingDay,
                            linkedBankId: linkedBankId,
                            clearLinkedBank: linkedBankId == null && pm.linkedBankId != null,
                          ));
                        },
                      ),
                    ),
                  );
                }
              },
              onDelete: (id) {
                pmBloc.add(DeletePaymentMethod(id));
                if (_paymentMethodId == id) {
                  setState(() => _paymentMethodId = null);
                }
              },
              onCreate: () => _showCreatePaymentMethodSheet(context),
              createLabel: '+ 새 결제수단',
            );
          },
        ),
      ),
    );
  }

  void _showCreatePaymentMethodSheet(BuildContext context) {
    final pmBloc = getIt<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider<PaymentMethodBloc>.value(
        value: pmBloc,
        child: PaymentMethodFormSheet(
          onSubmit: (name, type, settlementDay, closingDay, linkedBankId) {
            pmBloc.add(CreatePaymentMethod(
              name: name,
              type: type,
              settlementDay: settlementDay,
              closingDay: closingDay,
              linkedBankId: linkedBankId,
            ));
          },
        ),
      ),
    );
  }
}
