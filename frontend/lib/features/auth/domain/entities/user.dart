import 'package:equatable/equatable.dart';

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
