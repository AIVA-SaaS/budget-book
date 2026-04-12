import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_state.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_event.dart';
import 'package:budget_book/features/feedback/presentation/bloc/release_note_state.dart';
import 'package:budget_book/features/feedback/presentation/widgets/feedback_card.dart';
import 'package:budget_book/features/feedback/presentation/widgets/release_note_card.dart';
import 'package:budget_book/features/feedback/presentation/pages/public_feedback_board_page.dart';
import 'package:budget_book/core/widgets/announcement_banner.dart';

class FeedbackHubPage extends StatefulWidget {
  const FeedbackHubPage({super.key});

  @override
  State<FeedbackHubPage> createState() => _FeedbackHubPageState();
}

class _FeedbackHubPageState extends State<FeedbackHubPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('피드백 및 공지'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '공지사항'),
            Tab(text: '내 요청'),
            Tab(text: '업데이트'),
            Tab(text: '공개 보드'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Announcements
          const _AnnouncementsTab(),
          // Tab 1: My Feedback
          _MyFeedbackTab(
            onCreateTap: () => context.push('/feedback/create'),
          ),
          // Tab 2: Release Notes
          const _ReleaseNotesTab(),
          // Tab 3: Public Board
          const PublicFeedbackBoardPage(),
        ],
      ),
    );
  }
}

class _AnnouncementsTab extends StatelessWidget {
  const _AnnouncementsTab();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.only(top: 8),
      child: AnnouncementBanner(),
    );
  }
}

class _MyFeedbackTab extends StatelessWidget {
  final VoidCallback onCreateTap;

  const _MyFeedbackTab({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeedbackBloc, FeedbackState>(
      listener: (context, state) {
        if (state is FeedbackLoaded && state.operationError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.operationError!)),
          );
        }
        if (state is FeedbackLoaded && state.operationSuccess != null) {
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.message),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () =>
                      context.read<FeedbackBloc>().add(const LoadFeedbacks()),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }
        if (state is FeedbackLoaded) {
          if (state.feedbacks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.feedback_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '아직 요청한 피드백이 없습니다',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: onCreateTap,
                    icon: const Icon(Icons.add),
                    label: const Text('피드백 작성'),
                  ),
                ],
              ),
            );
          }
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  context.read<FeedbackBloc>().add(const LoadFeedbacks());
                },
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: state.feedbacks.length,
                  itemBuilder: (context, index) {
                    final fb = state.feedbacks[index];
                    return FeedbackCard(
                      feedback: fb,
                      onTap: () => context.push('/feedback/${fb.id}'),
                    );
                  },
                ),
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: onCreateTap,
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _ReleaseNotesTab extends StatelessWidget {
  const _ReleaseNotesTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ReleaseNoteBloc, ReleaseNoteState>(
      builder: (context, state) {
        if (state is ReleaseNoteLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state is ReleaseNoteError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(state.message),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context
                      .read<ReleaseNoteBloc>()
                      .add(const LoadReleaseNotes()),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
        }
        if (state is ReleaseNoteLoaded) {
          if (state.releaseNotes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.new_releases_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '아직 업데이트 노트가 없습니다',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              context.read<ReleaseNoteBloc>().add(const LoadReleaseNotes());
            },
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: state.releaseNotes.length,
              itemBuilder: (context, index) {
                final note = state.releaseNotes[index];
                return ReleaseNoteCard(
                  releaseNote: note,
                  onTap: () => context.push('/releases/${note.id}'),
                );
              },
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
