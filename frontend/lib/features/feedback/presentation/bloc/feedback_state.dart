import 'package:equatable/equatable.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_post.dart';
import 'package:budget_book/features/feedback/domain/entities/public_feedback.dart';

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

class PublicFeedbacksLoaded extends FeedbackState {
  final List<PublicFeedback> feedbacks;
  final int totalElements;
  final int totalPages;
  final int currentPage;
  final String currentSort;
  final String? filterCategory;
  final String? filterStatus;
  final bool isLoadingMore;
  final String? operationError;

  const PublicFeedbacksLoaded({
    required this.feedbacks,
    this.totalElements = 0,
    this.totalPages = 0,
    this.currentPage = 0,
    this.currentSort = 'latest',
    this.filterCategory,
    this.filterStatus,
    this.isLoadingMore = false,
    this.operationError,
  });

  bool get hasMore => currentPage < totalPages - 1;

  @override
  List<Object?> get props => [
        feedbacks,
        totalElements,
        totalPages,
        currentPage,
        currentSort,
        filterCategory,
        filterStatus,
        isLoadingMore,
        operationError,
      ];
}

class PublicFeedbacksLoading extends FeedbackState {
  const PublicFeedbacksLoading();
}
