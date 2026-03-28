import 'package:equatable/equatable.dart';

sealed class InsuranceEvent extends Equatable {
  const InsuranceEvent();

  @override
  List<Object?> get props => [];
}

class LoadInsurances extends InsuranceEvent {
  final bool? activeOnly;

  const LoadInsurances({this.activeOnly});

  @override
  List<Object?> get props => [activeOnly];
}

class LoadInsuranceSummary extends InsuranceEvent {
  final int year;
  final int month;

  const LoadInsuranceSummary({required this.year, required this.month});

  @override
  List<Object?> get props => [year, month];
}

class CreateInsurance extends InsuranceEvent {
  final String name;
  final String? insurer;
  final String insuranceType;
  final int premiumAmount;
  final int? paymentDay;
  final String? paymentCycle;
  final String? paymentMethodId;
  final String? categoryId;
  final String? startDate;
  final String? endDate;
  final String? memo;
  final String? visibility;

  const CreateInsurance({
    required this.name,
    this.insurer,
    required this.insuranceType,
    required this.premiumAmount,
    this.paymentDay,
    this.paymentCycle,
    this.paymentMethodId,
    this.categoryId,
    this.startDate,
    this.endDate,
    this.memo,
    this.visibility,
  });

  @override
  List<Object?> get props => [
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
        visibility,
      ];
}

class UpdateInsurance extends InsuranceEvent {
  final String id;
  final String? name;
  final String? insurer;
  final bool clearInsurer;
  final String? insuranceType;
  final int? premiumAmount;
  final int? paymentDay;
  final bool clearPaymentDay;
  final String? paymentCycle;
  final String? paymentMethodId;
  final bool clearPaymentMethodId;
  final String? categoryId;
  final bool clearCategoryId;
  final String? startDate;
  final bool clearStartDate;
  final String? endDate;
  final bool clearEndDate;
  final String? memo;
  final bool clearMemo;
  final bool? isActive;
  final String? visibility;

  const UpdateInsurance({
    required this.id,
    this.name,
    this.insurer,
    this.clearInsurer = false,
    this.insuranceType,
    this.premiumAmount,
    this.paymentDay,
    this.clearPaymentDay = false,
    this.paymentCycle,
    this.paymentMethodId,
    this.clearPaymentMethodId = false,
    this.categoryId,
    this.clearCategoryId = false,
    this.startDate,
    this.clearStartDate = false,
    this.endDate,
    this.clearEndDate = false,
    this.memo,
    this.clearMemo = false,
    this.isActive,
    this.visibility,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        insurer,
        clearInsurer,
        insuranceType,
        premiumAmount,
        paymentDay,
        clearPaymentDay,
        paymentCycle,
        paymentMethodId,
        clearPaymentMethodId,
        categoryId,
        clearCategoryId,
        startDate,
        clearStartDate,
        endDate,
        clearEndDate,
        memo,
        clearMemo,
        isActive,
        visibility,
      ];
}

class DeleteInsurance extends InsuranceEvent {
  final String id;

  const DeleteInsurance(this.id);

  @override
  List<Object?> get props => [id];
}
