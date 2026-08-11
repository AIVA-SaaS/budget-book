# 연/월 피커 단일 화면 통합 + 스피너 (설계 정본)

- 작성 2026-08-11 · 회차 시작 · 선행 회차 = PR #295(월 네비게이터 드릴다운 피커, 라이브 검증 통과)
- 대상 파일 `frontend/lib/core/widgets/month_year_picker_dialog.dart` (+ 가드/테스트)
- 근거 등급 표기 규칙(글로벌 §1.15): `[측정]` 직접 실행·관측 / `[1차]` 코드·공식 문서 / `[추론]` 유도(과정 병기) / `[미확인]`

---

## 1. 요청 내용 (사용자, 2026-08-11)

1. 월 선택과 연 선택이 **사실상 같은 포맷**인데 서로 왔다갔다 하는 게 번거롭다 → **한 공간에서 연도와 월을 같이** 고르고 싶다
2. `날짜 선택`(일 달력)에서 `2026년 8월` 을 누르면 **연도 설정이 바로 나온다 — 월 선택이 나와야 한다**
3. (부가) 연도·월을 **스피너로 돌려** 고르는 방식도 있으면 좋겠다

### 이번 세션에서 확정된 결정 (사용자 선택)

- **형태 C** — 왼쪽 **연도 휠 스피너** + 오른쪽 **12개월 그리드**를 한 화면에. 단계 전환 0회, 연도 그리드 삭제. 요청 ①·③ 이 이 하나로 수렴한다
- **일 선택** — `CalendarDatePicker` 를 **자체 일 그리드로 교체**. 헤더는 우리가 소유하고, 탭하면 연/월 화면으로 돌아온다

---

## 2. 영향 범위 분석

### 2.1 도달 경로 (2026-08-10 인시던트 대응 필수 항목)

- 거래 탭 `/transactions` → `TransactionListPage._buildLoaded` → `MonthNavigator`(`onDatePicked` 있음 → **일 그리드 진입**) → 가운데 날짜 버튼 탭 → 이 다이얼로그 `[측정]` (`transaction_list_page.dart:678`)
- 나머지 8개 호스트(분석·이체·결제수단·자산관리·주간예산·주간정산·리포트·지출계획) → `MonthNavigator`(`onDatePicked` 없음 → **연/월 화면 진입**) `[측정]` (S3 가드에 목록 고정)
- 즉 **모든 진입점이 이미 살아 있는 화면**이다. 죽은 화면에 얹는 위험 없음

### 2.2 변경 파일

- `frontend/lib/core/widgets/month_year_picker_dialog.dart` — **전면 재작성**(단일 파일, 호출부 1곳)
- `frontend/test/core/widgets/month_year_picker_dialog_test.dart` — 재작성(현행 6건 → 12건)
- `frontend/test/core/widgets/month_navigator_single_source_guard_test.dart` — S2 에 **가드 1건 추가**
- 변경 없음: `month_navigator.dart`(공개 API `showMonthYearPickerDialog` / `MonthPickerResult` 시그니처 유지) · 호스트 9곳 · BE 전부

### 2.3 제약 / 유지해야 할 계약

- `MonthPickerResult.day == null` = "월까지만 골랐다" 신호. 거래 목록이 이 값으로 스크롤 여부를 정한다 `[측정]` (`transaction_list_page.dart:681`, `day > 1` 일 때만 `_pendingScrollToDate`)
- `allowDaySelection: onDatePicked != null` 규칙은 S2 가드가 소스 스캔으로 고정 중 — 유지
- 사용자 노출 문자열 한국어 / 코드·주석 영어 혼용은 기존 파일 관례를 따른다(주석 한국어 유지)
- Flutter `3.41.2` stable `[측정]`

### 2.4 이전 세션에서 이미 밝혀진 사실 (재조사 안 함)

- 요청 ②의 범인은 `_buildDayStage`(:332)가 쓰는 **`CalendarDatePicker` 내장 헤더**다. Material 이 소유하는 위젯이라 **헤더를 숨기거나 탭을 가로챌 공개 API 가 없다** `[1차: CalendarDatePicker 는 `_DatePickerModeToggleButton` 을 항상 렌더하고 토글 대상은 내부 YearPicker 고정]`
- 직전 회차가 넣은 `월 선택으로` 버튼(:327)은 그것과 **별개의 두 번째 어포던스**라, 사용자가 내장 헤더를 먼저 눌렀다 `[측정: 사용자 보고]`

---

## 3. 하네스 Scope Audit 결과 (Step 1.5)

`bash ~/.claude/harness/scripts/pre-change-audit.sh . navigation_state` → **`STRUCTURAL_FIX_REQUIRED`** `[측정]`
- 과거 인시던트 4건: 2026-04-14 예산→카드→월 어긋남 / 2026-04-15 월 이동 후 리셋 / 2026-04-15 카드 요약 stale / 2026-08-10 죽은 화면 위젯
- 게이트 상태: **LOCKED** — 구조적 수정 계획을 이 문서에 포함하고 `acknowledge-gate.sh budget-book <이 파일>` 로 해제해야 편집 가능

### 3.1 구조적 수정 계획 (패치 아님)

이번 결함의 구조적 정체는 **"월 이동 UI 의 일부를 프레임워크가 소유하고 있다"** 이다. 앞 회차는 우리 버튼을 하나 더 붙였을 뿐이라(어포던스 2개) 프레임워크 헤더가 그대로 남아 재발했다.

1. **소유권 통일** — 다이얼로그 안에서 `CalendarDatePicker` 를 **제거**한다. 연·월·일 세 축 전부 우리가 그린다. "우리가 개선한 경로 옆에 프레임워크가 만든 다른 경로가 열려 있는" 상태 자체를 없앤다
2. **단계 제거** — 연도 그리드 단계를 삭제해 `_PickerStage` 를 3개 → 2개(`monthYear`, `day`)로 줄인다. 연도는 같은 화면의 휠이므로 "연↔월 왕복"이라는 상태 전이가 존재하지 않는다(요청 ①)
3. **가드로 고정** — S2 에 다음을 추가한다: *`month_year_picker_dialog.dart` 는 `CalendarDatePicker` 를 포함하지 않는다*(소스 스캔) + 위젯 테스트 *일 그리드에 `CalendarDatePicker` 가 없다*(`findsNothing`). 누군가 편의상 되돌리면 **테스트가 깨진다** — 요청 ②의 재발 경로가 컴파일/CI 층에서 막힌다
4. 기존 S1(자체 월 헤더 금지)·S2(피커 호출부 1곳)·S3(도달성 9곳)는 **약화 없이 유지**한다

---

## 4. 설계

### 4.1 연/월 통합 화면 (`_PickerStage.monthYear`)

```
┌ 연/월 선택 ──────────── ✕ ┐
│  2024 │  1월   2월   3월   │
│  2025 │  4월   5월   6월   │
│ ▸2026◂│  7월  [8월]  9월   │
│  2027 │ 10월  11월  12월   │
│  2028 │                    │
└────────────────────────────┘
```

- 왼쪽 `SizedBox(width: 92, height: 208)` 안에 `ListWheelScrollView.useDelegate`
  - `itemExtent: 44`, `FixedExtentScrollController(initialItem: initialYear - firstYear)`, `physics: FixedExtentScrollPhysics()`
  - `onSelectedItemChanged` → `setState(_year = ...)` → 오른쪽 그리드의 활성/비활성·강조가 즉시 갱신
  - 항목 탭 → `animateToItem`(가운데가 아닌 연도를 눌러도 선택된다 — 휠만으로는 정밀도가 떨어지는 것 보완)
  - 가운데에 선택 밴드(둥근 테두리 44px)를 `Stack` 으로 깔아 "지금 이 값" 을 드러낸다
  - **웹 마우스 드래그 보정**: `ScrollConfiguration` 으로 `dragDevices` 에 mouse/trackpad 포함. Flutter 웹 기본 동작은 마우스 드래그 스크롤을 제외한다 `[1차: MaterialScrollBehavior.dragDevices 는 touch/stylus 만]` → 보정 없으면 PC 에서 휠 회전이 어색해질 수 있다
- 오른쪽은 기존 `_buildGrid(columns: 3)` + `_GridCell` 재사용. 높이 4행 × 52 = 208 로 휠과 정렬
- 월 셀 1탭 = 확정. `allowDaySelection` 이면 일 그리드로, 아니면 즉시 `pop(MonthPickerResult(year, month))`
- 셀 상태: `selected` = 진입 시점의 연·월(현재 보고 있는 달) / `outlined` = 오늘이 속한 연·월 / 범위 밖은 비활성(기존 `_isMonthEnabled` 유지)
- 타이틀 `연/월 선택` (기존 `연도 선택`/`월 선택` 2종을 대체)

### 4.2 자체 일 그리드 (`_PickerStage.day`, 거래 탭 전용)

```
┌ 2026년 8월 ▴ ────────── ✕ ┐   ← 라벨 탭 = 연/월 화면
│  ‹   2026년 8월 ▴   ›      │
│  일  월  화  수  목  금  토 │
│                       1    │
│   2   3   4   5   6  7  8  │
│  ...                       │
└────────────────────────────┘
```

- 헤더는 기존 `_buildStageHeader` 재사용 — `‹ ›` 는 **달 이동**, 가운데 라벨 탭은 **연/월 화면으로 복귀**(요청 ②의 정답)
- 요일 라벨은 **일요일 시작**, 한국어 하드코딩(`일 월 화 수 목 금 토`). `MaterialLocalizations` 의존을 피해 테스트 환경에서도 동일하게 검증된다 `[측정: 현행 테스트가 "로케일 델리게이트가 없어 헤더가 영문" 이라 주석으로 회피 중]`
- 선행 공백 = `DateTime(y, m, 1).weekday % 7` (Dart 의 weekday 는 월=1…일=7)
- 셀: 선택일 = 채움 / 오늘 = 테두리 / `firstDate`~`lastDate` 밖 = 비활성
- **일 1탭 = 확정·닫힘**(기존 `선택` 버튼 제거). 월도 1탭이므로 동작 규칙을 하나로 맞춘다 — 탭 수도 1회 줄어든다
- `CalendarDatePicker` 는 이 파일에서 완전히 사라진다

### 4.3 공개 API (변경 없음)

- `showMonthYearPickerDialog({context, initialYear, initialMonth, firstDate, lastDate, allowDaySelection})`
- `MonthPickerResult{year, month, day?}` — `day == null` 의미 유지

---

## 5. 성능 설계

- 순수 FE·다이얼로그 단일 위젯. 네트워크·BE·DB 변경 0
- 연도 휠은 `useDelegate` + `childCount = lastYear - firstYear + 1`(현행 호출 기준 **11개**)로 지연 생성. 그리드 12칸 + 일 최대 42칸 = 프레임당 위젯 수 100 미만 `[추론: 셀 수 직접 계산]`
- 상태 갱신은 `setState` 로 다이얼로그 서브트리에 한정. 호스트 페이지 rebuild 없음
- 제거되는 비용: `CalendarDatePicker`(내부에 `PageView` + 연도 `GridView` 동반) 1개

---

## 6. 자동 검증 계획 (비용 오름차순 + 편향 제거)

1. **정적** — `flutter analyze --no-fatal-infos --no-congratulate` 전체 경로(부분 경로 금지) 신규 0
2. **가드(소스 스캔)** — `month_navigator_single_source_guard_test.dart`
   - S2 추가: 피커 파일에 `CalendarDatePicker` 문자열이 **없다**
   - S1·S2·S3 기존 항목 전부 유지 통과
3. **위젯 테스트** — `month_year_picker_dialog_test.dart` 재작성 12건
   - 열자마자 연도(휠)와 12개월이 **동시에** 보인다 / `연도 선택` 단계가 존재하지 않는다
   - 월 1탭 → 즉시 닫힘 · `day == null`
   - 연도 휠 **드래그** → 선택 연도 변경 → 그 연도로 월 확정(결과 year 검증)
   - 가운데가 아닌 연도 **항목 탭** → 그 연도로 이동
   - 범위 밖 달 비활성(눌러도 안 닫힘) / 범위가 1년이면 휠 항목 1개
   - `allowDaySelection`: 일 그리드 진입 · 헤더 라벨 탭 → 연/월 화면 · 헤더 `‹ ›` 로 달 이동
   - 일 1탭 → `year/month/day` 반환
   - **회귀 가드**: 일 단계에 `find.byType(CalendarDatePicker)` 가 `findsNothing`
   - **편향 제거 케이스**: ① 2026-08-01 = 토요일이라 선행 공백 6칸(달 시작 요일 오프셋 최악 케이스) ② `firstDate`/`lastDate` 가 달 중간을 자르는 범위에서 경계일 비활성 ③ 좁은 화면(320×640)에서 overflow 0
4. **`flutter test` 전체** — 현행 924건 기준, 순증/순감을 대장에 기록
5. **`./gradlew test`** — BE 무변경 확인용(회귀 없음 입증)
6. **`flutter build web --release`** + **배포 전 번들 문자열 확인**: `연/월 선택`·`이번 달로` 가 산출물에 존재.
   ⚠ dart2js 는 한글을 **소문자 hex** 로 이스케이프한다(`연`). 대문자로 grep 하면 0건 오탐 `[측정: 2026-08-11 실제 겪음]`

---

## 7. 작업 계획

1. `acknowledge-gate.sh budget-book docs/sessions/2026-08-11_1_month-picker-unified_plan.md` 로 하네스 게이트 해제
2. 브랜치 `feat/month-picker-unified` 생성
3. `month_year_picker_dialog.dart` 재작성 — 통합 화면 + 자체 일 그리드 + `CalendarDatePicker` 제거
4. 위젯 테스트 재작성(12건) · 가드 S2 항목 추가
5. 로컬 CI 4종 + 번들 문자열 확인
6. 진행 대장 append → 커밋 → PR → 원격 CI → squash 머지(개인 계정 자동 진행 범위)
7. 배포(deploy-nas) → 라이브 번들 문자열·`last-modified` 확인 → **사용자 라이브 검증 요청**

---

## 8. 배포 절차

- `frontend/` 변경만 → `deploy-nas.yml` 의 changes 필터가 `deploy-frontend` + `verify-live` 만 실행(BE·nginx skipped) `[측정: 직전 회차 run 31455747310 동일 패턴]`
- 배포 후: 라이브 `main.dart.js` 의 `cache-control: no-cache` · `last-modified` 갱신 · 신규 문자열(escaped) 확인

---

## 9. 사용자 검증 시나리오

- **A. 연/월 통합 (요청 ①·③)**
  - A1 분석 탭 상단 `2026년 8월` 탭 → **연도 휠과 12개월이 한 화면**에 보인다. 연도만 따로 나오는 단계가 없다
  - A2 왼쪽 연도를 돌려(또는 탭해) 2025 로 → 오른쪽 그리드가 2025 기준으로 바뀐다 → `3월` 1탭 → 닫히고 화면이 2025년 3월로 이동
  - A3 PC(마우스 휠)와 폰(드래그) 양쪽에서 연도 스크롤이 자연스럽다
- **B. 일 선택 (요청 ②)**
  - B1 거래 탭 상단 날짜 탭 → 일 달력이 나온다. 상단 `2026년 8월` 탭 → **연/월 화면**이 나온다(연도 목록 아님)
  - B2 그 화면에서 `10월` 탭 → 10월 일 달력으로 내려온다 → `15` 1탭 → 닫히고 거래 목록이 10월 15일로 스크롤
  - B3 일 달력 헤더의 `‹ ›` 로 달을 넘길 수 있다
- **C. 회귀**
  - C1 `오늘` 버튼(이번 달로)이 그대로 동작하고, 이번 달에선 비활성
  - C2 거래 폼의 날짜 입력(기존 달력)은 **변화 없음**
  - C3 이체·결제수단·자산관리·주간예산·리포트·지출계획 상단 월 이동 정상

---

## 10. 결정 필요 항목 + 사전 판정 기준

- 없음. 형태(C)와 일 선택 방식(자체 그리드)은 2026-08-11 사용자 선택으로 확정

## 11. 미해결 사항

1. **웹에서 마우스 드래그로 휠이 돌아가는지** — 자동 위젯 테스트는 touch 드래그 경로만 검증한다. `ScrollConfiguration.dragDevices` 보정을 넣지만 실제 브라우저 동작은 **사용자 라이브 검증 A3** 로 확인한다(확인 주체: 사용자 / 수단: PC 브라우저) `[미확인]`
2. **자체 일 그리드의 접근성(스크린리더) 라벨 품질**이 `CalendarDatePicker` 대비 어떤지 — 셀에 `Semantics(label: 'M월 D일')` 을 붙이되, 실제 리더 낭독 비교는 이번 범위 밖 `[미확인]`
3. **연도 범위 2020~2030** 은 호출부 하드코딩 그대로 둔다. 범위를 데이터(최초 거래일)에서 유도하는 안은 별건 `[측정: month_navigator.dart:95]`
