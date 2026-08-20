# 세로 리듬 통일 — 기획서 (2026-08-21)

> 회차: 여백·간격 회차의 라이브 검증 후속(미종결분 1건).
> 근거 등급 표기 규칙은 `~/.claude/CLAUDE.md §1.15`. 이 문서의 수치는 전부 라벨을 붙였다.
> 하네스 게이트: `ui_pattern` 3회+ 재발 → **STRUCTURAL_FIX_REQUIRED**. §4 가 그 계획이다.

## 1. 사용자 요청 (원문, 2026-08-21 라이브 검증)

> 분석에서 자산현황 내 항목 간 위아래 여백과 자산 탭 내 위아래 여백이 다른데?
> 기준을 자산 탭으로 맞추고 자산도 조금 더 위아래 값들이 가까워질 수 있으면 가깝게 해서
> 전체 설정을 맞춰라

요구 2건: ① 분석>예산의 "자산 현황"을 **자산 탭 기준**에 맞춘다 ② 자산 탭 자체의 세로 리듬을
**한 단계 촘촘**하게 하고 그것을 전체 기준으로 전파한다.

## 2. 실측 — 진단 정정 `[측정 2026-08-21]`

진행 대장 §3 의 착수 실측은 "분석 타일 내부 상하 = 12 고정"이라고 적었으나 **틀렸다**(그 표는
`[추론: 토큰값 계산]` 라벨이었다). 코드를 직접 읽은 결과:

- 두 화면 **모두** 항목은 `EntityTileRow` 로 그려지고, 그 내부 세로 padding 은 양쪽 다
  `space.lg` 다(`entity_tile_row.dart:308`). 따라서 **인접 항목 간격은 양쪽 다 16.0dp @390** 로
  이미 같다.
- 벌어진 것은 **그룹 박스**다.
  - 자산 탭 = **평면 목록**. 그룹 헤더 `only(l:xl, t:lg, r:xl, b:xs)`
    (`asset_management_page.dart:1147`) · 항목은 `EntityTileRow` **직접**(Card·margin 없음, 1256) ·
    리스트 `only(top: md, bottom: 88)`(1056). **그룹 경계 = lg+lg+xs ≈ 19dp**
  - 분석>예산 자산현황(`showHeader:false`) = 외곽 `fromLTRB(12,16,12,8)`(78) → 제목 `bottom 8`(54)
    → 그룹마다 `Container(margin b:8, padding all(12), border, radius 10)`(101~104) → 헤더 Row
    (`Icon size 16` + `SizedBox(width:6)` + `fontSize 13`) → `SizedBox(height:6)` → 항목들.
    **그룹 경계 = 12+8+12 = 32dp**
  - 좌우도 어긋난다: 들여쓰기 12(외곽)+12(그룹박스)+xl(10.2) = **34.2dp** vs 자산 탭 **10.2dp**
- 호스트는 `budget_list_page.dart:593`·`665` 두 곳(둘 다 `showHeader:false`).
  `showHeader:true` 경로는 `dashboard_page.dart:89` = **미라우팅 죽은 화면**
  (`reference_dead_home_dashboard`) — 유지만 하고 검증 대상에서 뺀다.
- `account_balance_card.dart` 리터럴 **11건**, `PILOT_FILES` **미등재** `[측정]`.
- `check_ui_scaling.py` 패턴에 `indent:`/`endIndent:`/`Divider(height:` 가 없어
  `asset_management_page.dart:742` 의 `Divider(height: 1, indent: 16, endIndent: 16)` 이
  **세어지지 않는다** — 시범 파일이 "잔존 0"인데 고정 px 가 살아 있다 `[측정]`.

**결론**: 사용자가 본 차이는 타일이 아니라 **분석 쪽에만 있는 손수 작성 그룹 박스**다.

## 3. 결정

### ① 분석>예산 자산현황을 자산 탭 구조로 통일

- 그룹 테두리 `Container`(padding 12 / margin 8 / border / radius 10) **제거** → 자산 탭과 같은
  평면 목록. 그룹 구분은 자산 탭과 **같은 헤더**가 맡는다.
- 외곽·제목 여백을 자산 탭 리스트와 같은 토큰으로(`only(top: md)` 계열).
- 완료 기준은 "토큰을 썼다"가 아니라 **"자산 탭과 같은 토큰을 썼다"**.

### ② 세로 한 단계 촘촘 — `EntityTileRow` padV `lg` → `md`

- 함께: 그룹 헤더 `top: lg` → `md`(두 화면 공통 헤더이므로 1곳).
- **후보 ⓒ(`kBbSpaceSpec` 의 `lg` 하한 하향)를 버린 근거** `[측정]`: `lg` 는 세로가 아닌 자리에서
  12곳 쓰인다 — `radiusMd`(카드·입력·다이얼로그 반지름) · `dividerTheme.space` ·
  `tabBar.labelPadding` · `TextButton` 수평 padding · 필터바 수평 padding · 통계/거래 탭 여백.
  세로만 좁히라는 요청을 넘어서고, 승인 앵커(`lg` = tilePaddingV 8/12)를 무효화한다.
- 후보 ⓑ(타일 간 margin `md`→`sm`)는 **대상이 없다**: 자산 탭 결제수단 타일에는 margin 이 없다
  (포켓 타일에만 있다) `[측정]`.
- ⓐ 는 `EntityTileRow` **1곳** 수정으로 전 앱 타일에 퍼진다 = "전체 설정을 맞춰라".
  호스트 `[측정]`: 자산 탭 결제수단·포켓 · 카테고리 타일 · 분석 자산현황.
- **귀결** `[추론: 토큰 곡선 계산]` @390 — 인접 항목 16 → **12.8** · 그룹 경계 19 → **15.8** /
  @960 — 24 → **20** · 28 → **24**.
- 터치 하한: 아바타 있는 행 = 32 + 12.8 = **44.8dp** 유지. 아바타 없는 한 줄 행은 **이전에도**
  44 미만(사전 위반) — 이번 변경이 만든 위반이 아니다.

### ③ 검수 도구 공백 메움

- `check_ui_scaling.py` 패턴에 `indent:` · `endIndent:` · `Divider(height:` 추가.
- 검출되는 리터럴 토큰화(우선 `asset_management_page.dart:742`).
- **패턴 확장으로 총계가 오르므로 baseline 1회 재생성** — 상승은 의도이며 이 문서와 진행 대장에
  기록한다(기록 없는 상승은 ratchet 의 의미를 깬다).

## 4. 구조적 수정 계획 (하네스 게이트 필수 조항)

재발 패턴은 "경로를 **추가**했다"로 끝내는 것이다. 이번 근본 원인도 그 형태다 —
**같은 콘텐츠(자산 그룹 목록)를 그리는 손수 작성 구현이 2개** 있고, 한쪽만 토큰화돼 리듬이 갈렸다.
리터럴만 이관하면 다음 화면에서 또 갈린다.

1. **공유 위젯으로 경쟁 경로를 0개로 만든다** — `EntityGroupHeader` 신설
   (`lib/core/widgets/entity_group_header.dart`). 값 타입 API 봉인(`label`/`icon`/`color` 만 받고
   `padding`·`fontSize`·`Widget` 슬롯을 **노출하지 않는다**) → 호출부가 여백·폰트를 적을 경로
   자체가 없다. 자산 탭(1147)과 분석 자산현황이 **같은 위젯**을 지난다.
2. **세로 리듬 단일 소스** — 타일 내부 세로 padding 은 `EntityTileRow` 한 곳(`space.md`),
   그룹 경계는 `EntityGroupHeader` 한 곳. 화면이 자기 값을 갖지 않는다.
3. **소스 가드 3겹** (`test/core/widgets/`)
   - `EntityTileRow` 세로 padding == `space.md` 위젯 단정(320/390/960).
   - 두 호스트 파일에 **자체 헤더 조립 금지**: `Icon(... size:` / `fontSize:` 리터럴 부재 +
     `EntityGroupHeader` 참조 존재(문자열 스캔).
   - `PILOT_FILES` 에 `account_balance_card.dart` · `entity_group_header.dart` 등재 → 잔존 0 강제.
4. **승인값 표 갱신** — 스윕 `anchors` 의 `tilePaddingV` 를 **md(6/10)** 로 재배선하고 주석에
   2026-08-21 승인값과 이유를 적는다. 코드에서 읽지 않는다(순환 검증 금지).
5. **도달 경로 명시**(2026-08-10 인시던트 방지): 분석 탭 → 예산 → 목록 **맨 아래** "자산 현황"
   (`budget_list_page.dart:665`, 예산 0건이면 593) / 자산 탭 → 결제수단 목록
   (`asset_management_page.dart:1056~1256`). 배포 후 번들 검증은 escaped 한글 + `last-modified`
   + `verify-live` 3종(`reference_live_bundle_string_verification`).

## 5. 범위 밖 / 미해결 사항

- **분석>예산의 예산 항목은 `ListTile`** 이라 프레임워크가 높이(48+)를 소유한다 → 자산현황보다
  헐렁하게 남는다 `[측정]`. **사전 판정 기준**: 사용자가 "예산 항목과 자산현황이 다르다"고 하면
  다음 회차는 대기열 1번(`ListTile` 87건 → `EntityTileRow`)을 **분석>예산부터** 착수한다.
  지금 함께 하지 않는 이유는 39파일 규모라 이 회차를 삼키기 때문이다.
- 그룹 테두리 제거는 여백이 아니라 **시각적 변경**이다. 되돌리기 = `EntityGroupHeader` 호출부에
  테두리 옵션을 되살리는 대신 **분석 쪽 `Container` decoration 블록 복원**(한 곳).
- 라이브 검증 잔여 항목(±1일 버튼 · 폼/카드 여백 · 토글 열 · 320px 편집 모드)은 반증 보고가
  없었을 뿐 개별 확인은 미완 — 이번 배포 때 함께 확인 요청한다.
- BE·DB·`api-spec` 변경 **0건**(FE 표현 계층 전용).

## 6. 게이트 (승인 후 자동 진행)

로컬 CI 6종: `flutter analyze --no-fatal-infos --no-congratulate`(전체 경로) ·
`flutter test` · `./gradlew test` · `flutter build web --release` ·
`python3 tool/check_ui_scaling.py` · `python3 tool/audit_ui_consistency.py`
→ 전부 통과 후에만 커밋·PR·머지·배포(개인 계정 자동 진행 범위) → 라이브 검증 요청.
