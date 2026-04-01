import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/feedback/domain/repositories/feedback_repository.dart';
import 'release_note_event.dart';
import 'release_note_state.dart';

class ReleaseNoteBloc extends Bloc<ReleaseNoteEvent, ReleaseNoteState> {
  final FeedbackRepository feedbackRepository;

  ReleaseNoteBloc({required this.feedbackRepository})
      : super(const ReleaseNoteInitial()) {
    on<LoadReleaseNotes>(_onLoadReleaseNotes);
    on<LoadReleaseNoteDetail>(_onLoadReleaseNoteDetail);
    on<CreateReleaseNote>(_onCreateReleaseNote);
    on<UpdateReleaseNote>(_onUpdateReleaseNote);
    on<DeleteReleaseNote>(_onDeleteReleaseNote);
    on<PublishReleaseNote>(_onPublishReleaseNote);
    on<LinkFeedbackToRelease>(_onLinkFeedbackToRelease);
  }

  Future<void> _onLoadReleaseNotes(
    LoadReleaseNotes event,
    Emitter<ReleaseNoteState> emit,
  ) async {
    try {
      emit(const ReleaseNoteLoading());
      final result = await feedbackRepository.getReleaseNotes();
      result.fold(
        (failure) => emit(ReleaseNoteError(failure.message)),
        (notes) => emit(ReleaseNoteLoaded(releaseNotes: notes)),
      );
    } catch (e) {
      emit(const ReleaseNoteError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onLoadReleaseNoteDetail(
    LoadReleaseNoteDetail event,
    Emitter<ReleaseNoteState> emit,
  ) async {
    try {
      final result = await feedbackRepository.getReleaseNoteDetail(event.id);
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is ReleaseNoteLoaded) {
            emit(ReleaseNoteLoaded(
              releaseNotes: currentState.releaseNotes,
              operationError: failure.message,
            ));
          } else {
            emit(ReleaseNoteError(failure.message));
          }
        },
        (detail) {
          final currentState = state;
          if (currentState is ReleaseNoteLoaded) {
            emit(ReleaseNoteLoaded(
              releaseNotes: currentState.releaseNotes,
              detail: detail,
            ));
          } else {
            emit(ReleaseNoteLoaded(
              releaseNotes: const [],
              detail: detail,
            ));
          }
        },
      );
    } catch (e) {
      emit(const ReleaseNoteError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCreateReleaseNote(
    CreateReleaseNote event,
    Emitter<ReleaseNoteState> emit,
  ) async {
    try {
      final result = await feedbackRepository.createReleaseNote(
        version: event.version,
        title: event.title,
        content: event.content,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is ReleaseNoteLoaded) {
            emit(ReleaseNoteLoaded(
              releaseNotes: currentState.releaseNotes,
              detail: currentState.detail,
              operationError: failure.message,
            ));
          } else {
            emit(ReleaseNoteError(failure.message));
          }
        },
        (_) => add(const LoadReleaseNotes()),
      );
    } catch (e) {
      emit(const ReleaseNoteError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onUpdateReleaseNote(
    UpdateReleaseNote event,
    Emitter<ReleaseNoteState> emit,
  ) async {
    try {
      final result = await feedbackRepository.updateReleaseNote(
        id: event.id,
        version: event.version,
        title: event.title,
        content: event.content,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is ReleaseNoteLoaded) {
            emit(ReleaseNoteLoaded(
              releaseNotes: currentState.releaseNotes,
              detail: currentState.detail,
              operationError: failure.message,
            ));
          } else {
            emit(ReleaseNoteError(failure.message));
          }
        },
        (_) => add(const LoadReleaseNotes()),
      );
    } catch (e) {
      emit(const ReleaseNoteError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onDeleteReleaseNote(
    DeleteReleaseNote event,
    Emitter<ReleaseNoteState> emit,
  ) async {
    try {
      final currentState = state;
      final result = await feedbackRepository.deleteReleaseNote(event.id);
      result.fold(
        (failure) {
          if (currentState is ReleaseNoteLoaded) {
            emit(ReleaseNoteLoaded(
              releaseNotes: currentState.releaseNotes,
              detail: currentState.detail,
              operationError: failure.message,
            ));
          } else {
            emit(ReleaseNoteError(failure.message));
          }
        },
        (_) {
          if (currentState is ReleaseNoteLoaded) {
            final updatedList = currentState.releaseNotes
                .where((n) => n.id != event.id)
                .toList();
            emit(ReleaseNoteLoaded(
              releaseNotes: updatedList,
              operationSuccess: '배포 노트가 삭제되었습니다',
            ));
          }
        },
      );
    } catch (e) {
      emit(const ReleaseNoteError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onPublishReleaseNote(
    PublishReleaseNote event,
    Emitter<ReleaseNoteState> emit,
  ) async {
    try {
      final result = await feedbackRepository.publishReleaseNote(event.id);
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is ReleaseNoteLoaded) {
            emit(ReleaseNoteLoaded(
              releaseNotes: currentState.releaseNotes,
              detail: currentState.detail,
              operationError: failure.message,
            ));
          }
        },
        (_) => add(const LoadReleaseNotes()),
      );
    } catch (e) {
      emit(const ReleaseNoteError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onLinkFeedbackToRelease(
    LinkFeedbackToRelease event,
    Emitter<ReleaseNoteState> emit,
  ) async {
    try {
      final result = await feedbackRepository.linkFeedbackToRelease(
        releaseId: event.releaseId,
        feedbackIds: event.feedbackIds,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is ReleaseNoteLoaded) {
            emit(ReleaseNoteLoaded(
              releaseNotes: currentState.releaseNotes,
              detail: currentState.detail,
              operationError: failure.message,
            ));
          }
        },
        (_) => add(const LoadReleaseNotes()),
      );
    } catch (e) {
      emit(const ReleaseNoteError('예기치 않은 오류가 발생했습니다'));
    }
  }
}
