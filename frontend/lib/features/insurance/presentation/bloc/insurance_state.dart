import 'package:equatable/equatable.dart';
import 'package:budget_book/features/insurance/domain/entities/insurance.dart';

sealed class InsuranceState extends Equatable {
  const InsuranceState();

  @override
  List<Object?> get props => [];
}

class InsuranceInitial extends InsuranceState {
  const InsuranceInitial();
}

class InsuranceLoading extends InsuranceState {
  const InsuranceLoading();
}

class InsuranceLoaded extends InsuranceState {
  final List<Insurance> insurances;
  final InsuranceSummary? summary;
  final String? operationError;
  final String? operationSuccess;

  const InsuranceLoaded({
    required this.insurances,
    this.summary,
    this.operationError,
    this.operationSuccess,
  });

  /// Group insurances by type for display.
  Map<String, List<Insurance>> get groupedByType {
    final grouped = <String, List<Insurance>>{};
    for (final ins in insurances) {
      grouped.putIfAbsent(ins.insuranceType, () => []).add(ins);
    }
    return grouped;
  }

  List<Insurance> get activeInsurances =>
      insurances.where((i) => i.isActive).toList();

  List<Insurance> get inactiveInsurances =>
      insurances.where((i) => !i.isActive).toList();

  @override
  List<Object?> get props =>
      [insurances, summary, operationError, operationSuccess];
}

class InsuranceError extends InsuranceState {
  final String message;

  const InsuranceError(this.message);

  @override
  List<Object?> get props => [message];
}
