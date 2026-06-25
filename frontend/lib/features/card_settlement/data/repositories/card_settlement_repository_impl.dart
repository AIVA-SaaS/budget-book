import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/core/error/dio_error_mapper.dart';
import 'package:budget_book/features/card_settlement/data/datasources/card_settlement_remote_datasource.dart';
import 'package:budget_book/features/card_settlement/domain/entities/settlement_transaction.dart';
import 'package:budget_book/features/card_settlement/domain/repositories/card_settlement_repository.dart';

class CardSettlementRepositoryImpl implements CardSettlementRepository {
  final CardSettlementRemoteDataSource remoteDataSource;

  CardSettlementRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, SettlementTransactionsResponse>>
      getSettlementTransactions({
    required String paymentMethodId,
    required int year,
    required int month,
    String? settlementTransferId,
  }) async {
    try {
      final result = await remoteDataSource.getSettlementTransactions(
        paymentMethodId: paymentMethodId,
        year: year,
        month: month,
        settlementTransferId: settlementTransferId,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(mapDioError(e, '결제 대상 거래를 불러오지 못했습니다'));
    } catch (e) {
      return const Left(ServerFailure('결제 대상 거래를 불러오지 못했습니다'));
    }
  }
}
