import 'package:flutter_test/flutter_test.dart';
import 'package:budget_book/core/domain/entities/record_base.dart';
import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';

/// PR-10 에서 모든 RecordBase 상속 타입이 준수해야 할 제네릭 contract 테스트를
/// 만들기 전 단계의 기본 검증. PR-1 은 RecordBase 자체의 유효성만 확인.

class _FakeRecord extends RecordBase {
  final String category;
  const _FakeRecord({
    required super.id,
    required super.coupleId,
    required super.author,
    required super.amount,
    required super.dateField,
    required super.createdAt,
    super.updatedAt,
    super.description,
    super.memo,
    required this.category,
  });

  @override
  List<Object?> get props => [...baseProps, category];
}

void main() {
  const author = TransactionAuthor(
    id: 'u1',
    nickname: '테스트',
    profileImageUrl: null,
  );
  final now = DateTime(2026, 4, 20, 12);

  group('RecordBase', () {
    test('기본 필드 보존', () {
      final r = _FakeRecord(
        id: 'r1',
        coupleId: 'c1',
        author: author,
        amount: 10000,
        dateField: '2026-04-20',
        createdAt: now,
        category: 'food',
      );
      expect(r.id, 'r1');
      expect(r.coupleId, 'c1');
      expect(r.amount, 10000);
      expect(r.dateField, '2026-04-20');
      expect(r.createdAt, now);
      expect(r.updatedAt, isNull);
      expect(r.category, 'food');
    });

    test('baseProps 에 9 개 공통 필드 포함', () {
      final r = _FakeRecord(
        id: 'r1',
        coupleId: 'c1',
        author: author,
        amount: 10000,
        dateField: '2026-04-20',
        createdAt: now,
        category: 'food',
      );
      expect(r.baseProps, hasLength(9));
    });

    test('Equatable 동등성 (공통 필드만 같아도 category 다르면 다름)', () {
      final a = _FakeRecord(
        id: 'r1',
        coupleId: 'c1',
        author: author,
        amount: 10000,
        dateField: '2026-04-20',
        createdAt: now,
        category: 'food',
      );
      final b = _FakeRecord(
        id: 'r1',
        coupleId: 'c1',
        author: author,
        amount: 10000,
        dateField: '2026-04-20',
        createdAt: now,
        category: 'food',
      );
      final c = _FakeRecord(
        id: 'r1',
        coupleId: 'c1',
        author: author,
        amount: 10000,
        dateField: '2026-04-20',
        createdAt: now,
        category: 'travel', // 다름
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('updatedAt null 허용 (PR-3 에서 non-null 전환 예정)', () {
      final r = _FakeRecord(
        id: 'r1',
        coupleId: 'c1',
        author: author,
        amount: 10000,
        dateField: '2026-04-20',
        createdAt: now,
        category: 'x',
      );
      expect(r.updatedAt, isNull);
    });

    test('optional 필드 모두 채움 시 정상', () {
      final r = _FakeRecord(
        id: 'r1',
        coupleId: 'c1',
        author: author,
        amount: 10000,
        dateField: '2026-04-20',
        createdAt: now,
        updatedAt: now.add(const Duration(hours: 1)),
        description: 'lunch',
        memo: 'with team',
        category: 'food',
      );
      expect(r.updatedAt, isNotNull);
      expect(r.description, 'lunch');
      expect(r.memo, 'with team');
    });

    test('dateField ISO 포맷 — 파싱 가능', () {
      final r = _FakeRecord(
        id: 'r1',
        coupleId: 'c1',
        author: author,
        amount: 10000,
        dateField: '2026-04-20',
        createdAt: now,
        category: 'x',
      );
      // 계약: dateField 는 DateTime.parse 가능해야 함
      expect(() => DateTime.parse(r.dateField), returnsNormally);
    });
  });
}
