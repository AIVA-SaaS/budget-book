import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/recurring/domain/entities/recurring_transaction.dart';
import 'package:budget_book/features/recurring/domain/repositories/recurring_repository.dart';
import 'recurring_event.dart';
import 'recurring_state.dart';

class RecurringBloc extends Bloc<RecurringEvent, RecurringState> {
  final RecurringRepository recurringRepository;

  RecurringBloc({required this.recurringRepository})
      : super(const RecurringInitial()) {
    on<LoadRecurringTransactions>(_onLoadRecurringTransactions);
    on<CreateRecurringTransaction>(_onCreateRecurringTransaction);
    on<UpdateRecurringTransaction>(_onUpdateRecurringTransaction);
    on<DeleteRecurringTransaction>(_onDeleteRecurringTransaction);
  }

  Future<void> _onLoadRecurringTransactions(
    LoadRecurringTransactions event,
    Emitter<RecurringState> emit,
  ) async {
    try {
      emit(const RecurringLoading());
      final result = await recurringRepository.getRecurringTransactions();
      result.fold(
        (failure) => emit(RecurringError(failure.message)),
        (transactions) => emit(RecurringLoaded(transactions)),
      );
    } catch (e) {
      emit(const RecurringError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCreateRecurringTransaction(
    CreateRecurringTransaction event,
    Emitter<RecurringState> emit,
  ) async {
    final currentTransactions = state is RecurringLoaded
        ? (state as RecurringLoaded).transactions
        : <RecurringTransaction>[];

    try {
      final result = await recurringRepository.createRecurringTransaction(
        type: event.type,
        amount: event.amount,
        description: event.description,
        memo: event.memo,
        frequency: event.frequency,
        dayOfMonth: event.dayOfMonth,
        dayOfWeek: event.dayOfWeek,
        categoryId: event.categoryId,
        paymentMethodId: event.paymentMethodId,
      );
      result.fold(
        (failure) => emit(RecurringLoaded(
          currentTransactions,
          operationError: failure.message,
        )),
        (transaction) => emit(RecurringLoaded(
          [...currentTransactions, transaction],
        )),
      );
    } catch (e) {
      emit(RecurringLoaded(
        currentTransactions,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  Future<void> _onUpdateRecurringTransaction(
    UpdateRecurringTransaction event,
    Emitter<RecurringState> emit,
  ) async {
    final currentTransactions = state is RecurringLoaded
        ? (state as RecurringLoaded).transactions
        : <RecurringTransaction>[];

    try {
      final result = await recurringRepository.updateRecurringTransaction(
        id: event.id,
        amount: event.amount,
        description: event.description,
        memo: event.memo,
        categoryId: event.categoryId,
        paymentMethodId: event.paymentMethodId,
        dayOfMonth: event.dayOfMonth,
        dayOfWeek: event.dayOfWeek,
        isActive: event.isActive,
      );
      result.fold(
        (failure) => emit(RecurringLoaded(
          currentTransactions,
          operationError: failure.message,
        )),
        (updated) {
          final updatedList = currentTransactions
              .map((t) => t.id == updated.id ? updated : t)
              .toList();
          emit(RecurringLoaded(updatedList));
        },
      );
    } catch (e) {
      emit(RecurringLoaded(
        currentTransactions,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  Future<void> _onDeleteRecurringTransaction(
    DeleteRecurringTransaction event,
    Emitter<RecurringState> emit,
  ) async {
    final currentTransactions = state is RecurringLoaded
        ? (state as RecurringLoaded).transactions
        : <RecurringTransaction>[];

    try {
      final result =
          await recurringRepository.deleteRecurringTransaction(event.id);
      result.fold(
        (failure) => emit(RecurringLoaded(
          currentTransactions,
          operationError: failure.message,
        )),
        (_) {
          final updatedList =
              currentTransactions.where((t) => t.id != event.id).toList();
          emit(RecurringLoaded(updatedList));
        },
      );
    } catch (e) {
      emit(RecurringLoaded(
        currentTransactions,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }
}
