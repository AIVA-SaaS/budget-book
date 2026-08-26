import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:budget_book/core/bloc/month_cubit.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/storage/secure_storage.dart';
import 'package:budget_book/core/websocket/websocket_bloc.dart';
import 'package:budget_book/core/websocket/websocket_event.dart';
import 'package:budget_book/core/websocket/websocket_state.dart';
import 'package:budget_book/core/websocket/websocket_service.dart';
import 'package:budget_book/core/widgets/offline_banner.dart';
import 'package:budget_book/core/services/connectivity_service.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:budget_book/features/auth/presentation/bloc/auth_state.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_state.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_bloc.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';
import '../../core/theme/bb_scale.dart';

class MainShellPage extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellPage({super.key, required this.navigationShell});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  // 회차 1 (2026-05-10) — defect A fix.
  // 이전: `int _previousIndex = 0;` 가 _onDestinationSelected 내부에서만
  // 갱신 → context.go (asset card → /transactions) 같은 cross-branch 진입
  // 시에는 미갱신 → 다음 BottomNav 거래 탭 시 stale previousIndex 와 비교 →
  // `index != previousIndex` 분기 진입 → 불필요한 stale LoadTransactions 발사.
  // navigationShell.currentIndex 가 cross-branch 도 포함한 실제 진입 추적자.
  // didUpdateWidget 으로 동기화하여 항상 최신.
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.navigationShell.currentIndex;
    _connectWebSocketIfAuthenticated();
    _preloadCommonData();
    _promptEmailRegistrationIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MainShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // cross-branch context.go 후 GoRouter 가 navigationShell 을 새 currentIndex
    // 로 rebuild. _previousIndex 를 이 변경에 동기화하여 다음 BottomNav 탭 시
    // 정확한 비교가 되도록.
    _previousIndex = widget.navigationShell.currentIndex;
  }

  void _preloadCommonData() {
    // Pre-load categories, payment methods, favorites, and couple state
    getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
    getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
    getIt<FavoritesBloc>().add(const LoadFavorites());
    getIt<CoupleBloc>().add(const LoadCouple());
  }

  /// Kakao users who did not consent to email sharing are stored with a
  /// placeholder email. Prompt them once per shell entry to register a real
  /// email (required for partner linking + account recovery).
  void _promptEmailRegistrationIfNeeded() {
    final authState = getIt<AuthBloc>().state;
    if (authState is AuthAuthenticated && !authState.user.hasRegisteredEmail) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('이메일 등록 안내'),
            content: const Text(
              '계정에 이메일이 등록되어 있지 않습니다.\n'
              '파트너 연결과 계정 보호를 위해 이메일을 등록해 주세요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('나중에'),
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
      });
    }
  }

  Future<void> _connectWebSocketIfAuthenticated() async {
    final authState = getIt<AuthBloc>().state;
    if (authState is AuthAuthenticated && authState.user.coupleId != null) {
      final token = await getIt<SecureStorageService>().getAccessToken();
      if (token != null) {
        getIt<WebSocketBloc>().add(WebSocketConnect(
          baseUrl: ApiEndpoints.baseUrl,
          accessToken: token,
          coupleId: authState.user.coupleId!,
          currentUserId: authState.user.id,
        ));
      }
    }
  }

  void _onDestinationSelected(int index) {
    final previousIndex = _previousIndex;
    _previousIndex = index;

    // Phase 25 Step 13/14 — 예산/통계 탭 제거. 4탭 최종 인덱스 매핑:
    // 0:거래, 1:분석, 2:자산, 3:더보기
    if (index != previousIndex) {
      // 회차 12 P2 Phase A (2026-05-03) — `now.year/month` 강제 사용 회귀 fix.
      // MonthCubit 단일 source of truth. BottomNav 탭 전환 시 사용자가 보던
      // month 유지. 이전 회귀: 4월 보던 중 BottomNav 거래 탭 클릭 시 5월로 reset.
      final monthState = getIt<MonthCubit>().state;
      switch (index) {
        case 0:
          // 회차 1 (2026-05-10) — defect A follow-up.
          // 회차 9 (2026-04-28) 의 case 0 LoadTransactions 가 매 탭 전환마다
          // 발사되어 router builder 의 dispatch 와 중복 / 충돌 — Network 측정
          // 으로 동일 탭 진입 시 2~4 회 LoadTransactions 가 fired 됨을 확인.
          // 회차 12 P2 Phase A 의 "BottomNav 탭 시 month reset 회귀" 만 보호:
          // BLoC state 의 month 가 MonthCubit 의 month 와 다를 때만 reload.
          // 그 외에는 case 0 가 reload 하지 않음 (router builder + didUpdateWidget
          // 가 처리).
          final txnBloc = getIt<TransactionBloc>();
          final txnState = txnBloc.state;
          final blocMonthDiffers = txnState is TransactionLoaded &&
              (txnState.year != monthState.year ||
                  txnState.month != monthState.month);
          if (blocMonthDiffers) {
            // 2026-07-27 — 필드 나열 제거(needsReviewOnly 누락 fix). VO 전체 전달.
            txnBloc.add(LoadTransactions.fromFilter(
              monthState.year,
              monthState.month,
              txnBloc.currentFilter,
            ));
          }
        // Tab 1 (Analysis) — wrapper 가 자체 BudgetBloc/StatisticsBloc 처리
        case 2:
          // Tab 2 (Assets) — refresh payment method data + card settlement summary
          getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
          getIt<PaymentMethodBloc>().add(
              LoadCardSettlementSummary(year: monthState.year, month: monthState.month));
        // Tab 3 (Settings) needs no refresh
      }
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      bloc: getIt<AuthBloc>(),
      listener: (context, state) {
        if (state is AuthAuthenticated && state.user.coupleId != null) {
          _connectWebSocketIfAuthenticated();
        } else if (state is AuthUnauthenticated) {
          getIt<WebSocketBloc>().add(const WebSocketDisconnect());
        }
      },
      child: Scaffold(
      body: SafeArea(
        bottom: false, // Bottom is handled by NavigationBar
        child: Column(
          children: [
            OfflineBanner(
              connectivityService: getIt<ConnectivityService>(),
            ),
            _ConnectionStatusBanner(
              onReconnect: _connectWebSocketIfAuthenticated,
            ),
            Expanded(child: widget.navigationShell),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        // Phase 25 Step 13/14 — 4탭 최종: [거래][분석][자산][더보기].
        // 예산/통계는 분석 탭 안의 [예산][통계] sub-tab 으로 통합됨.
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '거래',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: '분석',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: '자산',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '더보기',
          ),
        ],
      ),
      ),
    );
  }
}

class _ConnectionStatusBanner extends StatelessWidget {
  final VoidCallback onReconnect;

  const _ConnectionStatusBanner({required this.onReconnect});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WebSocketBloc, WebSocketState>(
      builder: (context, state) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return SizeTransition(
              sizeFactor: animation,
              axisAlignment: -1.0,
              child: child,
            );
          },
          child: _buildBanner(context, state.connectionStatus, onReconnect),
        );
      },
    );
  }

  Widget _buildBanner(
    BuildContext context,
    WebSocketConnectionStatus status,
    VoidCallback onReconnect,
  ) {
    switch (status) {
      case WebSocketConnectionStatus.connected:
        // Don't show anything when connected to avoid clutter
        return const SizedBox.shrink(key: ValueKey('connected'));
      case WebSocketConnectionStatus.reconnecting:
        // Silent background reconnection - don't bother user
        return const SizedBox.shrink(key: ValueKey('reconnecting'));
      case WebSocketConnectionStatus.disconnected:
        return Container(
          key: const ValueKey('disconnected'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.red.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off,
                size: context.bbType.iconSm,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                '오프라인 - 실시간 동기화 중단',
                style: TextStyle(
                  fontSize: context.bbType.label,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onReconnect,
                child: Text(
                  '재연결',
                  style: TextStyle(
                    fontSize: context.bbType.label,
                    color: Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}
