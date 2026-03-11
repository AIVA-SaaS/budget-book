import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/weekly_budget/domain/repositories/weekly_budget_repository.dart';
import 'weekly_budget_event.dart';
import 'weekly_budget_state.dart';

class WeeklyBudgetBloc extends Bloc<WeeklyBudgetEvent, WeeklyBudgetState> {
  final WeeklyBudgetRepository weeklyBudgetRepository;

  WeeklyBudgetBloc({required this.weeklyBudgetRepository})
      : super(const WeeklyBudgetInitial()) {
    on<LoadWeeklyOverview>(_onLoadWeeklyOverview);
    on<LoadCurrentWeek>(_onLoadCurrentWeek);
  }

  Future<void> _onLoadWeeklyOverview(
    LoadWeeklyOverview event,
    Emitter<WeeklyBudgetState> emit,
  ) async {
    final previousCurrentWeek = state is WeeklyBudgetLoaded
        ? (state as WeeklyBudgetLoaded).currentWeek
        : null;
    emit(const WeeklyBudgetLoading());
    final result = await weeklyBudgetRepository.getWeeklyOverview(
      event.year,
      event.month,
    );
    result.fold(
      (failure) => emit(WeeklyBudgetError(failure.message)),
      (overview) {
        emit(WeeklyBudgetLoaded(
            overview: overview, currentWeek: previousCurrentWeek));
      },
    );
  }

  Future<void> _onLoadCurrentWeek(
    LoadCurrentWeek event,
    Emitter<WeeklyBudgetState> emit,
  ) async {
    final currentOverview = state is WeeklyBudgetLoaded
        ? (state as WeeklyBudgetLoaded).overview
        : null;

    if (currentOverview == null) {
      emit(const WeeklyBudgetLoading());
    }

    final result = await weeklyBudgetRepository.getCurrentWeekSummary();
    result.fold(
      (failure) {
        if (currentOverview != null) {
          emit(WeeklyBudgetLoaded(overview: currentOverview));
        } else {
          emit(WeeklyBudgetError(failure.message));
        }
      },
      (currentWeek) => emit(WeeklyBudgetLoaded(
        overview: currentOverview,
        currentWeek: currentWeek,
      )),
    );
  }
}
