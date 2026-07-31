# 이체 → 거래 역변환 — 기획 정본 (2026-07-31)

> **상태: 기획 완료 · 사용자 승인 대기 · 코드 변경 0줄.**
> 이 문서 하나만 읽으면 재부팅 후에도 그대로 구현에 들어갈 수 있다.
> 진행 상태(단계·다음 액션)는 `docs/PROGRESS.md` 가 단일 진입점이고, 이 문서는 그 회차의 설계 정본이다.

---

## 0. 재부팅 후 재개 절차 (이 순서 그대로)

1. `cd /Users/kdh/kdh/github/AIVA-SaaS/budget-book` (**cwd 필수** — 이 프로젝트는 project-local
   하드게이트 `.claude/hooks/pre-edit-guard.sh` 라 다른 cwd 에서는 강제가 걸리지 않는다)
2. `git switch main && git pull` — 마지막 커밋이 이 문서 + 대장 갱신 커밋인지 확인
3. `docs/PROGRESS.md` §1 STATE 확인 (`/clear` 후에는 SessionStart 훅이 자동 주입한다)
4. 이 문서 §2~§6 순서대로 구현. **§1 승인 게이트가 먼저다** — 사용자 승인 없이 코드 편집 시작 금지
5. 로컬 CI 3종(§7) 통과 후에만 커밋 → PR → 머지 → 라이브 검증 요청

재부팅으로 유실되는 것은 없다: 실행 중인 로컬 서버·워처 없음, 작업 트리 clean, 원격 배포물 무관.

---

## 1. 승인 게이트 (미승인)

사용자가 "이체 → 거래 역변환" 착수를 지정하고 이 설계를 승인하면 §2 부터 자동 진행한다
(구현 → 로컬 CI → PR → 머지 → 라이브 검증 요청까지 추가 승인 없음).
승인 전 이 문서/대장 외의 파일은 건드리지 않는다.

미승인 상태에서 다른 후보로 바꾸고 싶으면 `docs/PROGRESS.md` §3 의 후보 2~5 를 본다.

---

## 2. 측정으로 확인한 사실 (가설 아님 — 재확인 불필요)

1. 정방향 정본은 `backend/.../transaction/service/TransactionService.kt:456 convertToTransfer`.
   - 원본 거래 삭제 + 이체 생성을 **한 트랜잭션**에서 처리
   - 이체 생성은 `TransferService.createTransfer` 를 **재사용**한다 (카드결제 판정·카드간 이체 금지
     규칙이 두 벌이 되는 것을 막기 위해 — 주석에 명시)
   - `TRANSACTION_DELETED` + `TRANSFER_CREATED` **두 이벤트** 발행 (장부 목록이 거래+이체 병합이라
     한쪽만 쏘면 파트너 화면에 원본이 남는다)
2. `transfers` 를 FK 로 참조하는 테이블은 **2개뿐**
   - `transactions.settlement_transfer_id` — V63, `ON DELETE SET NULL`
   - `reconciliation_items.transfer_id` — V65, `ON DELETE SET NULL`
   - → 역변환에서 이 둘만 막으면 무결성 사고 경로가 닫힌다. 지출 계획(`spending_plans`)에는
     이체 링크 컬럼이 **없다**(정방향에만 있는 제약).
3. `Transfer` 엔티티에는 `visibility`/`owner` 가 **없다**(`transfer/domain/Transfer.kt`).
   거래 생성 규칙(`TransactionService.kt:262`)은 visibility 를 **카테고리에서 파생**하므로,
   역변환도 그 규칙을 그대로 타면 공유/개인 판정이 자동으로 맞는다.
4. `TransferService.updateTransfer:138` 은 이미 `kind == CARD_SETTLEMENT` 를
   `CARD_SETTLEMENT_EDIT_NOT_ALLOWED` 로 차단한다 → 역변환도 같은 선을 쓰면 V63 링크 문제가
   자동 해소되고 규칙이 한 벌로 유지된다.
5. `createTransaction` 은 **카테고리-유형 일치 검증을 하지 않는다**(`validateCategoryMatchesType` 는
   update 경로에만 있다) → 변환 경로에서 명시적으로 태워야 어긋난 데이터가 안 생긴다.
6. FE 진입점: 장부 목록의 이체 항목 → `transferEditRoute()`
   (`features/card_settlement/presentation/card_settlement_route.dart`) → `/transfers/edit/:id`.
   카드정산 이체는 이미 전용 플로우로 분기되므로 §4 의 차단 규칙과 UI 가 어긋나지 않는다.
7. FE `TransferRepository.getTransfer(id)` 가 **이미 있다** → 새로고침에도 살아남는 prefill 가능
   (기존 `copyFromId` 패턴과 동일 조건).
8. 하네스 audit: `pre-change-audit.sh . "amount_calculation ui_pattern navigation_state"`
   → `OVERALL VERDICT: OK`, gate OPEN (과거 인시던트 0건).

---

## 3. API 계약 (먼저 확정 — 코드보다 이 절이 앞선다)

- **엔드포인트**: `POST /api/v1/transfers/{id}/convert-to-transaction`
- **응답**: `ApiResponse<TransactionResponse>` (생성된 거래)
- **RateLimit**: `maxRequests = 30, windowSeconds = 60` (정방향 `convert-to-transfer` 와 동일)

요청 필드
- `type` — 필수. `EXPENSE` | `INCOME` (그 외 400)
- `categoryId` — 선택. 주면 유형 일치 검증. visibility 는 이 카테고리에서 파생
- `paymentMethodId` — 선택. 생략 시 **EXPENSE → 출금 결제수단 / INCOME → 입금 결제수단** 승계
- `amount` — 선택. 생략 시 원본 이체 금액 승계
- `transactionDate` — 선택. 생략 시 원본 `transferDate` 승계
- `description` — 선택. 생략 시 원본 설명 승계
- `memo` — 선택. 생략 시 원본 메모 승계
- `pocketId` — 선택. 이체에 대응 개념이 없어 신규 입력값
- `needsReview` — 선택, 기본 false. 동일

에러
- `400 VALIDATION_ERROR` — 지원하지 않는 `type` / 정산에 기록된 이체 / 카드 결제(`CARD_SETTLEMENT`)
  이체 / 결제수단 링크가 남은 이체 / 카테고리가 유형과 불일치 / **설명이 비어 있음**
- `403 FORBIDDEN` — 다른 커플의 이체
- `404 TRANSFER_NOT_FOUND` / `CATEGORY_NOT_FOUND` / `PAYMENT_METHOD_NOT_FOUND` / `POCKET_NOT_FOUND`
- **동기화**: `TRANSFER_DELETED` + `TRANSACTION_CREATED` 두 이벤트 모두 발행

### 함정 1건 — 설명 nullable 비대칭 (선반영)

`transfers.description` 은 nullable 인데 `transactions.description` 은 `@NotBlank` +
DB NOT NULL 이다. 승계만 하면 설명 없는 이체를 변환할 때 DB 제약에서 500 이 난다.
→ 승계 결과가 비면 **400 `VALIDATION_ERROR("설명을 입력하세요")`** 로 서비스에서 먼저 막는다.
FE 는 이 경우 설명 입력을 필수로 표시한다.

### 문서 위치

`docs/api-spec.md`
- `## Transfers`(3282) 의 `### 4. Update Transfer`(3456) 뒤에 **`### 4-1. Convert Transfer to
  Transaction`** 신설 — 거래 쪽 4-1 절(1245)과 번호 체계를 대칭으로 맞춘다
- 상호 참조 2곳 추가: 거래 4-1 절 끝(1292 부근) ↔ 새 절, `### 4. Update Transfer` 의 규칙 목록에
  "거래로의 변경은 이 엔드포인트가 아니다" 한 줄

---

## 4. 백엔드 설계

### 4.1 배치 결정 (순환 의존 회피)

구현은 **`TransactionService.convertFromTransfer(userId, transferId, request)`** 에 두고
`TransferController` 가 `TransactionService` 를 주입해 호출한다.

이유: `TransactionService → TransferService` 주입이 이미 있다(`TransactionService.kt:62`).
반대 방향(`TransferService → TransactionService`)을 추가하면 **순환 빈 의존**이 된다.
`TransactionService` 는 `transferRepository`(:57)·`reconciliationLookup`(:59)을 이미 갖고 있어
새 배선이 필요 없다. 컨트롤러→다른 서비스 의존은 순환이 아니다.

정방향과의 대칭: 정방향은 "거래 서비스가 이체 생성 경로를 재사용", 역방향은 "거래 서비스가
이체를 읽어 거래 생성 경로를 재사용" — **생성 규칙은 항상 목적지 도메인 서비스가 소유**한다는
점에서 일관된다. 이 판단 근거를 코드 주석에 남긴다(다음 사람이 되돌리지 않게).

### 4.2 처리 순서

1. `getActiveCouple(userId)` → 이체 조회 `transferRepository.findByIdAndCoupleId` (없으면 404)
2. 차단 3종 — 각각 한국어 사유 + 해제 방법 메시지
   - `reconciliationLookup.refsForTransfers(listOf(id))` 비어 있지 않음 → 정산 기록됨
   - `transfer.kind == TransferKind.CARD_SETTLEMENT` → 카드 결제는 전용 화면에서 처리
   - `transactionRepository.existsBySettlementTransferId(id)` → 결제 링크 잔존 (방어선. kind 검사와
     중복되지만 자동 생성 정산·과거 데이터를 위해 둔다)
3. 승계값 계산(§3) + 설명 공백 가드
4. 카테고리·결제수단·포켓 소유권 검증 → `Transaction` 생성 (visibility = 카테고리 파생,
   owner = PRIVATE 일 때만 현재 사용자) → `validateCategoryMatchesType`
5. `transactionRepository.saveAndFlush(...)` 후 `transferRepository.delete(transfer)`
   - **순서 주의**: 저장 후 flush. 카드정산 flush 사건(`reference_card_settlement_flush_ordering`)과
     같은 유형의 FK 타이밍 문제를 예방한다
6. `TRANSFER_DELETED` + `TRANSACTION_CREATED` 발행 → `learnPattern` → `toResponse()`

### 4.3 파일 목록

- `transaction/dto/TransactionDtos.kt` — `ConvertToTransactionRequest` 신설
  (`ConvertToTransferRequest`(198) 바로 뒤, 같은 주석 스타일)
- `transaction/service/TransactionService.kt` — `convertFromTransfer` 신설 (`convertToTransfer`(456) 뒤)
- `transaction/repository/TransactionRepository.kt` — `existsBySettlementTransferId(UUID): Boolean`
- `transfer/controller/TransferController.kt` — `POST /{id}/convert-to-transaction` + `TransactionService` 주입
- (필요 시) `transfer/repository/TransferRepository.kt` — 기존 `findByIdAndCoupleId` 로 충분, 변경 없음 예상

---

## 5. 프론트엔드 설계

### 5.1 왜 거래 폼으로 보내는가

이체 폼(534줄)에 카테고리·포켓 피커·자동완성을 복제하면 두 벌이 된다. 거래 폼은 **이미 양쪽 폼을
다 갖고 있다** — `transaction_form_page.dart` 의 `_buildEditTypeSelector`(726, 지출/수입/이체
SegmentedButton) + `_buildTransferFormContent`(1194). 그래서 **변환은 언제나 거래 폼에서**
일어나게 통일한다. 이체 폼의 유형 선택기는 거래 폼으로 보내는 라우터 역할만 한다.

### 5.2 작업 목록

1. `features/transfer/presentation/pages/transfer_form_page.dart`
   - 수정 모드(`isEditing`)에 `유형` SegmentedButton(지출/수입/이체) 추가 — 거래 폼 `:726` 과 동일 모양
   - 지출/수입 선택 → `context.push('/transactions/create?convertFromTransferId=<id>&type=EXPENSE')`
   - 카드정산 이체는 애초에 이 폼에 오지 않지만(전용 플로우 분기), 방어적으로 선택기를 숨긴다
2. `features/transaction/presentation/pages/transaction_form_page.dart`
   - `convertFromTransferId` 파라미터 추가 — prefill 은 기존 `copyFromId` 패턴 그대로
     (`initState:240` → fetch → `_prefillFromTransfer`)
   - 결제수단 기본값: EXPENSE → 이체의 출금 / INCOME → 입금
   - 상단 배너 "이체 → 거래로 변경 — 저장하면 원본 이체가 삭제됩니다"
   - 저장 경로 분기: `convertFromTransferId != null` → `_convertToTransaction()` (기존
     `_convertToTransfer:1144` 의 거울상. BLoC 을 안 거치고 repository 직접 호출 + 성공 후 재조회)
3. `features/transfer/data|domain` — `convertToTransaction` 추가
   - `transfer_remote_datasource.dart`: `POST ${ApiEndpoints.transfers}/$id/convert-to-transaction`
   - `transfer_repository.dart` / `_impl.dart`: `Future<Either<Failure, Transaction>>`
   - 위치 이유: 정방향이 **source 쪽 repository**(`TransactionRepository.convertToTransfer`)에
     있으므로 역방향은 `TransferRepository` 가 소유해야 대칭이다
4. `core/router/app_router.dart` — `/transactions/create` 빌더에
   `convertFromTransferId` query param 배선 + `TransferBloc` 프로바이더 확인(이미 있음, :458)

### 5.3 성공 후 리로드 (양방향 동일)

`LoadTransactions.fromFilter(year, month, currentFilter)` + `LoadTransfers(year, month)` +
`LoadDashboard(year, month)` + `LoadPaymentMethods()`.

**정방향에서 발견한 기존 결함(이번에 같이 고친다)**: `_convertToTransfer:1170` 은 거래·이체 BLoC 만
리로드하고 `DashboardBloc`·`PaymentMethodBloc` 은 리로드하지 않는다 → 변환 직후 월 합계와 자산
잔액이 즉시 갱신되지 않는다(이체 폼의 일반 저장 경로는 `transfer_form_page.dart:277-281` 에서
둘 다 리로드한다 — 변환 경로만 빠져 있다).
역방향만 고치면 또 갈라지므로 **네 BLoC 리로드를 양방향 공통 헬퍼로** 묶는다
(원칙: `feedback_common_scope_audit` — 한 곳만 수정 금지).

---

## 6. 테스트 (게이트)

백엔드 — `backend/src/test/kotlin/com/budgetbook/`
- `transaction/service/TransactionServiceTest.kt` — `convertFromTransfer` 블록.
  기존 `convertToTransfer` 테스트(:1281~1360) 대칭으로:
  정상 EXPENSE(이체 삭제 + 거래 생성 + 승계값) / 정상 INCOME(결제수단 = 입금 승계) /
  차단 4종(정산 기록·카드결제·결제링크·카테고리 유형 불일치) / 설명 공백 400 /
  다른 커플 403 / 이벤트 2건 발행
- `transfer/integration/` — Testcontainers 통합테스트 1건 신설.
  이유: mock 은 FK·CHECK 를 검증하지 않는다(`reference_card_settlement_flush_ordering` 교훈).
  검증: 한 트랜잭션에서 이체 삭제 + 거래 삽입이 FK 위반 없이 커밋되고, 월 합계·자산 잔액이
  변환 전후로 정합한지

프론트엔드 — `frontend/test/`
- `features/transfer/` — repository 테스트(`features/transaction/type_change_test.dart` 대칭:
  요청 body 필드 전송/생략 승계/실패 매핑)
- 폼 위젯 테스트 — 이체 폼 유형 선택기 → 라우팅 인자 확인, 거래 폼 변환 모드 배너·저장 경로
- 가드 테스트 — 변환 성공 시 **네 BLoC 리로드**가 양방향 모두에서 발생하는지 (한쪽만 고치는 재발 차단)

---

## 7. 로컬 CI (전부 통과 전 PR·머지 금지)

- `cd backend && ./gradlew test`
- `cd frontend && flutter analyze --no-fatal-infos --no-congratulate` (**전체 경로. 부분 경로 금지**)
- `cd frontend && flutter test`
- `cd frontend && flutter build web --release`

주의: 로컬 analyze 통과 ≠ CI 통과(CI Flutter 가 더 최신이면 같은 lint 가 warning 으로 승격).
CI 실패 시 추측 금지 — `gh run view --log-failed` 로 지적 내용부터 본다.

## 8. 규모 / 산출물

BE 4파일 + FE 5파일 + 문서 2 + 테스트 4 → **PR 1개**. DB 마이그레이션 없음.
