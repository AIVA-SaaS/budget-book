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
        (methods) => emit(PaymentMethodLoaded(methods)),
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
          await paymentMethodRepository.getCardSettlementSummary();
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
}
