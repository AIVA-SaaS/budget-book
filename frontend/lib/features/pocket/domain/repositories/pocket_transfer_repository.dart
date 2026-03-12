import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/pocket/domain/entities/pocket_transfer.dart';

abstract class PocketTransferRepository {
  Future<Either<Failure, List<PocketTransfer>>> getPocketTransfers({
    String? fromPocketId,
    String? toPocketId,
    String? startDate,
    String? endDate,
  });
  Future<Either<Failure, PocketTransfer>> createPocketTransfer({
    required String fromPocketId,
    required String toPocketId,
    required int amount,
    String? description,
    required String transferDate,
  });
}
