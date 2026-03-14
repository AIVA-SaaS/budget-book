import 'package:budget_book/features/pocket/domain/entities/money_pocket.dart';

class PocketModel extends MoneyPocket {
  const PocketModel({
    required super.id,
    required super.name,
    required super.type,
    required super.allocatedAmount,
    required super.balance,
    super.icon,
    super.color,
    required super.displayOrder,
    required super.isActive,
    super.goalAmount,
    super.targetDate,
  });

  factory PocketModel.fromJson(Map<String, dynamic> json) {
    return PocketModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      allocatedAmount: json['allocatedAmount'] as int,
      balance: json['balance'] as int,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      displayOrder: json['displayOrder'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      goalAmount: json['goalAmount'] as int?,
      targetDate: json['targetDate'] as String?,
    );
  }
}
