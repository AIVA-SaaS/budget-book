import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/card_settlement/domain/entities/settlement_transaction.dart';

abstract class CardSettlementRepository {
  Future<Either<Failure, SettlementTransactionsResponse>>
      getSettlementTransactions({
    required String paymentMethodId,
    required int year,
    required int month,
    String? settlementTransferId,
  });
}
