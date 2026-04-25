import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/domain/repositories/payment_method_repository.dart';
import 'payment_method_event.dart';
import 'payment_method_state.dart';

class PaymentMethodBloc
    extends Bloc<PaymentMethodEvent, PaymentMethodState> {
  final PaymentMethodRepository paymentMethodRepository;

  PaymentMethodBloc({required this.paymentMethodRepository})
      : super(const PaymentMethodInitial()) {
    on<LoadPaymentMethods>(_onLoadPaymentMethods);
    on<CreatePaymentMethod>(_onCreatePaymentMethod);
    on<UpdatePaymentMethod>(_onUpdatePaymentMethod);
    on<DeletePaymentMethod>(_onDeletePaymentMethod);
    on<LoadCardPending>(_onLoadCardPending);
    on<LoadCardSettlementSummary>(_onLoadCardSettlementSummary);
    on<ReorderPaymentMethods>(_onReorderPaymentMethods);
  }

  Future<void> _onLoadPaymentMethods(
    LoadPaymentMethods event,
    Emitter<PaymentMethodState> emit,
  ) async {
    try {
      emit(const PaymentMethodLoading());
      final result = await paymentMethodRepository.getPaymentMethods();
      result.fold(
        (failure) => emit(PaymentMethodError(failure.message)),
        (methods) {
          emit(PaymentMethodLoaded(methods));
          // Auto-load card settlement summary if credit cards exist
          if (methods.any((pm) => pm.isCredit)) {
            final now = DateTime.now();
            add(LoadCardSettlementSummary(year: now.year, month: now.month));
          }
        },
      );
    } catch (_) {
      emit(const PaymentMethodError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCreatePaymentMethod(
    CreatePaymentMethod event,
    Emitter<PaymentMethodState> emit,
  ) async {
    try {
      final currentMethods = state is PaymentMethodLoaded
          ? (state as PaymentMethodLoaded).paymentMethods
          : <PaymentMethod>[];
      final currentPendings = state is PaymentMethodLoaded
          ? (state as PaymentMethodLoaded).cardPendings
          : null;

      final result = await paymentMethodRepository.createPaymentMethod(
        name: event.name,
        type: event.type,
        settlementDay: event.settlementDay,
        closingDay: event.closingDay,
        linkedBankId: event.linkedBankId,
      );
      result.fold(
        (failure) => emit(PaymentMethodLoaded(
          currentMethods,
          cardPendings: currentPendings,
          operationError: failure.message,
        )),
        (method) => emit(PaymentMethodLoaded(
          [...currentMethods, method],
          cardPendings: currentPendings,
        )),
      );
    } catch (_) {
      if (state is PaymentMethodLoaded) {
        final loaded = state as PaymentMethodLoaded;
        emit(PaymentMethodLoaded(
          loaded.paymentMethods,
          cardPendings: loaded.cardPendings,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const PaymentMethodError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onUpdatePaymentMethod(
    UpdatePaymentMethod event,
    Emitter<PaymentMethodState> emit,
  ) async {
    try {
      final currentMethods = state is PaymentMethodLoaded
          ? (state as PaymentMethodLoaded).paymentMethods
          : <PaymentMethod>[];
      final currentPendings = state is PaymentMethodLoaded
          ? (state as PaymentMethodLoaded).cardPendings
          : null;

      final result = await paymentMethodRepository.updatePaymentMethod(
        id: event.id,
        name: event.name,
        settlementDay: event.settlementDay,
        closingDay: event.closingDay,
        isActive: event.isActive,
        displayOrder: event.displayOrder,
        linkedBankId: event.linkedBankId,
        clearLinkedBank: event.clearLinkedBank,
      );
      result.fold(
        (failure) => emit(PaymentMethodLoaded(
          currentMethods,
          cardPendings: currentPendings,
          operationError: failure.message,
        )),
        (updated) {
          final updatedList = currentMethods
              .map((pm) => pm.id == updated.id ? updated : pm)
              .toList();
          emit(PaymentMethodLoaded(
            updatedList,
            cardPendings: currentPendings,
          ));
        },
      );
    } catch (_) {
      if (state is PaymentMethodLoaded) {
        final loaded = state as PaymentMethodLoaded;
        emit(PaymentMethodLoaded(
          loaded.paymentMethods,
          cardPendings: loaded.cardPendings,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const PaymentMethodError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onDeletePaymentMethod(
    DeletePaymentMethod event,
    Emitter<PaymentMethodState> emit,
  ) async {
    try {
      final currentMethods = state is PaymentMethodLoaded
          ? (state as PaymentMethodLoaded).paymentMethods
          : <PaymentMethod>[];
      final currentPendings = state is PaymentMethodLoaded
          ? (state as PaymentMethodLoaded).cardPendings
          : null;

      final result =
          await paymentMethodRepository.deletePaymentMethod(event.id);
      result.fold(
        (failure) => emit(PaymentMethodLoaded(
          currentMethods,
          cardPendings: currentPendings,
          operationError: failure.message,
        )),
        (_) {
          final updatedList =
              currentMethods.where((pm) => pm.id != event.id).toList();
          emit(PaymentMethodLoaded(
            updatedList,
            cardPendings: currentPendings,
          ));
        },
      );
    } catch (_) {
      if (state is PaymentMethodLoaded) {
        final loaded = state as PaymentMethodLoaded;
        emit(PaymentMethodLoaded(
          loaded.paymentMethods,
          cardPendings: loaded.cardPendings,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const PaymentMethodError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onLoadCardPending(
    LoadCardPending event,
    Emitter<PaymentMethodState> emit,
  ) async {
    try {
      final currentMethods = state is PaymentMethodLoaded
          ? (state as PaymentMethodLoaded).paymentMethods
          : <PaymentMethod>[];

      final result = await paymentMethodRepository.getCardPending(
        event.year,
        event.month,
      );
      result.fold(
        (failure) => emit(PaymentMethodLoaded(
          currentMethods,
          operationError: failure.message,
        )),
        (pendings) => emit(PaymentMethodLoaded(
          currentMethods,
          cardPendings: pendings,
        )),
      );
    } catch (_) {
      if (state is PaymentMethodLoaded) {
        final loaded = state as PaymentMethodLoaded;
        emit(PaymentMethodLoaded(
          loaded.paymentMethods,
          cardPendings: loaded.cardPendings,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const PaymentMethodError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onLoadCardSettlementSummary(
    LoadCardSettlementSummary event,
    Emitter<PaymentMethodState> emit,
  ) async {
    try {
      final currentMethods = state is PaymentMethodLoaded
          ? (state as PaymentMethodLoaded).paymentMethods
          : <PaymentMethod>[];
      final currentPendings = state is PaymentMethodLoaded
          ? (state as PaymentMethodLoaded).cardPendings
          : null;

      final result =
          await paymentMethodRepository.getCardSettlementSummary(year: event.year, month: event.month);
      result.fold(
        (failure) => emit(PaymentMethodLoaded(
          currentMethods,
          cardPendings: currentPendings,
          operationError: failure.message,
        )),
        (summary) => emit(PaymentMethodLoaded(
          currentMethods,
          cardPendings: currentPendings,
          cardSettlementSummary: summary,
        )),
      );
    } catch (_) {
      if (state is PaymentMethodLoaded) {
        final loaded = state as PaymentMethodLoaded;
        emit(PaymentMethodLoaded(
          loaded.paymentMethods,
          cardPendings: loaded.cardPendings,
          cardSettlementSummary: loaded.cardSettlementSummary,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const PaymentMethodError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onReorderPaymentMethods(
    ReorderPaymentMethods event,
    Emitter<PaymentMethodState> emit,
  ) async {
    final currentMethods = state is PaymentMethodLoaded
        ? (state as PaymentMethodLoaded).paymentMethods
        : <PaymentMethod>[];
    final currentPendings = state is PaymentMethodLoaded
        ? (state as PaymentMethodLoaded).cardPendings
        : null;
    final currentSummary = state is PaymentMethodLoaded
        ? (state as PaymentMethodLoaded).cardSettlementSummary
        : null;

    // Compute desired ordering (event ids first, then any unspecified at end).
    // CRITICAL: 각 entity 의 displayOrder 도 새 인덱스로 갱신해야 함.
    // 이를 누락하면 builder 가 sort by displayOrder 시 원래 순서로 복귀하여
    // "Optimistic update 가 즉시 되돌아가는" 회귀 발생 (#155~#158 의 진짜 원인).
    final orderedPool = <String, PaymentMethod>{
      for (final pm in currentMethods) pm.id: pm,
    };
    final reordered = <PaymentMethod>[];
    for (final id in event.orderedIds) {
      final pm = orderedPool[id];
      if (pm != null) {
        reordered.add(pm.copyWith(displayOrder: reordered.length));
      }
    }
    for (final pm in currentMethods) {
      if (!event.orderedIds.contains(pm.id)) {
        reordered.add(pm.copyWith(displayOrder: reordered.length));
      }
    }

    // Idempotent dedup: 현재 순서와 동일하면 no-op.
    // - Flutter ReorderableListView 가 동일 drop 에 대해 onReorder 를 두 번
    //   fire 하는 케이스 방지 (Optimistic emit 으로 인한 rebuild 와 충돌)
    // - 동일 페이로드 재호출 (다른 경로/refresh) 시 BE 부하 절감
    final currentOrder = currentMethods.map((m) => m.id).toList();
    final desiredOrder = reordered.map((m) => m.id).toList();
    if (listEquals(currentOrder, desiredOrder)) {
      return;
    }

    // Optimistic update — reordered list + 갱신된 displayOrder
    emit(PaymentMethodLoaded(
      reordered,
      cardPendings: currentPendings,
      cardSettlementSummary: currentSummary,
    ));

    try {
      final result =
          await paymentMethodRepository.reorderPaymentMethods(event.orderedIds);
      result.fold(
        (failure) {
          // Rollback on failure
          emit(PaymentMethodLoaded(
            currentMethods,
            cardPendings: currentPendings,
            cardSettlementSummary: currentSummary,
            operationError: failure.message,
          ));
        },
        (_) {
          // Already showing reordered state
        },
      );
    } catch (_) {
      // Rollback on unexpected error
      emit(PaymentMethodLoaded(
        currentMethods,
        cardPendings: currentPendings,
        cardSettlementSummary: currentSummary,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }
}
