import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_bloc.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_event.dart';
import 'package:budget_book/features/feedback/presentation/bloc/feedback_state.dart';
import '../../../../core/theme/bb_scale.dart';

class FeedbackCreatePage extends StatefulWidget {
  const FeedbackCreatePage({super.key});

  @override
  State<FeedbackCreatePage> createState() => _FeedbackCreatePageState();
}

class _FeedbackCreatePageState extends State<FeedbackCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'BUG';
  bool _submitting = false;

  static const _categories = [
    ('BUG', '\uD83D\uDC1B 버그'),
    ('IMPROVEMENT', '\uD83D\uDCA1 개선'),
    ('FEATURE', '\u2728 기능 추가'),
    ('OTHER', '\uD83D\uDCAC 기타'),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    context.read<FeedbackBloc>().add(CreateFeedback(
          category: _selectedCategory,
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FeedbackBloc, FeedbackState>(
      listener: (context, state) {
        if (state is FeedbackLoaded && _submitting) {
          if (state.operationError != null) {
            setState(() => _submitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.operationError!)),
            );
          } else {
            // Successfully created and list reloaded
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('저장되었습니다')),
            );
            context.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('피드백 작성'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '카테고리',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              context.bbSpace.gapV(BbSpaceToken.lg),
              Wrap(
                spacing: 8,
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat.$1;
                  return ChoiceChip(
                    label: Text(cat.$2),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedCategory = cat.$1);
                    },
                  );
                }).toList(),
              ),
              context.bbSpace.gapV(BbSpaceToken.block),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  hintText: '피드백 제목을 입력하세요',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '제목을 입력해주세요';
                  }
                  return null;
                },
              ),
              context.bbSpace.gapV(BbSpaceToken.xxl),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: '내용',
                  hintText: '피드백 내용을 자세히 작성해주세요',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 8,
                minLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '내용을 입력해주세요';
                  }
                  return null;
                },
              ),
              context.bbSpace.gapV(BbSpaceToken.block),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
