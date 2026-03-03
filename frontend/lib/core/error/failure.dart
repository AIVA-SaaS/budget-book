import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  final String? code;
  final int? statusCode;

  const ServerFailure([
    super.message = 'Server error occurred',
    this.code,
    this.statusCode,
  ]);

  @override
  List<Object> get props => [
        message,
        if (code != null) code!,
        if (statusCode != null) statusCode!,
      ];
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache error occurred']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error occurred']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}
