import 'package:equatable/equatable.dart';

import 'package:budget_book/features/transaction/domain/entities/transaction_author.dart';

/// Transaction / Transfer / PocketTransfer 등 "시간·금액·작성자" 공통 성질을 가진
/// 레코드들의 공통 계약(contract).
///
/// ## 목적 (navigation_state / ui_pattern 재발 방지)
/// - 3개 유사 도메인 간 **공통 필드 중복 선언** 문제 근본 해결
/// - 필드 추가·변경 시 한 곳(이 파일) 수정하면 상속 타입 전체 자동 반영
/// - `updatedAt` 같은 필수 타임스탬프 누락 → **컴파일 에러로 강제 감지**
/// - 하위 클래스들이 `Equatable`을 각자 구현하던 보일러플레이트 제거
///
/// ## 계약
/// 이 클래스를 상속(extends)하는 타입은 반드시:
/// 1. 생성자에서 모든 required 필드를 super 로 전달
/// 2. `props` 를 override 하여 자신의 고유 필드를 **추가** (base props 포함)
/// 3. `dateField` 는 ISO-8601 `yyyy-MM-dd` 포맷의 대표 날짜 문자열
///    (Transaction: transactionDate, Transfer: transferDate, PocketTransfer: transferDate)
///
/// ## 비상속 유지 가능성
/// PR-1 단계에서는 **기존 Transaction/Transfer/PocketTransfer 수정 없음**.
/// PR-2~3 에서 각 entity 가 `extends RecordBase` 로 전환되며, 이 단계에서
/// 호환성 회귀 테스트가 있음 (test/core/domain/entities/record_base_test.dart).
abstract class RecordBase extends Equatable {
  /// 고유 식별자 (UUID).
  final String id;

  /// 커플 범위 (multi-tenancy).
  final String coupleId;

  /// 작성자 정보 (embed 된 value object).
  final TransactionAuthor author;

  /// 정수 원 단위 금액. 음수는 지출 관례가 아닌 **절댓값** 으로 저장한다
  /// (type 필드로 수입/지출 구분. Transfer 는 본질적으로 이체이므로 type 없음).
  final int amount;

  /// 대표 날짜 `yyyy-MM-dd`. 하위 클래스마다 필드명이 달라도 이 getter 로 접근.
  final String dateField;

  /// 레코드 최초 생성 시각.
  final DateTime createdAt;

  /// 레코드 최종 수정 시각. **nullable 이유**: PocketTransfer 는 현재 보유 안 함.
  /// PR-3 에서 BE 스키마 확장과 함께 non-null 로 전환 예정.
  final DateTime? updatedAt;

  /// 간단 설명. null 가능 (Transfer 는 optional).
  final String? description;

  /// 사용자 메모.
  final String? memo;

  const RecordBase({
    required this.id,
    required this.coupleId,
    required this.author,
    required this.amount,
    required this.dateField,
    required this.createdAt,
    this.updatedAt,
    this.description,
    this.memo,
  });

  /// 하위 클래스가 props 를 super 호출로 쉽게 가져올 수 있도록 분리.
  /// 사용 예: `List<Object?> get props => [...baseProps, category, paymentMethodId];`
  List<Object?> get baseProps => [
        id,
        coupleId,
        author,
        amount,
        dateField,
        createdAt,
        updatedAt,
        description,
        memo,
      ];

  /// Equatable 기본 구현. 하위 클래스가 고유 필드가 있으면 override.
  @override
  List<Object?> get props => baseProps;
}
