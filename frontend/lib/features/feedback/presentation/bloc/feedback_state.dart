import 'package:equatable/equatable.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_post.dart';

sealed class FeedbackState extends Equatable {
  const FeedbackState();

  @override
  List<Object?> get props => [];
}

class FeedbackInitial extends FeedbackState {
  const FeedbackInitial();
}

class FeedbackLoading extends FeedbackState {
  const FeedbackLoading();
}

class FeedbackLoaded extends FeedbackState {
  final List<FeedbackPost> feedbacks;
  final FeedbackPost? detail;
  final FeedbackStats? stats;
  final String? operationError;
  final String? operationSuccess;

  const FeedbackLoaded({
    required this.feedbacks,
    this.detail,
    this.stats,
    this.operationError,
    this.operationSuccess,
  });

  @override
  List<Object?> get props => [
        feedbacks,
        detail,
        stats,
        operationError,
        operationSuccess,
      ];
}

class FeedbackError extends FeedbackState {
  final String message;

  const FeedbackError(this.message);

  @override
  List<Object?> get props => [message];
}
