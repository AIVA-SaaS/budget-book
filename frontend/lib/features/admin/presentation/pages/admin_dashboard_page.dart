import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';

/// Admin dashboard page showing system statistics.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;

  int _totalUsers = 0;
  int _totalCouples = 0;
  int _totalTransactions = 0;
  int _newUsersThisMonth = 0;
  int _newUsersLastMonth = 0;
  int _activeUsersLast30Days = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await getIt<ApiClient>().dio.get(ApiEndpoints.adminStats);
      final data = response.data['data'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _totalUsers = (data['totalUsers'] as num?)?.toInt() ?? 0;
          _totalCouples = (data['totalCouples'] as num?)?.toInt() ?? 0;
          _totalTransactions =
              (data['totalTransactions'] as num?)?.toInt() ?? 0;
          _newUsersThisMonth =
              (data['newUsersThisMonth'] as num?)?.toInt() ?? 0;
          _newUsersLastMonth =
              (data['newUsersLastMonth'] as num?)?.toInt() ?? 0;
          _activeUsersLast30Days =
              (data['activeUsersLast30Days'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 대시보드'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: '사용자 관리',
            onPressed: () => context.push('/admin/users'),
          ),
          IconButton(
            icon: const Icon(Icons.campaign),
            tooltip: '공지사항 관리',
            onPressed: () => context.push('/admin/announcements'),
          ),
          IconButton(
            icon: const Icon(Icons.feedback),
            tooltip: '피드백 관리',
            onPressed: () => context.push('/admin/feedback'),
          ),
          IconButton(
            icon: const Icon(Icons.new_releases),
            tooltip: '배포 노트 관리',
            onPressed: () => context.push('/admin/releases'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('오류: $_error'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadStats,
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount =
                          constraints.maxWidth > 600 ? 2 : 1;
                      return GridView.count(
                        crossAxisCount: crossAxisCount,
                        padding: const EdgeInsets.all(16),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: crossAxisCount == 2 ? 2.0 : 3.0,
                        children: [
                          _StatCard(
                            icon: Icons.people,
                            label: '총 사용자 수',
                            count: _totalUsers,
                            color: Colors.blue,
                          ),
                          _StatCard(
                            icon: Icons.favorite,
                            label: '총 커플 수',
                            count: _totalCouples,
                            color: Colors.pink,
                          ),
                          _StatCard(
                            icon: Icons.receipt_long,
                            label: '총 거래 수',
                            count: _totalTransactions,
                            color: Colors.green,
                          ),
                          _StatCard(
                            icon: Icons.person_add,
                            label: '이번 달 신규 사용자',
                            count: _newUsersThisMonth,
                            color: Colors.orange,
                          ),
                          _StatCard(
                            icon: Icons.person_add_alt,
                            label: '지난 달 신규 사용자',
                            count: _newUsersLastMonth,
                            color: Colors.purple,
                          ),
                          _StatCard(
                            icon: Icons.trending_up,
                            label: '최근 30일 활성 사용자',
                            count: _activeUsersLast30Days,
                            color: Colors.teal,
                          ),
                        ],
                      );
                    },
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
