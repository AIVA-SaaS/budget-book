import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_state.dart';

class ReleaseNoteDetailPage extends StatelessWidget {
  final String releaseId;

  const ReleaseNoteDetailPage({super.key, required this.releaseId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy.MM.dd');

    return BlocBuilder<ReleaseNoteBloc, ReleaseNoteState>(
      builder: (context, state) {
        final detail =
            state is ReleaseNoteLoaded ? state.detail : null;

        return Scaffold(
          appBar: AppBar(
            title: const Text('업데이트 노트'),
          ),
          body: detail == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          detail.version,
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        detail.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detail.publishedAt != null
                            ? dateFormat.format(detail.publishedAt!)
                            : dateFormat.format(detail.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: 32),
                      // Render content as plain text (markdown rendering
                      // can be added later with flutter_markdown).
                      Text(
                        detail.content,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
