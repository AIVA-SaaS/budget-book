import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

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
import 'package:budget_book/features/category_group/presentation/bloc/category_group_bloc.dart';
import 'package:budget_book/features/category_group/presentation/bloc/category_group_event.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_bloc.dart';
import 'package:budget_book/features/payment_method/presentation/bloc/payment_method_event.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_bloc.dart';
import 'package:budget_book/features/preference/presentation/bloc/favorites_event.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_bloc.dart';
import 'package:budget_book/features/couple/presentation/bloc/couple_event.dart';

class MainShellPage extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellPage({super.key, required this.navigationShell});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _connectWebSocketIfAuthenticated();
    _preloadCommonData();
  }

  void _preloadCommonData() {
    // Pre-load categories, payment methods, favorites, and couple state
    getIt<CategoryGroupBloc>().add(const LoadCategoryGroups());
    getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
    getIt<FavoritesBloc>().add(const LoadFavorites());
    getIt<CoupleBloc>().add(const LoadCouple());
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
      final now = DateTime.now();
      switch (index) {
        case 0:
          // 회차 9 (2026-04-28) — 탭 전환 시 LoadTransactions 호출 시 currentFilter 보존.
          // 이전 회귀: visibility 등 필터가 reset 되어 chip 표시는 유지되나 list 는 전체 노출.
          final txnBloc = getIt<TransactionBloc>();
          final f = txnBloc.currentFilter;
          txnBloc.add(LoadTransactions(
            year: now.year, month: now.month,
            keyword: f.keyword,
            categoryId: f.categoryId,
            categoryIds: f.categoryIds,
            categoryGroupIds: f.categoryGroupIds,
            paymentMethodId: f.paymentMethodId,
            paymentMethodIds: f.paymentMethodIds,
            pocketId: f.pocketId,
            pocketIds: f.pocketIds,
            amountMin: f.amountMin,
            amountMax: f.amountMax,
            dateFrom: f.dateFrom,
            dateTo: f.dateTo,
            type: f.type,
            transactionTypes: f.transactionTypes,
            visibility: f.visibility,
          ));
        // Tab 1 (Analysis) — wrapper 가 자체 BudgetBloc/StatisticsBloc 처리
        case 2:
          // Tab 2 (Assets) — refresh payment method data + card settlement summary
          getIt<PaymentMethodBloc>().add(const LoadPaymentMethods());
          getIt<PaymentMethodBloc>().add(
              LoadCardSettlementSummary(year: now.year, month: now.month));
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
                size: 14,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                '오프라인 - 실시간 동기화 중단',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade900,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onReconnect,
                child: Text(
                  '재연결',
                  style: TextStyle(
                    fontSize: 12,
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
