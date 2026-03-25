import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

abstract class TransferRepository {
  Future<Either<Failure, List<Transfer>>> getTransfers({
    required int year,
    required int month,
  });

  Future<Either<Failure, Transfer>> getTransfer(String id);

  Future<Either<Failure, Transfer>> createTransfer({
    required String sourcePaymentMethodId,
    required String destinationPaymentMethodId,
    required int amount,
    String? description,
    required String transferDate,
    String? memo,
  });

  Future<Either<Failure, Transfer>> updateTransfer({
    required String id,
    String? sourcePaymentMethodId,
    String? destinationPaymentMethodId,
    int? amount,
    String? description,
    bool clearDescription = false,
    String? transferDate,
    String? memo,
    bool clearMemo = false,
  });

  Future<Either<Failure, void>> deleteTransfer(String id);
}
