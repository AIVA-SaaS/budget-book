import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/amount_input_field.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/features/card_settlement/domain/entities/settlement_transaction.dart';
import 'package:budget_book/features/card_settlement/presentation/bloc/card_settlement_bloc.dart';
import 'package:budget_book/features/card_settlement/presentation/bloc/card_settlement_event.dart';
import 'package:budget_book/features/card_settlement/presentation/bloc/card_settlement_state.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';

class CardSettlementPage extends StatefulWidget {
  final String? initialCardId;
  final int? initialYear;
  final int? initialMonth;

  const CardSettlementPage({
    super.key,
    this.initialCardId,
    this.initialYear,
    this.initialMonth,
  });

  @override
  State<CardSettlementPage> createState() => _CardSettlementPageState();
}

class _CardSettlementPageState extends State<CardSettlementPage> {
  late final TextEditingController _amountController;
  String? _selectedCardId;
  String? _selectedBankId;
  late DateTime _selectedDate;
  late int _selectedYear;
  late int _selectedMonth;
  bool _useCustomAmount = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _selectedDate = DateTime.now();
    final now = DateTime.now();
    _selectedYear = widget.initialYear ?? now.year;
    _selectedMonth = widget.initialMonth ?? now.month;

    // Set initial card from param or pick the first credit card
    final pmState = getIt<PaymentMethodBloc>().state;
    if (pmState is PaymentMethodLoaded) {
      final creditCards = pmState.activePaymentMethods
          .where((pm) => pm.isCredit)
          .toList();
      if (widget.initialCardId != null) {
        _selectedCardId = widget.initialCardId;
      } else if (creditCards.isNotEmpty) {
        _selectedCardId = creditCards.first.id;
      }

      // Auto-select linked bank as default payment source
      if (_selectedCardId != null) {
        _selectLinkedBank(pmState.activePaymentMethods);
      }
    }

    // Load settlement data
    if (_selectedCardId != null) {
      _loadSettlement();
    }
  }

  void _selectLinkedBank(List<PaymentMethod> methods) {
    final card = methods.where((pm) => pm.id == _selectedCardId).firstOrNull;
    if (card?.linkedBankId != null) {
      _selectedBankId = card!.linkedBankId;
    } else {
      // Fallback to first BANK/DEBIT
      final bank = methods
          .where((pm) => pm.isBank || pm.isDebit)
          .firstOrNull;
      _selectedBankId = bank?.id;
    }
  }

  void _loadSettlement() {
    if (_selectedCardId == null) return;
    context.read<CardSettlementBloc>().add(LoadSettlement(
          paymentMethodId: _selectedCardId!,
          year: _selectedYear,
          month: _selectedMonth,
        ));
  }

  Future<void> _selectDate() async {
    final picked = await showCalendarPickerDialog(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    if (_selectedCardId == null || _selectedBankId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출금 계좌와 결제 카드를 모두 선택해주세요')),
      );
      return;
    }

    final blocState = context.read<CardSettlementBloc>().state;
    if (blocState is! CardSettlementLoaded) return;

    final amount = _useCustomAmount
        ? CurrencyFormatter.parse(_amountController.text) ?? 0
        : blocState.selectedAmount;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제 금액을 확인해주세요')),
      );
      return;
    }

    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카드 결제 확인'),
        content: Text(
          '${CurrencyFormatter.format(amount)}원을 결제하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              final dateStr =
                  DateFormat('yyyy-MM-dd').format(_selectedDate);
              context.read<CardSettlementBloc>().add(SubmitSettlement(
                    sourcePaymentMethodId: _selectedBankId!,
                    destinationPaymentMethodId: _selectedCardId!,
                    amount: amount,
                    date: dateStr,
                    description: '카드 결제',
                  ));
            },
            child: const Text('결제'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CardSettlementBloc, CardSettlementState>(
      listener: (context, state) {
        if (state is CardSettlementSuccess) {
          // Refresh related BLoCs
          getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
          getIt<PaymentMethodBloc>().add(LoadCardSettlementSummary(
            year: _selectedYear,
            month: _selectedMonth,
          ));
          final dashState = getIt<DashboardBloc>().state;
          final year = dashState is DashboardLoaded
              ? dashState.year
              : DateTime.now().year;
          final month = dashState is DashboardLoaded
              ? dashState.month
              : DateTime.now().month;
          getIt<DashboardBloc>().add(LoadDashboard(year: year, month: month));

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카드 결제가 완료되었습니다')),
          );
          context.pop();
        } else if (state is CardSettlementError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('카드 결제')),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final pmState = getIt<PaymentMethodBloc>().state;
    final methods = pmState is PaymentMethodLoaded
        ? pmState.activePaymentMethods
        : <PaymentMethod>[];
    final creditCards = methods.where((pm) => pm.isCredit).toList();
    final bankMethods =
        methods.where((pm) => pm.isBank || pm.isDebit).toList();

    return BlocBuilder<CardSettlementBloc, CardSettlementState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Card selection dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedCardId,
              decoration: const InputDecoration(
                labelText: '결제 카드',
                prefixIcon: Icon(Icons.credit_card),
              ),
              isExpanded: true,
              items: creditCards
                  .map((pm) => DropdownMenuItem(
                        value: pm.id,
                        child: Text(pm.name),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCardId = value;
                  _selectLinkedBank(methods);
                });
                _loadSettlement();
              },
            ),
            const SizedBox(height: 16),

            // 2. Month selector
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth--;
                      if (_selectedMonth < 1) {
                        _selectedMonth = 12;
                        _selectedYear--;
                      }
                    });
                    _loadSettlement();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '$_selectedYear년 $_selectedMonth월',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedMonth++;
                      if (_selectedMonth > 12) {
                        _selectedMonth = 1;
                        _selectedYear++;
                      }
                    });
                    _loadSettlement();
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Content based on state
            if (state is CardSettlementLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (state is CardSettlementLoaded) ...[
              // 3. Total amount summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '결제 대상 총액 (전월 사용)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${CurrencyFormatter.format(state.totalAmount)}원',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '선택 금액: ${CurrencyFormatter.format(state.selectedAmount)}원 (${state.selectedIds.length}건)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 4. Settlement amount (auto or custom)
              Row(
                children: [
                  Text(
                    '결제 금액',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _useCustomAmount = !_useCustomAmount;
                        if (_useCustomAmount) {
                          _amountController.text =
                              CurrencyFormatter.format(state.selectedAmount);
                        }
                      });
                    },
                    child: Text(_useCustomAmount ? '자동 계산' : '직접 입력'),
                  ),
                ],
              ),
              if (_useCustomAmount)
                AmountInputField(
                  controller: _amountController,
                  labelText: '결제 금액',
                  filterDigitsOnly: true,
                )
              else
                Card(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.3),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('결제 금액'),
                        Text(
                          '${CurrencyFormatter.format(state.selectedAmount)}원',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // 5. Source bank account
              DropdownButtonFormField<String>(
                initialValue: _selectedBankId,
                decoration: const InputDecoration(
                  labelText: '출금 계좌',
                  prefixIcon: Icon(Icons.account_balance),
                ),
                isExpanded: true,
                items: bankMethods
                    .map((pm) => DropdownMenuItem(
                          value: pm.id,
                          child: Text(pm.name),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedBankId = value);
                },
              ),
              const SizedBox(height: 16),

              // 6. Settlement date
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '결제일',
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    DateFormat('yyyy년 M월 d일 (E)', 'ko')
                        .format(_selectedDate),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 7. Transaction list (expandable)
              _buildTransactionList(context, state),
              const SizedBox(height: 24),

              // 8. Submit button
              FilledButton.icon(
                onPressed: state is CardSettlementSubmitting ? null : _submit,
                icon: const Icon(Icons.payment),
                label: Text(
                  '${CurrencyFormatter.format(_useCustomAmount ? (CurrencyFormatter.parse(_amountController.text) ?? 0) : state.selectedAmount)}원 결제',
                ),
              ),
            ] else if (state is CardSettlementError)
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      state.message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadSettlement,
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              )
            else if (state is CardSettlementSubmitting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_selectedCardId == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('결제할 카드를 선택해주세요'),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTransactionList(
      BuildContext context, CardSettlementLoaded state) {
    return Card(
      child: ExpansionTile(
        title: Row(
          children: [
            Text(
              '결제 항목 (${state.transactions.length}건)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            Checkbox(
              value: state.allSelected,
              tristate: state.selectedIds.isNotEmpty && !state.allSelected,
              onChanged: (value) {
                context
                    .read<CardSettlementBloc>()
                    .add(ToggleAllTransactions(value ?? false));
              },
            ),
          ],
        ),
        initiallyExpanded: true,
        children: [
          if (state.transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('결제 대상 거래가 없습니다'),
            )
          else
            ...state.transactions.map(
              (tx) => _buildTransactionTile(context, tx, state.selectedIds),
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    SettlementTransaction tx,
    Set<String> selectedIds,
  ) {
    final isSelected = selectedIds.contains(tx.id);
    return CheckboxListTile(
      value: isSelected,
      onChanged: (_) {
        context.read<CardSettlementBloc>().add(ToggleTransaction(tx.id));
      },
      title: Row(
        children: [
          if (tx.isTransfer)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.swap_horiz, size: 16,
                  color: Theme.of(context).colorScheme.tertiary),
            ),
          Expanded(
            child: Text(
              tx.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${tx.transactionDate}${tx.isTransfer ? ' (이체)' : ''}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
      ),
      secondary: Text(
        '${CurrencyFormatter.format(tx.amount)}원',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
      dense: true,
    );
  }
}
