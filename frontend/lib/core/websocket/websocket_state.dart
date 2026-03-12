import 'package:equatable/equatable.dart';

import 'websocket_service.dart';

/// State for the WebSocketBloc.
class WebSocketState extends Equatable {
  final WebSocketConnectionStatus connectionStatus;

  const WebSocketState({
    this.connectionStatus = WebSocketConnectionStatus.disconnected,
  });

  WebSocketState copyWith({
    WebSocketConnectionStatus? connectionStatus,
  }) {
    return WebSocketState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
    );
  }

  @override
  List<Object?> get props => [connectionStatus];
}
