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
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';

class CardSettlementPage extends StatefulWidget {
  final String? initialCardId;
  final int? initialYear;
  final int? initialMonth;

  /// 편집 모드: 수정 대상 카드 정산(Transfer)의 ID. null 이면 신규 생성 모드.
  final String? settlementTransferId;

  /// 편집 모드 프리필: 출금 계좌(source) ID.
  final String? initialBankId;

  /// 편집 모드 프리필: 결제 금액.
  final int? initialAmount;

  /// 편집 모드 프리필: 결제일(yyyy-MM-dd).
  final String? initialDate;

  const CardSettlementPage({
    super.key,
    this.initialCardId,
    this.initialYear,
    this.initialMonth,
    this.settlementTransferId,
    this.initialBankId,
    this.initialAmount,
    this.initialDate,
  });

  bool get isEditing => settlementTransferId != null;

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

  bool get _isEditing => widget.settlementTransferId != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    final now = DateTime.now();
    // 편집 모드 프리필 날짜 (yyyy-MM-dd). 파싱 실패 시 오늘.
    _selectedDate = DateTime.tryParse(widget.initialDate ?? '') ?? now;
    _selectedYear = widget.initialYear ?? now.year;
    _selectedMonth = widget.initialMonth ?? now.month;

    // 편집 모드: 직접 입력 금액으로 프리필.
    if (_isEditing && widget.initialAmount != null) {
      _useCustomAmount = true;
      _amountController.text =
          CurrencyFormatter.format(widget.initialAmount!);
    }

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

      // 편집 모드: 프리필된 출금 계좌 우선. 아니면 카드 연결 계좌 자동 선택.
      if (_isEditing && widget.initialBankId != null) {
        _selectedBankId = widget.initialBankId;
      } else if (_selectedCardId != null) {
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
          settlementTransferId: widget.settlementTransferId,
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
        title: Text(_isEditing ? '카드 정산 수정 확인' : '카드 결제 확인'),
        content: Text(
          _isEditing
              ? '${CurrencyFormatter.format(amount)}원으로 정산을 수정하시겠습니까?'
              : '${CurrencyFormatter.format(amount)}원을 결제하시겠습니까?',
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
              // 선택된 거래 중 TRANSACTION 타입만 paid_at 업데이트 대상
              // (TRANSFER는 이미 이체이므로 별도 결제 완료 처리 불필요)
              final selectedTransactionIds = blocState.transactions
                  .where((t) =>
                      blocState.selectedIds.contains(t.id) && !t.isTransfer)
                  .map((t) => t.id)
                  .toList();
              if (_isEditing) {
                context.read<CardSettlementBloc>().add(UpdateSettlement(
                      transferId: widget.settlementTransferId!,
                      sourcePaymentMethodId: _selectedBankId!,
                      destinationPaymentMethodId: _selectedCardId!,
                      amount: amount,
                      date: dateStr,
                      description: '카드 결제',
                      transactionIds: selectedTransactionIds,
                    ));
              } else {
                context.read<CardSettlementBloc>().add(SubmitSettlement(
                      sourcePaymentMethodId: _selectedBankId!,
                      destinationPaymentMethodId: _selectedCardId!,
                      amount: amount,
                      date: dateStr,
                      description: '카드 결제',
                      transactionIds: selectedTransactionIds,
                    ));
              }
            },
            child: Text(_isEditing ? '수정' : '결제'),
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
          // 거래내역 갱신 — 결제 대상 거래들의 paid_at 업데이트 + 신규 정산
          // 이체(Transfer, 결제일 _selectedDate 기준 생성) 가 거래 목록(거래+이체
          // 병합 뷰)에 즉시 보이도록 셀프 경로에서 직접 갱신.
          // (WebSocket 경로는 authorId 체크로 본인 이벤트 스킵)
          // 정산 이체가 사는 결제일의 달로 거래/이체 BLoC 을 함께 로드해 두
          // BLoC 의 월을 일치시킨다 (과거: TransferBloc 미갱신 → 탭 재진입 전까지
          // 정산 이체 미노출).
          getIt<TransactionBloc>().add(LoadTransactions.monthOnly(
            _selectedDate.year,
            _selectedDate.month,
          ));
          getIt<TransferBloc>().add(LoadTransfers(
            year: _selectedDate.year,
            month: _selectedDate.month,
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
            SnackBar(
              content: Text(_isEditing ? '카드 정산이 수정되었습니다' : '카드 결제가 완료되었습니다'),
            ),
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
        appBar: AppBar(title: Text(_isEditing ? '카드 정산 수정' : '카드 결제')),
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
                icon: Icon(_isEditing ? Icons.save : Icons.payment),
                label: Text(
                  '${CurrencyFormatter.format(_useCustomAmount ? (CurrencyFormatter.parse(_amountController.text) ?? 0) : state.selectedAmount)}원 ${_isEditing ? '수정' : '결제'}',
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
