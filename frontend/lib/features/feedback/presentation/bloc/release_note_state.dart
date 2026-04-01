import 'package:equatable/equatable.dart';
import 'package:budget_book/features/feedback/domain/entities/release_note.dart';

sealed class ReleaseNoteState extends Equatable {
  const ReleaseNoteState();

  @override
  List<Object?> get props => [];
}

class ReleaseNoteInitial extends ReleaseNoteState {
  const ReleaseNoteInitial();
}

class ReleaseNoteLoading extends ReleaseNoteState {
  const ReleaseNoteLoading();
}

class ReleaseNoteLoaded extends ReleaseNoteState {
  final List<ReleaseNote> releaseNotes;
  final ReleaseNote? detail;
  final String? operationError;
  final String? operationSuccess;

  const ReleaseNoteLoaded({
    required this.releaseNotes,
    this.detail,
    this.operationError,
    this.operationSuccess,
  });

  @override
  List<Object?> get props => [
        releaseNotes,
        detail,
        operationError,
        operationSuccess,
      ];
}

class ReleaseNoteError extends ReleaseNoteState {
  final String message;

  const ReleaseNoteError(this.message);

  @override
  List<Object?> get props => [message];
}
