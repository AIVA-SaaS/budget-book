import 'package:budget_book/features/feedback/domain/entities/feedback_post.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_comment.dart';
import 'package:budget_book/features/feedback/domain/entities/release_note.dart';

class FeedbackPostModel extends FeedbackPost {
  const FeedbackPostModel({
    required super.id,
    required super.userId,
    required super.userName,
    required super.category,
    required super.title,
    required super.content,
    required super.status,
    super.adminNote,
    super.resolvedReleaseId,
    required super.comments,
    required super.createdAt,
    required super.updatedAt,
  });

  factory FeedbackPostModel.fromJson(Map<String, dynamic> json) {
    final commentsJson = json['comments'] as List<dynamic>? ?? [];
    return FeedbackPostModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      category: json['category'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      status: json['status'] as String,
      adminNote: json['adminNote'] as String?,
      resolvedReleaseId: json['resolvedReleaseId'] as String?,
      comments: commentsJson
          .map((e) => FeedbackCommentModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class FeedbackCommentModel extends FeedbackComment {
  const FeedbackCommentModel({
    required super.id,
    required super.authorId,
    required super.authorName,
    required super.content,
    required super.isAdminReply,
    required super.createdAt,
  });

  factory FeedbackCommentModel.fromJson(Map<String, dynamic> json) {
    return FeedbackCommentModel(
      id: json['id'] as String,
      authorId: json['authorId'] as String,
      authorName: json['authorName'] as String,
      content: json['content'] as String,
      isAdminReply: json['isAdminReply'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class ReleaseNoteModel extends ReleaseNote {
  const ReleaseNoteModel({
    required super.id,
    required super.version,
    required super.title,
    required super.content,
    required super.isPublished,
    super.publishedAt,
    required super.linkedFeedbackIds,
    required super.createdAt,
  });

  factory ReleaseNoteModel.fromJson(Map<String, dynamic> json) {
    final linkedIds = json['linkedFeedbackIds'] as List<dynamic>? ?? [];
    return ReleaseNoteModel(
      id: json['id'] as String,
      version: json['version'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      isPublished: json['isPublished'] as bool,
      publishedAt: json['publishedAt'] != null
          ? DateTime.parse(json['publishedAt'] as String)
          : null,
      linkedFeedbackIds: linkedIds.map((e) => e as String).toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class FeedbackStatsModel extends FeedbackStats {
  const FeedbackStatsModel({
    required super.totalCount,
    required super.byCategory,
    required super.byStatus,
  });

  factory FeedbackStatsModel.fromJson(Map<String, dynamic> json) {
    return FeedbackStatsModel(
      totalCount: json['totalCount'] as int,
      byCategory: (json['byCategory'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as int)),
      byStatus: (json['byStatus'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as int)),
    );
  }
}
