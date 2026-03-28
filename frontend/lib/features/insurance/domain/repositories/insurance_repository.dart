import 'package:dartz/dartz.dart';
import 'package:budget_book/core/error/failure.dart';
import 'package:budget_book/features/insurance/domain/entities/insurance.dart';

abstract class InsuranceRepository {
  Future<Either<Failure, List<Insurance>>> getInsurances({bool? active});

  Future<Either<Failure, Insurance>> createInsurance({
    required String name,
    String? insurer,
    required String insuranceType,
    required int premiumAmount,
    int? paymentDay,
    String? paymentCycle,
    String? paymentMethodId,
    String? categoryId,
    String? startDate,
    String? endDate,
    String? memo,
    String? visibility,
  });

  Future<Either<Failure, Insurance>> updateInsurance({
    required String id,
    String? name,
    String? insurer,
    bool clearInsurer = false,
    String? insuranceType,
    int? premiumAmount,
    int? paymentDay,
    bool clearPaymentDay = false,
    String? paymentCycle,
    String? paymentMethodId,
    bool clearPaymentMethodId = false,
    String? categoryId,
    bool clearCategoryId = false,
    String? startDate,
    bool clearStartDate = false,
    String? endDate,
    bool clearEndDate = false,
    String? memo,
    bool clearMemo = false,
    bool? isActive,
    String? visibility,
  });

  Future<Either<Failure, void>> deleteInsurance(String id);

  Future<Either<Failure, InsuranceSummary>> getInsuranceSummary({
    required int year,
    required int month,
  });
}
