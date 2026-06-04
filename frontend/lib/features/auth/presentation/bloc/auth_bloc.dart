import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/storage/secure_storage.dart';
import 'package:budget_book/core/utils/error_reporter.dart';
import 'package:budget_book/features/auth/domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final SecureStorageService storageService;

  AuthBloc({
    required this.authRepository,
    required this.storageService,
  }) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthCallbackReceived>(_onCallbackReceived);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthTokenRefreshRequested>(_onTokenRefreshRequested);
    on<AuthRefreshUser>(_onRefreshUser);
    on<AuthSessionExpired>(_onSessionExpired);
    on<UpdateProfile>(_onUpdateProfile);
    on<UploadProfileImage>(_onUploadProfileImage);
    on<DeleteProfileImage>(_onDeleteProfileImage);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final token = await storageService.getAccessToken();
      if (token == null) {
        emit(const AuthUnauthenticated());
        return;
      }
      final result = await authRepository.getCurrentUser();
      result.fold(
        (failure) {
          // Try refresh before giving up
          add(const AuthTokenRefreshRequested());
        },
        (user) => emit(AuthAuthenticated(user)),
      );
    } catch (e) {
      emit(const AuthError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onCallbackReceived(
    AuthCallbackReceived event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      await storageService.saveAccessToken(event.accessToken);
      await storageService.saveRefreshToken(event.refreshToken);
      final result = await authRepository.getCurrentUser();
      result.fold(
        (failure) {
          ErrorReporter.captureException(
            failure,
            context: 'auth:callback_user_fetch',
          );
          emit(AuthError(failure.message));
        },
        (user) => emit(AuthAuthenticated(user)),
      );
    } catch (e) {
      emit(const AuthError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final refreshToken = await storageService.getRefreshToken();
      if (refreshToken != null) {
        await authRepository.logout(refreshToken);
      }
      await storageService.clearTokens();
      emit(const AuthUnauthenticated());
    } catch (e) {
      // Even on error, clear tokens and log out
      await storageService.clearTokens();
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onRefreshUser(
    AuthRefreshUser event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final result = await authRepository.getCurrentUser();
      result.fold(
        (failure) {
          // Re-emit current state so BlocListeners waiting for refresh still fire
          if (state is AuthAuthenticated) {
            emit(AuthAuthenticated((state as AuthAuthenticated).user));
          }
        },
        (user) => emit(AuthAuthenticated(user)),
      );
    } catch (e) {
      // Keep current state on unexpected error
      if (state is AuthAuthenticated) {
        emit(AuthAuthenticated((state as AuthAuthenticated).user));
      }
    }
  }

  Future<void> _onSessionExpired(
    AuthSessionExpired event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await storageService.clearTokens();
      emit(const AuthUnauthenticated(
        message: '세션이 만료되었습니다. 다시 로그인해주세요.',
      ));
    } catch (e) {
      emit(const AuthUnauthenticated(
        message: '세션이 만료되었습니다. 다시 로그인해주세요.',
      ));
    }
  }

  Future<void> _onUpdateProfile(
    UpdateProfile event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final result = await authRepository.updateProfile(
        nickname: event.nickname,
        email: event.email,
        profileImageUrl: event.profileImageUrl,
        clearProfileImage: event.clearProfileImage,
      );
      result.fold(
        (failure) => emit(AuthError(
          failure.message,
          errorCode: failure is ServerFailure ? failure.code : null,
        )),
        (user) => emit(AuthAuthenticated(user)),
      );
    } catch (e) {
      emit(const AuthError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onUploadProfileImage(
    UploadProfileImage event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final result = await authRepository.uploadProfileImage(
        event.imageBytes,
        event.fileName,
      );
      result.fold(
        (failure) => emit(AuthError(failure.message)),
        (user) => emit(AuthAuthenticated(user)),
      );
    } catch (e) {
      emit(const AuthError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onDeleteProfileImage(
    DeleteProfileImage event,
    Emitter<AuthState> emit,
  ) async {
    try {
      emit(const AuthLoading());
      final result = await authRepository.deleteProfileImage();
      result.fold(
        (failure) => emit(AuthError(failure.message)),
        (_) async {
          // Refresh user data to get updated profile
          final userResult = await authRepository.getCurrentUser();
          userResult.fold(
            (failure) => emit(AuthError(failure.message)),
            (user) => emit(AuthAuthenticated(user)),
          );
        },
      );
    } catch (e) {
      emit(const AuthError('예기치 않은 오류가 발생했습니다'));
    }
  }

  Future<void> _onTokenRefreshRequested(
    AuthTokenRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final refreshToken = await storageService.getRefreshToken();
      if (refreshToken == null) {
        emit(const AuthUnauthenticated());
        return;
      }
      final result = await authRepository.refreshToken(refreshToken);
      await result.fold(
        (failure) async {
          ErrorReporter.captureException(
            failure,
            context: 'auth:token_refresh',
          );
          await storageService.clearTokens();
          emit(const AuthUnauthenticated());
        },
        (token) async {
          await storageService.saveAccessToken(token.accessToken);
          await storageService.saveRefreshToken(token.refreshToken);
          final userResult = await authRepository.getCurrentUser();
          userResult.fold(
            (failure) => emit(AuthError(failure.message)),
            (user) => emit(AuthAuthenticated(user)),
          );
        },
      );
    } catch (e) {
      await storageService.clearTokens();
      emit(const AuthUnauthenticated());
    }
  }
}
