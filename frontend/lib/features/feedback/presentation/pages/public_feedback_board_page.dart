import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/feedback/domain/entities/public_feedback.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_state.dart';
import 'package:budget_book/features/feedback/presentation/widgets/feedback_vote_button.dart';
import 'package:budget_book/features/feedback/presentation/widgets/feedback_status_badge.dart';

class PublicFeedbackBoardPage extends StatefulWidget {
  const PublicFeedbackBoardPage({super.key});

  @override
  State<PublicFeedbackBoardPage> createState() =>
      _PublicFeedbackBoardPageState();
}

class _PublicFeedbackBoardPageState extends State<PublicFeedbackBoardPage> {
  String _sort = 'latest';
  String? _category;
  String? _status;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  void _loadFeedbacks({int page = 0}) {
    context.read<FeedbackBloc>().add(LoadPublicFeedbacks(
          sort: _sort,
          category: _category,
          status: _status,
          page: page,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeedbackBloc, FeedbackState>(
      listener: (context, state) {
        if (state is PublicFeedbacksLoaded && state.operationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.operationError!)),
          );
        }
      },
      builder: (context, state) {
        return Column(
          children: [
            // Sort + filter chips
            _FilterBar(
              currentSort: _sort,
              currentCategory: _category,
              currentStatus: _status,
              onSortChanged: (sort) {
                setState(() => _sort = sort);
                _loadFeedbacks();
              },
              onCategoryChanged: (cat) {
                setState(() => _category = cat);
                _loadFeedbacks();
              },
              onStatusChanged: (st) {
                setState(() => _status = st);
                _loadFeedbacks();
              },
            ),
            // Content
            Expanded(child: _buildContent(state)),
          ],
        );
      },
    );
  }

  Widget _buildContent(FeedbackState state) {
    if (state is PublicFeedbacksLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state is FeedbackError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(state.message),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _loadFeedbacks(),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (state is PublicFeedbacksLoaded) {
      if (state.feedbacks.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                '아직 피드백이 없습니다',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async => _loadFeedbacks(),
        child: ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          itemCount: state.feedbacks.length + (state.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == state.feedbacks.length) {
              // Load more trigger
              if (!state.isLoadingMore) {
                _loadFeedbacks(page: state.currentPage + 1);
              }
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final fb = state.feedbacks[index];
            return _PublicFeedbackCard(
              feedback: fb,
              onTap: () => context.push('/feedback/${fb.id}'),
              onVote: () =>
                  context.read<FeedbackBloc>().add(ToggleVote(fb.id)),
            );
          },
        ),
      );
    }

    // If we're in a different state (e.g. FeedbackLoaded from another tab), load
    return const Center(child: CircularProgressIndicator());
  }
}

class _FilterBar extends StatelessWidget {
  final String currentSort;
  final String? currentCategory;
  final String? currentStatus;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onStatusChanged;

  const _FilterBar({
    required this.currentSort,
    required this.currentCategory,
    required this.currentStatus,
    required this.onSortChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Sort chips
            _buildChip(
              context,
              label: '최신순',
              selected: currentSort == 'latest',
              onTap: () => onSortChanged('latest'),
            ),
            const SizedBox(width: 6),
            _buildChip(
              context,
              label: '인기순',
              selected: currentSort == 'popular',
              onTap: () => onSortChanged('popular'),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: Theme.of(context).dividerColor),
            const SizedBox(width: 12),
            // Category filter
            _buildFilterChip(
              context,
              label: _categoryLabel(currentCategory),
              active: currentCategory != null,
              onTap: () => _showCategoryPicker(context),
            ),
            const SizedBox(width: 6),
            // Status filter
            _buildFilterChip(
              context,
              label: _statusLabel(currentStatus),
              active: currentStatus != null,
              onTap: () => _showStatusPicker(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      deleteIcon: active ? const Icon(Icons.close, size: 16) : null,
      onDeleted: active
          ? () {
              if (label.contains('카테고리') || _isCategoryLabel(label)) {
                onCategoryChanged(null);
              } else {
                onStatusChanged(null);
              }
            }
          : null,
    );
  }

  bool _isCategoryLabel(String label) {
    return ['버그', '개선', '기능 추가', '기타'].contains(label);
  }

  String _categoryLabel(String? category) {
    if (category == null) return '카테고리';
    return FeedbackCategoryChip.categoryLabel(category);
  }

  String _statusLabel(String? status) {
    if (status == null) return '상태';
    return FeedbackStatusBadge.statusLabel(status);
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('전체'),
            onTap: () {
              onCategoryChanged(null);
              Navigator.pop(ctx);
            },
          ),
          for (final cat in ['BUG', 'IMPROVEMENT', 'FEATURE', 'OTHER'])
            ListTile(
              leading: Text(FeedbackCategoryChip.categoryIcon(cat)),
              title: Text(FeedbackCategoryChip.categoryLabel(cat)),
              selected: currentCategory == cat,
              onTap: () {
                onCategoryChanged(cat);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }

  void _showStatusPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('전체'),
            onTap: () {
              onStatusChanged(null);
              Navigator.pop(ctx);
            },
          ),
          for (final st in [
            'SUBMITTED',
            'REVIEWING',
            'IN_PROGRESS',
            'RESOLVED',
            'REJECTED'
          ])
            ListTile(
              title: Text(FeedbackStatusBadge.statusLabel(st)),
              selected: currentStatus == st,
              onTap: () {
                onStatusChanged(st);
                Navigator.pop(ctx);
              },
            ),
        ],
      ),
    );
  }
}

class _PublicFeedbackCard extends StatelessWidget {
  final PublicFeedback feedback;
  final VoidCallback? onTap;
  final VoidCallback onVote;

  const _PublicFeedbackCard({
    required this.feedback,
    this.onTap,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy.MM.dd');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              const SizedBox(height: 8),
              Text(
                feedback.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                feedback.contentPreview,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    feedback.authorName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateFormat.format(feedback.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (feedback.commentCount > 0) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${feedback.commentCount}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  FeedbackVoteButton(
                    voteCount: feedback.voteCount,
                    hasVoted: feedback.hasVoted,
                    onToggle: onVote,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
