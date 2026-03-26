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
  final int? goalAmount;
  final String? targetDate;
  final String visibility;
  final String? ownerId;

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
    this.goalAmount,
    this.targetDate,
    this.visibility = 'SHARED',
    this.ownerId,
  });

  bool get isLiving => type == 'LIVING';
  bool get isFixed => type == 'FIXED';
  bool get isCardPending => type == 'CARD_PENDING';
  bool get isSavings => type == 'SAVINGS';
  bool get isCustom => type == 'CUSTOM';
  bool get isPrivate => visibility == 'PRIVATE';
  bool get isShared => visibility == 'SHARED';

  /// Returns goal progress as a ratio (0.0 to 1.0+), or null if no goal set.
  double? get goalProgress {
    if (goalAmount == null || goalAmount! <= 0) return null;
    return balance / goalAmount!;
  }

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
        goalAmount,
        targetDate,
        visibility,
        ownerId,
      ];
}
