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
      // 회차 12 follow-up (2026-05-04) — race 회귀 fix.
      // 이전: 항상 PaymentMethodLoading emit → fetch → Loaded.
      //   결과: 자산 탭 진입 시 기존 Loaded data 가 잠시 빈 상태 (Loading) 로
      //   transition → _AssetSummaryHeader 가 SizedBox.shrink → "총자산 안 나옴"
      //   + _PaymentMethodTab 도 빈 화면 ("결제수단이 없습니다" 처럼 보임).
      // 신규: 기존 Loaded 가 있으면 그대로 keep, fetch 후 update. Loading 은 첫
      //   진입 (Initial/Error 상태) 에서만 emit.
      final currentLoaded =
          state is PaymentMethodLoaded ? state as PaymentMethodLoaded : null;
      if (currentLoaded == null) {
        emit(const PaymentMethodLoading());
      }
      final result = await paymentMethodRepository.getPaymentMethods();
      result.fold(
        (failure) {
          if (currentLoaded != null) {
            // 기존 data 보존 + 에러만 표시
            emit(PaymentMethodLoaded(
              currentLoaded.paymentMethods,
              cardPendings: currentLoaded.cardPendings,
              cardSettlementSummary: currentLoaded.cardSettlementSummary,
              operationError: failure.message,
            ));
          } else {
            emit(PaymentMethodError(failure.message));
          }
        },
        (methods) {
          emit(PaymentMethodLoaded(
            methods,
            // 기존 settlement summary / cardPendings 는 별도 event 로 갱신.
            // 첫 fetch 가 아니면 보존하여 잠시 사라짐 회피.
            cardPendings: currentLoaded?.cardPendings,
            cardSettlementSummary: currentLoaded?.cardSettlementSummary,
          ));
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
    final currentOrder = currentMethods.map((m) => m.id).toList();
    final desiredOrder = reordered.map((m) => m.id).toList();
    if (listEquals(currentOrder, desiredOrder)) {
      return;
    }

    // 즉시 백그라운드 PUT.
    // - UI 즉시 반영은 _PaymentMethodTab 의 로컬 _localMethods 가 담당
    //   (BlocConsumer rebuild 우회로 ReorderableListView native animation 보존).
    // - 성공: reordered state 로 emit. listener 가 _localMethods 와 동기화 (변경 없음).
    // - 실패: currentMethods + operationError emit. UI 가 원위치로 sync.
    try {
      final result =
          await paymentMethodRepository.reorderPaymentMethods(event.orderedIds);
      result.fold(
        (failure) {
          emit(PaymentMethodLoaded(
            currentMethods,
            cardPendings: currentPendings,
            cardSettlementSummary: currentSummary,
            operationError: failure.message,
          ));
        },
        (_) {
          emit(PaymentMethodLoaded(
            reordered,
            cardPendings: currentPendings,
            cardSettlementSummary: currentSummary,
          ));
        },
      );
    } catch (_) {
      emit(PaymentMethodLoaded(
        currentMethods,
        cardPendings: currentPendings,
        cardSettlementSummary: currentSummary,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }
}
