import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_event.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_state.dart';
import 'package:budget_book/features/feedback/domain/entities/release_note.dart';
import '../../../../core/theme/bb_scale.dart';

class AdminReleaseNotePage extends StatelessWidget {
  const AdminReleaseNotePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy.MM.dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('배포 노트 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '배포 노트 생성',
            onPressed: () => _showForm(context, null),
          ),
        ],
      ),
      body: BlocConsumer<ReleaseNoteBloc, ReleaseNoteState>(
        listener: (context, state) {
          if (state is ReleaseNoteLoaded && state.operationError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.operationError!)),
            );
          }
          if (state is ReleaseNoteLoaded && state.operationSuccess != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.operationSuccess!)),
            );
          }
        },
        builder: (context, state) {
          if (state is ReleaseNoteLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is ReleaseNoteError) {
            return Center(child: Text(state.message));
          }
          if (state is ReleaseNoteLoaded) {
            if (state.releaseNotes.isEmpty) {
              return const Center(child: Text('배포 노트가 없습니다'));
            }
            return RefreshIndicator(
              onRefresh: () async {
                context
                    .read<ReleaseNoteBloc>()
                    .add(const LoadReleaseNotes());
              },
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: state.releaseNotes.length,
                itemBuilder: (context, index) {
                  final note = state.releaseNotes[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: note.isPublished
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      child: Icon(
                        note.isPublished ? Icons.check : Icons.edit_note,
                        color: note.isPublished ? Colors.green : Colors.grey,
                        size: context.bbType.iconSm,
                      ),
                    ),
                    title: Text(
                      '${note.version} - ${note.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      note.isPublished
                          ? '게시됨 | ${note.publishedAt != null ? dateFormat.format(note.publishedAt!) : ""}'
                          : '미게시 | ${dateFormat.format(note.createdAt)}',
                      style: theme.textTheme.bodySmall,
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) =>
                          _onAction(context, action, note),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('수정'),
                        ),
                        if (!note.isPublished)
                          const PopupMenuItem(
                            value: 'publish',
                            child: Text('게시'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('삭제',
                              style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _onAction(
      BuildContext context, String action, ReleaseNote note) {
    switch (action) {
      case 'edit':
        _showForm(context, note);
      case 'publish':
        context
            .read<ReleaseNoteBloc>()
            .add(PublishReleaseNote(note.id));
      case 'delete':
        _confirmDelete(context, note);
    }
  }

  void _confirmDelete(BuildContext context, ReleaseNote note) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('배포 노트 삭제'),
        content: Text('${note.version} - ${note.title}을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              context
                  .read<ReleaseNoteBloc>()
                  .add(DeleteReleaseNote(note.id));
              Navigator.of(dialogContext).pop();
            },
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _showForm(BuildContext context, ReleaseNote? existing) {
    final versionController =
        TextEditingController(text: existing?.version ?? '');
    final titleController =
        TextEditingController(text: existing?.title ?? '');
    final contentController =
        TextEditingController(text: existing?.content ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null ? '배포 노트 생성' : '배포 노트 수정',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  context.bbSpace.gapV(BbSpaceToken.xxl),
                  TextFormField(
                    controller: versionController,
                    decoration: const InputDecoration(
                      labelText: '버전',
                      hintText: 'v1.3.0',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '버전을 입력해주세요' : null,
                  ),
                  context.bbSpace.gapV(BbSpaceToken.xl),
                  TextFormField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: '제목',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '제목을 입력해주세요' : null,
                  ),
                  context.bbSpace.gapV(BbSpaceToken.xl),
                  TextFormField(
                    controller: contentController,
                    decoration: const InputDecoration(
                      labelText: '내용 (Markdown)',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 8,
                    minLines: 4,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? '내용을 입력해주세요' : null,
                  ),
                  context.bbSpace.gapV(BbSpaceToken.xxl),
                  FilledButton(
                    onPressed: () {
                      if (!formKey.currentState!.validate()) return;
                      if (existing == null) {
                        context.read<ReleaseNoteBloc>().add(CreateReleaseNote(
                              version: versionController.text.trim(),
                              title: titleController.text.trim(),
                              content: contentController.text.trim(),
                            ));
                      } else {
                        context.read<ReleaseNoteBloc>().add(UpdateReleaseNote(
                              id: existing.id,
                              version: versionController.text.trim(),
                              title: titleController.text.trim(),
                              content: contentController.text.trim(),
                            ));
                      }
                      Navigator.of(sheetContext).pop();
                    },
                    child: Text(existing == null ? '생성' : '저장'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
