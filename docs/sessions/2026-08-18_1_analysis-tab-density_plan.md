# 분석 탭 UI/UX 개편 + UI 크기 동적 체계 도입 (calynda 이식) — 기획서

- 일자: 2026-08-18
- 회차: 분석 탭 개편 (자산 탭 회차 후속)
- 기반: `main` = `e611d23`, 직전 회차 PR #298
- 근거 등급 표기: `[측정]` 직접 실행/관측 · `[1차]` 공식 소스·코드 · `[추론]` 유도(과정 병기) · `[미확인]`

---

## 1. 요청 내용 (사용자 원문 보존)

2026-08-14 접수:

> 아쉬운 것, 분석도 자산처럼 UI/UX 전체 개편 필요
>
> 특히 상단 예산/통계, 월말 점검, 월간/주간 버튼, 이번달 예산 영역이 너무 크게 노출되어
> 실제 데이터 노출 영역이 엄청나게 적음
>
> 자산에서는 카드의 경우 잔액이 없으므로 마감일, 결제일 정보가 잔액 대신 노출되어
> 2줄로만 노출되게 개선

2026-08-18 추가·수정 접수:

> 분석에서 월말 점검 정보 자체를 없애야할 것 같다.
>
> 그리고 모바일 화면에 비해 아이콘이나 버튼 크기가 너무 커 콘텐츠가 너무 적게 보인다.

**해석 및 범위 확정**

- 요청 A — **월말 점검 제거**. 08-14 의 "너무 크게 노출"이 08-18 에 "정보 자체를 없앤다"로 **격상**됐다.
  축소가 아니라 삭제다.
- 요청 B — **아이콘·버튼 크기 축소**. 08-14 의 4곳 지목(①상단 예산/통계 ②월말 점검
  ③월간/주간 버튼 ④이번달 예산)이 08-18 에 **"크롬 전반"** 으로 일반화됐다. 분석 탭 한정이
  아니다 → 전수 적용 (`feedback_common_scope_audit`).
- 요청 C — **자산 탭 카드 2줄화**. 08-14 요청 2, 변경 없음. 이번 회차에 함께 처리.

---

## 2. 진단 — 무엇이 문제인가

### 2.1 세로 공간 장부 (분석 > 통계, 360×780 논리 픽셀 기준)

Flutter SDK 상수 `[1차]` (로컬 SDK `/opt/homebrew/share/flutter` 직접 확인):

- `kToolbarHeight = 56.0` — `packages/flutter/lib/src/material/constants.dart:30`
- `_kTabHeight = 46.0` / `_kTextAndIconTabHeight = 72.0` — `material/tabs.dart:30-31`
- `NavigationBar` 기본 `height: 80.0` — `material/navigation_bar.dart:1383,1430`

현재 스택 (위→아래):

1. 상태바/세이프에어리어 — 24 `[추론]` (기기별. Android 표준값 가정)
2. `AppBar(title: '분석')` — 56 `[1차]`
3. TabBar `[예산][통계]`, `Tab(icon:+text:)` — 72 `[1차]` (`analysis_page.dart:33-38`)
4. `MonthNavigator` — 56 `[추론]` (`IconButton` 기본 48 + `EdgeInsets.symmetric(vertical: 4)` ×2 — `month_navigator.dart:69,76`)
5. 월말 점검 카드 — 약 138 `[추론]` (`Card` 기본 margin 4×2 + `Padding(all:16)` ×2 + 제목행 36 + 4 + `titleLarge` 28 + 6 + `bodyMedium` 20 + 바깥 `Padding` 하단 4 — `reconciliation_summary_card.dart:43-109`, `analysis_page.dart:91-98`)
6. 통계 내부 TabBar `Tab(icon:+text:)` ×4 — 72 `[1차]` (`statistics_page.dart:34-38,58`)
7. 필터 행 (`SegmentedButton` + 기간 `IconButton`) — 48 `[추론]` (`statistics_page.dart:76-79`)
8. `NavigationBar` — 80 `[1차]`

**크롬 합계 546dp. 콘텐츠에 남는 것은 780 − 546 = 234dp — 화면의 30.0%** `[추론: 위 8항 합산]`

분석 > 예산 sub-tab 도 같은 구조다: 6·7 대신 월간/주간 `SegmentedButton` 행 56
(`budget_list_page.dart:114-133`) + `BudgetSummaryCard` 약 130
(`budget_summary_card.dart:17,19` margin 8×2 + padding 16×2 + 본문) → 크롬 572, **콘텐츠 208dp = 26.7%** `[추론]`

사용자 표현 "실제 데이터 노출 영역이 엄청나게 적음" 은 정확하다. **화면의 70%가 크롬이다.**

### 2.2 근본 원인 — 자산 탭 회차와 같다

크롬 치수가 **각 화면에 흩어진 리터럴**이라서 아무도 총합을 보지 못한다. 개별 값은 전부
Material 기본값이라 "정상"이고, 리뷰에서 한 화면씩 보면 어디에도 잘못이 없다. 문제는
**중첩**이다 — 분석 탭은 icon+text TabBar 를 2단으로 쌓아 그것만 144dp 다.

자산 탭 회차에서 같은 병을 `BbDensity`(폭 읽기 단일 지점) + `EntityTileRow`(타일 계약 봉인)
+ 가드 8종으로 고쳤다. **크롬에는 그 계약이 아직 없다.** `BbDensity` 는 타일 전용
(`tilePaddingH`, `avatarSize`, `actionIconSize` …)이고 크롬 치수 토큰이 없다
`[측정: bb_density.dart 전문 확인, 크롬 관련 필드 0개]`.

### 2.3 아이콘·버튼 전수 실측 `[측정]`

- `Tab(icon: …, text: …)` — **9곳 / 3파일**. `statistics_page`(4), `transaction_form_page`(3),
  `analysis_page`(2). 각 72dp, text-only 대비 **+26dp**
- `IconButton(` — **70곳**. 기본 탭 타깃 48dp / 아이콘 24dp
- `iconSize:` 또는 `visualDensity:` 를 명시한 곳 — **20곳**. 즉 **50곳이 기본값 방치**
- `Icon(size: N)` 분포 — 20(66), 18(64), 16(47), 14(27), 24(5)… 타일 쪽은 이미 촘촘한데
  크롬 쪽만 기본값 24/48 로 크다

### 2.4 월말 점검 제거 — 도달성 사전 확인 `[측정]`

`feedback_screen_reachability_check` 에 따라 **삭제 전에** 정산 기능이 고아가 되는지 측정했다.

- `ReconciliationSummaryCard` 호스팅은 `analysis_page.dart:93` **단 한 곳**
- 이 카드의 역할은 `ledgerLocation(view: LedgerView.reconciliation)` 로의 이동
  (`reconciliation_summary_card.dart:30-36`)
- **독립 도달 경로 존재 확인**: 거래 탭 뷰 토글 `SegmentedButton` 의 3번째 세그먼트
  (`transaction_list_page.dart:1438-1440`, `Icons.fact_check`, tooltip `'정산 보기 — 미기록 항목 확인/기록'`)
- 따라서 **카드를 지워도 정산 기능은 살아 있다.** 삭제 가능 ✅

잃는 것은 기능이 아니라 **수동적 알림**("이 달 미기록 N건")이다. 사용자가 명시적으로
없애라고 했으므로 수용하고, 대체 경로는 대기열 #6(월말 미기록 인앱 알림)으로 넘긴다 → §8.

### 2.5 ★근본 진단 정정 — "웹 그대로"가 문자 그대로 맞다 `[측정]`

2026-08-18 사용자 지적("모바일 화면에서 글씨나 버튼 크기 등이 웹 그대로")을 코드로 확인했다.

- **`core/theme/app_theme.dart` 에 타이포·밀도·아이콘 설정이 없다** `[측정]` —
  `TextTheme` · `visualDensity` · `IconTheme` · `IconButtonTheme` · `TabBarTheme` ·
  `NavigationBarTheme` · `SegmentedButtonTheme` **전부 부재**.
  ⚠ **정정(구현 중 확인)**: 최초 진단에서 "컴포넌트 테마가 전부 없다"고 적었으나
  `appBarTheme` · `inputDecorationTheme` · `cardTheme` 3종은 있었다. 없는 것은
  **크기·밀도를 정하는 테마**이고, 결론(폭에 대한 반응 0)은 그대로다
- 즉 앱 전체가 **Material 기본 타이포 한 벌로 320px 폰부터 2560px 웹까지 똑같이 그린다.**
  폭에 대한 반응이 **0** 이다
- 크기 리터럴 **1,458건** `[측정]`: `fontSize` 115 · `EdgeInsets` 446 ·
  `SizedBox(width/height)` 747 · `circular()` 150. dart 파일 416개
- 반응하는 유일한 체계인 `BbDensity` 는 **타일 전용**이고 3단 계단
  (compact/regular/wide)이다. 크롬·본문·폼은 그 밖에 있다

**§2.2 의 진단("치수가 흩어진 리터럴")은 맞았지만 범위를 과소평가했다.**
분석 탭 크롬만의 문제가 아니라 **앱 전체에 크기 체계가 없다.**

### 2.6 calynda 선례 — 같은 병을 이미 고쳤다 `[1차: 코드·문서 직접 확인]`

사용자 지시로 `calynda/fe` 를 측정했다. 같은 문제를 2026-08-14~17 에 진단·구현했고
**이미 배포 게이트까지 배선돼 돌아간다.**

- 정본 규칙 `calynda/docs/sessions/2026-08-14_1_ui_scaling_rules.md` (4층 모델)
- 구현 `calynda/fe/lib/ui/shared/themes/ui_scale.dart` (301줄)
- 게이트 `calynda/fe/tool/check_ui_scaling.py` + `ui_scaling_baseline.json`
- 스윕 `calynda/fe/test/ui/responsive_sweep_test.dart` (31건)
- 결과: 리터럴 509 → 405, PR fe#197, 배포 게이트 1-B 첫 실전 통과

**★내 원안(`BbChrome` 토큰 7종)은 calynda 가 이미 실측으로 틀렸다고 판정한 모양이었다:**

1. **3단 계단은 반응이 아니다.** calynda 실측: `sqrt(W/1440).clamp(0.9,1.8)` 이
   **320~1024px 전 구간 0.900 붙박이** — 폭 3.2배에 반응 0 `[측정: calynda]`.
   비율에 하한을 걸면 **닿는 순간 전 축이 통째로 굳는다.**
   처방은 **clamp 를 비율이 아니라 가독 기준 px 에 거는 것**
2. **화면 폭 판정은 틀린다.** calynda 실측: **최악이 모바일이 아니라 900px** 였다 —
   패널이 352px 인데 `isMobile` 이 화면 폭 기준이라 데스크톱 폰트를 써서 22.49자,
   390px(27.81자)보다 좁았다 `[측정: calynda]`.
   **`BbDensity.of(context)` 가 정확히 이 안티패턴이다**(`bb_density.dart:131-133`,
   `MediaQuery.sizeOf(context).width`)
3. **여백이 폰트를 안 따라가면 이름만 바뀐다.** 기준 폰트가 고정된 자리에서 여백을
   `0.5em` 으로 바꾸면 `6px` 고정과 완전히 같다

→ **원안을 폐기하고 calynda 체계를 이식한다.** 이것이 사용자 지시
("calynda 에서 진행했던 것을 기반으로 budget book 에도 적용")의 직역이다.

---

## 3. 하네스 Scope Audit 결과 (Step 1.5)

`bash ~/.claude/harness/scripts/pre-change-audit.sh . "ui_pattern,navigation_state"` 실행 `[측정]`

**OVERALL VERDICT: 🚫 STRUCTURAL_FIX_REQUIRED** — `ui_pattern` 5건, `navigation_state` 5건.
패치 수정 불허. 컴파일 타임 또는 아키텍처 수준 강제 필수.

이번 회차에 직접 걸리는 과거 인시던트 3건:

- `[2026-08-10]` 홈 대시보드 월말 점검 위젯이 **죽은 화면에 얹혀 라이브에 없었다.**
  → 방지책 ④ 가 "카드가 살아있는 화면(분석 탭)에 호스팅되는지 가드 고정" 이었다.
  **이번에 그 카드를 지우므로 그 가드를 반전시켜야 한다** (§4 S4). 무심코 지우면 CI 가 깨진다.
- `[2026-08-11]` 프레임워크 위젯이 자체 어포던스를 가지면 "경로 추가"는 재발 →
  **완료 기준은 경쟁 경로 0개.** 이번 건에서는 `Tab`/`NavigationBar`/`SegmentedButton` 이
  프레임워크 소유 치수를 갖는다 → 리터럴로 덮지 말고 **테마 레벨에서 한 번에** 눌러야 한다 (§4 S1).
- `[2026-07-27]` 액션을 덮어써 기본 어포던스가 사라짐 → 크롬을 줄일 때 **탭 타깃 40dp 하한**을
  깨면 안 된다. 기존 가드 S4(`actionSlotSize` ≥ 40)를 크롬에도 확장한다.

⚠ Known pitfall 직격: **"모바일 화면에서 공간 부족 고려 누락"** — 이번 요청 그 자체다.

게이트 해제: 이 기획서 경로로
`bash ~/.claude/harness/scripts/acknowledge-gate.sh frontend docs/sessions/2026-08-18_1_analysis-tab-density_plan.md`

---

## 4. 구조적 수정 계획 (패치 아님) — calynda 체계 이식

> 전 앱 공통 규칙은 **`~/.claude/domains/12-ui-scaling.md`** 로 승격했다(2026-08-18 신설).
> 사용자 지시: "앞으로 앱 작업, budget book은 물론 calynda나 다른 추가 앱 작업에는
> 이게 항상 기본이어야 한다." 라우팅 표·분류 훅에도 배선 완료.

### S1 — `BbType` / `BbSpace` 토큰 (`CalType`/`CalSpace` 이식)

`core/theme/bb_scale.dart` 신설. 계산식은 calynda 와 **동일**하게 간다 —
같은 곡선을 두 앱이 공유해야 "다른 앱에도 기본" 이 성립한다.

```
size(role, W) = clamp( min_px, ref × (W / 1440)^0.25, max_px )
space(token)  = base[token] × sqrt( textScaler.scale(body(W)) / refBody )
```

- **폰트 역할 6종** `display / title / section / body / label / caption`
- **아이콘 역할 3종** `sm / md / lg` — 별도 사다리(글자와 나란히 놓이므로 고정 px 면
  혼자 안 움직여 어긋난다)
- `ref/min/max` 기준값은 **budget-book 자체 리터럴 분포 실측**에서 뽑는다.
  calynda 값을 그대로 베끼지 않는다 — 앱마다 현행 분포가 다르다
- **`of(context)`(화면 폭)와 `forWidth(w)`(컨테이너 폭) 둘 다 제공**하고,
  분할 뷰·그리드 셀·패널은 반드시 후자를 쓴다 (§2.6-2 처방)
- `style(role)` 이 `TextStyle` 을 돌려준다 → **호출부가 `fontSize:` 를 적을 이유를 없앤다**
- `EdgeInsets` 직접 생성 경로를 노출하지 않는다

### S2 — `app_theme.dart` 에 배선 (지금은 빈 껍데기다)

`TextTheme` · `IconThemeData` · `IconButtonTheme` · `TabBarTheme` ·
`NavigationBarTheme` · `SegmentedButtonTheme` 를 `BbType`/`BbSpace` 로 구성한다.
**화면이 아무것도 안 해도 줄어든다.**

이것이 §3 `[2026-08-11]` 교훈의 적용 — 프레임워크가 치수를 소유하면 덧칠하지 말고
소유 지점(테마)에서 바꾼다. 경쟁 경로 0개.

### S3 — `BbDensity` 를 흡수·정리 (경쟁 경로 0개)

**토큰을 추가만 하면 축이 3개에서 4개로 늘 뿐이다.** `BbDensity` 의 타일 치수를
`BbType`/`BbSpace` 위에서 재정의하고, **`MediaQuery` 직접 조회는 `BbType` 한 곳으로
단일화**한다. `BbDensity.of(context)` 는 `forWidth` 경유로 바꾼다.

기존 가드 8종(타일 API 봉인·`ListTile` 금지·`MediaQuery` 금지 등)은 **유지**한다 —
`MediaQuery` 금지 가드는 오히려 강화된다.

### S4 — 리터럴 ratchet 게이트 (`check_ui_scaling.py` 이식)

`frontend/tool/check_ui_scaling.py` + `ui_scaling_baseline.json`.

- 영역별 리터럴 수가 baseline 보다 **늘면 exit 1**. 줄면 통과 + 갱신 안내
- **시범 범위 잔존 0** 을 따로 강제 — ratchet 만 있으면 "다른 데서 줄이고 여기서 늘리기"가
  통과한다
- L4 허용 목록 `0 / 1 / 0.5 / 44` 만. 불가피하면 `// ui-fixed: <이유>` 주석 →
  제외하되 **건수는 리포트**(숨지 못하게)
- **착수 baseline = 1,458건** `[측정]`. 이번 회차 목표는 시범 범위 0 + 총계 감소
- ⚠ 스캔은 줄 단위라 여러 줄로 쪼개진 `EdgeInsets` 는 못 센다 →
  **기준선 갱신은 `dart format` 뒤에** (calynda 에서 407↔404 로 흔들린 실측)

### S5 — 반응형 스윕 테스트

`frontend/test/core/theme/responsive_sweep_test.dart`.
폭 {320, 360, 390, 768, 1024, 1440, 2560} × 텍스트배율 {1.0, 1.3, 1.6}.

단정:
- 오버플로 예외 **0**
- 본문 폰트 ≥ 가독 하한 · 터치 타깃 ≥ 44
- **배율↑ 시 텍스트 폭이 줄지 않는다** (calynda 가 실측한 역행 결함 금지)
- **역할마다 하한 도달 폭이 다르다** (한 지점에서 전 축이 굳지 않는다)
- 크롬 예산: 콘텐츠 뷰포트 ≥ 55%

**§3 하네스가 요구한 "아키텍처 수준 강제"는 S4+S5 다.** 색 래칫(baseline 313건)이
이미 같은 기전으로 돌고 있어 검증된 패턴이다.

### S6 — 도달성 가드 이관 (월말 점검 삭제분)

`dashboard_widget_registry_guard_test.dart:67` 의
`expect(analysis.contains('ReconciliationSummaryCard'), isTrue)` → **`isFalse` 로 반전**하고,
**정산 도달성 가드를 거래 탭 세그먼트로 이관**한다
(`transaction_list_page.dart` 에 `LedgerView.reconciliation` 세그먼트 존재).
기능의 도달성은 계속 지켜지되 호스팅 위치만 옮긴다.

## 5. 작업 계획

> **범위 결정**: calynda 가 검증한 스코프(**토큰 + 게이트 + 시범 1영역**)를 그대로 따른다.
> 시범 영역 = **분석 탭**(사용자 요청 영역과 일치). 1,458건 전수 이관은 이 회차가 아니다 —
> ratchet 이 회차마다 낮춘다.

### 1단계 — 기반 (S1·S2·S3)

1. `core/theme/bb_scale.dart` 신설 — `BbType`(폰트 6역할 + 아이콘 3역할) · `BbSpace`
   (`xs~xxl`) · 브레이크포인트 단일 소스. `of(context)` / `forWidth(w)` 둘 다
2. **`ref/min/max` 기준값 결정** — 현행 리터럴 분포를 먼저 집계해서 뽑는다
   (`fontSize` 115건의 값 분포). 추측 금지
3. `core/theme/app_theme.dart` 배선 — `TextTheme` · `IconThemeData` ·
   `IconButtonTheme` · `TabBarTheme` · `NavigationBarTheme` · `SegmentedButtonTheme`.
   **지금 60줄짜리 빈 껍데기가 실제 크기 체계가 되는 지점**
4. `bb_density.dart` — 타일 치수를 `BbType`/`BbSpace` 위에서 재정의,
   `MediaQuery` 조회를 `BbType` 으로 단일화 (경쟁 경로 0개)

### 2단계 — 게이트 (S4·S5)

5. `frontend/tool/check_ui_scaling.py` + `ui_scaling_baseline.json` 이식.
   착수 baseline **1,458건**
6. CI·배포 게이트에 배선
7. `test/core/theme/responsive_sweep_test.dart` — 폭 7 × 배율 3

### 3단계 — 요청 A: 월말 점검 제거

8. `analysis_page.dart` — `_ReconciliationSummarySection` + 호출부(45-51행) + import 2개 삭제
9. `reconciliation_summary_card.dart` 삭제
10. `reconciliation_summary_cubit.dart` 삭제
11. `core/di/injection.dart:383-386` 등록 삭제
12. `core/bloc/month_sync_handler.dart:66-68` 재조회 삭제
13. `test/features/reconciliation/reconciliation_summary_card_test.dart` 삭제
14. `dashboard_widget_registry_guard_test.dart` — `isTrue` → `isFalse` + 도달성 가드 이관 (S6)
15. **유지**: `data`/`domain` 의 `getReconciliationSummary` + `/api/v1/reconciliations/summary`.
    BE 계약 불변 — 대기열 #6(인앱 알림)이 재사용할 자산이다.
    FE 미사용 상태를 §8 과 PROGRESS 산출물 지도에 명시
16. BE·DB·`api-spec.md` 변경 **0건**

### 4단계 — 요청 B: 분석 탭 시범 이관 (리터럴 잔존 0)

17. `analysis_page.dart` — `toolbarHeight: 0`. AppBar 타이틀 '분석' 은 하단 네비 라벨과
    중복이다(`main_shell_page.dart:214` 확인). **−56dp**
18. `Tab(icon:+text:)` 9곳 → `Tab(height: <토큰>, child: Row(...))` **가로 배치**.
    아이콘을 잃지 않고 72→46. 분석 탭은 2단 중첩이라 **−52dp**, 거래 폼 −26dp

    **`[1차]` 근거 (SDK `material/tabs.dart` 직접 확인)**: `Tab.build` 는 `icon == null` 이면
    `calculatedHeight = _kTabHeight`(46)를 쓴다(198-199행). 아이콘을 `Tab.icon` 이 아니라
    `Tab.child` 안의 `Row` 로 넣으면 **아이콘을 유지한 채 46dp** 가 된다. 나아가 `Tab` 은
    `height` 파라미터를 이미 갖고 있고 `preferredSize` 가 그것을 그대로 반환한다
    (221·234-235행) → **토큰 주입이 프레임워크 지원 경로다.** 리터럴 덮어쓰기가 아니다
19. `month_navigator.dart` — 여백·아이콘·슬롯을 토큰으로. 56→44 **−12dp**
20. `statistics_page.dart` 필터 행 + `budget_list_page.dart` 월간/주간 행 — 토큰화. **−8~16dp**
21. `main_shell_page.dart` — `NavigationBar(height: <토큰>)`. 80→64 **−16dp**
    ⚠ 오버플로 위험 — §8-6. 실측 후 확정
22. **위 5개 파일 + `budget_summary_card.dart` 는 리터럴 잔존 0** (S4 시범 범위 강제)

### 5단계 — 요청 C: 자산 탭 카드 2줄화

23. `asset_management_page.dart` `_buildPaymentMethodTile` — 마감일·결제일 문자열을
    `subtitle` → `trailingMetric` 으로 이동. 3줄 → 2줄. `EntityTileRow` 계약 안에서
    해결되며 새 API 는 필요 없다 (`reference_asset_tab_tile_contract`)

### 절감 예상

138(카드) + 56(AppBar) + 52(TabBar 2단) + 12(MonthNav) + 16(필터) + 16(하단바)
= **290dp** `[추론: 항목 합산]` → 콘텐츠 234 → **524dp = 67.2%**. 30% → 67%, **2.24배**

여기에 **타이포·여백이 폭에 반응하기 시작하는 효과가 더해진다** — 이건 dp 로 미리
계산하지 않는다(§8-7).

## 6. 성능 설계

- 렌더 비용: 순감소. 위젯 3개(`Card`+`InkWell`+`BlocBuilder`) 제거, TabBar 세로→가로 배치는
  동일 비용
- 네트워크: **월 이동마다 `/reconciliations/summary` 1회 호출이 사라진다**
  (`month_sync_handler.dart:66-68`). 월 이동은 사용자가 가장 자주 하는 동작 → 실질 개선
- BLoC: `ReconciliationSummaryCubit` singleton 1개 해제. `SyncEventHandler` 의
  `_refreshReconciliations`(`sync_event_handler.dart:124-132`)는 `ReconciliationBloc` 대상이라
  **영향 없음** `[측정: 두 BLoC 은 별개]`
- `BbDensity.of` 는 `MediaQuery.sizeOf` 1회 — 기존과 동일, 추가 비용 없음

---

## 7. 검증 계획 (비용 오름차순 + 편향 제거)

**L1 정적** — `flutter analyze --no-fatal-infos --no-congratulate` 전체 경로, 신규 0건
(`feedback_full_flutter_analyze`: 부분 경로 금지)

**L2 단위·위젯** — `flutter test` 전체. 현재 **1036건** 기준. 신규/변경:
- 크롬 예산 가드 (S3): 320/360/412 × 780, 4개 탭 = 12조합
- 도달성 가드 반전 (S4)
- 삭제된 카드 테스트 제거분 반영

**편향 제거 조건 (최상 조건만 재지 않는다)**:
- **320dp** 최악 폭을 반드시 포함 (360 만 재면 낙관 편향)
- **텍스트 배율 1.3×** 조합 1건 — 글꼴 확대 시 크롬이 다시 부풀지 확인
- **가로 모드(780×360)** 1건 — 세로 예산이 가로에서 역전되지 않는지
- 빈 상태(데이터 0건)와 만재 상태 각 1건 — 콘텐츠가 없을 때 크롬 비율이 왜곡되지 않는지

**L3 빌드** — `./gradlew test` (BE 무변경 회귀 확인) + `flutter build web --release`

**L4 배포 후 자동** — `infra/scripts/verify-cache-headers.sh` (아이콘 폰트 해시 게이트 포함)

**L5 사용자 라이브 검증** — §9. **색·여백은 서버로 판정 불가**
(`reference_live_bundle_string_verification`: 한글은 번들에서 `\uXXXX` 이스케이프,
대조군도 0건 = 프로브 무효). 사용자 눈만이 판정한다.

---

## 8. 미해결 사항 (확인 주체/수단 병기)

1. **월말 점검 삭제로 잃는 수동적 알림의 대체** — 지금은 사용자가 거래 탭 정산 뷰에
   **직접 들어가야만** 미기록 건수를 안다. 대체는 대기열 #6(인앱 알림, 알림 인프라 선행 필요).
   *확인 주체*: 사용자. *수단*: 한 달 운용 후 "미기록을 놓쳤는가" 자체 보고.
   *사전 판정 기준*: 한 달 내 미기록 누락이 실제로 발생하면 #6 을 대기열 상단으로 올린다.
   발생하지 않으면 현행 유지.
2. **크롬 예산 임계값 55%** — S3 가드의 통과선. 이번 설계 예상치는 67% 라 여유가 있지만,
   55% 가 "충분히 촘촘한가"는 사용자 눈으로만 정해진다.
   *확인 주체*: 사용자. *수단*: §9 시나리오 A.
   *사전 판정 기준*: A 에서 "아직 크다"가 나오면 임계를 65% 로 올리고 `navBarHeight`·
   `appBarHeight` 를 한 단계 더 내린다. "너무 빽빽하다"가 나오면 50% 로 내린다.
3. **차트 색 미이관** — 시리즈 팔레트가 파일마다 복제돼 있고 **차트는 수입을 초록, 장부는
   수입을 파랑**으로 그린다. 분석 탭을 건드리면 눈에 띈다.
   *판정*: **이번 범위에서 제외.** 색 문제이지 밀도 문제가 아니고, 한 회차에 섞으면 라이브
   검증에서 원인 분리가 안 된다. 대기열 #1 로 유지.
4. **텍스트 배율 1.3× 에서의 실제 값** — L2 에서 측정 전까지 `[미확인]`. 크롬 토큰이
   고정 dp 라 배율 상승 시 콘텐츠가 잘릴 수 있다.
   *확인 주체*: 나. *수단*: L2 편향 제거 케이스. 깨지면 토큰을 `textScaler` 연동으로 전환.
5. **상태바 24dp 가정** — §2.1 항목 1 은 `[추론]`. 실기기 값이 다르면 절대치는 바뀌지만
   **절감량 290dp 와 비율 개선 방향은 불변**이다(크롬에서 빼는 값이라 상수항).
6. **`NavigationBar` 64dp 의 오버플로 위험** — 총괄 검토에서 걸린 항목. SDK 는 높이를
   `SizedBox(height: effectiveHeight)` **하드 박스**로 강제한다(`navigation_bar.dart:296-297`
   `[1차]`). 내부는 인디케이터 32(`_kIndicatorHeight`, 29행) + 라벨이므로 64 는 여유가 32dp 뿐이다.
   프레임워크가 라벨 배율을 `_kMaxLabelTextScaleFactor` 로 clamp 하지만(506-511행) 여전히
   `RenderFlex overflow` 가 날 수 있다. 현재 `[미확인]`.
   *확인 주체*: 나. *수단*: L2 위젯 테스트에서 4개 탭 × 텍스트 배율 1.0/1.3 을 pump 하고
   오버플로 예외 부재를 단언.
   *사전 판정 기준*: **오버플로가 나면 compact 를 72dp 로 올린다** — 그 경우 절감이
   16→8dp 로 줄어 총합 290→282dp, 콘텐츠 비율 67.2%→66.2%. **결론은 바뀌지 않으므로
   이 항목 때문에 회차를 멈추지 않는다.**

---

7. **★승인된 spec 의 귀결 — 미리 보고한다** (calynda 에서 실제로 문제가 된 지점).
   `body/label/caption` 은 `min == ref` 로 두므로 **1440px 아래에서 상수**다.
   calynda 실측 결과 역할별 해제 폭이 `display 645 · section 1071 · title 1112 · 나머지 1440`
   이었고 → **320~640px 구간은 타이포가 완전 상수**였다 `[측정: calynda]`.
   즉 **"모바일에서 글자가 작아지는" 변화는 이 회차에 안 생긴다.** 모바일 개선은
   **여백·아이콘·크롬 축소**에서 온다(글자는 가독성 때문에 일부러 안 줄인다 — §12-ui-scaling ★5).
   *확인 주체*: 사용자. *수단*: §9 시나리오 A·B.
   *사전 판정 기준*: **"글자가 여전히 크다"** 가 나오면 레버는 `kBbTextSpec.min` 하향 하나뿐.
   **"글자가 작아 읽기 힘들다"** 면 현행 유지. 둘 다 상수 1곳 수정으로 끝난다.
8. **budget-book 기준값(`ref/min/max`)이 아직 미정** `[미확인]`. calynda 값을 베끼지 않고
   자체 리터럴 분포에서 뽑기로 했다(§5-2).
   *확인 주체*: 나. *수단*: 구현 1단계에서 `fontSize` 115건 값 분포 집계.
   *사전 판정 기준*: 분포 최빈값을 `body.ref` 로 잡고, `min` 은 그보다 낮추지 않는다.
9. **1,458건 중 이번 회차 이관은 분석 탭 시범 범위뿐**이다. 나머지는 ratchet 이 회차마다
   낮춘다. **이건 한계가 아니라 calynda 가 검증한 스코프 결정**이다(509→405 로 한 회차 −104).
   *사전 판정 기준*: 총계가 늘면 게이트가 exit 1 로 막는다.

## 9. 사용자 검증 시나리오

**0단계 (필수 선행)** — 오프라인 배너가 없는지 먼저 확인한다.
있으면 재연결 후 시작 (`feedback_live_verification_online_precheck`: 오프라인이면 수정 전
수치가 그대로 보여 "배포 미반영"과 구분 불가).

**A — 분석 탭 밀도 (핵심)**
1. 하단 [분석] → [통계] sub-tab. **월말 점검 카드가 보이지 않을 것**
2. 화면 위→아래로 크롬(제목·탭·월이동·필터·하단바)과 데이터의 비율을 눈으로 판정
3. [예산] sub-tab 으로 전환. 월간/주간 버튼과 이번달 예산 카드가 이전보다 낮을 것
4. 판정: 데이터가 화면 절반 이상을 차지하는가?

**B — 아이콘·버튼 (전수 확인)**
1. 거래 탭 / 자산 탭 / 더보기 탭 순회 — 하단 네비가 낮아졌는지
2. 거래 추가 폼의 [지출][수입][이체] 탭이 아이콘을 유지한 채 낮아졌는지
3. 월 이동 화살표·오늘 버튼이 **여전히 누르기 쉬운지** (40dp 하한 체감 확인)

**C — 자산 탭 카드 2줄**
1. [자산] → 신용카드 항목. `이름` / `마감일·결제일`+칩 **2줄**로 끝나는지
2. 계좌(잔액 있음) 항목은 이전과 동일한지

**D — 회귀 (기능 손실 없음)**
1. 거래 탭 뷰 토글 3번째 세그먼트(체크 아이콘)로 **정산 뷰 진입 가능**한지 — 월말 점검
   카드를 지운 뒤에도 정산 기능이 살아 있는지 확인하는 항목이다
2. 분석 탭에서 월 이동 → 예산·통계 두 sub-tab 이 같은 달을 보는지
3. 통계 4개 sub-tab 과 기간 필터가 정상 동작하는지

---

## 10. 배포 절차

1. 브랜치 `feat/analysis-tab-density`
2. 로컬 CI 4종 전부 통과 후에만 PR (§1.8 — analyze 만 돌리고 통과 간주 금지)
3. `gh pr create` → CI 통과 → `gh pr merge --squash --delete-branch`
   (개인 계정 사전 승인: `feedback_personal_account_auto_merge`)
4. GitHub Actions `deploy-nas.yml` → NAS 배포
5. `infra/scripts/verify-cache-headers.sh` 로 캐시 헤더 + 아이콘 폰트 해시 검증
6. 사용자 라이브 검증 요청 (§9). **머지는 완료가 아니다** (§1.3)

⚠ CI Flutter 가 로컬(3.41.2)보다 최신이다. 로컬 통과 ≠ CI 통과.
실패 시 `gh run view <id> --log-failed` 부터 본다 (`feedback_flutter_sdk_skew_analyze`).

---

## 11. 요약

- **표면 증상**: 분석 탭 크롬이 화면의 **70%** `[추론: SDK 상수 1차 + 구성요소 합산]`
- **진짜 원인**: `app_theme.dart` 가 **60줄·`useMaterial3` 하나뿐** — 앱 전체에
  **크기 체계가 없다.** Material 기본 타이포 한 벌로 320px 폰부터 2560px 웹까지 똑같이
  그린다. 사용자 표현 "웹 그대로"가 문자 그대로 맞다 `[측정]`
- **처방**: 내 원안(`BbChrome` 3단 계단)을 **폐기**하고 **calynda 체계를 이식**한다.
  calynda 가 실측으로 증명한 것 — ①비율 clamp 는 하한에 닿는 순간 전 축이 굳는다
  (320~1024px 반응 0) ②화면 폭 판정은 틀린다(최악이 모바일이 아니라 900px)
  ③여백이 폰트를 안 따라가면 이름만 바뀐다
- **구조적 수정 6종**: `BbType`/`BbSpace` 토큰(S1) · `app_theme` 배선(S2) ·
  `BbDensity` 흡수로 경쟁 경로 0개(S3) · **리터럴 ratchet**(S4, baseline 1,458) ·
  **반응형 스윕**(S5, 폭 7 × 배율 3) · 도달성 가드 이관(S6)
- **월말 점검은 삭제 가능** — 정산 기능은 거래 탭 세그먼트로 독립 도달 `[측정]`
- **예상**: 콘텐츠 영역 30% → 67%. BE·DB·api-spec 변경 **0건**
- **전 앱 승격 완료**: `~/.claude/domains/12-ui-scaling.md` 신설 + INDEX·CLAUDE.md
  라우팅 + 분류 훅 키워드 등록. 앞으로 모든 앱 UI 작업의 기본값이다

---

## 12. 구현 결과 · 정정 (2026-08-18, 코드 완료 시점)

### 12.1 ★대조군 실험으로 진단 확정 `[측정]`

같은 크롬 구성(AppBar + TabBar ×2단 + NavigationBar)을 **이관 전(legacy) / 후(token)**
두 벌로 렌더해 콘텐츠 높이를 쟀다(780dp 화면).

```
              320px    360px    390px    768px    960px
전(legacy)   496dp    496dp    496dp    496dp    496dp   ← 전 구간 동일
             63.6%    63.6%    63.6%    63.6%    63.6%
후(token)    620dp    620dp    620dp    600dp    600dp
             79.5%    79.5%    79.5%    76.9%    76.9%
```

**legacy 가 320px 과 960px 에서 완전히 같다** — "폭에 대한 반응 0" 이 추론이 아니라
대조군으로 확정됐다. 크롬 **284dp → 160dp (−124dp, −43.7%)**,
콘텐츠 **63.6% → 79.5%**.

토큰 실측값(모바일 360px): `body 14.0`(유지) · `title 18.0`(22 → −18%) ·
`iconMd 19.0`(24 → −21%) · `navBar 66`(80 → −18%).
960px 에서는 `title 19.9` · `iconMd 21.7` 로 **연속 변화**한다(계단 아님).

### 12.2 기획 대비 정정 4건

1. **§2.1 의 546dp 는 크롬 '프레임' 이 아니라 페이지 전체 추정치였다.**
   프레임만(AppBar 56 + TabBar 72×2 + NavBar 80 = 280)은 **실측 284dp** 로
   SDK 상수 산술이 **1.4% 오차**로 맞았다. 546 은 여기에 월말 점검 카드·
   MonthNavigator·필터 행·상태바를 더한 값이라 측정 하네스와 범위가 다르다.
   **두 수치는 모순이 아니라 범위가 다르다.**
2. **ratchet baseline 은 1,458 이 아니라 1,699 다.** 기획 시 내 grep 과 이식한
   `check_ui_scaling.py` 의 패턴 집합이 다르다(도구는 일반 `size:` 도 센다).
   ratchet 으로 쓰는 데는 무관하지만 숫자를 정정해 둔다.
3. **§8-6 `NavigationBar` 오버플로 위험 — 해소.** 66dp 로 폭 7종 × 배율 3종
   21조합 전부 오버플로 예외 0. 72dp 폴백은 불필요했다.
4. **가드 임계 55% → 70% 로 상향.** 실측이 79.5% 라 55% 는 래칫으로서 헐겁다.

### 12.3 산출물

- `lib/core/theme/bb_scale.dart` (신설) — `BbType`(폰트 6역할 + 아이콘 3역할 +
  크롬 높이) · `BbSpace`(xs~xxl) · `BbScaleScope`(유효 콘텐츠 폭 단일 소스)
- `lib/core/theme/app_theme.dart` — `responsive(base, width)`: Material 15슬롯
  `TextTheme` + `visualDensity` + 아이콘·앱바·탭바·네비·세그먼트·칩·타일 테마.
  **`textTheme.*` 450 호출부가 코드 변경 0으로 반응형이 됐다**
- `lib/app.dart` — `LayoutBuilder` 에서 **유효 콘텐츠 폭**(`min(maxWidth, 960)`)
  으로 스코프+테마 주입. 웹 960 칼럼 안에서 2560 크기로 그리는 결함을 원천 차단
- `lib/core/widgets/bb_tab.dart` (신설) — 아이콘 가로 배치 탭. 9곳 전부 이관
- `lib/core/theme/bb_density.dart` — 폭 조회를 `BbType` 에 위임(경쟁 경로 0개)
- `tool/check_ui_scaling.py` + `ui_scaling_baseline.json` (신설) — ratchet,
  baseline 1,699, 시범 3파일 잔존 0 강제
- `test/core/theme/responsive_sweep_test.dart` (신설, **30건**)
- 삭제 4파일: 월말 점검 카드·큐빗 + 테스트 2

### 12.4 게이트 결과 `[측정]`

- `flutter analyze` 전체 — **3 issues (전부 기존 테스트 파일 info, 신규 0)**
- `flutter test` — **1058 pass** (1036 → −8 삭제 +30 스윕)
- `./gradlew test` — BUILD SUCCESSFUL (BE 무변경 회귀 확인)
- `flutter build web --release` — **EXIT=0**
- `python3 tool/check_ui_scaling.py` — **통과** (total=1699 = 기준선, 시범 3파일 0)

### 12.5 가드가 실제로 막은 것

구현 중 기존 가드 **S3(폭 읽기 단일 지점)** 가 `bb_scale.dart` 를 즉시 잡아 실패했다.
설계대로 `BbDensity` 를 `BbType` 아래로 흡수하고 소유자를 이관해 해소했다 —
**토큰을 추가만 하고 옛 경로를 남겼다면 여기서 걸렸을 것**이고, 그게 이 가드의 목적이다.
