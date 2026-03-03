import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';

class TransactionAuthorModel extends TransactionAuthor {
  const TransactionAuthorModel({
    required super.id,
    required super.nickname,
    super.profileImageUrl,
  });

  factory TransactionAuthorModel.fromJson(Map<String, dynamic> json) {
    return TransactionAuthorModel(
      id: json['id'] as String,
      nickname: json['nickname'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
    );
  }
}
