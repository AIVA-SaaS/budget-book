import 'package:equatable/equatable.dart';

class AiInsight extends Equatable {
  final String type;
  final String title;
  final String description;
  final String severity;
  final Map<String, dynamic>? data;

  const AiInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    this.data,
  });

  @override
  List<Object?> get props => [type, title, description, severity, data];
}

class AiInsightsResponse extends Equatable {
  final List<AiInsight> insights;
  final String generatedAt;

  const AiInsightsResponse({
    required this.insights,
    required this.generatedAt,
  });

  @override
  List<Object?> get props => [insights, generatedAt];
}
