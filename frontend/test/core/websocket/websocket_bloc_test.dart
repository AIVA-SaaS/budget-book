import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'package:budget_book/core/websocket/websocket_bloc.dart';
import 'package:budget_book/core/websocket/websocket_event.dart';
import 'package:budget_book/core/websocket/websocket_state.dart';
import 'package:budget_book/core/websocket/websocket_service.dart';
import 'package:budget_book/core/websocket/sync_event.dart';
import 'package:budget_book/core/websocket/sync_event_handler.dart';

class MockWebSocketService extends Mock implements WebSocketService {
  final StreamController<SyncEvent> _eventController =
      StreamController<SyncEvent>.broadcast();
  final StreamController<WebSocketConnectionStatus> _statusController =
      StreamController<WebSocketConnectionStatus>.broadcast();

  @override
  Stream<SyncEvent> get eventStream => _eventController.stream;

  @override
  Stream<WebSocketConnectionStatus> get statusStream =>
      _statusController.stream;

  void emitEvent(SyncEvent event) => _eventController.add(event);
  void emitStatus(WebSocketConnectionStatus status) =>
      _statusController.add(status);

  void closeStreams() {
    _eventController.close();
    _statusController.close();
  }
}

class MockSyncEventHandler extends Mock implements SyncEventHandler {}

void main() {
  late MockWebSocketService mockService;
  late MockSyncEventHandler mockHandler;

  final tSyncEvent = SyncEvent(
    type: 'CREATED',
    entityType: 'TRANSACTION',
    entityId: 'tx-1',
    coupleId: 'couple-1',
    authorId: 'user-2',
    timestamp: DateTime.parse('2026-03-12T10:00:00Z'),
  );

  setUp(() {
    mockService = MockWebSocketService();
    mockHandler = MockSyncEventHandler();
  });

  tearDown(() {
    mockService.closeStreams();
  });

  group('WebSocketBloc', () {
    test('initial state is WebSocketState with disconnected status', () {
      final bloc = WebSocketBloc(
        webSocketService: mockService,
        syncEventHandler: mockHandler,
      );
      expect(bloc.state, const WebSocketState());
      expect(bloc.state.connectionStatus,
          WebSocketConnectionStatus.disconnected);
      bloc.close();
    });

    blocTest<WebSocketBloc, WebSocketState>(
      'emits [reconnecting] when WebSocketConnect is added',
      build: () => WebSocketBloc(
        webSocketService: mockService,
        syncEventHandler: mockHandler,
      ),
      act: (bloc) => bloc.add(const WebSocketConnect(
        baseUrl: 'https://api.example.com',
        accessToken: 'token-123',
        coupleId: 'couple-1',
        currentUserId: 'user-1',
      )),
      expect: () => [
        const WebSocketState(
          connectionStatus: WebSocketConnectionStatus.reconnecting,
        ),
      ],
      verify: (_) {
        verify(mockService.connect(
          'https://api.example.com',
          'token-123',
          'couple-1',
        )).called(1);
      },
    );

    blocTest<WebSocketBloc, WebSocketState>(
      'emits [disconnected] when WebSocketDisconnect is added',
      build: () => WebSocketBloc(
        webSocketService: mockService,
        syncEventHandler: mockHandler,
      ),
      seed: () => const WebSocketState(
        connectionStatus: WebSocketConnectionStatus.connected,
      ),
      act: (bloc) => bloc.add(const WebSocketDisconnect()),
      expect: () => [
        const WebSocketState(
          connectionStatus: WebSocketConnectionStatus.disconnected,
        ),
      ],
      verify: (_) {
        // disconnect() is called once by the event and once by bloc.close()
        verify(mockService.disconnect()).called(2);
      },
    );

    blocTest<WebSocketBloc, WebSocketState>(
      'forwards sync event to handler when WebSocketEventReceived is added',
      build: () => WebSocketBloc(
        webSocketService: mockService,
        syncEventHandler: mockHandler,
      ),
      act: (bloc) {
        // First connect to set currentUserId
        bloc.add(const WebSocketConnect(
          baseUrl: 'https://api.example.com',
          accessToken: 'token-123',
          coupleId: 'couple-1',
          currentUserId: 'user-1',
        ));
        // Then receive an event
        bloc.add(WebSocketEventReceived(tSyncEvent));
      },
      expect: () => [
        const WebSocketState(
          connectionStatus: WebSocketConnectionStatus.reconnecting,
        ),
      ],
      verify: (_) {
        verify(mockHandler.handle(tSyncEvent, 'user-1')).called(1);
      },
    );

    blocTest<WebSocketBloc, WebSocketState>(
      'emits connection status when WebSocketConnectionChanged is added',
      build: () => WebSocketBloc(
        webSocketService: mockService,
        syncEventHandler: mockHandler,
      ),
      act: (bloc) => bloc.add(
        const WebSocketConnectionChanged(
          WebSocketConnectionStatus.connected,
        ),
      ),
      expect: () => [
        const WebSocketState(
          connectionStatus: WebSocketConnectionStatus.connected,
        ),
      ],
    );

    blocTest<WebSocketBloc, WebSocketState>(
      'listens to service streams after connect',
      build: () => WebSocketBloc(
        webSocketService: mockService,
        syncEventHandler: mockHandler,
      ),
      act: (bloc) async {
        bloc.add(const WebSocketConnect(
          baseUrl: 'https://api.example.com',
          accessToken: 'token-123',
          coupleId: 'couple-1',
          currentUserId: 'user-1',
        ));
        // Wait for connect to process
        await Future.delayed(const Duration(milliseconds: 50));
        // Emit status change from service
        mockService.emitStatus(WebSocketConnectionStatus.connected);
        // Wait for status to propagate
        await Future.delayed(const Duration(milliseconds: 50));
        // Emit a sync event from service
        mockService.emitEvent(tSyncEvent);
        await Future.delayed(const Duration(milliseconds: 50));
      },
      expect: () => [
        // From WebSocketConnect
        const WebSocketState(
          connectionStatus: WebSocketConnectionStatus.reconnecting,
        ),
        // From status stream
        const WebSocketState(
          connectionStatus: WebSocketConnectionStatus.connected,
        ),
        // WebSocketEventReceived doesn't change state
      ],
      verify: (_) {
        verify(mockHandler.handle(tSyncEvent, 'user-1')).called(1);
      },
    );
  });
}
