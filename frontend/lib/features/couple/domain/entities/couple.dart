import 'package:equatable/equatable.dart';
import 'package:budget_book/features/couple/domain/entities/user_summary.dart';

class Couple extends Equatable {
  final String id;
  final UserSummary partner;
  final String status;
  final DateTime createdAt;

  const Couple({
    required this.id,
    required this.partner,
    required this.status,
    required this.createdAt,
  });

  bool get isActive => status == 'ACTIVE';

  @override
  List<Object?> get props => [id, partner, status, createdAt];
}
