# 월 네비게이터 개선 — 연/월 드릴다운 피커 + "오늘" 버튼

- 회차: **다음 회차 후보 1번** → **2026-08-11 착수 회차**
- 상태: **기획 v2 (재측정 반영) · 착수 승인 대기**. 코드 변경 0줄
- 요청(사용자, 2026-08-10): "거래 상단 `< yyyy년 mm월 >` 에서 날짜 선택 시 뜨는 달력 팝업에서
  **연도별 보기 → 연도 내 달 선택**이 편했으면 좋겠다. 또 **팝업 전에 '오늘로 가는 버튼'** 이
  적절한 위치에 있으면 좋겠다."

> **v1 → v2 변경 이유(2026-08-11 재측정)**: v1 의 사실 2건이 틀렸다.
> ① "사용처 13개 페이지" → 실제로 **렌더되는 호스트는 9개**. 3개 호출부는 `showMonthNavigator: false`
> 로만 쓰여 화면에 나오지 않는다. ② v1 Step 3(홈 `_MonthHeader` 통합)은 홈 화면이 미라우팅
> 죽은 코드라 **무효**. 그런데 v1 의 구조적 수정(Step 4)이 그 Step 3 에 의존하고 있었다 →
> 구조 항목을 재설계했다.

---

## 1. 측정된 현재 상태 (hard evidence, 2026-08-11)

### 1.1 월 네비게이터는 공용 위젯 하나다 `[측정]`

`lib/core/widgets/month_navigator.dart` (106줄). `MonthNavigator(` 호출부는 소스상 12곳/11파일.

### 1.2 그중 **실제 화면에 렌더되는 호스트는 9개** `[측정]`

라우팅되어 사용자에게 도달하는 호출부:

1. `transaction/…/transaction_list_page.dart:678` — 거래 탭. **유일하게 `onDatePicked` 사용**
2. `analysis/…/analysis_page.dart:47` — 분석 탭 (예산/통계 sub-tab 공용)
3. `transfer/…/transfer_list_page.dart:72` — `/transfers`
4. `payment_method/…/payment_method_page.dart:134` — `/payment-methods`
5. `settings/…/asset_management_page.dart:117` — 자산 탭 + `/asset-management`
6. `weekly_budget/…/weekly_budget_page.dart:60` — `onMonthChanged` 커스텀
7. `weekly_budget/…/weekly_settlement_page.dart:97` — `onMonthChanged` 커스텀
8. `report/…/report_page.dart:85` — `onMonthChanged` 커스텀
9. `spending_plan/…/spending_plan_list_page.dart:118` — `onMonthChanged` 커스텀

**렌더되지 않는 호출부 3곳** — 이번 변경의 검증 대상이 아니다:

- `statistics_page.dart:68` — `if (showMonthNavigator && !state.hasDateRange)`
- `budget_list_page.dart:269`, `:566` — `if (widget.showMonthNavigator)`
- 두 페이지의 유일한 사용처가 `analysis_page.dart:117/135` 의
  `showMonthNavigator: false` 이고, `/budgets`·`/statistics` 라우트는 분석 탭으로 redirect 다.
  즉 이 3곳은 **파라미터로 꺼져 있는 죽은 분기**다.

**추가 예외 1곳** — `home/…/dashboard_page.dart:198 _MonthHeader`. MonthNavigator 를 쓰지 않는
자체 구현이고 가운데가 `Text` 라 눌러도 팝업이 없다. 그러나 **홈은 미라우팅**
(`app_router.dart:792` `/home` → `/transactions` redirect)이라 사용자에게 도달하지 않는다.
→ v1 이 계획한 "홈 통합" 은 **무효**. 삭제도 하지 않는다(홈 탭 복원 여부는 미결 사항).

### 1.3 팝업은 `showCalendarPickerDialog` 하나이고, **일 선택이 본질인 호출부가 17곳**이다 `[측정]`

`core/widgets/calendar_picker_dialog.dart` → 내부는 Material `CalendarDatePicker`.
호출부 18곳 중 **MonthNavigator 는 1곳**이고, 나머지 17곳은 전부 "특정 날짜 입력"이다:
`period_selector.dart` 5곳(기간 필터 시작/종료), 거래·이체·보험·지출계획·카드정산 폼,
포켓 시트 2곳, `transaction_list_page.dart:1225`.

→ **결론: 기존 함수는 손대지 않는다.** 월 피커는 별도 함수로 신설한다.
(v1 은 "통합 여부를 착수 시 확인" 으로 열어뒀는데, 측정 결과 통합은 17곳 회귀 위험만 있다.)

### 1.4 결손 지점 `[측정]`

- `CalendarDatePicker` 는 연도 목록은 열리지만 **월 그리드가 없다.** 연도를 골라도 그 연도의
  *같은 달* 일 그리드로 돌아오고, 원하는 달까지 좌우로 넘겨야 한다. → 요청 ①이 가리키는 지점.
- **"오늘" 버튼은 어디에도 없다** — MonthNavigator·팝업 모두. → 요청 ②.

### 1.5 부수 확인 `[측정]`

- `Icons.today` 는 이미 `period_selector.dart:138`·`date_range_filter.dart:59` 에서 쓰인다
  → **신규 아이콘 코드포인트 없음. 아이콘 폰트 subset 변화 없음**
  (`reference_flutter_icon_font_cache` 리스크 해당 없음).
- `MonthNavigator` 전용 테스트는 **없다**. `test/core/widgets/` 에 `period_selector_test.dart`
  등 12개가 있으나 월 네비게이터는 미커버.
- 소스 스캔 가드 테스트 선례 다수(`ledger_view_param_wiring_test.dart`,
  `dashboard_widget_registry_guard_test.dart` 등) → 같은 패턴을 따른다.

---

## 2. 하네스 게이트와 구조적 수정 (필수)

`pre-change-audit.sh . navigation_state` → **🚫 STRUCTURAL_FIX_REQUIRED (LOCKED)**, 인시던트 4건.

- 2026-04-14 예산 3월 → 카드 선택 → 4월 거래 표시
- 2026-04-15 홈/예산 월 이동 후 거래 이동 시 현재 월로 리셋
- 2026-04-15 월 이동 시 카드 요약이 홈/예산에서 stale
- 2026-08-10 홈 대시보드에 위젯 추가 → CI 전부 통과·배포까지 갔는데 **죽은 화면이라 미노출**

앞 3건의 구조적 이행은 2026-08-10 회차의 `ledgerLocation()`(required year/month → 컴파일 에러)이
이미 담당한다. **이번 회차가 추가로 이행할 구조 항목은 4번째 인시던트 축**이다 —
"공용 월 UI 를 고쳤는데 어떤 화면에는 반영되지 않는다 / 죽은 화면에 반영한다".

### 구조 항목 S1 — 자체 월 헤더 금지 (소스 스캔 가드)

`Icons.chevron_left` 와 `changeMonth(` 를 **동시에** 가진 파일은 `month_navigator.dart` 하나여야
한다. 현재 위반 후보는 `dashboard_page.dart` 1건뿐 `[측정]`.

- 이 파일은 **"미라우팅인 동안만" 예외**로 허용한다. 가드가 `app_router.dart` 를 함께 읽어
  `/home` 이 여전히 redirect 인지 확인하고, redirect 가 사라지면(=홈을 되살리면) **테스트가 실패**한다.
  → 홈 복원 시 `_MonthHeader` → `MonthNavigator` 이행이 강제된다.
- 이 예외 방식이 "죽은 코드를 지금 삭제" 보다 나은 이유: 홈 복원 여부가 미결이고, 삭제하면
  `dashboard_widget_registry_guard_test.dart`·`home_config_page` 까지 연쇄 정리가 필요해
  이번 요청의 범위를 벗어난다.

### 구조 항목 S2 — 월 피커 단일 소스

`showMonthYearPickerDialog` 를 직접 호출하는 파일은 `month_navigator.dart` 하나여야 한다.
(월 이동 UI 가 다시 페이지별로 갈라지는 것을 막는다.)

### 구조 항목 S3 — 도달성 고정 (2026-08-10 인시던트 직결)

§1.2 의 **9개 호스트 목록을 테스트에 상수로 박는다.** 각 항목에 대해
① 그 파일이 `MonthNavigator(` 를 포함하고 ② `app_router.dart` 가 그 페이지를 참조하는지 검사.
동시에 §1.2 의 "렌더되지 않는 3곳" 은 목록에서 제외돼 있음을 주석으로 명시 —
다음 사람이 "13곳에 반영됐다" 고 착각하지 못하게 한다.

### 구조 항목 S4 — MonthNavigator 위젯 테스트 신설

`test/core/widgets/month_navigator_test.dart` — 지금까지 0건이라 회귀 감지가 없었다.
9개 호스트 페이지에 개별 테스트를 다는 대신, 공용 위젯 자체를 커버해 9곳을 동시에 방어한다.

> 게이트 해제는 이 문서를 근거로
> `acknowledge-gate.sh budget-book docs/sessions/2026-08-10_3_month-navigator_plan.md` 로 처리한다.

---

## 3. 설계

### Step 1 — 신규 `showMonthYearPickerDialog` (`core/widgets/month_year_picker_dialog.dart`)

반환값:

- `MonthPickerResult { int year; int month; int? day; }` — `day == null` 이면 월까지만 고른 것.
  거래 목록이 "사용자가 실제로 일을 골랐을 때만 스크롤" 을 구분할 수 있어야 하므로
  `DateTime` 단일 타입으로 뭉개지 않는다(1일 반환과 구분 불가해진다).

단계(`_Stage`): `year` → `month` → `day`

- **월 그리드**: 3×4, `1월`~`12월`. 선택 달 filled, 오늘이 속한 달 테두리, 범위 밖 비활성.
  탭 = 즉시 확정(확인 버튼 없음 — 탭 수 최소화가 요청 취지).
- **연도 그리드**: 헤더의 `2026년` 을 탭하면 진입. 3열, 좌우 화살표로 12년 페이징.
  연도 탭 → 월 그리드로 복귀.
- **일 그리드**: `allowDaySelection: true` 일 때만. `CalendarDatePicker` 재사용 +
  상단에 "월 선택으로" 되돌아가기.
- **진입 단계 규칙** (2026-08-11 사용자 결정):
  - `allowDaySelection: false` (호스트 8곳) → **월 그리드로 진입**. 달 선택이 1탭이 된다.
  - `allowDaySelection: true` (거래 목록) → **일 그리드로 진입**(= 기존 첫 화면 그대로).
    헤더 `2026년 8월 ▾` 탭 → 월 그리드 → 헤더 `2026년 ▾` 탭 → 연도 그리드로 *올라간다*.
  - 탭 수 검산 `[추론]`: 거래 탭 기준 달 이동 2탭·일 선택 2탭으로 **어느 쪽도 퇴보가 없다**.
    먼 달 이동만 "좌우 화살표 N회" 에서 "3탭 고정" 으로 개선된다.
  - 기각안: 거래 탭도 월 그리드 진입 — 달 이동은 1탭이 되지만 같은 달 안의 일 스크롤이
    2탭 → 3탭으로 퇴보한다. 사용자가 퇴보 없는 쪽을 선택했다.
- `firstDate`/`lastDate` 기본값은 기존과 동일(2020 ~ 2030-12-31).
- **기존 `showCalendarPickerDialog` 는 변경 없음** (§1.3 — 17개 호출부).

### Step 2 — `MonthNavigator` 배선

```
final res = await showMonthYearPickerDialog(
  context: context,
  initialYear: displayYear, initialMonth: displayMonth,
  allowDaySelection: onDatePicked != null,
);
if (res == null || !context.mounted) return;
if (res.day != null) onDatePicked!(DateTime(res.year, res.month, res.day!));
handleChange((year: res.year, month: res.month));
```

호출부 9곳 모두 **시그니처 변경 없음** — `onDatePicked` 유무로 동작이 갈린다.

### Step 3 — "오늘" 버튼

- 위치: `>` **오른쪽**. 좌측에 같은 폭(48) 투명 스페이서를 넣어 가운데 텍스트의 대칭을 유지한다.
  폭 검산: 아이콘 4칸(48×4=192) + 날짜 텍스트(~90) ≒ 282 < 360(모바일 최소 폭) → overflow 없음 `[추론: 48dp IconButton 기본 폭 × 4 + titleMedium '2026년 8월' 실측 근사]`.
- 표시 중인 달이 이번 달이면 **비활성**(`onPressed: null`).
- 동작: `handleChange((year: now.year, month: now.month))` — 기존 월 변경 경로를 그대로 탄다.
  새 동기화 경로를 만들지 않으므로 `MonthSyncHandler`·페이지별 `onMonthChanged` 가 자동 적용된다.
- 아이콘 `Icons.today`(기존 사용 중), 툴팁 `'이번 달로'`.

### Step 4 — 가드/테스트 (§2 이행)

- `test/core/widgets/month_navigator_single_source_guard_test.dart` — S1·S2·S3
- `test/core/widgets/month_navigator_test.dart` — S4
  - 오늘 버튼: 이번 달이면 비활성 / 다른 달이면 활성 + 탭 시 MonthCubit 이 이번 달로
  - 날짜 탭 → 피커 오픈, 월 선택 시 `onMonthChanged` 호출·`onDatePicked` **미호출**
  - `onDatePicked` 를 준 경우 일 선택이 `onDatePicked` 로 전달
- `test/core/widgets/month_year_picker_dialog_test.dart` — 단계 전환(월→연→월), 범위 밖 비활성

---

## 4. 영향 범위와 리스크

- **회귀 범위 9개 호스트.** 그중 개별 위젯 테스트가 있는 페이지는 `statistics_page_test.dart` 뿐인데
  그건 렌더 안 되는 호출부다 → 실질 커버 0. **공용 위젯 테스트(S4)로 대체 커버**한다.
- **월 그리드 기본 진입의 부작용**: 8개 호스트는 원래 일을 고를 이유가 없다(연/월만 사용) → 영향 없음.
  일 선택이 실제로 쓰이는 거래 목록은 진입 단계를 일 그리드로 유지해 퇴보를 막는다.
- **아이콘 폰트**: 신규 코드포인트 없음 → 캐시 리스크 없음(§1.5).
- **홈 대시보드**: 이번 변경으로 달라지지 않는다(미라우팅). S1 가드가 되살아날 때를 대비한다.

---

## 5. 검증 게이트

로컬 CI 4종 + 배포 전 1종:

1. `flutter analyze --no-fatal-infos --no-congratulate` 전체 — 신규 지적 0
2. `flutter test` — 기존 894건 + 신규 통과
3. `./gradlew test` (BE 무변경이나 게이트 유지)
4. `flutter build web --release`
5. **번들 문자열 확인** — 산출물에서 `이번 달로`(툴팁)와 월 그리드 고유 문자열을 찾는다.
   한글은 번들에서 `\uXXXX` 이스케이프되므로 **escaped 형태로 대조**한다
   (`reference_live_bundle_string_verification`). 2026-08-10 인시던트의 재발 방지 게이트.

## 6. 사용자 검증 시나리오 (배포 후)

- A1. **분석·자산·이체 등**에서 `2026년 8월` 을 누르면 **월 그리드**가 먼저 뜬다
- A2. 헤더의 `2026년` 을 누르면 연도 그리드 → 연도 선택 → 12개월 → 달 선택
- A3. 2024년 3월처럼 먼 달도 좌우 스와이프 없이 도달한다
- A4. **거래 탭**은 기존처럼 **일 달력이 먼저** 뜨고, 헤더를 누르면 월 → 연도로 올라간다
- B1. `>` 오른쪽 **오늘** 버튼으로 어디서든 이번 달로 즉시 복귀
- B2. 이미 이번 달이면 그 버튼이 비활성(회색)
- C1. 거래 목록에서 특정 **일**을 고르면 그 날짜로 스크롤되는 기존 동작이 그대로다
- C2. 어느 화면에서 달을 바꾸든 다른 탭도 같은 달로 따라온다(기존 동작 유지)

---

## 7. 미해결 사항

- **9개 호스트 중 UI 진입점이 실제로 존재하는지는 라우팅 등록까지만 확인했다** `[측정: 라우트 등록]`
  / 각 화면으로 가는 메뉴·버튼 전수는 미확인 `[미확인]`. 이번 변경은 어느 쪽이든 회귀를 만들지
  않으므로(공용 위젯 개선) 착수 조건은 아니다. 확인 주체: 사용자 라이브 검증 A1.
- **`statistics_page`·`budget_list_page` 의 `showMonthNavigator` 죽은 분기 정리** — 이번 범위 밖.
  홈 복원 여부와 함께 별도 회차에서 판단한다.
- **S1 가드는 휴리스틱이다** `[추론: `Icons.chevron_left` + `changeMonth(` 동시 보유로 탐지]`.
  누군가 `Icons.arrow_back_ios` 같은 다른 아이콘으로 자체 월 헤더를 만들면 탐지하지 못한다
  `[미확인: 실효 커버리지]`. 완전한 컴파일 타임 강제는 불가능한 형태(위젯 구성 자유도)이므로,
  탐지 누락이 실제로 발생하면 그때 아이콘 후보를 가드에 추가한다.
- **거래 탭의 드릴업 발견 가능성** — 헤더 `2026년 8월 ▾` 이 눌린다는 것을 사용자가 알아채는지는
  `[미확인]`. `▾` 표식으로 어포던스를 준다. 라이브 검증 A4 에서 판정.

## 8. 범위 밖

- 기간(범위) 선택 — 이번 요청은 단일 월 이동이다
- 주간 예산 화면의 주차 네비게이션
- 홈 대시보드 복원 / 죽은 코드 삭제
