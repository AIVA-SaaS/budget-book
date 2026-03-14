import 'dart:async';
import 'package:flutter/material.dart';
import 'package:budget_book/core/services/connectivity_service.dart';

/// A banner that shows "오프라인 상태입니다" when the device has no network.
/// Auto-hides when connectivity is restored.
class OfflineBanner extends StatefulWidget {
  final ConnectivityService connectivityService;

  const OfflineBanner({super.key, required this.connectivityService});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late bool _isOnline;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _isOnline = widget.connectivityService.isOnline;
    _subscription =
        widget.connectivityService.onConnectivityChanged.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1.0,
          child: child,
        );
      },
      child: _isOnline
          ? const SizedBox.shrink(key: ValueKey('online'))
          : Container(
              key: const ValueKey('offline'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey.shade800,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.wifi_off,
                    size: 16,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '오프라인 상태입니다',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
