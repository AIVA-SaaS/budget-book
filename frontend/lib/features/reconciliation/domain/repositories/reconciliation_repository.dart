import 'package:dartz/dartz.dart';

import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/reconciliation/domain/entities/reconciliation.dart';

abstract class ReconciliationRepository {
  Future<Either<Failure, List<Reconciliation>>> getReconciliations({
    required int year,
    required int month,
  });

  Future<Either<Failure, ReconciliationDetail>> getReconciliation(String id);

  Future<Either<Failure, ReconciliationDetail>> createReconciliation({
    required String yearMonth,
    String? label,
    List<String> transactionIds,
    List<String> transferIds,
  });

  Future<Either<Failure, ReconciliationDetail>> updateReconciliation({
    required String id,
    String? label,
    List<String> addTransactionIds,
    List<String> addTransferIds,
    List<String> removeItemIds,
  });

  Future<Either<Failure, void>> deleteReconciliation(String id);

  Future<Either<Failure, ReconciliationSummary>> getSummary({
    required int year,
    required int month,
  });
}
