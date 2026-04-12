import 'package:equatable/equatable.dart';

class PublicFeedback extends Equatable {
  final String id;
  final String category;
  final String title;
  final String contentPreview;
  final String status;
  final int voteCount;
  final bool hasVoted;
  final int commentCount;
  final String authorName;
  final DateTime createdAt;

  const PublicFeedback({
    required this.id,
    required this.category,
    required this.title,
    required this.contentPreview,
    required this.status,
    required this.voteCount,
    required this.hasVoted,
    required this.commentCount,
    required this.authorName,
    required this.createdAt,
  });

  PublicFeedback copyWith({
    int? voteCount,
    bool? hasVoted,
  }) =>
      PublicFeedback(
        id: id,
        category: category,
        title: title,
        contentPreview: contentPreview,
        status: status,
        voteCount: voteCount ?? this.voteCount,
        hasVoted: hasVoted ?? this.hasVoted,
        commentCount: commentCount,
        authorName: authorName,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [
        id, category, title, contentPreview, status,
        voteCount, hasVoted, commentCount, authorName, createdAt,
      ];
}

class VoteResponse extends Equatable {
  final bool voted;
  final int voteCount;

  const VoteResponse({required this.voted, required this.voteCount});

  @override
  List<Object?> get props => [voted, voteCount];
}
