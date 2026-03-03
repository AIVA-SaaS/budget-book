import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/couple/domain/entities/couple.dart';
import 'package:budget_book/features/couple/domain/entities/invitation.dart';

abstract class CoupleRepository {
  Future<Either<Failure, Couple>> getMyCouple();
  Future<Either<Failure, Invitation>> createInvitation();
  Future<Either<Failure, Couple>> acceptInvitation(String code);
  Future<Either<Failure, void>> dissolveCouple();
}
