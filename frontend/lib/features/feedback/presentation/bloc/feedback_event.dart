import 'package:equatable/equatable.dart';

sealed class FeedbackEvent extends Equatable {
  const FeedbackEvent();

  @override
  List<Object?> get props => [];
}

class LoadFeedbacks extends FeedbackEvent {
  const LoadFeedbacks();
}

class CreateFeedback extends FeedbackEvent {
  final String category;
  final String title;
  final String content;

  const CreateFeedback({
    required this.category,
    required this.title,
    required this.content,
  });

  @override
  List<Object?> get props => [category, title, content];
}

class LoadFeedbackDetail extends FeedbackEvent {
  final String id;

  const LoadFeedbackDetail(this.id);

  @override
  List<Object?> get props => [id];
}

class AddComment extends FeedbackEvent {
  final String feedbackId;
  final String content;

  const AddComment({
    required this.feedbackId,
    required this.content,
  });

  @override
  List<Object?> get props => [feedbackId, content];
}

// Admin events
class LoadAdminFeedbacks extends FeedbackEvent {
  final String? status;
  final String? category;

  const LoadAdminFeedbacks({this.status, this.category});

  @override
  List<Object?> get props => [status, category];
}

class UpdateFeedbackStatus extends FeedbackEvent {
  final String feedbackId;
  final String status;
  final String? reason;

  const UpdateFeedbackStatus({
    required this.feedbackId,
    required this.status,
    this.reason,
  });

  @override
  List<Object?> get props => [feedbackId, status, reason];
}

class AddAdminComment extends FeedbackEvent {
  final String feedbackId;
  final String content;

  const AddAdminComment({
    required this.feedbackId,
    required this.content,
  });

  @override
  List<Object?> get props => [feedbackId, content];
}

class UpdateAdminNote extends FeedbackEvent {
  final String feedbackId;
  final String adminNote;

  const UpdateAdminNote({
    required this.feedbackId,
    required this.adminNote,
  });

  @override
  List<Object?> get props => [feedbackId, adminNote];
}

class LoadFeedbackStats extends FeedbackEvent {
  const LoadFeedbackStats();
}
