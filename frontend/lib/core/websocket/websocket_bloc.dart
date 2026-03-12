import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'sync_event.dart';
import 'sync_event_handler.dart';
import 'websocket_event.dart';
import 'websocket_service.dart';
import 'websocket_state.dart';

/// BLoC that manages WebSocket connection lifecycle and event routing.
class WebSocketBloc extends Bloc<WebSocketEvent, WebSocketState> {
  final WebSocketService webSocketService;
  final SyncEventHandler syncEventHandler;

  StreamSubscription<SyncEvent>? _eventSubscription;
  StreamSubscription<WebSocketConnectionStatus>? _statusSubscription;
  String? _currentUserId;

  WebSocketBloc({
    required this.webSocketService,
    required this.syncEventHandler,
  }) : super(const WebSocketState()) {
    on<WebSocketConnect>(_onConnect);
    on<WebSocketDisconnect>(_onDisconnect);
    on<WebSocketEventReceived>(_onEventReceived);
    on<WebSocketConnectionChanged>(_onConnectionChanged);
  }

  Future<void> _onConnect(
    WebSocketConnect event,
    Emitter<WebSocketState> emit,
  ) async {
    _currentUserId = event.currentUserId;

    // Listen to incoming sync events
    _eventSubscription?.cancel();
    _eventSubscription = webSocketService.eventStream.listen((syncEvent) {
      add(WebSocketEventReceived(syncEvent));
    });

    // Listen to connection status changes
    _statusSubscription?.cancel();
    _statusSubscription = webSocketService.statusStream.listen((status) {
      add(WebSocketConnectionChanged(status));
    });

    // Initiate the connection
    webSocketService.connect(
      event.baseUrl,
      event.accessToken,
      event.coupleId,
    );

    emit(state.copyWith(
      connectionStatus: WebSocketConnectionStatus.reconnecting,
    ));
  }

  Future<void> _onDisconnect(
    WebSocketDisconnect event,
    Emitter<WebSocketState> emit,
  ) async {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
    _currentUserId = null;

    webSocketService.disconnect();

    emit(state.copyWith(
      connectionStatus: WebSocketConnectionStatus.disconnected,
    ));
  }

  void _onEventReceived(
    WebSocketEventReceived event,
    Emitter<WebSocketState> emit,
  ) {
    if (_currentUserId != null) {
      syncEventHandler.handle(event.syncEvent, _currentUserId!);
    }
  }

  void _onConnectionChanged(
    WebSocketConnectionChanged event,
    Emitter<WebSocketState> emit,
  ) {
    emit(state.copyWith(connectionStatus: event.status));
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    _statusSubscription?.cancel();
    webSocketService.disconnect();
    return super.close();
  }
}
