import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/category/domain/entities/category.dart';
import 'package:budget_book/features/category/presentation/bloc/category_bloc.dart';
import 'package:budget_book/features/category/presentation/bloc/category_state.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_bloc.dart';
import 'package:budget_book/features/pocket/presentation/bloc/pocket_state.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';

class TransactionFormPage extends StatefulWidget {
  /// If editing, pass the transaction ID (from URL path parameter).
  /// The page will load the transaction data from the BLoC/repository.
  final String? transactionId;

  const TransactionFormPage({super.key, this.transactionId});

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
  String? _selectedPaymentMethodId;
  String? _selectedPocketId;
  late DateTime _selectedDate;
  bool _isLoadingTransaction = false;

  bool get isEditing => widget.transactionId != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();
    _memoController = TextEditingController();
    _selectedType = 'EXPENSE';
    _selectedDate = DateTime.now();

    if (isEditing) {
      _isLoadingTransaction = true;
      // Load the transaction by ID via the bloc
      _loadTransaction();
    }
  }

  Future<void> _loadTransaction() async {
    final bloc = context.read<TransactionBloc>();
    final repo = bloc.transactionRepository;
    final result = await repo.getTransaction(widget.transactionId!);
    result.fold(
      (failure) {
        if (mounted) {
          setState(() {
            _isLoadingTransaction = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('거래를 불러올 수 없습니다: ${failure.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      (transaction) {
        if (mounted) {
          setState(() {
            _isLoadingTransaction = false;
            _amountController.text = transaction.amount.toString();
            _descriptionController.text = transaction.description;
            _memoController.text = transaction.memo ?? '';
            _selectedType = transaction.type;
            _selectedCategoryId = transaction.category?.id;
            _selectedPaymentMethodId = transaction.paymentMethodId;
            _selectedPocketId = transaction.pocketId;
            _selectedDate = DateTime.parse(transaction.transactionDate);
          });
        }
      },
    );
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
    if (_isLoadingTransaction) {
      return Scaffold(
        appBar: AppBar(title: const Text('거래 수정')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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
                // Payment method picker
                _buildPaymentMethodPicker(context),
                const SizedBox(height: 16),
                // Pocket picker
                _buildPocketPicker(context),
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

  Widget _buildPaymentMethodPicker(BuildContext context) {
    return BlocBuilder<PaymentMethodBloc, PaymentMethodState>(
      builder: (context, pmState) {
        final methods = pmState is PaymentMethodLoaded
            ? pmState.activePaymentMethods
            : <PaymentMethod>[];

        return DropdownButtonFormField<String>(
          initialValue: _selectedPaymentMethodId,
          decoration: const InputDecoration(
            labelText: '결제수단',
            prefixIcon: Icon(Icons.account_balance_wallet),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('선택 안 함'),
            ),
            ...methods.map((pm) => DropdownMenuItem<String>(
                  value: pm.id,
                  child: Text(pm.name),
                )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedPaymentMethodId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildPocketPicker(BuildContext context) {
    return BlocBuilder<PocketBloc, PocketState>(
      builder: (context, pocketState) {
        final pockets = pocketState is PocketLoaded
            ? pocketState.pockets
            : <MoneyPocket>[];

        return DropdownButtonFormField<String>(
          initialValue: _selectedPocketId,
          decoration: const InputDecoration(
            labelText: '포켓 (선택)',
            prefixIcon: Icon(Icons.account_balance_wallet),
          ),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('포켓 미지정'),
            ),
            ...pockets.map((p) => DropdownMenuItem<String>(
                  value: p.id,
                  child: Text(p.name),
                )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedPocketId = value;
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
          id: widget.transactionId!,
          amount: amount,
          description: description,
          categoryId: _selectedCategoryId,
          transactionDate: dateStr,
          memo: memo,
          clearMemo: memo == null,
          paymentMethodId: _selectedPaymentMethodId,
          pocketId: _selectedPocketId,
        ));
      } else {
        bloc.add(CreateTransaction(
          type: _selectedType,
          amount: amount,
          description: description,
          categoryId: _selectedCategoryId,
          transactionDate: dateStr,
          memo: memo,
          paymentMethodId: _selectedPaymentMethodId,
          pocketId: _selectedPocketId,
        ));
      }
    }
  }
}
