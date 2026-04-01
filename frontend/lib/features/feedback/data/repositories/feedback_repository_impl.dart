import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/feedback/data/datasources/feedback_remote_datasource.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_post.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_comment.dart';
import 'package:budget_book/features/feedback/domain/entities/release_note.dart';
import 'package:budget_book/features/feedback/domain/repositories/feedback_repository.dart';

class FeedbackRepositoryImpl implements FeedbackRepository {
  final FeedbackRemoteDataSource remoteDataSource;

  FeedbackRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<FeedbackPost>>> getFeedbacks() async {
    try {
      final result = await remoteDataSource.getFeedbacks();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '피드백 목록을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('피드백 목록을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, FeedbackPost>> createFeedback({
    required String category,
    required String title,
    required String content,
  }) async {
    try {
      final data = {
        'category': category,
        'title': title,
        'content': content,
      };
      final result = await remoteDataSource.createFeedback(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '피드백을 등록하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('피드백을 등록하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, FeedbackPost>> getFeedbackDetail(String id) async {
    try {
      final result = await remoteDataSource.getFeedbackDetail(id);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '피드백 상세를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('피드백 상세를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, FeedbackComment>> addComment({
    required String feedbackId,
    required String content,
  }) async {
    try {
      final data = {'content': content};
      final result = await remoteDataSource.addComment(feedbackId, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '댓글을 등록하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('댓글을 등록하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<ReleaseNote>>> getReleaseNotes() async {
    try {
      final result = await remoteDataSource.getReleaseNotes();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '업데이트 노트를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('업데이트 노트를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, ReleaseNote>> getReleaseNoteDetail(String id) async {
    try {
      final result = await remoteDataSource.getReleaseNoteDetail(id);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '업데이트 노트를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('업데이트 노트를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, ReleaseNote>> getLatestReleaseNote() async {
    try {
      final result = await remoteDataSource.getLatestReleaseNote();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '최신 업데이트 노트를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('최신 업데이트 노트를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, List<FeedbackPost>>> getAdminFeedbacks({
    String? status,
    String? category,
  }) async {
    try {
      final result = await remoteDataSource.getAdminFeedbacks(
        status: status,
        category: category,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '피드백 목록을 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('피드백 목록을 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, FeedbackPost>> updateFeedbackStatus({
    required String feedbackId,
    required String status,
    String? reason,
  }) async {
    try {
      final data = <String, dynamic>{
        'status': status,
        if (reason != null) 'reason': reason,
      };
      final result =
          await remoteDataSource.updateFeedbackStatus(feedbackId, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '상태를 변경하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('상태를 변경하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, FeedbackComment>> addAdminComment({
    required String feedbackId,
    required String content,
  }) async {
    try {
      final data = {'content': content};
      final result = await remoteDataSource.addAdminComment(feedbackId, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '답변을 등록하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('답변을 등록하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, void>> updateAdminNote({
    required String feedbackId,
    required String adminNote,
  }) async {
    try {
      await remoteDataSource.updateAdminNote(
          feedbackId, {'adminNote': adminNote});
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, '메모를 저장하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('메모를 저장하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, FeedbackStats>> getFeedbackStats() async {
    try {
      final result = await remoteDataSource.getFeedbackStats();
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '통계를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('통계를 불러오지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, ReleaseNote>> createReleaseNote({
    required String version,
    required String title,
    required String content,
  }) async {
    try {
      final data = {
        'version': version,
        'title': title,
        'content': content,
      };
      final result = await remoteDataSource.createReleaseNote(data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '배포 노트를 생성하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('배포 노트를 생성하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, ReleaseNote>> updateReleaseNote({
    required String id,
    required String version,
    required String title,
    required String content,
  }) async {
    try {
      final data = {
        'version': version,
        'title': title,
        'content': content,
      };
      final result = await remoteDataSource.updateReleaseNote(id, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '배포 노트를 수정하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('배포 노트를 수정하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReleaseNote(String id) async {
    try {
      await remoteDataSource.deleteReleaseNote(id);
      return const Right(null);
    } on DioException catch (e) {
      return Left(mapDioError(e, '배포 노트를 삭제하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('배포 노트를 삭제하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, ReleaseNote>> publishReleaseNote(String id) async {
    try {
      final result = await remoteDataSource.publishReleaseNote(id);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '배포 노트를 게시하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('배포 노트를 게시하지 못했습니다'));
    }
  }

  @override
  Future<Either<Failure, ReleaseNote>> linkFeedbackToRelease({
    required String releaseId,
    required List<String> feedbackIds,
  }) async {
    try {
      final data = {'feedbackIds': feedbackIds};
      final result =
          await remoteDataSource.linkFeedbackToRelease(releaseId, data);
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '피드백을 연결하지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('피드백을 연결하지 못했습니다'));
    }
  }
}
