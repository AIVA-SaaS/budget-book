import 'package:equatable/equatable.dart';

class AiClassifyResult extends Equatable {
  final String categoryId;
  final String categoryName;
  final String groupName;
  final double confidence;
  final String source;

  const AiClassifyResult({
    required this.categoryId,
    required this.categoryName,
    required this.groupName,
    required this.confidence,
    required this.source,
  });

  @override
  List<Object?> get props => [categoryId, categoryName, groupName, confidence, source];
}
