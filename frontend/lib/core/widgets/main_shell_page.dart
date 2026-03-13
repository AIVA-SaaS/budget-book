import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/websocket/websocket_bloc.dart';
import 'package:budget_book/core/websocket/websocket_state.dart';
import 'package:budget_book/core/websocket/websocket_service.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_bloc.dart';
import 'package:budget_book/features/home/presentation/bloc/dashboard_event.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:budget_book/features/transaction/presentation/bloc/transaction_event.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_bloc.dart';
import 'package:budget_book/features/budget/presentation/bloc/budget_event.dart';

class MainShellPage extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellPage({super.key, required this.navigationShell});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _previousIndex = 0;

  void _onDestinationSelected(int index) {
    final previousIndex = _previousIndex;
    _previousIndex = index;

    // Refresh data when switching to a different tab
    if (index != previousIndex) {
      final now = DateTime.now();
      switch (index) {
        case 0:
          getIt<DashboardBloc>()
              .add(LoadDashboard(year: now.year, month: now.month));
        case 1:
          getIt<TransactionBloc>()
              .add(LoadTransactions(year: now.year, month: now.month));
        case 2:
          getIt<BudgetBloc>()
              .add(LoadBudgets(year: now.year, month: now.month));
        // Tab 3 (Statistics) uses factory, loaded fresh by its builder
        // Tab 4 (Settings) needs no refresh
      }
    }

    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false, // Bottom is handled by NavigationBar
        child: Column(
          children: [
            const _ConnectionStatusBanner(),
            Expanded(child: widget.navigationShell),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: '거래',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: '예산',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: '통계',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }
}

class _ConnectionStatusBanner extends StatelessWidget {
  const _ConnectionStatusBanner();

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
          child: _buildBanner(context, state.connectionStatus),
        );
      },
    );
  }

  Widget _buildBanner(
    BuildContext context,
    WebSocketConnectionStatus status,
  ) {
    switch (status) {
      case WebSocketConnectionStatus.connected:
        // Don't show anything when connected to avoid clutter
        return const SizedBox.shrink(key: ValueKey('connected'));
      case WebSocketConnectionStatus.reconnecting:
        return Container(
          key: const ValueKey('reconnecting'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          color: Colors.orange.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.orange.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '연결 중...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade900,
                ),
              ),
            ],
          ),
        );
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
            ],
          ),
        );
    }
  }
}
