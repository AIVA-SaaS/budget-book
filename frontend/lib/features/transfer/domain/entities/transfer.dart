import 'package:equatable/equatable.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';

/// Transfer kind — classifies how a transfer affects aggregations.
///
/// - [cardSettlement]: BANK → CREDIT. The original EXPENSE transaction is
///   already counted in expense totals, so this transfer is excluded from
///   income/expense/transfer aggregates.
/// - [expenseTransfer]: transfer recorded as expense. Source amount counts
///   toward totalExpense. No income side-effect.
/// - [incomeTransfer]: transfer recorded as income. Destination amount counts
///   toward totalIncome. No expense side-effect.
/// - [generic]: pure internal move (bank→bank, cash↔bank). Excluded from
///   income/expense; counted only in totalTransfer.
enum TransferKind {
  cardSettlement('CARD_SETTLEMENT'),
  expenseTransfer('EXPENSE_TRANSFER'),
  incomeTransfer('INCOME_TRANSFER'),
  generic('GENERIC');

  final String wire;
  const TransferKind(this.wire);

  /// Parse wire name to enum with safe fallback to [generic].
  static TransferKind fromWire(String? wire) {
    if (wire == null) return TransferKind.generic;
    for (final k in TransferKind.values) {
      if (k.wire == wire) return k;
    }
    return TransferKind.generic;
  }
}

class PaymentMethodRef extends Equatable {
  final String id;
  final String name;
  final String type;

  const PaymentMethodRef({
    required this.id,
    required this.name,
    required this.type,
  });

  @override
  List<Object?> get props => [id, name, type];
}

class Transfer extends Equatable {
  final String id;
  final String coupleId;
  final TransactionAuthor author;
  final PaymentMethodRef sourcePaymentMethod;
  final PaymentMethodRef destinationPaymentMethod;
  final int amount;
  final String? description;
  final String? memo;
  final String transferDate;
  final DateTime createdAt;
  final TransferKind kind;

  /// V65 (2026-07-27) — 이 이체가 담긴 정산 스냅샷. 미기록이면 전부 null.
  /// Transaction 과 **같은 3필드** (두 스트림 병합 뷰에서 배지 동작을 일치시킨다).
  final String? reconciliationId;
  final int? reconciliationSeq;
  final DateTime? reconciledAt;

  const Transfer({
    required this.id,
    required this.coupleId,
    required this.author,
    required this.sourcePaymentMethod,
    required this.destinationPaymentMethod,
    required this.amount,
    this.description,
    this.memo,
    required this.transferDate,
    required this.createdAt,
    this.kind = TransferKind.generic,
    this.reconciliationId,
    this.reconciliationSeq,
    this.reconciledAt,
  });

  /// Legacy boolean — derived from [kind]. Keep until BE drops the column.
  bool get isCardSettlement => kind == TransferKind.cardSettlement;

  /// 정산 스냅샷에 기록된 이체인지 (배지 표시 조건).
  bool get isReconciled => reconciliationId != null;

  @override
  List<Object?> get props => [
        id,
        coupleId,
        author,
        sourcePaymentMethod,
        destinationPaymentMethod,
        amount,
        description,
        memo,
        transferDate,
        createdAt,
        kind,
        reconciliationId,
        reconciliationSeq,
        reconciledAt,
      ];
}
