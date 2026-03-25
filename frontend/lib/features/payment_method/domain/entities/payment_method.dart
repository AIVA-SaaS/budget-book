import 'package:equatable/equatable.dart';

class PaymentMethod extends Equatable {
  final String id;
  final String name;
  final String type;
  final int? settlementDay;
  final int? closingDay;
  final bool isActive;
  final bool isDefault;
  final int displayOrder;
  final int? balance;
  final String? linkedBankId;
  final String? linkedBankName;
  final DateTime createdAt;

  const PaymentMethod({
    required this.id,
    required this.name,
    required this.type,
    this.settlementDay,
    this.closingDay,
    required this.isActive,
    required this.isDefault,
    required this.displayOrder,
    this.balance,
    this.linkedBankId,
    this.linkedBankName,
    required this.createdAt,
  });

  bool get isCash => type == 'CASH';
  bool get isDebit => type == 'DEBIT';
  bool get isCredit => type == 'CREDIT';
  bool get isBank => type == 'BANK';

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        settlementDay,
        closingDay,
        isActive,
        isDefault,
        displayOrder,
        balance,
        linkedBankId,
        linkedBankName,
        createdAt,
      ];
}
