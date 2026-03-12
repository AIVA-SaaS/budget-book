import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/websocket/sync_event.dart';

void main() {
  group('SyncEvent', () {
    test('fromJson creates correct SyncEvent', () {
      final json = {
        'type': 'CREATED',
        'entityType': 'TRANSACTION',
        'entityId': 'tx-1',
        'coupleId': 'couple-1',
        'authorId': 'user-2',
        'timestamp': '2026-03-12T10:00:00.000Z',
      };

      final event = SyncEvent.fromJson(json);

      expect(event.type, 'CREATED');
      expect(event.entityType, 'TRANSACTION');
      expect(event.entityId, 'tx-1');
      expect(event.coupleId, 'couple-1');
      expect(event.authorId, 'user-2');
      expect(event.timestamp, DateTime.parse('2026-03-12T10:00:00.000Z'));
    });

    test('fromJson handles missing fields with defaults', () {
      final json = <String, dynamic>{};

      final event = SyncEvent.fromJson(json);

      expect(event.type, '');
      expect(event.entityType, '');
      expect(event.entityId, '');
      expect(event.coupleId, '');
      expect(event.authorId, '');
      expect(event.timestamp, isA<DateTime>());
    });

    test('toJson produces correct map', () {
      final event = SyncEvent(
        type: 'UPDATED',
        entityType: 'BUDGET',
        entityId: 'b-1',
        coupleId: 'couple-1',
        authorId: 'user-1',
        timestamp: DateTime.parse('2026-03-12T10:00:00.000Z'),
      );

      final json = event.toJson();

      expect(json['type'], 'UPDATED');
      expect(json['entityType'], 'BUDGET');
      expect(json['entityId'], 'b-1');
      expect(json['coupleId'], 'couple-1');
      expect(json['authorId'], 'user-1');
      expect(json['timestamp'], '2026-03-12T10:00:00.000Z');
    });

    test('supports equality comparison', () {
      final timestamp = DateTime.parse('2026-03-12T10:00:00.000Z');
      final event1 = SyncEvent(
        type: 'CREATED',
        entityType: 'TRANSACTION',
        entityId: 'tx-1',
        coupleId: 'couple-1',
        authorId: 'user-2',
        timestamp: timestamp,
      );
      final event2 = SyncEvent(
        type: 'CREATED',
        entityType: 'TRANSACTION',
        entityId: 'tx-1',
        coupleId: 'couple-1',
        authorId: 'user-2',
        timestamp: timestamp,
      );

      expect(event1, equals(event2));
    });
  });
}
