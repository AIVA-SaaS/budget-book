import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/auth/domain/entities/user.dart';
import 'package:budget_book/features/auth/domain/entities/auth_token.dart';

abstract class AuthRepository {
  Future<Either<Failure, AuthToken>> refreshToken(String refreshToken);
  Future<Either<Failure, User>> getCurrentUser();
  Future<Either<Failure, void>> logout(String refreshToken);
}
