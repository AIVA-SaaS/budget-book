import 'package:budget_book/features/pocket/domain/entities/pocket_transfer.dart';

class PocketTransferModel extends PocketTransfer {
  const PocketTransferModel({
    required super.id,
    required super.fromPocket,
    required super.toPocket,
    required super.amount,
    super.description,
    required super.transferDate,
    required super.authorId,
  });

  factory PocketTransferModel.fromJson(Map<String, dynamic> json) {
    return PocketTransferModel(
      id: json['id'] as String,
      fromPocket: PocketRefModel.fromJson(
          json['fromPocket'] as Map<String, dynamic>),
      toPocket: PocketRefModel.fromJson(
          json['toPocket'] as Map<String, dynamic>),
      amount: json['amount'] as int,
      description: json['description'] as String?,
      transferDate: json['transferDate'] as String,
      authorId: json['authorId'] as String,
    );
  }
}

class PocketRefModel extends PocketRef {
  const PocketRefModel({required super.id, required super.name});

  factory PocketRefModel.fromJson(Map<String, dynamic> json) {
    return PocketRefModel(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }
}
