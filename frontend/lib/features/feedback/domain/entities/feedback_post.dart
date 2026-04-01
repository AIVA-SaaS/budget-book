import 'package:equatable/equatable.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_comment.dart';

class FeedbackPost extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String category;
  final String title;
  final String content;
  final String status;
  final String? adminNote;
  final String? resolvedReleaseId;
  final List<FeedbackComment> comments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FeedbackPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.category,
    required this.title,
    required this.content,
    required this.status,
    this.adminNote,
    this.resolvedReleaseId,
    required this.comments,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        category,
        title,
        content,
        status,
        adminNote,
        resolvedReleaseId,
        comments,
        createdAt,
        updatedAt,
      ];
}

class FeedbackStats extends Equatable {
  final int totalCount;
  final Map<String, int> byCategory;
  final Map<String, int> byStatus;

  const FeedbackStats({
    required this.totalCount,
    required this.byCategory,
    required this.byStatus,
  });

  @override
  List<Object?> get props => [totalCount, byCategory, byStatus];
}
