import 'package:equatable/equatable.dart';

class Invitation extends Equatable {
  final String code;
  final DateTime expiresAt;

  const Invitation({
    required this.code,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  @override
  List<Object?> get props => [code, expiresAt];
}
