import 'package:equatable/equatable.dart';
import 'package:budget_book/features/couple/domain/entities/user_summary.dart';

class Couple extends Equatable {
  final String id;
  final UserSummary? partner;
  final String status;
  final DateTime createdAt;

  const Couple({
    required this.id,
    this.partner,
    required this.status,
    required this.createdAt,
  });

  bool get isActive => status == 'ACTIVE';

  /// True when the couple has a real partner (not a self-couple).
  bool get isCouple => partner != null;

  @override
  List<Object?> get props => [id, partner, status, createdAt];
}
