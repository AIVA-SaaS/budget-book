# 여백·간격 체계 회차 — `BbDensity` 흡수 + 공간 곡선 재설계 (기획서)

- 회차: 2026-08-20 / 요청: 사용자(2026-08-19) "여백, 간격 같은 부분도 확인되어 적절하게 조정될 수 있게 해줘"
- 규칙 정본: `~/.claude/domains/12-ui-scaling.md` (전 앱 기본값)
- 직전 회차 정본: `docs/sessions/2026-08-19_1_typography-anchor_result.md` (PR #299/#300)
- 하네스: `ui_pattern` = **STRUCTURAL_FIX_REQUIRED** → 본 기획서 §4 가 구조적 수정 계획

---

## 1. 문제 — 측정

### 1.1 여백은 폭에 사실상 반응하지 않는다 `[측정 2026-08-20]`

`BbSpace.factor = sqrt(body(W)/14)` 이고 `body` 는 `13~15` 로 clamp 돼 있어 계수 범위가
`0.964 ~ 1.035` (7%) 뿐이다. 폭 320→2560(8배)에서 `md` 토큰은 **7.71 → 8.28dp**, 즉 **0.57dp** 움직인다.

```
            320   360   390   768   960  1440  2560
BbSpace md  7.71  7.71  7.71  8.08  8.28  8.28  8.28   ← 7% 범위 = 사실상 상수
```

원인은 **층 의존의 부작용**이다. 폰트의 가독 clamp(13~15)가 여백 계수까지 묶는다.
직전 회차에서 폰트가 겪은 것과 **같은 구도**이고, 이번이 두 번째다.

### 1.2 여백 토큰은 앱에 거의 이관되지 않았다 `[측정 2026-08-20]`

`BbSpace` 를 쓰는 `lib` 파일은 **3개**뿐이다 — `bb_scale.dart`(정의) · `bb_tab.dart` · `month_navigator.dart`.
반면 체계 밖 크기 리터럴은 **1,699건**(ratchet baseline)이고 `EdgeInsets` 446 · `SizedBox(w/h)` 747 이다.

귀결: **곡선만 고쳐도 사용자 눈에 보이는 변화는 거의 없다.** 폰트는 `TextTheme` 이 전역이라
토큰 수정만으로 전 화면에 퍼졌지만, 여백에는 그 전역 통로가 없다. 따라서 이 회차는
(곡선 수정) + (전역 통로 = 테마 여백) + (가시 표면 이관) 세 가지를 함께 해야 성립한다.

### 1.3 경쟁 경로 `BbDensity` 가 남아 있다 `[측정 2026-08-20]`

`BbDensity` 는 폭을 3단 계단(`<400` / `400~839` / `>=840`)으로 끊어 15개 값을 별도로 정의한다.
소비 지점은 2파일뿐이다 — `entity_tile_row.dart`(대부분) · `asset_management_page.dart`(헤더 폰트 3곳).

- 폰트 5개(`titleFontSize`·`metricFontSize`·`chipFontSize`·`headerLabelFontSize`·`headerValueFontSize`)는
  직전 회차에서 이미 `BbType`/`TextTheme` 이 **같은 값을 지나가도록** 역산했다 → 완전 중복.
- 여백·박스 8개(`tilePaddingH/V`·`gap`·`chipPaddingH`·`avatarSize`·`avatarIconSize`·
  `actionIconSize`·`actionSlotSize`·`toggleSlotWidth`)는 **곡선 체계에 대응물이 없다**
  = 폭에 반응하는 유일한 여백이면서 동시에 계단이다.

또한 계단은 `BbDensity` 만이 아니다 `[측정]`: `BbType.tabHeight`(`width<600 ? 44 : 48`),
`BbType.navBarHeight`(`width<600 ? 66 : 80`), `AppTheme._densityFor`(`<600` / `<960` / else) 3곳이 더 있다.

### 1.4 기준점은 다시 자산 탭이다 `[1차]`

`BbDensity` 의 3단 값은 사용자가 승인한 유일한 실측 표면이다(2026-08-19 "자산 내 크기가 딱 적절하다").
따라서 폰트 때와 동일하게 **그 값을 연속 곡선이 지나가도록 역산**한다.

---

## 2. 해법 — 곡선 재설계

### 2.1 왜 "폰트 비율의 제곱근" 을 버리는가 `[추론 — 유도 과정 병기]`

승인된 자산 탭 값의 320→960 스팬을 보면:

- `padH` 10→16 = **1.60배** · `padV` 8→12 = 1.50배 · `gap` 6→10 = 1.67배
- 반면 본문 폰트 13→15 = **1.15배**

현행 결합식(`space ∝ body^0.5`, 순 폭지수 = 0.25×0.5 = **0.125**)의 최대 스팬은
`(960/320)^0.125 = 1.15배`다. 즉 **어떤 ref/clamp 를 골라도 여백의 1.6배 스팬을 만들 수 없다.**
검증: `padH` 를 폭지수 0.125 로 두고 상한 16 을 960 에서 맞추면 390px 에서 **14.30dp** 가 나온다
(승인값 10). 하한 clamp 가 아예 개입하지 못한다.

필요한 폭지수는 `ln(0.625)/ln(1/3) = 0.428` 이상 → **0.5**(제곱근)를 택한다.
결론: **여백은 폰트보다 탄성이 커야 한다.** 이것은 도그마가 아니라 승인된 표면의 실측 결과다
(자산 탭 자체가 폰트 1.15배 / 여백 1.60배로 그려져 있고 사용자가 그것을 "적절하다"고 판정했다).

### 2.2 새 결합식

```
space(token, W, scaler) = clamp( min_px[token], ref[token] × (W/1440)^0.5 , max_px[token] ) × sqrt(scaler)
type (role,  W)         = clamp( min_px[role],  ref[role]  × (W/1440)^0.25, max_px[role]  )
```

세 가지가 핵심이다.

1. **clamp 는 각 토큰이 자기 px 로** 건다 → 아래 층(폰트)의 clamp 가 위 층(여백)을 묶지 못한다.
   §1.1 의 재발(이번이 2회)을 **구조적으로** 끊는 지점이다.
2. `sqrt(scaler)` 는 **clamp 밖**에 곱한다 → 접근성 배율이 상한에 잘려 "글자만 커지고 여백은
   그대로"가 되는 것을 막는다. 도메인 ★4(부분 결합 = 제곱근, textScaler 를 1급 입력으로)는 유지된다.
   기존 스윕 단정 `scaled.md/plain.md ≈ sqrt(1.6) = 1.265` 가 **그대로 통과**한다.
3. 폭지수는 타이포 0.25 / 공간 0.5 **두 개**로 고정하고, 그 외 어떤 축도 자기 곡선을 갖지 못한다.

### 2.3 역산 결과 `[측정 — 계산 검증 완료]`

`ref = max / (960/1440)^0.5 = max / 0.81650` (상한을 콘텐츠 최대폭 960 에서 정확히 찍는다).

```
토큰(자산 앵커)         ref     min  max │  320   360   390   768   960  1440   768 대역 계단차
xl  ← tilePaddingH    19.60    10   16 │ 10.0  10.0  10.2  14.3  16.0  16.0   +0.31
lg  ← tilePaddingV    14.70     8   12 │  8.0   8.0   8.0  10.7  12.0  12.0   +0.73
md  ← gap             12.25     6   10 │  6.0   6.1   6.4   8.9  10.0  10.0   +0.94
sm  ← chipPaddingH     9.80     5    8 │  5.0   5.0   5.1   7.2   8.0   8.0   +1.16
xs  (앵커 없음)         4.90     3    4 │  3.0   3.0   3.0   3.6   4.0   4.0   [추론]
xxl (앵커 없음)        29.39    15   24 │ 15.0  15.0  15.3  21.5  24.0  24.0   [추론]

박스(BbBox — 공간 곡선 e=0.5, scaler 미적용. 아이콘도 텍스트 줄이 아니라 슬롯 기하에 묶인다:
타이포 곡선(e=0.25)으로 계산하면 avatarIcon 768 오차가 -0.32 → +0.81 로 나빠진다 [측정])
avatar                48.99    32   40 │ 32.0  32.0  32.0  35.8  40.0  40.0   -2.22
avatarIcon             26.94    18   22 │ 18.0  18.0  18.0  19.7  22.0  22.0   -0.32
actionIcon             29.39    20   24 │ 20.0  20.0  20.0  21.5  24.0  24.0   -0.53
actionSlot            58.79    44   48 │ 44.0  44.0  44.0  44.0  48.0  48.0   L4-2 하한 44
tabHeight             58.79    44   48 │ 44.0  44.0  44.0  44.0  48.0  48.0   계단 제거
navBarHeight          97.98    66   80 │ 66.0  66.0  66.0  71.6  80.0  80.0   계단 제거(-8.4)
toggleSlot            고정 52 — L4-3(M3 Switch 트랙 52dp 고정). 기존 wide 56 → 52 로 4dp 축소
```

- **양 끝은 승인값과 일치**한다 — `320` 과 `960` 이상은 **정확 일치**, `360/390` 은 하한 근방에서
  최대 +0.4dp(`md←gap` 6.12·`xl←padH` 10.2) 벗어난다(곡선의 정상 성질).
- 중간 대역(768~840)은 계단 대비 최대 **+1.16dp / -2.22dp** 차이. 폰트 회차에서 이미 수용한
  성질(계단↔곡선)과 동일하며, **허용 오차를 가드로 고정**한다(§4 G3).
- `actionSlot` 은 compact 40 → **44** 로 올린다(L4-2 터치 하한). 귀결: 320px 편집 모드에서
  액션 레인이 8dp 넓어져 이름 칸이 116dp 로 줄어든다. `OneLineLabel` 이 축소·생략을 맡고
  스윕이 오버플로 0 을 지킨다. **되돌리는 법**: `min` 을 40 으로 내리면 원복.
- `VisualDensity` 는 `-2 → 0` 을 폭에 대해 **연속 보간**한다(`VisualDensity` 는 double 을 받는다).

### 2.4 전역 통로 — 테마 여백 (§1.2 의 처방)

`AppTheme.responsive()` 가 지금 채우지 않는 여백 슬롯을 곡선으로 채운다. 전 화면 자동 반영이다.

- `inputDecorationTheme.contentPadding` — **현재 하드코딩 `16/12`**
- `inputDecorationTheme.border.borderRadius` — 현재 하드코딩 `12`
- `cardTheme.shape.borderRadius`(현재 `16`) + `cardTheme.margin`
- `chipTheme.padding` / `labelPadding` · `listTileTheme.contentPadding`(+`minVerticalPadding`)
- `dialogTheme.insetPadding` · `bottomSheetTheme` · `tabBarTheme.labelPadding` · `dividerTheme.space`
- `elevatedButtonTheme`/`textButtonTheme`/`outlinedButtonTheme`/`filledButtonTheme` 의 `padding`

### 2.5 가시 표면 이관 (사용자가 "여백이 적절해졌다"를 확인하는 지점)

시범 이관 파일 = 리터럴 잔존 **0** 을 강제한다. 사용자가 지목한 탭을 그대로 덮는다.

1. `lib/core/widgets/entity_tile_row.dart` (3) — 타일 계약 정본
2. `lib/features/settings/presentation/pages/asset_management_page.dart` (67) — **자산**(기준 표면)
3. `lib/features/transaction/presentation/pages/transaction_list_page.dart` (24) — **거래**
4. `lib/features/transaction/presentation/widgets/transaction_list_tile.dart` (22) — **거래**
5. `lib/core/widgets/filters/unified_filter_bar.dart` (29) — 거래·분석 공통 필터바
6. `lib/features/statistics/presentation/widgets/category_breakdown_tab.dart` (27) — **분석**
7. `lib/features/statistics/presentation/widgets/summary_tab.dart` (18) — **분석**

합계 **190건** → ratchet baseline `1699` → **약 1,509** 로 하향. 기존 시범 3파일은 0 유지.
나머지 통계 탭·설정 하위 화면은 이 회차 범위가 아니다 — ratchet 이 회차마다 낮춘다.

---

## 3. 대안과 기각 이유 `[추론]`

- **ⓐ `kBbSpaceReferenceBody` 재설정만** — 계수를 평행이동할 뿐 스팬(7%)이 그대로다. §2.1 로 기각.
- **ⓑ 결합 지수(0.5)만 조정** — 순 폭지수가 0.125 에 묶여 1.6배 스팬 불가. §2.1 계산으로 기각.
- **ⓒ 토큰마다 폭지수를 따로** — 축이 다시 늘어난다(경쟁 경로 재생산). 지수는 2개로 봉인.
- **ⓓ `BbDensity` 유지 + 여백만 곡선화** — 계단과 곡선이 같은 타일에 공존한다. 직전 회차가
  정확히 이 실패("자산만 반응")를 겪었다. 기각.
- **ⓔ 곡선만 고치고 이관은 다음 회차** — §1.2 때문에 사용자 눈에 변화가 거의 없다. 요청 미충족.

---

## 4. 구조적 수정 계획 (하네스 `ui_pattern` STRUCTURAL_FIX_REQUIRED 대응)

재발 패턴은 "**토큰을 추가했지만 경쟁 경로가 남았다**"이고 3회 이상 반복됐다.
이번 회차의 완료 기준은 **경쟁 경로 0개**이며, 컴파일·테스트 수준으로 강제한다.

- **S1. `lib/core/theme/bb_density.dart` 를 삭제한다.** 남은 참조는 **컴파일 실패**한다.
  → "계단을 계속 쓸 수 있는 상태"를 물리적으로 없앤다(문서·리뷰 의존 아님).
- **S2. 폭 분기 금지 가드**(신규 `test/core/theme/no_step_ladder_guard_test.dart`):
  `lib` 전체에서 `width <`·`width >=`·`size.width` 비교와 `Tier`/`compactMaxWidth` 류 식별자를
  금지하고, 허용은 `bb_scale.dart` 의 곡선 정의뿐(허용 목록에 파일 1개). 새 계단은 테스트가 막는다.
- **S3. API 봉인 확장**: `BbSpace` 가 `EdgeInsets`·`SizedBox`·`BorderRadius` 생성 경로를
  토큰 인자로만 노출한다(`double` 을 받는 공개 API 를 두지 않는다) → 리터럴이 새려면 API 를
  우회해야 하고 그건 ratchet 이 잡는다.
- **S4. ratchet + 시범 잔존 0**: baseline 하향 + `PILOT_FILES` 에 §2.5 의 7파일 추가.
- **S5. 정본 문서 갱신**: `~/.claude/domains/12-ui-scaling.md` ★4 를 "여백은 폰트의 **클램프된**
  출력에 결합하지 않는다 — 같은 폭 곡선을 타되 자기 px clamp 를 갖고, textScaler 결합(sqrt)은
  clamp **밖**에 둔다"로 개정한다. 이유: 층 의존 clamp 부작용이 **2회 발생**(폰트·여백)했고
  전 앱 정본이 그 함정을 그대로 담고 있다. calynda 이식 시 같은 함정을 물려주지 않기 위함.

### G. 가드 (스윕 32건 → 약 46건)

- **G1** 여백 토큰이 역할별 px 하한/상한을 지킨다(전 폭 × 배율).
- **G2** **기준점 정합**(가드는 승인값 `10/14/16` 등을 **테스트 안에 직접 적는다** — 코드에서
  읽어 오면 순환 검증이 된다):
  - `320` 에서 전 토큰이 승인된 compact 값과 **정확히 일치**(전부 하한 clamp 구간).
  - `360`·`390` 에서는 compact 값 **이상 + 0.5dp 이내**(실측: `md←gap` 만 360 에서 6.12 로
    하한을 0.12 벗어난다 — 곡선이므로 정상. 정확 일치를 요구하면 거짓 단정이 된다).
  - `960`·`1440`·`2560` 에서 wide 값과 **정확히 일치**.
- **G3** 중간 대역 허용 오차: `400~840` 에서 곡선값이 `[compact, wide]` 구간 안에 있고
  계단값과의 차이가 **±1.5dp 이내**(`avatar` 만 ±2.5dp — §2.3 실측).
- **G4** **불연속 0**: `|v(399.9) - v(400.1)| < 0.05` 및 `|v(839.9) - v(840.1)| < 0.05`
  (계단 재도입을 수치로 막는다).
- **G5** 단조 증가: 폭이 커질 때 어떤 토큰도 줄지 않는다.
- **G6** 배율 결합: `space(1.6)/space(1.0) ≈ sqrt(1.6) = 1.265` (clamp 밖 곱셈 보증) + 배율↑에
  여백이 줄지 않는다(역행 금지).
- **G7** 터치 타깃: `actionSlot` ≥ 44 전 폭 · `IconButton` ≥ 44 (기존 유지).
- **G8** 크롬 예산 래칫: 모바일 콘텐츠 비율 **≥ 0.70** 유지(계단 제거로 768 대역 8.4dp 개선 예상).
- **G9** 테마 여백이 폭에 반응한다: `responsive(_, 360)` 과 `responsive(_, 1440)` 의
  `inputDecorationTheme.contentPadding`·`cardTheme.margin`·`listTileTheme.contentPadding` 이 **서로 다르다**.
- **G10** 기존 타일 가드 8종 · 하드코딩 색 · `ListTile` 금지 · `MediaQuery width` 금지 전부 유지
  (S3 문구에서 `BbDensity` 언급만 `bb_scale.dart` 로 갱신).

---

## 5. 작업 순서

1. `bb_scale.dart` — `kBbSpaceSpec`(토큰별 ref/min/max) · `BbBox`(avatar·slot·chrome) ·
   `_progress(W, e)` 단일 곡선 함수 · `sqrt(scaler)` clamp 밖 적용. `tabHeight`/`navBarHeight` 곡선화.
2. `app_theme.dart` — 테마 여백 슬롯(§2.4) + `VisualDensity` 연속 보간.
3. `bb_density.dart` **삭제** → `entity_tile_row.dart`·`asset_management_page.dart` 를
   토큰으로 교체(폰트 5개는 `BbType` 역할로: title→`section` · metric→`body` · chip→`caption` ·
   hdrL→`label` · hdrV→`title`).
4. 시범 이관 5파일(§2.5 3~7번).
5. 가드: 스윕 확장 · `no_step_ladder_guard_test.dart` 신설 · `bb_density_test.dart` 삭제 ·
   `tile_contract_guard_test.dart` 문구 갱신 · `PILOT_FILES`·baseline 갱신.
6. 정본 문서(`domains/12-ui-scaling.md`) 개정 + 진행 대장 append.
7. 로컬 CI 5종 → PR → 머지 → 배포 → 라이브 검증 요청.

## 6. 사전 판정 기준 (사후 합리화 방지)

- **모바일이 답답하다**(320~400px) → `min` 을 내린다(레버 1개). 곡선·지수는 손대지 않는다.
- **웹이 허전하다** → `max` 를 내린다.
- **전 구간 비율이 어색하다** → 공간 폭지수 0.5 를 0.4/0.6 으로. **G2 가 깨지므로 승인 필요**.
- **자산 탭이 달라졌다** → G2 가 통과했다면 원인은 여백이 아니라 §2.5 이관 파일의
  페이지 크롬 리터럴 제거다(의도된 변화). 그때 되돌릴 대상은 해당 파일의 토큰 선택.
- **768~840px 에서만 어색하다** → G3 허용 오차 조정(계단↔곡선 성질).

## 7. 미해결 사항

- **모바일 실기기 체감** — 계산상 `padH` 10dp/`padV` 8dp 는 현행(10/8)과 동일해 320~390px 에서는
  **여백 변화가 없다**. 사용자가 기대하는 "조정"이 모바일 쪽이라면 §6 첫 레버(`min` 하향)가
  필요하다. **확인 주체: 사용자 라이브 검증**(개발 중 판정 불가).
- **테마 여백 슬롯의 회귀 표면** — `contentPadding`·`labelPadding` 은 전 화면 폼·칩에 닿는다.
  스윕은 오버플로만 잡고 "보기 좋음"은 못 잡는다. **확인 수단: 사용자 육안 + `build web` 후 라이브**.
- **`xs`/`xxl` 앵커 부재** — 승인 표면에 대응값이 없어 비례(0.625)로 추론했다. **확인 주체: 사용자**.
- **CI Flutter 스큐**(로컬 3.41.2 vs CI 3.47.0) — 신규 lint 가 CI 에서만 뜰 수 있다.
  실패 시 `gh run view <id> --log-failed` 부터.
- **`toggleSlot` 56→52** 로 웹 자산 타일의 토글 열이 4dp 좁아진다. 오버플로 위험은 없으나
  육안 확인 대상.

## 8. 범위 밖 (명시)

- BE·DB·`api-spec` 변경 **0건**.
- 나머지 리터럴 1,509건 일괄 이관(회차마다 ratchet 으로 하향).
- 하드코딩 색 이관(별도 대기열 5번) · 차트 색 체계(대기열 1번).
- 하네스 `filter_propagation` 게이트: 이 회차는 필터·API 체인을 건드리지 않아 **해당 없음**.

---

# 9. UI 불일치 전수 검수 (사용자 추가 지시, 2026-08-20) — 승인 범위 확장

> 요청 원문: "거래 추가 시 -1일 전, +1일 후 문구를 보면 왼쪽 여백이 더 길다. 위와 같이
> UI가 불일치하거나 문제 있는 부분 전수 검수 후 같이 진행"

## 9.1 지적 케이스 — 측정으로 확정 `[측정 2026-08-20]`

위젯 기하를 직접 렌더해 읽었다(`transaction_form_page.dart:2226~2252`, 폭 390):

```
[1일 전] btn=0.00..191.00  icon=57.30..73.30  text=81.30..133.70
         leftGap=57.30  rightGap=57.30  iconTextGap=8.00
```

- **버튼의 좌우 여백은 정확히 같다**(57.30 / 57.30). "여백이 비대칭"이라는 가설은 **기각**.
- 어긋난 것은 **라벨**이다: `*Button.icon` 은 `아이콘 + 간격 + 라벨` 을 **한 덩어리로 중앙
  정렬**한다. 그래서 라벨만 보면 `아이콘폭(16) + 간격(8) = 24dp` 만큼 오른쪽으로 밀린다.
  텍스트 기준 좌 81.30 / 우 57.30 — 사용자가 본 그대로다.
- 프레임워크 기본 거동이라 `padding` 조정으로는 해결되지 않는다(도메인 ★
  `reference_framework_owned_affordance` 와 같은 성질 — 경로를 더하지 말고 **구조를 바꾼다**).

## 9.2 전수 검수 도구 — `tool/audit_ui_consistency.py` (신설)

`check_ui_scaling.py` 는 "리터럴이 몇 개냐"를 센다. 이 도구는 **"같은 역할인데 값·구조가
갈렸냐"** 를 센다. 크기 체계가 갖춰져도 비대칭·중복 축은 따로 남기 때문이다.
**클래스별 래칫**(`tool/ui_consistency_baseline.json`)이라 늘면 `exit 1`.

## 9.3 검수 결과 `[측정 2026-08-20 — 기준선]`

```
클래스                                         건수   파일   이 회차 처리
A  폭 채우는 Button.icon — 라벨 off-center        2     1    전건 수정
B  좌우 비대칭 여백 (only/fromLTRB)              38    24    이관 파일 내 개별 판정
C  버튼 style padding 세로만 (수평 0)            22     9    전건 수정
D  국소 visualDensity override                  17     9    전건 제거(경쟁 경로)
E  ListTile 계열 — 타일 밀도 계약 밖             87    39    등록만(래칫)
F  하드코딩 색                                 474    83    등록만(대기열 5번)
G  화면이 MediaQuery 폭 직접 읽기                 2     1    정당(bb_scale 단독 소유)
H  같은 역할에 값 종류 수                        33     -    이관 파일 내 토큰화
```

`H` 세부 `[측정]` — **불일치의 직접 증거**:

- `BorderRadius.circular` **8종**(2·4·6·8·10·12·16·20) / 142곳
- `SizedBox(w/h)` **15종**(1·2·4·6·8·12·16·20·24·32·40·48·60·88·100) / 544곳
- `EdgeInsets.all` **9종**(1·4·8·10·12·16·20·24·32) / 149곳

토큰 사다리는 6종이다. 즉 같은 역할을 **2~3배 많은 값**으로 그리고 있었다.

`B` 판정 `[추론]` — 38건 중 다수는 **정당한 보정**이다(들여쓰기 `left:24`, 아바타 정렬
`left:52/72`, 후행 아이콘 보정 `right:16`). 일괄 대칭화는 오히려 정렬을 깨므로
**이관 파일 범위 내에서만 개별 판정**하고 나머지는 래칫으로 동결한다.

## 9.4 처방

- **A**: 공용 위젯 `lib/core/widgets/bb_step_buttons.dart` 신설 — 라벨을 **버튼 정중앙**에
  두고 아이콘은 **바깥쪽 끝**에 고정(`Stack` + `Align`), 두 버튼이 서로 **거울 대칭**.
  `*Button.icon` 을 폭 채우는 자리에 쓰지 못하게 **A 래칫이 0 을 고정**한다.
- **C**: 버튼 `padding` 은 `bbSpace.symmetric(h:, v:)` 로만 — 수평 0 금지.
- **D**: 국소 `VisualDensity` 전건 제거 → `AppTheme.responsive()` 의 **연속 밀도** 단일 소스.
  (§2.4 가 이미 그 통로를 만든다 — 이번 회차 구조 작업과 같은 지점이다.)
- **E·F**: 이 회차 범위 밖. 래칫 기준선으로 **동결**해 늘지 못하게 하고 대기열에 등록.
- **H**: 이관 7파일에서 토큰화 → 값 종류가 줄어드는 것으로 검증(래칫).

## 9.5 미해결 (검수 한계)

- 정적 스캔은 **문구 불일치·정렬 기준선·색 대비** 를 못 본다. 그건 라이브 육안 검증 몫이다.
  **확인 주체: 사용자.** 이번 배포 후 확인 항목으로 §라이브 검증에 싣는다.
- `E`(ListTile 87건)는 `reference_framework_owned_affordance` 성질이라 "경로 추가"로는
  안 끝난다 — 별도 회차에서 `EntityTileRow` 로 교체해야 한다. **미확인**: 교체 시 회귀 표면.
