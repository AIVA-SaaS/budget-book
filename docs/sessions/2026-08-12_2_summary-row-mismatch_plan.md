# 합계 ≠ 행 불일치 — 기획서 (2026-08-12)

> 분석 정본: `docs/sessions/2026-08-12_1_summary-row-mismatch_analysis.md`
> 근거 등급: `[측정]` 직접 실행·관측 / `[1차]` 코드·문서 / `[추론]` 유도(과정 병기) / `[미확인]`
> 하네스 게이트: `filter_propagation` **STRUCTURAL_FIX_REQUIRED** — 본 문서 §2 가 해제 근거
> 상태: **승인 대기** (코드 변경 0줄)

---

## 0. 확정된 판정 (사용자, 2026-08-12)

- **Q1 = 합계에 이체를 포함한다.** 필터 경로를 고친다. 근거: 무필터 경로·`getMonthlyTrend`·
  `ReconciliationAggregator`·FE `LedgerSummary` 가 이미 전부 포함 규칙이고, 어기는 곳은
  BE 필터 경로 하나뿐이다 `[1차]`
- **Q2 = 기간 장부다.** 거래·이체·합계 셋이 모두 `dateFrom~dateTo` 를 본다. 이체도 범위로 로드
- **Q3 = 행은 유지하고 "합계 제외" 배지를 붙인다.** ADJUSTMENT 17건 · CARD_SETTLEMENT 이체 8건 `[측정]`

---

## 1. 목표 / 비목표

목표

1. 기간 필터가 월을 넘어도 **이체 행이 누락되지 않는다** (F1 — 현재 77% 누락 `[측정]`)
2. 필터가 켜져도 **합계가 이체를 포함**한다 (F2 — 잠재, `EXPENSE_TRANSFER` 첫 등록 시 발현)
3. 행 집합과 합계 집합이 **같은 판정·같은 범위**에서 나온다 (근본 원인 제거)
4. 합계에서 제외되는 행은 화면에 그 사실이 표시된다 (F3)

비목표 (이번 회차에서 하지 않는다)

- 거래+이체를 서버가 하나의 병합 리스트로 주는 API 신설 — 진짜 최종형이지만 계약 대변경.
  §6 에 향후 항목으로 남긴다
- 200건 초과 페이지 UI (F4) — 대기열 1번 항목. 이번 변경으로 악화되지 않는지만 확인
- 개인 자산(ASSET-PRIVATE) 도입 — 대기열 2번

---

## 2. 구조적 수정 설계 (게이트 해제 근거)

게이트가 패치를 불허하는 이유는 같은 판정이 **두 곳**에 존재해 왔다는 것이다.
현재도 이체 판정은 FE `ledger_gating.dart` 에만 있고 BE 합계는 "필터 있으면 이체 제외"라는
**다른 규칙**을 쓴다. 판정을 BE 한 곳으로 모으고, 목록 쿼리와 집계가 **같은 함수**를 타게 한다.

### S1. BE — `LedgerFilter` VO + 축 enum (컴파일 강제)

- 신설 `common/filter/LedgerFilter.kt` — 장부 필터의 모든 축을 담는 data class.
  컨트롤러 3곳(거래 목록 · 이체 목록 · 통계 합계)이 개별 `@RequestParam` 나열 대신 이 VO 로 받는다
- 신설 `enum class LedgerFilterAxis` — 축 1개 = enum 1개. `TransferGating` 이 `when(axis)` 를
  **exhaustive** 로 처리하므로 **축을 추가하면 컴파일이 실패**한다
- 리플렉션 가드 테스트: `LedgerFilter` 의 프로퍼티 수 == `LedgerFilterAxis` 항목 수.
  둘의 대응이 깨지면 테스트 실패 (FE `kUnifiedFilterAxisCount` 선례를 BE 로 이식)

### S2. BE — `TransferGating` 단일 판정, 목록과 집계가 공유

- 신설 `transfer/service/TransferGating.kt`:
  - `excludedWholesale(f): Boolean` — 이체에 없는 축이 켜지면 전량 제외
    (needsReviewOnly / categoryIds·categoryGroupIds / pocketIds / visibility=PRIVATE /
    transactionTypes 에 TRANSFER 미포함). FE `ledger_gating.dart:93~110` 의 규칙을 그대로 이관
  - `spec(f, coupleId): Specification<Transfer>` — 적용 가능한 축
    (기간 / 결제수단 출금·입금 OR / 금액범위 / 검색어 = 설명 + 출금·입금 결제수단명)
- **이체 목록 조회와 이체 집계가 이 두 함수를 함께 쓴다.** 한쪽만 고치는 것이 구조적으로 불가능해진다

### S3. BE — 합계에서 `hasContentFilters` 분기 제거

- `StatisticsService.getMonthlySummary` 의 이중 분기(`StatisticsService.kt:98~165`)를 없앤다.
  항상 "거래 spec 집계 + 이체 spec 집계(kind 별 버킷)".
  `totalTransfer = 0L` 하드코딩 삭제 — 분기 자체가 사라지므로 재발 지점이 없다
- kind 규칙은 `ExpenseCalculator` 의 기존 정의를 그대로 따른다 `[1차]`:
  EXPENSE_TRANSFER→지출 / INCOME_TRANSFER→수입 / GENERIC→이체 칸 / CARD_SETTLEMENT→전량 제외 /
  ADJUSTMENT→통계 제외
- `getPeriodSummary` 의 동일 패턴(`StatisticsService.kt:373, 402~403, 440`)도 같은 함수로 통일

### S4. FE — 장부 전용 이체 소스 분리 (사이드이펙트 차단)

`TransferBloc` 은 **6개 소비자가 공유하는 lazy singleton** 이다 `[측정, §3]`.
여기에 장부의 필터·범위를 주입하면 이체 목록·카드정산·정산 뷰·거래 폼이 오염된다.

- 신설 `features/transaction/presentation/bloc/ledger_transfers_cubit.dart` — 장부 전용.
  `load({required String dateFrom, required String dateTo, required TransactionFilter filter})`.
  `required` 라 월만 넘기는 호출은 **컴파일이 실패**한다
- 공유 `TransferBloc` 과 `LoadTransfers(year, month)` 는 **손대지 않는다** → 다른 5개 소비자 무영향
- `transaction_list_page.dart` 는 `TransferBloc` 참조를 버리고 이 Cubit 을 소비.
  소스 검사 가드 테스트: 장부 페이지에 `TransferBloc` 참조가 재등장하면 실패
- 배선: `MonthSyncHandler`(월 이동) · `SyncEventHandler`(WebSocket) 에 새 Cubit 등록.
  `registerLazySingleton` 사용 (SyncEventHandler 가 참조하는 BLoC 규칙)

### S5. FE — 합계바를 서버 단일 소스로, 게이팅은 서버 신뢰

- 합계바 3칸(수입·지출·이체) 전부 서버값. 서버/클라 혼합(`transaction_list_page.dart:811~822`)을 제거
- `gateLedger` 에서 **이체 축 판정을 삭제**한다(서버가 이미 좁힌 결과를 받으므로).
  파일은 거래 pseudo-type 게이팅과 `resolveLedgerKeyword` 만 남긴다.
  가드 테스트를 "FE 에 이체 축 판정이 재도입되면 실패" 로 재작성
- 클라 `LedgerSummary` 는 **러닝밸런스 전용**으로 축소(행 순서 누적 계산은 여전히 FE 몫)

### S6. FE — 합계 제외 배지 (Q3)

- `transaction_list_tile.dart`(ADJUSTMENT) · 이체 타일(CARD_SETTLEMENT)에 "합계 제외" 배지.
  문구는 한국어, 규칙 판정은 단일 헬퍼(`isExcludedFromTotals(item)`)를 거친다 — 두 타일이 각자
  판정하면 그게 다음 drift 다

### S7. 계약 문서 선행 갱신 (프로젝트 필수 규칙)

`.claude/domains/contracts.md` — "API 변경: `docs/api-spec.md` 먼저 수정 → 구현".
자체 검토에서 **기존 문서 drift 2건**을 발견했다 `[측정]`:

- `docs/api-spec.md:1773` 의 Monthly Summary 는 쿼리 파라미터를 `year`·`month`·`visibility`
  **3개만** 문서화하고 있다. 실제 구현은 회차 8 에서 카테고리·결제수단·포켓·금액·검색어·타입·
  needsReview 까지 받는다(`StatisticsService.kt:52~73`) → **문서가 이미 뒤처져 있다**
- `docs/api-spec.md:42` 는 이번에 바꿀 동작을 규범으로 적어두었다 —
  "When category/payment-method/pocket filters are active, `totalTransfer` is always `0`".
  이 문장을 고치지 않으면 다음 사람이 옛 규칙으로 되돌린다

갱신 항목: Monthly Summary·Period Summary 의 전체 필터 파라미터 · 이체 포함 집계 규칙 ·
List Transfers 의 `dateFrom`/`dateTo` + 필터 파라미터(기존 `year`/`month` 는 하위호환 유지) ·
응답의 집계 건수 필드. **구현보다 먼저 커밋한다.**

### S8. 계약 테스트 — "합계 = 행" 을 게이트로 고정

- BE 통합 테스트(Testcontainers, 실 PG): 축 조합 매트릭스마다 **목록 API 합 == 합계 API** 를 검증.
  mock 으로는 spec/쿼리 층이 검증되지 않는다(메모리 `reference_card_settlement_flush_ordering` 교훈)
- 현재 `StatisticsServiceTest` 에 `totalTransfer`·필터 조합 케이스가 **0건** `[측정: grep]` → 신설
- 대상 조합: 무필터 / 금액 / 결제수단(복수) / 검색어 / 기간(월 내부·월 초과) / 타입(TRANSFER 단독·혼합) /
  카테고리 / 포켓 / needsReview / 개인. 각 조합에서 이체 kind 4종을 섞은 픽스처

---

## 3. 사이드이펙트 감사 — `TransferBloc` 공유 소비자 전수 `[측정]`

S4 가 필요한 이유. 아래 6곳이 같은 싱글톤 상태를 본다:

1. `transaction_list_page.dart:280, 763~765` — 장부 (이번에 분리 대상)
2. `transfer_list_page.dart:27~68` — 이체 목록 화면
3. `card_settlement_page.dart:253` — 카드정산 (월 일치 목적으로 LoadTransfers 재발행)
4. `reconciliation_view.dart:150` — 정산 뷰
5. `transaction_form_page.dart:707~711, 1358` — 거래 폼(카드 결제 후보)
6. `core/bloc/month_sync_handler.dart:94` · `core/websocket/sync_event_handler.dart:201` — 전역 재조회

판정: 장부만 별도 Cubit 으로 떼어내면 1번 외에는 코드 변경이 없다. 2~5 는 기존 월 단위 계약을 유지.

---

## 4. 금액 표시 위치 전수 조사 `[측정]` (메모리 `feedback_financial_consistency`)

`totalIncome|totalExpense|totalTransfer` 를 참조하는 파일 26개를 전수 확인했다.
이번 변경의 영향 판정:

**영향 있음 (직접 수정)**

- `transaction/presentation/pages/transaction_list_page.dart` — 합계바 소스 통일 (S5)
- `transaction/presentation/widgets/month_summary_bar.dart` — 3칸 서버값 수용
- `transaction/presentation/bloc/transaction_bloc.dart` · `transaction_state.dart` — 서버 총계 필드
- `transaction/presentation/utils/running_balance.dart` — 클라 집계 잔존 범위 확인
- `statistics/domain/entities/ledger_summary.dart` — 러닝밸런스 전용으로 축소
- `statistics/data/models/statistics_summary_model.dart` · `entities/statistics_summary.dart` —
  응답에 집계 건수 추가 시 확장

**영향 없음 (측정 근거 병기)**

- `reconciliation_view.dart:729` 의 `totalTransfer` 는 **정산 스냅샷** 값으로 별개 소스
- `statistics/presentation/*`(summary_tab · monthly_trend_tab · year_comparison_tab ·
  period_summary_page) 는 **이체 칸을 그리지 않는다** `[측정: grep 결과 0건]` —
  분석 탭에서 서버 `totalTransfer` 는 표시되지 않는다(분석서 §6 미해결 항목 해소)
- `report/*` · `pocket/*` · `home/dashboard_page.dart` — 후자는 미라우팅 죽은 코드
  (메모리 `reference_dead_home_dashboard`)
- `features/transfer/domain/entities/transfer.dart` — 엔티티 정의

단, `getPeriodSummary` 를 S3 로 함께 고치면 분석 탭의 수입·지출 값이 바뀔 수 있다
(이체 포함으로) → §8 라이브 검증에 항목으로 넣는다.

---

## 5. 게이트 계획

로컬 CI 4종 + 1 (대장 §1 기준)

1. `flutter analyze --no-fatal-infos --no-congratulate` 전체 경로 — 신규 0건
   (부분 경로 금지, 메모리 `feedback_full_flutter_analyze`)
2. `flutter test` — 기존 894건 + 신규(가드 재작성 · Cubit · 배지 · 계약)
3. `./gradlew test` — 신규 계약 테스트 포함
4. `flutter build web --release`
5. 배포 후 번들 문자열 확인 — 신규 배지 문구가 트리셰이킹되지 않았는지
   (한글은 `\uXXXX` 이스케이프 대조, 메모리 `reference_live_bundle_string_verification`)

게이트 해제: `bash ~/.claude/harness/scripts/acknowledge-gate.sh budget-book docs/sessions/2026-08-12_2_summary-row-mismatch_plan.md`

---

## 6. 리스크 · 미해결

- **PR 규모** — BE(VO·게이팅·합계 통합·계약 테스트) + FE(Cubit 분리·게이팅 이관·합계바·배지)로
  크다. §7 에서 커밋을 3단으로 쪼개 롤백 지점을 만든다. 한 PR 로 가는 이유는 중간 상태가
  "행은 범위, 합계는 월" 처럼 더 어긋나기 때문
- **배포 순서** `[추론: 파라미터 하위호환성으로 유도]` — 새 쿼리 파라미터는 구 BE 가 무시하고,
  구 FE 는 새 파라미터를 보내지 않는다 → BE·FE 어느 쪽이 먼저 떠도 안전
- **Spring 파라미터 바인딩** `[미확인]` — `LedgerFilter` 를 `@ModelAttribute` 생성자 바인딩으로
  받을 때 Kotlin 기본값 + `List<UUID>`(반복 쿼리 파라미터) 조합이 그대로 바인딩되는지 확인이
  필요하다. 실패하면 대안은 VO 를 유지하면서 컨트롤러에서 명시 팩토리(`LedgerFilter.from(...)`)로
  조립하는 것 — **축 강제(S1 enum + 리플렉션 가드)는 어느 쪽이든 유지된다**.
  확인 수단: 컨트롤러 슬라이스 테스트를 구현 첫 단계에서 먼저 작성
- **FE 이체 datasource 확장** `[1차]` — `LedgerTransfersCubit` 이 쓸 조회는 기존 이체
  repository/datasource 에 **옵셔널 파라미터 추가**로 처리한다(기존 월 단위 호출부 무영향).
  필터 직렬화는 `TransactionFilter.toQueryParams()` 단일 경로를 재사용 —
  새 직렬화 함수를 만들면 그것이 다음 drift 다
- **MODE B(단일 자산 필터) 이체 leg 의미** `[미확인]` — 현재 클라가 pmFilter 기준으로 leg 1회만
  더한다. 서버 spec 이 이미 그 이체를 좁히므로 동등할 것으로 보이나(추론), 구현 시 자산 모드
  화면에서 수치 대조가 필요하다. 확인 수단: MODE B 위젯 테스트 + 라이브 자산 필터 확인
- **검색 반응성** `[미확인]` — 이체 게이팅이 서버로 가면 검색어 입력 시 이체도 왕복을 탄다.
  거래는 이미 그렇게 동작하므로 체감 저하는 없을 것으로 보나(추론), 라이브에서 확인
- **사용자 원 보고 부재** `[미확인]` — F1 은 코드·DB 측정으로 확정했지만 사용자가 이 증상을
  화면에서 목격한 기록은 없다. 라이브 검증에서 재현 시나리오(§8 A1)로 확인한다
- 거래+이체 서버 병합 리스트 API — 최종형. 이번 비목표, 향후 후보

---

## 7. 작업 순서 (승인 후)

1. 계약 커밋 0 — `docs/api-spec.md` 갱신 (S7). 구현보다 먼저
2. BE 커밋 1 — `LedgerFilter` + `LedgerFilterAxis` + `TransferGating` + 리플렉션 가드 +
   컨트롤러 바인딩 슬라이스 테스트(§6 리스크 선검증)
3. BE 커밋 2 — 합계 분기 제거(`getMonthlySummary` · `getPeriodSummary`) + 이체 목록 필터 파라미터 +
   계약 통합 테스트(S8)
4. FE 커밋 3 — `LedgerTransfersCubit` + 장부 배선 + `gateLedger` 축 판정 제거 + 가드 재작성
5. FE 커밋 4 — 합계바 서버 단일 소스 + 배지(S6)
6. 로컬 CI 5종 → PR → 원격 CI → 머지 → 배포 → §8 라이브 검증 요청
7. DB 마이그레이션 **없음** (스키마 변경 0건 — 집계·조회 경로만 변경)

---

## 8. 라이브 검증 체크리스트 (사용자 확인용)

- **A1 (F1 핵심)**: 기간을 `2026-06-15 ~ 2026-08-05` 로 걸고 장부를 본다 →
  6월·7월 **이체 행이 보이고**(GENERIC 9건 + 카드정산 3건 `[측정]`), 이체 합계가
  4,393,787원 수준으로 오른다. 수정 전에는 8월 2건 1,008,648원만 보였다
- **A2**: 같은 기간에서 상단 합계와 화면 행의 합이 일치한다(수입·지출·이체 3칸)
- **A3**: 결제수단 여러 개 선택 → 이체가 두 결제수단 어느 쪽이든 걸리면 행에 남고 합계에도 반영
- **A4**: 금액 범위 필터 → 이체도 같은 기준으로 걸러지고 합계가 행과 일치
- **A5**: 검색어 → 이체는 설명·출금/입금 결제수단명으로 매칭
- **A6**: 카테고리 / 포켓 / 확인 필요만 / 개인 → 이체는 행과 합계에서 **함께** 사라진다
- **A7**: 타입에서 "이체" 단독 → 거래 행 0건, 수입·지출 0원, 이체 칸만 표시
- **A8**: 타입에서 "지출 + 이체" → 지출 거래와 이체가 함께 보이고 합계가 둘을 반영
- **A9 (F3)**: 잔액 수정(ADJUSTMENT) 행과 카드정산 이체 행에 "합계 제외" 배지가 보인다
- **A10**: 이체 목록 화면 · 카드정산 화면 · 정산 뷰 · 거래 폼(카드 결제 후보)이 이전과 동일하게
  동작한다 (S4 사이드이펙트 없음 확인)
- **A11**: 분석 탭 수입·지출 수치 — 필터를 걸었을 때 값이 장부와 같은 규칙으로 나온다
