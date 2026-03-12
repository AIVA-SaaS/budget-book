import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/pocket/domain/entities/pocket_transfer.dart';
import 'package:budget_book/features/pocket/domain/repositories/pocket_transfer_repository.dart';
import 'pocket_transfer_event.dart';
import 'pocket_transfer_state.dart';

class PocketTransferBloc
    extends Bloc<PocketTransferEvent, PocketTransferState> {
  final PocketTransferRepository pocketTransferRepository;

  PocketTransferBloc({required this.pocketTransferRepository})
      : super(const PocketTransferInitial()) {
    on<LoadPocketTransfers>(_onLoadPocketTransfers);
    on<CreatePocketTransfer>(_onCreatePocketTransfer);
  }

  Future<void> _onLoadPocketTransfers(
    LoadPocketTransfers event,
    Emitter<PocketTransferState> emit,
  ) async {
    emit(const PocketTransferLoading());
    final result = await pocketTransferRepository.getPocketTransfers(
      fromPocketId: event.fromPocketId,
      toPocketId: event.toPocketId,
      startDate: event.startDate,
      endDate: event.endDate,
    );
    result.fold(
      (failure) => emit(PocketTransferError(failure.message)),
      (transfers) => emit(PocketTransferLoaded(transfers)),
    );
  }

  Future<void> _onCreatePocketTransfer(
    CreatePocketTransfer event,
    Emitter<PocketTransferState> emit,
  ) async {
    final currentTransfers = state is PocketTransferLoaded
        ? (state as PocketTransferLoaded).transfers
        : <PocketTransfer>[];

    final result = await pocketTransferRepository.createPocketTransfer(
      fromPocketId: event.fromPocketId,
      toPocketId: event.toPocketId,
      amount: event.amount,
      description: event.description,
      transferDate: event.transferDate,
    );
    result.fold(
      (failure) => emit(PocketTransferLoaded(
        currentTransfers,
        operationError: failure.message,
      )),
      (transfer) => emit(PocketTransferLoaded(
        [transfer, ...currentTransfers],
      )),
    );
  }
}
