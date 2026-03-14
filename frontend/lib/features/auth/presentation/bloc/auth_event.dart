import 'package:equatable/equatable.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

class AuthCallbackReceived extends AuthEvent {
  final String accessToken;
  final String refreshToken;

  const AuthCallbackReceived({
    required this.accessToken,
    required this.refreshToken,
  });

  @override
  List<Object?> get props => [accessToken, refreshToken];
}

class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

class AuthTokenRefreshRequested extends AuthEvent {
  const AuthTokenRefreshRequested();
}

class AuthRefreshUser extends AuthEvent {
  const AuthRefreshUser();
}

/// Fired by AuthInterceptor when token refresh fails.
/// Clears tokens and transitions to unauthenticated state.
class AuthSessionExpired extends AuthEvent {
  const AuthSessionExpired();
}

/// Updates the current user's profile (nickname, profile image).
class UpdateProfile extends AuthEvent {
  final String? nickname;
  final String? profileImageUrl;
  final bool clearProfileImage;

  const UpdateProfile({
    this.nickname,
    this.profileImageUrl,
    this.clearProfileImage = false,
  });

  @override
  List<Object?> get props => [nickname, profileImageUrl, clearProfileImage];
}
