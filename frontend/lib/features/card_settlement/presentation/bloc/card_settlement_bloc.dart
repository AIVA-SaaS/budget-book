import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/card_settlement/domain/repositories/card_settlement_repository.dart';
import 'package:budget_book/features/transfer/domain/repositories/transfer_repository.dart';
import 'card_settlement_event.dart';
import 'card_settlement_state.dart';

class CardSettlementBloc
    extends Bloc<CardSettlementEvent, CardSettlementState> {
  final CardSettlementRepository cardSettlementRepository;
  final TransferRepository transferRepository;

  CardSettlementBloc({
    required this.cardSettlementRepository,
    required this.transferRepository,
  }) : super(const CardSettlementInitial()) {
    on<LoadSettlement>(_onLoadSettlement);
    on<ToggleTransaction>(_onToggleTransaction);
    on<ToggleAllTransactions>(_onToggleAllTransactions);
    on<UpdateCustomAmount>(_onUpdateCustomAmount);
    on<SubmitSettlement>(_onSubmitSettlement);
    on<UpdateSettlement>(_onUpdateSettlement);
  }

  Future<void> _onLoadSettlement(
    LoadSettlement event,
    Emitter<CardSettlementState> emit,
  ) async {
    // 회차 12 follow-up — race fix.
    if (state is! CardSettlementLoaded) {
      emit(const CardSettlementLoading());
    }

    final result = await cardSettlementRepository.getSettlementTransactions(
      paymentMethodId: event.paymentMethodId,
      year: event.year,
      month: event.month,
      settlementTransferId: event.settlementTransferId,
    );

    result.fold(
      (failure) {
        if (state is! CardSettlementLoaded) {
          emit(CardSettlementError(failure.message));
        }
      },
      (response) {
        // 편집 모드: 이 정산에 이미 묶인 거래만 pre-select.
        // 생성 모드: 후보 거래 전부 select (기존 동작 유지).
        final editingId = event.settlementTransferId;
        final selectedIds = editingId != null
            ? response.transactions
                .where((t) => t.settlementTransferId == editingId)
                .map((t) => t.id)
                .toSet()
            : response.transactions.map((t) => t.id).toSet();
        emit(CardSettlementLoaded(
          transactions: response.transactions,
          selectedIds: selectedIds,
          totalAmount: response.totalAmount,
        ));
      },
    );
  }

  void _onToggleTransaction(
    ToggleTransaction event,
    Emitter<CardSettlementState> emit,
  ) {
    final currentState = state;
    if (currentState is! CardSettlementLoaded) return;

    final newSelectedIds = Set<String>.from(currentState.selectedIds);
    if (newSelectedIds.contains(event.transactionId)) {
      newSelectedIds.remove(event.transactionId);
    } else {
      newSelectedIds.add(event.transactionId);
    }

    emit(CardSettlementLoaded(
      transactions: currentState.transactions,
      selectedIds: newSelectedIds,
      totalAmount: currentState.totalAmount,
      customAmount: currentState.customAmount,
    ));
  }

  void _onToggleAllTransactions(
    ToggleAllTransactions event,
    Emitter<CardSettlementState> emit,
  ) {
    final currentState = state;
    if (currentState is! CardSettlementLoaded) return;

    final newSelectedIds = event.selected
        ? currentState.transactions.map((t) => t.id).toSet()
        : <String>{};

    emit(CardSettlementLoaded(
      transactions: currentState.transactions,
      selectedIds: newSelectedIds,
      totalAmount: currentState.totalAmount,
      customAmount: currentState.customAmount,
    ));
  }

  void _onUpdateCustomAmount(
    UpdateCustomAmount event,
    Emitter<CardSettlementState> emit,
  ) {
    final currentState = state;
    if (currentState is! CardSettlementLoaded) return;

    emit(CardSettlementLoaded(
      transactions: currentState.transactions,
      selectedIds: currentState.selectedIds,
      totalAmount: currentState.totalAmount,
      customAmount: event.amount,
    ));
  }

  Future<void> _onSubmitSettlement(
    SubmitSettlement event,
    Emitter<CardSettlementState> emit,
  ) async {
    emit(const CardSettlementSubmitting());

    // 신규 카드 결제 API: Transfer(is_card_settlement=true) + 거래 paid_at 일괄 업데이트
    final result = await transferRepository.createCardSettlement(
      sourcePaymentMethodId: event.sourcePaymentMethodId,
      destinationPaymentMethodId: event.destinationPaymentMethodId,
      amount: event.amount,
      description: event.description,
      transferDate: event.date,
      transactionIds: event.transactionIds,
    );

    result.fold(
      (failure) => emit(CardSettlementError(failure.message)),
      (_) => emit(const CardSettlementSuccess()),
    );
  }

  Future<void> _onUpdateSettlement(
    UpdateSettlement event,
    Emitter<CardSettlementState> emit,
  ) async {
    emit(const CardSettlementSubmitting());

    // 카드 정산 수정 API: 기존 링크 거래 unmark + 새 선택 거래 mark 를 BE 가 처리.
    final result = await transferRepository.updateCardSettlement(
      transferId: event.transferId,
      sourcePaymentMethodId: event.sourcePaymentMethodId,
      destinationPaymentMethodId: event.destinationPaymentMethodId,
      amount: event.amount,
      description: event.description,
      transferDate: event.date,
      transactionIds: event.transactionIds,
    );

    result.fold(
      (failure) => emit(CardSettlementError(failure.message)),
      (_) => emit(const CardSettlementSuccess()),
    );
  }
}
