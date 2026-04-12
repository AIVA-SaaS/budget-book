import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_state.dart';
import 'package:budget_book/features/feedback/domain/repositories/feedback_repository.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_post.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_comment.dart';
import 'package:budget_book/features/feedback/domain/entities/release_note.dart';
import 'package:budget_book/features/feedback/domain/entities/public_feedback.dart';
import 'package:budget_book/core/error/failure.dart';

// Manual mock to avoid build_runner / @GenerateMocks overhead
class MockFeedbackRepository extends Mock implements FeedbackRepository {
  @override
  Future<Either<Failure, List<FeedbackPost>>> getFeedbacks() =>
      super.noSuchMethod(
        Invocation.method(#getFeedbacks, []),
        returnValue:
            Future.value(const Right<Failure, List<FeedbackPost>>([])),
      ) as Future<Either<Failure, List<FeedbackPost>>>;

  @override
  Future<Either<Failure, FeedbackPost>> createFeedback({
    required String category,
    required String title,
    required String content,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createFeedback, [], {
          #category: category,
          #title: title,
          #content: content,
        }),
        returnValue: Future.value(Right<Failure, FeedbackPost>(_dummyFeedback)),
      ) as Future<Either<Failure, FeedbackPost>>;

  @override
  Future<Either<Failure, FeedbackPost>> getFeedbackDetail(String id) =>
      super.noSuchMethod(
        Invocation.method(#getFeedbackDetail, [id]),
        returnValue: Future.value(Right<Failure, FeedbackPost>(_dummyFeedback)),
      ) as Future<Either<Failure, FeedbackPost>>;

  @override
  Future<Either<Failure, FeedbackComment>> addComment({
    required String feedbackId,
    required String content,
  }) =>
      super.noSuchMethod(
        Invocation.method(#addComment, [], {
          #feedbackId: feedbackId,
          #content: content,
        }),
        returnValue:
            Future.value(Right<Failure, FeedbackComment>(_dummyComment)),
      ) as Future<Either<Failure, FeedbackComment>>;

  @override
  Future<Either<Failure, List<FeedbackPost>>> getAdminFeedbacks({
    String? status,
    String? category,
  }) =>
      super.noSuchMethod(
        Invocation.method(#getAdminFeedbacks, [], {
          #status: status,
          #category: category,
        }),
        returnValue:
            Future.value(const Right<Failure, List<FeedbackPost>>([])),
      ) as Future<Either<Failure, List<FeedbackPost>>>;

  @override
  Future<Either<Failure, FeedbackPost>> updateFeedbackStatus({
    required String feedbackId,
    required String status,
    String? reason,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateFeedbackStatus, [], {
          #feedbackId: feedbackId,
          #status: status,
          #reason: reason,
        }),
        returnValue: Future.value(Right<Failure, FeedbackPost>(_dummyFeedback)),
      ) as Future<Either<Failure, FeedbackPost>>;

  @override
  Future<Either<Failure, FeedbackComment>> addAdminComment({
    required String feedbackId,
    required String content,
  }) =>
      super.noSuchMethod(
        Invocation.method(#addAdminComment, [], {
          #feedbackId: feedbackId,
          #content: content,
        }),
        returnValue:
            Future.value(Right<Failure, FeedbackComment>(_dummyComment)),
      ) as Future<Either<Failure, FeedbackComment>>;

  @override
  Future<Either<Failure, void>> updateAdminNote({
    required String feedbackId,
    required String adminNote,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateAdminNote, [], {
          #feedbackId: feedbackId,
          #adminNote: adminNote,
        }),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, FeedbackStats>> getFeedbackStats() =>
      super.noSuchMethod(
        Invocation.method(#getFeedbackStats, []),
        returnValue: Future.value(
          const Right<Failure, FeedbackStats>(FeedbackStats(
            totalCount: 0,
            byCategory: {},
            byStatus: {},
          )),
        ),
      ) as Future<Either<Failure, FeedbackStats>>;

  // Release note methods (needed to satisfy the interface but not used in
  // FeedbackBloc tests).
  @override
  Future<Either<Failure, List<ReleaseNote>>> getReleaseNotes() =>
      super.noSuchMethod(
        Invocation.method(#getReleaseNotes, []),
        returnValue:
            Future.value(const Right<Failure, List<ReleaseNote>>([])),
      ) as Future<Either<Failure, List<ReleaseNote>>>;

  @override
  Future<Either<Failure, ReleaseNote>> getReleaseNoteDetail(String id) =>
      super.noSuchMethod(
        Invocation.method(#getReleaseNoteDetail, [id]),
        returnValue:
            Future.value(Right<Failure, ReleaseNote>(_dummyReleaseNote)),
      ) as Future<Either<Failure, ReleaseNote>>;

  @override
  Future<Either<Failure, ReleaseNote>> getLatestReleaseNote() =>
      super.noSuchMethod(
        Invocation.method(#getLatestReleaseNote, []),
        returnValue:
            Future.value(Right<Failure, ReleaseNote>(_dummyReleaseNote)),
      ) as Future<Either<Failure, ReleaseNote>>;

  @override
  Future<Either<Failure, ReleaseNote>> createReleaseNote({
    required String version,
    required String title,
    required String content,
  }) =>
      super.noSuchMethod(
        Invocation.method(#createReleaseNote, [], {
          #version: version,
          #title: title,
          #content: content,
        }),
        returnValue:
            Future.value(Right<Failure, ReleaseNote>(_dummyReleaseNote)),
      ) as Future<Either<Failure, ReleaseNote>>;

  @override
  Future<Either<Failure, ReleaseNote>> updateReleaseNote({
    required String id,
    required String version,
    required String title,
    required String content,
  }) =>
      super.noSuchMethod(
        Invocation.method(#updateReleaseNote, [], {
          #id: id,
          #version: version,
          #title: title,
          #content: content,
        }),
        returnValue:
            Future.value(Right<Failure, ReleaseNote>(_dummyReleaseNote)),
      ) as Future<Either<Failure, ReleaseNote>>;

  @override
  Future<Either<Failure, void>> deleteReleaseNote(String id) =>
      super.noSuchMethod(
        Invocation.method(#deleteReleaseNote, [id]),
        returnValue: Future.value(const Right<Failure, void>(null)),
      ) as Future<Either<Failure, void>>;

  @override
  Future<Either<Failure, ReleaseNote>> publishReleaseNote(String id) =>
      super.noSuchMethod(
        Invocation.method(#publishReleaseNote, [id]),
        returnValue:
            Future.value(Right<Failure, ReleaseNote>(_dummyReleaseNote)),
      ) as Future<Either<Failure, ReleaseNote>>;

  @override
  Future<Either<Failure, ReleaseNote>> linkFeedbackToRelease({
    required String releaseId,
    required List<String> feedbackIds,
  }) =>
      super.noSuchMethod(
        Invocation.method(#linkFeedbackToRelease, [], {
          #releaseId: releaseId,
          #feedbackIds: feedbackIds,
        }),
        returnValue:
            Future.value(Right<Failure, ReleaseNote>(_dummyReleaseNote)),
      ) as Future<Either<Failure, ReleaseNote>>;

  @override
  Future<Either<Failure, (List<PublicFeedback>, int, int)>>
      getPublicFeedbacks({
    String sort = 'latest',
    String? category,
    String? status,
    int page = 0,
    int size = 20,
  }) =>
          super.noSuchMethod(
            Invocation.method(#getPublicFeedbacks, [], {
              #sort: sort,
              #category: category,
              #status: status,
              #page: page,
              #size: size,
            }),
            returnValue: Future.value(
              const Right<Failure, (List<PublicFeedback>, int, int)>(
                  (<PublicFeedback>[], 0, 0)),
            ),
          ) as Future<Either<Failure, (List<PublicFeedback>, int, int)>>;

  @override
  Future<Either<Failure, List<PublicFeedback>>> getTopFeedbacks() =>
      super.noSuchMethod(
        Invocation.method(#getTopFeedbacks, []),
        returnValue:
            Future.value(const Right<Failure, List<PublicFeedback>>([])),
      ) as Future<Either<Failure, List<PublicFeedback>>>;

  @override
  Future<Either<Failure, VoteResponse>> toggleVote(String feedbackId) =>
      super.noSuchMethod(
        Invocation.method(#toggleVote, [feedbackId]),
        returnValue: Future.value(
          const Right<Failure, VoteResponse>(
              VoteResponse(voted: true, voteCount: 1)),
        ),
      ) as Future<Either<Failure, VoteResponse>>;
}

final _dummyFeedback = FeedbackPost(
  id: 'dummy',
  userId: 'u1',
  userName: 'Test',
  category: 'BUG',
  title: 'dummy',
  content: 'dummy',
  status: 'SUBMITTED',
  comments: const [],
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
);

final _dummyComment = FeedbackComment(
  id: 'c1',
  authorId: 'u1',
  authorName: 'Test',
  content: 'reply',
  isAdminReply: false,
  createdAt: DateTime(2024),
);

final _dummyReleaseNote = ReleaseNote(
  id: 'r1',
  version: 'v1.0.0',
  title: 'Release',
  content: 'Content',
  isPublished: true,
  linkedFeedbackIds: const [],
  createdAt: DateTime(2024),
);

void main() {
  late FeedbackBloc bloc;
  late MockFeedbackRepository mockRepository;

  final tFeedback1 = FeedbackPost(
    id: 'f1',
    userId: 'u1',
    userName: '김철수',
    category: 'BUG',
    title: '앱이 멈춤',
    content: '홈 화면에서 앱이 멈춰요',
    status: 'SUBMITTED',
    comments: const [],
    createdAt: DateTime.parse('2026-03-01T10:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T10:00:00Z'),
  );

  final tFeedback2 = FeedbackPost(
    id: 'f2',
    userId: 'u1',
    userName: '김철수',
    category: 'FEATURE',
    title: '다크모드 지원',
    content: '다크모드를 지원해주세요',
    status: 'REVIEWING',
    comments: const [],
    createdAt: DateTime.parse('2026-03-02T10:00:00Z'),
    updatedAt: DateTime.parse('2026-03-02T10:00:00Z'),
  );

  final tFeedbackWithDetail = FeedbackPost(
    id: 'f1',
    userId: 'u1',
    userName: '김철수',
    category: 'BUG',
    title: '앱이 멈춤',
    content: '홈 화면에서 앱이 멈춰요',
    status: 'SUBMITTED',
    comments: [
      FeedbackComment(
        id: 'c1',
        authorId: 'admin1',
        authorName: '관리자',
        content: '확인하겠습니다',
        isAdminReply: true,
        createdAt: DateTime.parse('2026-03-01T11:00:00Z'),
      ),
    ],
    createdAt: DateTime.parse('2026-03-01T10:00:00Z'),
    updatedAt: DateTime.parse('2026-03-01T11:00:00Z'),
  );

  final tFeedbacks = [tFeedback1, tFeedback2];

  setUp(() {
    mockRepository = MockFeedbackRepository();
    bloc = FeedbackBloc(feedbackRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('FeedbackBloc', () {
    test('initial state is FeedbackInitial', () {
      expect(bloc.state, const FeedbackInitial());
    });

    group('LoadFeedbacks', () {
      blocTest<FeedbackBloc, FeedbackState>(
        'emits [Loading, Loaded] on success',
        build: () {
          when(mockRepository.getFeedbacks())
              .thenAnswer((_) async => Right(tFeedbacks));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadFeedbacks()),
        expect: () => [
          const FeedbackLoading(),
          FeedbackLoaded(feedbacks: tFeedbacks),
        ],
      );

      blocTest<FeedbackBloc, FeedbackState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(mockRepository.getFeedbacks()).thenAnswer(
            (_) async =>
                const Left(ServerFailure('피드백 목록을 불러오지 못했습니다')),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadFeedbacks()),
        expect: () => [
          const FeedbackLoading(),
          const FeedbackError('피드백 목록을 불러오지 못했습니다'),
        ],
      );
    });

    group('CreateFeedback', () {
      blocTest<FeedbackBloc, FeedbackState>(
        'reloads list on success',
        build: () {
          when(mockRepository.createFeedback(
            category: 'BUG',
            title: '새 버그',
            content: '내용',
          )).thenAnswer((_) async => Right(tFeedback1));
          when(mockRepository.getFeedbacks())
              .thenAnswer((_) async => Right(tFeedbacks));
          return bloc;
        },
        seed: () => FeedbackLoaded(feedbacks: tFeedbacks),
        act: (bloc) => bloc.add(const CreateFeedback(
          category: 'BUG',
          title: '새 버그',
          content: '내용',
        )),
        expect: () => [
          const FeedbackLoading(),
          FeedbackLoaded(feedbacks: tFeedbacks),
        ],
      );

      blocTest<FeedbackBloc, FeedbackState>(
        'emits operationError on failure',
        build: () {
          when(mockRepository.createFeedback(
            category: 'BUG',
            title: '새 버그',
            content: '내용',
          )).thenAnswer(
            (_) async =>
                const Left(ServerFailure('피드백을 등록하지 못했습니다')),
          );
          return bloc;
        },
        seed: () => FeedbackLoaded(feedbacks: tFeedbacks),
        act: (bloc) => bloc.add(const CreateFeedback(
          category: 'BUG',
          title: '새 버그',
          content: '내용',
        )),
        expect: () => [
          FeedbackLoaded(
            feedbacks: tFeedbacks,
            operationError: '피드백을 등록하지 못했습니다',
          ),
        ],
      );
    });

    group('LoadFeedbackDetail', () {
      blocTest<FeedbackBloc, FeedbackState>(
        'emits Loaded with detail on success',
        build: () {
          when(mockRepository.getFeedbackDetail('f1'))
              .thenAnswer((_) async => Right(tFeedbackWithDetail));
          return bloc;
        },
        seed: () => FeedbackLoaded(feedbacks: tFeedbacks),
        act: (bloc) => bloc.add(const LoadFeedbackDetail('f1')),
        expect: () => [
          FeedbackLoaded(
            feedbacks: tFeedbacks,
            detail: tFeedbackWithDetail,
          ),
        ],
      );

      blocTest<FeedbackBloc, FeedbackState>(
        'emits Error when not loaded and failure',
        build: () {
          when(mockRepository.getFeedbackDetail('f1')).thenAnswer(
            (_) async =>
                const Left(ServerFailure('피드백 상세를 불러오지 못했습니다')),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadFeedbackDetail('f1')),
        expect: () => [
          const FeedbackError('피드백 상세를 불러오지 못했습니다'),
        ],
      );
    });

    group('AddComment', () {
      blocTest<FeedbackBloc, FeedbackState>(
        'reloads detail on success',
        build: () {
          when(mockRepository.addComment(
            feedbackId: 'f1',
            content: '댓글',
          )).thenAnswer((_) async => Right(FeedbackComment(
                id: 'c2',
                authorId: 'u1',
                authorName: '김철수',
                content: '댓글',
                isAdminReply: false,
                createdAt: DateTime.parse('2026-03-01T12:00:00Z'),
              )));
          // LoadFeedbackDetail will be dispatched
          when(mockRepository.getFeedbackDetail('f1'))
              .thenAnswer((_) async => Right(tFeedbackWithDetail));
          return bloc;
        },
        seed: () => FeedbackLoaded(
          feedbacks: tFeedbacks,
          detail: tFeedback1,
        ),
        act: (bloc) => bloc.add(const AddComment(
          feedbackId: 'f1',
          content: '댓글',
        )),
        expect: () => [
          FeedbackLoaded(
            feedbacks: tFeedbacks,
            detail: tFeedbackWithDetail,
          ),
        ],
      );
    });

    group('LoadAdminFeedbacks', () {
      blocTest<FeedbackBloc, FeedbackState>(
        'emits [Loading, Loaded] with filters',
        build: () {
          when(mockRepository.getAdminFeedbacks(
                  status: 'SUBMITTED'))
              .thenAnswer((_) async => Right([tFeedback1]));
          return bloc;
        },
        act: (bloc) => bloc.add(
            const LoadAdminFeedbacks(status: 'SUBMITTED')),
        expect: () => [
          const FeedbackLoading(),
          FeedbackLoaded(feedbacks: [tFeedback1]),
        ],
      );
    });

    group('UpdateFeedbackStatus', () {
      blocTest<FeedbackBloc, FeedbackState>(
        'reloads admin feedbacks on success',
        build: () {
          when(mockRepository.updateFeedbackStatus(
            feedbackId: 'f1',
            status: 'REVIEWING',
          )).thenAnswer((_) async => Right(tFeedback1));
          when(mockRepository.getAdminFeedbacks())
              .thenAnswer((_) async => Right(tFeedbacks));
          return bloc;
        },
        seed: () => FeedbackLoaded(feedbacks: [tFeedback1]),
        act: (bloc) => bloc.add(const UpdateFeedbackStatus(
          feedbackId: 'f1',
          status: 'REVIEWING',
        )),
        expect: () => [
          const FeedbackLoading(),
          FeedbackLoaded(feedbacks: tFeedbacks),
        ],
      );
    });

    group('LoadPublicFeedbacks', () {
      final tPublicFeedback = PublicFeedback(
        id: 'pf1',
        category: 'FEATURE',
        title: '다크모드 지원',
        contentPreview: '다크모드를 지원해주세요...',
        status: 'REVIEWING',
        voteCount: 10,
        hasVoted: false,
        commentCount: 3,
        authorName: '홍길동',
        createdAt: DateTime.parse('2026-04-01T10:00:00Z'),
      );

      blocTest<FeedbackBloc, FeedbackState>(
        'emits [PublicFeedbacksLoading, PublicFeedbacksLoaded] on success',
        build: () {
          when(mockRepository.getPublicFeedbacks(
            sort: 'latest',
            page: 0,
          )).thenAnswer((_) async => Right(([tPublicFeedback], 1, 1)));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadPublicFeedbacks()),
        expect: () => [
          const PublicFeedbacksLoading(),
          isA<PublicFeedbacksLoaded>()
              .having((s) => s.feedbacks.length, 'count', 1)
              .having((s) => s.feedbacks.first.id, 'first id', 'pf1')
              .having((s) => s.totalElements, 'totalElements', 1),
        ],
      );

      blocTest<FeedbackBloc, FeedbackState>(
        'emits Error on failure',
        build: () {
          when(mockRepository.getPublicFeedbacks(
            sort: 'latest',
            page: 0,
          )).thenAnswer(
            (_) async => const Left(ServerFailure('공개 피드백을 불러오지 못했습니다')),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadPublicFeedbacks()),
        expect: () => [
          const PublicFeedbacksLoading(),
          const FeedbackError('공개 피드백을 불러오지 못했습니다'),
        ],
      );
    });

    group('ToggleVote', () {
      final tPublicFeedback = PublicFeedback(
        id: 'pf1',
        category: 'FEATURE',
        title: '다크모드 지원',
        contentPreview: '다크모드를 지원해주세요...',
        status: 'REVIEWING',
        voteCount: 10,
        hasVoted: false,
        commentCount: 3,
        authorName: '홍길동',
        createdAt: DateTime.parse('2026-04-01T10:00:00Z'),
      );

      blocTest<FeedbackBloc, FeedbackState>(
        'optimistically updates then confirms with server (deduplicated)',
        build: () {
          when(mockRepository.toggleVote('pf1')).thenAnswer(
            (_) async =>
                const Right(VoteResponse(voted: true, voteCount: 11)),
          );
          return bloc;
        },
        seed: () => PublicFeedbacksLoaded(
          feedbacks: [tPublicFeedback],
          totalElements: 1,
          totalPages: 1,
        ),
        act: (bloc) => bloc.add(const ToggleVote('pf1')),
        expect: () => [
          // Optimistic + server confirm are equal, so BLoC deduplicates to 1 emission
          isA<PublicFeedbacksLoaded>()
              .having((s) => s.feedbacks.first.hasVoted, 'voted', true)
              .having((s) => s.feedbacks.first.voteCount, 'count', 11),
        ],
      );

      blocTest<FeedbackBloc, FeedbackState>(
        'reverts on server failure',
        build: () {
          when(mockRepository.toggleVote('pf1')).thenAnswer(
            (_) async => const Left(ServerFailure('투표를 처리하지 못했습니다')),
          );
          return bloc;
        },
        seed: () => PublicFeedbacksLoaded(
          feedbacks: [tPublicFeedback],
          totalElements: 1,
          totalPages: 1,
        ),
        act: (bloc) => bloc.add(const ToggleVote('pf1')),
        expect: () => [
          // Optimistic update
          isA<PublicFeedbacksLoaded>()
              .having((s) => s.feedbacks.first.hasVoted, 'voted', true),
          // Revert on failure
          isA<PublicFeedbacksLoaded>()
              .having((s) => s.feedbacks.first.hasVoted, 'reverted', false)
              .having((s) => s.feedbacks.first.voteCount, 'reverted count', 10)
              .having((s) => s.operationError, 'error', '투표를 처리하지 못했습니다'),
        ],
      );
    });
  });

  group('FeedbackPost entity', () {
    test('equatable compares by all props', () {
      final copy = FeedbackPost(
        id: 'f1',
        userId: 'u1',
        userName: '김철수',
        category: 'BUG',
        title: '앱이 멈춤',
        content: '홈 화면에서 앱이 멈춰요',
        status: 'SUBMITTED',
        comments: const [],
        createdAt: DateTime.parse('2026-03-01T10:00:00Z'),
        updatedAt: DateTime.parse('2026-03-01T10:00:00Z'),
      );
      expect(tFeedback1, equals(copy));
    });
  });
}
