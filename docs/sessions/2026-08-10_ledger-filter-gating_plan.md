# 2026-08-10 — 장부 필터 게이팅 단일화 + 동적 빈 상태 문구 (기획)

> 트리거: 사용자 보고 — "확인 필요 등 필터 적용 시 이체를 선택하지 않았는데도 이체가 보인다".
> 하네스 감사(`filter_propagation`) = **STRUCTURAL_FIX_REQUIRED**(4회째 재발) → 패치 수정 불허.
> 관련 메모리: `reference_transaction_merged_transfer_stream_drift`, `feedback_filter_vo_single_source`,
> `reference_month_move_filter_drop`, `feedback_common_scope_audit`.

---

## 1. 증상 → 원인 (hard evidence)

- 증상 관찰 레이어: 거래 탭 목록(그리고 달력·월합계바) 화면.
- 코드 근거
  - `frontend/lib/features/transaction/presentation/pages/transaction_list_page.dart:727~785`
    이체 스트림 게이팅이 필터 필드를 **인라인으로 수동 나열**한다.
    - 적용됨: `paymentMethodIds.first`(**복수 선택 중 1개만**), `dateFrom/dateTo`, 검색 키워드,
      `transactionTypes`(TRANSFER 포함 여부), `visibility == 'PRIVATE'`
    - **누락**: `needsReviewOnly`, `categoryIds` / `categoryGroupIds`, `amountMin/amountMax`, `pocketIds`
  - `frontend/lib/features/transfer/domain/entities/transfer.dart:49~83`
    `Transfer` 에는 `needsReview` / category / pocket 필드가 **존재하지 않는다**
    → 해당 축이 활성이면 이체는 **논리적으로 매칭 불가** = 전량 제외가 정답인데 게이팅이 그 축을 보지 않아 통과된다.
  - `backend/.../TransactionSpecifications.kt:100`, `StatisticsService.kt:105`
    거래·합계는 BE 가 `needsReviewOnly` 를 정상 적용 → "거래는 맞는데 이체만 남는" 비대칭이 설명된다.
- 인과 1문장:
  **증상 ← 이체 게이팅이 `UnifiedFilterState` 를 수동 나열해 `needsReviewOnly` 축을 보지 않음
  ← 이체 게이팅이 VO 를 관통하지 않고 페이지 안에 인라인으로 흩어져 있음.**

### 반증 시도 (fix 후에도 증상이 남을 조건)

1. 달력뷰/월합계바가 다른 리스트를 소비한다면 목록만 고쳐도 증상 잔존
   → 세 소비처가 모두 `visibleTransactions` / `visibleTransfers` 를 쓰는지 확인 완료
   (`:791` summary, `:854` calendar, `:880`·`:890` list). 게이팅 함수 1개 교체로 3곳 동시 커버.
2. BE 가 `/transfers` 를 월 단위로만 주고 FE 가 필터를 못 건다면 → 이체 축(기간·금액·결제수단·키워드)은
   FE 에서 판정 가능함을 엔티티로 확인 완료.
3. 배포 후 구번들 캐시 → 라이브 검증 시 `last-modified` + escaped 문자열 대조
   (`reference_live_bundle_string_verification`).

---

## 2. 전수 조사 (공통 적용 범위)

- `UnifiedFilterBar` 사용처는 2곳뿐: `transaction_list_page.dart:698`, `period_summary_page.dart:85`.
  후자는 `dateRange/category/paymentMethod` 만 활성이고 **이체 병합이 없다** → 이번 누출 범위 밖.
- 이체 스트림을 거래와 병합하는 화면은 **거래 탭 1곳**(목록·달력·합계바·러닝밸런스).
- 정산 뷰(`reconciliation_view.dart`)는 서버 필터로 직접 로드 → 범위 밖(자체 빈 문구 보유).
- ⇒ 게이팅 수정 1곳으로 전수 커버되며, 빈 문구 동적화도 거래 탭 `_buildEmpty`(`:1281`) 1곳.

---

## 3. 구조적 수정 (게이트 해제 요건)

패치가 아니라 **재발을 컴파일/테스트 타임에 막는 장치**를 넣는다.

### S1. 단일 게이팅 진입점 — 순수 함수 모듈

새 파일 `frontend/lib/features/transaction/presentation/utils/ledger_gating.dart`
(기존 `running_balance.dart` 와 동일한 "순수 함수 + 단위 테스트" 관례를 따른다)

```dart
class GatedLedger { final List<Transaction> transactions; final List<Transfer> transfers; }

GatedLedger gateLedger({
  required List<Transaction> transactions,   // BE 가 이미 좁힌 결과
  required List<Transfer> transfers,         // 월 단위 원본
  required UnifiedFilterState filter,
  String? keyword,
});
```

- `UnifiedFilterState` 의 **모든 축**에 대해 "이체에 적용 / 이체에 없음→전량 제외 / 무관" 을 **명시적으로** 판정한다.
  - 이체에 없는 축(`needsReviewOnly`, category, pocket): 활성이면 **이체 0건**
  - 이체에 있는 축(date, amount, paymentMethodIds **전체 OR 매칭**, keyword, type, visibility): 실제 매칭
  - `dateRangeLabel` / `categoryName` / `paymentMethodName` / `status`: 표시용·미사용 축으로 명시 분류
- 페이지는 이 함수의 결과만 소비한다(변수명 `visibleTransactions` / `visibleTransfers` 유지) →
  목록·달력·합계·러닝밸런스가 **같은 리스트**를 본다.

### S2. 필드 수 가드 테스트 (재발 강제 차단)

`frontend/test/features/transaction/presentation/utils/ledger_gating_test.dart`

- `UnifiedFilterState().props.length` 를 상수와 대조. 불일치 시 실패 메시지:
  > "UnifiedFilterState 에 필드가 추가/삭제되었다. ledger_gating.dart 의 이체 축 판정에 이 필드를
  > 명시 처리한 뒤 이 상수를 갱신하라."
  → **새 필터를 추가하면 이체 게이팅 갱신 없이는 CI 가 빨간불**이 된다(누락의 구조적 봉인).
- 축별 케이스: needsReview / category / group / pocket → 이체 0건, 금액범위, 결제수단 2개 OR,
  TRANSFER-only → 거래 0건, PRIVATE → 이체 0건, 무필터 → 전량 통과.

### S3. 인라인 게이팅 재도입 차단

- 같은 테스트 파일에서 `transaction_list_page.dart` 소스를 읽어
  이체 리스트를 페이지에서 직접 `.where(` 로 거르는 패턴이 없는지 검사(회귀 가드).
- 페이지에는 "이체 게이팅은 `ledger_gating.dart` 단일 진입점" 주석 앵커를 남긴다.

---

## 4. 동적 빈 상태 문구 (2번째 요구사항)

새 파일 `frontend/lib/features/transaction/presentation/utils/ledger_empty_message.dart` (순수 함수)

```dart
class LedgerEmptyMessage { final String title; final String? subtitle; final bool hasFilters; }
LedgerEmptyMessage buildLedgerEmptyMessage(UnifiedFilterState filter, {String? keyword});
```

- 필터 없음 → `거래 내역이 없습니다` / `이 달에 기록된 거래가 없습니다` (현행 유지)
- 단일 축 활성 → 그 축 전용 문구
  - `확인/입력 필요한 거래가 없습니다`
  - `이체 내역이 없습니다` / `지출 내역이 없습니다` / `수입 내역이 없습니다` (복수 선택 시 `지출/이체 …`)
  - `개인 거래가 없습니다` / `공유 거래가 없습니다`
  - `선택한 카테고리의 거래가 없습니다` / `… 결제수단의 …` / `… 포켓의 …`
  - `해당 금액대의 거래가 없습니다` / `선택한 기간에 거래가 없습니다`
  - `'{검색어}' 검색 결과가 없습니다`
- 2축 이상 → title 은 우선순위 최상위 축 문구, subtitle 은 `적용된 필터: 확인 필요 · 지출 · 카테고리`
- 액션 버튼: 필터가 하나라도 활성이면 **`필터 초기화`**(필터 + 검색어 동시 해제), 아니면 기존 `거래 추가`
- 값 라벨(카테고리명 등)은 상단 필터 칩이 이미 보여주므로 문구에는 **축 이름만** → getIt 의존 없는 순수 함수 유지
- 테스트: 축별 문구 + 복합 케이스 + 액션 라벨 분기

---

## 5. 변경 파일 (예상)

- 신규 `frontend/lib/features/transaction/presentation/utils/ledger_gating.dart`
- 신규 `frontend/lib/features/transaction/presentation/utils/ledger_empty_message.dart`
- 신규 테스트 2개 (`test/features/transaction/presentation/utils/…`)
- 수정 `frontend/lib/features/transaction/presentation/pages/transaction_list_page.dart`
  (인라인 게이팅 → `gateLedger` 호출, `_buildEmpty` → 동적 문구 + 필터 초기화 액션)
- 수정 `frontend/lib/core/widgets/filters/unified_filter_bar.dart`
  (`_typeLabels` 를 공용 상수로 승격해 문구 유틸과 공유 — 라벨 이중 정의 방지)

BE 변경 없음(거래·합계는 이미 서버가 정확히 필터).

---

## 6. 검증 계획

- 로컬 CI 4종: `flutter analyze --no-fatal-infos --no-congratulate`(전체 경로) / `flutter test` /
  `./gradlew test` / `flutter build web`
- 관찰 레이어 검증(라이브): 거래 탭에서
  1. 확인/입력 필요만 ON → **이체 0건**, 월합계바 이체 금액 미표시
  2. 카테고리/포켓 필터 → 이체 0건
  3. 결제수단 2개 선택 → 두 결제수단 이체 모두 표시(기존엔 1개만)
  4. 금액범위 → 범위 밖 이체 제외
  5. 결과 0건일 때 조건에 맞는 문구 + `필터 초기화` 버튼 동작
  6. 달력뷰에서도 1~4 동일(마커 사라짐)

---

## 7. 남은 요구사항 — 단계 정리 (3번째 요구사항)

| 단계 | 항목 | 근거/문서 | 비고 |
|---|---|---|---|
| Step 1 (이번) | 장부 필터 이체 누출 fix + 동적 빈 문구 | 본 기획서 | FE only, PR 1개 |
| Step 2 | 미종결 라이브 검증 정리 | PROGRESS §3, current-tasks | 역변환(PR #290), RECON-VERIFY A/B/C, KI-006 |
| Step 3 | RECON-P6 홈 "미정산 N건" 위젯 | current-tasks Backlog | 기존 API 재사용, 소규모 |
| Step 4 | 미기록 200건 초과 추가 페이지 로드 UI | `reconciliation_view.dart:191` | LoadMore 패턴 재사용 |
| Step 5 | ASSET-PRIVATE 개인 자산 + 이체 visibility 파생 | 메모리 | 본 fix 의 "이체=SHARED 취급" 임시 전제를 정식화 |
| Step 6 | RECON-P4 월말 "미기록 N건" 인앱 알림 | current-tasks Backlog | 알림 인프라 선행, 최대 규모 |
| Step 7 | REL-ANDROID / KI-007-P2 카카오 비즈니스 | current-tasks Backlog | 선택 |

> 표 형식은 기획 문서 내부용. 사용자 보고 시에는 불릿으로 전달(글로벌 §1.9).
