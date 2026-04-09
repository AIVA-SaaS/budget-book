import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';

class PartnerManagementPage extends StatelessWidget {
  const PartnerManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('파트너 관리'),
      ),
      body: BlocConsumer<CoupleBloc, CoupleState>(
        listener: (context, state) {
          if (state is CoupleError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          } else if (state is CoupleLinked && state.couple.isCouple) {
            // Partner linked — refresh auth state
            context.read<AuthBloc>().add(const AuthRefreshUser());
          } else if (state is CoupleNotLinked) {
            // Dissolved — refresh auth state
            context.read<AuthBloc>().add(const AuthRefreshUser());
          }
        },
        builder: (context, state) {
          return switch (state) {
            CoupleInitial() || CoupleLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            CoupleLinked(couple: final couple) => couple.isCouple
                ? _buildCoupleMode(context, couple)
                : _buildPersonalMode(context),
            _ => _buildPersonalMode(context),
          };
        },
      ),
    );
  }

  Widget _buildPersonalMode(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.person,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '개인 가계부',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '파트너와 함께 사용하면 수입/지출을 공유하고\n함께 예산을 관리할 수 있어요',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Invite partner
          FilledButton.icon(
            onPressed: () => context.push('/couple'),
            icon: const Icon(Icons.person_add),
            label: const Text('파트너 초대하기'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          // Accept invitation
          OutlinedButton.icon(
            onPressed: () => context.push('/couple'),
            icon: const Icon(Icons.vpn_key),
            label: const Text('초대코드 입력'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoupleMode(BuildContext context, dynamic couple) {
    final partner = couple.partner;
    final dateFormat = DateFormat('yyyy.MM.dd');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '함께 사용 중',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Partner info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: partner.profileImageUrl != null
                        ? NetworkImage(partner.profileImageUrl!)
                        : null,
                    child: partner.profileImageUrl == null
                        ? Text(
                            partner.nickname.isNotEmpty
                                ? partner.nickname[0]
                                : '?',
                            style: const TextStyle(fontSize: 24),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          partner.nickname,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '연결일: ${dateFormat.format(couple.createdAt)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Dissolve button
          OutlinedButton.icon(
            onPressed: () => _showDissolveDialog(context),
            icon: const Icon(Icons.link_off),
            label: const Text('연결 해제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showDissolveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('파트너 연결 해제'),
        content: const Text(
          '정말 연결을 해제하시겠습니까?\n공유된 데이터는 유지되지만 더 이상 공유되지 않습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<CoupleBloc>().add(const DissolveCouple());
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('해제'),
          ),
        ],
      ),
    );
  }
}
