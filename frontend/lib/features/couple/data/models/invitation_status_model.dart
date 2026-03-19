import 'package:budget_book/features/couple/domain/entities/invitation.dart';

class InvitationStatusModel extends Invitation {
  const InvitationStatusModel({
    required super.code,
    required super.expiresAt,
    required super.status,
  });

  factory InvitationStatusModel.fromJson(Map<String, dynamic> json) {
    return InvitationStatusModel(
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      status: json['status'] as String,
    );
  }
}
