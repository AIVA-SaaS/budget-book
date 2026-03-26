import 'package:equatable/equatable.dart';

class Invitation extends Equatable {
  final String code;
  final DateTime expiresAt;
  final String? status;

  const Invitation({
    required this.code,
    required this.expiresAt,
    this.status,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [code, expiresAt, status];
}
