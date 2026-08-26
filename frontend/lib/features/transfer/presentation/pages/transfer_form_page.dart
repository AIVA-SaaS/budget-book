import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/utils/currency_formatter.dart';
import 'package:budget_book/core/widgets/amount_input_field.dart';
import 'package:budget_book/core/widgets/calendar_picker_dialog.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_state.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_state.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_bloc.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_event.dart';
import 'package:budget_book/features/transfer/presentation/bloc/transfer_state.dart';
import '../../../../core/theme/bb_scale.dart';

class TransferFormPage extends StatefulWidget {
  final String? transferId;

  const TransferFormPage({super.key, this.transferId});

  @override
  State<TransferFormPage> createState() => _TransferFormPageState();
}

class _TransferFormPageState extends State<TransferFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _memoController;
  String? _sourcePaymentMethodId;
  String? _destinationPaymentMethodId;
  late DateTime _selectedDate;
  bool _isSubmitting = false;
  Transfer? _existingTransfer;
  int _swapCounter = 0;
  // Transfer kind: GENERIC (순수 이체) / EXPENSE_TRANSFER (지출로 반영) /
  // INCOME_TRANSFER (수입으로 반영). CARD_SETTLEMENT is set via the dedicated
  // card settlement flow (payment_method card settlement page), not this form.
  TransferKind _kind = TransferKind.generic;
  // Whether the user has manually overridden the auto-recommended kind.
  // Once true, we stop auto-recommending on source/dest changes.
  bool _kindOverridden = false;

  bool get isEditing => widget.transferId != null;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _descriptionController = TextEditingController();
    _memoController = TextEditingController();
    _selectedDate = DateTime.now();

    if (isEditing) {
      _loadExistingTransfer();
    }
  }

  void _loadExistingTransfer() {
    final bloc = context.read<TransferBloc>();
    final state = bloc.state;
    if (state is TransferLoaded) {
      final transfer =
          state.transfers.where((t) => t.id == widget.transferId).firstOrNull;
      if (transfer != null) {
        _populateForm(transfer);
      }
    }
  }

  void _populateForm(Transfer transfer) {
    _existingTransfer = transfer;
    _amountController.text = CurrencyFormatter.format(transfer.amount);
    _descriptionController.text = transfer.description ?? '';
    _memoController.text = transfer.memo ?? '';
    _sourcePaymentMethodId = transfer.sourcePaymentMethod.id;
    _destinationPaymentMethodId = transfer.destinationPaymentMethod.id;
    _kind = transfer.kind;
    // Editing a transfer should preserve the stored kind unless the user
    // changes it, even if source/dest happen to differ.
    _kindOverridden = true;
    try {
      _selectedDate = DateTime.parse(transfer.transferDate);
    } catch (_) {}
  }

  /// Recommend a kind based on source/destination payment method types.
  /// Only GENERIC is auto-picked here; EXPENSE_TRANSFER / INCOME_TRANSFER
  /// are user-driven. CARD_SETTLEMENT is out of scope for this form.
  TransferKind _recommendKind({
    required String? sourceType,
    required String? destType,
  }) {
    // We default to GENERIC; the user can override to EXPENSE/INCOME_TRANSFER.
    // (BANK → CREDIT should go through the card settlement page, not here.)
    return TransferKind.generic;
  }

  void _maybeAutoRecommendKind({
    required String? sourceType,
    required String? destType,
  }) {
    if (_kindOverridden) return;
    final recommended = _recommendKind(
      sourceType: sourceType,
      destType: destType,
    );
    if (recommended != _kind) {
      setState(() => _kind = recommended);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _memoController.dispose();
    super.dispose();
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

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이체 삭제'),
        content: const Text('정말 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context
                  .read<TransferBloc>()
                  .add(DeleteTransfer(widget.transferId!));
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_sourcePaymentMethodId == null || _destinationPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출금/입금 결제수단을 모두 선택해주세요')),
      );
      return;
    }
    if (_sourcePaymentMethodId == _destinationPaymentMethodId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('출금/입금 결제수단이 같을 수 없습니다')),
      );
      return;
    }

    // Block CREDIT↔CREDIT transfers
    final pmState = getIt<PaymentMethodBloc>().state;
    if (pmState is PaymentMethodLoaded) {
      final source = pmState.activePaymentMethods
          .where((pm) => pm.id == _sourcePaymentMethodId)
          .firstOrNull;
      final dest = pmState.activePaymentMethods
          .where((pm) => pm.id == _destinationPaymentMethodId)
          .firstOrNull;
      if (source != null && dest != null && source.isCredit && dest.isCredit) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카드 간 이체는 지원하지 않습니다')),
        );
        return;
      }
    }

    final amount = CurrencyFormatter.parse(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액을 입력해주세요')),
      );
      return;
    }

    final description = _descriptionController.text.trim().isEmpty
        ? null
        : _descriptionController.text.trim();
    final memo = _memoController.text.trim().isEmpty
        ? null
        : _memoController.text.trim();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    setState(() => _isSubmitting = true);

    final bloc = context.read<TransferBloc>();

    if (isEditing) {
      final oldDescription = _existingTransfer?.description;
      final clearDescription = description == null && oldDescription != null;
      final oldMemo = _existingTransfer?.memo;
      final clearMemo = memo == null && oldMemo != null;

      bloc.add(UpdateTransfer(
        id: widget.transferId!,
        sourcePaymentMethodId: _sourcePaymentMethodId,
        destinationPaymentMethodId: _destinationPaymentMethodId,
        amount: amount,
        description: description,
        clearDescription: clearDescription,
        transferDate: dateStr,
        memo: memo,
        clearMemo: clearMemo,
        kind: _kind,
      ));
    } else {
      bloc.add(CreateTransfer(
        sourcePaymentMethodId: _sourcePaymentMethodId!,
        destinationPaymentMethodId: _destinationPaymentMethodId!,
        amount: amount,
        description: description,
        transferDate: dateStr,
        memo: memo,
        kind: _kind,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TransferBloc, TransferState>(
      listener: (context, state) {
        if (state is TransferLoaded) {
          if (state.operationSuccess != null) {
            // Delete success
            final dashState = getIt<DashboardBloc>().state;
            final year = dashState is DashboardLoaded
                ? dashState.year
                : DateTime.now().year;
            final month = dashState is DashboardLoaded
                ? dashState.month
                : DateTime.now().month;
            getIt<DashboardBloc>().add(LoadDashboard(year: year, month: month));
            getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.operationSuccess!)),
            );
            context.pop();
            return;
          }
          if (_isSubmitting) {
            if (state.operationError != null) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.operationError!),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            } else {
              final dashState = getIt<DashboardBloc>().state;
              final year = dashState is DashboardLoaded
                  ? dashState.year
                  : DateTime.now().year;
              final month = dashState is DashboardLoaded
                  ? dashState.month
                  : DateTime.now().month;
              getIt<DashboardBloc>()
                  .add(LoadDashboard(year: year, month: month));
              getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
              context.pop();
            }
          }
        } else if (state is TransferError && _isSubmitting) {
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
          title: Text(isEditing ? '이체 수정' : '이체 추가'),
          actions: [
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _isSubmitting ? null : () => _confirmDelete(context),
              ),
          ],
          bottom: _showsTypeSelector
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(48),
                  child: _buildTypeSelector(context),
                )
              : null,
        ),
        body: _buildForm(context),
      ),
    );
  }

  /// 유형 선택기를 보일 조건 (2026-08-09).
  ///
  /// 수정 모드에서 원본 이체를 읽어온 뒤에만 보인다 — 종류를 모르면 카드 결제 이체를
  /// 걸러낼 수 없다. 카드 결제는 전용 플로우(`/card-settlement`)가 있어 애초에 이 폼으로
  /// 오지 않지만, 서버도 400 으로 막는 규칙이라 UI 에서도 선택지를 주지 않는다.
  bool get _showsTypeSelector =>
      isEditing &&
      _existingTransfer != null &&
      _existingTransfer!.kind != TransferKind.cardSettlement;

  /// 유형 선택 — 지출 / 수입 / 이체. 거래 폼의 수정 모드 선택기(`_buildEditTypeSelector`)와
  /// 같은 모양이다.
  ///
  /// 지출/수입을 고르면 **거래 폼으로 보낸다**. 이 폼에 카테고리·포켓 피커를 복제하지 않기
  /// 위해서다 — 변환은 언제나 거래 폼에서 일어난다(거래 → 이체 방향도 마찬가지).
  Widget _buildTypeSelector(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Text(
              '유형',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(width: 8),
            SegmentedButton<String>(
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                ButtonSegment(
                  value: 'EXPENSE',
                  icon: Icon(Icons.arrow_downward, size: context.bbType.iconSm),
                  label: const Text('지출'),
                ),
                ButtonSegment(
                  value: 'INCOME',
                  icon: Icon(Icons.arrow_upward, size: context.bbType.iconSm),
                  label: const Text('수입'),
                ),
                ButtonSegment(
                  value: 'TRANSFER',
                  icon: Icon(Icons.swap_horiz, size: context.bbType.iconSm),
                  label: const Text('이체'),
                ),
              ],
              selected: const {'TRANSFER'},
              showSelectedIcon: false,
              onSelectionChanged: (selection) {
                if (selection.isEmpty) return;
                _onTypeSelected(selection.first);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _onTypeSelected(String next) {
    if (next == 'TRANSFER') return;
    // 거래 폼이 원본 이체를 fetch 해 prefill 한다 (query param 이라 새로고침에도 유지).
    final tab = next == 'INCOME' ? 'income' : 'expense';
    context.push(
      '/transactions/create'
      '?convertFromTransferId=${widget.transferId}&tab=$tab',
    );
  }

  Widget _buildForm(BuildContext context) {
    final pmState = getIt<PaymentMethodBloc>().state;
    final methods = pmState is PaymentMethodLoaded
        ? pmState.activePaymentMethods
        : <PaymentMethod>[];

    // Determine if selected payment methods are CREDIT
    final selectedDest =
        methods.where((pm) => pm.id == _destinationPaymentMethodId).firstOrNull;
    final selectedSource =
        methods.where((pm) => pm.id == _sourcePaymentMethodId).firstOrNull;
    final destIsCredit = selectedDest?.isCredit ?? false;
    final sourceIsCredit = selectedSource?.isCredit ?? false;

    // Filter source list: exclude CREDIT if destination is CREDIT
    final sourceMethods =
        destIsCredit ? methods.where((pm) => !pm.isCredit).toList() : methods;
    // Filter dest list: exclude source + exclude CREDIT if source is CREDIT
    final destMethods = methods
        .where((pm) => pm.id != _sourcePaymentMethodId)
        .where((pm) => !sourceIsCredit || !pm.isCredit)
        .toList();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Date (matches transaction form order: date first)
          InkWell(
            onTap: _selectDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '이체일',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selectedDate),
              ),
            ),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // Amount
          AmountInputField(
            controller: _amountController,
            labelText: '금액',
            filterDigitsOnly: true,
            validator: (value) {
              if (value == null || value.isEmpty) return '금액을 입력하세요';
              final amount = CurrencyFormatter.parse(value);
              if (amount == null || amount <= 0) return '유효한 금액을 입력하세요';
              if (amount > 999999999) return '최대 999,999,999원까지 입력 가능합니다';
              return null;
            },
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // Source payment method
          DropdownButtonFormField<String>(
            key: ValueKey('source_$_swapCounter'),
            initialValue: _sourcePaymentMethodId,
            decoration: const InputDecoration(
              labelText: '출금 결제수단',
              prefixIcon: Icon(Icons.account_balance_wallet),
            ),
            isExpanded: true,
            items: sourceMethods
                .map((pm) => DropdownMenuItem(
                      value: pm.id,
                      child: Text(pm.name),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _sourcePaymentMethodId = value;
                final newSource =
                    methods.where((pm) => pm.id == value).firstOrNull;
                if (newSource?.isCredit == true &&
                    selectedDest?.isCredit == true) {
                  _destinationPaymentMethodId = null;
                }
              });
              _maybeAutoRecommendKind(
                sourceType:
                    methods.where((pm) => pm.id == value).firstOrNull?.type,
                destType: selectedDest?.type,
              );
            },
            validator: (value) => value == null ? '출금 결제수단을 선택하세요' : null,
          ),
          context.bbSpace.gapV(BbSpaceToken.lg),
          // Swap button
          Center(
            child: IconButton(
              onPressed: () {
                final wouldSwapSourceBeCredit = selectedDest?.isCredit ?? false;
                final wouldSwapDestBeCredit = selectedSource?.isCredit ?? false;
                if (wouldSwapSourceBeCredit && wouldSwapDestBeCredit) return;
                setState(() {
                  final temp = _sourcePaymentMethodId;
                  _sourcePaymentMethodId = _destinationPaymentMethodId;
                  _destinationPaymentMethodId = temp;
                  _swapCounter++;
                });
              },
              icon: const Icon(Icons.swap_vert),
              tooltip: '출금/입금 교환',
            ),
          ),
          context.bbSpace.gapV(BbSpaceToken.lg),
          // Destination payment method
          DropdownButtonFormField<String>(
            key: ValueKey('dest_$_swapCounter'),
            initialValue: _destinationPaymentMethodId,
            decoration: const InputDecoration(
              labelText: '입금 결제수단',
              prefixIcon: Icon(Icons.account_balance),
            ),
            isExpanded: true,
            items: destMethods
                .map((pm) => DropdownMenuItem(
                      value: pm.id,
                      child: Text(pm.name),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _destinationPaymentMethodId = value;
                final newDest =
                    methods.where((pm) => pm.id == value).firstOrNull;
                if (newDest?.isCredit == true &&
                    selectedSource?.isCredit == true) {
                  _sourcePaymentMethodId = null;
                  _swapCounter++;
                }
              });
              _maybeAutoRecommendKind(
                sourceType: selectedSource?.type,
                destType:
                    methods.where((pm) => pm.id == value).firstOrNull?.type,
              );
            },
            validator: (value) => value == null ? '입금 결제수단을 선택하세요' : null,
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // Transfer kind (Phase 22 §2.1) — user can override the default.
          // Card settlement (BANK→CREDIT) is handled via a dedicated card
          // settlement flow, so it is intentionally not offered here.
          DropdownButtonFormField<TransferKind>(
            initialValue: _kind,
            decoration: const InputDecoration(
              labelText: '종류',
              prefixIcon: Icon(Icons.category_outlined),
              helperText: '이체의 성격을 선택하세요. 기본은 "순수 이체" 입니다.',
            ),
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: TransferKind.generic,
                child: Text('순수 이체 (통계 제외)'),
              ),
              DropdownMenuItem(
                value: TransferKind.expenseTransfer,
                child: Text('지출로 반영'),
              ),
              DropdownMenuItem(
                value: TransferKind.incomeTransfer,
                child: Text('수입으로 반영'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _kind = value;
                _kindOverridden = true;
              });
            },
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // Description
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: '설명 (선택)',
              prefixIcon: Icon(Icons.description),
              hintText: '예: ATM 출금',
            ),
            maxLength: 255,
          ),
          context.bbSpace.gapV(BbSpaceToken.lg),
          // Memo
          TextFormField(
            controller: _memoController,
            decoration: const InputDecoration(
              labelText: '메모 (선택)',
              prefixIcon: Icon(Icons.notes),
            ),
            maxLines: 2,
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
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
