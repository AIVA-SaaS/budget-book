import 'package:equatable/equatable.dart';

class ReleaseNote extends Equatable {
  final String id;
  final String version;
  final String title;
  final String content;
  final bool isPublished;
  final DateTime? publishedAt;
  final List<String> linkedFeedbackIds;
  final DateTime createdAt;

  const ReleaseNote({
    required this.id,
    required this.version,
    required this.title,
    required this.content,
    required this.isPublished,
    this.publishedAt,
    required this.linkedFeedbackIds,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        version,
        title,
        content,
        isPublished,
        publishedAt,
        linkedFeedbackIds,
        createdAt,
      ];
}
