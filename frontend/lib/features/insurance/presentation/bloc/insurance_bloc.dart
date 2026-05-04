import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/insurance/domain/repositories/insurance_repository.dart';
import 'insurance_event.dart';
import 'insurance_state.dart';

class InsuranceBloc extends Bloc<InsuranceEvent, InsuranceState> {
  final InsuranceRepository insuranceRepository;

  bool? _lastActiveFilter;

  InsuranceBloc({required this.insuranceRepository})
      : super(const InsuranceInitial()) {
    on<LoadInsurances>(_onLoadInsurances);
    on<LoadInsuranceSummary>(_onLoadInsuranceSummary);
    on<CreateInsurance>(_onCreateInsurance);
    on<UpdateInsurance>(_onUpdateInsurance);
    on<DeleteInsurance>(_onDeleteInsurance);
  }

  Future<void> _onLoadInsurances(
    LoadInsurances event,
    Emitter<InsuranceState> emit,
  ) async {
    try {
      _lastActiveFilter = event.activeOnly;
      // 회차 12 follow-up — race fix.
      final currentLoaded =
          state is InsuranceLoaded ? state as InsuranceLoaded : null;
      if (currentLoaded == null) {
        emit(const InsuranceLoading());
      }

      final result =
          await insuranceRepository.getInsurances(active: event.activeOnly);
      result.fold(
        (failure) {
          if (currentLoaded != null) {
            // 기존 data 유지
          } else {
            emit(InsuranceError(failure.message));
          }
        },
        (insurances) {
          emit(InsuranceLoaded(
            insurances: insurances,
            summary: currentLoaded?.summary,
          ));
        },
      );
    } catch (e) {
      if (state is! InsuranceLoaded) {
        emit(const InsuranceError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }

  Future<void> _onLoadInsuranceSummary(
    LoadInsuranceSummary event,
    Emitter<InsuranceState> emit,
  ) async {
    try {
      final result = await insuranceRepository.getInsuranceSummary(
        year: event.year,
        month: event.month,
      );
      result.fold(
        (failure) {
          // Don't overwrite insurance list on summary failure
          final currentState = state;
          if (currentState is InsuranceLoaded) {
            emit(InsuranceLoaded(
              insurances: currentState.insurances,
              summary: currentState.summary,
              operationError: failure.message,
            ));
          }
        },
        (summary) {
          final currentState = state;
          if (currentState is InsuranceLoaded) {
            emit(InsuranceLoaded(
              insurances: currentState.insurances,
              summary: summary,
            ));
          } else {
            // Summary loaded before list — store it, list will merge later
            emit(InsuranceLoaded(
              insurances: const [],
              summary: summary,
            ));
          }
        },
      );
    } catch (e) {
      // Silent fail for summary
    }
  }

  Future<void> _onCreateInsurance(
    CreateInsurance event,
    Emitter<InsuranceState> emit,
  ) async {
    try {
      final result = await insuranceRepository.createInsurance(
        name: event.name,
        insurer: event.insurer,
        insuranceType: event.insuranceType,
        premiumAmount: event.premiumAmount,
        paymentDay: event.paymentDay,
        paymentCycle: event.paymentCycle,
        paymentMethodId: event.paymentMethodId,
        categoryId: event.categoryId,
        startDate: event.startDate,
        endDate: event.endDate,
        memo: event.memo,
        visibility: event.visibility,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is InsuranceLoaded) {
            emit(InsuranceLoaded(
              insurances: currentState.insurances,
              summary: currentState.summary,
              operationError: failure.message,
            ));
          } else {
            emit(InsuranceError(failure.message));
          }
        },
        (_) => add(LoadInsurances(activeOnly: _lastActiveFilter)),
      );
    } catch (e) {
      emit(const InsuranceError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onUpdateInsurance(
    UpdateInsurance event,
    Emitter<InsuranceState> emit,
  ) async {
    try {
      final result = await insuranceRepository.updateInsurance(
        id: event.id,
        name: event.name,
        insurer: event.insurer,
        clearInsurer: event.clearInsurer,
        insuranceType: event.insuranceType,
        premiumAmount: event.premiumAmount,
        paymentDay: event.paymentDay,
        clearPaymentDay: event.clearPaymentDay,
        paymentCycle: event.paymentCycle,
        paymentMethodId: event.paymentMethodId,
        clearPaymentMethodId: event.clearPaymentMethodId,
        categoryId: event.categoryId,
        clearCategoryId: event.clearCategoryId,
        startDate: event.startDate,
        clearStartDate: event.clearStartDate,
        endDate: event.endDate,
        clearEndDate: event.clearEndDate,
        memo: event.memo,
        clearMemo: event.clearMemo,
        isActive: event.isActive,
        visibility: event.visibility,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is InsuranceLoaded) {
            emit(InsuranceLoaded(
              insurances: currentState.insurances,
              summary: currentState.summary,
              operationError: failure.message,
            ));
          } else {
            emit(InsuranceError(failure.message));
          }
        },
        (_) => add(LoadInsurances(activeOnly: _lastActiveFilter)),
      );
    } catch (e) {
      emit(const InsuranceError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onDeleteInsurance(
    DeleteInsurance event,
    Emitter<InsuranceState> emit,
  ) async {
    try {
      final currentState = state;
      final result = await insuranceRepository.deleteInsurance(event.id);
      result.fold(
        (failure) {
          if (currentState is InsuranceLoaded) {
            emit(InsuranceLoaded(
              insurances: currentState.insurances,
              summary: currentState.summary,
              operationError: failure.message,
            ));
          } else {
            emit(InsuranceError(failure.message));
          }
        },
        (_) {
          if (currentState is InsuranceLoaded) {
            final updatedList = currentState.insurances
                .where((i) => i.id != event.id)
                .toList();
            emit(InsuranceLoaded(
              insurances: updatedList,
              summary: currentState.summary,
              operationSuccess: '보험이 삭제되었습니다',
            ));
          }
        },
      );
    } catch (e) {
      final currentState = state;
      if (currentState is InsuranceLoaded) {
        emit(InsuranceLoaded(
          insurances: currentState.insurances,
          summary: currentState.summary,
          operationError: '예기치 않은 오류가 발생했습니다',
        ));
      } else {
        emit(const InsuranceError('예기치 않은 오류가 발생했습니다'));
      }
    }
  }
}
