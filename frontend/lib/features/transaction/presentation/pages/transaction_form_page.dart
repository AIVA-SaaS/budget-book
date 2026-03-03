import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction.dart'
    as txn;
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';

class TransactionFormPage extends StatefulWidget {
  final txn.Transaction? transaction;

  const TransactionFormPage({super.key, this.transaction});

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _memoController;
  late String _selectedType;
  String? _selectedCategoryId;
  late DateTime _selectedDate;

  bool get isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _amountController =
        TextEditingController(text: t != null ? t.amount.toString() : '');
    _descriptionController =
        TextEditingController(text: t?.description ?? '');
    _memoController = TextEditingController(text: t?.memo ?? '');
    _selectedType = t?.type ?? 'EXPENSE';
    _selectedCategoryId = t?.category?.id;
    _selectedDate = t != null
        ? DateTime.parse(t.transactionDate)
        : DateTime.now();
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
        title: Text(isEditing ? '거래 수정' : '거래 추가'),
      ),
      body: BlocListener<TransactionBloc, TransactionState>(
        listener: (context, state) {
          if (state is TransactionLoaded) {
            context.pop();
          } else if (state is TransactionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type toggle
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'EXPENSE',
                      label: Text('지출'),
                      icon: Icon(Icons.arrow_downward),
                    ),
                    ButtonSegment(
                      value: 'INCOME',
                      label: Text('수입'),
                      icon: Icon(Icons.arrow_upward),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (value) {
                    setState(() {
                      _selectedType = value.first;
                      _selectedCategoryId = null;
                    });
                  },
                ),
                const SizedBox(height: 24),
                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: '금액',
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
                const SizedBox(height: 16),
                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: '내용',
                    hintText: '예: 점심 식사',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLength: 255,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '내용을 입력하세요';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Category picker
                _buildCategoryPicker(context),
                const SizedBox(height: 16),
                // Date picker
                _buildDatePicker(context),
                const SizedBox(height: 16),
                // Memo
                TextFormField(
                  controller: _memoController,
                  decoration: const InputDecoration(
                    labelText: '메모 (선택)',
                    hintText: '추가 메모',
                    prefixIcon: Icon(Icons.note),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 32),
                // Submit button
                FilledButton(
                  onPressed: _onSubmit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(isEditing ? '수정' : '추가'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPicker(BuildContext context) {
    return BlocBuilder<CategoryBloc, CategoryState>(
      builder: (context, catState) {
        final categories = catState is CategoryLoaded
            ? (_selectedType == 'INCOME'
                ? catState.incomeCategories
                : catState.expenseCategories)
            : <Category>[];

        return DropdownButtonFormField<String>(
          initialValue: _selectedCategoryId,
          decoration: const InputDecoration(
            labelText: '카테고리',
            prefixIcon: Icon(Icons.category),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('미분류'),
            ),
            ...categories.map((c) => DropdownMenuItem<String>(
                  value: c.id,
                  child: Text(c.name),
                )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030, 12, 31),
        );
        if (picked != null) {
          setState(() {
            _selectedDate = picked;
          });
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: '날짜',
          prefixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(formattedDate),
      ),
    );
  }

  void _onSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      final amount = int.parse(_amountController.text.trim());
      final description = _descriptionController.text.trim();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final memo =
          _memoController.text.trim().isEmpty ? null : _memoController.text.trim();
      final bloc = context.read<TransactionBloc>();

      if (isEditing) {
        bloc.add(UpdateTransaction(
          id: widget.transaction!.id,
          amount: amount,
          description: description,
          categoryId: _selectedCategoryId,
          transactionDate: dateStr,
          memo: memo,
          clearMemo: memo == null,
        ));
      } else {
        bloc.add(CreateTransaction(
          type: _selectedType,
          amount: amount,
          description: description,
          categoryId: _selectedCategoryId,
          transactionDate: dateStr,
          memo: memo,
        ));
      }
    }
  }
}
