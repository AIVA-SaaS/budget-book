# 합계 ≠ 행 불일치 (장부 합계·행 단일 소스화) — 결과

> 날짜: 2026-08-13 | 회차: "합계 ≠ 행" | 상태: **완료 (사용자 라이브 검증 전부 통과)**
> 정본 문서: 분석 `2026-08-12_1_summary-row-mismatch_analysis.md` / 기획 `2026-08-12_2_summary-row-mismatch_plan.md`

---

## 1. 무엇을 고쳤나

행 집합과 합계 집합이 **같은 소스에서 나오지 않던 것**을 서버 단일 지점으로 통합했다.

- 서버는 거래를 **범위 전체**로 세고, 클라는 이체를 **포커스 월**로만 들고 있었다 →
  기간 필터가 월을 넘으면 범위 내 이체 금액의 **77% 가 합계에서 누락**(발현 결함 F1)
- 합계 API 는 필터가 걸리면 `totalTransfer = 0` 을 하드코딩하고 있었다(죽은 값이 아니라
  기간 장부에서 실제로 노출되는 경로였다)
- FE `gateLedger` 가 이체 축을 **자체 판정**하고 있어 판정 지점이 2곳이었다 = 재발 메커니즘

## 2. 변경 사항

- BE 신설 `common/filter/LedgerFilterAxis.kt` — 필터 축 20개 enum + `TransferAxisHandling`.
  `TransferGating.handling` 의 exhaustive when 이 **축 추가 시 컴파일을 막는다**
- BE 신설 `common/filter/LedgerTypeSelection.kt` — `transactionTypes` 파싱 단일 진입점.
  `TRANSFER` 가 계약 값으로 승격(이전엔 400). "필터 없음" vs "거래 타입 0개 선택" 구분
- BE 신설 `transfer/service/TransferGating.kt` — 이체 판정 단일 지점.
  `excludedWholesale` + `spec` 을 **목록 조회와 집계가 공유**
- BE 수정 `StatisticsService` — `hasContentFilters` 분기 제거, `totalTransfer = 0L` 삭제.
  `getMonthlySummary` · `getPeriodSummary` 를 `resolveTransactionScope` 로 통일
- BE 수정 `ExpenseCalculator`(kind 별 버킷) · `TransferRepository`(JpaSpecificationExecutor) ·
  응답 `transferCount` 추가 · 컨트롤러의 필드 수동 나열 제거(필터 VO 통째 전달)
- FE 신설 `LedgerTransfersCubit` — 장부 전용 이체 소스. 공유 `TransferBloc`(소비자 6곳) 무변경
- FE 수정 `ledger_gating.dart` — **이체 축 판정 삭제**(서버 신뢰)
- FE 수정 합계바 3칸 전부 서버 단일 소스(`serverTotalTransfer`). 클라 `LedgerSummary` 는
  러닝밸런스 전용으로 축소
- FE 신설 `ledger_totals_exclusion.dart` + `ExcludedFromTotalsBadge` — ADJUSTMENT·카드정산 행
  "합계 제외" 배지(판정은 단일 헬퍼 경유)
- 계약 문서 **선행** 갱신 `docs/api-spec.md` — summary 필터 파라미터 12개+ 문서화 ·
  "필터 시 totalTransfer 항상 0" 규범 폐기 명시 · List Transfers 범위·필터 · `TRANSFER` 계약 값
- DB 마이그레이션 **0건**(스키마 변경 없음)

## 3. 커밋 / PR / 배포

- PR **#297** (squash `027e8f7`) — fix(ledger): 합계와 행이 같은 집합을 세도록 이체 판정을 서버 단일 지점으로 통합
- 원격 CI: `backend-ci` pass(4m23s) / `frontend-ci` pass(3m16s)
- `deploy-nas.yml` run **31657145604 success** (changes / deploy-frontend / deploy-backend /
  verify-live 전부 success · nginx 무변경으로 sync-nginx skipped)
- 라이브 번들 `main.dart.js` last-modified **2026-08-13 01:18:30 GMT**

## 4. 자동 검증 결과

- BE `./gradlew clean test` — PASS. 신설 `LedgerSummaryRowContractIntegrationTest`
  (실 PostgreSQL, 축 조합 **15건**: 합계 = 행 대조 + 절대값 고정) ·
  `LedgerFilterAxisGuardTest`(리플렉션 1:1) · `TransferGatingTest` · `LedgerTypeSelectionTest`
- FE `flutter analyze`(전체) — 신규 0건(잔여 3건은 미변경 테스트 파일 기존 info)
- FE `flutter test` — **936건 PASS**. 신설 `ledger_transfers_cubit_test.dart` ·
  `ledger_gating_test.dart` 재작성(FE 이체 판정 재도입 금지 + 장부의 `TransferBloc` 사용 금지 가드)
- `flutter build web --release` — PASS
- 배포 전 번들 문자열 확인 — `합계 제외` 1건 + 배지 툴팁 2건 존재
- 배포 후 `verify-live` — success

**구현 중 테스트가 잡은 실제 버그 1건**: "타입 필터 없음" 과 "타입 필터가 거래를 하나도 고르지
않음"(= 이체만 보기)을 혼동해 이체만 보기에서 거래 합계가 남았다 → `hasTypeFilter` 로 분리,
`LedgerTypeSelectionTest` 가 회귀 가드.

## 5. 사용자 라이브 검증 결과 — **A1~A11 전부 PASS**

- A1 기간 `2026-06-15 ~ 2026-08-05` 이체 행·합계 — PASS
- A2 합계 = 행(수입·지출·이체) — PASS
- A3 결제수단 다중(출금·입금 어느 쪽이든) — PASS
- A4 금액 범위 — PASS
- A5 검색어(설명 · 출금/입금 결제수단명) — PASS
- A6 카테고리 / 포켓 / 확인 필요만 / 개인 → 이체가 행·합계에서 함께 사라짐 — PASS(4축 각각)
- A7 유형 "이체" 단독 → 거래 0건, 수입·지출 0원 — PASS
- A8 유형 "지출 + 이체" — PASS
- A9 ADJUSTMENT · 카드정산 이체 행의 "합계 제외" 배지 — PASS
- A10 사이드이펙트 없음(이체 수정 · 카드정산 · 정산 뷰 · 거래 폼) — PASS
- A11 분석 탭 일관성 — PASS

## 6. 검증 과정에서 발생한 오판 1건 (기록 — 코드 결함 아님)

첫 A1 보고는 **실패**였다(이체 1,008,648원). 스크린샷에 **"오프라인 - 실시간 동기화 중단"
배너**가 떠 있었고, 재연결 후 재확인하니 통과했다.

- 원인: 검증 지시서에 **"온라인 상태 선행 확인"** 단계가 없었다. 오프라인이면 화면이 이전
  데이터를 그대로 보여주므로 **수정 전 수치와 구분되지 않는다** — 배포 미반영과 증상이 동일하다
- 조치: 앞으로 라이브 검증 체크리스트는 **0단계에 "오프라인 배너 없음 확인(있으면 재연결)"** 을
  고정한다. 번들 `last-modified` 확인만으로는 부족하다(서버는 최신인데 클라가 끊겨 있는 상태를
  못 걸러낸다). 메모리 `feedback_live_verification_online_precheck` 로 등록

## 7. 검증 지시서에서 드러난 문서 오류 2건 (정정 완료)

- 기획서 §8 A10 이 확인 대상으로 적은 **"이체 목록 화면"(`/transfers`)은 도달 불가**다 —
  유일한 진입점이 죽은 화면 `PaymentMethodPage` 다 `[측정]`. 대체 경로(장부에서 이체 행 탭 →
  `/transfers/edit/:id`)로 확인했다. 카드정산 화면은 **거래 탭에서 신용카드 1개 필터 시
  나타나는 "결제" FAB** 로 도달한다
- 필터 시트 섹션 순서는 유형 → 공개 범위 → 기간 → **금액** → 카테고리 → 결제수단 → 포켓 →
  확인/입력 필요만 이다(금액이 맨 뒤가 아니다). 필터 진입 아이콘은 깔때기가 아니라 **`tune`
  (슬라이더)** 이다

## 8. 재사용 가치 (knowledge 캐시 등록)

- `~/.claude/projects/.../knowledge/ledger-summary-row-single-source.md` —
  "합계와 행이 다르다" 류 증상의 진단 순서와 구조적 해법(축 enum + exhaustive when +
  목록·집계 공유 spec + 계약 통합테스트)

## 9. 발견된 추가 이슈 (후속)

- 차트 시리즈 팔레트가 파일마다 복제되고, **차트는 수입을 그린 / 장부는 수입을 블루**로 그린다
  `[측정]` → 다음 회차(자산 탭·색상)에서 만드는 `BbColors` 에 `series` 토큰으로 통합 검토
- 죽은 화면 6개(`PaymentMethodPage` · `CategoryPage` · `DashboardPage` · `home_page` ·
  `monthly_trend_card` · `category_breakdown_card`) 정리 여부는 홈 탭 복원 결정과 함께 판단
- `/transfers`(이체 목록) 는 기능은 살아 있는데 진입점이 없다 — 되살릴지 삭제할지 결정 필요
