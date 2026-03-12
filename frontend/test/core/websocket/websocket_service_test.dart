import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/websocket/websocket_service.dart';

void main() {
  group('WebSocketService', () {
    late WebSocketService service;

    setUp(() {
      service = WebSocketService();
    });

    tearDown(() {
      service.dispose();
    });

    test('initial state is disconnected', () {
      expect(service.isConnected, false);
    });

    test('disconnect on already disconnected does not throw', () {
      service.disconnect();
      expect(service.isConnected, false);
    });
  });

  group('WebSocketConnectionStatus', () {
    test('enum values exist', () {
      expect(WebSocketConnectionStatus.values.length, 3);
      expect(
        WebSocketConnectionStatus.values,
        containsAll([
          WebSocketConnectionStatus.connected,
          WebSocketConnectionStatus.disconnected,
          WebSocketConnectionStatus.reconnecting,
        ]),
      );
    });
  });
}
