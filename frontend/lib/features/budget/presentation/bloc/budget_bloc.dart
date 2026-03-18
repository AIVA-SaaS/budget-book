import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/budget/domain/repositories/budget_repository.dart';
import 'budget_event.dart';
import 'budget_state.dart';

class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  final BudgetRepository budgetRepository;

  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;

  BudgetBloc({required this.budgetRepository}) : super(const BudgetInitial()) {
    on<LoadBudgets>(_onLoadBudgets);
    on<LoadBudgetSummary>(_onLoadBudgetSummary);
    on<CreateBudget>(_onCreateBudget);
    on<UpdateBudget>(_onUpdateBudget);
    on<DeleteBudget>(_onDeleteBudget);
    on<CopyPreviousMonthBudgets>(_onCopyPreviousMonthBudgets);
  }

  Future<void> _onLoadBudgets(
    LoadBudgets event,
    Emitter<BudgetState> emit,
  ) async {
    try {
      _currentYear = event.year;
      _currentMonth = event.month;
      emit(const BudgetLoading());

      final budgetsResult = await budgetRepository.getBudgets(
        year: event.year,
        month: event.month,
      );
      final summaryResult = await budgetRepository.getBudgetSummary(
        year: event.year,
        month: event.month,
      );

      budgetsResult.fold(
        (failure) => emit(BudgetError(failure.message)),
        (budgets) {
          summaryResult.fold(
            (failure) => emit(BudgetLoaded(
              budgets: budgets,
              year: event.year,
              month: event.month,
            )),
            (summary) => emit(BudgetLoaded(
              budgets: budgets,
              summary: summary,
              year: event.year,
              month: event.month,
            )),
          );
        },
      );
    } catch (e) {
      emit(const BudgetError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onLoadBudgetSummary(
    LoadBudgetSummary event,
    Emitter<BudgetState> emit,
  ) async {
    try {
      final currentState = state;
      final result = await budgetRepository.getBudgetSummary(
        year: event.year,
        month: event.month,
      );
      result.fold(
        (failure) {
          if (currentState is BudgetLoaded) {
            emit(BudgetLoaded(
              budgets: currentState.budgets,
              summary: currentState.summary,
              year: currentState.year,
              month: currentState.month,
              operationError: failure.message,
            ));
          }
        },
        (summary) {
          if (currentState is BudgetLoaded) {
            emit(BudgetLoaded(
              budgets: currentState.budgets,
              summary: summary,
              year: currentState.year,
              month: currentState.month,
            ));
          }
        },
      );
    } catch (e) {
      final currentState = state;
      if (currentState is BudgetLoaded) {
        emit(BudgetLoaded(
          budgets: currentState.budgets,
          summary: currentState.summary,
          year: currentState.year,
          month: currentState.month,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const BudgetError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onCreateBudget(
    CreateBudget event,
    Emitter<BudgetState> emit,
  ) async {
    try {
      final result = await budgetRepository.createBudget(
        categoryId: event.categoryId,
        yearMonth: event.yearMonth,
        amount: event.amount,
        budgetPeriod: event.budgetPeriod,
        weeklyAmount: event.weeklyAmount,
        pocketId: event.pocketId,
        periodType: event.periodType,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is BudgetLoaded) {
            emit(BudgetLoaded(
              budgets: currentState.budgets,
              summary: currentState.summary,
              year: currentState.year,
              month: currentState.month,
              operationError: failure.message,
            ));
          } else {
            emit(BudgetError(failure.message));
          }
        },
        (_) => add(LoadBudgets(year: _currentYear, month: _currentMonth)),
      );
    } catch (e) {
      final currentState = state;
      if (currentState is BudgetLoaded) {
        emit(BudgetLoaded(
          budgets: currentState.budgets,
          summary: currentState.summary,
          year: currentState.year,
          month: currentState.month,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const BudgetError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onUpdateBudget(
    UpdateBudget event,
    Emitter<BudgetState> emit,
  ) async {
    try {
      final result = await budgetRepository.updateBudget(
        id: event.id,
        amount: event.amount,
        budgetPeriod: event.budgetPeriod,
        weeklyAmount: event.weeklyAmount,
        pocketId: event.pocketId,
        periodType: event.periodType,
        startDate: event.startDate,
        endDate: event.endDate,
        categoryId: event.categoryId,
        yearMonth: event.yearMonth,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is BudgetLoaded) {
            emit(BudgetLoaded(
              budgets: currentState.budgets,
              summary: currentState.summary,
              year: currentState.year,
              month: currentState.month,
              operationError: failure.message,
            ));
          } else {
            emit(BudgetError(failure.message));
          }
        },
        (_) => add(LoadBudgets(year: _currentYear, month: _currentMonth)),
      );
    } catch (e) {
      final currentState = state;
      if (currentState is BudgetLoaded) {
        emit(BudgetLoaded(
          budgets: currentState.budgets,
          summary: currentState.summary,
          year: currentState.year,
          month: currentState.month,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const BudgetError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onDeleteBudget(
    DeleteBudget event,
    Emitter<BudgetState> emit,
  ) async {
    try {
      final currentState = state;
      final result = await budgetRepository.deleteBudget(event.id);
      result.fold(
        (failure) {
          if (currentState is BudgetLoaded) {
            emit(BudgetLoaded(
              budgets: currentState.budgets,
              summary: currentState.summary,
              year: currentState.year,
              month: currentState.month,
              operationError: failure.message,
            ));
          } else {
            emit(BudgetError(failure.message));
          }
        },
        (_) {
          if (currentState is BudgetLoaded) {
            final updatedList = currentState.budgets
                .where((b) => b.id != event.id)
                .toList();
            emit(BudgetLoaded(
              budgets: updatedList,
              summary: currentState.summary,
              year: currentState.year,
              month: currentState.month,
            ));
            // Reload to get updated summary
            add(LoadBudgets(year: _currentYear, month: _currentMonth));
          }
        },
      );
    } catch (e) {
      final currentState = state;
      if (currentState is BudgetLoaded) {
        emit(BudgetLoaded(
          budgets: currentState.budgets,
          summary: currentState.summary,
          year: currentState.year,
          month: currentState.month,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const BudgetError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onCopyPreviousMonthBudgets(
    CopyPreviousMonthBudgets event,
    Emitter<BudgetState> emit,
  ) async {
    try {
      final currentState = state;
      final result = await budgetRepository.copyPreviousMonthBudgets(
        year: event.year,
        month: event.month,
      );
      result.fold(
        (failure) {
          if (currentState is BudgetLoaded) {
            emit(BudgetLoaded(
              budgets: currentState.budgets,
              summary: currentState.summary,
              year: currentState.year,
              month: currentState.month,
              operationError: failure.message,
            ));
          } else {
            emit(BudgetError(failure.message));
          }
        },
        (copiedBudgets) {
          if (currentState is BudgetLoaded) {
            emit(BudgetLoaded(
              budgets: currentState.budgets,
              summary: currentState.summary,
              year: currentState.year,
              month: currentState.month,
              operationSuccess: '전월 예산이 복사되었습니다 (${copiedBudgets.length}건)',
            ));
            // Reload to get fresh data
            add(LoadBudgets(year: _currentYear, month: _currentMonth));
          }
        },
      );
    } catch (e) {
      final currentState = state;
      if (currentState is BudgetLoaded) {
        emit(BudgetLoaded(
          budgets: currentState.budgets,
          summary: currentState.summary,
          year: currentState.year,
          month: currentState.month,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const BudgetError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }
}
