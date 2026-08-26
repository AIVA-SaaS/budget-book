import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_state.dart';
import 'package:budget_book/features/feedback/presentation/widgets/feedback_status_badge.dart';
import '../../../../core/theme/bb_scale.dart';

class FeedbackDetailPage extends StatefulWidget {
  final String feedbackId;

  const FeedbackDetailPage({super.key, required this.feedbackId});

  @override
  State<FeedbackDetailPage> createState() => _FeedbackDetailPageState();
}

class _FeedbackDetailPageState extends State<FeedbackDetailPage> {
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _sendComment() {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    context.read<FeedbackBloc>().add(AddComment(
          feedbackId: widget.feedbackId,
          content: text,
        ));
    _commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy.MM.dd HH:mm');

    return BlocConsumer<FeedbackBloc, FeedbackState>(
      listener: (context, state) {
        if (state is FeedbackLoaded && state.detail != null) {
          if (_sending) {
            setState(() => _sending = false);
          }
        }
        if (state is FeedbackLoaded && state.operationError != null) {
          setState(() => _sending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.operationError!)),
          );
        }
      },
      builder: (context, state) {
        final detail =
            state is FeedbackLoaded ? state.detail : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('피드백 상세'),
          ),
          body: detail == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // Header
                          Row(
                            children: [
                              FeedbackCategoryChip(
                                  category: detail.category),
                              const Spacer(),
                              FeedbackStatusBadge(status: detail.status),
                            ],
                          ),
                          context.bbSpace.gapV(BbSpaceToken.xl),
                          Text(
                            detail.title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          context.bbSpace.gapV(BbSpaceToken.lg),
                          Text(
                            '${detail.userName} | ${dateFormat.format(detail.createdAt)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          context.bbSpace.gapV(BbSpaceToken.xxl),
                          Text(
                            detail.content,
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (detail.adminNote != null) ...[
                            context.bbSpace.gapV(BbSpaceToken.xxl),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '관리자 메모',
                                    style:
                                        theme.textTheme.labelSmall?.copyWith(
                                      color: theme
                                          .colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  context.bbSpace.gapV(BbSpaceToken.xs),
                                  Text(detail.adminNote!),
                                ],
                              ),
                            ),
                          ],
                          if (detail.status == 'RESOLVED' &&
                              detail.resolvedReleaseId != null) ...[
                            context.bbSpace.gapV(BbSpaceToken.xl),
                            OutlinedButton.icon(
                              onPressed: () => context.push(
                                  '/releases/${detail.resolvedReleaseId}'),
                              icon: Icon(Icons.new_releases, size: context.bbType.iconSm),
                              label: const Text('관련 업데이트 보기'),
                            ),
                          ],
                          const Divider(height: 32),
                          Text(
                            '댓글 (${detail.comments.length})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          context.bbSpace.gapV(BbSpaceToken.lg),
                          // Comments timeline
                          ...detail.comments.map((comment) {
                            final isAdmin = comment.isAdminReply;
                            return Container(
                              // ★세로는 호스트가 갖는다(`bbCardItems`).
                              margin: EdgeInsets.zero,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isAdmin
                                    ? theme.colorScheme.primaryContainer
                                        .withAlpha(80)
                                    : theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: isAdmin
                                    ? Border.all(
                                        color: theme.colorScheme.primary
                                            .withAlpha(40),
                                      )
                                    : null,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        comment.authorName,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (isAdmin) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color:
                                                theme.colorScheme.primary,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '관리자',
                                            style: TextStyle(
                                              color: theme
                                                  .colorScheme.onPrimary,
                                              fontSize: context.bbType.caption,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Text(
                                        dateFormat.format(comment.createdAt),
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  context.bbSpace.gapV(BbSpaceToken.xs),
                                  Text(comment.content),
                                ],
                              ),
                            );
                          }),
                          if (detail.comments.isEmpty)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  '아직 댓글이 없습니다',
                                  style:
                                      theme.textTheme.bodyMedium?.copyWith(
                                    color: theme
                                        .colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Comment input
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          top: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                decoration: const InputDecoration(
                                  hintText: '댓글을 입력하세요',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  isDense: true,
                                ),
                                maxLines: 3,
                                minLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              onPressed: _sending ? null : _sendComment,
                              icon: _sending
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Icon(Icons.send, size: context.bbType.iconSm),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
