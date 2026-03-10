import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel', () {
    group('fromJson', () {
      test('parses all fields including coupleId', () {
        final json = {
          'id': '123e4567-e89b-12d3-a456-426614174000',
          'email': 'test@example.com',
          'nickname': 'TestUser',
          'profileImageUrl': 'https://example.com/photo.jpg',
          'provider': 'GOOGLE',
          'role': 'USER',
          'coupleId': 'couple-abc-123',
          'createdAt': '2024-01-15T10:30:00.000Z',
        };

        final user = UserModel.fromJson(json);

        expect(user.id, '123e4567-e89b-12d3-a456-426614174000');
        expect(user.email, 'test@example.com');
        expect(user.nickname, 'TestUser');
        expect(user.profileImageUrl, 'https://example.com/photo.jpg');
        expect(user.provider, 'GOOGLE');
        expect(user.role, 'USER');
        expect(user.coupleId, 'couple-abc-123');
        expect(user.createdAt, DateTime.parse('2024-01-15T10:30:00.000Z'));
      });

      test('handles null coupleId', () {
        final json = {
          'id': '123e4567-e89b-12d3-a456-426614174000',
          'email': 'test@example.com',
          'nickname': 'TestUser',
          'profileImageUrl': null,
          'provider': 'GOOGLE',
          'role': 'USER',
          'coupleId': null,
          'createdAt': '2024-01-15T10:30:00.000Z',
        };

        final user = UserModel.fromJson(json);

        expect(user.coupleId, isNull);
        expect(user.profileImageUrl, isNull);
      });

      test('handles missing coupleId key', () {
        final json = {
          'id': '123e4567-e89b-12d3-a456-426614174000',
          'email': 'test@example.com',
          'nickname': 'TestUser',
          'provider': 'GOOGLE',
          'role': 'USER',
          'createdAt': '2024-01-15T10:30:00.000Z',
        };

        final user = UserModel.fromJson(json);

        expect(user.coupleId, isNull);
      });
    });
  });
}
