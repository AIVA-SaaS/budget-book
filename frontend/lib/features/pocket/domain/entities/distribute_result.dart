import 'package:equatable/equatable.dart';

class DistributeResult extends Equatable {
  final List<DistributionEntry> distributions;
  final int totalDistributed;

  const DistributeResult({
    required this.distributions,
    required this.totalDistributed,
  });

  @override
  List<Object?> get props => [distributions, totalDistributed];
}

class DistributionEntry extends Equatable {
  final String pocketId;
  final String pocketName;
  final int amount;

  const DistributionEntry({
    required this.pocketId,
    required this.pocketName,
    required this.amount,
  });

  @override
  List<Object?> get props => [pocketId, pocketName, amount];
}
