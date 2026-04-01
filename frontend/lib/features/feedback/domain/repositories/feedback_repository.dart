import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_post.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_comment.dart';
import 'package:budget_book/features/feedback/domain/entities/release_note.dart';

abstract class FeedbackRepository {
  // User endpoints
  Future<Either<Failure, List<FeedbackPost>>> getFeedbacks();

  Future<Either<Failure, FeedbackPost>> createFeedback({
    required String category,
    required String title,
    required String content,
  });

  Future<Either<Failure, FeedbackPost>> getFeedbackDetail(String id);

  Future<Either<Failure, FeedbackComment>> addComment({
    required String feedbackId,
    required String content,
  });

  // Release notes (public)
  Future<Either<Failure, List<ReleaseNote>>> getReleaseNotes();

  Future<Either<Failure, ReleaseNote>> getReleaseNoteDetail(String id);

  Future<Either<Failure, ReleaseNote>> getLatestReleaseNote();

  // Admin endpoints
  Future<Either<Failure, List<FeedbackPost>>> getAdminFeedbacks({
    String? status,
    String? category,
  });

  Future<Either<Failure, FeedbackPost>> updateFeedbackStatus({
    required String feedbackId,
    required String status,
    String? reason,
  });

  Future<Either<Failure, FeedbackComment>> addAdminComment({
    required String feedbackId,
    required String content,
  });

  Future<Either<Failure, void>> updateAdminNote({
    required String feedbackId,
    required String adminNote,
  });

  Future<Either<Failure, FeedbackStats>> getFeedbackStats();

  // Admin release note management
  Future<Either<Failure, ReleaseNote>> createReleaseNote({
    required String version,
    required String title,
    required String content,
  });

  Future<Either<Failure, ReleaseNote>> updateReleaseNote({
    required String id,
    required String version,
    required String title,
    required String content,
  });

  Future<Either<Failure, void>> deleteReleaseNote(String id);

  Future<Either<Failure, ReleaseNote>> publishReleaseNote(String id);

  Future<Either<Failure, ReleaseNote>> linkFeedbackToRelease({
    required String releaseId,
    required List<String> feedbackIds,
  });
}
