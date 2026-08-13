# 자산 탭 모바일 가독성 + 브랜드 색상 체계 개편 (기획서)

- 작성: 2026-08-13
- 회차 태그: `ui_pattern` (하네스 게이트 STRUCTURAL_FIX_REQUIRED — §5 가 해제 근거)
- 선행 회차: "합계 ≠ 행" (PR #297, 라이브 검증 대기 중 — 이 회차와 파일 충돌 없음)
- 근거 등급: `[측정]` 직접 실행/관측 · `[1차]` 공식 소스(Flutter SDK 코드) · `[추론]` 유도(과정 병기) · `[미확인]`

---

## 0. 확정된 판정 (사용자, 2026-08-13)

1. **메인 색상 = 틸 `#0F766E`** (라이트 primary), 다크 primary `#5ED3C4`.
   단, 수입 블루가 틸과 인접 → 수입 색은 채도·색상 재조정 대상(§3 U3 판정 기준).
2. **타일 구조 = 편집 모드 분리.** 보기 모드는 이름 + 금액만. 상단 "편집" 진입 시에만
   활성 토글 · 설정(⋮) · 순서 변경(≡) 노출.
3. **적용 범위 = 자산 탭 3개 하위 탭 + 분석>예산 화면의 "자산 현황" 카드 + 테마 토큰(앱 전역)
   + 저장&계속 스크롤 fix.** 나머지 68파일 하드코딩 색은 래칫 가드로 점진 축소(이번 회차 미수정).

---

## 1. 요청 내용

1. 모바일에서 자산 탭 콘텐츠가 안 보인다. On/Off 버튼이 너무 커서 글자 영역이 좁다.
   활성화 버튼을 별도 공간으로 두고 설정·순서 변경 아이콘도 조정.
   **모바일에서 콘텐츠 자체는 한 줄에 온전히 표시**되고, 크기를 조정해 전체 내용이 보여야 한다.
2. 다크모드에서 기본 녹색이 안 맞는다. Budget Book 메인 색상을 정해 라이트/다크 모두에서
   잘 보이도록 개편.
3. (턴 중 추가) "저장 & 계속" 으로 저장하면 **최상단으로 이동**해야 한다. 현재는 위치가 유지된다.

---

## 2. 영향 범위 분석 (측정)

### 2.1 왜 안 보이는가 — 크롬이 콘텐츠보다 넓다

360dp 폭에서 결제수단 한 행이 쓰는 **고정 크롬 236dp**, 콘텐츠 잔여 **124dp** `[추론]`
(유도: 아래 상수 합산 — 40+32+40+16+52+40+16 = 236, 360−236 = 124):

- 순서 변경 핸들 40dp — 아이콘 24 + 좌우 패딩 8·8. 타일 **밖** Row `[측정: asset_management_page.dart:1120-1132]`
- ListTile 좌우 contentPadding 32dp `[1차: list_tile.dart:619 EdgeInsets.symmetric(horizontal: 16.0)]`
- leading CircleAvatar 40dp + horizontalTitleGap 16dp `[1차: list_tile.dart:1026 기본값 16]`
- trailing Switch **52dp** `[1차: switch.dart:2370 _SwitchConfigM3.switchWidth => 52.0]`
- trailing PopupMenuButton 40dp `[1차: icon_button.dart:1130 minimumSize Size(40,40), popup_menu.dart:1340 padding 8]`
- trailing 과 title 사이 간격 16dp

**핵심 오진 정정**: `Transform.scale(0.85)` 로 "컴팩트화" 했다는 주석
`[측정: asset_management_page.dart:1287-1301]` 은 **레이아웃 폭을 1dp도 줄이지 않는다** —
`Transform` 은 페인트만 스케일하는 프록시 박스이므로 부모 Row 는 여전히 52dp 를 예약한다 `[1차]`.
2026-05-04 의 fix 는 시각적으로만 작아 보였고 폭 압박은 그대로였다.

### 2.2 반응형 기준이 앱에 없다

- `isMobile` / 브레이크포인트 헬퍼 **0건**. `LayoutBuilder` 는 무관한 2곳(app.dart:65,
  admin_dashboard_page.dart:112)뿐 `[측정]`
- `textScaler` 취급 **0건** `[측정]` → 시스템 글꼴 확대(1.15~1.3) 시 뱃지·칩이 커져 더 나빠진다
- 결론: 폭에 따라 밀도를 바꿀 단일 소스가 없어서 화면마다 하드코딩 fontSize(10~15)가 흩어져 있다

### 2.3 다크모드가 어긋나는 진짜 이유

- 라이트/다크 모두 `colorSchemeSeed: AppColors.primary(#4CAF50)` 하나 `[측정: app_theme.dart:12,38]`
- 화면 색은 대부분 팔레트 하드코딩: `Colors.{grey,red,green,blue,...}` **324건 / 71파일** `[측정]`
- 의미 토큰은 사실상 **죽어 있다** — `AppColors` 참조 3건 중 실사용은 `AppColors.primary` 2건
  (둘 다 `app_theme.dart` 의 씨드)이고, `income` / `expense` / `budget` / `savings` 4개는
  **참조 0건** `[측정, 2026-08-13 정정]`. 즉 의미 색 체계는 선언만 있고 화면에 연결된 적이 없다
- 자산 탭 실례: 칩 배경 `Colors.grey.shade200` / `red.shade50` / `blue.shade50` + 짙은 전경
  `[측정: asset_management_page.dart:1200-1211]`, 요약 카드 `Colors.green.shade700` /
  `red.shade700` `[측정: 1814-1836]` → 다크 서피스 위에서 **라이트 전용 값이 그대로** 남는다
- 타입 색도 단일 함수에 하드코딩: `paymentMethodTypeColor` = green/blue/deepPurple/teal
  `[측정: payment_method_helpers.dart:34-41]` → 다크 미대응
- 사용자 지정 색(카테고리·포켓)은 DB hex → `UIHelpers.parseColor` **19곳** `[측정]`.
  어두운 사용자 색이 다크 배경에 묻는 경로가 여기 하나로 좁혀진다
- 결론: **씨드만 바꿔도 안 고쳐진다.** 토큰화 + 다크 쌍 정의가 함께 가야 한다

### 2.4 도달 경로 (필수 — 죽은 화면에 작업하지 않기 위한 확인)

- 자산 탭: 하단 네비 index 2 → `/assets` → `AssetManagementPage` `[측정: app_router.dart:752-783,
  main_shell_page.dart:219]`
- 같은 페이지가 더보기(설정) → `/asset-management` 로도 열린다 `[측정: settings_page.dart:123]`
  → **한 번 고치면 두 경로 모두 반영**
- "자산 현황" 카드: 분석 탭 → 예산 화면에서 `AccountBalanceCard(showHeader: false)` 로 **라이브**
  `[측정: budget_list_page.dart:593,665]`
- ⚠ **죽은 화면 판정**: `PaymentMethodPage`(`/payment-methods`)로 가는 유일한 진입점은
  `account_balance_card.dart:46` 의 "관리" 버튼이고, 그 버튼은 `showHeader: true` 에서만
  렌더된다. `showHeader: true` 사용처는 `dashboard_page.dart:89`(미라우팅 죽은 코드)뿐
  `[측정]` → **PaymentMethodPage 는 사실상 도달 불가. 이번 회차 작업 대상에서 제외**
- ⚠ `CategoryPage`(`/categories`)도 진입점이 `home_page.dart:24`(죽은 홈)뿐 `[측정]` → 제외
- 근거 메모리: `reference_dead_home_dashboard`

### 2.5 "저장 & 계속" 스크롤 (요청 3)

- `_resetFormForContinue()` 는 입력값만 비우고 스크롤을 건드리지 않는다
  `[측정: transaction_form_page.dart:2373-2402]`
- 폼 본문 `SingleChildScrollView` 에 **ScrollController 가 없다** `[측정: :958]`
  → 버튼이 있는 하단 위치가 그대로 유지된다
- 지출/수입 탭이 TabBarView 로 **동시 생존**한다 `[측정: :790-798]` → 컨트롤러는 탭별 1개.
  이미 FocusNode 를 탭별로 분리한 선례가 있다 `[측정: :158-169]`
- 편집 모드에서는 `context.go` 로 목록으로 나가므로 무관 `[측정: :686-693]`

### 2.6 이전 세션 관련 이력

- `reference_framework_owned_affordance` — 프레임워크 위젯이 같은 동작의 어포던스를 이미 가지면
  "경로 추가"는 재발. 이번엔 ListTile 자체를 우리 위젯으로 교체하는 방향이므로 같은 함정을 피한다
- `feedback_common_scope_audit` (5회+) — 한 곳만 수정 금지 → §0-3 범위 판정이 이 규칙의 적용
- `feedback_financial_consistency` (CRITICAL) — **금액 축약 금지.** 폭이 부족하면 축약이 아니라
  폰트 자동 축소로 해결한다(§4 D3)
- `feedback_full_flutter_analyze` — 부분 경로 analyze 금지, 전체로 돌린다

---

## 3. 결정 필요 항목 · 미해결 사항

### 결정된 것 (§0) 외에 남은 판정 — 사전 기준 병기

- **U1 차트 색이 primary 에 묶여 있는지** → **해소(2026-08-13 측정)**.
  통계 위젯 9개 중 `colorScheme.primary` 사용은 `period_budget_tab.dart` **1건**뿐 `[측정]`.
  차트는 각 파일이 자기 시리즈 팔레트를 하드코딩·복제해서 쓴다 —
  `_defaultColors` 10색이 `category_breakdown_tab` / `period_category_tab` /
  `period_payment_method_tab` 에 복제, `payment_method_stats_tab` 은 별도 `_colors`,
  `monthly_trend_tab` 은 `_incomeColor #4CAF50` · `_expenseColor #F44336` · `#2196F3` 하드코딩 `[측정]`.
  → **사전 판정 기준대로 "primary 의존 없음 = 차트는 이번 회차 미변경"** 을 적용한다.
  씨드를 틸로 바꿔도 차트 판독성은 흔들리지 않는다.
  ⚠ 단 부수 사실 1건: 차트는 **수입을 그린(#4CAF50, 구 브랜드색)** 으로, 장부는 수입을 블루로
  그린다 — 기존부터 있던 불일치이며 이번 회차 범위 밖이다(§13 후속 대기열로 이관)
- **U3 수입 블루 vs 브랜드 틸 인접** `[미확인]`.
  수단=명도비 + 색상 거리 자동 측정 테스트. 사전 판정: 두 색의 HSL hue 차 < 40° 또는
  인접 배치 시 명도비 < 1.5 이면 수입을 `#2563EB` 로, 그래도 미달이면 `#4338CA`(인디고)로 이동.
  **지출 레드는 error 와 구분되어야 하므로 error 토큰과 hue 차 유지**
- **U2 사용자 기기 실제 논리 폭** `[미확인]`. 확인 주체=사용자(라이브 검증 C1).
  대응: 최악 조건 320dp 를 자동 매트릭스에 포함해 가정 없이 커버
- **U4 편집 모드 어포던스 수용성** `[미확인]`. 확인 주체=사용자(라이브 검증 B).
  사전 판정: "토글/삭제를 못 찾겠다" 가 나오면 → 상단 편집 버튼에 텍스트 라벨 병기(이미 계획된
  상태) 확인 → 그래도 미해결이면 **롤백 옵션 = 우측 세로 액션 레인**(질문 2안)으로 전환.
  이 판정은 재기획이 아니라 사전 합의된 분기다
- **U5 다크에서 사용자 지정 색 보정 시 "내가 고른 색과 달라 보인다" 인지** `[미확인]`.
  대응: 보정은 HSL 명도(L) 클램프만 하고 hue·채도는 보존(§4 D5). 확인=라이브 검증 C4

---

## 4. 설계

### D1. 색상 토큰 — `BbColors` ThemeExtension (단일 소스)

- `core/theme/bb_colors.dart` 신설. 라이트/다크 **쌍**으로 정의하고 `ThemeExtension` 으로 주입.
  접근은 `context.bb.income` 형태의 확장 게터 하나로만.
- 브랜드: 라이트 `#0F766E` / 다크 `#5ED3C4` (씨드는 `#0F766E`, 다크는 씨드 + 명시 override)
- 의미 토큰(각각 fg/container 쌍): `income`, `expense`, `transfer`, `budget`, `savings`,
  `neutralChip`, `positiveBalance`, `negativeBalance`, `warnChip`
- 결제수단 타입 색은 `paymentMethodTypeColor(type)` → `context.bb.paymentType(type)` 로 이동
  (하드코딩 5색 제거, 다크 쌍 확보)
- `AppColors` 는 삭제하지 않고 `@Deprecated` + 토큰 위임으로 남긴다(참조 3건 정리 후 다음 회차 제거)

### D2. 밀도 단일 소스 — `BbDensity`

- `core/theme/bb_density.dart`: `compact(<400dp)` / `regular(400–839)` / `wide(≥840)`.
  값은 `MediaQuery.sizeOf(context).width` 한 곳에서만 읽는다
- 노출 값: 타일 좌우 패딩, 아바타 크기, 액션 아이콘 크기, 기준 글꼴 크기, 칩 밀도
- 화면 코드에서 `MediaQuery...width` 직접 사용 금지(가드 S3)

### D3. 한 줄 온전 표시 — `OneLineLabel`

- `core/widgets/one_line_label.dart`. 입력은 **String** 과 (base, min) 글꼴 크기.
  `TextPainter` 로 가용 폭에 맞는 크기를 base→min 사이에서 고른다. min(=12sp) 에서도 넘칠 때만
  ellipsis. **금액 문자열 축약은 하지 않는다**(금액 정확도 규칙)
- 결과: "카카오뱅크 생활비" 같은 이름이 잘리지 않고 크기만 줄어든다 = 요청의 "크기를 조정해서
  전체 내용이 보이는 구조"

### D4. 공통 타일 — `EntityTileRow` + `AssetEditModeScope`

- `core/widgets/entity_tile_row.dart` 신설. **`ListTile` 을 쓰지 않는다**(폭 계약을 우리가 소유).
  API 형태:
  - `title: String` (Widget 불가 — 호출부가 폭 계약을 깨지 못하게 **컴파일 타임 봉인**)
  - `badge: EntityBadge?` (열거 값 + 라벨 문자열. 임의 위젯 불가)
  - `metrics: List<EntityMetric>` (라벨·금액·의미색 토큰. 표시 형식은 위젯이 결정)
  - `leadingIcon`, `leadingColor`, `dimmed`(비활성), `onTap`
  - `actions: EntityTileActions?` — **편집 모드에서만** 렌더. 토글/설정/순서 세 슬롯 고정
- 보기 모드: 좌측 아바타 + 이름(전체 폭, `OneLineLabel`) + 금액. **타입 텍스트 뱃지는 제거**
  (아바타 아이콘이 이미 타입을 표현 — 중복 40~50dp 회수). 비활성 항목은 dimmed + "비활성" 표기
- 편집 모드: 이름 한 줄 + 우측 고정 액션 레인 `[토글] [⋮] [≡]`. 편집 모드에서 `onTap` 은
  비활성(오조작 방지)
- `AssetEditModeScope` (InheritedNotifier) — 페이지 AppBar 의 편집 버튼이 소유. 하위 3개 탭이
  `of(context)` 로 읽는다. 탭 전환 시 유지, 페이지 이탈 시 해제
- `ReorderableListView` 는 `buildDefaultDragHandles: false` 유지 + 드래그 리스너를 편집 모드에서만
  부착(기존 reorder 로직·이벤트는 그대로)

### D5. 사용자 지정 색 판독성 — 단일 보정 지점

- `BbColors.readable(Color userColor, Brightness b)` — HSL 명도만 클램프(다크: L ≥ 0.55,
  라이트: L ≤ 0.55). hue·채도 보존
- 자산 탭·자산 현황 카드의 표시 경로는 `parseColor` 결과를 이 함수에 통과시킨다

### D6. 저장 & 계속 → 최상단

- 폼 본문에 **탭별 ScrollController** (`_expenseScroll`, `_incomeScroll`, 편집 단일 폼용 1개)
- `_resetFormForContinue()` 에 `animateTo(0)` + 금액 입력 필드 포커스 요청 추가
  (요청은 "최상단 이동" 이고, 다음 입력이 금액이므로 포커스까지 옮기는 것이 자연스럽다)
- 활성 탭 판정은 기존 `_tabController.index` 규칙 재사용 `[측정: :2423]`

---

## 5. 하네스 게이트 해제 근거 — 구조적 강제 S1~S7

`ui_pattern` 은 STRUCTURAL_FIX_REQUIRED(과거 4건: 아이콘 폰트 캐시 / nginx 하드코딩 /
죽은 화면 위젯 / 프레임워크 어포던스). 공통 실패 원인은 **"한 곳에 얹기"** 였다.
이번 회차의 강제는 다음 7개다.

- **S1 (컴파일 타임)** `EntityTileRow.title: String` — 호출부가 임의 위젯을 넣어 폭 계약을 깨는
  것이 **불가능**. 뱃지·메트릭·액션도 값 타입만 받는다
- **S2 (가드 테스트 · 래칫)** `test/core/theme/hardcoded_color_ratchet_test.dart` —
  파일별 `Colors.*` 허용 상한 baseline(현재 324건/71파일)을 스냅샷으로 고정. 상한 초과 시 실패,
  **신규 파일은 0**, 이번 회차 대상 6파일은 **0 고정**. 하드코딩은 이제 늘어날 수 없다
- **S3 (가드 테스트)** 대상 파일에 `ListTile(` 직접 생성 0건 + `MediaQuery...size.width` 직접
  사용 0건 — 밀도·타일 계약 우회 금지
- **S4 (자동 매트릭스)** `{320, 360, 390, 768}dp × {light, dark} × textScale{1.0, 1.3} ×
  {보기, 편집}` = 32조합에서 ① 오버플로 예외 0건 ② 대표 20자 이름이 ellipsis 되지 않음
  ③ 액션 레인 탭 타깃 ≥ 40dp
- **S5 (자동 정량)** WCAG 명도비 계산 테스트 — 모든 토큰 쌍(전경 vs 컨테이너)에서 본문 ≥ 4.5,
  아이콘·대형 ≥ 3.0. 라이트·다크 각각. **미달 토큰은 채택 불가**(사전 판정 기준)
- **S6 (가드 테스트)** 대상 파일에서 `parseColor(` 결과를 `readable()` 없이 색으로 쓰지 않는다
- **S7 (위젯 테스트)** 폼을 아래로 스크롤 → 저장&계속 → **offset == 0** + 금액 필드 포커스.
  탭별 컨트롤러 2개 모두 검증

---

## 6. 작업 계획 (커밋 단위, 승인 후 순서 고정)

1. **선행 측정** — U1(차트 primary 의존) grep. 결과에 따라 커밋 1 범위에 `series` 토큰 포함 여부 결정
2. **커밋 1 — 토큰/테마 기반**: `bb_colors.dart`(라이트·다크 쌍, 틸 씨드) / `bb_density.dart` /
   `one_line_label.dart` / `readable()` + 단위 테스트 + **S5 명도비 테스트**.
   화면 코드 변경 0 → 회귀 표면 최소
3. **커밋 2 — 공통 타일**: `entity_tile_row.dart` + `AssetEditModeScope` + **S4 매트릭스 테스트** +
   **S1/S3 가드**
4. **커밋 3 — 자산 탭 이관**: 결제수단·카테고리·포켓 3개 탭을 공통 타일로 교체, AppBar 편집 버튼,
   reorder 편집 모드 배선, 대상 파일 하드코딩 색 0건화. `CategoryListTile` 도 같은 타일로 이관
   (자산 탭이 유일한 라이브 사용처 — `category_page` 는 죽은 화면).
   **상단 헤더 카드도 같은 커밋에 포함** — `_AssetSummaryHeader`(총자산·부채·순자산),
   `_CardSettlementCardsView`(전월·미결제·이번달), `_SettlementCard`/`_SummaryCard`/`_SubChip` 의
   하드코딩 fontSize(10~15)·색을 density·토큰으로 교체. 헤더만 라이트 전용으로 남으면
   "한 곳만 수정" 재발이다
5. **커밋 4 — 자산 현황 카드**: `account_balance_card.dart` 를 같은 토큰·타일로. 칩 3종 다크 대응
6. **커밋 5 — 저장&계속**: 탭별 ScrollController + **S7 테스트**
7. **커밋 6 — 래칫 가드**: baseline 스냅샷 + **S2 테스트**
8. **로컬 CI 5종** → PR → 원격 CI → 머지 → 배포 → §8 라이브 검증 요청

- BE 변경 **0건**, DB 마이그레이션 **0건**, `docs/api-spec.md` 변경 **없음**
- 문서: `docs/PROGRESS.md` 타임라인 + STATE/NEXT 갱신(각 게이트 통과 시점마다)

---

## 7. 성능 설계

- `OneLineLabel` 은 빌드마다 `TextPainter` 를 돌린다 → 후보 크기를 **이진 탐색 4회 이하**로
  제한하고, (문자열, 가용폭, 스타일) 키로 프레임 단위 메모이즈. 목록 200행 기준 프레임 예산 초과
  여부를 위젯 테스트에서 측정(빌드 시간 상한 가드)
- `BbDensity` 는 `MediaQuery.sizeOf` 사용(전체 MediaQuery 의존 제거) → 키보드 등장 등
  무관한 변화로 리빌드되지 않는다
- 편집 모드는 `InheritedNotifier` 로 타일만 리빌드(페이지 전체 setState 금지)
- 색 토큰은 `const` 값 + `ThemeExtension` 캐시 → 런타임 계산 0. `readable()` 만 HSL 변환이므로
  타일당 1회, 결과는 위젯 필드로 보관

---

## 8. 자동 검증 계획 (비용 오름차순 + 편향 제거)

1. **단위(가장 저렴)**: `OneLineLabel` 크기 선택 함수 / 명도비 계산 / `readable()` 클램프 /
   density 경계값(399·400·839·840)
2. **소스 스캔 가드**: S1~S3, S6, 래칫 S2
3. **위젯 매트릭스 S4**: 32조합. **편향 제거 — 최상 조건(390dp·textScale 1.0·라이트)만 재지 않고
   최악(320dp·1.3·다크·편집 모드)을 반드시 포함.** 실데이터 최악 케이스로 20자 이름 + 9자리 금액 +
   칩 3개를 함께 렌더
4. **명도비 S5**: 토큰 전수 × 라이트/다크
5. **폼 S7**: 스크롤 → 저장&계속 → offset 0
6. **전체 CI**: `flutter analyze --no-fatal-infos --no-congratulate`(전체 경로) /
   `flutter test`(현재 894건 + 신규) / `./gradlew test`(BE 무변경 확인) /
   `flutter build web --release`
7. **번들 문자열**: 신규 UI 문자열("편집", "비활성" 등)이 릴리스 번들에 존재하는지 —
   한글은 `\uXXXX` 이스케이프 대조로 확인(메모리 `reference_live_bundle_string_verification`)
8. **배포 후**: `infra/scripts/verify-cache-headers.sh`(아이콘 폰트 해시 게이트 포함)

---

## 9. 배포 절차

1. 로컬 CI 5종 전부 통과 후에만 PR 생성(개인 계정 저장소 → 커밋·PR·머지 자동 진행)
2. 원격 CI 통과 → `gh pr merge --squash --delete-branch`
3. GitHub Actions → NAS 배포 → `verify-cache-headers.sh` 통과 확인
4. `main.dart.js` `last-modified` 갱신 확인 후 사용자 라이브 검증 요청
5. ⚠ 머지·배포는 완료가 아니다. **사용자 라이브 검증 통과만 완료**

---

## 10. 사용자 검증 시나리오

### A. 모바일 자산 탭 가독성

- **A1** 모바일에서 자산 탭 → 결제수단: 이름이 **잘리지 않고 한 줄로** 보이고, 잔액이 같은 행에서
  읽힌다. 이름이 긴 항목(예: "카카오뱅크 생활비")에서 `…` 이 없다
- **A2** 카드 항목: 마감/결제일 + 전월·미결제·이번달 금액이 **줄바꿈 없이** 읽힌다.
  금액은 축약(만원 등) 없이 원 단위 그대로다
- **A3** 카테고리 탭·포켓 탭도 같은 밀도·같은 한 줄 규칙으로 보인다
- **A4** 시스템 글꼴 크기를 크게(1.3배) 설정해도 깨지지 않는다
- **A5** 자산 탭 **상단 3카드**(총자산·부채·순자산 / 전월·미결제·이번달)도 금액이 잘리지 않고
  라벨이 읽힌다. 좌우 스와이프 전환도 이전과 동일하다

### B. 편집 모드

- **B1** 보기 모드에는 토글·⋮·≡ 가 없고 이름/금액만 보인다
- **B2** 상단 "편집" → 세 아이콘이 우측 레인에 나타난다. 토글로 활성/비활성 전환이 즉시 반영된다
- **B3** 편집 모드에서 ≡ 드래그로 순서 변경이 이전과 동일하게 동작한다(그룹 간 이동 제약 포함)
- **B4** 편집 모드에서 ⋮ → 수정/삭제/잔액 수정이 이전과 동일하다
- **B5** 편집 모드에서 항목을 눌러도 거래 탭으로 튀지 않는다. 보기 모드에서는 튄다(기존 동작)
- **B6** 탭(결제수단↔카테고리↔포켓)을 바꿔도 편집 모드가 유지되고, 화면을 나가면 해제된다
- **B7** 비활성 항목이 보기 모드에서도 구분된다(흐림 + "비활성")

### C. 색상 (라이트·다크)

- **C1** 다크모드로 바꾼 뒤 자산 탭: 칩·금액·뱃지가 배경에 묻지 않는다
- **C2** 라이트/다크 모두에서 브랜드 틸이 어색하지 않다(FAB·선택 상태·탭 인디케이터)
- **C3** 분석>예산 화면의 "자산 현황" 카드도 같은 규칙으로 보인다
- **C4** 카테고리·포켓의 **직접 고른 색**이 다크에서도 보이고, 고른 색과 크게 달라 보이지 않는다
- **C5** 수입(블루)·지출(레드)이 브랜드 틸과 혼동되지 않는다
- **C6** 거래·분석·정산 등 다른 화면에서 색이 깨진 곳이 없다(씨드 변경 전역 영향 확인)

### D. 저장 & 계속

- **D1** 거래 등록 폼에서 아래로 스크롤 → "저장 & 계속" → **최상단으로 이동**하고 금액 입력에
  포커스가 잡힌다
- **D2** 지출 탭·수입 탭 각각에서 동일하게 동작한다
- **D3** "저장"(계속 아님)은 이전처럼 목록으로 나간다

---

## 11. 리스크

- **R1 어포던스 회귀** — 편집 모드로 숨기면 토글/삭제를 못 찾을 수 있다.
  완화: 편집 버튼에 아이콘 + 텍스트 라벨 병기, 비활성 항목은 보기 모드에서도 표기.
  판정·롤백 경로는 §3 U4
- **R2 reorder 회귀** — 드래그 리스너를 조건부로 붙이면서 인덱스 계산이 깨질 수 있다(헤더 포함
  리스트라 기존 로직이 예민하다 `[측정: :994-1061]`). 완화: 기존 reorder 로직 무변경 + 편집 모드
  드래그 위젯 테스트 추가
- **R3 씨드 변경 전역 영향** — primary 를 쓰는 모든 화면의 색이 바뀐다. 완화: U1 선행 측정 +
  검증 C6
- **R4 래칫 baseline 오염** — baseline 을 잘못 크게 잡으면 가드가 무력해진다. 완화: baseline 생성
  스크립트를 테스트가 직접 실행해 재계산(수동 편집 값 신뢰 금지)
- **R5 "합계 ≠ 행" 회차와 병행** — 그 회차는 라이브 검증 대기 중이다. 이번 변경은 거래 목록
  타일·합계바·필터를 **건드리지 않는다**(범위 §0-3) → 검증 간섭 없음. 단 배포가 겹치면
  A1~A11 재확인이 필요할 수 있으므로 **선행 회차 라이브 검증을 먼저 받고 착수**한다

---

## 12. 미해결 사항 요약

- ~~U1 차트 primary 의존 여부~~ — **해소(§3)**: 의존 1건뿐 → 차트 미변경
- U2 사용자 기기 실제 폭 — 사용자 / 라이브 검증(320dp 를 매트릭스에 포함해 무가정 커버)
- U3 수입 블루 최종 hex — 나 / 자동 색차·명도비 측정, 사전 판정 기준 §3
- U4 편집 모드 수용성 — 사용자 / 검증 B, 롤백 경로 사전 합의
- U5 사용자 색 보정 인지 — 사용자 / 검증 C4

---

## 13. 후속 대기열로 이관 (이번 회차 범위 밖)

- **차트 색 체계 통일** — 통계 위젯 9개가 시리즈 팔레트를 각자 복제(`_defaultColors` 3중복 +
  `_colors` 별도)하고, **차트는 수입을 그린으로 / 장부는 수입을 블루로** 그린다 `[측정]`.
  이번 회차에서 만드는 `BbColors` 에 `series` 토큰을 얹어 한 곳으로 모으는 것이 다음 단계다.
  이번 회차에 넣지 않는 이유: 사용자 확정 범위(자산 탭 + 자산 현황 카드 + 토큰) 밖이고,
  차트가 primary 에 의존하지 않아 씨드 변경으로 깨지지 않는다(§3 U1)
- **나머지 68파일 하드코딩 색 이관** — 래칫 가드(S2)가 증가를 막고, 회차마다 baseline 을
  낮추는 방식으로 점진 축소
- **죽은 화면 정리** — `PaymentMethodPage` · `CategoryPage` · `DashboardPage` ·
  `home_page` · `monthly_trend_card` · `category_breakdown_card` 는 도달 불가 `[측정]`.
  삭제 여부는 홈 탭 복원 결정과 함께 판단
