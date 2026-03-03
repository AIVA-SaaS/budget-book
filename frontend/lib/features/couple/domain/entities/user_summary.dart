import 'package:equatable/equatable.dart';

class UserSummary extends Equatable {
  final String id;
  final String nickname;
  final String? profileImageUrl;

  const UserSummary({
    required this.id,
    required this.nickname,
    this.profileImageUrl,
  });

  @override
  List<Object?> get props => [id, nickname, profileImageUrl];
}
