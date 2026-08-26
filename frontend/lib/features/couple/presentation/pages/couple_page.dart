import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/core/theme/bb_scale.dart';
import 'package:budget_book/core/widgets/bb_wide_button.dart';
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

  /// Shown when the partner-link API rejects a placeholder-email user
  /// (BE returns EMAIL_REQUIRED_FOR_COUPLE). Guides the user to register
  /// a real email in the profile-edit screen before linking a partner.
  void _showEmailRequiredDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('이메일 등록 필요'),
        content: const Text(
          '파트너 연결 전 이메일 등록이 필요합니다.\n정보 수정 화면에서 이메일을 등록해 주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.push('/settings/profile-edit');
            },
            child: const Text('이메일 등록'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CoupleBloc, CoupleState>(
      listener: (context, state) {
        if (state is CoupleError) {
          if (state.errorCode == 'EMAIL_REQUIRED_FOR_COUPLE') {
            _showEmailRequiredDialog(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        } else if (state is CoupleLinked) {
          // Refresh auth state to update coupleId so router guard is aware
          context.read<AuthBloc>().add(const AuthRefreshUser());
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('파트너 연결'),
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
              CoupleLinked(couple: final couple) => couple.isCouple
                  ? _buildLinked(context, couple)
                  : _buildSelfCouple(context),
              CoupleError() => _buildNotLinked(context),
            };
          },
        ),
      ),
    );
  }

  /// Self-couple state: user has a couple record but no partner.
  /// Offer to invite a partner or continue as personal.
  Widget _buildSelfCouple(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.person,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          Text(
            '개인 가계부로 사용 중',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          context.bbSpace.gapV(BbSpaceToken.lg),
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
          context.bbSpace.gapV(BbSpaceToken.block),
          // Generate invitation
          BbWideButton(
            label: '파트너 초대하기',
            icon: Icons.add_link,
            onPressed: () {
              context.read<CoupleBloc>().add(const GenerateInvitation());
            },
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          const Divider(),
          context.bbSpace.gapV(BbSpaceToken.block),
          // Accept invitation
          Text(
            '초대 코드 입력',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          context.bbSpace.gapV(BbSpaceToken.xl),
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
          context.bbSpace.gapV(BbSpaceToken.xl),
          OutlinedButton(
            onPressed: () {
              final code = _codeController.text.trim();
              if (code.length == 8) {
                context.read<CoupleBloc>().add(AcceptInvitation(code));
                _codeController.clear();
              }
            },
            style: OutlinedButton.styleFrom(
              padding: context.bbSpace
                  .symmetric(h: BbSpaceToken.md, v: BbSpaceToken.xl),
            ),
            child: const Text('코드로 연결'),
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          // Skip — go home
          TextButton(
            onPressed: () {
              context.read<AuthBloc>().add(const AuthRefreshUser());
              context.go('/home');
            },
            child: const Text('나중에 연결하기'),
          ),
        ],
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
            Icons.person_add,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          Text(
            '파트너와 연결하세요',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          context.bbSpace.gapV(BbSpaceToken.lg),
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
          context.bbSpace.gapV(BbSpaceToken.block),
          // Generate invitation
          BbWideButton(
            label: '초대 코드 생성',
            icon: Icons.add_link,
            onPressed: () {
              context.read<CoupleBloc>().add(const GenerateInvitation());
            },
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          const Divider(),
          context.bbSpace.gapV(BbSpaceToken.block),
          // Accept invitation
          Text(
            '초대 코드 입력',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          context.bbSpace.gapV(BbSpaceToken.xl),
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
          context.bbSpace.gapV(BbSpaceToken.xl),
          OutlinedButton(
            onPressed: () {
              final code = _codeController.text.trim();
              if (code.length == 8) {
                context.read<CoupleBloc>().add(AcceptInvitation(code));
                _codeController.clear();
              }
            },
            style: OutlinedButton.styleFrom(
              padding: context.bbSpace
                  .symmetric(h: BbSpaceToken.md, v: BbSpaceToken.xl),
            ),
            child: const Text('코드로 연결'),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationPending(BuildContext context, dynamic invitation) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          context.bbSpace.gapV(BbSpaceToken.block),
          InvitationCodeWidget(invitation: invitation),
          context.bbSpace.gapV(BbSpaceToken.block),
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
          context.bbSpace.gapV(BbSpaceToken.block),
          BbWideButton(
            label: '연결 상태 확인',
            icon: Icons.refresh,
            onPressed: () {
              context.read<CoupleBloc>().add(const CheckInvitationStatus());
            },
          ),
          context.bbSpace.gapV(BbSpaceToken.xl),
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
          context.bbSpace.gapV(BbSpaceToken.block),
          Icon(
            Icons.timer_off,
            size: 80,
            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          Text(
            '초대 코드가 만료되었습니다',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          // Show expired code (dimmed, strikethrough)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
          context.bbSpace.gapV(BbSpaceToken.block),
          BbWideButton(
            label: '새 코드 발급',
            icon: Icons.add_link,
            onPressed: () {
              context.read<CoupleBloc>().add(const GenerateInvitation());
            },
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          const Divider(),
          context.bbSpace.gapV(BbSpaceToken.block),
          // Accept invitation section (connect with partner's code)
          Text(
            '초대 코드 입력',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          context.bbSpace.gapV(BbSpaceToken.xl),
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
          context.bbSpace.gapV(BbSpaceToken.xl),
          OutlinedButton(
            onPressed: () {
              final code = _codeController.text.trim();
              if (code.length == 8) {
                context.read<CoupleBloc>().add(AcceptInvitation(code));
                _codeController.clear();
              }
            },
            style: OutlinedButton.styleFrom(
              padding: context.bbSpace
                  .symmetric(h: BbSpaceToken.md, v: BbSpaceToken.xl),
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
          context.bbSpace.gapV(BbSpaceToken.xxl),
          Text(
            '파트너 연결 완료',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          CoupleInfoWidget(partner: couple.partner),
          context.bbSpace.gapV(BbSpaceToken.block),
          // Navigate to home
          BbWideButton(
            label: '홈으로 이동',
            icon: Icons.home,
            onPressed: () {
              // Ensure auth state is fresh, then navigate
              context.read<AuthBloc>().add(const AuthRefreshUser());
              context.go('/home');
            },
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('해제'),
          ),
        ],
      ),
    );
  }
}
