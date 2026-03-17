import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_bloc.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_event.dart';
import 'package:budget_book/features/recurring/presentation/bloc/recurring_state.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/core/widgets/item_selector_sheet.dart';
import 'package:budget_book/core/widgets/category_group_selector_sheet.dart';

class RecurringFormPage extends StatefulWidget {
  /// If editing, pass the recurring transaction ID (from URL path parameter).
  /// The page will find the recurring transaction from the RecurringBloc's loaded state.
  final String? recurringId;

  const RecurringFormPage({super.key, this.recurringId});

  @override
  State<RecurringFormPage> createState() => _RecurringFormPageState();
}

class _RecurringFormPageState extends State<RecurringFormPage> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late TextEditingController _memoController;
  late String _frequency;
  int? _dayOfMonth;
  int? _dayOfWeek;
  String? _categoryId;
  String? _paymentMethodId;
  bool _initialized = false;
  bool _isSubmitting = false;

  bool get isEdit => widget.recurringId != null;

  @override
  void initState() {
    super.initState();
    _type = 'EXPENSE';
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();
    _memoController = TextEditingController();
    _frequency = 'MONTHLY';
  }

  void _initializeFromRecurring(RecurringTransaction recurring) {
    if (_initialized) return;
    _initialized = true;
    _type = recurring.type;
    _amountController.text = recurring.amount.toString();
    _descriptionController.text = recurring.description;
    _memoController.text = recurring.memo ?? '';
    _frequency = recurring.frequency;
    _dayOfMonth = recurring.dayOfMonth;
    _dayOfWeek = recurring.dayOfWeek;
    _categoryId = recurring.categoryId;
    _paymentMethodId = recurring.paymentMethodId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? '반복 거래 수정' : '반복 거래 추가'),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _isSubmitting ? null : () => _confirmDelete(context),
            ),
        ],
      ),
      body: BlocConsumer<RecurringBloc, RecurringState>(
        listener: (context, state) {
          if (state is RecurringLoaded && state.operationError == null && _isSubmitting) {
            context.pop();
          } else if (state is RecurringLoaded &&
              state.operationError != null) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          // For editing: find the recurring transaction from the loaded list
          if (isEdit && state is RecurringLoaded && !_initialized) {
            final found = state.transactions.where(
              (r) => r.id == widget.recurringId,
            );
            if (found.isNotEmpty) {
              _initializeFromRecurring(found.first);
            } else {
              return Center(
                child: Text('반복 거래를 찾을 수 없습니다 (ID: ${widget.recurringId})'),
              );
            }
          }

          if (isEdit && state is! RecurringLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildForm(context);
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Type selector
          if (!isEdit) ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'EXPENSE', label: Text('지출')),
                ButtonSegment(value: 'INCOME', label: Text('수입')),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() => _type = value.first);
              },
            ),
            const SizedBox(height: 16),
          ],
          if (isEdit) ...[
            ListTile(
              leading: Icon(
                _type == 'INCOME' ? Icons.arrow_upward : Icons.arrow_downward,
              ),
              title: Text(_type == 'INCOME' ? '수입' : '지출'),
              subtitle: const Text('유형은 수정할 수 없습니다'),
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
          // Amount
          TextFormField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: '금액',
              prefixIcon: Icon(Icons.monetization_on_outlined),
              suffixText: '원',
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) return '금액을 입력해주세요';
              final amount = int.tryParse(value);
              if (amount == null || amount <= 0) return '올바른 금액을 입력해주세요';
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: '설명',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return '설명을 입력해주세요';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Memo
          TextFormField(
            controller: _memoController,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              prefixIcon: Icon(Icons.note_outlined),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          // Frequency
          if (!isEdit) ...[
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(
                labelText: '반복 주기',
                prefixIcon: Icon(Icons.repeat),
              ),
              items: const [
                DropdownMenuItem(value: 'DAILY', child: Text('매일')),
                DropdownMenuItem(value: 'WEEKLY', child: Text('매주')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('매월')),
                DropdownMenuItem(value: 'YEARLY', child: Text('매년')),
              ],
              onChanged: (value) {
                setState(() {
                  _frequency = value!;
                  _dayOfMonth = null;
                  _dayOfWeek = null;
                });
              },
            ),
            const SizedBox(height: 16),
          ],
          // Day selector based on frequency
          if (_frequency == 'MONTHLY' || _frequency == 'YEARLY')
            DropdownButtonFormField<int>(
              initialValue: _dayOfMonth,
              decoration: const InputDecoration(
                labelText: '실행일',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: List.generate(
                28,
                (i) => DropdownMenuItem(
                  value: i + 1,
                  child: Text('${i + 1}일'),
                ),
              ),
              onChanged: (value) {
                setState(() => _dayOfMonth = value);
              },
              validator: (value) {
                if (value == null) return '실행일을 선택해주세요';
                return null;
              },
            ),
          if (_frequency == 'WEEKLY')
            DropdownButtonFormField<int>(
              initialValue: _dayOfWeek,
              decoration: const InputDecoration(
                labelText: '요일',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text('월요일')),
                DropdownMenuItem(value: 2, child: Text('화요일')),
                DropdownMenuItem(value: 3, child: Text('수요일')),
                DropdownMenuItem(value: 4, child: Text('목요일')),
                DropdownMenuItem(value: 5, child: Text('금요일')),
                DropdownMenuItem(value: 6, child: Text('토요일')),
                DropdownMenuItem(value: 7, child: Text('일요일')),
              ],
              onChanged: (value) {
                setState(() => _dayOfWeek = value);
              },
              validator: (value) {
                if (value == null) return '요일을 선택해주세요';
                return null;
              },
            ),
          const SizedBox(height: 16),
          // Category picker
          BlocBuilder<CategoryBloc, CategoryState>(
            builder: (context, state) {
              if (state is! CategoryLoaded) {
                return const LinearProgressIndicator();
              }
              final categories = _type == 'INCOME'
                  ? state.incomeCategories
                  : state.expenseCategories;
              final selectedName = _categoryId != null
                  ? categories
                      .where((c) => c.id == _categoryId)
                      .map((c) => c.name)
                      .firstOrNull
                  : null;

              return ItemSelectorField(
                label: '카테고리 (선택)',
                selectedLabel: selectedName,
                prefixIcon: Icons.category_outlined,
                placeholder: '선택 안 함',
                onTap: () => _showCategorySelectorSheet(context, categories),
              );
            },
          ),
          const SizedBox(height: 16),
          // Payment method picker
          BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
            builder: (context, state) {
              if (state is! PaymentMethodLoaded) {
                return const LinearProgressIndicator();
              }
              final methods = state.activePaymentMethods;
              final selectedName = _paymentMethodId != null
                  ? methods
                      .where((pm) => pm.id == _paymentMethodId)
                      .map((pm) => pm.name)
                      .firstOrNull
                  : null;

              return ItemSelectorField(
                label: '결제수단 (선택)',
                selectedLabel: selectedName,
                prefixIcon: Icons.payment_outlined,
                placeholder: '선택 안 함',
                onTap: () => _showPaymentMethodSelectorSheet(context, methods),
              );
            },
          ),
          const SizedBox(height: 32),
          // Submit button
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(isEdit ? '수정' : '추가'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('반복 거래 삭제'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<RecurringBloc>().add(
                    DeleteRecurringTransaction(widget.recurringId!),
                  );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showCategorySelectorSheet(BuildContext context, List<Category> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      builder: (_) => CategoryGroupSelectorSheet(
        selectedCategoryId: _categoryId,
        categoryType: _type,
        onSelected: (category) {
          setState(() => _categoryId = category?.id);
        },
        onDelete: (id) {
          if (_categoryId == id) {
            setState(() => _categoryId = null);
          }
        },
      ),
    );
  }

  void _showPaymentMethodSelectorSheet(BuildContext context, List<PaymentMethod> methods) {
    final pmBloc = context.read<PaymentMethodBloc>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
                  .map((pm) => SelectorItem(
                        id: pm.id,
                        label: pm.name,
                        leadingIcon: Icons.payment,
                        isDeletable: !pm.isDefault,
                      ))
                  .toList(),
              selectedId: _paymentMethodId,
              nullLabel: '선택 안 함',
              onSelected: (item) {
                setState(() => _paymentMethodId = item?.id);
              },
              onDelete: (id) {
                pmBloc.add(DeletePaymentMethod(id));
                if (_paymentMethodId == id) {
                  setState(() => _paymentMethodId = null);
                }
              },
            );
          },
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final amount = int.parse(_amountController.text);
    final description = _descriptionController.text.trim();
    final memo =
        _memoController.text.trim().isEmpty ? null : _memoController.text.trim();

    if (isEdit) {
      context.read<RecurringBloc>().add(UpdateRecurringTransaction(
            id: widget.recurringId!,
            amount: amount,
            description: description,
            memo: memo,
            categoryId: _categoryId,
            paymentMethodId: _paymentMethodId,
            dayOfMonth: _dayOfMonth,
            dayOfWeek: _dayOfWeek,
          ));
    } else {
      context.read<RecurringBloc>().add(CreateRecurringTransaction(
            type: _type,
            amount: amount,
            description: description,
            memo: memo,
            frequency: _frequency,
            dayOfMonth: _dayOfMonth,
            dayOfWeek: _dayOfWeek,
            categoryId: _categoryId,
            paymentMethodId: _paymentMethodId,
          ));
    }
  }
}
