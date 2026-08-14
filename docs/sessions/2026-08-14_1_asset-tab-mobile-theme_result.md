# 자산 탭 모바일 가독성 + 브랜드 틸 색상 체계 개편 — 결과

- 회차: 2026-08-13 착수 → **2026-08-14 사용자 라이브 검증 통과 = 완료**
- 기획서: `docs/sessions/2026-08-13_1_asset-tab-mobile-theme_plan.md`
- PR: **#298** (squash, `main` = `9af3c85`)
- 하네스 태그: `ui_pattern` (STRUCTURAL_FIX_REQUIRED → S1~S7 구현으로 해제)

---

## 1. 사용자 판정

> "색상도 깔끔하고 수정된거 잘 된다."

A / B / C / D 전 시나리오 통과. **완료.**

---

## 2. 근본 원인 (측정)

### 2.1 왜 모바일에서 안 보였나

360dp 폭에서 결제수단 한 행의 **고정 크롬 236dp**, 콘텐츠 잔여 **124dp**:

- 순서 변경 핸들 40 (타일 **밖** Row)
- `ListTile` 좌우 contentPadding 32 + leading 40 + horizontalTitleGap 16
- trailing Switch **52** + PopupMenu 40 + 간격 16

**핵심 오진 정정**: 2026-05-04 의 `Transform.scale(0.85)` "컴팩트화" 는
**레이아웃 폭을 1dp 도 줄이지 않았다**. `Transform` 은 페인트만 스케일하는 프록시
박스라 부모 Row 는 여전히 52dp 를 예약한다. 시각적으로만 작아 보였고 폭 압박은 그대로였다.

### 2.2 왜 다크모드가 어긋났나

씨드 색 문제가 아니었다. 화면 색 대부분이 raw `Colors.*` 하드코딩이고,
의미 토큰 `AppColors.income/expense/budget/savings` 는 **참조 0건** — 선언만 있고
화면에 연결된 적이 없었다. **씨드만 바꿔서는 고쳐지지 않는다.**

---

## 3. 만든 것

- `core/theme/bb_colors.dart` — 브랜드 틸 `#0F766E`(다크 `#5ED3C4`), 의미 토큰 7종을
  `color·container·onContainer` 삼중쌍으로 라이트·다크 모두 정의.
  `readable()`(사용자 색 HSL 명도 클램프) · WCAG 명도비/색상거리 계산 포함
- `core/theme/bb_density.dart` — compact(<400dp)/regular/wide(≥840dp).
  **`MediaQuery.sizeOf` 를 읽는 앱 내 유일한 지점**
- `core/widgets/one_line_label.dart` — String 봉인 API. TextPainter 이진탐색 4회 +
  프레임 메모이즈. **금액 축약 없음**
- `core/widgets/entity_tile_row.dart` — `ListTile` 을 쓰지 않고 폭 계약을 직접 소유
- `core/widgets/asset_edit_mode_scope.dart` — InheritedNotifier
- `tool/hardcoded_color_scan.dart` / `tool/listtile_ink_scan.dart` — 가드용 스캐너

이관: 자산 탭 3탭 + 상단 헤더 3카드 + `CategoryListTile` + `account_balance_card`.
`_SubChip` 은 타일 메트릭에 흡수돼 삭제.

---

## 4. 측정이 결정을 바꾼 지점

1. **수입 블루** `#2196F3` 은 틸과 hue **31.3°** 차로 사전 기준(40°) 미달 → **`#2563EB`**(45.9°)
2. **지출 레드**: 후보 `#E11D48` 이 **M3 라이트 surface 가 순백이 아니라서** 명도비
   **4.47:1** → WCAG 테스트가 반려 → **`#D11440`** 재선정.
   색을 눈이 아니라 테스트가 골랐다
3. **금액 vs 이름 충돌**: 320dp·textScale 1.3 에서는 둘을 한 줄에 못 넣는다 →
   타일이 폭을 먼저 재고, 안 들어가면 **금액을 아래 칩 줄로 내린다**.
   이름을 자르지도 금액을 축약하지도 않는 유일한 해법
4. **공통 범위**: `paymentMethodTypeColor` 가 자산 탭 외 **8개 파일**에서도 쓰이고 있었다
   → 헬퍼 자체를 `context.bb.paymentType` 위임으로 바꾸고 호출부 일괄 수정
5. **`EntityViewAction`**: 분석>예산 카드엔 편집 모드가 없어서, 편집 전용 액션으로
   넣었으면 "잔액 수정" 기능이 **사라질 뻔했다** → 봉인 값 타입 슬롯 1개 추가

---

## 5. 인시던트 1건 — CI 만 실패한 ListTile 잉크 결함

- **증상**: 로컬 `flutter test` 1034건 통과, 원격 frontend-ci 1031 pass / **3 fail**
- **원인**: Flutter SDK 스큐. 로컬 **3.41.2**(2026-02 리비전), CI 는 `channel: stable`
  을 실행 시점에 해석 → 더 최신. 최신에만 있는 프레임워크 assert 가 터졌다:
  **"ListTile background color or ink splashes may be invisible"**
- **진짜 결함이었다(테스트 문제 아님)**: `ListTile` 은 **가장 가까운 Material 조상** 위에
  배경·잉크를 그리는데 중간에 색칠된 `Container` 가 있으면 그 뒤에 깔린다.
  이번에 추가한 폼 위젯 테스트가 **그 화면을 처음 렌더**하면서 잠복 결함이 드러난 것
- **전수 조사 후 2건 일괄 수정**: `transaction_form_page` 메모 카드 /
  `category_group_selector_sheet` "잔액 조정" 항목 →
  `Material(type: MaterialType.transparency)` 로 감쌈
- **재발 방지**: `listtile_ink_guard_test.dart` — **설치된 SDK 와 무관하게 소스에서** 잡는다.
  SDK 스큐로 다시 새는 것을 막는 유일한 방법. 역방향 확인 완료

---

## 6. 구조적 강제 (S1~S7) — 전부 구현·통과

- **S1** 타일 API 값 타입 봉인 (`title: String`, Widget 필드 0건, ListTile 사용 0건)
- **S2** 하드코딩 색 **래칫** — baseline **313건/73파일**(스크립트 생성).
  늘면 실패 / 신규 파일 0 / 이관 10파일 0 / **baseline 인플레도 실패**.
  역방향 확인 완료
- **S3** 대상 파일 `ListTile` 0건 · `MediaQuery...width` 직접 사용 0건
- **S4** **32조합 매트릭스**(320·360·390·768dp × light·dark × 1.0·1.3배 × 보기·편집).
  최악 조건(320dp·1.3배·다크·편집)을 반드시 포함
- **S5** WCAG 명도비 자동 측정 — 토큰 전수 × 라이트·다크. 미달 토큰 채택 불가
- **S6** `parseColor` 결과는 반드시 `readable()` 통과
- **S7** 저장&계속 offset 0 + 금액 포커스, 지출·수입 각각
  (이 페이지의 **첫 위젯 테스트**)

추가 가드: ListTile 잉크 스캐너(§5).

---

## 7. 게이트 결과

- `flutter analyze`(전체) — 신규 지적 **0건**
- `flutter test` — **1036건 통과**
- `flutter build web --release` / `./gradlew test` / `./gradlew build` — 통과
- **BE·DB·`docs/api-spec.md` 변경 0건**
- 배포 후 `verify-cache-headers.sh` 통과(아이콘 폰트 content hash 포함)

---

## 8. 측정 한계 — 색은 서버에서 판정할 수 없다

번들에서 색 상수를 grep 으로 확인하려고 10진수·16진수·정규화 double 성분 등
**4가지 표기를 모두** 시도했으나, **대조군인 구 브랜드 그린(`#4CAF50`)도 똑같이 0건**이었다.
→ 프로브가 무효인 것이지 색이 빠진 게 아니다.

**색상 반영 여부는 서버 측 검증으로 판정 불가. 사용자 눈이 유일한 판정 수단이다.**
문자열(`편집` 등 신규 한글, `\uXXXX` 이스케이프 대조)과 `last-modified` 로
"새 번들인지" 까지만 서버가 말해 줄 수 있다.

---

## 9. 이 회차에서 나온 후속 (다음 회차 후보)

1. **분석 탭 UI/UX 전체 개편** — 사용자 요청(2026-08-14). 상단 예산/통계 · 월말 점검 ·
   월간/주간 버튼 · 이번달 예산 영역이 너무 크게 잡아서 **실제 데이터 노출 영역이 극히 작다**
2. **자산 탭 카드 항목 2줄화** — 사용자 요청(2026-08-14). 카드는 잔액이 없으므로
   **잔액 자리에 마감일·결제일**을 넣어 2줄로 끝낸다
3. 차트 색 체계 통일 — `BbColors` 에 `series` 토큰을 얹는다.
   차트는 수입을 그린, 장부는 수입을 블루로 그리는 불일치가 남아 있다
4. 나머지 하드코딩 색 이관 — 래칫 baseline 을 회차마다 낮춘다
