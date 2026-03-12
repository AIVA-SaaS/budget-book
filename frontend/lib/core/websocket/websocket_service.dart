import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:logger/logger.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'sync_event.dart';

/// Connection status for the WebSocket service.
enum WebSocketConnectionStatus {
  connected,
  disconnected,
  reconnecting,
}

/// Service that manages a STOMP WebSocket connection for real-time sync.
class WebSocketService {
  final Logger _logger = Logger();

  StompClient? _stompClient;
  final StreamController<SyncEvent> _eventController =
      StreamController<SyncEvent>.broadcast();
  final StreamController<WebSocketConnectionStatus> _statusController =
      StreamController<WebSocketConnectionStatus>.broadcast();

  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  static const int _maxReconnectDelay = 30;

  String? _baseUrl;
  String? _accessToken;
  String? _coupleId;
  bool _isDisposed = false;

  /// Stream of incoming [SyncEvent]s from the WebSocket.
  Stream<SyncEvent> get eventStream => _eventController.stream;

  /// Stream of connection status changes.
  Stream<WebSocketConnectionStatus> get statusStream =>
      _statusController.stream;

  /// Whether the service is currently connected.
  bool get isConnected =>
      _stompClient?.connected == true;

  /// Connect to the WebSocket server.
  ///
  /// [baseUrl] is the HTTP(S) base URL (e.g., https://api.example.com).
  /// It will be converted to ws(s) URL with /ws path.
  void connect(String baseUrl, String accessToken, String coupleId) {
    _baseUrl = baseUrl;
    _accessToken = accessToken;
    _coupleId = coupleId;
    _reconnectAttempt = 0;

    _doConnect();
  }

  void _doConnect() {
    if (_isDisposed) return;

    final wsUrl = _convertToWsUrl(_baseUrl!);
    _logger.i('WebSocket connecting to: $wsUrl');

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        stompConnectHeaders: {
          'Authorization': 'Bearer $_accessToken',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $_accessToken',
        },
        heartbeatIncoming: const Duration(milliseconds: 10000),
        heartbeatOutgoing: const Duration(milliseconds: 10000),
        onConnect: _onConnect,
        onDisconnect: _onDisconnect,
        onStompError: _onStompError,
        onWebSocketError: _onWebSocketError,
        reconnectDelay: Duration.zero, // We handle reconnection ourselves
      ),
    );

    _stompClient!.activate();
    _statusController.add(WebSocketConnectionStatus.reconnecting);
  }

  void _onConnect(StompFrame frame) {
    _logger.i('WebSocket connected');
    _reconnectAttempt = 0;
    _statusController.add(WebSocketConnectionStatus.connected);

    // Subscribe to the couple's topic
    _stompClient?.subscribe(
      destination: '/topic/couple/$_coupleId',
      callback: _onMessage,
    );
    _logger.i('Subscribed to /topic/couple/$_coupleId');
  }

  void _onMessage(StompFrame frame) {
    if (frame.body == null) return;

    try {
      final json = jsonDecode(frame.body!) as Map<String, dynamic>;
      final event = SyncEvent.fromJson(json);
      _logger.d('Received sync event: ${event.entityType} ${event.type}');
      _eventController.add(event);
    } catch (e) {
      _logger.e('Failed to parse sync event: $e');
    }
  }

  void _onDisconnect(StompFrame frame) {
    _logger.w('WebSocket disconnected');
    _statusController.add(WebSocketConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _onStompError(StompFrame frame) {
    _logger.e('STOMP error: ${frame.body}');
    _statusController.add(WebSocketConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _onWebSocketError(dynamic error) {
    _logger.e('WebSocket error: $error');
    _statusController.add(WebSocketConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed || _baseUrl == null) return;

    _reconnectTimer?.cancel();
    _reconnectAttempt++;

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, 30s (max)
    final delay = min(
      pow(2, _reconnectAttempt - 1).toInt(),
      _maxReconnectDelay,
    );

    _logger.i('Scheduling reconnect attempt $_reconnectAttempt in ${delay}s');
    _statusController.add(WebSocketConnectionStatus.reconnecting);

    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (!_isDisposed) {
        _doConnect();
      }
    });
  }

  /// Disconnect from the WebSocket server.
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _baseUrl = null;
    _accessToken = null;
    _coupleId = null;
    _reconnectAttempt = 0;

    try {
      _stompClient?.deactivate();
    } catch (_) {
      // Ignore errors during deactivation
    }
    _stompClient = null;
    _statusController.add(WebSocketConnectionStatus.disconnected);
  }

  /// Dispose the service and release all resources.
  void dispose() {
    _isDisposed = true;
    disconnect();
    _eventController.close();
    _statusController.close();
  }

  /// Convert an HTTP(S) base URL to a WebSocket URL with /ws path.
  static String _convertToWsUrl(String baseUrl) {
    String wsUrl = baseUrl;
    if (wsUrl.startsWith('https://')) {
      wsUrl = 'wss://${wsUrl.substring(8)}';
    } else if (wsUrl.startsWith('http://')) {
      wsUrl = 'ws://${wsUrl.substring(7)}';
    }
    // Remove trailing slash if present
    if (wsUrl.endsWith('/')) {
      wsUrl = wsUrl.substring(0, wsUrl.length - 1);
    }
    return '$wsUrl/ws';
  }
}
