import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/domain/repositories/pocket_repository.dart';
import 'pocket_event.dart';
import 'pocket_state.dart';

class PocketBloc extends Bloc<PocketEvent, PocketState> {
  final PocketRepository pocketRepository;

  PocketBloc({required this.pocketRepository})
      : super(const PocketInitial()) {
    on<LoadPockets>(_onLoadPockets);
    on<CreatePocket>(_onCreatePocket);
    on<UpdatePocket>(_onUpdatePocket);
    on<DeletePocket>(_onDeletePocket);
    on<DistributeIncome>(_onDistributeIncome);
    on<LoadDistributionRatios>(_onLoadDistributionRatios);
    on<SaveDistributionRatios>(_onSaveDistributionRatios);
  }

  Future<void> _onLoadPockets(
    LoadPockets event,
    Emitter<PocketState> emit,
  ) async {
    try {
      // 회차 12 follow-up — race fix.
      final currentLoaded =
          state is PocketLoaded ? state as PocketLoaded : null;
      if (currentLoaded == null) {
        emit(const PocketLoading());
      }
      final result = await pocketRepository.getPockets();
      result.fold(
        (failure) {
          if (currentLoaded != null) {
            emit(PocketLoaded(currentLoaded.pockets,
                operationError: failure.message));
          } else {
            emit(PocketError(failure.message));
          }
        },
        (pockets) => emit(PocketLoaded(pockets)),
      );
    } catch (e) {
      emit(const PocketError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCreatePocket(
    CreatePocket event,
    Emitter<PocketState> emit,
  ) async {
    final currentPockets = state is PocketLoaded
        ? (state as PocketLoaded).pockets
        : <MoneyPocket>[];

    try {
      final result = await pocketRepository.createPocket(
        name: event.name,
        type: event.type,
        allocatedAmount: event.allocatedAmount,
        icon: event.icon,
        color: event.color,
        goalAmount: event.goalAmount,
        targetDate: event.targetDate,
      );
      result.fold(
        (failure) => emit(PocketLoaded(
          currentPockets,
          operationError: failure.message,
        )),
        (pocket) => emit(PocketLoaded([...currentPockets, pocket])),
      );
    } catch (e) {
      emit(PocketLoaded(
        currentPockets,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  Future<void> _onUpdatePocket(
    UpdatePocket event,
    Emitter<PocketState> emit,
  ) async {
    final currentPockets = state is PocketLoaded
        ? (state as PocketLoaded).pockets
        : <MoneyPocket>[];

    try {
      final result = await pocketRepository.updatePocket(
        id: event.id,
        name: event.name,
        type: event.type,
        allocatedAmount: event.allocatedAmount,
        icon: event.icon,
        color: event.color,
        displayOrder: event.displayOrder,
        goalAmount: event.goalAmount,
        targetDate: event.targetDate,
      );
      result.fold(
        (failure) => emit(PocketLoaded(
          currentPockets,
          operationError: failure.message,
        )),
        (updated) {
          final updatedList = currentPockets
              .map((p) => p.id == updated.id ? updated : p)
              .toList();
          emit(PocketLoaded(updatedList));
        },
      );
    } catch (e) {
      emit(PocketLoaded(
        currentPockets,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  Future<void> _onDeletePocket(
    DeletePocket event,
    Emitter<PocketState> emit,
  ) async {
    final currentPockets = state is PocketLoaded
        ? (state as PocketLoaded).pockets
        : <MoneyPocket>[];

    try {
      final result = await pocketRepository.deletePocket(event.id);
      result.fold(
        (failure) => emit(PocketLoaded(
          currentPockets,
          operationError: failure.message,
        )),
        (_) {
          final updatedList =
              currentPockets.where((p) => p.id != event.id).toList();
          emit(PocketLoaded(updatedList));
        },
      );
    } catch (e) {
      emit(PocketLoaded(
        currentPockets,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  Future<void> _onDistributeIncome(
    DistributeIncome event,
    Emitter<PocketState> emit,
  ) async {
    final currentPockets = state is PocketLoaded
        ? (state as PocketLoaded).pockets
        : <MoneyPocket>[];

    try {
      final result = await pocketRepository.distributeIncome(
        totalAmount: event.totalAmount,
        distributions: event.distributions,
      );
      result.fold(
        (failure) => emit(PocketLoaded(
          currentPockets,
          operationError: failure.message,
        )),
        (_) {
          // Reload pockets after distribution to get fresh balances
          add(const LoadPockets());
        },
      );
    } catch (e) {
      emit(PocketLoaded(
        currentPockets,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  Future<void> _onLoadDistributionRatios(
    LoadDistributionRatios event,
    Emitter<PocketState> emit,
  ) async {
    final currentPockets = state is PocketLoaded
        ? (state as PocketLoaded).pockets
        : <MoneyPocket>[];

    try {
      final result = await pocketRepository.getDistributionRatios();
      result.fold(
        (failure) => emit(PocketLoaded(
          currentPockets,
          operationError: failure.message,
        )),
        (ratios) => emit(PocketLoaded(
          currentPockets,
          distributionRatios: ratios,
        )),
      );
    } catch (e) {
      emit(PocketLoaded(
        currentPockets,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }

  Future<void> _onSaveDistributionRatios(
    SaveDistributionRatios event,
    Emitter<PocketState> emit,
  ) async {
    final currentPockets = state is PocketLoaded
        ? (state as PocketLoaded).pockets
        : <MoneyPocket>[];

    try {
      final result =
          await pocketRepository.saveDistributionRatios(event.ratios);
      result.fold(
        (failure) => emit(PocketLoaded(
          currentPockets,
          operationError: failure.message,
        )),
        (_) => emit(PocketLoaded(
          currentPockets,
          ratiosSaved: true,
        )),
      );
    } catch (e) {
      emit(PocketLoaded(
        currentPockets,
        operationError: '예기치 않은 오류가 발생했습니다',
      ));
    }
  }
}
