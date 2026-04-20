# Common Refactor — Base + Variant 로드맵

> 거래/이체/포켓이체 등 유사 도메인의 공통화 누수 제거를 위한 10-PR 시리즈.
> 하네스 request: req-1776658055997-007

## 목표
- 중복 선언된 공통 필드 (id/coupleId/author/amount/date/createdAt 등) 를 한 곳에서 관리
- Event / State / DataSource / Form 위젯까지 각 계층 base 추상화
- 컴파일 타임 + 테스트로 재발 자동 차단

## PR 시리즈

| PR | 브랜치 | 범위 | 상태 |
|----|-------|------|------|
| 1 | `refactor/record-base-pr1` | `RecordBase` 추상 클래스 추가 (entity 미수정) | ✅ 이번 회차 |
| 2 | `refactor/record-base-pr2-transaction` | TransactionEntity → RecordBase 상속 | ⏳ |
| 3 | `refactor/record-base-pr3-transfer` | TransferEntity → RecordBase + updatedAt 추가 | ⏳ |
| 4 | `refactor/load-records-event-pr4` | `LoadRecordsEvent<T>` + `PeriodFilterArgs` | ⏳ |
| 5 | `refactor/record-loaded-pr5` | `RecordLoaded<T>` 공통 state | ⏳ |
| 6 | `refactor/generic-datasource-pr6` | `GenericRemoteDataSource<T>` | ⏳ |
| 7 | `refactor/amount-date-memo-section-pr7` | `AmountDateMemoSection` 공통 위젯 | ⏳ |
| 8 | `refactor/tx-form-consolidation-pr8` | TransactionFormPage → 공통 위젯 통합 | ⏳ |
| 9 | `refactor/transfer-form-consolidation-pr9` | TransferFormPage → 공통 위젯 통합 | ⏳ |
| 10 | `test+lint/contract-pr10` | Contract test + custom lint | ⏳ |

## PR-1 성과
- `lib/core/domain/entities/record_base.dart` 신규
- 9개 공통 필드 + `baseProps` getter + Equatable 통합
- 기존 entity 는 변경 없음 (호환성 유지) — PR-2/3 에서 전환
- 테스트 6/6 통과

## 신규 Record 타입 추가 체크리스트
(PocketTransfer 에 Recurring 추가 등 미래 시나리오)

- [ ] `class XxxRecord extends RecordBase` 로 선언
- [ ] 생성자에서 모든 required 필드 `super` 로 전달
- [ ] 고유 필드를 `props` 에 `[...baseProps, field1, field2]` 패턴으로 추가
- [ ] `dateField` 는 ISO `yyyy-MM-dd` 형식 준수
- [ ] Event / State / DataSource 확장 시 해당 계층 base class 상속 (PR-4~6 완료 시)
- [ ] `testRecordContract<XxxRecord>` 를 테스트에 추가 (PR-10 완료 시)

## 공통 필드 추가 시 체크리스트
(RecordBase 에 새 필드 추가할 때)

- [ ] `RecordBase` 필드 + 생성자 파라미터 추가
- [ ] `baseProps` 에 추가 (Equatable 누락 방지)
- [ ] 모든 상속 타입(Transaction/Transfer/PocketTransfer) 컴파일 확인
- [ ] BE 스키마 migration (Flyway) 동반 필요 여부 확인
- [ ] `record_base_test.dart` 에 optional 필드면 presence/null 테스트, required 면 생성자 테스트

## 과거 인시던트 매핑 (CLAUDE.md / lessons-learned 기반)

| 인시던트 | 해결되는 PR | 비고 |
|---------|------------|------|
| updatedAt 필드 누락 (PocketTransfer) | PR-3 (+ PR-1 상속 강제) | 컴파일 에러로 감지 |
| 월 이동 시 필터 drop | PR-4 (LoadRecordsEvent) | TransactionFilter 이미 적용됨 |
| 카드결제 거래내역 자동 반영 누락 | PR-5 (RecordLoaded) | 이미 해결, 회귀 방지 |
| Form 컨트롤러 6개 중복 | PR-7~9 | AmountDateMemoSection |
| Repository 파라미터 불일치 | PR-6 (GenericRemoteDataSource) | PeriodFilterArgs 강제 |
