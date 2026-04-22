import 'package:budget_book/features/transfer/domain/entities/transfer.dart';
import 'package:budget_book/features/transaction/data/models/transaction_author_model.dart';

class PaymentMethodRefModel extends PaymentMethodRef {
  const PaymentMethodRefModel({
    required super.id,
    required super.name,
    required super.type,
  });

  factory PaymentMethodRefModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodRefModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
    );
  }
}

class TransferModel extends Transfer {
  const TransferModel({
    required super.id,
    required super.coupleId,
    required super.author,
    required super.sourcePaymentMethod,
    required super.destinationPaymentMethod,
    required super.amount,
    super.description,
    super.memo,
    required super.transferDate,
    required super.createdAt,
    super.kind,
  });

  factory TransferModel.fromJson(Map<String, dynamic> json) {
    // BE contract (PR-B): TransferResponse has `kind` field with values
    // CARD_SETTLEMENT | EXPENSE_TRANSFER | INCOME_TRANSFER | GENERIC.
    // For backward compatibility, fall back to legacy `isCardSettlement`.
    final rawKind = json['kind'] as String?;
    final legacySettlement = json['isCardSettlement'] as bool? ?? false;
    final TransferKind kind = rawKind != null
        ? TransferKind.fromWire(rawKind)
        : (legacySettlement
            ? TransferKind.cardSettlement
            : TransferKind.generic);
    return TransferModel(
      id: json['id'] as String,
      coupleId: json['coupleId'] as String,
      author: TransactionAuthorModel.fromJson(
          json['author'] as Map<String, dynamic>),
      sourcePaymentMethod: PaymentMethodRefModel.fromJson(
          json['sourcePaymentMethod'] as Map<String, dynamic>),
      destinationPaymentMethod: PaymentMethodRefModel.fromJson(
          json['destinationPaymentMethod'] as Map<String, dynamic>),
      amount: json['amount'] as int,
      description: json['description'] as String?,
      memo: json['memo'] as String?,
      transferDate: json['transferDate'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      kind: kind,
    );
  }
}
