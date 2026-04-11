import 'package:budget_book/features/ai/domain/entities/ai_insight.dart';

class AiInsightModel extends AiInsight {
  const AiInsightModel({
    required super.type,
    required super.title,
    required super.description,
    required super.severity,
  });

  factory AiInsightModel.fromJson(Map<String, dynamic> json) {
    return AiInsightModel(
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String? ?? 'INFO',
    );
  }
}

class AiInsightsResponseModel extends AiInsightsResponse {
  const AiInsightsResponseModel({
    required super.insights,
    required super.generatedAt,
  });

  factory AiInsightsResponseModel.fromJson(Map<String, dynamic> json) {
    final insightsList = (json['insights'] as List<dynamic>?)
            ?.map((e) => AiInsightModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return AiInsightsResponseModel(
      insights: insightsList,
      generatedAt: json['generatedAt'] as String? ?? '',
    );
  }
}
