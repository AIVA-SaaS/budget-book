import 'package:budget_book/features/ai/domain/entities/ai_classify_result.dart';

class AiClassifyModel extends AiClassifyResult {
  const AiClassifyModel({
    required super.categoryId,
    required super.categoryName,
    required super.groupName,
    required super.confidence,
    required super.source,
  });

  factory AiClassifyModel.fromJson(Map<String, dynamic> json) {
    return AiClassifyModel(
      categoryId: json['categoryId'] as String,
      categoryName: json['categoryName'] as String,
      groupName: json['groupName'] as String? ?? '',
      confidence: (json['confidence'] as num).toDouble(),
      source: json['source'] as String? ?? 'AI',
    );
  }
}
