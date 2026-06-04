import 'package:equatable/equatable.dart';
import 'package:budget_book/core/utils/email_policy.dart';

class User extends Equatable {
  final String id;
  final String email;
  final String nickname;
  final String? profileImageUrl;
  final String provider;
  final String role;
  final String? coupleId;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    required this.nickname,
    this.profileImageUrl,
    required this.provider,
    required this.role,
    this.coupleId,
    required this.createdAt,
  });

  /// Returns true when this user has a verified, non-placeholder email.
  bool get hasRegisteredEmail => !isPlaceholderEmail(email);

  @override
  List<Object?> get props => [
        id,
        email,
        nickname,
        profileImageUrl,
        provider,
        role,
        coupleId,
        createdAt,
      ];
}
