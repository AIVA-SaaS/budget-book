import 'package:budget_book/features/couple/domain/entities/couple.dart';
import 'package:budget_book/features/couple/data/models/user_summary_model.dart';

class CoupleModel extends Couple {
  const CoupleModel({
    required super.id,
    required super.partner,
    required super.status,
    required super.createdAt,
  });

  factory CoupleModel.fromJson(Map<String, dynamic> json) {
    return CoupleModel(
      id: json['id'] as String,
      partner: UserSummaryModel.fromJson(
        json['partner'] as Map<String, dynamic>,
      ),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
