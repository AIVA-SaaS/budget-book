import 'package:equatable/equatable.dart';

import 'sync_event.dart';
import 'websocket_service.dart';

/// Events for the WebSocketBloc.
sealed class WebSocketEvent extends Equatable {
  const WebSocketEvent();

  @override
  List<Object?> get props => [];
}

/// Request to connect to the WebSocket server.
class WebSocketConnect extends WebSocketEvent {
  final String baseUrl;
  final String accessToken;
  final String coupleId;
  final String currentUserId;

  const WebSocketConnect({
    required this.baseUrl,
    required this.accessToken,
    required this.coupleId,
    required this.currentUserId,
  });

  @override
  List<Object?> get props => [baseUrl, accessToken, coupleId, currentUserId];
}

/// Request to disconnect from the WebSocket server.
class WebSocketDisconnect extends WebSocketEvent {
  const WebSocketDisconnect();
}

/// A sync event was received from the WebSocket.
class WebSocketEventReceived extends WebSocketEvent {
  final SyncEvent syncEvent;

  const WebSocketEventReceived(this.syncEvent);

  @override
  List<Object?> get props => [syncEvent];
}

/// The connection status changed.
class WebSocketConnectionChanged extends WebSocketEvent {
  final WebSocketConnectionStatus status;

  const WebSocketConnectionChanged(this.status);

  @override
  List<Object?> get props => [status];
}
