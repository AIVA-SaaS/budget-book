import 'package:budget_book/features/insurance/domain/entities/insurance.dart';

class InsuranceModel extends Insurance {
  const InsuranceModel({
    required super.id,
    required super.coupleId,
    required super.userId,
    required super.name,
    super.insurer,
    required super.insuranceType,
    required super.premiumAmount,
    super.paymentDay,
    required super.paymentCycle,
    super.paymentMethodId,
    super.categoryId,
    super.startDate,
    super.endDate,
    super.memo,
    required super.isActive,
    required super.visibility,
    super.ownerId,
    required super.createdAt,
    required super.updatedAt,
  });

  factory InsuranceModel.fromJson(Map<String, dynamic> json) {
    return InsuranceModel(
      id: json['id'] as String,
      coupleId: json['coupleId'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      insurer: json['insurer'] as String?,
      insuranceType: json['insuranceType'] as String,
      premiumAmount: json['premiumAmount'] as int,
      paymentDay: json['paymentDay'] as int?,
      paymentCycle: json['paymentCycle'] as String,
      paymentMethodId: json['paymentMethodId'] as String?,
      categoryId: json['categoryId'] as String?,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      memo: json['memo'] as String?,
      isActive: json['isActive'] as bool,
      visibility: json['visibility'] as String,
      ownerId: json['ownerId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class InsuranceSummaryItemModel extends InsuranceSummaryItem {
  const InsuranceSummaryItemModel({
    required super.id,
    required super.name,
    required super.insuranceType,
    required super.premiumAmount,
    required super.paymentCycle,
    super.paymentDay,
    required super.isActive,
  });

  factory InsuranceSummaryItemModel.fromJson(Map<String, dynamic> json) {
    return InsuranceSummaryItemModel(
      id: json['id'] as String,
      name: json['name'] as String,
      insuranceType: json['insuranceType'] as String,
      premiumAmount: json['premiumAmount'] as int,
      paymentCycle: json['paymentCycle'] as String,
      paymentDay: json['paymentDay'] as int?,
      isActive: json['isActive'] as bool,
    );
  }
}

class InsuranceSummaryModel extends InsuranceSummary {
  const InsuranceSummaryModel({
    required super.year,
    required super.month,
    required super.totalPremium,
    required super.activeCount,
    required super.items,
  });

  factory InsuranceSummaryModel.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>;
    return InsuranceSummaryModel(
      year: json['year'] as int,
      month: json['month'] as int,
      totalPremium: json['totalPremium'] as int,
      activeCount: json['activeCount'] as int,
      items: itemsJson
          .map((e) =>
              InsuranceSummaryItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
