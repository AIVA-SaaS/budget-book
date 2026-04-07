import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/weekly_budget/domain/repositories/weekly_settlement_repository.dart';
import 'weekly_settlement_event.dart';
import 'weekly_settlement_state.dart';

class WeeklySettlementBloc
    extends Bloc<WeeklySettlementEvent, WeeklySettlementState> {
  final WeeklySettlementRepository settlementRepository;

  WeeklySettlementBloc({required this.settlementRepository})
      : super(const SettlementInitial()) {
    on<LoadSettlements>(_onLoadSettlements);
    on<SettleItems>(_onSettleItems);
    on<UnsettleItems>(_onUnsettleItems);
  }

  Future<void> _onLoadSettlements(
    LoadSettlements event,
    Emitter<WeeklySettlementState> emit,
  ) async {
    emit(const SettlementLoading());
    final result =
        await settlementRepository.getSettlements(event.year, event.month);
    result.fold(
      (failure) => emit(SettlementError(failure.message)),
      (overview) => emit(SettlementLoaded(overview: overview)),
    );
  }

  Future<void> _onSettleItems(
    SettleItems event,
    Emitter<WeeklySettlementState> emit,
  ) async {
    final result =
        await settlementRepository.settle(event.budgetIds, event.weekNumber);
    await result.fold(
      (failure) async => emit(SettlementError(failure.message)),
      (_) async {
        // Reload settlements after successful settle
        final reloadResult = await settlementRepository.getSettlements(
            event.year, event.month);
        reloadResult.fold(
          (failure) => emit(SettlementError(failure.message)),
          (overview) => emit(SettlementLoaded(overview: overview)),
        );
      },
    );
  }

  Future<void> _onUnsettleItems(
    UnsettleItems event,
    Emitter<WeeklySettlementState> emit,
  ) async {
    final result =
        await settlementRepository.unsettle(event.budgetIds, event.weekNumber);
    await result.fold(
      (failure) async => emit(SettlementError(failure.message)),
      (_) async {
        final reloadResult = await settlementRepository.getSettlements(
            event.year, event.month);
        reloadResult.fold(
          (failure) => emit(SettlementError(failure.message)),
          (overview) => emit(SettlementLoaded(overview: overview)),
        );
      },
    );
  }
}
