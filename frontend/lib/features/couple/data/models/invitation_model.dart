import 'package:budget_book/features/couple/domain/entities/invitation.dart';

class InvitationModel extends Invitation {
  const InvitationModel({
    required super.code,
    required super.expiresAt,
  });

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      code: json['code'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}
