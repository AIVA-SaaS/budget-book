import 'package:budget_book/features/payment_method/domain/entities/payment_method.dart';

class PaymentMethodModel extends PaymentMethod {
  const PaymentMethodModel({
    required super.id,
    required super.name,
    required super.type,
    super.settlementDay,
    super.closingDay,
    required super.isActive,
    required super.isDefault,
    required super.displayOrder,
    super.balance,
    super.linkedBankId,
    super.linkedBankName,
    required super.createdAt,
  });

  factory PaymentMethodModel.fromJson(Map<String, dynamic> json) {
    return PaymentMethodModel(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      settlementDay: json['settlementDay'] as int?,
      closingDay: json['closingDay'] as int?,
      isActive: json['isActive'] as bool,
      isDefault: json['isDefault'] as bool? ?? false,
      displayOrder: json['displayOrder'] as int,
      balance: json['balance'] as int?,
      linkedBankId: json['linkedBankId'] as String?,
      linkedBankName: json['linkedBankName'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
