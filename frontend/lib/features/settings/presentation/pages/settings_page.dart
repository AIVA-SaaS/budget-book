import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) {
          context.go('/login');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('설정'),
        ),
        body: ListView(
          children: [
            // Couple management
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('커플 관리'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/couple'),
            ),
            const Divider(),
            // Categories
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('카테고리 관리'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/categories'),
            ),
            // Category Groups
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('카테고리 그룹'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/category-groups'),
            ),
            // Payment Methods
            ListTile(
              leading: const Icon(Icons.payment),
              title: const Text('결제수단 관리'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/payment-methods'),
            ),
            // Recurring Transactions
            ListTile(
              leading: const Icon(Icons.repeat),
              title: const Text('반복 거래'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/recurring'),
            ),
            const Divider(),
            // Logout
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                '로그아웃',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('로그아웃'),
                    content: const Text('정말 로그아웃하시겠습니까?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          context
                              .read<AuthBloc>()
                              .add(const AuthLogoutRequested());
                        },
                        child: const Text('로그아웃'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
