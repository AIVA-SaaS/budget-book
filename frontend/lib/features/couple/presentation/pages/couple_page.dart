import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_state.dart';
import 'package:budget_book/features/couple/presentation/widgets/couple_info_widget.dart';
import 'package:budget_book/features/couple/presentation/widgets/invitation_code_widget.dart';

class CouplePage extends StatefulWidget {
  const CouplePage({super.key});

  @override
  State<CouplePage> createState() => _CouplePageState();
}

class _CouplePageState extends State<CouplePage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CoupleBloc, CoupleState>(
      listener: (context, state) {
        if (state is CoupleError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state is CoupleLinked) {
          // Refresh auth state to update coupleId so router guard is aware
          context.read<AuthBloc>().add(const AuthRefreshUser());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('커플 연결'),
          automaticallyImplyLeading: Navigator.canPop(context),
        ),
        body: BlocBuilder<CoupleBloc, CoupleState>(
          builder: (context, state) {
            return switch (state) {
              CoupleInitial() || CoupleLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              CoupleNotLinked() => _buildNotLinked(context),
              CoupleInvitationPending(invitation: final inv) =>
                _buildInvitationPending(context, inv),
              CoupleInvitationExpired(invitation: final inv) =>
                _buildInvitationExpired(context, inv),
              CoupleLinked(couple: final couple) =>
                _buildLinked(context, couple),
              CoupleError() => _buildNotLinked(context),
            };
          },
        ),
      ),
    );
  }

  Widget _buildNotLinked(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            '파트너와 연결하세요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '초대 코드를 생성하거나 파트너의 코드를 입력하세요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 40),
          // Generate invitation
          FilledButton.icon(
            onPressed: () {
              context.read<CoupleBloc>().add(const GenerateInvitation());
            },
            icon: const Icon(Icons.add_link),
            label: const Text('초대 코드 생성'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),
          // Accept invitation
          Text(
            '초대 코드 입력',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            decoration: const InputDecoration(
              hintText: '8자리 코드 입력',
              prefixIcon: Icon(Icons.vpn_key),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              final code = _codeController.text.trim();
              if (code.length == 8) {
                context.read<CoupleBloc>().add(AcceptInvitation(code));
                _codeController.clear();
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('코드로 연결'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationPending(
      BuildContext context, dynamic invitation) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          InvitationCodeWidget(invitation: invitation),
          const SizedBox(height: 24),
          Text(
            '파트너에게 위 코드를 공유하세요.\n파트너가 코드를 입력하면 자동으로 연결됩니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              context.read<CoupleBloc>().add(const CheckInvitationStatus());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('연결 상태 확인'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              context.read<CoupleBloc>().add(const GenerateInvitation());
            },
            child: const Text('새 코드 생성'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationExpired(BuildContext context, dynamic invitation) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Icon(
            Icons.timer_off,
            size: 80,
            color: Theme.of(context)
                .colorScheme
                .error
                .withValues(alpha: 0.7),
          ),
          const SizedBox(height: 24),
          Text(
            '초대 코드가 만료되었습니다',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          // Show expired code (dimmed, strikethrough)
          Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                invitation.code as String,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      decoration: TextDecoration.lineThrough,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3),
                    ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () {
              context.read<CoupleBloc>().add(const GenerateInvitation());
            },
            icon: const Icon(Icons.add_link),
            label: const Text('새 코드 발급'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),
          // Accept invitation section (connect with partner's code)
          Text(
            '초대 코드 입력',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            decoration: const InputDecoration(
              hintText: '8자리 코드 입력',
              prefixIcon: Icon(Icons.vpn_key),
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              final code = _codeController.text.trim();
              if (code.length == 8) {
                context.read<CoupleBloc>().add(AcceptInvitation(code));
                _codeController.clear();
              }
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('코드로 연결'),
          ),
        ],
      ),
    );
  }

  Widget _buildLinked(BuildContext context, dynamic couple) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.favorite,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '커플 연결 완료',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 24),
          CoupleInfoWidget(partner: couple.partner),
          const SizedBox(height: 32),
          // Navigate to home
          FilledButton.icon(
            onPressed: () {
              // Ensure auth state is fresh, then navigate
              context.read<AuthBloc>().add(const AuthRefreshUser());
              context.go('/home');
            },
            icon: const Icon(Icons.home),
            label: const Text('홈으로 이동'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showDissolveDialog(context),
            icon: const Icon(Icons.link_off, color: Colors.red),
            label: const Text('연결 해제'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
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
        title: const Text('커플 연결 해제'),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('해제'),
          ),
        ],
      ),
    );
  }
}
