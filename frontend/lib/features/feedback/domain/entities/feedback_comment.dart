import 'package:equatable/equatable.dart';

class FeedbackComment extends Equatable {
  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final bool isAdminReply;
  final DateTime createdAt;

  const FeedbackComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.isAdminReply,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorName,
        content,
        isAdminReply,
        createdAt,
      ];
}
