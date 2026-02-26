import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:budget_book/core/storage/secure_storage.dart';
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
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
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
  }

  Future<void> _onCallbackReceived(
    AuthCallbackReceived event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    await storageService.saveAccessToken(event.accessToken);
    await storageService.saveRefreshToken(event.refreshToken);
    final result = await authRepository.getCurrentUser();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final refreshToken = await storageService.getRefreshToken();
    if (refreshToken != null) {
      await authRepository.logout(refreshToken);
    }
    await storageService.clearTokens();
    emit(const AuthUnauthenticated());
  }

  Future<void> _onTokenRefreshRequested(
    AuthTokenRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    final refreshToken = await storageService.getRefreshToken();
    if (refreshToken == null) {
      emit(const AuthUnauthenticated());
      return;
    }
    final result = await authRepository.refreshToken(refreshToken);
    await result.fold(
      (failure) async {
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
  }
}
