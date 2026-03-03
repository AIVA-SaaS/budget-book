import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/couple/domain/repositories/couple_repository.dart';
import 'couple_event.dart';
import 'couple_state.dart';

class CoupleBloc extends Bloc<CoupleEvent, CoupleState> {
  final CoupleRepository coupleRepository;

  CoupleBloc({required this.coupleRepository}) : super(const CoupleInitial()) {
    on<LoadCouple>(_onLoadCouple);
    on<GenerateInvitation>(_onGenerateInvitation);
    on<AcceptInvitation>(_onAcceptInvitation);
    on<DissolveCouple>(_onDissolveCouple);
  }

  Future<void> _onLoadCouple(
    LoadCouple event,
    Emitter<CoupleState> emit,
  ) async {
    emit(const CoupleLoading());
    final result = await coupleRepository.getMyCouple();
    result.fold(
      (failure) {
        final isNotInCouple = failure is ServerFailure &&
            (failure.code == 'COUPLE_NOT_FOUND' || failure.statusCode == 404);
        if (isNotInCouple) {
          emit(const CoupleNotLinked());
        } else {
          emit(CoupleError(failure.message));
        }
      },
      (couple) => emit(CoupleLinked(couple)),
    );
  }

  Future<void> _onGenerateInvitation(
    GenerateInvitation event,
    Emitter<CoupleState> emit,
  ) async {
    emit(const CoupleLoading());
    final result = await coupleRepository.createInvitation();
    result.fold(
      (failure) => emit(CoupleError(failure.message)),
      (invitation) => emit(CoupleInvitationPending(invitation)),
    );
  }

  Future<void> _onAcceptInvitation(
    AcceptInvitation event,
    Emitter<CoupleState> emit,
  ) async {
    emit(const CoupleLoading());
    final result = await coupleRepository.acceptInvitation(event.code);
    result.fold(
      (failure) => emit(CoupleError(failure.message)),
      (couple) => emit(CoupleLinked(couple)),
    );
  }

  Future<void> _onDissolveCouple(
    DissolveCouple event,
    Emitter<CoupleState> emit,
  ) async {
    emit(const CoupleLoading());
    final result = await coupleRepository.dissolveCouple();
    result.fold(
      (failure) => emit(CoupleError(failure.message)),
      (_) => emit(const CoupleNotLinked()),
    );
  }
}
