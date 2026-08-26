import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';
import '../../../../core/theme/bb_scale.dart';

/// Admin user management page.
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  bool _loading = false;
  String? _error;
  List<_AdminUser> _users = [];
  int _page = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadUsers({bool reset = true}) async {
    if (reset) {
      setState(() {
        _page = 0;
        _users = [];
        _hasMore = true;
      });
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await getIt<ApiClient>().dio.get(
        ApiEndpoints.adminUsers,
        queryParameters: {
          'page': _page,
          'size': 20,
          'search': _searchController.text,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final content = (data['content'] as List<dynamic>?) ?? [];
      final totalPages = (data['totalPages'] as num?)?.toInt() ?? 0;
      final users = content
          .map((e) => _AdminUser.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        setState(() {
          _users = reset ? users : [..._users, ...users];
          _hasMore = _page + 1 < totalPages;
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

  Future<void> _loadMore() async {
    _page++;
    await _loadUsers(reset: false);
  }

  Future<void> _toggleUserActive(_AdminUser user) async {
    final endpoint = user.active
        ? '${ApiEndpoints.adminUsers}/${user.id}/deactivate'
        : '${ApiEndpoints.adminUsers}/${user.id}/activate';
    try {
      await getIt<ApiClient>().dio.patch(endpoint);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(user.active
                ? '${user.nickname} 계정이 비활성화되었습니다'
                : '${user.nickname} 계정이 활성화되었습니다'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용자 관리'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '이메일 또는 닉네임으로 검색',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadUsers();
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _loadUsers(),
            ),
          ),
          // User list
          Expanded(
            child: _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('오류: $_error'),
                        context.bbSpace.gapV(BbSpaceToken.xxl),
                        FilledButton(
                          onPressed: _loadUsers,
                          child: const Text('재시도'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadUsers,
                    child: _users.isEmpty && !_loading
                        ? ListView(
                            // ★`gapV` 는 토큰을 읽으므로 const 목록에서 나와야 한다.
                            children: [
                              context.bbSpace.gapV(BbSpaceToken.block),
                              const Center(child: Text('사용자가 없습니다')),
                            ],
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _users.length + (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= _users.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final user = _users[index];
                              return _UserListTile(
                                user: user,
                                onToggleActive: () => _toggleUserActive(user),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _UserListTile extends StatelessWidget {
  final _AdminUser user;
  final VoidCallback onToggleActive;

  const _UserListTile({
    required this.user,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.profileImageUrl != null
            ? NetworkImage(user.profileImageUrl!)
            : null,
        child: user.profileImageUrl == null
            ? const Icon(Icons.person)
            : null,
      ),
      title: Row(
        children: [
          Flexible(child: Text(user.nickname)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: user.role == 'ADMIN'
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              user.role,
              style: TextStyle(
                fontSize: context.bbType.caption,
                fontWeight: FontWeight.bold,
                color: user.role == 'ADMIN' ? Colors.red : Colors.blue,
              ),
            ),
          ),
          if (!user.active) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '비활성',
                style: TextStyle(
                  fontSize: context.bbType.caption,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text('${user.email}  |  가입: ${dateFormat.format(user.createdAt)}'),
      trailing: IconButton(
        icon: Icon(
          user.active ? Icons.block : Icons.check_circle_outline,
          color: user.active ? Colors.red : Colors.green,
        ),
        tooltip: user.active ? '비활성화' : '활성화',
        onPressed: () {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(user.active ? '계정 비활성화' : '계정 활성화'),
              content: Text(
                user.active
                    ? '${user.nickname} 계정을 비활성화하시겠습니까?'
                    : '${user.nickname} 계정을 활성화하시겠습니까?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onToggleActive();
                  },
                  child: Text(user.active ? '비활성화' : '활성화'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdminUser {
  final String id;
  final String email;
  final String nickname;
  final String? profileImageUrl;
  final String role;
  final bool active;
  final DateTime createdAt;

  _AdminUser({
    required this.id,
    required this.email,
    required this.nickname,
    this.profileImageUrl,
    required this.role,
    required this.active,
    required this.createdAt,
  });

  factory _AdminUser.fromJson(Map<String, dynamic> json) {
    return _AdminUser(
      id: json['id'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      role: (json['role'] as String?) ?? 'USER',
      active: (json['active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
