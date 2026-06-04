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
    on<CheckInvitationStatus>(_onCheckInvitationStatus);
  }

  Future<void> _onLoadCouple(
    LoadCouple event,
    Emitter<CoupleState> emit,
  ) async {
    try {
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
    } catch (_) {
      emit(const CoupleError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onGenerateInvitation(
    GenerateInvitation event,
    Emitter<CoupleState> emit,
  ) async {
    try {
      emit(const CoupleLoading());
      final result = await coupleRepository.createInvitation();
      result.fold(
        (failure) => emit(CoupleError(
          failure.message,
          errorCode: failure is ServerFailure ? failure.code : null,
        )),
        (invitation) => emit(CoupleInvitationPending(invitation)),
      );
    } catch (_) {
      emit(const CoupleError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onAcceptInvitation(
    AcceptInvitation event,
    Emitter<CoupleState> emit,
  ) async {
    try {
      emit(const CoupleLoading());
      final result = await coupleRepository.acceptInvitation(event.code);
      result.fold(
        (failure) => emit(CoupleError(
          failure.message,
          errorCode: failure is ServerFailure ? failure.code : null,
        )),
        (couple) => emit(CoupleLinked(couple)),
      );
    } catch (_) {
      emit(const CoupleError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCheckInvitationStatus(
    CheckInvitationStatus event,
    Emitter<CoupleState> emit,
  ) async {
    try {
      emit(const CoupleLoading());

      // First try to get couple — if already linked, go directly to CoupleLinked
      final coupleResult = await coupleRepository.getMyCouple();
      final coupleHandled = coupleResult.fold(
        (failure) => false,
        (couple) {
          emit(CoupleLinked(couple));
          return true;
        },
      );
      if (coupleHandled) return;

      // Couple not found — check invitation status
      final invResult = await coupleRepository.getMyInvitation();
      invResult.fold(
        (failure) {
          // No invitation found (404) — user has no pending invitation
          emit(const CoupleNotLinked());
        },
        (invitation) {
          final status = invitation.status;
          if (status == 'ACCEPTED') {
            // Just linked — reload couple
            add(const LoadCouple());
          } else if (status == 'EXPIRED') {
            emit(CoupleInvitationExpired(invitation));
          } else {
            // PENDING or other
            emit(CoupleInvitationPending(invitation));
          }
        },
      );
    } catch (_) {
      emit(const CoupleError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onDissolveCouple(
    DissolveCouple event,
    Emitter<CoupleState> emit,
  ) async {
    try {
      emit(const CoupleLoading());
      final result = await coupleRepository.dissolveCouple();
      result.fold(
        (failure) => emit(CoupleError(
          failure.message,
          errorCode: failure is ServerFailure ? failure.code : null,
        )),
        (_) => emit(const CoupleNotLinked()),
      );
    } catch (_) {
      emit(const CoupleError('예기치 않은 오류가 발생했습니다'));
    }
  }
}
