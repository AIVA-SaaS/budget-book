import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';
import 'package:budget_book/features/payment_method/domain/entities/card_pending.dart';

abstract class PaymentMethodRepository {
  Future<Either<Failure, List<PaymentMethod>>> getPaymentMethods();
  Future<Either<Failure, PaymentMethod>> createPaymentMethod({
    required String name,
    required String type,
    int? settlementDay,
    int? closingDay,
  });
  Future<Either<Failure, PaymentMethod>> updatePaymentMethod({
    required String id,
    String? name,
    int? settlementDay,
    int? closingDay,
    bool? isActive,
    int? displayOrder,
  });
  Future<Either<Failure, void>> deletePaymentMethod(String id);
  Future<Either<Failure, List<CardPending>>> getCardPending(
      int year, int month);
}
