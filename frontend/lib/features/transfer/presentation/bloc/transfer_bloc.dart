import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/transfer/domain/repositories/transfer_repository.dart';
import 'transfer_event.dart';
import 'transfer_state.dart';

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  final TransferRepository transferRepository;

  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;

  TransferBloc({required this.transferRepository})
      : super(const TransferInitial()) {
    on<LoadTransfers>(_onLoadTransfers);
    on<CreateTransfer>(_onCreateTransfer);
    on<UpdateTransfer>(_onUpdateTransfer);
    on<DeleteTransfer>(_onDeleteTransfer);
  }

  Future<void> _onLoadTransfers(
    LoadTransfers event,
    Emitter<TransferState> emit,
  ) async {
    try {
      _currentYear = event.year;
      _currentMonth = event.month;
      emit(const TransferLoading());

      final result = await transferRepository.getTransfers(
        year: event.year,
        month: event.month,
      );
      result.fold(
        (failure) => emit(TransferError(failure.message)),
        (transfers) => emit(TransferLoaded(
          transfers: transfers,
          year: event.year,
          month: event.month,
        )),
      );
    } catch (e) {
      emit(const TransferError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCreateTransfer(
    CreateTransfer event,
    Emitter<TransferState> emit,
  ) async {
    try {
      final result = await transferRepository.createTransfer(
        sourcePaymentMethodId: event.sourcePaymentMethodId,
        destinationPaymentMethodId: event.destinationPaymentMethodId,
        amount: event.amount,
        description: event.description,
        transferDate: event.transferDate,
        memo: event.memo,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is TransferLoaded) {
            emit(TransferLoaded(
              transfers: currentState.transfers,
              year: currentState.year,
              month: currentState.month,
              operationError: failure.message,
            ));
          } else {
            emit(TransferError(failure.message));
          }
        },
        (_) => add(LoadTransfers(year: _currentYear, month: _currentMonth)),
      );
    } catch (e) {
      emit(const TransferError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onUpdateTransfer(
    UpdateTransfer event,
    Emitter<TransferState> emit,
  ) async {
    try {
      final result = await transferRepository.updateTransfer(
        id: event.id,
        sourcePaymentMethodId: event.sourcePaymentMethodId,
        destinationPaymentMethodId: event.destinationPaymentMethodId,
        amount: event.amount,
        description: event.description,
        clearDescription: event.clearDescription,
        transferDate: event.transferDate,
        memo: event.memo,
        clearMemo: event.clearMemo,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is TransferLoaded) {
            emit(TransferLoaded(
              transfers: currentState.transfers,
              year: currentState.year,
              month: currentState.month,
              operationError: failure.message,
            ));
          } else {
            emit(TransferError(failure.message));
          }
        },
        (_) => add(LoadTransfers(year: _currentYear, month: _currentMonth)),
      );
    } catch (e) {
      emit(const TransferError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onDeleteTransfer(
    DeleteTransfer event,
    Emitter<TransferState> emit,
  ) async {
    try {
      final currentState = state;
      final result = await transferRepository.deleteTransfer(event.id);
      result.fold(
        (failure) {
          if (currentState is TransferLoaded) {
            emit(TransferLoaded(
              transfers: currentState.transfers,
              year: currentState.year,
              month: currentState.month,
              operationError: failure.message,
            ));
          } else {
            emit(TransferError(failure.message));
          }
        },
        (_) {
          if (currentState is TransferLoaded) {
            final updatedList = currentState.transfers
                .where((t) => t.id != event.id)
                .toList();
            emit(TransferLoaded(
              transfers: updatedList,
              year: currentState.year,
              month: currentState.month,
              operationSuccess: '이체가 삭제되었습니다',
            ));
          }
        },
      );
    } catch (e) {
      final currentState = state;
      if (currentState is TransferLoaded) {
        emit(TransferLoaded(
          transfers: currentState.transfers,
          year: currentState.year,
          month: currentState.month,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const TransferError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }
}
