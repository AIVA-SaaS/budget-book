# 합계 ≠ 행 잔존 불일치 — 분석 (2026-08-12)

> 회차: "합계 ≠ 행 잔존 불일치" · 단계: **분석 (기획 전)** · 코드 변경 0줄
> 근거 등급 표기: `[측정]` 직접 실행·관측 / `[1차]` 코드·공식 문서 / `[추론]` 유도(과정 병기) / `[미확인]`
> 하네스 게이트: `filter_propagation` **STRUCTURAL_FIX_REQUIRED** (LOCKED) — 기획서에 구조적 수정 포함 필수

---

## 0. 한 줄 결론

착수 지점에 적혀 있던 전제("금액/기간/결제수단 필터만 켜면 상단 합계와 아래 행이 서로 다른 집합을
센다", 근거 `StatisticsService.kt:147`)는 **수입/지출 축에서는 현재 발현하지 않는다** —
그 코드가 만드는 `totalTransfer = 0` 은 **어느 화면에도 표시되지 않는 값**이고, 수입/지출이
갈라지려면 실 DB 에 0건인 이체 kind 가 필요하다. 대신 **기간 필터가 포커스 월을 넘어가는 순간
이체 행이 통째로 누락되는 결함**이 지금 발현 중이다(측정: 범위 내 이체 금액의 **77% 누락**).

---

## 1. 측정 기록 (hard evidence)

실 DB (`ssh tiggle` → `db_postgres_bb`, 2026-08-12):

- 이체 kind 분포 `[측정]`: `GENERIC` 22건 / 17,835,887원, `CARD_SETTLEMENT` 8건 / 6,539,921원,
  **`EXPENSE_TRANSFER` 0건, `INCOME_TRANSFER` 0건**
- 거래 type 분포 `[측정]`: `EXPENSE` 542건, `INCOME` 31건, **`ADJUSTMENT` 17건**
- 월별 거래 최대 건수 `[측정]`: 119건 (2026-06 / 2026-03) — **페이지 크기 200 미달**
- `needs_review` 1건 / `visibility='PRIVATE'` 87건 `[측정]`

교차 검증용 범위 표본 `[측정]` — 2026-06-15 ~ 2026-08-05:

- 거래 192건 (06월 63 / 07월 118 / 08월 11)
- 이체 `GENERIC` 11건 4,393,787원 (06월 1 / 07월 8 / 08월 2), `CARD_SETTLEMENT` 3건

---

## 2. 지형 (코드 근거)

합계바 한 줄이 **서로 다른 세 소스**를 섞는다 `[1차]` — `transaction_list_page.dart:797~836`:

- 수입·지출: **서버값 우선** (`state.serverTotalIncome/Expense`, BE `/statistics/summary`)
- 이체: **클라 계산** (`LedgerSummary.from(visibleTransfers)`)
- 잔액: `displayIncome - displayExpense` (ADJUSTMENT 미반영)

행 집합은 `gateLedger()` 결과 `[1차]` — `ledger_gating.dart:60~86`. 거래는 BE 가 좁힌 결과에
타입 게이팅만 추가, 이체는 FE 가 16축 전수 판정.

집계 규칙 정본은 BE `ExpenseCalculator` `[1차]` — `ExpenseCalculator.kt:36~82`:
지출 = EXPENSE 거래 + `EXPENSE_TRANSFER` 이체, 수입 = INCOME 거래 + `INCOME_TRANSFER` 이체,
이체 = `GENERIC`, ADJUSTMENT·CARD_SETTLEMENT 는 전량 제외. FE `LedgerSummary` 규칙과 **동일** `[1차]`.

---

## 3. 원인 분해 — 발현 중 / 잠재 구분

### F1. 기간 필터가 월을 넘으면 이체 스트림만 월에 갇힌다 — **발현 중 (이번 회차의 본체)**

근거 `[1차]`:

- 이체 로드는 **월 단위 고정**: `LoadTransfers({required year, required month})`
  (`transfer_event.dart:15`), 호출 1곳 `transaction_list_page.dart:280`
- 거래 목록은 `dateFrom/dateTo` 가 **월을 완전히 덮어쓴다**: 지정 시 범위 전체,
  미지정 축은 `2000-01-01`~`2099-12-31` (`TransactionService.kt:109~118`)
- 서버 합계도 동일하게 월을 덮어쓴다 (`StatisticsService.kt:78~79`)
- 행 빌더는 포커스 월로 **다시 자르지 않는다** — `_buildGroupedList` 는 받은 리스트를
  날짜 그룹으로만 묶는다 (`transaction_list_page.dart:951~965`, 주석에 "Server already
  filters transactions by dateFrom/dateTo")

발현 계산 `[추론: §1 범위 표본 + 위 코드 경로를 조합]` — 2026-06-15~2026-08-05 범위를 걸고
8월을 보고 있을 때:

- 거래 행: 192건 전량 노출(200 미달이라 페이지 1회로 완주)
- 이체 행: **8월 GENERIC 2건 1,008,648원만** — 06·07월 GENERIC 9건 3,385,139원 +
  CARD_SETTLEMENT 3건이 행에서 사라짐 → 범위 내 이체 금액의 **77% 누락**
- 이체 칸도 같은 리스트를 세므로 함께 과소 표시
- 수입/지출 합계는 서버·행 모두 범위 전체라 **일치** → 사용자 눈에는 "6월 거래는 보이는데
  6월 이체만 없다" + "이체 합계가 너무 작다"

이것이 메모리 `reference_transaction_merged_transfer_stream_drift` 의 5번째 변형이다 —
이번에는 **필터 축이 아니라 스트림의 로드 범위**가 갈라졌다.

### F2. 필터 활성 시 BE 합계가 이체를 전량 제외 — **잠재 (데이터 0건, 도달 가능)**

근거 `[1차]` — `StatisticsService.kt:98~149`: `hasContentFilters`(카테고리·결제수단·포켓·금액·
검색어·타입·needsReview 중 하나) 가 참이면 Specifications 로 **거래만** 집계하고
`totalTransfer = 0L` 하드코딩. 거짓이면 `ExpenseCalculator` 로 **이체 포함**.
즉 규칙을 어기는 것은 필터 경로 한쪽뿐이다.

발현 조건 두 개가 모두 필요하다:

1. 이체를 전량 제외하지 않는 축이 켜짐 — 금액·결제수단·검색어, 또는 타입에서 TRANSFER 와
   지출/수입을 함께 선택 (`ledger_gating.dart:93~110` 기준: 카테고리·포켓·needsReview·
   개인 visibility 는 이체를 전량 제외하므로 양쪽이 함께 이체를 뺀다 = 불일치 없음)
2. `EXPENSE_TRANSFER` / `INCOME_TRANSFER` 이체가 존재 — **실 DB 0건** `[측정]`

→ 현재 미발현. 그러나 이체 폼에서 사용자가 직접 kind 를 고를 수 있어(자동 추천은 GENERIC 고정,
사용자 override 가능 — `transfer_form_page.dart:41~47, 96~103, 234`) **"이체로 기록된 지출"을
한 건 넣는 순간 발현**한다. `[1차]`

부수 확인 `[측정: grep]`: `totalTransfer = 0L` 이 만드는 값은 **FE 어디에서도 쓰이지 않는다** —
`totalTransfer` 를 읽는 FE 코드는 `ledger_summary.dart`(클라 계산) 뿐이고, 장부 합계바는 클라값,
분석 탭은 이체 칸을 아예 그리지 않는다. **착수 지점이 근거로 든 `StatisticsService.kt:147` 은
표시되지 않는 죽은 값이었다** — 이 회차의 전제를 여기서 정정한다.

### F3. 합계 어느 칸에도 안 들어가는 행 — **발현 중 (설계 의도, 표시 문제)**

- `ADJUSTMENT` 17건 `[측정]`: 행에는 부호 있는 금액으로 렌더링됨
  (`transaction_list_tile.dart:29~34, 144`). BE 통계는 전량 제외
  (`ExpenseCalculator.kt:88~97`), FE `LedgerSummary` 는 `balance` 에만 반영하지만
  합계바 잔액은 `displayIncome - displayExpense` 로 계산해 **그 balance 를 쓰지 않는다**
  (`transaction_list_page.dart:834`) → ADJUSTMENT 는 화면 어디에도 안 잡힌다
- `CARD_SETTLEMENT` 이체 8건 `[측정]`: `gateLedger` 는 kind 를 보지 않아 행에 남지만
  모든 버킷에서 제외 `[1차]`

의도된 규칙이지만(원본 EXPENSE 로 이미 집계 / 잔액 전용) **행에 그 사실이 표시되지 않으면
사용자에게는 "합계에서 빠진 행"** 이다. 판정이 필요한 항목.

### F4. 페이지네이션 — **잠재 (여유 8건)**

행은 page 0 / 200건, 서버 합계는 범위 전체 `[1차]` (`transaction_bloc.dart:67, 88~94`).
월 최대 119건이라 월 단위로는 미발현이나 `[측정]`, 기간 필터로 범위를 넓히면 도달한다
(§1 표본이 이미 192건). 자동 LoadMore 가 있어 최종적으로는 채워지지만
**로드 완주 전 합계 > 행** 구간이 존재한다.

---

## 4. 근본 원인 (한 문장)

행 집합과 합계 집합이 **같은 소스에서 나오지 않는다**: 합계는 서버(거래 전용·범위 전체)와
클라(이체·포커스 월 한정)를 한 줄에 섞고, 이체 스트림의 로드 범위(월)는 필터의 범위(임의 기간)와
다르다. `gateLedger` 가 봉인한 것은 "축의 누락"이었고, 남은 구멍은 **"범위와 소스의 불일치"** 다.

---

## 5. 구조적 수정 방향 (게이트 대응) — 사전 판정 기준 포함

게이트가 패치 수정을 불허하므로, 두 안 중 하나를 택해 컴파일/테스트 수준으로 강제한다.

### 안 A (권장) — 서버 단일 집계 + 이체 로드 범위를 필터에 종속

- **S1**: BE 합계에서 `hasContentFilters` 분기를 **없앤다**. 이체 집계도 필터 축을 받는
  단일 함수(`ExpenseCalculator` 확장)로 통일해 두 경로가 같은 코드를 타게 한다 —
  `totalTransfer = 0L` 하드코딩 삭제. (분기 제거 = 재발 불가, 패치가 아니라 구조)
- **S2**: 이체 로드를 **기간 기반**으로 바꾼다 — `LoadTransfers({required dateFrom, required dateTo})`.
  `required` 라 호출부가 월만 넘기면 컴파일이 실패한다(`ledgerLocation` 선례와 동일한 강제).
- **S3**: BE 합계 응답에 **집계에 포함된 건수**(거래/이체/제외)를 실어 FE 가 표시 행 수와
  대조 가능하게 한다 → 위젯 테스트가 "합계 = 행" 을 골든으로 고정.
- **S4**: 합계바가 서버·클라 혼합 소스를 쓰면 실패하는 소스 검사 가드
  (인라인 게이팅 재도입 검사 테스트의 선례를 그대로 확장).
- **S5**: BE 테스트 공백 메우기 — `StatisticsServiceTest` 에 `totalTransfer`/필터 조합 케이스가
  **0건** `[측정: grep]`. kind × 필터 축 매트릭스를 Kotest 로 고정.

### 안 B (비권장) — 클라 단일 집계

모든 행을 완주 로드한 뒤 `LedgerSummary` 로만 계산. 범위가 넓어질수록 라운드트립·정확도 비용이
커지고 F4 를 악화시킨다. 200건 초과 달의 페이지 UI(대기열 1번)와도 충돌.

### 결정 항목 — "무엇이 나오면 어느 쪽" (사후 합리화 방지)

- **Q1. 합계에 이체를 포함하는가?** → 포함이 정답으로 **판정한다**. 근거: 무필터 경로·
  `getMonthlyTrend`·`ReconciliationAggregator`·FE `LedgerSummary` 가 **전부 이미 포함 규칙**이고
  어기는 곳은 필터 경로 하나뿐이다 `[1차]`. **반증 조건**: 사용자가 "필터를 걸면 이체는 빼는 게
  맞다"고 판단하면, 그때는 **행에서도 이체를 제외하고 이체 칸도 숨겨야** 한다 — 한쪽만 바꾸면
  같은 불일치가 방향만 바꿔 남는다.
- **Q2. 기간 필터가 월을 넘을 때 이 화면의 정체성은?** "기간 장부"로 판정하면 S2(이체도 범위 로드)가
  정답. "월 장부"로 판정하면 **기간 필터를 월 안으로 제약**하거나 월 밖 데이터를 거래 쪽에서도
  잘라야 한다. 어느 쪽이든 거래·이체·합계 세 곳이 같은 범위를 봐야 한다.
- **Q3. ADJUSTMENT / CARD_SETTLEMENT 행을 계속 보여주는가?** 보여주면 "합계 제외" 배지를 붙인다.
  안 보여주면 잔액 흐름 추적이 끊긴다 → 배지 쪽을 권장.

---

## 6. 미해결 사항 (본문에 섞지 않고 격리)

- **20곳 표시 위치 전수 조사 미실시** `[미확인]` — 금액 표시 지점 전수(메모리
  `feedback_financial_consistency`)는 기획 단계에서 `scope-auditor` 관점으로 수행해야 한다.
  현재 확인한 소비 지점은 장부 합계바·달력뷰·러닝밸런스·정산 뷰 4곳뿐.
- **분석 탭(PeriodSummary)의 필터 경로** `[미확인]` — `getPeriodSummary` 도 같은
  `hasContentFilters` 패턴(`StatisticsService.kt:373, 402~403, 440`)을 갖지만, 화면이 어떤
  필드를 그리는지 전수 확인하지 않았다. 확인 주체: 기획 단계, 수단: `period_summary` 위젯 grep.
- **사용자 원 보고의 존재 여부** `[미확인]` — 이 증상은 2026-08-10 **자체 코드 검토**에서
  파생된 항목이다(대장 타임라인 16 "미해결로 남긴 것"). 사용자가 실제로 목격한 화면·필터 조합이
  있다면 F1 인지 F3 인지 특정이 달라진다. 확인 주체: 사용자.
- **`EXPENSE_TRANSFER` 를 실제로 쓸 계획인지** `[미확인]` — 쓰지 않는다면 F2 의 우선순위는
  낮아지고(가드 테스트만), 쓴다면 F1 과 함께 한 PR 로 묶어야 한다. 확인 주체: 사용자.

---

## 7. 다음 단계

1. §5 Q1~Q3 판정 (사용자) → 2. 기획서 승격
   `docs/sessions/2026-08-12_2_summary-row-mismatch_plan.md` 에 S1~S5 구조적 수정 명시 →
   3. `acknowledge-gate.sh budget-book <plan_path>` 로 게이트 해제 → 4. 승인 후 구현
