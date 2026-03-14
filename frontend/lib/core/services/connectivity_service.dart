import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service that monitors network connectivity status.
/// Exposes a [Stream<bool>] indicating whether the device is online.
class ConnectivityService {
  final Connectivity _connectivity;
  late final StreamController<bool> _controller;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOnline = true;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity() {
    _controller = StreamController<bool>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
  }

  /// Whether the device is currently online.
  bool get isOnline => _isOnline;

  /// Stream that emits true when online, false when offline.
  Stream<bool> get onConnectivityChanged => _controller.stream;

  void _startListening() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });

    // Check initial status
    _connectivity.checkConnectivity().then((results) {
      final online = !results.contains(ConnectivityResult.none);
      if (online != _isOnline) {
        _isOnline = online;
        _controller.add(_isOnline);
      }
    });
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() {
    _stopListening();
    _controller.close();
  }
}
