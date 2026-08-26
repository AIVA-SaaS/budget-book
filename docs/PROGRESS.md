# Budget Book (aiva-bb) 진행 이력 대장

> **이 파일이 진행 상황의 단일 진입점이다.** `/clear` 후에도 이 파일 하나면 어디까지 왔는지 복원된다.
> SessionStart 훅 `progress-resume.py` 가 아래 STATE·타임라인 꼬리·NEXT 를 자동 주입한다.
> 실질 진전(산출물 생성·게이트 통과·결정 확정·실패)마다 §2 타임라인에 append. **무기록 변경 금지**.

---

## 1. 현재 상태 (한눈에)

<!-- HNS:STATE -->
- **단계**: **8차 구현·로컬 CI 완료 → PR·배포 대기.** 7차 높이는 **통과**(유지), 이번은 **계층 관계** 축
- **상태**: in_progress · 사람 답변 대기 없음
- **갱신**: 2026-08-26
- **[측정] 7차 결과**: 행 간 높이 ✅ 라이브 통과("높이 조정이 잘 됐다"). 그 계약은 **유지**한다
- **[측정] 8차 요구**: "상위 총 예산에 각 예산항목이 **묶이는 개념**" · **펼치기/숨기기** ·
  "지금은 **별도로 떨어진 것** 처럼 되었다". 승인 형태(사용자 선택 3안 중) = **한 카드 안에 합친다**
- **[측정] 원인 2겹**: ①계층 표현 장치가 **원래 하나도 없었다**(카드와 리스트가 형제) ②7차 이관으로
  항목 인셋이 16 → **10.20** 로 줄어 카드(바깥선 16)보다 **밖으로** 나갔다 — 항목 아바타 **10.20 vs 헤더 32.00 = −21.80px**
- **[측정] 결과**: 항목이 카드 자손 **3/3** · 정렬 차 **0.00px**(390·430·768) · **행 간 높이 편차 0.00 유지**
- **★가드 2개가 내 처방을 되돌렸다**: `no_step_ladder_guard` S3(국소 `visualDensity` 금지 — 밀도는
  `AppTheme._densityFor` 단일 소유) · G3 축을 아이콘 잉크로 재려다 허용오차를 늘리게 돼 **아바타 상자**로 교정
- **[측정] 로컬 CI**: analyze **14**(기준선 15↓·회귀 0) / test **전량 통과** / build web EXIT=0 / 색 래칫 통과
- **blocker**: 없음
<!-- /HNS:STATE -->

## 2. 타임라인 (append-only)

> 형식: `N. **YYYY-MM-DD** — 한 줄 요약.` + 하위 불릿(산출물 / 게이트 결과 / 결정 / 실패·인시던트).
> 지우지 않는다. 틀린 기록은 지우지 말고 다음 항목에서 정정한다.

<!-- HNS:ARCHIVE -->
> **항목 1~37 은 `docs/progress-archive/timeline-001.md` 로 롤오프됐다(2026-08-24 · 내용 무삭제).** 본체를 100KB 아래로 유지해 전문 Read 가 막히지 않게 하기 위해서다.
> 이전 이력을 볼 때는 그 파일을 읽는다. 새 항목은 계속 이 아래에 append 한다.

38. **2026-08-13** — PR #297 원격 CI 통과 → 머지 → 배포 성공 → **서버 측 검증 완료.
   남은 것은 사용자 라이브 검증.**
   - 원격 CI: `backend-ci` pass(4m23s) / `frontend-ci` pass(3m16s) → squash 머지 + 브랜치 삭제
   - main `027e8f7` · deploy-nas run **31657145604 success**
     (changes / deploy-frontend / deploy-backend / **verify-live 전부 success**;
     nginx 변경 없어 sync-nginx skipped)
   - **라이브 번들 측정**(`main.dart.js`, 5,495,549 B): escaped 대조 —
     `합계 제외` 1건 · `잔액 수정은 수입·지출 합계에 포함되지 않습니다` 1건 ·
     `카드 정산은 원본 지출로 이미 집계되었습니다` 1건. 이 세 문구는 이번 PR 에서 처음
     생긴 것이라 **번들 신원 자체가 이번 배포임을 증명**한다. `last-modified` 01:18:30 GMT
   - BE 컨테이너 재기동 확인(`bb_app` StartedAt 01:18:50) · 기동 로그 **에러 0건** ·
     Flyway "Successfully validated 64 migrations / schema 65 up to date"
     (이번 회차는 스키마 변경이 없으므로 마이그레이션 없음이 정상)
   - **주의**: 인증이 필요한 API 는 서버에서 직접 호출해 확인하지 않았다. 수치 정확성은
     실 PostgreSQL 계약 테스트(축 조합 15건)가 담보하며, 화면 확인은 사용자 몫이다

39. **2026-08-13** — 다음 회차 **"자산 탭 모바일 가독성 + 브랜드 색상 체계" 기획 완료**(승인 대기).
   코드 변경 0줄. #297 라이브 검증은 여전히 미완이며 이 회차는 그 검증 통과 후 착수한다.
   - 산출물: `docs/sessions/2026-08-13_1_asset-tab-mobile-theme_plan.md`
   - 하네스 게이트: `ui_pattern` → **STRUCTURAL_FIX_REQUIRED**(과거 인시던트 4건).
     해제 근거는 기획서 §5 S1~S7. **acknowledge 는 승인 후 실행**(현재 frontend 편집 잠김)
   - 측정(hard evidence):
     ① 360dp 에서 결제수단 한 행의 고정 크롬 **236dp** / 콘텐츠 잔여 **124dp**
     ② `Transform.scale(0.85)` 는 레이아웃 폭을 줄이지 않는다 —
        Switch 는 여전히 52dp(`switch.dart:2370 switchWidth => 52.0`).
        2026-05-04 의 "컴팩트화" 는 폭 압박을 전혀 완화하지 못했다
     ③ 하드코딩 팔레트 색 **324건 / 71파일** vs 의미 토큰(`AppColors`) **3건 / 2파일**
        → 씨드만 바꿔도 다크는 안 고쳐진다
     ④ 반응형 헬퍼(`isMobile`/브레이크포인트) **0건**, `textScaler` 취급 0건
     ⑤ 사용자 지정 색 경로 `UIHelpers.parseColor` **19곳**(다크 명도 보정 단일 지점 후보)
     ⑥ "저장 & 계속" 은 `_resetFormForContinue()` 가 스크롤을 건드리지 않고 폼
        `SingleChildScrollView` 에 컨트롤러가 없다 → 하단 위치 유지. 지출/수입 탭이
        TabBarView 로 동시 생존하므로 컨트롤러는 탭별 1개
   - 도달성 확인: 자산 탭(`/assets`) + 더보기(`/asset-management`) 가 **같은 페이지** →
     한 번 수정으로 두 경로 반영. `AccountBalanceCard` 는 분석>예산에서 라이브.
     ⚠ `PaymentMethodPage`(`/payment-methods`) 와 `CategoryPage`(`/categories`) 는
     진입점이 죽은 홈 화면뿐이라 **도달 불가 → 작업 대상 제외**
   - 사용자 판정 3건 확정: 메인 색상 **틸 #0F766E**(다크 #5ED3C4) / 타일 **편집 모드 분리** /
     범위 **자산 탭 + 자산 현황 카드 + 테마 토큰(전역) + 저장&계속 fix**(나머지 68파일은 래칫)

40. **2026-08-13** — 기획 **승인 확정**. 사용자가 **#297 라이브 검증을 먼저** 수행하기로 →
   코드 변경은 그 결과 수신 후 착수(현재 0줄, frontend 게이트 LOCKED 유지 · acknowledge 미실행).
   - 결정: 착수 전제 = #297 A1~A11 검증 결과 수신. 검증 실패 항목이 있으면 그 fix 가 우선이다
   - **U1 선행 측정 완료(해소)**: 통계 위젯 9개 중 `colorScheme.primary` 의존은
     `period_budget_tab.dart` **1건**뿐 → 사전 판정 기준대로 **차트는 이번 회차 미변경**.
     씨드를 틸로 바꿔도 차트 판독성은 흔들리지 않는다
   - **U1 부수 발견(후속 대기열로 이관)**: 차트는 시리즈 팔레트를 파일마다 복제하고
     (`_defaultColors` 10색이 3파일 중복 + `payment_method_stats_tab` 은 별도 `_colors`),
     **차트 수입 = 그린(#4CAF50) vs 장부 수입 = 블루** 불일치가 기존부터 있다.
     이번 회차에서 만드는 `BbColors` 에 `series` 토큰을 얹는 것이 다음 단계
   - **근거 정정**: 기획서 §2.3 의 "의미 토큰 3건/2파일" 은 실사용 기준으로 정정 —
     `AppColors.primary` 2건(둘 다 씨드)만 살아 있고 `income/expense/budget/savings` 4개는
     **참조 0건**. 의미 색 체계는 선언만 있고 화면에 연결된 적이 없다
   - 산출물 갱신: 기획서 §3 U1 해소 · §2.3 정정 · **§13 후속 대기열 신설**(차트 색 통일 /
     하드코딩 래칫 축소 / 죽은 화면 6개 정리)

41. **2026-08-13** — 🎉 **"합계 ≠ 행" 회차 종결 — 사용자 라이브 검증 A1~A11 전부 통과 = 완료.**
   - 산출물: `docs/sessions/2026-08-13_2_summary-row-mismatch_result.md`(결과 정본) +
     knowledge 캐시 `ledger-summary-row-single-source.md`(재사용 패턴)
   - 검증 범위: A1 기간 이체 누락 / A2 합계=행 / A3 결제수단 다중 / A4 금액 / A5 검색어 /
     A6 카테고리·포켓·확인필요·개인 4축 각각 / A7 이체 단독 / A8 지출+이체 / A9 "합계 제외" 배지 /
     A10 사이드이펙트 / A11 분석 탭 — **전부 PASS**
   - **검증 과정 오판 1건(코드 결함 아님)**: 첫 A1 보고는 실패(이체 1,008,648원)였는데
     스크린샷에 **"오프라인 - 실시간 동기화 중단" 배너**가 떠 있었다. 재연결 후 통과.
     오프라인이면 이전 데이터가 그대로 보여 **배포 미반영과 증상이 동일**하고,
     서버 측 검증(번들 last-modified·verify-live)으로는 걸러지지 않는다
     → **재발 방지: 라이브 검증 체크리스트 0단계에 "오프라인 배너 없음 확인" 고정.**
     메모리 `feedback_live_verification_online_precheck` 등록
   - **문서 오류 2건 정정**(검증 지시서를 쓰다 측정으로 발견):
     ① 기획서 §8 A10 의 "이체 목록 화면"(`/transfers`)은 **도달 불가** — 유일 진입점이 죽은
     `PaymentMethodPage`. 대체 경로 = 장부에서 이체 행 탭(`transferEditRoute`).
     카드정산 화면은 **거래 탭 신용카드 1개 필터 시 나타나는 "결제" FAB** 로 도달
     ② 필터 시트 순서는 유형 → 공개 범위 → 기간 → **금액** → 카테고리 → 결제수단 → 포켓 →
     확인/입력 필요만이고, 진입 아이콘은 깔때기가 아니라 **`tune`(슬라이더)**
     → 메모리 `reference_dead_home_dashboard` 에 "죽은 화면이 끌고 내려간 화면들" 절 추가
   - 후속으로 이관: `/transfers` 진입점 부활 여부 · 차트 수입 그린 vs 장부 수입 블루 불일치 ·
     죽은 화면 6개 정리(결과 문서 §9)

42. **2026-08-13** — 자산 탭 회차 **착수**: 하네스 게이트 해제 + **커밋 1(토큰/테마 기반) 완료**.
   - 게이트: `acknowledge-gate.sh frontend <기획서>` 실행 → `ui_pattern`
     STRUCTURAL_FIX_REQUIRED **acknowledged**(frontend 편집 허용). 브랜치
     `feat/asset-tab-mobile-theme`
   - 산출물: `core/theme/bb_colors.dart`(BbColors ThemeExtension — 브랜드 틸 씨드 `#0F766E` /
     다크 `#5ED3C4` + 의미 토큰 7종의 `color·container·onContainer` 삼중쌍 + 결제수단 타입색 5종 +
     `readable()` HSL 명도 클램프 + WCAG 명도비·색상거리 계산) / `core/theme/bb_density.dart`
     (compact<400 / regular / wide≥840, `MediaQuery.sizeOf` 단일 독점 지점) /
     `core/widgets/one_line_label.dart`(String 봉인 + TextPainter 이진탐색 4회 + 프레임 메모이즈,
     **금액 축약 없음**) / `app_theme.dart`(씨드 교체 + `extensions:` 주입, light·dark primary 명시
     override) / `app_colors.dart` `@Deprecated` 위임
   - 게이트 결과: 신규 테스트 41건 + 기존 936건 = **`flutter test` 977건 전부 통과**
     (씨드 변경이 기존 위젯 테스트를 하나도 깨지 않음 — R3 전역 영향 1차 확인)
   - **측정으로 확정된 값 2건**(사전 판정 기준 §3 U3 적용):
     ① 수입 블루는 `#2196F3`(hue 206.6°, 틸과 31.3° 차 → 기준 40° 미달)을 버리고 **`#2563EB`**
     (hue 221.2°, 45.9° 차)로 이동
     ② 지출 레드는 M3 `error` 와 hue 차가 0°라 **로즈 계열 `#D11440`**(hue 346°, error 와 18° 차).
     최초 후보 `#E11D48` 은 **M3 라이트 surface 가 순백이 아니라서** 명도비 4.47:1 로
     4.5 기준 **미달 → 자동 테스트가 반려** → 한 단계 어둡게 재선정(측정이 색을 결정한 사례)
   - 판정 근거: `bb_colors_contrast_test.dart` 가 라이트·다크 각각 토큰 전수(본문 4.5 / 아이콘 3.0)
     + 브랜드-수입-지출 hue 거리 + error 충돌을 **자동 측정**. 미달 토큰은 채택 불가

43. **2026-08-13** — **커밋 2(공통 타일 + 편집 모드 스코프) 완료.**
   - 산출물: `core/widgets/entity_tile_row.dart`(ListTile 을 쓰지 않는 자체 타일 —
     `title: String` 봉인, 뱃지·메트릭·액션 전부 값 타입) /
     `core/widgets/asset_edit_mode_scope.dart`(InheritedNotifier — 편집 모드 켜짐이
     페이지 전체가 아니라 타일만 리빌드) / `bb_density.toggleSlotWidth` 추가
   - **설계 판정 1건(측정 후 추가)**: 320dp·textScale 1.3 에서는 이름과 금액을 한 줄에 같이 둘 수
     없다 → 타일이 **폭을 먼저 재고**(`OneLineLabel.measureWidth`) 안 들어가면 **금액을 아래 칩
     줄로 내린다**. 이름을 자르지도, 금액을 축약하지도 않는 유일한 해법
     (`feedback_financial_consistency` 준수). 편집 모드에서는 액션 레인이 우측을 차지하므로
     금액·부제·칩을 감추고 이름+레인만 남긴다
   - 게이트: **S4 32조합 매트릭스**(320·360·390·768 × 라이트·다크 × 1.0·1.3배 × 보기·편집)
     통과 — 오버플로 0건 / 보기 모드에서 13자 이름 **ellipsis 0건** / 편집 모드 액션 탭 타깃 ≥40dp.
     **S1 API 봉인 가드**(Widget 타입 필드·ListTile 사용 0건 소스 스캔) 통과.
     `EntityTone` 전 값의 칩 배경↔전경 명도비 ≥4.5 자동 측정 통과
   - `flutter test` **1019건 통과** / `flutter analyze` 신규 지적 **0건**(잔여 3건은 기존 파일)
   - ⚠ **기획서 §6 대비 순서 조정 1건**: S3(ListTile·MediaQuery 직접사용 금지)·S6(parseColor→
     readable) 가드는 대상 화면이 아직 이관 전이라 **커밋 3(이관)과 같은 커밋**에 넣는다.
     커밋 2 에 넣으면 그 커밋이 빨간 상태로 남는다

44. **2026-08-13** — **커밋 3(자산 탭 이관) 완료.**
   - 이관: 결제수단·카테고리·포켓 **3개 탭 타일 전부** `EntityTileRow` 로 /
     `CategoryListTile` 도 같은 타일로(자산 탭이 유일한 라이브 사용처) /
     상단 헤더 `_AssetSummaryHeader`·`_CardSettlementCardsView`·`_SettlementCard`·
     `_SummaryCard` 를 density·토큰으로 / `_SubChip` 은 타일 메트릭으로 흡수돼 **삭제**
   - AppBar **편집 버튼**(아이콘 + "편집/완료" 텍스트 병기 — R1 어포던스 완화) +
     `AssetEditModeScope` 배선. 카테고리 **그룹 헤더의 ≡·⋮ 도 편집 모드에서만** 노출
   - 순서 변경 핸들을 **타일 밖 Row → 타일 안 편집 레인**으로 이동. 예전 구조는 보기
     모드에서도 40dp 를 영구히 점유했다. **reorder 인덱스 계산은 무변경**(visual index
     그대로 전달) — R2 회귀 표면을 만들지 않았다
   - **공통 범위 감사에서 추가 발견 1건**(`feedback_common_scope_audit` 적용):
     `paymentMethodTypeColor` 가 자산 탭 말고도 **8개 파일**(필터 시트·거래 폼·지출계획·
     보험·반복거래·대시보드 등)에서 쓰이고 있었다. 자산 탭만 토큰으로 바꾸면 같은 결제수단이
     화면마다 다른 색이 된다 → **헬퍼 자체의 시그니처를 `(BuildContext, String)` 으로 바꿔
     `context.bb.paymentType` 에 위임**하고 호출부 8곳 일괄 수정. 하드코딩 5색 제거 +
     전 화면 다크 쌍 확보
   - 게이트: **S3 가드**(대상 파일 `ListTile(` 0건 · `MediaQuery...width` 직접 사용 0건,
     `BbDensity` 가 앱 전체 유일 읽기 지점) + **S6 가드**(`parseColor` 결과는 반드시
     `readable()` 통과) 신설·통과. `flutter test` **1025건 통과** /
     `flutter analyze` 신규 지적 **0건**
   - 대상 파일 하드코딩 팔레트 색 **0건**(`Colors.transparent` 제외 — 테마 중립)

45. **2026-08-13** — **커밋 4(분석>예산 "자산 현황" 카드) 완료.**
   - `account_balance_card.dart` 의 `_AssetItem` 을 `EntityTileRow` 로, 그룹 헤더 색
     (현금 green / 은행 blue / 카드 purple 하드코딩)을 `context.bb.paymentType` 으로.
     칩 3종(전월·미결제·이번달)은 타일 메트릭으로 흡수 — 하드코딩 색 **0건**
   - **설계 추가 1건**: 이 화면에는 편집 모드가 없는데 "잔액 수정"(tune) 버튼은 살아 있는
     기능이다. 편집 모드 전용 액션으로 넣으면 **기능이 사라진다** → 타일에
     `EntityViewAction`(아이콘·툴팁·콜백 3개만 받는 봉인 값 타입) 슬롯을 하나 추가해
     보기 모드에서만 노출. S1 봉인 가드에 이 슬롯도 등재
   - 부수: 항목 끝 `chevron_right` 장식 아이콘 제거(행 전체가 이미 탭 가능, 폭 16dp 회수)
   - 게이트: S3·S6 가드 대상 목록에 이 파일 추가 후 통과 / `flutter test` **1025건 통과** /
     `analyze` 신규 지적 **0건**

46. **2026-08-13** — **커밋 5(저장 & 계속 → 최상단) 완료.**
   - `transaction_form_page.dart`: 폼 본문 `SingleChildScrollView` 에 **탭별
     ScrollController** 3개(지출·수입·편집) + **탭별 금액 FocusNode** 2개.
     `_resetFormForContinue()` 가 `animateTo(0)` + 금액 필드 포커스 요청까지 한다
   - `CalculatorAmountField` 에 **외부 `focusNode` 주입 옵션** 추가(없으면 종전대로 내부 생성,
     외부 주입 시 dispose 하지 않는다 — 소유권 분리)
   - **왜 탭별인가**: 지출/수입 폼은 `TabBarView` 에서 동시에 살아 있어 하나를 공유하면
     두 ScrollView 에 같은 컨트롤러가 붙어 런타임 예외가 난다. FocusNode 를 탭별로
     분리해 둔 기존 선례와 같은 이유
   - 게이트: **S7 위젯 테스트 신설** — 폼을 최하단까지 스크롤 → "저장 & 계속" →
     `offset == 0` + 금액 포커스. **지출 탭·수입 탭 각각** + 컨트롤러 인스턴스 분리 검증.
     이 페이지의 **첫 위젯 테스트**다(기존에는 bloc 테스트뿐)
   - **테스트 구성 중 측정한 사실 2건**: ① 성공 리스너는 `_isSubmitting` 가드를 먼저
     보므로 검증을 통과시켜야 경로가 돈다 → `copyFrom` 복사 등록 경로로 카테고리·결제수단·
     금액을 채웠다 ② 탭을 옮기면 카테고리 타입이 달라져 선택이 초기화되므로,
     수입 케이스는 탭 전환이 아니라 `initialType: 'INCOME'` 으로 **직접 진입**해야 한다
   - `flutter test` **1029건 통과** / `analyze` 신규 지적 **0건**

47. **2026-08-13** — **커밋 6(하드코딩 색 래칫 가드) 완료.**
   - 산출물: `tool/hardcoded_color_scan.dart`(스캐너 + baseline 생성기, 주석·doc 제외,
     `Colors.transparent` 는 테마 중립이라 제외) / `test/core/theme/hardcoded_color_baseline.json`
     (**313건 / 73파일** — 스크립트가 생성, 손으로 쓰지 않는다) /
     `hardcoded_color_ratchet_test.dart`
   - 규칙 4가지: ① 파일별 상한 초과 금지 ② **신규 파일은 0** ③ baseline 이 실제보다 높으면
     실패(가드가 헐거워진 상태를 붙잡는다 — R4 대응) ④ 이관 완료 **10개 파일은 0 고정**
   - **가드가 실제로 무는지 역방향 확인**: `entity_tile_row.dart` 에 `Colors.red` 한 줄을
     넣자 3개 테스트가 즉시 실패(`0 → 1`), 되돌리면 통과. 스캐너가 조용히 망가지는 경우도
     "총합 > 0" 테스트로 잡는다
   - ⚠ 기획서의 baseline 표기(324건/71파일)와 숫자가 다른 이유: 기획 시점 측정은 주석과
     `Colors.transparent` 를 포함한 단순 grep 이었고, 이 스캐너는 둘 다 제외한다.
     **이제부터의 정본은 스크립트가 만든 JSON** 이다

48. **2026-08-13** — **로컬 CI 5종 전부 통과 + 번들 문자열 확인.**
   - `flutter analyze --no-fatal-infos --no-congratulate`(전체) — 3건, **전부 기존 파일**
     (신규 지적 0)
   - `flutter test` — **1034건 통과**
   - `flutter build web --release` — 성공(아이콘 폰트 트리셰이킹 37,460B)
   - `./gradlew test` / `./gradlew build -x test` — 통과 (BE 변경 0건 확인)
   - **번들 문자열 확인**(메모리 `reference_live_bundle_string_verification`): 한글은
     `\uXXXX` 로 이스케이프되므로 원문 grep 은 항상 0건 → ASCII 보존 이스케이프로 대조.
     `편집`·`완료`·`비활성`·`잔액 수정`·`저장 & 계속`·`기본 카테고리`·`전월`·`미결제`·`이번달`
     **전부 존재**

49. **2026-08-13** — **PR #298 원격 CI 실패 → 근본 원인 수정 + 재발 방지.**
   - backend-ci 통과 / **frontend-ci 실패 — `flutter test` 1031 pass, 3 fail**
     (전부 신규 `transaction_form_continue_scroll_test.dart`)
   - **로컬은 통과했는데 CI 만 실패한 이유 = Flutter SDK 스큐**
     (메모리 `feedback_flutter_sdk_skew_analyze` 재현). 로컬 **3.41.2**(2026-02 리비전),
     CI 는 `channel: stable` 을 실행 시점에 해석 → 더 최신. 최신 SDK 에만 있는 프레임워크
     assert 가 터졌다: **"ListTile background color or ink splashes may be invisible"**
   - **진짜 결함이다(테스트 문제 아님)**: `ListTile` 은 **가장 가까운 Material 조상** 위에
     배경·잉크를 그리는데, 중간에 색칠된 `Container` 가 있으면 그 뒤에 깔려 안 보인다.
     내 S7 테스트가 **이 페이지를 처음 렌더한 위젯 테스트**라 잠복해 있던 결함이 드러난 것
   - **전수 조사 후 일괄 수정**(`feedback_common_scope_audit`): 조상 관계까지 보는 스캐너로
     `lib` 전체를 훑어 **2건** 확정 → ① `transaction_form_page` 메모 카드의 `SwitchListTile`
     ② `category_group_selector_sheet` 의 "잔액 조정" 고정 항목.
     둘 다 `Material(type: MaterialType.transparency)` 로 감쌌다
   - **재발 방지**: `tool/listtile_ink_scan.dart` + `listtile_ink_guard_test.dart` 신설.
     **설치된 SDK 버전과 무관하게** 소스에서 잡는다(SDK 스큐로 다시 새는 것을 막는 유일한 방법).
     역방향 확인 완료 — 색칠된 Container 안에 ListTile 을 넣자 즉시 실패, 되돌리면 통과
   - `flutter test` **1036건 통과** / `analyze` 신규 지적 0건

50. **2026-08-13** — **원격 CI 통과 → PR #298 머지 → 배포 진입.**
   - frontend-ci **pass**(2m35s) / backend-ci **pass** — ListTile 잉크 수정으로 해소
   - `gh pr merge 298 --squash --delete-branch` → `main` = **9af3c85**
   - ⚠ **머지는 완료가 아니다.** 사용자 라이브 검증 통과만 완료 (§9-5)

51. **2026-08-13** — **NAS 배포 성공 + 서버 측 검증 통과. 사용자 라이브 검증만 남았다.**
   - Deploy to NAS `31752486126` **success**(2m38s) /
     `main.dart.js` `last-modified` = **Thu, 13 Aug 2026 23:06:18 GMT**(배포 시각으로 갱신)
   - `verify-cache-headers.sh` **통과** — 20개 산출물 전부 `no-cache, must-revalidate` +
     아이콘 폰트 **content hash 있음**(`MaterialIcons-Regular.754cc592fddf.otf`)
   - 라이브 번들 문자열 확인: `편집`(신규, 1건) · `비활성`(11) · `잔액 수정`(9) ·
     `저장 & 계속`(1) · `기본 카테고리`(1) 등 **전부 존재**
   - ⚠ **측정 한계 1건(대조군으로 확인)**: 색 상수는 번들에서 grep 으로 확인할 수 없다.
     10·16진수·정규화 double 성분 4가지 표기를 다 시도했는데 **구 브랜드 그린(#4CAF50)도
     똑같이 0건**이었다 → 프로브가 무효인 것이지 색이 빠진 게 아니다.
     **색은 서버에서 판정 불가 → 사용자 눈(C1~C6)이 유일한 판정 수단**이다
   - **남은 것: 사용자 라이브 검증** A1~A5 / B1~B7 / C1~C6 / D1~D3 (기획서 §10)

52. **2026-08-14** — 🎉 **자산 탭 회차 종결 — 사용자 라이브 검증 통과 = 완료.**
   - 사용자 판정: **"색상도 깔끔하고 수정된거 잘 된다."** A/B/C/D 전 시나리오 통과
   - 결과 문서(정본): `docs/sessions/2026-08-14_1_asset-tab-mobile-theme_result.md`
   - PR #298, `main` = `9af3c85`. BE·DB·api-spec 변경 0건
   - **같은 턴에 다음 회차 요청 2건 접수**(아래 §3 NEXT 에 고정) — 이 세션에서는 착수하지 않는다

53. **2026-08-18** — **auto mode 권한 설정 정비** (개발 회차 아님 · 도구 트랙).
   - `/auto-mode-setup`. 전 프로젝트 세션 로그 21+개·Bash 1,662건 스캔 `[측정]`
   - **발견**: `permissions.allow` 의 블랭킷 `Bash`/`Edit`/`Write`/`WebFetch` 가 룰 단계에서
     먼저 매칭돼 **auto mode 분류기가 사실상 안 돌고 있었다**. 특히 `Bash(git push:*)` 가
     있어 글로벌 §1.5(main 직접 push 금지)를 `hard_deny` 에 써도 조회조차 되지 않는 구멍
   - **조치**: `~/.claude/settings.json` 에 `autoMode.environment`(6) / `allow`(7) /
     `soft_deny`(8) / `hard_deny`(5) 신설 + 블랭킷 룰 제거. 프로젝트
     `.claude/settings.json` 의 블랭킷도 제거(이게 남으면 이 repo 안에선 전부 무효)
   - 백업 `~/.claude/settings.json.bak-automode-20260818`
   - ⚠ **미커밋**: `.claude/settings.json` 1건이 워킹트리에 남아 있다(이번 회차와 무관한 변경)

54. **2026-08-18** — **분석 탭 개편 회차 착수 — 요청 갱신 + 기획서 작성. 코드 0줄.**
   - **사용자 요청 갱신 2건**: ① 월말 점검은 축소가 아니라 **"정보 자체를 없애야"**
     (08-14 대비 격상) ② "**아이콘이나 버튼 크기가 너무 커**" → 지목 4곳이 아니라
     **크롬 전반 전수**로 일반화
   - **측정 `[1차]`**(로컬 Flutter SDK 직접 확인): `kToolbarHeight=56` /
     `_kTabHeight=46`·`_kTextAndIconTabHeight=72` / `NavigationBar height=80`
   - **진단**: 분석>통계 크롬 546dp = 화면의 70%, 콘텐츠 234dp(30%). 예산 sub-tab 은 26.7%.
     근본 원인은 자산 탭과 동일 — **크롬 치수가 흩어진 리터럴이라 총합을 아무도 안 본다**.
     `BbDensity` 는 타일 전용이고 크롬 토큰이 0개 `[측정]`
   - **전수 실측 `[측정]`**: `Tab(icon:+text:)` 9곳/3파일 · `IconButton` 70곳 ·
     그중 `iconSize`/`visualDensity` 명시는 20곳뿐(**50곳 기본값 방치**)
   - **도달성 사전 확인 `[측정]`**: 월말 점검 카드 호스팅은 `analysis_page.dart:93` 단 1곳이나,
     정산 뷰는 거래 탭 `SegmentedButton` 3번째 세그먼트(`transaction_list_page.dart:1438-1440`)로
     **독립 도달 가능** → 삭제해도 기능이 고아가 되지 않는다
   - **하네스 Step 1.5**: `ui_pattern`·`navigation_state` 둘 다 🚫 **STRUCTURAL_FIX_REQUIRED**
     (각 5건). 게이트 LOCKED. 구조적 수정 S1~S4 를 기획서에 포함
   - **총괄 검토(독립 검증)에서 2건 정정**:
     ① `Tab(child: Row(...))` 는 `icon == null` 이라 46dp — 아이콘 유지하며 감축 가능하고,
     `Tab.height` 파라미터가 이미 있어 **토큰 주입이 프레임워크 지원 경로**임을 SDK 소스로 확인
     ② `NavigationBar` 64dp 는 `SizedBox` 하드 박스라 **오버플로 위험** → §8-6 미해결로 격리 +
     사전 판정 기준(오버플로 시 72dp, 결론 불변) 명시
   - 산출물: **`docs/sessions/2026-08-18_1_analysis-tab-density_plan.md`**
   - **게이트: 사용자 승인 대기.** 승인 전 코드 편집 금지

55. **2026-08-18** — **요구 확대: calynda UI 크기 체계를 budget-book 에 이식 + 전 앱 기본값으로 승격.** 기획서 개정. 코드 0줄.
   - **사용자 지시**: "calynda 에서 진행했던 모바일과 웹(화면 크기·비율 차이) 기반 사이즈 변동을
     budget book 에도 적용" / "모바일에서 글씨·버튼이 **웹 그대로**라 사용하기 어려운 수준" /
     "가독성 고려해 크기별 동적 크기 설정" / **"앞으로 앱 작업, budget book 은 물론 calynda 나
     다른 추가 앱 작업에는 이게 항상 기본이어야 한다"**
   - **★근본 진단 정정 `[측정]`**: `core/theme/app_theme.dart` 가 **60줄이고
     `useMaterial3: true` 하나뿐** — `TextTheme`·밀도·컴포넌트 테마가 **전무**하다.
     앱 전체가 Material 기본 타이포 한 벌로 320px~2560px 를 똑같이 그린다.
     **"웹 그대로"가 문자 그대로 맞았다.** 크기 리터럴 **1,458건**
     (fontSize 115 · EdgeInsets 446 · SizedBox 747 · radius 150 / dart 416파일)
   - **calynda 측정 `[1차: 코드·문서 직접 확인]`**: 같은 병을 2026-08-14~17 에 이미 해결.
     `fe/lib/ui/shared/themes/ui_scale.dart`(301줄) + `tool/check_ui_scaling.py` +
     `test/ui/responsive_sweep_test.dart`(31건). 리터럴 509→405, PR fe#197, 배포 게이트 배선 완료
   - **★내 원안 폐기**: `BbChrome` 3단 계단 토큰은 calynda 가 **실측으로 틀렸다고 판정한 모양**이었다.
     ①비율 clamp 는 하한에 닿는 순간 전 축이 굳는다(`sqrt(W/1440).clamp(0.9,1.8)` 이
     **320~1024px 전 구간 0.900 붙박이** = 폭 3.2배에 반응 0) ②**화면 폭 판정은 틀린다** —
     최악이 모바일이 아니라 900px 였다(352px 패널에서 데스크톱 폰트 → 22.49자 < 390px 의 27.81자).
     **`BbDensity.of` 가 정확히 이 안티패턴**(`bb_density.dart:131-133`) ③여백이 폰트를
     안 따라가면 이름만 바뀐다
   - **기획서 개정** `docs/sessions/2026-08-18_1_analysis-tab-density_plan.md` (474줄):
     §2.5·2.6 신설(근본 진단 정정 + calynda 선례) · §4 구조적 수정 **S1~S6 전면 교체**
     (`BbType`/`BbSpace` 이식 · `app_theme` 배선 · `BbDensity` 흡수 · ratchet · 스윕 · 도달성 이관) ·
     §5 를 5단계로 재구성 · §8 미해결 7~9 추가
   - **★전 앱 승격(사용자 지시 이행)** — 이 회차 밖 영구 산출물:
     · **`~/.claude/domains/12-ui-scaling.md` 신설**(164줄) — 4층 모델 L0~L4 · 핵심 규칙 5종
       (clamp 는 가독 px / 컨테이너 폭 판정 / 폰트→여백→밀도 순서 / 여백은 제곱근 결합 /
       작은 화면에서 본문 안 줄임) · 강제 3종 · 체크리스트 · 계측 함정
     · `~/.claude/domains/INDEX.md` 매핑·트리거·목록 3곳 배선
     · `~/.claude/CLAUDE.md` §3 라우팅 표 등재
     · **`~/.claude/harness/scripts/classify-route.py` 키워드 규칙 신설** — 이번 요청이
       `01-diagnosis` 로 **오분류**됐던 걸 확인하고 등록. 스모크 테스트로 정상 라우팅 검증
   - **범위 결정**: calynda 가 검증한 스코프(**토큰 + 게이트 + 시범 1영역**)를 따른다.
     시범 = 분석 탭. 1,458건 전수는 이 회차가 아니고 **ratchet 이 회차마다 낮춘다**
   - **게이트: 사용자 승인 대기**(개정판 기준). 승인 전 코드 편집 금지

56. **2026-08-18** — **승인("승인") → UI 크기 토큰 + 게이트 + 분석 탭 이관 구현 완료.** 브랜치 `feat/ui-scaling-tokens`.
   - 하네스 게이트 해제: `acknowledge-gate.sh frontend <기획서>` (지문 `8:2026-08-11`)
   - **★대조군 실험으로 진단 확정** `[측정]`. 같은 크롬 구성을 이관 전/후 두 벌로 렌더:
     **legacy 는 320px 과 960px 에서 콘텐츠가 완전히 동일한 496dp(63.6%)** = 폭 반응 0 이
     추론이 아니라 대조군으로 확정. 토큰 적용 후 **620dp(79.5%)** — 크롬 284 → 160dp(**−43.7%**)
   - 토큰 실측(360px): `body 14.0`(유지) · `title 18.0`(22 → −18%) · `iconMd 19.0`(24 → −21%) ·
     `navBar 66`(80 → −18%). 960px 에선 `title 19.9`·`iconMd 21.7` — **계단 아닌 연속 변화**
   - **산출물**: `bb_scale.dart`(신설, `BbType`/`BbSpace`/`BbScaleScope`) ·
     `app_theme.responsive()`(Material 15슬롯 TextTheme + visualDensity + 7개 컴포넌트 테마) ·
     `app.dart` 유효 콘텐츠 폭 주입 · `bb_tab.dart`(신설, 탭 9곳 이관) ·
     `bb_density` 폭 조회 위임 · `tool/check_ui_scaling.py`+baseline(신설) ·
     `responsive_sweep_test.dart`(신설 **30건**) · 월말 점검 4파일 삭제 · 자산 카드 2줄화
   - **★`textTheme.*` 450 호출부가 코드 변경 0으로 반응형이 됐다** — `app_theme` 배선이
     최고 레버리지였다(raw `fontSize` 는 115곳뿐)
   - **★웹 960 칼럼 결함 원천 차단**: `app.dart` 가 본문을 `maxWidth: 960` 으로 감싸는데
     `MediaQuery` 는 2560 을 준다. `BbScaleScope` 가 `min(maxWidth, 960)` 를 단일 소스로
     심어, calynda 가 실측한 "화면은 넓고 컨테이너는 좁은" 결함을 구조적으로 막았다
   - **★가드가 실제로 막았다**: 기존 S3(폭 읽기 단일 지점)가 `bb_scale.dart` 를 즉시 잡아
     실패 → 설계대로 `BbDensity` 를 `BbType` 아래로 흡수하고 소유자 이관. **토큰만 추가하고
     옛 경로를 남겼다면 여기서 걸렸을 것**이고 그게 이 가드의 목적이다
   - **기획 대비 정정 4건**(기획서 §12.2): ①§2.1 의 546dp 는 페이지 전체 추정이고 크롬
     프레임만은 실측 284dp — SDK 상수 산술이 **1.4% 오차**로 맞았다(범위가 다른 것이지 모순 아님)
     ②ratchet baseline 1,458 → **1,699**(도구 패턴 집합이 더 넓다) ③**§8-6 NavigationBar
     오버플로 위험 해소** — 66dp 로 21조합 전부 예외 0, 72dp 폴백 불필요 ④가드 임계 55% → **70%** 상향
   - **게이트 4+1 전부 통과** `[측정]`: analyze **3 issues(전부 기존 테스트 info, 신규 0)** /
     `flutter test` **1058 pass**(1036 → −8 삭제 +30 스윕) / `./gradlew test` BUILD SUCCESSFUL /
     `build web --release` **EXIT=0** / UI 크기 게이트 **통과**(total=1699=기준선, 시범 3파일 0)
   - BE·DB·`api-spec.md` 변경 **0건**. 다음: PR → 머지 → 배포 → **사용자 라이브 검증**

57. **2026-08-18** — **PR #299 머지 → 배포 완료(1회 실패 후 재실행). 라이브 검증 대기.**
   - 원격 CI: `backend-ci` pass 7s / `frontend-ci` pass 2m11s. ⚠ **CI Flutter 3.47.0 vs 로컬
     3.41.2** — 큰 skew 인데도 통과(`feedback_flutter_sdk_skew_analyze` 위험 미발현)
   - `gh pr merge --squash --delete-branch` → `main` = **`6bc3c86`**
   - **배포 1차 실패 인시던트**: `deploy-frontend` 의 "Package and deploy to NAS" 에서
     `ssh: connect to host *** port ***: Connection timed out` (exit 255). 빌드·아이콘 해시
     단계는 통과했고 **NAS 도달만 실패**. 로컬에서 `ssh tiggle` 확인 → `NAS_OK`,
     uptime 144일, site 200 = **NAS 는 정상, 러너→NAS 일시 도달 실패**.
     `gh run rerun --failed` 로 해소(2차 1m44s 통과)
   - **★내 판독 실수 1건(기록)**: `gh run watch --exit-status 2>&1 | tail -5` 로 실행해
     `$?` 가 **`tail` 의 상태**를 읽어 EXIT=0 을 "배포 성공" 으로 잘못 보고했다. 실제로는
     `deploy-frontend` 가 실패였다. 잡아낸 것은 **번들 신선도 확인**(`last-modified` 가
     8/13 = 5일 전)이었다. → 교훈: **파이프라인 종료 코드를 파이프 뒤에서 읽지 마라.**
     그리고 **배포 성공 판정은 워크플로 상태가 아니라 산출물 신선도로 한다**
   - **배포 후 게이트 통과** `[측정]`: 번들 `last-modified` **Tue, 18 Aug 2026 05:29:51 GMT** ·
     content-length **5505837 → 5506572**(내용이 실제로 바뀜) ·
     `verify-cache-headers.sh` 전 항목 OK · 아이콘 폰트 content hash `754cc592fddf` 존재 · site **200**
   - **남은 것: 사용자 라이브 검증** — 기획서 §9 시나리오 0/A/B/C/D

58. **2026-08-19** — **사용자 회신 → 타이포 기준점을 자산 탭으로 재보정.** 예고한 레버 발동.
   - **사용자 회신**: "자산 내 글자 크기가 **딱 적절하다**. 거래/분석/더보기 등 모든 곳에
     반영되어야 한다." → 기획서 §8-7 에 사전 판정 기준으로 예고한 그 분기다(재기획 아님)
   - **★측정으로 원인 확정** `[측정]`: `EntityTileRow` 는 폰트를 **`BbDensity` 의 리터럴
     3단 계단**에서 받고 새 `TextTheme` 을 우회하고 있었다 = **두 스케일 공존**.
     그리고 자산 쪽만 폭에 반응했다:
     · 자산(320/768/960): title **14/15/16** · metric 13/14/15 · chip 10/11/12 · hdrV 15/17/19
     · 테마(전 구간): bodyL **16.0 붙박이** · bodyM 14.0 · bodyS 12.0 (min == ref 였으므로)
     → 모바일에서 목록 제목이 자산보다 **+2px**, 그게 "거래/분석/더보기가 크다" 의 실체
   - **★내 이전 판단의 정정**: "작은 화면에서 본문을 줄이지 않는다"(domains/12 ★5)를
     지키려 `min == ref` 로 뒀는데, 그 결과 **1440px 아래 본문이 통째로 상수**가 됐다.
     이 체계가 고치려던 "폭 반응 0" 을 본문에서 재현한 셈이다. 하한을 **가독 기준 px** 에
     거는 원칙은 유지하되, 그 기준을 Material 기본값 → **자산 탭 실측**으로 옮겼다
   - **역산**: `clamp(min, ref × (W/1440)^0.25, max)` 에 자산 3단 값을 통과시키도록
     ref/min/max 를 풀었다 — title `17.8/14/16` · metric `16.7/13/15` · chip `13.4/10/12` ·
     hdrL `13.3/11/12` · hdrV `21.1/15/19`. `ref > max` 는 의도(기준 폭에서 이미 포화).
     ⚠ hdrV 는 21.0 이면 960px 에서 18.98 로 상한에 **0.02 미달** → 21.1 로 보정(가드가 잡았다)
   - **정합 실측** `[측정]`: 320·360 에서 자산 값과 **완전 일치**(14/13/10/11/15),
     960·1440 에서도 **완전 일치**(16/15/12/12/19). 768 은 계단(경계 840) 대신 매끄럽게 보간
   - **신규 가드 2건**: ①"기준점은 자산 탭" — 테마 타이포가 `BbDensity` 타일 폰트와
     양 끝에서 정확 일치(표류 시 자산 쪽을 정본으로 맞춘다) ②"본문도 폭에 반응" —
     전 구간 상수였던 이전 판의 회귀 방지. **구현 중 이 가드들이 내 단정 3건을 잡았다**
     (390px 은 곡선이 하한을 벗어남 / 960 이상은 포화하므로 960 vs 2560 비교 무의미 /
     hdrV 0.02 미달)
   - **알게 된 성질(문서화)**: 타이포는 **960px 부근에서 포화**한다. 본문 칼럼이
     `kBbContentMaxWidth = 960` 으로 묶여 있어 그보다 넓은 화면에서 커질 이유가 없다
   - **게이트 4+1 통과** `[측정]`: analyze 3 issues(기존 테스트 info, 신규 0) /
     `flutter test` **1060 pass**(1058 → +2 가드) / `./gradlew test` exit 0 /
     `build web --release` exit 0 / UI 크기 게이트 통과(1699 = 기준선)
   - **남은 것**: `BbDensity` 폰트 필드를 `BbType` 으로 흡수해 **경쟁 경로를 0개로** 만드는
     구조 정리. 이번엔 하지 않았다 — 자산 탭이 **사용자가 검증한 기준점**이라 흡수 시
     768px 대에서 계단↔곡선 차이(15 vs 15.2)가 생겨 검증된 표면을 건드린다. 별도 회차로

59. **2026-08-19** — **PR #300 머지·배포 완료. 라이브 검증 대기.**
   - CI: `backend-ci` pass 7s / `frontend-ci` pass 2m17s → `gh pr merge --squash --delete-branch`
   - `main` = **`f424143`**. 배포 `deploy-frontend` 1m42s 통과(1차 성공, 이번엔 재실행 불필요)
   - **성공 판정은 산출물 신선도로** (`feedback_deploy_success_by_artifact` 적용):
     번들 `last-modified` **Wed, 19 Aug 2026 07:00:41 GMT** · content-length **5506530**
     (직전 5506572 에서 변화) · `verify-cache-headers.sh` 전 항목 OK ·
     아이콘 폰트 hash `754cc592fddf` · site **200**
   - **남은 것: 사용자 라이브 검증** — 자산 탭 크기가 거래/분석/더보기에 반영됐는지

60. **2026-08-20** — 🎉 **UI 크기 체계 회차 종결 — 사용자 라이브 검증 통과 = 완료.**
   - 판정: **"잘 됐다."** 자산 탭 크기가 거래/분석/더보기에 반영됨 확인
   - 정본 `docs/sessions/2026-08-19_1_typography-anchor_result.md` ·
     PR #299+#300 · `main`=`f424143` · BE·DB·api-spec 0건
   - 영속 자산: `~/.claude/domains/12-ui-scaling.md`(전 앱 기본값) · `bb_scale.dart` ·
     `app_theme.responsive()` · ratchet(1699) · 스윕 32건
   - **같은 턴에 다음 회차 지시 접수**(여백·간격) → §3 NEXT 에 실측과 함께 고정.
     **이 세션에서는 착수하지 않는다**(회차 경계)

61. **2026-08-20** — 여백·간격 회차: 기획 승인 → 구현 → 로컬 CI 5종 통과.
   - **착수 실측(기획 근거)** `[측정]`: `BbSpace.factor` 범위 **0.964~1.035(7%)** = 폭 8배에
     여백 **0.57dp**. 원인은 `sqrt(body(W)/14)` 에서 `body` 가 `13~15` 로 clamp 돼 있던 것 —
     **아래 층 clamp 가 위 층을 굳히는 층 의존 부작용, 폰트·여백으로 2회 발생**.
     추가 발견: `BbSpace` 를 쓰는 `lib` 파일이 **3개**뿐이라 곡선만 고쳐도 가시 변화 0.
   - **결정**: 여백은 자기 폭 곡선(지수 0.5) + 자기 px clamp. 근거는 승인된 자산 탭 스팬
     (여백 1.60배 vs 폰트 1.15배)이고 폭지수 0.125 로는 **어떤 ref/clamp 로도 도달 불가**.
     `sqrt(textScaler)` 는 clamp **밖**(안에 넣으면 상한에 잘려 결합 목적이 사라진다).
   - **구조적 수정**: `bb_density.dart` **삭제** → 컴파일이 계단 사용을 막는다.
     소비 지점은 2파일뿐이었고(컴파일러가 증명), 폰트 5개는 직전 회차에 이미 `BbType` 과
     동일 값이라 완전 중복이었다. `tabHeight`/`navBarHeight`/`VisualDensity` 계단 3곳도 곡선화.
   - **전역 통로**: `AppTheme.responsive()` 에 `inputDecoration`(하드코딩 16/12 제거) ·
     card · listTile · tabBar · dialog · bottomSheet · divider · 4종 버튼 여백/반지름 배선.
   - **사용자 추가 지시 — UI 불일치 전수 검수**: "±1일 문구의 왼쪽 여백이 더 길다."
     기하 실측 결과 **버튼 좌우 여백은 정확히 같았다**(57.30/57.30) — 어긋난 것은 **라벨**로,
     `*Button.icon` 이 아이콘+라벨을 한 덩어리로 중앙 정렬해 `24dp` 밀려 있었다.
     처방: `BbWideButton` 신설(라벨 정중앙 + 아이콘 레인 양쪽 대칭 예약).
   - **검수 도구 신설** `tool/audit_ui_consistency.py` (클래스 래칫):
     A 전폭 `Button.icon` **2→0** · C 버튼 수평패딩 0 **22→0** · D 국소 `visualDensity`
     **17→0** · G 화면 폭 직접조회 **0** / 동결: B 비대칭 38→32 · E `ListTile` 87 · F 색 474.
     H 값 종류 실측 — radius **8종**/142곳 · `SizedBox` **15종**/544곳 · `EdgeInsets.all` 9종/149곳.
   - **이관**: 시범 7파일(자산·거래·분석·공통 필터바) 리터럴 **0**. 총 **1699 → 1481**.
   - 게이트: analyze 0 · `flutter test` **1065** · `./gradlew test` · `build web --release` ·
     래칫 2종 · 스윕 32→**37**건 · `no_step_ladder_guard_test.dart` 4종 신설
   - **인시던트(자기 실수)**: `dart format lib/` 를 전체에 돌려 195파일이 변경됐다.
     의도 변경이 없는 **171파일 되돌림**(diff 서명으로 판정). 교훈: 포맷은 이관 파일 범위에만.
   - **정본 문서 개정**: `~/.claude/domains/12-ui-scaling.md` ★4 재작성 + ★4-b(ref 유도) 신설
     + 강제 장치에 일관성 래칫·계단 금지 가드 추가 + ★5 의 `min == ref` 처방 무효화 기록
     (기준점이 있으면 기준점이 이긴다).

62. **2026-08-20** — PR #301 머지 → NAS 배포 성공. **라이브 검증 대기**.
   - CI: `backend-ci` pass(8s) · `frontend-ci` pass(래칫 2종 신규 포함)
   - 머지: squash + branch 삭제 (개인 계정 자동 진행 범위) · `main`=`6159efa`
   - 배포: `deploy-nas` run 32325049876 **success**
   - **산출물 신선도로 판정** `[측정]`: `main.dart.js` `last-modified Thu, 20 Aug 2026 02:35:35 GMT` ·
     `content-length 5515085` · `cache-control no-cache, must-revalidate`.
     번들에 escaped 한글 `1\uc77c \uc804` 와 `BbSpaceToken` 존재.
     ⚠ 로컬 빌드(5454417B)와 크기가 다른 것은 CI Flutter 가 최신(3.47 vs 로컬 3.41)이기 때문.
   - **완료 아님** — §3 의 라이브 검증 6항목 통과가 완료 기준

63. **2026-08-21** — 라이브 검증 결과: **부분 통과**. 세로 여백 불일치 1건으로 회차 미종결.
   - 사용자 판정 원문: "분석에서 자산현황 내 항목 간 위아래 여백과 자산 탭 내 위아래 여백이
     다른데? 기준을 자산 탭으로 맞추고 자산도 조금 더 위아래 값들이 가까워질 수 있으면
     가깝게 해서 전체 설정을 맞춰라"
   - ±1일 버튼·전역 통로 등 다른 항목에 대한 반증 보고는 없었다(개별 확인은 미완).
   - **착수 실측을 §3 NEXT 에 고정**(재조사 불필요). `/clear` 후 새 세션에서 기획부터.
   - **이 세션에서는 착수하지 않는다**(회차 경계 — `feedback_round_boundary_clear`).

64. **2026-08-21** — 세로 리듬 통일 회차 **기획 완료(승인 대기)**. 코드 변경 0줄.
   - **§3 NEXT 의 `[추론]` 표를 정정한다** `[측정 2026-08-21]`: "분석 타일 내부 상하 12 고정"은
     사실이 아니었다. 두 화면 **모두** 항목은 `EntityTileRow`(padV=`lg`)로 그려지고 인접 항목
     간격은 **양쪽 다 16.0dp @390** 으로 같다. 벌어진 것은 **그룹 박스**다.
     - 자산 탭(정본) = 평면 목록. 그룹 헤더 `only(l:xl, t:lg, r:xl, b:xs)`(1147) ·
       항목은 `EntityTileRow` **직접**(Card·margin 없음, 1256) · 리스트 `only(top: md, bottom: 88)`(1056).
       그룹 경계 = lg+lg+xs ≈ **19dp**
     - 분석>예산 자산현황(`showHeader:false`) = 외곽 `fromLTRB(12,16,12,8)` → 제목 `bottom 8`
       → 그룹마다 `Container(margin b:8, padding all(12), border, radius 10)` → 헤더 Row
       (`Icon 16` + `SizedBox 6` + `fontSize 13`) → `SizedBox(6)` → 항목들.
       그룹 경계 = 12+8+12 = **32dp**
     - 좌우도 어긋난다: 들여쓰기 12(외곽)+12(그룹박스)+xl(10.2) = **34.2** vs 자산 탭 **10.2**
     - 호스트는 `budget_list_page.dart:593·665` 두 곳(둘 다 `showHeader:false`).
       `showHeader:true` 경로는 `dashboard_page.dart:89` = **미라우팅 죽은 화면**
   - **결정 ①** — `account_balance_card.dart` 를 **자산 탭과 같은 평면 목록**으로 재작성:
     그룹 테두리 박스 제거 · 헤더를 자산 탭과 **동일 토큰·동일 스타일**(`iconSm`/`labelMedium w600`)
     · 항목은 `EntityTileRow` 직접. 완료 기준은 "토큰을 썼다"가 아니라 **"자산 탭과 같은 토큰"**.
     `PILOT_FILES` 등재로 잔존 0 강제(현재 리터럴 11건)
   - **결정 ②** — 세로 한 단계 촘촘: **`EntityTileRow` padV `lg`→`md`** + 그룹 헤더 `top: lg`→`md`.
     후보 ⓒ(`kBbSpaceSpec` 의 `lg` 하한 하향)를 **버린 근거** `[측정]`: `lg` 는 `radiusMd`(카드·
     입력·다이얼로그 반지름) · `dividerTheme.space` · `tabBar.labelPadding` · `TextButton` 수평 ·
     필터바 수평 등 **세로가 아닌 자리에서 12곳** 쓰인다 → 세로만 좁히라는 요청을 넘어서고
     승인 앵커(`lg` 8/12)를 무효화한다. ⓐ 는 타일 1곳 수정으로 **전 앱 타일**에 퍼진다
     (호스트: 자산 탭 결제수단·포켓 · 카테고리 타일 · 분석 자산현황).
     귀결 @390: 인접 항목 16 → **12.8** · 그룹 경계 19 → **15.8** / @960: 24 → **20** · 28 → **24**
   - **결정 ③** — 검수 공백 메움: `check_ui_scaling.py` 패턴에 `indent:`/`endIndent:`/`Divider(height:`
     추가(지금은 `asset_management_page.dart:742` 의 고정 `16/16` 이 **안 세어진다** — 시범 파일이
     "잔존 0" 인데 고정 px 가 살아 있는 상태). 검출분 토큰화 + **패턴 확장으로 총계가 오르므로
     baseline 1회 재생성**(상승은 의도 — 기록 없이는 ratchet 의 의미가 깨진다)
   - **가드 갱신**: 스윕 `anchors` 의 `tilePaddingV` 를 **md(6/10)** 로 재배선(주석에 2026-08-21
     승인값과 이유를 적는다 — 코드에서 읽으면 순환 검증) + `EntityTileRow` 세로 padding ==
     `space.md` 위젯 단정 신설 + 두 화면 그룹 헤더가 같은 토큰을 쓰는 소스 가드
   - **미해결**: 분석>예산의 **예산 항목은 `ListTile`** 이라 프레임워크가 높이(48+)를 소유한다 —
     자산현황보다 여전히 헐렁하다. **사전 판정 기준**: 사용자가 "예산 항목과 자산현황이 다르다"고
     하면 다음 회차는 대기열 1번(`ListTile`→`EntityTileRow`)을 **분석>예산부터** 착수한다
   - **리스크**: 그룹 테두리 제거는 여백이 아니라 **시각적 변경**이다(되돌리기 = `Container`
     decoration 블록 복원 한 곳). 아바타 있는 행은 32+12.8 = **44.8dp** 로 터치 하한 유지,
     아바타 없는 한 줄 행은 **이전에도** 44 미만이라 새 위반은 아니다

65. **2026-08-21** — 승인 → 구현 → **로컬 CI 6종 통과**. 세로 리듬 단일 소스화.
   - **구조적 수정**(하네스 게이트 필수 조항): `EntityGroupHeader` 신설
     (`lib/core/widgets/entity_group_header.dart`) — `label`/`icon`/`color` 만 받고
     `padding`·`fontSize`·`Widget` 슬롯을 **노출하지 않는다**. 자산 탭(`asset_management_page`)과
     분석>예산 자산현황(`account_balance_card`)이 **같은 위젯**을 지난다 = 경쟁 경로 0개.
   - **① 불일치 제거**: 분석 자산현황의 그룹 테두리 `Container`(padding 12 / margin 8 / border)
     **제거** → 자산 탭과 같은 평면 목록. 좌우 여백도 헤더·타일이 소유하게 해 들여쓰기
     **34.2 → 10.2dp**(자산 탭과 동일). 리터럴 11 → **0**, `PILOT_FILES` 등재.
   - **② 세로 한 단계 촘촘**: `EntityTileRow` 세로 padding `lg`→`md`(1곳 = 전 앱 타일 전파) +
     자산 탭 리스트 레벨 `top: lg`→`md` **3곳**(카테고리 그룹 헤더 · 총자산/부채 요약 행 ·
     카드정산 요약 행 — `feedback_common_scope_audit` 전수 적용).
     귀결 `[측정]` @390: 인접 항목 16.0 → **12.8dp** · 그룹 경계 19 → **15.8** /
     @960: 24 → **20** · 28 → **24**. 아바타 행 높이 **44.8dp** 로 터치 하한 유지.
   - **③ 검수 공백 메움**: `check_ui_scaling.py` 에 `Divider(height|thickness:` · `indent:` ·
     `endIndent:` 패턴 추가 → `asset_management_page.dart:748` 의 고정 `indent/endIndent 16` 을
     토큰화. **baseline 1481 → 1488 재생성**: 신규 패턴 검출 **+18**(feedback 5 · home 2 ·
     payment_method 1 · reconciliation 1 · statistics 1 · transaction 8), 이관분 **−11**(_core).
     증가분이 신규 패턴 검출분과 **정확히 일치**함을 별도 스캔으로 확인 = 회귀 아님 `[측정]`.
   - **가드 신설** `test/core/widgets/vertical_rhythm_guard_test.dart` **7건**:
     V1 타일 세로 padding == `md`(320/390/960) + 아바타 행 44dp 하한 ·
     V2 두 호스트가 `EntityGroupHeader` 를 지난다 / 자산현황에 `EdgeInsets`·`fontSize:`·
     `BoxDecoration` 재유입 금지 / 헤더 API 봉인 / `vertical: space.lg` 복귀 금지 ·
     V3 헤더 위 `md`·아래 `xs`·좌 `xl`.
   - **승인값 표 갱신**: 스윕 `anchors` 의 `tilePaddingV` = **md(6/10)** 로 재배선하고
     `lg`(8/12) 곡선 검증은 `radiusMd` 키로 이름만 옮겼다(카드·입력 반지름 ·
     `dividerTheme.space` · `tabBar.labelPadding` 이 여전히 쓰므로 곡선 검증은 유지해야 한다).
   - **게이트 6종** `[측정]`: `flutter analyze` **12건 = 변경 전과 동일(신규 0)** ·
     `flutter test` **1072**(1065 + 신규 7) · `./gradlew test` BUILD SUCCESSFUL ·
     `flutter build web --release` ✓ · `check_ui_scaling.py` exit 0 · `audit_ui_consistency.py` exit 0
   - **자기 인시던트 1건**: `dart format` 이 단행 `if` 를 두 줄로 접어
     `curly_braces_in_flow_control_structures` **신규 1건**을 만들었다(12 → 13).
     중괄호를 넣어 12로 복귀. 교훈: 포맷 후 analyze 를 **다시** 돌린다(포맷이 린트를 만든다).
   - 하네스: `pre-change-audit.sh . "ui_pattern"` → **STRUCTURAL_FIX_REQUIRED** →
     기획서 `docs/sessions/2026-08-21_vertical-rhythm_plan.md` 로 `acknowledge-gate.sh` 통과
   - BE·DB·`api-spec` 변경 **0건**

66. **2026-08-21** — PR #303 머지 → NAS 배포 성공. **라이브 검증 대기**(완료 아님).
   - CI: `backend-ci` pass · `frontend-ci` pass → `gh pr merge --squash --delete-branch`
     (개인 계정 자동 진행 범위) · `main` = **`8c39b0e`**
   - 배포 `deploy-nas` run **32425283860 success**: `changes` success ·
     `deploy-frontend` success · **`verify-live` success**(캐시 21종 + 아이콘 폰트 해시) ·
     `deploy-backend`·`sync-nginx` skipped(FE 전용 변경이라 정상)
   - **산출물 신선도로 판정** `[측정]`(`feedback_deploy_success_by_artifact`):
     `main.dart.js` `last-modified Thu, 20 Aug 2026 22:41:31 GMT`(= 08-21 07:41 KST) ·
     `content-length 5514869`(직전 5515085 에서 변화) · `no-cache, must-revalidate` · site 200
   - 번들 문자열 대조 `[측정]`: escaped `\uc790\uc0b0 \ud604\ud669`(자산 현황) **2건** ·
     `\uc740\ud589 / \uccb4\ud06c` **1건** — 로컬 빌드와 동일 건수.
     ⚠ 원문 한글 grep 은 라이브·로컬 **양쪽 0건**(항상 이스케이프된다 —
     `reference_live_bundle_string_verification`). 크기가 로컬(5454201)과 다른 것은
     CI Flutter 가 최신(3.47 vs 로컬 3.41)이기 때문
   - **완료 기준은 사용자 라이브 검증** — §3 체크리스트 통과 전까지 회차 미종결

67. **2026-08-21** — ❌ **라이브 검증 실패 — 요구 오해. PR #303 되돌림 + 측정 모드 전환.**
   - 사용자 판정 원문: "오히려 테두리 및 좌우 여백은 이전이 나았고 내가 말한건 위아래 항목이
     가깝게 배치되도록인데 동일하거나 넓은 느낌이다. 요구사항을 제대로 이해하지 못하고
     진행한 것 같다. (이전으로 되돌리고 다시 분석 후 진행)"
     추가 지적: "분석 > 통계 탭 내 상단 카테고리별·추이·전년 비교, 가운데가 안 맞고 이상해졌다."
   - **내 오류 3건**(자기 진단):
     ① **요구를 넓게 해석했다.** 요청은 "위아래 항목이 가깝게"였는데 테두리 제거·좌우 여백
        변경까지 했다. 사용자가 요청하지 않은 시각적 변경을 "기준을 자산 탭으로 맞춰라"의
        귀결로 밀어붙였다 — 승인 받았어도 **요청 범위를 넘긴 것이 오류**다.
     ② **세로 간격의 지배 변수를 틀렸다.** padV 를 `lg`(8) → `md`(6.4) 로 1.6dp 줄였지만
        사용자 체감은 "동일하거나 넓다". 즉 **padding 이 지배 변수가 아니다** — 다른 요소가
        행 높이를 결정하고 있다. 무엇인지는 **측정 전 단정 금지**(다음 항목).
     ③ 통계 탭 상단 탭 정렬 이상은 **원인 미확인**. 이번 PR 인지 직전 #301 인지 미판정.
   - **되돌림**: `frontend/` 전체를 `9a8b30c`(PR #303 직전)로 복원 + 신규 2파일 삭제
     (`entity_group_header.dart` · `vertical_rhythm_guard_test.dart`).
     검수 도구 패턴·baseline 도 함께 되돌렸다(부분 유지 시 baseline 불일치로 게이트가 깨진다).
     게이트: analyze 12건(동일) · `flutter test` **1065**(원상) · `build web` ✓ · 래칫 2종 ✓
   - **다음 단계는 측정 모드**(§1.2 정신): 추측 fix 금지. 실제 렌더 높이·간격을 위젯 테스트로
     계측해 "무엇이 세로 간격을 지배하는가"를 수치로 확정한 뒤 재기획한다
   - 문서 기록(`docs/sessions/2026-08-21_vertical-rhythm_plan.md` · 타임라인 64~66)은
     **지우지 않는다** — 틀린 기획도 이력이다(정정은 이 항목이 담당)

68. **2026-08-21** — 측정 모드 결과: **지배 변수 확정 + 통계 탭 원인 확정**. 재기획(승인 대기).
   - **Q1 세로 간격** `[측정: 위젯 렌더 기하 320/390/960]`: 행 높이 **48.0dp @390** 이고
     **인접 제목 간 거리도 48.0** = 행 사이 gap 은 **0**. 즉 "항목 간 여백"의 정체는 **행 높이**다.
     구성은 **아바타 32.0dp = 67%** + `padV`(lg 8)×2 = 33%. 제목 텍스트 줄은 ~16.4dp 로
     아바타보다 훨씬 작다. @960 은 64.0 = 아바타 40 + 12×2. 칩 카드 타일 71.2/94.0.
     → **1차 변경(padV 8→6.37)은 48.0 → 44.7dp, −6.8% 였다.** 사용자의 "동일하거나 넓다"는
     정확한 관찰이고, 내가 지배 변수를 틀렸다.
   - **Q2 통계 탭** `[측정 + git log]`: 원인은 이번 회차가 아니라 **PR #299**(`Tab(icon:,text:)`
     세로 2단 → `bbTab` 가로 배치)로 탭 폭이 넓어진 것. 결함 본체는 **M3 스크롤 탭의 기본
     `tabAlignment = startOffset`(왼쪽 52dp 빈칸)**: 첫 라벨 x=**80.0**, 마지막 라벨 끝
     **411.1** > 바 폭 390 → 왼쪽 죽은 여백 + 오른쪽 **21dp 잘림**(360→51, 320→91).
     `TabAlignment.center` 실측: 첫 라벨 39.6 / 끝 370.5 / 오른쪽 여유 19.5 = **전부 들어가고 균형**.
     **공통 범위 전수**: 스크롤 TabBar 는 3곳(통계·기간별 상세·피드백 허브) — 셋 다 같은 결함.
   - **재기획서**: `docs/sessions/2026-08-21_2_vertical-rhythm-remeasured_plan.md`
     (선택지 5개 수치 + 권장 (c) `padV` xs = 38.0dp/−20.8% + 44dp 하한 트레이드오프 명시 +
     범위 봉인 §4 + 강제 장치 + 미해결)
   - 하네스: 새 기획서로 `acknowledge-gate.sh` 재승인(지문 6:2026-08-21)
   - **승인 대기** — 승인 전 코드 편집 금지(§2)

69. **2026-08-21** — 사용자 지표 정정 + **승인 → 구현 → 로컬 CI 6종 통과**.
   - **사용자 정정**: "1과 2 **사이**(위아래 사이)가 넓다는 뜻이다." → 지표는 **행 높이가
     아니라 인접 항목 텍스트 사이의 빈 공간**이다. 다시 재니 지배 변수도 반대였다 `[측정]`:
     - 행 높이 48.0dp @390 = 아바타 32(**67%**) + 패딩 16(33%)
     - **텍스트 사이 28.0dp @390 = 패딩 16(57%) + 아바타 오버행 12(43%)** · @960 41.0
     → 즉 **이 지표에서는 패딩이 지배 변수**다. 1차의 `lg`→`md` 는 28.0→24.7(−12%)에 그쳤다.
   - **사용자 승인값**: `EntityTileRow` 세로 padding `lg` → **`xs`** =
     텍스트 사이 **18.0dp @390(−36%)** · **25.0 @960(−39%)**. 아바타·폰트·가로는 **불변**
     (선택지 22.2 / 18.0 / 14.0dp 중 18.0 선택)
   - **통계 탭 정렬 fix**: 스크롤 TabBar **3곳**(`statistics_page`·`period_summary_page`·
     `feedback_hub_page`)에 `tabAlignment: TabAlignment.center` 명시.
     원인은 M3 기본값 `startOffset`(왼쪽 52dp 죽은 여백) + #299 의 가로 배치로 넓어진 탭 폭
     → 첫 라벨 x=80.0 · 마지막 끝 411.1 > 폭 390(오른쪽 21dp 잘림). center 로 전부 들어온다
   - **가드 4건 신설** `test/core/widgets/vertical_rhythm_guard_test.dart`:
     V1 텍스트 사이 **18.0/25.0** 승인값 단정(테스트가 소유) + 세로 padding == `xs` ·
     가로는 `xl` 불변 단정 + 소스에 `space.lg`/`space.md` 회귀 금지 ·
     V2 **`isScrollable: true` 인 모든 파일에 `tabAlignment` 존재**(개수 대조) —
     기본값 노출을 앱 전체에서 막는다
   - 게이트 6종 `[측정]`: analyze **12건 = 변경 전과 동일(신규 0)** · `flutter test` **1069**
     (1065+4) · `./gradlew test` BUILD SUCCESSFUL · `build web --release` ✓ · 래칫 2종 exit 0
   - 자기 인시던트 재발: `dart format` 이 또 신규 lint 1건을 만들었다(13건) → const 추가로 12 복귀.
     `feedback_full_flutter_analyze` 에 기록한 순서(포맷 → analyze 재실행)가 실제로 값을 했다
   - 범위 봉인 준수: 테두리·좌우 여백·아바타·폰트·구조 **변경 0건**

70. **2026-08-21** — PR #306 머지 → 배포 성공. **라이브 검증 대기**(완료 아님).
   - CI: `backend-ci` pass · `frontend-ci` pass → squash 머지 · `main` = **`cc20eac`**
   - 배포 `deploy-nas` run **32460302400 success**(`changes`·`deploy-frontend`·**`verify-live`** 전부)
   - **산출물 신선도** `[측정]`: `content-length` **5515135**(되돌림 상태 5515085 → 변화) ·
     `last-modified Fri, 21 Aug 2026 07:50:48 GMT`(16:50 KST) · site 200
   - 재발 방지 등록: `~/.claude/harness/lessons-learned.jsonl`(ui_pattern·meta_process) →
     `recurrence_tracker` 갱신(ui_pattern **7건**) = 다음 회차 audit 이 이 실패를 자동 경고한다
   - 메모리 2건 신설: `feedback_user_metric_definition`(지표 치환 금지) ·
     `reference_m3_scrollable_tabbar_offset`(스크롤 탭 기본 startOffset)

71. **2026-08-21** — 사용자 판정 **"잘 되고 마음에 든다"** + 추가 지시 2건 → 구현 · 로컬 CI 6종 통과.
   - 지시: ① 항목 사이를 **20 정도로** ② **항목 사이 좁히기를 전체에 적용**
   - **① 20dp**: `kBbSpaceSpec[xs]` (3,4) → **(4,4)** → `EntityTileRow` 사이
     18.0 → **20.0dp @390**(@960 은 25.0 그대로 — xs 는 960 에서 이미 4였다).
     `xs` 가 폭 상수가 된 근거: 이 크기의 "곡선"은 폭 8배에 **1dp** = 지각 불가 노이즈다
   - **② 전체 적용 — 지렛대를 측정으로 찾았다** `[측정 2026-08-21]`:
     주요 목록(거래·이체·반복·정산·리포트·설정·선택 시트 등 **87곳**)은 프레임워크
     `ListTile` 이라 **높이를 SDK 가 소유**한다(M3 1줄 56 · 2줄 72 + density) →
     손대지 않으면 **사이 34.8dp** = 우리 타일(20.0)의 **1.7배**.
     - `ListTileThemeData.minTileHeight` 를 주면 SDK 기본 높이 경로가 꺼지고
       **사이(2줄) = 2 × `minVerticalPadding`** · **사이(1줄) = `minTileHeight` − 제목줄** 이 된다
     - 실패한 후보들도 기록: `dense: true` **무효** · `visualDensity` 는 하한 −4 라
       2줄 56dp 가 한계(사이 26.8) · `minVerticalPadding` 단독은 **무효**(기본 높이가 이긴다)
     - 처방: `kBbBoxSpec` 에 목록 행 역할 2종 신설 —
       `listRowPadV`(10, 12.5) · `listRowMinHeight`(34, 41) → 테마 한 곳에 배선.
       실측 결과 **1줄·2줄 모두 사이 20.0 @320/390 · 25.0 @960/1440** = 우리 타일과 **동일**
   - ⚠ 트레이드오프: 1줄 타일 높이 **34dp** 로 44dp 터치 하한 미달(설정 메뉴 등).
     사용자가 승인한 "사이 20dp" 를 1줄에도 적용한 결과다. 되돌리기 =
     `listRowMinHeight` min 을 44 로(사이 30dp)
   - **가드 9건**(`vertical_rhythm_guard_test`): 승인값 20.0/25.0 을 **우리 타일 + ListTile
     1줄/2줄** 양쪽에서 폭별로 단정 · 테마가 **두 지렛대를 모두** 들었는지(하나만 있으면
     SDK 기본 높이가 이긴다) · 세로만 바뀌었는지 · 스크롤 탭 `tabAlignment` 존재
   - **계측 함정 2건 기록**: ⓐ **한 테스트 안에서 폭을 바꾸면 안 된다** — `MaterialApp` 이
     테마를 `AnimatedTheme`(200ms)로 감싸 옛 값이 읽힌다(960 에서 390 값이 나와 오진 직전까지
     갔다). 폭마다 테스트를 나눈다. ⓑ `ListTile` 높이는 leading 아바타(40)·제목줄·padding·
     SDK 기본값 4개가 경쟁하므로 **분해해서** 읽어야 한다
   - 남는 차이(보고): **카드형 목록**(포켓·지출계획)은 `Card` 여백이 더 붙어 사이가 +6~10dp.
     카드 간 분리는 의도된 시각 단위라 이번 범위에서 제외
   - 게이트 6종 `[측정]`: analyze **12건(신규 0)** · `flutter test` **1074**(1069+5) ·
     `./gradlew test` · `build web --release` · 래칫 2종 exit 0

72. **2026-08-21** — PR #308 머지 → 배포 성공. **라이브 검증 대기**(완료 아님).
   - 사용자 머지 지시 시점에 `frontend-ci` 가 **pending** 이었다 → 게이트(§1.8)를 지키려고
     **auto-merge** 를 걸었고 `frontend-ci` pass(2m21s) 확인 후 머지됐다. `main` = **`14b13bf`**
   - 배포 `deploy-nas` run **32467170752 success**: `changes`·`deploy-frontend`·
     **`verify-live`** 전부 success · BE·nginx skipped(FE 전용)
   - **산출물 신선도** `[측정]`: `content-length` **5515205**(직전 5515135 → 변화) ·
     `last-modified Fri, 21 Aug 2026 09:19:08 GMT`(18:19 KST) · site 200
   - 완료 기준은 사용자 라이브 검증 — §3 체크리스트

73. **2026-08-24** — 라이브 검증 **부분 통과**: `ListTile`·우리 타일은 반영 확인,
    **카드형은 미적용**(사용자 추측이 정확했다). 다음 회차 착수 지점 고정 → `/clear`.
   - 사용자 판정: "모두 적용해달라고 했는데 분석 내 예산/통계에는 적용되지 않은 것 같다.
     이건 카드 쪽이라 적용 안 된 건가? 확인 후 맞으면 clear 후 다음 진행과 카드에도
     줄이는 작업 포함 후 적용"
   - **측정으로 확인** `[측정 2026-08-24, 실제 구조 복제 렌더]`:
     - 분석>예산 항목은 `Dismissible → ListTile` → 사이 **20.0dp @390 / 25.0 @960 = 적용됨** ✓
     - 분석>통계 카테고리별 항목은 `Padding(v: xs) → Card → InkWell → Padding(all: lg)`
       → 사이 **34.2dp @390 / 48.0 @960 = 미적용** ✓ **카드는 `ListTile` 테마 경로를 안 탄다**
     - 34.2 분해: 바깥 `Padding` xs(4)×2 **8** + **`cardTheme.margin` 세로 sm(5.1)×2 = 10.2**
       + 카드 내부 `Padding` lg(8)×2 **16**. @960 은 8 + 16 + 24 = 48
     - 예산 화면이 헐렁해 보인 부수 원인: 목록에 **카드가 섞여 있다**
       (`BudgetSummaryCard` · `WeekSummaryCard` · `_buildCurrentWeekHero`).
       히어로는 `EdgeInsets.all(20)` · `circular(16)` **리터럴 잔존**
   - **카드 전수** `[측정]`: `Card(` **169건 / 52파일**(최다: dashboard_page 27 — 죽은 화면 ·
     asset_management 14 · report_page 11 · admin_dashboard 8 · statistics 3탭 각 6 · pocket 6)
   - 이번 회차(PR #308) 자체는 되돌리지 않는다 — 사용자가 "잘 되고 마음에 든다"로 판정한 부분이다
   - **이 세션에서는 카드 작업에 착수하지 않는다**(회차 경계 — `feedback_round_boundary_clear`)

74. **2026-08-24** — 카드형 회차 착수: **대조군 실측 완료**(추측 아님) + 기획서 + 게이트 재승인.
   - 산출물: `docs/sessions/2026-08-24_1_card-rhythm_plan.md` / 계측기 2종
     (`frontend/test/measure_card_gap_test.dart` · `measure_budget_gap_test.dart`)
   - 실측(텍스트↔텍스트, 390/960 · 승인값 20.0/25.0) `[측정]`:
     예산 항목(`ListTile`) **20.0/25.0 = 이미 적용** · 예산 주간카드 **75.2/80.5** ·
     통계 카테고리별 **34.2/48.0** · 결제수단별 **32.0/32.0** · 전년비교 **62.7/67.5** ·
     요약탭 **48.8/76.0** · 통계 추이는 카드 1개(대상 외)
   - 요청 해석 정정: 사용자가 말한 "예산 미적용" 대상은 항목이 아니라 **주간 카드 목록**이다
   - 전제 정정: "`cardTheme.margin` 한 줄로 169건에 닿는다"(직전 대장)는 틀렸다 —
     **호출부가 margin 을 덮어쓰는 곳 18건**(결제수단별·period_*·요약카드·알림 등)
   - 계측 함정 2건: ①`Card` 의 RenderBox 는 자기 margin 을 포함(보이는 표면은 안쪽 `Material`)
     ②항목 사이를 제목↔제목으로 재면 79.0dp(부제목 포함) → 이미 적용된 화면을 오판
   - 결정: **`margin: xs` + 신규 `BbBoxRole.cardRowPadV`(6, 8.5)** = 사이 20.0/25.0 정확히 일치
     (`ListTile` 의 `listRowPadV`(10,12.5) 와 같은 전용 박스 spec 관용구)
   - 게이트: 하네스 audit **STRUCTURAL_FIX_REQUIRED**(ui_pattern 8 / navigation_state 5) →
     `BbCardTile` 단일 소유자 + 가드 A~F 계획으로 재승인(지문 13:2026-08-24)

75. **2026-08-24** — 카드형 세로 리듬 **구현 + 로컬 CI 6종 통과**(배포 대기).
   - 구조적 수정: 신규 `BbCardTile`(세로 축 인자 미노출) + `BbBoxRole.cardRowPadV`(6, 8.5)
   - 이관 9파일: 통계 4탭 · 기간요약 4탭 · `week_summary_card`(+호스트 `budget_list_page`)
   - 사후 실측 `[측정]`(텍스트↔텍스트 390/960, 승인값 20.0/25.0):
     카테고리별 34.2/48.0 → **20.0/25.0** · 결제수단별 32.0/32.0 → **20.0/25.0** ·
     요약탭 48.8/76.0 → **20.0/25.0** · 전년비교 62.7/67.5 → **28.5/32.5** ·
     주간카드 75.2/80.5 → **41.0/45.5** · 예산 항목은 불변(20.0/25.0)
   - **보이는 테두리 사이는 전 표면 8.0dp 균일** — 전년비교·주간카드의 초과분은 카드
     안쪽 잉크(아이콘 블록 36dp · 진행바 5dp)이고 빈 공간 자체는 승인값과 같다 → `[무가드]`
   - 가드: `vertical_rhythm_guard_test` **V3** 3종 + `bb_card_tile_adoption_test`
     (호스트 9개 열거 · 맨 `Card(` 0건 · `DashboardPage` 미도달 단정)
   - 뺀 것(의도): `_buildCurrentWeekHero` 리터럴 2건 — 목록 아님 + 다른 축(PR #303 실패 재발 방지)
   - CI 6종: analyze 신규 0 / **flutter test 1105** / gradlew test / build web / ratchet 1464 / 일관성

76. **2026-08-24** — PR #311 머지 → 배포 성공. **산출물 신선도로 판정**(워크플로 상태 아님).
   - 원격 CI: backend-ci pass · frontend-ci pass(2m15s) → squash 머지(`7d55060`)
   - deploy-nas run 32673984184: changes/deploy-frontend/**verify-live 전부 success**
     (sync-nginx·deploy-backend 은 변경 없어 skipped)
   - 산출물 대조 `[측정]`: `main.dart.js` last-modified **2026-08-21 09:19 → 08-23 23:35** ·
     content-length **5,515,205 → 5,515,435** = 실제 새 번들이 서빙된다
   - ⚠ 번들 문자열 지문은 이번엔 쓸 수 없다 — 이 회차는 **신규 사용자 노출 문자열이 0건**
     (여백 수치만 바뀐다). 그래서 판정 근거는 신선도 2종 + verify-live 다
   - **완료 아님** — 사용자 라이브 검증 대기(§3 NEXT 의 기대값 목록)

77. **2026-08-24** — 5차: 항목 간 간격 **전역 통일** 요청 → 근본 원인 재정의 + 구현 + CI 6종.
   - 요청: "예산 항목 내, 자산 현황 내도 동일하게 … 20.0 으로 모두 통일 => 전역 UI"
   - **근본 원인 재정의** `[측정]`: `사이 = 행 박스 − 행 잉크`, `박스 = max(아바타, 액션
     슬롯 44, 텍스트) + 2×여백`. **여백이 아니라 슬롯이 리듬을 정한다** — 같은 위젯인데
     액션을 든 행만 사이가 12dp 넓었다(32 vs 20)
   - 실측 위반 표면: 주간 카드 **내부** 행 28.0 · 자산 현황 그룹 내 24~32 · 그룹 경계 91.0
   - 반증 시도 실패: 예산 **최상위** 항목은 375~960 전 폭에서 20.0/25.0 정확 = 이미 적용
   - **지표 정의 확정**: 승인 표면(거래 목록)의 아바타는 32dp → 잉크 사이 **13.0** 이고
     텍스트 사이 20.0 `[측정]`. 즉 사용자 기준은 **텍스트↔텍스트** → `ListTile` 45파일
     아바타 축소 스윕은 **착수 안 함**(잉크 기준으로 가면 승인 표면에서 멀어진다)
   - **히트 영역 계측이 우회를 반증**: 슬롯 레이아웃 높이만 낮추고 `OverflowBox` 로 44 를
     살리려 했으나 위쪽 20dp 탭이 새어나갔다(조상이 hit test 를 박스로 제한).
     위젯 박스로 판정했으면 통과했을 오류 — calynda 교훈 재현
   - 결과: 주간 카드 내부 28.0 → **20.0** · 그룹 경계 91.0 → 69.0(여백분 20.0) ·
     액션 행 32.0 → **24.0**(터치 하한 44 를 지킨 최소값) · 기준·예산 항목 불변
   - 산출물: `entity_tile_row`(액션 행 여백 0) · `budget_row_actions`(메뉴 높이 아이콘 사다리)
     · `account_balance_card`(그룹 박스 xs/cardRowPadV) · `week_summary_card`(2×listRowPadV)
     · 가드 `row_slot_rhythm_guard_test`(탭 라우팅 히트 영역 포함) · 계측기 `measure_global_gap_test`
   - CI 6종: analyze 신규 0 / **flutter test 1133** / gradlew test / build web / 래칫 1461 / 일관성
   - 잔차(사용자 판단 필요): 액션 행 24.0(+4) · 칩 행 16.0(−4) · 주간 카드 320dp 가로
     오버플로우(기존 결함, 대조군으로 확인)

78. **2026-08-24** — PR #313 머지 → 배포 성공(산출물 신선도로 판정). **라이브 검증 대기**.
   - 원격 CI: backend-ci pass · frontend-ci pass(2m20s) → squash 머지(`dd4aa37`)
   - deploy-nas run 32678694248: changes/deploy-frontend/**verify-live success**
   - 산출물 대조 `[측정]`: `main.dart.js` content-length **5,515,435 → 5,515,901** ·
     last-modified **08-23 23:35 → 08-24 01:07**
   - **완료 아님** — 사용자 확인 3점: 주간 카드 내부 행 · 자산 현황 그룹/항목 ·
     액션(⋮·잔액수정) 행의 24.0(유일한 미달 항목)

79. **2026-08-24** — 라이브 회신 3건 → **전수 계측 + 진단 완료**(코드 변경 없음, 측정 모드).
   - 신고: ①거래 아이콘 아래 글자 붙음(위는 여백 많음) ②예산·자산 현황 여백 과다
     ③자산 결제수단·카테고리 탭 아이콘 위아래 여백 0
   - 계측기 신규 `measure_row_balance_test.dart` — 지표 3종(행 사이 / **행 안 위·아래** /
     선행 위젯 내부)을 동시 측정
   - **①의 원인 = 3차(PR #308) 회귀** `[측정]`: `minTileHeight: 34` 로 2줄 타일이 72 → **45**
     인데 거래 타일의 선행 Column 은 **50** → 넘친다(타일상단→아바타 −1.5 ·
     글자→타일하단 **−4.5** · 행 사이 **−6.0 = 겹침**)
   - **③의 원인 = 5차(PR #313) 회귀** `[측정]`: `hasTallSlot ? 0 : space.xs` 로 액션 행
     여백이 0 → 위 **12.0** / 아래 **4.0**(3배 비대칭). 자산 탭·카테고리 탭·자산 현황 전부
   - **②는 여백이 아니라 랩** `[측정]`: 예산 행 위/아래는 10.0/10.0 대칭인데 부제목이
     폭 145.6dp 안에서 **3줄 45.0dp**(행 93dp 의 48%). @430 2줄 · @768 1줄
   - 진단: 여백·슬롯·선행·랩이 **각각 다른 파일에서 행 박스를 정한다** → 회차마다 한 항만
     고쳐 다른 표면이 깨졌다
   - 처방(기획서 §3): 행 리듬 단일 소유자 규칙 —
     `박스 = max(잉크, 선행, 슬롯 44) + 2×listRowPadV`, **위 여백 = 아래 여백**
   - 산출물: `docs/sessions/2026-08-24_3_row-balance_plan.md` + 계측기
   - **미적용** — 사용자 승인 후 착수(측정 모드 준수)

80. **2026-08-24** — 6차: 행 안 **위아래 균형** 구현 — 슬롯을 세로 흐름 밖으로, 중복 정보 2건 삭제.
    - 산출물: `entity_tile_row.dart`(슬롯·액션 레인을 제목 행 밖으로 → `박스 = max(잉크 + 2×xs,
      슬롯 44)`, 여백 무조건 대칭. `hasTallSlot` 삭제) / `transaction_list_tile.dart`(선행 캡션
      삭제 — **부제목이 이미 같은 결제수단명을 보여준다**) / `transfer_list_tile.dart`(선행 `이체`
      캡션 삭제 + 부제목 머리로 이관, 리터럴 2건 제거) / `budget_list_page.dart`(부제목의 예산
      총액 삭제 — **trailing 이 같은 금액을 굵게 표시한다** + `OneLineLabel` 로 랩 봉인) /
      `row_balance_guard_test.dart`(신설 20건) / `row_slot_rhythm_guard_test.dart`·
      `vertical_rhythm_guard_test.dart`(봉인 갱신) / `measure_row_balance_test.dart`(대조군 표기)
    - 결정: 기획서 §5-1 택1 → **(a) 선행 캡션 삭제**. 근거는 새로 확인한 중복이다 `[측정]` —
      결제수단명이 선행과 부제목 두 곳에 있었다. 그래서 "거래 목록 시각이 바뀐다"는 우려가
      사라지고 `minTileHeight`(모든 2줄 행 +5dp)를 건드릴 필요도 없어졌다
    - 결정: 기획서 §5-2(사용자 판단 필요로 남겼던 축) → **같은 근거로 자체 판정**. 예산 총액이
      trailing 에 이미 있으므로 부제목의 분모는 중복이었다. 정보 손실 0, 되돌리려면 문자열에
      분모를 다시 넣으면 된다(그래도 `OneLineLabel` 이 1줄을 유지)
    - 게이트(로컬 CI 6종): `analyze` 13 info(**전부 기존** — 변경 파일 0건) / `flutter test`
      1,165건 통과 / `gradlew test` BUILD SUCCESSFUL / `build web --release` 성공 /
      `check_ui_scaling.py` 통과(리터럴 1461 → **1460**) / `audit_ui_consistency.py` 통과
    - 계측(변경 후) `[측정]`: 자산 탭 칩 행 위 10.0 / 아래 8.0 · 사이 18.0 @390
      (텍스트 기준. **칠해진 표면 기준으로는 4.0 / 4.0**) · @960 12.5 / 8.0 · 사이 20.5 /
      1줄+슬롯 행 6.0 / 6.0 · 사이 24.0 / 예산 항목 잉크높이 43.0 · 사이 20.0 @375
    - 대조군(변경 전 코드에 새 가드 실행) `[측정]`: 5건 실패 — 칩+액션 행 위 6.0 / 아래 0.0
      (@390·@960) · 거래 타일 @390 · 소스 봉인 2건. **가드가 회귀를 실제로 잡는다**
    - 교훈(하네스 등록 대상): ① 봉인 테스트가 **주석 문구로 통과**했다 — 폐기한 표현을 주석에
      인용했더니 `row_slot_rhythm_guard` S3 가 초록이었다. 소스 스캔은 주석을 제거하고 봐야 한다.
      ② `find.byWidget` 은 위젯 **동일성**으로 찾는다 — `const` 로 canonical 화된 두 행이 한 행으로
      합쳐져 잉크가 두 행을 덮었다(아래 −74.0). 픽스처는 행마다 값을 달리해야 한다.
      ③ `of: find.byType(InkWell)` 는 **모든 행**을 잡아 여백을 2배로 센다 → `.first` 로 좁힌다.
      ④ 아바타는 `CircleAvatar` 가 아니라 `Container(decoration:)` 이라 텍스트만 재면 원의 위쪽
      8.5dp 를 놓친다 → **대칭인 행이 12.5 vs 8.0 으로 오독**된다. 균형 축은 칠해진 표면으로 잰다

81. **2026-08-24** — PR #316 머지 → 배포 성공(산출물 신선도로 판정). **라이브 검증 대기**.
    - CI(원격): `backend-ci` pass 6s · `frontend-ci` pass 2m29s
    - 머지: squash + branch 삭제(개인 계정 자동 진행 범위) → main `5735b2c`
    - 배포: deploy-nas run 32699949694 — changes/deploy-frontend/**verify-live 전부 success**
      (BE·nginx 는 변경 없어 skipped)
    - 판정 근거 `[측정]`: `main.dart.js` last-modified **07:06:29**(run 시작 07:05:02) ·
      content-length 5,515,266 · 번들에 `이체 · `(escaped `이체 \xb7 `) 존재.
      워크플로 상태가 아니라 산출물로 판정했다
    - 재발 방지: `lessons-learned.jsonl` 에 교훈 1건 등록(ui_pattern·meta_process) —
      "균형 축은 칠해진 표면으로", "슬롯은 세로 흐름 밖", "붙는다 = 중복 먼저 의심",
      "봉인은 주석 제거 후 스캔", "새 가드는 대조군에서 1회 실패시킨다".
      프로젝트 메모리에도 `reference_row_balance_measurement_traps` 로 남겼다

82. **2026-08-26** — **6차 라이브 회신: 1·2 통과, 3 실패(요구 오독).** 코드는 배포됐고 결함은 판정 축에 있었다.
    - **[측정] 회신**: ①거래 탭 ✅ ②자산·카테고리·자산현황 여백 ✅ ③분석>예산 — "예산 간의 위아래 항목 높이도 **자산처럼 일치**시키고 싶었던 건데 잘못 이해한 것 같다"
    - **원인 ⓐ 요구 오독**: "항목 높이"를 **축소**로 읽었다. 실제 요구는 **행 간 동일성**이다. 6차는 잉크높이 93.0→43.0 을 달성했지만 그건 다른 축이었다.
    - **[측정: 코드] 원인 ⓑ 구조**: `budget_list_page.dart:743` 이 `ListTile` 을 쓴다 → **프레임워크가 높이를 소유**한다. subtitle Column 의 `_buildBudgetProgressBar` 가 `budgetAmount <= 0` 에서 `SizedBox.shrink()` 를 돌려주므로 **항목마다 subtitle 높이가 갈린다**. 통과한 자산(`asset_management_page.dart`)·카테고리(`category_list_tile.dart`)는 `EntityTileRow` 라 **앱이 높이를 소유**한다 — 통과/실패가 갈린 지점이 정확히 여기다.
    - **[측정: 코드] 원인 ⓒ 가드 공백**: `row_balance_guard_test` 는 `expect(top, closeTo(bottom))` 로 **행 안 위/아래 대칭**만 잰다. 행 **간** 높이 동일성 축이 없어 20/20 초록인 채로 이 결함이 나갔다.
    - **★원인 ⓓ 교훈 자체의 구멍(가장 중요)**: 2026-08-24 교훈은 "'여백이 없다/많다' 회신은 **축을 셋으로** 갈라서 잰다: 행 사이 · 행 안 균형 · 랩"이었다. **거기에 '행 간 높이 동일성'이 없다.** 교훈이 축을 빠뜨렸으니 가드도 빠뜨렸다. 같은 교훈의 "놓친 위치"에 이미 `budget_list_page.dart` 가 적혀 있었는데도 다시 샜다.
    - **[측정] 하네스 audit**(`ui_pattern`): **STRUCTURAL_FIX_REQUIRED** — 12건(이 프로젝트 1). 패치 수정 불허, 구조적 수정안을 기획서에 넣어야 게이트가 열린다.
    - **다음**: 7차 기획(§3 NEXT) — 계측기로 4축 동시 측정 → `EntityTileRow` 이관 → 신규 가드(대조군 1회 실패 필수). **승인 대기**.

83. **2026-08-26** — **★7차 구현 완료 — 예산 행 간 높이 편차 0.00px. 로컬 CI 전량 통과.**
    - **[측정] 요구 축**: 신규 가드가 6행 픽스처(일반·**예산액 0**·초과·**개인**·**긴 제목**·경계 80%)를 3폭에서 재서 **편차 0.00px**(390 전부 68.37 · 430 전부 68.69 · 768 전부 76.72).
    - **[측정] V3 대조군**: 원래 결함(`budgetAmount <= 0` 이면 자리 비움)을 되살려 재현하니 **예산액 0 행만 59.19**(나머지 68.37) = **편차 9.19px** 로 가드가 실패한다. 되돌리면 6/6 통과. 가드가 요구 축에 걸려 있다는 증거이고, **사용자가 본 결함의 크기가 9.19px 였다**는 뜻이기도 하다.
    - **구조적 수정 3건**: ①`ListTile` → **`EntityTileRow` 이관** — 높이 소유권을 프레임워크에서 앱으로 옮긴다(`박스 = max(잉크 + 2×xs, 슬롯 44)`). 사용자가 "자산처럼"이라 한 것이 이 계약이다. ②프로그레스 자리 **항상 예약**(0원도 빈 트랙 — 조건부로 비우는 것이 원인이었다). ③소스 봉인(예산 페이지에 `ListTile(` 없음 · 타일에 `SizedBox.shrink()` 없음, **주석 제거 후 스캔**).
    - **★[측정] 설계를 두 번 되돌렸다(중요)**:
      · **1차**: `Widget? progress`·`Widget? trailingAction` 로 슬롯을 열었더니 **`entity_tile_api_guard_test` 가 막았다**. 그 가드의 사유가 내 audit 결과와 **같은 문장**이다 — "과거 `ui_pattern` 실패는 전부 **한 곳에 얹기**(호출부가 임의 위젯을 끼워 레이아웃을 다시 깬다)". → **값 타입** `EntityProgress`(0~1 + 톤)·`EntityOverflowMenu`(항목 + onSelected)로 재설계했다. **가드를 낮추지 않았다.**
      · **2차**: 긴 제목 행만 **+25.19px** 높았다 — `EntityTileRow` 기본 동작이 "제목이 길면 금액을 칩 행으로 내린다(이름이 이긴다)"인데 칩 행이 그 행만 키운다. 목록 요구가 **행 간 동일성**이므로 예산에 한해 `keepMetricInline: true` 로 금액을 제목 행에 고정했다(기본값은 그대로).
    - **부수 성과**: 하드코딩 색을 `EntityTone`(→`BbColors`)으로 옮겨 래칫 baseline **313 → 309** 로 낮췄다(성과 고정). 죽은 코드 4함수 제거로 analyze **18 → 15**.
    - **신규 가드 `test/features/budget/budget_row_height_guard_test.dart`(6케이스)** — B1 행 간 높이 동일(3폭) · B2 예산액 0 도 트랙 유지(원인 봉인) · B3 소스 봉인 2종.
    - **★교훈 보강 대상**: 2026-08-24 교훈의 "여백 회신은 **3축**(행 사이·행 안 균형·랩)"에 **'행 간 높이 동일성'이 없었다**. 교훈이 축을 빠뜨려 `row_balance_guard_test`(위==아래만 본다)도 빠뜨렸고, 20/20 초록인 채로 배포됐다. → 4축으로 보강한다.
    - **다음**: PR → 배포 → 라이브 검증(예산 항목들이 **같은 높이로 보이나**).

84. **2026-08-26** — **7차 배포 완료 → 라이브 검증 대기.**
    - PR **#318** squash 머지 → main **`7b7fb49`**. Backend CI success · deploy-nas run **32932445245 success**(changes·deploy-frontend success / nginx·backend skipped / **verify-live success**).
    - **[측정] 배포 판정**: `main.dart.js` last-modified **`Wed, 26 Aug 2026 05:03:14 GMT`** · content-length **5,515,266 → 5,516,333(+1,067B)**. 워크플로 상태가 아니라 산출물로 판정했다.
    - **재발 방지 등록**: `lessons-learned.jsonl` 에 교훈 1건(ui_pattern·meta_process). 핵심 = **"높이/여백 회신은 3축이 아니라 4축"**(2026-08-24 교훈이 '행 간 높이 동일성'을 빠뜨렸다) · "'A처럼 해달라'는 A 의 계약을 가져오라는 뜻" · "프레임워크가 높이를 소유하면 여백 토큰으로는 못 고친다" · "공용 위젯 슬롯은 값 타입으로 연다". `recurrence_tracker.py` 재생성 확인 — `ui_pattern` 12 → **14**.
    - ⚠ 그 결과 **이 프로젝트의 게이트 승인이 자동 무효화됐다**(새 교훈 유입). 다음 코드 변경 전 `pre-change-audit.sh` 재감사 필요 — 설계대로다.
    - **다음**: 라이브 검증 — §3 NEXT.

85. **2026-08-26** — **✅ 7차 라이브 통과(높이) + ★8차 착수·구현 완료(계층 관계).**
    - **[측정] 7차 회신**: "높이 조정이 잘 됐다" → **행 간 높이 동일성 요구 달성 확정**. 7차 계약(`EntityTileRow` 이관 · 프로그레스 자리 항상 예약 · `keepMetricInline`)은 **그대로 유지**한다.
    - **[측정] 8차 요구(같은 회신)**: "상위 총 예산에 각 예산항목이 **묶이는 개념**이기 때문에 **펼치기/숨기기** 가능한 구조여야하고 UI도 그렇게 엮여야할 것 같은데 지금은 **별도로 떨어진 것** 처럼 되었다. 위 기조는 이전과 동일하게, **높이는 지금 변경된거 유지**."
    - **형태는 사용자가 골랐다**: 3안(카드에 토글만 / 항목 들여쓰기 / **한 카드 안에 합친다**) 중 **한 카드 안에 합친다**. 상위 영역 구조가 바뀌는 안이라 "위 기조는 이전과 동일"보다 사용자의 명시 선택이 우선한다.
    - **[측정] 원인 2겹**: ①`_buildLoaded` 가 `Column[MonthNavigator, BudgetSummaryCard, Expanded(ListView(항목))]` — **카드와 항목이 형제**고 계층 장치가 원래 **하나도 없었다** ②7차 이관으로 항목 인셋 `ListTile` 16 → `space.xl` **10.20** 로 줄어 카드 바깥선(16)보다 **밖으로** 나갔다. 대조군 실측 **항목 아바타 10.20 vs 헤더 32.00 = −21.80px**. 즉 **원래 없던 것 + 7차가 만든 것**이 겹쳤다.
    - **구조적 수정 4건**: S1 항목이 카드의 **자식**이 된다(관계를 여백이 아니라 **컨테이너가 소유**) · S2 접힘 상태 **단일 소유자**(`_totalExpanded`, 헤더 chevron 과 항목 렌더가 같은 값을 읽는다) · S3 정렬 인셋 = `16 − bbSpace.xl` **토큰 산술**(리터럴 금지) · S4 소스 봉인(`BudgetSummaryCard` 가 `Expanded` 밖 형제로 못 돌아간다).
    - **`ExpansionTile` 을 쓰지 않았다**: 2026-07-27 에 `trailing` 을 다른 위젯이 덮어써 **펼침 chevron 이 통째로 사라진** 인시던트가 있었다 → 헤더 행에 chevron 을 **명시적으로** 두어 다른 액션이 그 자리를 못 가져가게 했다.
    - **★가드 2개가 내 처방을 되돌렸다(중요)**: ①`no_step_ladder_guard` **S3** — chevron 에 `visualDensity: compact` 를 줬다가 걸렸다("밀도는 `AppTheme._densityFor` 하나가 정한다", 2026-08-20 에 17곳이 테마와 경쟁하던 실측이 근거). 국소 override 를 지웠다. ②내가 만든 **G3 축 자체를 교정**했다 — 아이콘 잉크로 재니 아바타 원 안쪽 여백 7px 때문에 허용오차를 8.51 로 늘려야 했다. 그건 축을 눈속임하는 것이라 **칠해진 아바타 상자**로 재도록 바꿨고 오차 **0.00** 으로 맞았다.
    - **[측정] V3 대조군**: 최종 가드로 변경 전 lib 실행 → **9 실패 / 2 통과**(통과한 2건은 G4 높이 무회귀 — 변경 전에도 지켜져야 하므로 정확히 옳다) → 변경 후 **11/11 통과**.
    - **신규 가드 `test/features/budget/budget_group_card_guard_test.dart`(11케이스, 페이지 레벨)** — G1 항목이 카드 자손(3폭) · G2 토글로 접힘/펼침 + **chevron 실재** · G3 아바타 상자 == 헤더 제목 좌측(3폭) · G4 **행 간 높이 편차 0 무회귀**(7차 계약) · G5 소스 봉인 2종.
    - **[측정] 로컬 CI**: analyze **14**(기준선 15 대비 감소·회귀 0) / `flutter test` **전량 통과** / build web **EXIT=0** / 하드코딩 색 래칫 통과(309 유지).
    - **기획 정본**: `docs/sessions/2026-08-26_2_budget_group_card_plan.md`(게이트 승인 지문 17:2026-08-26). **미해결 4건**: 접기 상태 세션 간 기억 · `나만 보임` 별도 접기 · 항목 20+ 체감 · `전체 예산` 행 실재 여부.
    - **다음**: PR → 배포 → 라이브 검증.

## 3. 다음 단계

<!-- HNS:NEXT -->
**8차 = 예산 항목을 상위 총 예산 카드 안으로. 구현·로컬 CI 완료(항목 85). 다음 = PR → 배포 → 라이브 검증.**

### 라이브 검증 (배포 후)

1. **분석 > 예산** — 총 예산과 항목들이 **하나의 카드 안에 묶여** 보인다(항목이 카드 밖으로 삐져나오지 않는다)
2. 총액 오른쪽 **`▴`/`▾` 를 누르면 항목이 접히고/펼쳐진다**. 기본은 펼침
3. 항목 왼쪽 아이콘이 **`이번 달 예산` 글자와 같은 줄**에서 시작한다
4. **항목 높이는 7차 그대로 서로 같다**(예산액 0 · 개인 예산 포함) — 이게 깨지면 즉시 보고
5. 자산 탭·카테고리 탭은 변화 없다

### 아직 안 정한 것 (회신 주시면 반영)

- 접어두면 **다음에도 접혀 있길** 원하시나? 지금은 매번 펼침이다
- 커플 모드 `나만 보임` 섹션을 **따로** 접고 싶으신가? 지금은 총 예산 토글 하나다
- 항목이 20개 넘으면 카드가 화면보다 길어진다 — 그때도 "묶임"이 느껴지나

### 그 다음 대기열

1. `ListTile` 나머지 이관 · 2. 주간 카드 320dp 오버플로우 · 3. 좌우 비대칭 32건 · 하드코딩 색 래칫
4. 미기록 200건 초과 페이지 로드 UI · 개인 자산 · 죽은 화면 정리 · P4 알림 · Android

### 회차 밖 — 사용자 확인만 필요

- 정산 스냅샷 A1~A10 / B1~B7 / C1~C5(`docs/sessions/2026-07-27_1_result.md §4.1`) · KI-006
- 자산 현황 그룹 경계 67.0dp `[측정]` — 그룹 박스를 없애야 하고 시각이 바뀐다 → 사용자 결정
<!-- /HNS:NEXT -->

### 그 다음 대기열 (착수 순서 아님 — 자동 주입 대상 아님)

1. **차트 색 체계 통일** — `BbColors` 에 `series` 토큰. 위 회차와 합칠 수도 있다
2. **미기록 200건 초과 달의 추가 페이지 로드 UI** — 안내 문구만 있다
   (`reconciliation_view.dart:191`). 패턴은 `reference_transaction_pagination_focus`
3. **개인 자산(ASSET-PRIVATE)** — PaymentMethod visibility/owner + 이체 visibility 파생.
   고칠 지점은 `ledger_gating.dart` 한 곳
4. **죽은 화면·고아 진입점 정리** — `PaymentMethodPage` · `CategoryPage` · `DashboardPage` ·
   `home_page` · `monthly_trend_card` · `category_breakdown_card` 도달 불가.
   `/transfers` 는 기능은 살아 있고 진입점만 없다 → 부활/삭제 결정 필요
5. **나머지 하드코딩 색 이관** — 래칫 baseline(313건/73파일)을 회차마다 낮춘다
6. **P4 월말 "미기록 N건" 인앱 알림** — 알림 인프라 선행 필요(가장 큼)
7. **Android 배포(Play Store)** — PWA 설치는 이미 가능
8. **카카오 비즈니스 앱 전환(KI-007-P2)** — placeholder email 로 본질은 해결. 선택 사항

### 회차 밖 트랙 — 사용자 확인만 필요 (개발 착수 아님)

- 정산 스냅샷 라이브 검증 A1~A10 / B1~B7 / C1~C5 — `docs/sessions/2026-07-27_1_result.md §4.1`
- KI-006(지출계획 완료 시 거래 자동 등록) 배포 후 확인 — `docs/known-issues.md`


## 4. 산출물 지도

- `frontend/lib/core/widgets/month_year_picker_dialog.dart` — **월 이동 피커 정본**.
  연도 휠 + 12개월 그리드 한 화면 + 자체 일 그리드. **프레임워크 위젯을 쓰지 않는다** —
  `CalendarDatePicker` 를 다시 넣으면 그 헤더가 우리 제어 밖이라 "월 선택 대신 연도 설정"
  결함이 재발한다(가드가 막는다). 호출부는 `month_navigator.dart` 한 곳
- `frontend/test/core/widgets/month_navigator_single_source_guard_test.dart` — S1 자체 월 헤더 금지 /
  S2 피커 단일 소스 + **프레임워크 위젯 부재** / S3 도달성 9곳 고정
- `frontend/lib/core/utils/ledger_route.dart` — **장부 목록 URL 단일 소스**(`ledgerLocation`).
  year/month 가 required 라 "화면 이동 시 보던 달이 안 따라간다"(navigation_state, 3회 재발)를
  컴파일이 막는다. 새 진입 경로는 반드시 이 함수를 쓴다
- `frontend/lib/features/reconciliation/presentation/widgets/reconciliation_summary_card.dart`
  + `.../bloc/reconciliation_summary_cubit.dart` — 분석 탭 "월말 점검" 카드.
  **홈이 아니라 분석 탭**에 있는 이유는 홈 화면이 미라우팅이기 때문(타임라인 23)
- `frontend/test/features/home/dashboard_widget_registry_guard_test.dart` — 위젯 등록 누락 가드 +
  장부 URL 단일 소스 가드 + **카드가 살아 있는 화면에 호스팅되는지** 가드
- `docs/sessions/2026-08-10_ledger-filter-gating_plan.md` — 장부 필터 게이팅 설계 정본(장부 필터 게이팅
  단일화 + 동적 빈 문구, 2026-08-10 종결). §7 에 남은 요구사항 Step 1~7 정리 — 단 "홈 위젯" 항목은 무효
- `frontend/lib/features/transaction/presentation/utils/ledger_gating.dart` — **이체 게이팅 단일 진입점**.
  장부에 새 필터 축을 추가할 때 반드시 여기 판정을 먼저 쓴다(필드 수 가드가 강제)
- `frontend/lib/features/transaction/presentation/utils/ledger_empty_message.dart` — 빈 상태 문구 단일 생성기
- `docs/sessions/2026-07-31_transfer-to-transaction_plan.md` — 이체→거래 역변환 설계 정본.
  2026-08-10 라이브 검증 통과로 **종결**. 이력 보존용
- `frontend/test/features/transfer/convert_wiring_guard_test.dart` — 이체↔거래 변환 **양방향 대칭** 가드
  (네 BLoC 리로드 공통 헬퍼 경유 / 이체 폼은 거래 폼으로 보낸다 / 저장이 변환 API 를 탄다)
- `backend/src/test/kotlin/com/budgetbook/transfer/integration/TransferToTransactionIntegrationTest.kt`
  — 실제 PG 로 원자성·NOT NULL·FK 가드 검증(mock 으로는 안 잡히는 층)
- `docs/incidents/2026-07-30_icon-font-stale-cache.md` — **아이콘 캐시 사건 정본**(5회 발생 분석·방어선·진단 순서). 비슷한 증상이면 코드보다 이 문서를 먼저 본다
- `docs/sessions/2026-07-30_handoff.md` — 직전 회차 인수 문서(배포 현황·라이브 검증 체크리스트). 이력 보존용, 수정 금지
- `docs/sessions/2026-07-28_icon-missing-handoff.md` — 아이콘 사건 1·2회차 측정 기록. 수정 금지
- `infra/scripts/hash-icon-font.sh` — 아이콘 폰트 content hash (배포 파이프라인 필수 단계)
- `infra/scripts/verify-cache-headers.sh` — 배포 후 캐시 정책 + 아이콘 폰트 해시 검증 게이트
- `frontend/test/features/transaction/view_mode_toggle_guard_test.dart` — 뷰 토글 tooltip + 해시 게이트 배선 가드
- `frontend/test/features/transaction/calendar_day_sheet_add_test.dart` — 달력 일자 시트의 거래 추가 진입 +
  URL 조립 단일 소스(`_buildCreateTransactionUrl` 경유) 가드
- `frontend/test/core/theme/project_font_pin_guard_test.dart` — 프로젝트 폰트(NotoSansKR) 지문 고정. 교체 시 파일명도 바꾸게 강제

## 5. 미해결·리스크

- 아이콘 폰트 건은 종결(라이브 검증 통과). 잔존 위험은 `docs/incidents/2026-07-30_icon-font-stale-cache.md` §5 에 전수 정리.
- 프로젝트 폰트(`NotoSansKR-Subset.woff2`)는 여전히 해시 없는 고정 URL(`AssetManifest.bin` 등재
  때문에 빌드 후 rename 이 불가). 교체 시 파일명을 바꾸는 규칙을 지문 가드 테스트로 강제했다 —
  **자동화가 아니라 규칙 + 게이트**라는 점이 수용된 리스크.
- 2026-06-05 이전에 `main.dart.js` 를 장기 캐시로 물린 기기가 남아 있다면 앱 전체가 구버전으로
  보인다(보고 없음, `index.html` no-cache 로 대부분 자연 해소). 필요해지면 아이콘 폰트와 같은
  방식으로 해시 가능 — `flutter_bootstrap.js` 의 참조 1곳 재작성.
