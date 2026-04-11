import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/ai/data/models/ai_classify_model.dart';

void main() {
  group('AiClassifyModel', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'categoryId': 'cat-1',
        'categoryName': '식비',
        'groupName': '생활비',
        'confidence': 0.95,
        'source': 'AI',
      };

      final model = AiClassifyModel.fromJson(json);

      expect(model.categoryId, 'cat-1');
      expect(model.categoryName, '식비');
      expect(model.groupName, '생활비');
      expect(model.confidence, 0.95);
      expect(model.source, 'AI');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'categoryId': 'cat-2',
        'categoryName': '교통비',
        'confidence': 0.8,
      };

      final model = AiClassifyModel.fromJson(json);

      expect(model.categoryId, 'cat-2');
      expect(model.categoryName, '교통비');
      expect(model.groupName, '');
      expect(model.confidence, 0.8);
      expect(model.source, 'AI');
    });

    test('fromJson handles integer confidence', () {
      final json = {
        'categoryId': 'cat-3',
        'categoryName': '쇼핑',
        'groupName': '여가',
        'confidence': 1,
        'source': 'RULE',
      };

      final model = AiClassifyModel.fromJson(json);

      expect(model.confidence, 1.0);
      expect(model.source, 'RULE');
    });
  });
}
