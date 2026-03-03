import 'package:budget_book/features/couple/domain/entities/user_summary.dart';

class UserSummaryModel extends UserSummary {
  const UserSummaryModel({
    required super.id,
    required super.nickname,
    super.profileImageUrl,
  });

  factory UserSummaryModel.fromJson(Map<String, dynamic> json) {
    return UserSummaryModel(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}
