import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/features/feedback/domain/repositories/feedback_repository.dart';
import 'feedback_event.dart';
import 'feedback_state.dart';

class FeedbackBloc extends Bloc<FeedbackEvent, FeedbackState> {
  final FeedbackRepository feedbackRepository;

  // Persist last admin filter for reloads
  String? _lastAdminStatus;
  String? _lastAdminCategory;

  FeedbackBloc({required this.feedbackRepository})
      : super(const FeedbackInitial()) {
    on<LoadFeedbacks>(_onLoadFeedbacks);
    on<CreateFeedback>(_onCreateFeedback);
    on<LoadFeedbackDetail>(_onLoadFeedbackDetail);
    on<AddComment>(_onAddComment);
    on<LoadAdminFeedbacks>(_onLoadAdminFeedbacks);
    on<UpdateFeedbackStatus>(_onUpdateFeedbackStatus);
    on<AddAdminComment>(_onAddAdminComment);
    on<UpdateAdminNote>(_onUpdateAdminNote);
    on<LoadFeedbackStats>(_onLoadFeedbackStats);
    on<LoadPublicFeedbacks>(_onLoadPublicFeedbacks);
    on<ToggleVote>(_onToggleVote);
  }

  Future<void> _onLoadFeedbacks(
    LoadFeedbacks event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      emit(const FeedbackLoading());
      final result = await feedbackRepository.getFeedbacks();
      result.fold(
        (failure) => emit(FeedbackError(failure.message)),
        (feedbacks) => emit(FeedbackLoaded(feedbacks: feedbacks)),
      );
    } catch (e) {
      emit(const FeedbackError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCreateFeedback(
    CreateFeedback event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      final result = await feedbackRepository.createFeedback(
        category: event.category,
        title: event.title,
        content: event.content,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is FeedbackLoaded) {
            emit(FeedbackLoaded(
              feedbacks: currentState.feedbacks,
              detail: currentState.detail,
              stats: currentState.stats,
              operationError: failure.message,
            ));
          } else {
            emit(FeedbackError(failure.message));
          }
        },
        (_) => add(const LoadFeedbacks()),
      );
    } catch (e) {
      emit(const FeedbackError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onLoadFeedbackDetail(
    LoadFeedbackDetail event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      final result = await feedbackRepository.getFeedbackDetail(event.id);
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is FeedbackLoaded) {
            emit(FeedbackLoaded(
              feedbacks: currentState.feedbacks,
              stats: currentState.stats,
              operationError: failure.message,
            ));
          } else {
            emit(FeedbackError(failure.message));
          }
        },
        (detail) {
          final currentState = state;
          if (currentState is FeedbackLoaded) {
            emit(FeedbackLoaded(
              feedbacks: currentState.feedbacks,
              detail: detail,
              stats: currentState.stats,
            ));
          } else {
            emit(FeedbackLoaded(
              feedbacks: const [],
              detail: detail,
            ));
          }
        },
      );
    } catch (e) {
      emit(const FeedbackError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onAddComment(
    AddComment event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      final result = await feedbackRepository.addComment(
        feedbackId: event.feedbackId,
        content: event.content,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is FeedbackLoaded) {
            emit(FeedbackLoaded(
              feedbacks: currentState.feedbacks,
              detail: currentState.detail,
              stats: currentState.stats,
              operationError: failure.message,
            ));
          }
        },
        (_) => add(LoadFeedbackDetail(event.feedbackId)),
      );
    } catch (e) {
      // Silent fail for comment
    }
  }

  Future<void> _onLoadAdminFeedbacks(
    LoadAdminFeedbacks event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      _lastAdminStatus = event.status;
      _lastAdminCategory = event.category;
      emit(const FeedbackLoading());
      final result = await feedbackRepository.getAdminFeedbacks(
        status: event.status,
        category: event.category,
      );
      result.fold(
        (failure) => emit(FeedbackError(failure.message)),
        (feedbacks) => emit(FeedbackLoaded(feedbacks: feedbacks)),
      );
    } catch (e) {
      emit(const FeedbackError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onUpdateFeedbackStatus(
    UpdateFeedbackStatus event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      final result = await feedbackRepository.updateFeedbackStatus(
        feedbackId: event.feedbackId,
        status: event.status,
        reason: event.reason,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is FeedbackLoaded) {
            emit(FeedbackLoaded(
              feedbacks: currentState.feedbacks,
              detail: currentState.detail,
              stats: currentState.stats,
              operationError: failure.message,
            ));
          }
        },
        (updated) {
          // Reload admin list with last filters
          add(LoadAdminFeedbacks(
            status: _lastAdminStatus,
            category: _lastAdminCategory,
          ));
        },
      );
    } catch (e) {
      emit(const FeedbackError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onAddAdminComment(
    AddAdminComment event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      final result = await feedbackRepository.addAdminComment(
        feedbackId: event.feedbackId,
        content: event.content,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is FeedbackLoaded) {
            emit(FeedbackLoaded(
              feedbacks: currentState.feedbacks,
              detail: currentState.detail,
              stats: currentState.stats,
              operationError: failure.message,
            ));
          }
        },
        (_) => add(LoadFeedbackDetail(event.feedbackId)),
      );
    } catch (e) {
      // Silent fail for admin comment
    }
  }

  Future<void> _onUpdateAdminNote(
    UpdateAdminNote event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      final result = await feedbackRepository.updateAdminNote(
        feedbackId: event.feedbackId,
        adminNote: event.adminNote,
      );
      result.fold(
        (failure) {
          final currentState = state;
          if (currentState is FeedbackLoaded) {
            emit(FeedbackLoaded(
              feedbacks: currentState.feedbacks,
              detail: currentState.detail,
              stats: currentState.stats,
              operationError: failure.message,
            ));
          }
        },
        (_) {
          final currentState = state;
          if (currentState is FeedbackLoaded) {
            emit(FeedbackLoaded(
              feedbacks: currentState.feedbacks,
              detail: currentState.detail,
              stats: currentState.stats,
              operationSuccess: '메모가 저장되었습니다',
            ));
          }
        },
      );
    } catch (e) {
      // Silent fail for note update
    }
  }

  Future<void> _onLoadFeedbackStats(
    LoadFeedbackStats event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      final result = await feedbackRepository.getFeedbackStats();
      result.fold(
        (failure) {
          // Don't overwrite feedbacks on stats failure
        },
        (stats) {
          final currentState = state;
          if (currentState is FeedbackLoaded) {
            emit(FeedbackLoaded(
              feedbacks: currentState.feedbacks,
              detail: currentState.detail,
              stats: stats,
            ));
          }
        },
      );
    } catch (e) {
      // Silent fail for stats
    }
  }

  Future<void> _onLoadPublicFeedbacks(
    LoadPublicFeedbacks event,
    Emitter<FeedbackState> emit,
  ) async {
    try {
      final currentState = state;
      // If loading more pages, keep existing data visible
      if (event.page > 0 && currentState is PublicFeedbacksLoaded) {
        emit(PublicFeedbacksLoaded(
          feedbacks: currentState.feedbacks,
          totalElements: currentState.totalElements,
          totalPages: currentState.totalPages,
          currentPage: currentState.currentPage,
          currentSort: event.sort,
          filterCategory: event.category,
          filterStatus: event.status,
          isLoadingMore: true,
        ));
      } else {
        emit(const PublicFeedbacksLoading());
      }

      final result = await feedbackRepository.getPublicFeedbacks(
        sort: event.sort,
        category: event.category,
        status: event.status,
        page: event.page,
      );

      result.fold(
        (failure) => emit(FeedbackError(failure.message)),
        (data) {
          final (items, totalElements, totalPages) = data;
          // Append items for pagination
          final existingItems = (event.page > 0 && currentState is PublicFeedbacksLoaded)
              ? currentState.feedbacks
              : <dynamic>[];
          final allItems = [...existingItems, ...items];
          emit(PublicFeedbacksLoaded(
            feedbacks: allItems.cast(),
            totalElements: totalElements,
            totalPages: totalPages,
            currentPage: event.page,
            currentSort: event.sort,
            filterCategory: event.category,
            filterStatus: event.status,
          ));
        },
      );
    } catch (e) {
      emit(const FeedbackError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onToggleVote(
    ToggleVote event,
    Emitter<FeedbackState> emit,
  ) async {
    final currentState = state;
    if (currentState is! PublicFeedbacksLoaded) return;

    // Optimistic update: toggle immediately
    final updatedFeedbacks = currentState.feedbacks.map((fb) {
      if (fb.id == event.feedbackId) {
        return fb.copyWith(
          hasVoted: !fb.hasVoted,
          voteCount: fb.hasVoted ? fb.voteCount - 1 : fb.voteCount + 1,
        );
      }
      return fb;
    }).toList();

    emit(PublicFeedbacksLoaded(
      feedbacks: updatedFeedbacks,
      totalElements: currentState.totalElements,
      totalPages: currentState.totalPages,
      currentPage: currentState.currentPage,
      currentSort: currentState.currentSort,
      filterCategory: currentState.filterCategory,
      filterStatus: currentState.filterStatus,
    ));

    // Call server
    try {
      final result = await feedbackRepository.toggleVote(event.feedbackId);
      result.fold(
        (failure) {
          // Revert on error
          emit(PublicFeedbacksLoaded(
            feedbacks: currentState.feedbacks,
            totalElements: currentState.totalElements,
            totalPages: currentState.totalPages,
            currentPage: currentState.currentPage,
            currentSort: currentState.currentSort,
            filterCategory: currentState.filterCategory,
            filterStatus: currentState.filterStatus,
            operationError: failure.message,
          ));
        },
        (voteResponse) {
          // Update with actual server values
          final serverUpdated = updatedFeedbacks.map((fb) {
            if (fb.id == event.feedbackId) {
              return fb.copyWith(
                hasVoted: voteResponse.voted,
                voteCount: voteResponse.voteCount,
              );
            }
            return fb;
          }).toList();

          emit(PublicFeedbacksLoaded(
            feedbacks: serverUpdated,
            totalElements: currentState.totalElements,
            totalPages: currentState.totalPages,
            currentPage: currentState.currentPage,
            currentSort: currentState.currentSort,
            filterCategory: currentState.filterCategory,
            filterStatus: currentState.filterStatus,
          ));
        },
      );
    } catch (e) {
      // Revert on exception
      emit(PublicFeedbacksLoaded(
        feedbacks: currentState.feedbacks,
        totalElements: currentState.totalElements,
        totalPages: currentState.totalPages,
        currentPage: currentState.currentPage,
        currentSort: currentState.currentSort,
        filterCategory: currentState.filterCategory,
        filterStatus: currentState.filterStatus,
        operationError: '투표를 처리하지 못했습니다',
      ));
    }
  }
}
