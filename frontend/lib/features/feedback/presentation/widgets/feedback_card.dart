import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_post.dart';
import 'package:budget_book/features/feedback/presentation/widgets/feedback_status_badge.dart';
import '../../../../core/theme/bb_scale.dart';

class FeedbackCard extends StatelessWidget {
  final FeedbackPost feedback;
  final VoidCallback? onTap;

  const FeedbackCard({
    super.key,
    required this.feedback,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy.MM.dd');

    return Card(
      // ★세로는 호스트가 갖는다(`BbCardGap`). 가로만 남긴다.
      margin: EdgeInsets.symmetric(horizontal: context.bbSpace.xxl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FeedbackCategoryChip(category: feedback.category),
                  const Spacer(),
                  FeedbackStatusBadge(status: feedback.status),
                ],
              ),
              context.bbSpace.gapV(BbSpaceToken.lg),
              Text(
                feedback.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              context.bbSpace.gapV(BbSpaceToken.xs),
              Text(
                feedback.content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              context.bbSpace.gapV(BbSpaceToken.lg),
              Row(
                children: [
                  Text(
                    dateFormat.format(feedback.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (feedback.comments.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${feedback.comments.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
