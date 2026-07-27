import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/transfer/domain/entities/transfer.dart';

abstract class TransferRepository {
  /// [reconciled] — V65 정산 필터. 거래 목록(`reconciled` 쿼리)과 **동일한 의미**:
  /// false=미기록만, true=기록만, null=전체. 장부는 거래+이체 병합 뷰이므로 한쪽 스트림만
  /// 필터를 지원하면 "이체만 계속 남아 보이는" drift 가 난다 → 항상 함께 확장한다.
  Future<Either<Failure, List<Transfer>>> getTransfers({
    required int year,
    required int month,
    bool? reconciled,
  });

  Future<Either<Failure, Transfer>> getTransfer(String id);

  Future<Either<Failure, Transfer>> createTransfer({
    required String sourcePaymentMethodId,
    required String destinationPaymentMethodId,
    required int amount,
    String? description,
    required String transferDate,
    String? memo,
    TransferKind kind = TransferKind.generic,
  });

  /// 카드 결제 처리: Transfer 생성(is_card_settlement=true) + 거래 paid_at 일괄 업데이트
  Future<Either<Failure, Transfer>> createCardSettlement({
    required String sourcePaymentMethodId,
    required String destinationPaymentMethodId,
    required int amount,
    required String transferDate,
    String? description,
    required List<String> transactionIds,
  });

  /// 카드 결제(정산) 수정: 기존 링크 거래 unmark + 새 선택 거래 mark 를 BE 가 처리.
  Future<Either<Failure, Transfer>> updateCardSettlement({
    required String transferId,
    required String sourcePaymentMethodId,
    required String destinationPaymentMethodId,
    required int amount,
    required String transferDate,
    String? description,
    required List<String> transactionIds,
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
    TransferKind? kind,
  });

  Future<Either<Failure, void>> deleteTransfer(String id);
}
