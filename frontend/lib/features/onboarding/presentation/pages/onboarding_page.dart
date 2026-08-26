import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/router/app_router.dart' show markOnboardingCompleted;
import '../../../../core/theme/bb_scale.dart';

/// A 3-step onboarding flow shown once after first login.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage < 2) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeOnboarding() async {
    await markOnboardingCompleted();
    if (mounted) context.go('/home');
  }

  Future<void> _goToCouplePage() async {
    await markOnboardingCompleted();
    if (mounted) context.go('/couple');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                children: [
                  _WelcomeStep(),
                  _CoupleStep(
                    onConnect: _goToCouplePage,
                    onSkip: _goToNextPage,
                  ),
                  _StartStep(
                    onStart: _completeOnboarding,
                  ),
                ],
              ),
            ),
            // Dot indicators
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.2),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          Text(
            '환영합니다',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          Text(
            'Budget Book으로 똑똑하게 가계부를 관리하세요',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CoupleStep extends StatelessWidget {
  final VoidCallback onConnect;
  final VoidCallback onSkip;

  const _CoupleStep({
    required this.onConnect,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          Text(
            '파트너와 함께',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          Text(
            '파트너와 연결하면 수입/지출을 공유하고\n함께 예산을 관리할 수 있어요',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          FilledButton(
            onPressed: onConnect,
            child: const Text('파트너 연결하기'),
          ),
          context.bbSpace.gapV(BbSpaceToken.xl),
          TextButton(
            onPressed: onSkip,
            child: const Text('혼자 사용할게요'),
          ),
        ],
      ),
    );
  }
}

class _StartStep extends StatelessWidget {
  final VoidCallback onStart;

  const _StartStep({required this.onStart});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          Text(
            '준비 완료!',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          context.bbSpace.gapV(BbSpaceToken.xxl),
          Text(
            '첫 거래를 기록해보세요',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          context.bbSpace.gapV(BbSpaceToken.block),
          FilledButton(
            onPressed: onStart,
            child: const Text('시작하기'),
          ),
        ],
      ),
    );
  }
}
