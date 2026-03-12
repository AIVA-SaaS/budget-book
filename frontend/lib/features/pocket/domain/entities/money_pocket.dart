import 'package:equatable/equatable.dart';

class MoneyPocket extends Equatable {
  final String id;
  final String name;
  final String type;
  final int allocatedAmount;
  final int balance;
  final String? icon;
  final String? color;
  final int displayOrder;
  final bool isActive;

  const MoneyPocket({
    required this.id,
    required this.name,
    required this.type,
    required this.allocatedAmount,
    required this.balance,
    this.icon,
    this.color,
    required this.displayOrder,
    required this.isActive,
  });

  bool get isLiving => type == 'LIVING';
  bool get isFixed => type == 'FIXED';
  bool get isCardPending => type == 'CARD_PENDING';
  bool get isSavings => type == 'SAVINGS';
  bool get isCustom => type == 'CUSTOM';

  @override
  List<Object?> get props => [
        id,
        name,
        type,
        allocatedAmount,
        balance,
        icon,
        color,
        displayOrder,
        isActive,
      ];
}
