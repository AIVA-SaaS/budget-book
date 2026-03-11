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

class RecurringFormPage extends StatefulWidget {
  final RecurringTransaction? recurring;

  const RecurringFormPage({super.key, this.recurring});

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

  bool get isEdit => widget.recurring != null;

  @override
  void initState() {
    super.initState();
    _type = widget.recurring?.type ?? 'EXPENSE';
    _amountController = TextEditingController(
      text: widget.recurring?.amount.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.recurring?.description ?? '',
    );
    _memoController = TextEditingController(
      text: widget.recurring?.memo ?? '',
    );
    _frequency = widget.recurring?.frequency ?? 'MONTHLY';
    _dayOfMonth = widget.recurring?.dayOfMonth;
    _dayOfWeek = widget.recurring?.dayOfWeek;
    _categoryId = widget.recurring?.categoryId;
    _paymentMethodId = widget.recurring?.paymentMethodId;
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
      ),
      body: BlocListener<RecurringBloc, RecurringState>(
        listener: (context, state) {
          if (state is RecurringLoaded && state.operationError == null) {
            context.pop();
          } else if (state is RecurringLoaded &&
              state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.operationError!),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: Form(
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
                  return DropdownButtonFormField<String>(
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: '카테고리 (선택)',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('선택 안 함'),
                      ),
                      ...state.categories.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _categoryId = value);
                    },
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
                  return DropdownButtonFormField<String>(
                    initialValue: _paymentMethodId,
                    decoration: const InputDecoration(
                      labelText: '결제수단 (선택)',
                      prefixIcon: Icon(Icons.payment_outlined),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('선택 안 함'),
                      ),
                      ...state.activePaymentMethods.map((pm) =>
                          DropdownMenuItem(
                            value: pm.id,
                            child: Text(pm.name),
                          )),
                    ],
                    onChanged: (value) {
                      setState(() => _paymentMethodId = value);
                    },
                  );
                },
              ),
              const SizedBox(height: 32),
              // Submit button
              FilledButton(
                onPressed: _submit,
                child: Text(isEdit ? '수정' : '추가'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = int.parse(_amountController.text);
    final description = _descriptionController.text.trim();
    final memo =
        _memoController.text.trim().isEmpty ? null : _memoController.text.trim();

    if (isEdit) {
      context.read<RecurringBloc>().add(UpdateRecurringTransaction(
            id: widget.recurring!.id,
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
