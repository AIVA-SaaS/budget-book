import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:budget_book/core/di/injection.dart';
import 'package:budget_book/core/network/api_client.dart';
import 'package:budget_book/core/constants/api_endpoints.dart';

/// A dismissible announcement banner that fetches the active announcement
/// from the backend and displays it at the top of the page.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  String? _announcementId;
  String? _title;
  String? _content;
  bool _dismissed = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAnnouncement();
  }

  Future<void> _loadAnnouncement() async {
    try {
      final response =
          await getIt<ApiClient>().dio.get(ApiEndpoints.announcementsActive);
      final data = response.data['data'];
      if (data == null || data is! Map<String, dynamic>) {
        if (mounted) setState(() => _loaded = true);
        return;
      }
      final id = data['id'] as String;
      final prefs = await SharedPreferences.getInstance();
      final dismissedId = prefs.getString('dismissed_announcement_id');
      if (mounted) {
        setState(() {
          _announcementId = id;
          _title = data['title'] as String?;
          _content = data['content'] as String?;
          _dismissed = dismissedId == id;
          _loaded = true;
        });
      }
    } catch (_) {
      // Silently fail - announcement is not critical
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _dismiss() async {
    if (_announcementId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dismissed_announcement_id', _announcementId!);
    if (mounted) {
      setState(() => _dismissed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _dismissed || _announcementId == null) {
      return const SizedBox.shrink();
    }

    return MaterialBanner(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_title != null)
            Text(
              _title!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          if (_content != null && _content!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_content!),
            ),
        ],
      ),
      leading: const Icon(Icons.campaign, color: Colors.orange),
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      actions: [
        TextButton(
          onPressed: _dismiss,
          child: const Text('닫기'),
        ),
      ],
    );
  }
}
