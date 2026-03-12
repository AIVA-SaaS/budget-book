import 'package:equatable/equatable.dart';

/// Represents a real-time synchronization event received via WebSocket.
class SyncEvent extends Equatable {
  final String type;
  final String entityType;
  final String entityId;
  final String coupleId;
  final String authorId;
  final DateTime timestamp;

  const SyncEvent({
    required this.type,
    required this.entityType,
    required this.entityId,
    required this.coupleId,
    required this.authorId,
    required this.timestamp,
  });

  factory SyncEvent.fromJson(Map<String, dynamic> json) {
    return SyncEvent(
      type: json['type'] as String? ?? '',
      entityType: json['entityType'] as String? ?? '',
      entityId: json['entityId'] as String? ?? '',
      coupleId: json['coupleId'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'entityType': entityType,
      'entityId': entityId,
      'coupleId': coupleId,
      'authorId': authorId,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [type, entityType, entityId, coupleId, authorId, timestamp];
}
