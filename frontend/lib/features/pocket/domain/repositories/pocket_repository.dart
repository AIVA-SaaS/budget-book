import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';
import 'package:budget_book/features/pocket/domain/entities/distribute_result.dart';

abstract class PocketRepository {
  Future<Either<Failure, List<MoneyPocket>>> getPockets();
  Future<Either<Failure, MoneyPocket>> createPocket({
    required String name,
    required String type,
    required int allocatedAmount,
    String? icon,
    String? color,
    int? goalAmount,
    String? targetDate,
  });
  Future<Either<Failure, MoneyPocket>> updatePocket({
    required String id,
    String? name,
    String? type,
    int? allocatedAmount,
    String? icon,
    String? color,
    int? displayOrder,
    int? goalAmount,
    String? targetDate,
  });
  Future<Either<Failure, void>> deletePocket(String id);
  Future<Either<Failure, DistributeResult>> distributeIncome({
    required int totalAmount,
    required List<Map<String, dynamic>> distributions,
  });
  Future<Either<Failure, List<Map<String, dynamic>>>> getDistributionRatios();
  Future<Either<Failure, void>> saveDistributionRatios(
      List<Map<String, dynamic>> ratios);
}
