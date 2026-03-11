import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/recurring/domain/entities/recurring_transaction.dart';

abstract class RecurringRepository {
  Future<Either<Failure, List<RecurringTransaction>>>
      getRecurringTransactions();
  Future<Either<Failure, RecurringTransaction>> createRecurringTransaction({
    required String type,
    required int amount,
    required String description,
    String? memo,
    required String frequency,
    int? dayOfMonth,
    int? dayOfWeek,
    String? categoryId,
    String? paymentMethodId,
  });
  Future<Either<Failure, RecurringTransaction>> updateRecurringTransaction({
    required String id,
    int? amount,
    String? description,
    String? memo,
    String? categoryId,
    String? paymentMethodId,
    int? dayOfMonth,
    int? dayOfWeek,
    bool? isActive,
  });
  Future<Either<Failure, void>> deleteRecurringTransaction(String id);
}
