import 'package:equatable/equatable.dart';

class Insurance extends Equatable {
  final String id;
  final String coupleId;
  final String userId;
  final String name;
  final String? insurer;
  final String insuranceType;
  final int premiumAmount;
  final int? paymentDay;
  final String paymentCycle;
  final String? paymentMethodId;
  final String? categoryId;
  final String? startDate;
  final String? endDate;
  final String? memo;
  final bool isActive;
  final String visibility;
  final String? ownerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Insurance({
    required this.id,
    required this.coupleId,
    required this.userId,
    required this.name,
    this.insurer,
    required this.insuranceType,
    required this.premiumAmount,
    this.paymentDay,
    required this.paymentCycle,
    this.paymentMethodId,
    this.categoryId,
    this.startDate,
    this.endDate,
    this.memo,
    required this.isActive,
    required this.visibility,
    this.ownerId,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        id,
        coupleId,
        userId,
        name,
        insurer,
        insuranceType,
        premiumAmount,
        paymentDay,
        paymentCycle,
        paymentMethodId,
        categoryId,
        startDate,
        endDate,
        memo,
        isActive,
        visibility,
        ownerId,
        createdAt,
        updatedAt,
      ];
}

class InsuranceSummaryItem extends Equatable {
  final String id;
  final String name;
  final String insuranceType;
  final int premiumAmount;
  final String paymentCycle;
  final int? paymentDay;
  final bool isActive;

  const InsuranceSummaryItem({
    required this.id,
    required this.name,
    required this.insuranceType,
    required this.premiumAmount,
    required this.paymentCycle,
    this.paymentDay,
    required this.isActive,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        insuranceType,
        premiumAmount,
        paymentCycle,
        paymentDay,
        isActive,
      ];
}

class InsuranceSummary extends Equatable {
  final int year;
  final int month;
  final int totalPremium;
  final int activeCount;
  final List<InsuranceSummaryItem> items;

  const InsuranceSummary({
    required this.year,
    required this.month,
    required this.totalPremium,
    required this.activeCount,
    required this.items,
  });

  @override
  List<Object?> get props => [year, month, totalPremium, activeCount, items];
}
