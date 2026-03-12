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
  }

  Future<void> _onLoadPockets(
    LoadPockets event,
    Emitter<PocketState> emit,
  ) async {
    emit(const PocketLoading());
    final result = await pocketRepository.getPockets();
    result.fold(
      (failure) => emit(PocketError(failure.message)),
      (pockets) => emit(PocketLoaded(pockets)),
    );
  }

  Future<void> _onCreatePocket(
    CreatePocket event,
    Emitter<PocketState> emit,
  ) async {
    final currentPockets = state is PocketLoaded
        ? (state as PocketLoaded).pockets
        : <MoneyPocket>[];

    final result = await pocketRepository.createPocket(
      name: event.name,
      type: event.type,
      allocatedAmount: event.allocatedAmount,
      icon: event.icon,
      color: event.color,
    );
    result.fold(
      (failure) => emit(PocketLoaded(
        currentPockets,
        operationError: failure.message,
      )),
      (pocket) => emit(PocketLoaded([...currentPockets, pocket])),
    );
  }

  Future<void> _onUpdatePocket(
    UpdatePocket event,
    Emitter<PocketState> emit,
  ) async {
    final currentPockets = state is PocketLoaded
        ? (state as PocketLoaded).pockets
        : <MoneyPocket>[];

    final result = await pocketRepository.updatePocket(
      id: event.id,
      name: event.name,
      type: event.type,
      allocatedAmount: event.allocatedAmount,
      icon: event.icon,
      color: event.color,
      displayOrder: event.displayOrder,
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
  }

  Future<void> _onDeletePocket(
    DeletePocket event,
    Emitter<PocketState> emit,
  ) async {
    final currentPockets = state is PocketLoaded
        ? (state as PocketLoaded).pockets
        : <MoneyPocket>[];

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
  }

  Future<void> _onDistributeIncome(
    DistributeIncome event,
    Emitter<PocketState> emit,
  ) async {
    final currentPockets = state is PocketLoaded
        ? (state as PocketLoaded).pockets
        : <MoneyPocket>[];

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
  }
}
