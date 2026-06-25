import 'package:equatable/equatable.dart';

class SettlementTransactionsResponse extends Equatable {
  final int totalAmount;
  final int transactionCount;
  final List<SettlementTransaction> transactions;

  const SettlementTransactionsResponse({
    required this.totalAmount,
    required this.transactionCount,
    required this.transactions,
  });

  @override
  List<Object?> get props => [totalAmount, transactionCount, transactions];
}

class SettlementTransaction extends Equatable {
  final String id;
  final String transactionDate;
  final String? settlementDate;
  final String description;
  final int amount;
  final String? categoryName;
  final String? categoryIcon;
  final String type; // TRANSACTION or TRANSFER

  /// 이 거래가 이미 묶여 있는 카드 정산(Transfer)의 ID. 미결제 거래는 null.
  /// 편집 모드에서 "현재 편집 중인 정산에 묶인 거래" 를 식별하는 데 사용.
  final String? settlementTransferId;

  const SettlementTransaction({
    required this.id,
    required this.transactionDate,
    this.settlementDate,
    required this.description,
    required this.amount,
    this.categoryName,
    this.categoryIcon,
    this.type = 'TRANSACTION',
    this.settlementTransferId,
  });

  bool get isTransfer => type == 'TRANSFER';

  @override
  List<Object?> get props => [
        id,
        transactionDate,
        settlementDate,
        description,
        amount,
        categoryName,
        categoryIcon,
        type,
        settlementTransferId,
      ];
}
