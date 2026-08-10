# 홈 대시보드 "월말 점검(미기록 N건)" 위젯 — 설계 정본

- 회차: 2026-08-10 (2) — 진행 대장 §3 후보 1번
- 상태: **기획 완료 · 사용자 승인 대기** (승인 전 코드 변경 0줄)
- 선행 회차: 장부 필터 게이팅 단일화(PR #292, 라이브 검증 통과 = 종결)

---

## 1. 요청 내용

홈 대시보드에 그 달의 **미기록(=아직 정산 스냅샷에 담기지 않은) 항목 수**를 보여주는 위젯을 추가하고,
탭하면 거래 탭의 **정산 뷰**로 그 달 그대로 진입한다.

### 1-1. 용어 정정 (대장 표기 → 앱 용어)

대장 후보에는 "미정산 N건" 으로 적혀 있으나 **앱 안의 용어는 "미기록"** 이다
(`reconciliation_view.dart:585` `'미기록 ${summary.unrecordedCount}건'`).
또 "정산" 은 이 프로젝트에서 3개 동명 개념(장부 정산 스냅샷 / 카드 결제 / 주간 예산 마감)이라
위젯 이름에 그대로 쓰면 혼동된다. 따라서

- 위젯 이름: **월말 점검**
- 본문 지표: **미기록 N건**

으로 확정한다. (근거: 메모리 `reference_reconciliation_snapshot`)

---

## 2. 영향 범위 분석 (측정된 사실만)

### 2-1. 데이터는 이미 있다 — BE 신규 개발 없음

- `GET /api/v1/reconciliations/summary?year&month` 존재
  (`ReconciliationController.kt:51`, `@AuthUser` + year/month 필수)
- 응답 필드: `yearMonth / snapshotCount / recordedCount / unrecordedCount /
  unrecordedIncome / unrecordedExpense / unrecordedTransfer / needsReviewCount`
- FE 배선 전부 존재: `ReconciliationRepository.getSummary(year, month)` →
  `ReconciliationSummary` 엔티티(`isFullyReconciled` getter 포함) · DI 등록 완료
  (`injection.dart:97~100`)
- **따라서 이번 회차는 FE 전용.** BE·DB·마이그레이션·api-spec 변경 0

### 2-2. 대시보드 위젯 등록 지점 — 전수 조사 결과 5곳

위젯 하나를 추가하려면 다음 5곳을 **모두** 손대야 한다(하나라도 빠지면 부분 동작).

1. `home/domain/entities/dashboard_widget_config.dart` — `defaultDashboardWidgets` 등록
2. 같은 파일 — `defaultWidgetSettings` 기본 설정값
3. `home/presentation/pages/dashboard_page.dart:67` `_buildWidgetById` 렌더 분기
4. `home/presentation/widgets/widget_settings_sheet.dart:107` `_buildControls` 설정 분기
   (없으면 "설정 가능한 항목이 없습니다" 로 폴백)
5. `settings/presentation/pages/home_config_page.dart:45` `_getIconData` 아이콘 매핑
   (없으면 ON/OFF·순서 화면에서 회색 `Icons.widgets` 폴백으로 보인다)

- 기존 사용자 마이그레이션은 불필요: `HomeConfigService.loadConfig` 가 저장 목록에 없는
  신규 기본 위젯을 **끝에 자동 append** 한다(`home_config_service.dart:36~41`). 측정 완료.

### 2-3. 발견성 결함 (이번에 같이 고쳐야 하는 이유)

- `DashboardPage` 는 위젯 설정을 **initState 와 pull-to-refresh 에서만** 다시 읽는다
  (`dashboard_page.dart:45`, `:170`).
- 홈 화면 구성 페이지(`/settings/home-config`)는 push 로 열리므로 pop 해도 `DashboardPage`
  의 State 가 유지 → **위젯을 켜도 홈에 즉시 나타나지 않는다.**
- 새 위젯은 기본 OFF 이므로 사용자의 첫 동작이 "켜기" 다. 그 직후 아무것도 안 보이면
  기능이 없는 것처럼 보인다(메모리 `feedback_process_overhaul` P4 = 구현≠발견).
- 기존 위젯(월별 추이·카테고리별 현황)에도 이미 있던 결함 —
  한 곳만 고치지 않고 **설정 저장 경로 전체**를 한 번에 처리한다
  (메모리 `feedback_common_scope_audit`).

### 2-4. 네비게이션 — 정산 뷰는 URL 로 진입할 수 없다 (측정)

- 거래 탭 뷰 모드(`리스트|달력|정산`)는 **SharedPreferences 에만** 저장된다
  (`transaction_list_page.dart:80` `_kTxViewModePrefKey`, `:182 _loadViewMode`,
  `:196 _saveViewMode`).
- `/transactions` 라우트에는 `view` 쿼리 파라미터가 **없다**
  (`app_router.dart:277~287` 에서 읽는 키는 year·month·paymentMethodId·paymentMethodName·
  categoryId·categoryName·categoryGroupId 7개뿐).
- 즉 "위젯 탭 → 정산 뷰" 는 지금 구조로는 **불가능**하다. `view` 파라미터 신설이 필요하다.

### 2-5. 이전 세션 함정 — 이 파일에 이미 확립된 규칙

`transaction_list_page.dart` 의 `didUpdateWidget` 은 **value→null 전환을 reset 신호로 보지 않는다**
(`:104~175`, 2026-05-26 회귀 fix). 새 `view` 파라미터도 같은 규칙을 따라야 한다 —
따르지 않으면 "정산 뷰로 들어갔다가 거래를 수정 저장하면 리스트로 튕김" 회귀가 생긴다.
(지식 캐시 `filter-propagation-nav-vs-content.md`)

---

## 3. 하네스 Scope Audit 결과

실행: `bash ~/.claude/harness/scripts/pre-change-audit.sh . <tag>`

- `ui_pattern` → ⚠️ WARNING (과거 인시던트 2건, 전부 타 프로젝트) · GATE OPEN
- `navigation_state` → 🚫 **STRUCTURAL_FIX_REQUIRED** (과거 인시던트 3건) · GATE LOCKED

### 3-1. navigation_state 인시던트 3건 (전부 같은 뿌리)

1. `[2026-04-14]` 예산 3월 → 카드 선택 → 4월 거래 표시
2. `[2026-04-15]` 홈/예산 월 이동 후 거래 이동 시 현재 월로 리셋
   - 당시 재발 방지책: **"`navigation_helpers.dart` 중앙 헬퍼 도입 — year/month required
     파라미터로 컴파일 타임 누락 방지"**
3. `[2026-04-15]` 월 이동 시 카드 요약이 홈/예산에서 stale

### 3-2. 측정: 그때 약속한 구조적 수정은 **실제로 도입되지 않았다**

```
find lib -name "navigation_helpers*"   → 0건
```

`dashboard_page.dart` 는 지금도 `context.go('/transactions?year=$year&month=$month')` 를
**문자열로 직접 조립**한다(`:647`, `:1166` 등). 3회 재발의 이유가 이것이다 —
방지책이 문서로만 남고 코드 강제가 없었다.

### 3-3. 이번 회차가 이행할 구조적 수정

새 위젯도 "홈의 그 달 → 거래 탭 정산 뷰" 로 이동하므로 정확히 같은 위험군에 들어간다.
따라서 이번 PR 에 다음을 **함께** 넣는다.

1. **중앙 헬퍼 신설** `lib/core/utils/ledger_route.dart`
   - `String ledgerLocation({required int year, required int month, LedgerView? view,
     String? paymentMethodId, String? paymentMethodName, String? categoryId,
     String? categoryName, String? categoryGroupId})`
   - `year`/`month` 를 **required** 로 두어 월 누락을 **컴파일 타임에** 막는다
     (2026-04-15 인시던트가 지정한 방지책 그대로).
2. **기존 조립부 이관** — `dashboard_page.dart` 의 `/transactions?...` 직접 조립을 전수
   헬퍼 경유로 바꾼다. 측정한 장부 목록 URL 은 **3곳**:
   `:647`(최근 거래 더보기) · `:774`(결제수단별 현황 탭) · `:1166`(카테고리별 현황 탭).
   여기에 새 위젯 1곳이 더해져 4곳. `/transactions/create`(3곳)·`/transactions/detail`(1곳)은
   **다른 라우트**라 이번 범위 밖이다(거래 추가 URL 은 이미 거래 목록 페이지의
   `_buildCreateTransactionUrl` 단일 소스가 담당).
3. **가드 테스트** — `dashboard_page.dart` 소스에 raw `'/transactions?` 리터럴이
   **0건**임을 소스 스캔으로 고정. 새 진입 경로가 헬퍼를 우회하면 테스트가 깨진다.
4. **위젯 등록 누락 가드** — `defaultDashboardWidgets` 의 모든 id 가 `_buildWidgetById`
   분기와 `_getIconData` 매핑에 존재하는지 소스 스캔으로 강제(§2-2 의 5곳 중 3·5번).
   위젯을 추가하면서 등록을 빠뜨리는 유형(`feedback_feature_impact_check`)을 테스트로 고정.

→ 기획서에 구조적 수정을 포함했으므로 착수 직전 `acknowledge-gate.sh` 로 게이트를 해제한다.

---

## 4. 작업 계획

### Step A — 중앙 라우팅 헬퍼 (구조적 수정, 선행)

- A1. `lib/core/utils/ledger_route.dart` 신설: `enum LedgerView { list, calendar, reconciliation }`
  + `ledgerLocation(...)`. year/month required.
- A2. `app_router.dart` `/transactions` builder 에 `view` 쿼리 파라미터 파싱 추가 →
  `TransactionListPage(initialView: ...)`.
- A3. `transaction_list_page.dart`:
  - 생성자에 `final String? initialView` 추가
  - `initState`: `initialView` 가 있으면 그 값을 적용하고 **`_loadViewMode()` 를 호출하지 않는다**
    (비동기 prefs 복원이 URL 지정을 덮어쓰는 레이스 차단)
  - `didUpdateWidget`: null→value, value→다른 value 만 반영. **value→null 은 무시**(§2-5 규칙)
  - URL 진입은 **prefs 를 덮어쓰지 않는다**(1회성 이동 의도이지 기본값 변경이 아님).
    사용자가 화면 안에서 토글하면 기존대로 저장된다.
- A4. `dashboard_page.dart` 의 기존 `/transactions?...` 조립부를 헬퍼 경유로 이관.

### Step B — 데이터 로드 (DashboardBloc)

- B1. `DashboardBloc` 에 `ReconciliationRepository` 주입.
- B2. `_onLoadDashboard` 의 기존 `Future.wait` 6개 병렬 호출에 요약 조회를 **합류**시킨다
  (직렬 대기 추가 없음). 실패는 기존 trend/breakdown 과 같은 정책으로 **조용히 무시** → 위젯 미표시.
- B3. **위젯이 꺼져 있으면 호출 자체를 생략**한다. 판정은 `HomeConfigService.loadConfig()`
  (BLoC 이 이미 SharedPreferences 를 읽는 선례 있음: `_getRecentCount`, `dashboard_bloc.dart:31`).
  기본 OFF 이므로 **켜지 않은 사용자에게는 추가 API 호출 0**.
- B4. `DashboardLoaded` 에 `ReconciliationSummary? reconciliationSummary` 추가(+ `props`).
- B5. `injection.dart:485` 등록부에 리포지토리 주입 인자 추가.

### Step C — 위젯

- C1. `home/presentation/widgets/reconciliation_summary_card.dart` 신설.
  - 헤더: `Icons.fact_check` + `월말 점검` 제목 + `더보기` 버튼
  - 본문: **미기록 N건**, 소계(지출/수입/이체)는 **BE 계산값을 그대로** 표시
    (FE 재합산 금지 — `reconciliation_view.dart` 와 동일 규칙)
  - `needsReviewCount > 0` 이면 "확인 필요 M건" 칩
  - `unrecordedCount == 0 && recordedCount > 0` → `isFullyReconciled` 로 "정산 완료" 상태 표시
  - 탭·더보기 → `shell.goBranch(1)` + `ledgerLocation(year, month, view: reconciliation)`
  - 요약이 null(조회 실패)이면 위젯 자체를 렌더하지 않는다(`_buildWidgetById` 가 null 반환)
- C2. 설정 항목 1개: `showSubtotals`(소계 줄 표시 ON/OFF, 기본 true).

### Step D — 등록 5곳 전수 (§2-2)

- D1. `defaultDashboardWidgets` 에 `id: 'reconciliation_summary'`, `name: '월말 점검'`,
  `icon: 'fact_check'`, `enabled: false`, `order: 10` 추가
- D2. `defaultWidgetSettings['reconciliation_summary'] = {'showSubtotals': true}`
- D3. `dashboard_page._buildWidgetById` 분기 추가
- D4. `widget_settings_sheet._buildControls` 분기 추가(소계 표시 토글)
- D5. `home_config_page._getIconData` 에 `'fact_check'` 매핑 추가

### Step E — 설정 변경 즉시 반영 (§2-3)

- E1. `HomeConfigService` 에 `static final ValueNotifier<int> revision` 추가.
  `saveConfig` / `updateWidgetSettings` 성공 시 bump.
- E2. `DashboardPage` 가 구독 → `_loadWidgetConfig()` 재실행 + `LoadDashboard` 재발행
  (새로 켠 위젯의 데이터가 아직 state 에 없으므로 재조회가 필요하다).
- E3. dispose 에서 리스너 해제.

### Step F — 테스트 (§7)

---

## 5. 성능 설계

- **기본 OFF + 호출 게이팅**: 위젯을 켜지 않은 사용자는 네트워크 요청이 1건도 늘지 않는다(B3).
- **병렬 합류**: 켠 경우에도 기존 6개 호출과 같은 `Future.wait` 에 들어가므로
  대시보드 체감 로딩 시간은 **가장 느린 호출 하나**에 의해 결정된다(직렬 증가 없음).
- **BE 신규 쿼리 없음**: 정산 뷰가 이미 쓰는 동일 엔드포인트. 인덱스·쿼리 변경 불필요.
- **폴링·캐시 없음**: 월 변경 / pull-to-refresh / 설정 변경(E2) 시에만 재조회.
- 요약 응답은 정수 8개짜리 소형 페이로드 — 렌더 비용 무시 가능.
- 아이콘: `Icons.fact_check` 는 이미 번들에 포함(`transaction_list_page.dart:1399`) →
  **트리셰이킹 폰트 subset 불변** = 아이콘 캐시 사건(`docs/incidents/2026-07-30_...`) 위험군 아님.

---

## 6. 리스크와 차단책

1. **뷰 모드 레이스** — URL 로 정산 뷰 진입했는데 async prefs 복원이 리스트로 되돌림.
   → A3 에서 `initialView` 가 있으면 `_loadViewMode()` 자체를 건너뛴다 + 회귀 테스트.
2. **value→null 회귀** — 정산 뷰에서 거래 수정 저장 → `?year&month` 로 돌아올 때 튕김.
   → A3 의 didUpdateWidget 규칙 + 회귀 테스트.
3. **prefs 오염** — 위젯으로 한 번 들어갔다고 기본 뷰가 정산으로 바뀌면 안 된다.
   → A3 에서 URL 진입은 저장하지 않는다 + 테스트.
4. **등록 누락** — 5곳 중 일부만 반영.
   → §3-3(4) 가드 테스트가 소스 스캔으로 강제.
5. **월 누락** — 홈에서 3월을 보다 위젯을 눌렀는데 이번 달 정산이 뜬다(과거 3회 재발 유형).
   → `ledgerLocation` 의 required year/month 로 컴파일 타임 차단.

### 6-1. 수용하는 한계 (설계상 의도)

정산 뷰에 URL 로 진입한 뒤 `?year&month` 만 있는 URL 로 재진입할 때,
**State 가 재생성되면** 저장된 뷰(리스트/달력)로 돌아간다. GoRouter 는 같은 path 재진입 시
State 를 재사용하므로(지식 캐시 `filter-propagation-nav-vs-content.md`) 실사용 경로에서는
발생하지 않지만, "URL 진입은 기본 뷰를 바꾸지 않는다"(리스크 3)를 지키기 위해 감수하는 쪽을
택했다. 반대로 URL 진입 시 prefs 를 덮어쓰면 이 한계는 사라지지만 사용자의 기본 뷰가
말없이 바뀐다 — 그쪽이 더 나쁘다고 판단했다. 검증 시나리오 B3·C1 이 이 선택을 확인한다.

---

## 7. 자동 검증 계획

신규·수정 테스트

1. `test/features/home/presentation/bloc/dashboard_bloc_test.dart`(수정)
   - 기존 3개 build 에 Mock 리포지토리 추가
   - 신규: 위젯 ON → 요약이 `DashboardLoaded.reconciliationSummary` 에 실린다
   - 신규: 위젯 OFF → `getSummary` 가 **호출되지 않는다**(`verifyNever`)
   - 신규: 요약 조회 실패 → 나머지 데이터는 정상 로드되고 요약만 null
2. `test/features/home/reconciliation_summary_card_test.dart`(신설)
   - N건 표시 / 소계는 BE 값 그대로 / `needsReviewCount>0` 칩 / 0건+recorded>0 → 정산 완료
   - 더보기 탭 시 목적지 URL 에 `year`·`month`·`view=reconciliation` 이 모두 실린다
3. `test/core/utils/ledger_route_test.dart`(신설)
   - view 직렬화 / 선택 파라미터 생략 / 기존 URL 형태와 동등
4. `test/features/transaction/transaction_list_view_param_test.dart`(신설)
   - `view=reconciliation` 진입 시 정산 뷰 · prefs 미변경 · value→null 무시
5. `test/features/home/dashboard_widget_registry_guard_test.dart`(신설)
   - 등록 누락 가드(§3-3-4) + `dashboard_page.dart` raw `/transactions?` 리터럴 0건 가드
6. `test/features/home/home_config_revision_test.dart`(신설)
   - saveConfig 시 revision bump

로컬 CI 4종(전부 통과해야 PR 진입 — GR8)

- `flutter analyze --no-fatal-infos --no-congratulate` (**전체 경로**, 부분 경로 금지)
- `flutter test` (현재 843건 + 신규)
- `./gradlew test` (BE 무변경이지만 회귀 확인용)
- `flutter build web --release`

---

## 8. 배포 절차

1. 브랜치 `feat/dashboard-reconciliation-widget`
2. 로컬 CI 4종 → 커밋 → 진행 대장 갱신(GR14) → 푸시 → PR
3. 원격 CI 2종(`backend-ci` / `frontend-ci`) 통과 → squash 머지 + 브랜치 삭제
   (개인 계정 자동 진행 범위 — `feedback_personal_account_auto_merge`)
4. `deploy-nas` 실행 확인(deploy-frontend / verify-live)
5. 라이브 번들 검증: 한글은 `\uXXXX` 로 이스케이프되므로 **escaped 형태로 대조**
   (`월말 점검`, `미기록`, `view=reconciliation`) + `last-modified` 확인
   (`reference_live_bundle_string_verification`)
6. **사용자 라이브 검증 통과 전까지 "완료" 아님**(GR3)

---

## 9. 사용자 검증 시나리오

### A. 위젯 노출과 데이터

- A1. 설정 → 홈 화면 구성 → "월말 점검" 항목이 목록에 보이고 아이콘이 회색 기본값이 아니다
- A2. ON 으로 켠다 → **홈으로 돌아오면 새로고침 없이 바로 위젯이 보인다**
- A3. 위젯의 "미기록 N건" 이 거래 탭 정산 뷰 상단의 건수와 **같다**
- A4. 소계(지출/수입/이체)가 정산 뷰 헤더와 같다
- A5. 확인 필요 항목이 있는 달이면 "확인 필요 M건" 이 함께 보인다
- A6. 그 달을 전부 정산한 상태면 "정산 완료" 로 바뀐다

### B. 네비게이션 (과거 3회 재발 유형)

- B1. 홈에서 **지난 달**로 이동 → 위젯 탭 → 거래 탭 정산 뷰가 **그 지난 달**로 열린다
      (이번 달로 리셋되지 않는다)
- B2. 거래 탭에서 뒤로 → 홈의 달이 그대로다
- B3. 정산 뷰에서 항목 하나를 수정 저장 → **정산 뷰에 그대로 머문다**(리스트로 튕기지 않는다)

### C. 설정 보존

- C1. 위젯으로 정산 뷰에 들어갔다가 나온 뒤, 거래 탭을 직접 열면 **원래 쓰던 뷰**(리스트/달력)로 열린다
      (위젯 진입이 기본 뷰를 바꾸지 않는다)
- C2. 위젯 설정에서 "소계 표시" 를 끄면 소계 줄만 사라지고 건수는 남는다
- C3. 홈 화면 구성에서 순서를 바꾸면 위젯 위치가 즉시 반영된다
- C4. 위젯을 다시 OFF 하면 홈에서 사라진다

---

## 10. 범위 밖 (이번 회차에서 하지 않는 것)

- 미기록 200건 초과 달의 추가 페이지 로드 UI(대장 후보 2번)
- 합계 ≠ 행 잔존 불일치(대장 후보 3번)
- 월말 "미기록 N건" 인앱 알림(대장 후보 5번) — 알림 인프라 선행 필요
- BE 변경 일체(요약 엔드포인트 재사용만 한다)
