import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';

/// Admin announcement management page.
class AdminAnnouncementsPage extends StatefulWidget {
  const AdminAnnouncementsPage({super.key});

  @override
  State<AdminAnnouncementsPage> createState() =>
      _AdminAnnouncementsPageState();
}

class _AdminAnnouncementsPageState extends State<AdminAnnouncementsPage> {
  bool _loading = true;
  String? _error;
  List<_Announcement> _announcements = [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await getIt<ApiClient>().dio.get(ApiEndpoints.adminAnnouncements);
      final data = response.data['data'] as List<dynamic>;
      if (mounted) {
        setState(() {
          _announcements = data
              .map((e) => _Announcement.fromJson(e as Map<String, dynamic>))
              .toList();
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

  Future<void> _createAnnouncement(
      String title, String content, bool isActive) async {
    try {
      await getIt<ApiClient>().dio.post(
        ApiEndpoints.adminAnnouncements,
        data: {'title': title, 'content': content, 'active': isActive},
      );
      await _loadAnnouncements();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('생성 실패: $e')),
        );
      }
    }
  }

  Future<void> _updateAnnouncement(
      String id, String title, String content, bool isActive) async {
    try {
      await getIt<ApiClient>().dio.put(
        '${ApiEndpoints.adminAnnouncements}/$id',
        data: {'title': title, 'content': content, 'active': isActive},
      );
      await _loadAnnouncements();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('수정 실패: $e')),
        );
      }
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    try {
      await getIt<ApiClient>().dio.delete(
        '${ApiEndpoints.adminAnnouncements}/$id',
      );
      await _loadAnnouncements();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('삭제 실패: $e')),
        );
      }
    }
  }

  void _showFormDialog({_Announcement? existing}) {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final contentController =
        TextEditingController(text: existing?.content ?? '');
    bool isActive = existing?.active ?? true;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(existing == null ? '공지사항 작성' : '공지사항 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  decoration: const InputDecoration(
                    labelText: '내용',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('활성화'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                final title = titleController.text.trim();
                final content = contentController.text.trim();
                if (title.isEmpty) return;
                if (existing == null) {
                  _createAnnouncement(title, content, isActive);
                } else {
                  _updateAnnouncement(existing.id, title, content, isActive);
                }
              },
              child: Text(existing == null ? '작성' : '수정'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('공지사항 관리'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showFormDialog(),
        tooltip: '공지사항 작성',
        child: const Icon(Icons.add),
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
                        onPressed: _loadAnnouncements,
                        child: const Text('재시도'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnnouncements,
                  child: _announcements.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 100),
                            Center(child: Text('공지사항이 없습니다')),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _announcements.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _announcements.length) {
                              return const SizedBox(height: 88);
                            }
                            final ann = _announcements[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: ListTile(
                                leading: Icon(
                                  ann.active
                                      ? Icons.campaign
                                      : Icons.campaign_outlined,
                                  color:
                                      ann.active ? Colors.orange : Colors.grey,
                                ),
                                title: Text(ann.title),
                                subtitle: Text(
                                  '${ann.active ? "활성" : "비활성"}  |  ${dateFormat.format(ann.createdAt)}',
                                ),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _showFormDialog(existing: ann);
                                    } else if (value == 'delete') {
                                      _confirmDelete(ann);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('수정'),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('삭제',
                                          style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  void _confirmDelete(_Announcement ann) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('공지사항 삭제'),
        content: Text('"${ann.title}"을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteAnnouncement(ann.id);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

class _Announcement {
  final String id;
  final String title;
  final String content;
  final bool active;
  final DateTime createdAt;

  _Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.active,
    required this.createdAt,
  });

  factory _Announcement.fromJson(Map<String, dynamic> json) {
    return _Announcement(
      id: json['id'] as String,
      title: json['title'] as String,
      content: (json['content'] as String?) ?? '',
      active: (json['active'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
