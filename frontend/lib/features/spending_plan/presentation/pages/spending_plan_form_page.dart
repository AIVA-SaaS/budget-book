import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/budget/domain/entities/budget.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_state.dart';
import 'package:budget_book/features/spending_plan/domain/entities/spending_plan.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_bloc.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_event.dart';
import 'package:budget_book/features/spending_plan/presentation/bloc/spending_plan_state.dart';

class SpendingPlanFormPage extends StatefulWidget {
  final String? planId;

  const SpendingPlanFormPage({super.key, this.planId});

  @override
  State<SpendingPlanFormPage> createState() => _SpendingPlanFormPageState();
}

class _SpendingPlanFormPageState extends State<SpendingPlanFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _memoController;

  DateTime _targetDate = DateTime.now();
  String? _categoryId;
  String? _paymentMethodId;
  String? _budgetId;
  bool _isRecurring = false;
  String? _frequency;
  String _visibility = 'SHARED';
  bool _isSubmitting = false;
  SpendingPlan? _existingPlan;

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

    if (isEditing) {
      _loadExistingPlan();
    }
  }

  void _loadExistingPlan() {
    final bloc = context.read<SpendingPlanBloc>();
    final state = bloc.state;
    if (state is SpendingPlanLoaded) {
      final plan = state.plans
          .where((p) => p.id == widget.planId)
          .firstOrNull;
      if (plan != null) {
        _populateForm(plan);
      }
    }
  }

  void _populateForm(SpendingPlan plan) {
    _existingPlan = plan;
    _nameController.text = plan.name;
    _amountController.text = CurrencyFormatter.format(plan.amount);
    _memoController.text = plan.memo ?? '';
    _targetDate = DateTime.tryParse(plan.targetDate) ?? DateTime.now();
    _categoryId = plan.categoryId;
    _paymentMethodId = plan.paymentMethodId;
    _budgetId = plan.budgetId;
    _isRecurring = plan.isRecurring;
    _frequency = plan.frequency;
    _visibility = plan.visibility;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _memoController.dispose();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount == null || amount <= 0) return;

    final name = _nameController.text.trim();
    final memo =
        _memoController.text.trim().isEmpty ? null : _memoController.text.trim();
    final targetDateStr = DateFormat('yyyy-MM-dd').format(_targetDate);

    setState(() => _isSubmitting = true);

    final bloc = context.read<SpendingPlanBloc>();

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
          title: Text(isEditing ? '계획 수정' : '계획 추가'),
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
          // Plan name (required)
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: '계획명 *',
              prefixIcon: Icon(Icons.event_note),
              hintText: '예: 코스트코 장보기',
            ),
            maxLength: 100,
            validator: (value) {
              if (value == null || value.trim().isEmpty) return '계획명을 입력하세요';
              return null;
            },
          ),
          const SizedBox(height: 12),
          // Amount (required)
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
              if (value == null || value.isEmpty) return '금액을 입력하세요';
              final amount = CurrencyFormatter.parse(value);
              if (amount == null || amount <= 0) return '유효한 금액을 입력하세요';
              if (amount > 999999999) return '최대 999,999,999원까지 입력 가능합니다';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Target date
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
          // Category dropdown
          DropdownButtonFormField<String>(
            initialValue: _categoryId,
            decoration: const InputDecoration(
              labelText: '카테고리',
              prefixIcon: Icon(Icons.label),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('선택 안 함'),
              ),
              ...categories.map((cat) => DropdownMenuItem(
                    value: cat.id,
                    child: Text(cat.name),
                  )),
            ],
            onChanged: (value) {
              setState(() => _categoryId = value);
            },
          ),
          const SizedBox(height: 16),
          // Payment method dropdown
          DropdownButtonFormField<String>(
            initialValue: _paymentMethodId,
            decoration: const InputDecoration(
              labelText: '결제수단',
              prefixIcon: Icon(Icons.credit_card),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('선택 안 함'),
              ),
              ...methods.map((pm) => DropdownMenuItem(
                    value: pm.id,
                    child: Text(pm.name),
                  )),
            ],
            onChanged: (value) {
              setState(() => _paymentMethodId = value);
            },
          ),
          const SizedBox(height: 16),
          // Budget link dropdown
          DropdownButtonFormField<String>(
            initialValue: _budgetId,
            decoration: const InputDecoration(
              labelText: '예산 연결',
              prefixIcon: Icon(Icons.account_balance_wallet),
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('선택 안 함'),
              ),
              ...budgets.map((b) => DropdownMenuItem(
                    value: b.id,
                    child: Text(
                      b.category?.name != null
                          ? '${b.category!.name} (${CurrencyFormatter.format(b.amount)}원)'
                          : '${b.yearMonth} (${CurrencyFormatter.format(b.amount)}원)',
                    ),
                  )),
            ],
            onChanged: (value) {
              setState(() => _budgetId = value);
            },
          ),
          const SizedBox(height: 16),
          // Memo
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
          // Visibility
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
                : Text(isEditing ? '수정' : '저장'),
          ),
        ],
      ),
    );
  }
}
