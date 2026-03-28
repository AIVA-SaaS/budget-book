import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/spending_plan/domain/repositories/spending_plan_repository.dart';
import 'spending_plan_event.dart';
import 'spending_plan_state.dart';

class SpendingPlanBloc extends Bloc<SpendingPlanEvent, SpendingPlanState> {
  final SpendingPlanRepository spendingPlanRepository;

  String? _lastStartDate;
  String? _lastEndDate;
  String? _lastStatus;

  SpendingPlanBloc({required this.spendingPlanRepository})
      : super(const SpendingPlanInitial()) {
    on<LoadSpendingPlans>(_onLoadSpendingPlans);
    on<CreateSpendingPlan>(_onCreateSpendingPlan);
    on<UpdateSpendingPlan>(_onUpdateSpendingPlan);
    on<DeleteSpendingPlan>(_onDeleteSpendingPlan);
    on<CompletePlan>(_onCompletePlan);
    on<SkipPlan>(_onSkipPlan);
  }

  Future<void> _onLoadSpendingPlans(
    LoadSpendingPlans event,
    Emitter<SpendingPlanState> emit,
  ) async {
    try {
      _lastStartDate = event.startDate;
      _lastEndDate = event.endDate;
      _lastStatus = event.status;
      emit(const SpendingPlanLoading());

      final result = await spendingPlanRepository.getSpendingPlans(
        startDate: event.startDate,
        endDate: event.endDate,
        status: event.status,
      );
      result.fold(
        (failure) => emit(SpendingPlanError(failure.message)),
        (response) => emit(SpendingPlanLoaded(
          plans: response.plans,
          summary: response.summary,
        )),
      );
    } catch (e) {
      emit(const SpendingPlanError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCreateSpendingPlan(
    CreateSpendingPlan event,
    Emitter<SpendingPlanState> emit,
  ) async {
    try {
      final result = await spendingPlanRepository.createSpendingPlan(
        name: event.name,
        amount: event.amount,
        targetDate: event.targetDate,
        memo: event.memo,
        categoryId: event.categoryId,
        paymentMethodId: event.paymentMethodId,
        budgetId: event.budgetId,
        isRecurring: event.isRecurring,
        frequency: event.frequency,
        visibility: event.visibility,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is SpendingPlanLoaded) {
            emit(SpendingPlanLoaded(
              plans: currentState.plans,
              summary: currentState.summary,
              operationError: failure.message,
            ));
          } else {
            emit(SpendingPlanError(failure.message));
          }
        },
        (_) => add(LoadSpendingPlans(
          startDate: _lastStartDate,
          endDate: _lastEndDate,
          status: _lastStatus,
        )),
      );
    } catch (e) {
      emit(const SpendingPlanError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onUpdateSpendingPlan(
    UpdateSpendingPlan event,
    Emitter<SpendingPlanState> emit,
  ) async {
    try {
      final result = await spendingPlanRepository.updateSpendingPlan(
        id: event.id,
        name: event.name,
        amount: event.amount,
        targetDate: event.targetDate,
        memo: event.memo,
        clearMemo: event.clearMemo,
        categoryId: event.categoryId,
        clearCategoryId: event.clearCategoryId,
        paymentMethodId: event.paymentMethodId,
        clearPaymentMethodId: event.clearPaymentMethodId,
        budgetId: event.budgetId,
        clearBudgetId: event.clearBudgetId,
        isRecurring: event.isRecurring,
        frequency: event.frequency,
        clearFrequency: event.clearFrequency,
        visibility: event.visibility,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is SpendingPlanLoaded) {
            emit(SpendingPlanLoaded(
              plans: currentState.plans,
              summary: currentState.summary,
              operationError: failure.message,
            ));
          } else {
            emit(SpendingPlanError(failure.message));
          }
        },
        (_) => add(LoadSpendingPlans(
          startDate: _lastStartDate,
          endDate: _lastEndDate,
          status: _lastStatus,
        )),
      );
    } catch (e) {
      emit(const SpendingPlanError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onDeleteSpendingPlan(
    DeleteSpendingPlan event,
    Emitter<SpendingPlanState> emit,
  ) async {
    try {
      final currentState = state;
      final result = await spendingPlanRepository.deleteSpendingPlan(event.id);
      result.fold(
        (failure) {
          if (currentState is SpendingPlanLoaded) {
            emit(SpendingPlanLoaded(
              plans: currentState.plans,
              summary: currentState.summary,
              operationError: failure.message,
            ));
          } else {
            emit(SpendingPlanError(failure.message));
          }
        },
        (_) {
          if (currentState is SpendingPlanLoaded) {
            final updatedList =
                currentState.plans.where((p) => p.id != event.id).toList();
            emit(SpendingPlanLoaded(
              plans: updatedList,
              summary: currentState.summary,
              operationSuccess: '지출 계획이 삭제되었습니다',
            ));
          }
        },
      );
    } catch (e) {
      final currentState = state;
      if (currentState is SpendingPlanLoaded) {
        emit(SpendingPlanLoaded(
          plans: currentState.plans,
          summary: currentState.summary,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const SpendingPlanError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onCompletePlan(
    CompletePlan event,
    Emitter<SpendingPlanState> emit,
  ) async {
    try {
      final result = await spendingPlanRepository.completePlan(
        id: event.id,
        transactionId: event.transactionId,
        actualAmount: event.actualAmount,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is SpendingPlanLoaded) {
            emit(SpendingPlanLoaded(
              plans: currentState.plans,
              summary: currentState.summary,
              operationError: failure.message,
            ));
          } else {
            emit(SpendingPlanError(failure.message));
          }
        },
        (_) => add(LoadSpendingPlans(
          startDate: _lastStartDate,
          endDate: _lastEndDate,
          status: _lastStatus,
        )),
      );
    } catch (e) {
      emit(const SpendingPlanError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onSkipPlan(
    SkipPlan event,
    Emitter<SpendingPlanState> emit,
  ) async {
    try {
      final result = await spendingPlanRepository.skipPlan(event.id);
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is SpendingPlanLoaded) {
            emit(SpendingPlanLoaded(
              plans: currentState.plans,
              summary: currentState.summary,
              operationError: failure.message,
            ));
          } else {
            emit(SpendingPlanError(failure.message));
          }
        },
        (_) => add(LoadSpendingPlans(
          startDate: _lastStartDate,
          endDate: _lastEndDate,
          status: _lastStatus,
        )),
      );
    } catch (e) {
      emit(const SpendingPlanError('예기치 않은 오류가 발생했습니다'));
    }
  }
}
