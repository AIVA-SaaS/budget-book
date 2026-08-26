import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_state.dart';
import 'package:budget_book/features/feedback/presentation/widgets/feedback_status_badge.dart';
import 'package:budget_book/features/feedback/domain/entities/feedback_post.dart';
import '../../../../core/theme/bb_scale.dart';

class AdminFeedbackPage extends StatefulWidget {
  const AdminFeedbackPage({super.key});

  @override
  State<AdminFeedbackPage> createState() => _AdminFeedbackPageState();
}

class _AdminFeedbackPageState extends State<AdminFeedbackPage> {
  String? _statusFilter;
  String? _categoryFilter;

  static const _statusOptions = [
    (null, '전체'),
    ('SUBMITTED', '접수'),
    ('REVIEWING', '검토 중'),
    ('IN_PROGRESS', '개발 중'),
    ('RESOLVED', '완료'),
    ('REJECTED', '반려'),
  ];

  void _onStatusFilterChanged(String? status) {
    setState(() => _statusFilter = status);
    context.read<FeedbackBloc>().add(LoadAdminFeedbacks(
          status: status,
          category: _categoryFilter,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MM/dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('피드백 관리'),
      ),
      body: Column(
        children: [
          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: _statusOptions.map((opt) {
                final isSelected = _statusFilter == opt.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(opt.$2),
                    selected: isSelected,
                    onSelected: (_) => _onStatusFilterChanged(opt.$1),
                  ),
                );
              }).toList(),
            ),
          ),
          // List
          Expanded(
            child: BlocConsumer<FeedbackBloc, FeedbackState>(
              listener: (context, state) {
                if (state is FeedbackLoaded && state.operationError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.operationError!)),
                  );
                }
                if (state is FeedbackLoaded &&
                    state.operationSuccess != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.operationSuccess!)),
                  );
                }
              },
              builder: (context, state) {
                if (state is FeedbackLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is FeedbackError) {
                  return Center(child: Text(state.message));
                }
                if (state is FeedbackLoaded) {
                  if (state.feedbacks.isEmpty) {
                    return const Center(child: Text('피드백이 없습니다'));
                  }
                  return RefreshIndicator(
                    onRefresh: () async {
                      context.read<FeedbackBloc>().add(LoadAdminFeedbacks(
                            status: _statusFilter,
                            category: _categoryFilter,
                          ));
                    },
                    child: ListView.builder(
                      itemCount: state.feedbacks.length,
                      itemBuilder: (context, index) {
                        final fb = state.feedbacks[index];
                        return ListTile(
                          leading: FeedbackStatusBadge(status: fb.status),
                          title: Text(
                            fb.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${FeedbackCategoryChip.categoryLabel(fb.category)} | ${fb.userName} | ${dateFormat.format(fb.createdAt)}',
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _showManageDialog(context, fb),
                        );
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showManageDialog(BuildContext context, FeedbackPost fb) {
    final noteController = TextEditingController(text: fb.adminNote ?? '');
    final replyController = TextEditingController();
    String selectedStatus = fb.status;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fb.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    context.bbSpace.gapV(BbSpaceToken.xs),
                    Text(fb.content,
                        style: Theme.of(context).textTheme.bodySmall),
                    const Divider(height: 24),
                    // Status change
                    Text('상태 변경',
                        style: Theme.of(context).textTheme.labelLarge),
                    context.bbSpace.gapV(BbSpaceToken.lg),
                    Wrap(
                      spacing: 8,
                      children: [
                        'SUBMITTED',
                        'REVIEWING',
                        'IN_PROGRESS',
                        'RESOLVED',
                        'REJECTED',
                      ].map((s) {
                        return ChoiceChip(
                          label: Text(FeedbackStatusBadge.statusLabel(s)),
                          selected: selectedStatus == s,
                          onSelected: (_) {
                            setSheetState(() => selectedStatus = s);
                          },
                        );
                      }).toList(),
                    ),
                    if (selectedStatus != fb.status) ...[
                      context.bbSpace.gapV(BbSpaceToken.lg),
                      FilledButton(
                        onPressed: () {
                          this.context.read<FeedbackBloc>().add(
                                UpdateFeedbackStatus(
                                  feedbackId: fb.id,
                                  status: selectedStatus,
                                ),
                              );
                          Navigator.of(sheetContext).pop();
                        },
                        child: const Text('상태 저장'),
                      ),
                    ],
                    const Divider(height: 24),
                    // Admin note
                    Text('관리자 메모',
                        style: Theme.of(context).textTheme.labelLarge),
                    context.bbSpace.gapV(BbSpaceToken.lg),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        hintText: '내부 메모 (사용자에게 표시됨)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                    context.bbSpace.gapV(BbSpaceToken.lg),
                    OutlinedButton(
                      onPressed: () {
                        this.context.read<FeedbackBloc>().add(
                              UpdateAdminNote(
                                feedbackId: fb.id,
                                adminNote: noteController.text.trim(),
                              ),
                            );
                        Navigator.of(sheetContext).pop();
                      },
                      child: const Text('메모 저장'),
                    ),
                    const Divider(height: 24),
                    // Admin reply
                    Text('답변',
                        style: Theme.of(context).textTheme.labelLarge),
                    context.bbSpace.gapV(BbSpaceToken.lg),
                    TextField(
                      controller: replyController,
                      decoration: const InputDecoration(
                        hintText: '사용자에게 답변',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 3,
                    ),
                    context.bbSpace.gapV(BbSpaceToken.lg),
                    FilledButton.icon(
                      onPressed: () {
                        final text = replyController.text.trim();
                        if (text.isEmpty) return;
                        this.context.read<FeedbackBloc>().add(
                              AddAdminComment(
                                feedbackId: fb.id,
                                content: text,
                              ),
                            );
                        Navigator.of(sheetContext).pop();
                      },
                      icon: Icon(Icons.send, size: context.bbType.iconSm),
                      label: const Text('답변 보내기'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
