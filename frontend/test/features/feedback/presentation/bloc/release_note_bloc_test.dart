import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dartz/dartz.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_event.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_state.dart';
import 'package:budget_book/features/feedback/domain/entities/release_note.dart';
import 'package:budget_book/core/error/failure.dart';

// Reuse the mock from feedback_bloc_test.dart pattern
import 'feedback_bloc_test.dart';

void main() {
  late ReleaseNoteBloc bloc;
  late MockFeedbackRepository mockRepository;

  final tNote1 = ReleaseNote(
    id: 'r1',
    version: 'v1.0.0',
    title: '첫 릴리즈',
    content: '## 주요 변경사항\n- 가계부 기능',
    isPublished: true,
    publishedAt: DateTime.parse('2026-03-01T10:00:00Z'),
    linkedFeedbackIds: const [],
    createdAt: DateTime.parse('2026-03-01T09:00:00Z'),
  );

  final tNote2 = ReleaseNote(
    id: 'r2',
    version: 'v1.1.0',
    title: '기능 개선',
    content: '## 변경사항\n- 다크모드 추가',
    isPublished: false,
    linkedFeedbackIds: const ['f1'],
    createdAt: DateTime.parse('2026-03-15T09:00:00Z'),
  );

  final tNotes = [tNote1, tNote2];

  setUp(() {
    mockRepository = MockFeedbackRepository();
    bloc = ReleaseNoteBloc(feedbackRepository: mockRepository);
  });

  tearDown(() {
    bloc.close();
  });

  group('ReleaseNoteBloc', () {
    test('initial state is ReleaseNoteInitial', () {
      expect(bloc.state, const ReleaseNoteInitial());
    });

    group('LoadReleaseNotes', () {
      blocTest<ReleaseNoteBloc, ReleaseNoteState>(
        'emits [Loading, Loaded] on success',
        build: () {
          when(mockRepository.getReleaseNotes())
              .thenAnswer((_) async => Right(tNotes));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadReleaseNotes()),
        expect: () => [
          const ReleaseNoteLoading(),
          ReleaseNoteLoaded(releaseNotes: tNotes),
        ],
      );

      blocTest<ReleaseNoteBloc, ReleaseNoteState>(
        'emits [Loading, Error] on failure',
        build: () {
          when(mockRepository.getReleaseNotes()).thenAnswer(
            (_) async =>
                const Left(ServerFailure('업데이트 노트를 불러오지 못했습니다')),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadReleaseNotes()),
        expect: () => [
          const ReleaseNoteLoading(),
          const ReleaseNoteError('업데이트 노트를 불러오지 못했습니다'),
        ],
      );
    });

    group('LoadReleaseNoteDetail', () {
      blocTest<ReleaseNoteBloc, ReleaseNoteState>(
        'emits Loaded with detail on success',
        build: () {
          when(mockRepository.getReleaseNoteDetail('r1'))
              .thenAnswer((_) async => Right(tNote1));
          return bloc;
        },
        seed: () => ReleaseNoteLoaded(releaseNotes: tNotes),
        act: (bloc) => bloc.add(const LoadReleaseNoteDetail('r1')),
        expect: () => [
          ReleaseNoteLoaded(releaseNotes: tNotes, detail: tNote1),
        ],
      );

      blocTest<ReleaseNoteBloc, ReleaseNoteState>(
        'emits Loaded with empty list when no prior state',
        build: () {
          when(mockRepository.getReleaseNoteDetail('r1'))
              .thenAnswer((_) async => Right(tNote1));
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadReleaseNoteDetail('r1')),
        expect: () => [
          ReleaseNoteLoaded(releaseNotes: const [], detail: tNote1),
        ],
      );

      blocTest<ReleaseNoteBloc, ReleaseNoteState>(
        'emits Error when not loaded and failure',
        build: () {
          when(mockRepository.getReleaseNoteDetail('r1')).thenAnswer(
            (_) async =>
                const Left(ServerFailure('업데이트 노트를 불러오지 못했습니다')),
          );
          return bloc;
        },
        act: (bloc) => bloc.add(const LoadReleaseNoteDetail('r1')),
        expect: () => [
          const ReleaseNoteError('업데이트 노트를 불러오지 못했습니다'),
        ],
      );
    });

    group('DeleteReleaseNote', () {
      blocTest<ReleaseNoteBloc, ReleaseNoteState>(
        'removes note from list on success',
        build: () {
          when(mockRepository.deleteReleaseNote('r1'))
              .thenAnswer((_) async => const Right(null));
          return bloc;
        },
        seed: () => ReleaseNoteLoaded(releaseNotes: tNotes),
        act: (bloc) => bloc.add(const DeleteReleaseNote('r1')),
        expect: () => [
          ReleaseNoteLoaded(
            releaseNotes: [tNote2],
            operationSuccess: '배포 노트가 삭제되었습니다',
          ),
        ],
      );

      blocTest<ReleaseNoteBloc, ReleaseNoteState>(
        'emits operationError on failure',
        build: () {
          when(mockRepository.deleteReleaseNote('r1')).thenAnswer(
            (_) async =>
                const Left(ServerFailure('배포 노트를 삭제하지 못했습니다')),
          );
          return bloc;
        },
        seed: () => ReleaseNoteLoaded(releaseNotes: tNotes),
        act: (bloc) => bloc.add(const DeleteReleaseNote('r1')),
        expect: () => [
          ReleaseNoteLoaded(
            releaseNotes: tNotes,
            operationError: '배포 노트를 삭제하지 못했습니다',
          ),
        ],
      );
    });

    group('CreateReleaseNote', () {
      blocTest<ReleaseNoteBloc, ReleaseNoteState>(
        'reloads list on success',
        build: () {
          when(mockRepository.createReleaseNote(
            version: 'v2.0.0',
            title: '새 릴리즈',
            content: '내용',
          )).thenAnswer((_) async => Right(tNote1));
          when(mockRepository.getReleaseNotes())
              .thenAnswer((_) async => Right(tNotes));
          return bloc;
        },
        seed: () => ReleaseNoteLoaded(releaseNotes: tNotes),
        act: (bloc) => bloc.add(const CreateReleaseNote(
          version: 'v2.0.0',
          title: '새 릴리즈',
          content: '내용',
        )),
        expect: () => [
          const ReleaseNoteLoading(),
          ReleaseNoteLoaded(releaseNotes: tNotes),
        ],
      );
    });

    group('PublishReleaseNote', () {
      blocTest<ReleaseNoteBloc, ReleaseNoteState>(
        'reloads list on success',
        build: () {
          when(mockRepository.publishReleaseNote('r2'))
              .thenAnswer((_) async => Right(tNote2));
          when(mockRepository.getReleaseNotes())
              .thenAnswer((_) async => Right(tNotes));
          return bloc;
        },
        seed: () => ReleaseNoteLoaded(releaseNotes: tNotes),
        act: (bloc) => bloc.add(const PublishReleaseNote('r2')),
        expect: () => [
          const ReleaseNoteLoading(),
          ReleaseNoteLoaded(releaseNotes: tNotes),
        ],
      );
    });
  });

  group('ReleaseNote entity', () {
    test('equatable compares by all props', () {
      final copy = ReleaseNote(
        id: 'r1',
        version: 'v1.0.0',
        title: '첫 릴리즈',
        content: '## 주요 변경사항\n- 가계부 기능',
        isPublished: true,
        publishedAt: DateTime.parse('2026-03-01T10:00:00Z'),
        linkedFeedbackIds: const [],
        createdAt: DateTime.parse('2026-03-01T09:00:00Z'),
      );
      expect(tNote1, equals(copy));
    });
  });
}
