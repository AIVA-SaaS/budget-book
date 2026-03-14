import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  bool _isSubmitting = false;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    final currentNickname =
        authState is AuthAuthenticated ? authState.user.nickname : '';
    _nicknameController = TextEditingController(text: currentNickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    context.read<AuthBloc>().add(
          UpdateProfile(nickname: _nicknameController.text.trim()),
        );
  }

  Future<void> _showImageOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('카메라'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('갤러리에서 선택'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('이미지 삭제',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.of(ctx).pop();
                _deleteImage();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (pickedFile == null) return;

      setState(() => _isUploadingImage = true);
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      context.read<AuthBloc>().add(
            UploadProfileImage(
              imageBytes: bytes,
              fileName: pickedFile.name,
            ),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('이미지를 선택할 수 없습니다: $e')),
        );
      }
    }
  }

  void _deleteImage() {
    setState(() => _isUploadingImage = true);
    context.read<AuthBloc>().add(const DeleteProfileImage());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          if (_isSubmitting) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('프로필이 수정되었습니다')),
            );
            Navigator.of(context).pop();
          }
          if (_isUploadingImage) {
            setState(() => _isUploadingImage = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('프로필 이미지가 변경되었습니다')),
            );
          }
        } else if (state is AuthError) {
          if (_isSubmitting) {
            setState(() => _isSubmitting = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('프로필 수정 실패: ${state.message}')),
            );
          }
          if (_isUploadingImage) {
            setState(() => _isUploadingImage = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('이미지 변경 실패: ${state.message}')),
            );
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('프로필 수정'),
        ),
        body: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final user =
                state is AuthAuthenticated ? state.user : null;
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundImage: user?.profileImageUrl != null
                              ? NetworkImage(user!.profileImageUrl!)
                              : null,
                          child: user?.profileImageUrl == null
                              ? const Icon(Icons.person, size: 48)
                              : null,
                        ),
                        if (_isUploadingImage)
                          const CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.black26,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _isUploadingImage ? null : _showImageOptions,
                      icon: const Icon(Icons.camera_alt, size: 16),
                      label: const Text('이미지 변경'),
                    ),
                    Text(
                      user?.email ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                    Text(
                      '${user?.provider ?? ''} 계정',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                    ),
                    const SizedBox(height: 32),
                    // Nickname field
                    TextFormField(
                      controller: _nicknameController,
                      decoration: const InputDecoration(
                        labelText: '닉네임',
                        hintText: '닉네임을 입력하세요',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      maxLength: 50,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '닉네임을 입력해주세요';
                        }
                        if (value.trim().length > 50) {
                          return '닉네임은 50자 이내로 입력해주세요';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _onSubmit,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('저장'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
