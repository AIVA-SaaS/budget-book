import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/features/ai/data/models/ai_insight_model.dart';

void main() {
  group('AiInsightModel', () {
    test('fromJson parses all fields correctly', () {
      final json = {
        'type': 'SPENDING_PATTERN',
        'title': '식비 지출 증가',
        'description': '지난달 대비 식비가 20% 증가했습니다.',
        'severity': 'WARNING',
      };

      final model = AiInsightModel.fromJson(json);

      expect(model.type, 'SPENDING_PATTERN');
      expect(model.title, '식비 지출 증가');
      expect(model.description, '지난달 대비 식비가 20% 증가했습니다.');
      expect(model.severity, 'WARNING');
    });

    test('fromJson defaults severity to INFO', () {
      final json = {
        'type': 'TIP',
        'title': '절약 팁',
        'description': '커피를 직접 내려 마시면 절약할 수 있습니다.',
      };

      final model = AiInsightModel.fromJson(json);

      expect(model.severity, 'INFO');
    });
  });

  group('AiInsightsResponseModel', () {
    test('fromJson parses response with insights', () {
      final json = {
        'insights': [
          {
            'type': 'SPENDING_PATTERN',
            'title': '제목1',
            'description': '설명1',
            'severity': 'INFO',
          },
          {
            'type': 'BUDGET_ALERT',
            'title': '제목2',
            'description': '설명2',
            'severity': 'POSITIVE',
          },
        ],
        'generatedAt': '2026-04-07T12:00:00Z',
      };

      final model = AiInsightsResponseModel.fromJson(json);

      expect(model.insights.length, 2);
      expect(model.insights[0].title, '제목1');
      expect(model.insights[1].severity, 'POSITIVE');
      expect(model.generatedAt, '2026-04-07T12:00:00Z');
    });

    test('fromJson handles empty insights list', () {
      final json = {
        'insights': [],
        'generatedAt': '2026-04-07T12:00:00Z',
      };

      final model = AiInsightsResponseModel.fromJson(json);

      expect(model.insights, isEmpty);
    });

    test('fromJson handles null insights', () {
      final json = <String, dynamic>{
        'generatedAt': '2026-04-07T12:00:00Z',
      };

      final model = AiInsightsResponseModel.fromJson(json);

      expect(model.insights, isEmpty);
    });
  });
}
