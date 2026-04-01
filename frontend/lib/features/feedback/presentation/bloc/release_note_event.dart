import 'package:equatable/equatable.dart';

sealed class ReleaseNoteEvent extends Equatable {
  const ReleaseNoteEvent();

  @override
  List<Object?> get props => [];
}

class LoadReleaseNotes extends ReleaseNoteEvent {
  const LoadReleaseNotes();
}

class LoadReleaseNoteDetail extends ReleaseNoteEvent {
  final String id;

  const LoadReleaseNoteDetail(this.id);

  @override
  List<Object?> get props => [id];
}

// Admin events
class CreateReleaseNote extends ReleaseNoteEvent {
  final String version;
  final String title;
  final String content;

  const CreateReleaseNote({
    required this.version,
    required this.title,
    required this.content,
  });

  @override
  List<Object?> get props => [version, title, content];
}

class UpdateReleaseNote extends ReleaseNoteEvent {
  final String id;
  final String version;
  final String title;
  final String content;

  const UpdateReleaseNote({
    required this.id,
    required this.version,
    required this.title,
    required this.content,
  });

  @override
  List<Object?> get props => [id, version, title, content];
}

class DeleteReleaseNote extends ReleaseNoteEvent {
  final String id;

  const DeleteReleaseNote(this.id);

  @override
  List<Object?> get props => [id];
}

class PublishReleaseNote extends ReleaseNoteEvent {
  final String id;

  const PublishReleaseNote(this.id);

  @override
  List<Object?> get props => [id];
}

class LinkFeedbackToRelease extends ReleaseNoteEvent {
  final String releaseId;
  final List<String> feedbackIds;

  const LinkFeedbackToRelease({
    required this.releaseId,
    required this.feedbackIds,
  });

  @override
  List<Object?> get props => [releaseId, feedbackIds];
}
