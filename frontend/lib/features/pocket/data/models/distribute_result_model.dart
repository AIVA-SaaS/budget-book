import 'package:budget_book/features/pocket/domain/entities/distribute_result.dart';

class DistributeResultModel extends DistributeResult {
  const DistributeResultModel({
    required super.distributions,
    required super.totalDistributed,
  });

  factory DistributeResultModel.fromJson(Map<String, dynamic> json) {
    final entries = (json['distributions'] as List<dynamic>)
        .map((e) => DistributionEntryModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return DistributeResultModel(
      distributions: entries,
      totalDistributed: json['totalDistributed'] as int,
    );
  }
}

class DistributionEntryModel extends DistributionEntry {
  const DistributionEntryModel({
    required super.pocketId,
    required super.pocketName,
    required super.amount,
  });

  factory DistributionEntryModel.fromJson(Map<String, dynamic> json) {
    return DistributionEntryModel(
      pocketId: json['pocketId'] as String,
      pocketName: json['pocketName'] as String,
      amount: json['amount'] as int,
    );
  }
}
