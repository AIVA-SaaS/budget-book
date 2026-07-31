# Budget Book (aiva-bb) 진행 이력 대장

> **이 파일이 진행 상황의 단일 진입점이다.** `/clear` 후에도 이 파일 하나면 어디까지 왔는지 복원된다.
> SessionStart 훅 `progress-resume.py` 가 아래 STATE·타임라인 꼬리·NEXT 를 자동 주입한다.
> 실질 진전(산출물 생성·게이트 통과·결정 확정·실패)마다 §2 타임라인에 append. **무기록 변경 금지**.

---

## 1. 현재 상태 (한눈에)

<!-- HNS:STATE -->
- **단계**: 새 회차 **"이체 → 거래 역변환" 기획 완료 · 사용자 승인 대기**. 코드 변경 0줄
- **상태**: blocked (승인 대기 — 코드 편집 시작 금지)
- **정본 문서**: `docs/sessions/2026-07-31_transfer-to-transaction_plan.md` (§0 에 재부팅 후 재개 절차)
- **repo / 브랜치**: `AIVA-SaaS/budget-book` · main = 이 기획 문서 커밋 · 작업 트리 clean, 실행 중 프로세스 없음
- **CI 3종**: 직전 회차 기준 전부 통과(이번 회차는 아직 코드 없음)
- **blocker**: 사용자 승인 1건 (승인되면 계획서 §2 부터 추가 승인 없이 자동 진행)
- **갱신**: 2026-07-31
<!-- /HNS:STATE -->

## 2. 타임라인 (append-only)

> 형식: `N. **YYYY-MM-DD** — 한 줄 요약.` + 하위 불릿(산출물 / 게이트 결과 / 결정 / 실패·인시던트).
> 지우지 않는다. 틀린 기록은 지우지 말고 다음 항목에서 정정한다.

1. **2026-07-30** — 대장 신설. 이전 이력은 `docs/sessions/` 회차 문서가 보유(#277~#280 배포 완료,
   남은 것은 사용자 라이브 검증 5건).
   - 산출물: 이 파일
   - 결정: 앞으로 진행 기록은 이 대장이 단일 진입점

2. **2026-07-30** — "정산 아이콘만 안 나온다" 3회차 — 근본 원인 확정 + 구조적 fix.
   - 측정(hard evidence): 라이브 폰트(37,276B / 293글리프)에 `fact_check 0xE256` **존재**,
     `list 0xE384`·`calendar_month 0xF06BB` 도 존재. `index.html`·`main.dart.js`·`FontManifest.json`·
     `.otf` 전부 `no-cache, must-revalidate`. Service Worker 는 이미 비활성(`--pwa-strategy=none`).
     빌드 산출물 어디에도 폰트 파일명 하드코딩 없음(`FontManifest.json` 참조 2건).
   - 진단: 캐시 정책이 아니라 **URL 신원 ≠ 내용 신원**. 트리셰이킹 아이콘 폰트는 내용이 빌드마다
     바뀌는데 URL 이 `assets/fonts/MaterialIcons-Regular.otf` 로 고정 → nginx 가 이 URL 을
     `immutable` 로 내보내던 시절(2026-07-27 이전)에 캐시한 기기는 **재검증 요청조차 하지 않아**
     정산 도입 이전 subset 을 계속 사용 → 0xE256 만 빈칸. 헤더 fix(#277)로는 도달 불가.
   - 결정(사용자 승인): 폰트 파일명 content hash + 뷰 토글 텍스트 라벨 제거를 한 PR 로.
     라벨 제거는 해시 fix 가 전제 — 순서를 뒤집으면 stale 폰트 기기에서 정산 칸이 완전히 빈칸.
   - 산출물: `infra/scripts/hash-icon-font.sh`(신설) / `verify-cache-headers.sh` 해시 검증 추가 /
     `deploy-nas.yml` 배선 + FE 트리거 경로 / `_ViewModeToggle` 아이콘 전용 /
     `view_mode_toggle_guard_test.dart` 재작성(tooltip + 해시 게이트 배선 고정) /
     `ops/nas-nginx/aiva-bb.conf` 주석 갱신
   - 게이트: 합성 픽스처 + **실제 `flutter build web` 산출물**에서 rename·manifest 재작성·재실행
     안전성 확인 / analyze 통과 / test 805건 통과
   - 재발 방지: 해시 단계가 빠지면 배포 후 `verify-cache-headers.sh` 가 실패(FontManifest 경로의
     해시 패턴 검사), 워크플로 배선이 빠지면 `flutter test` 가 실패

3. **2026-07-30** — 커밋 → PR 생성 → 머지 → 배포 진입.
   - 커밋: `fix(deploy): 아이콘 폰트 파일명에 content hash …` (a0de353)
   - 함께 반영: `CLAUDE.md` 볼트 배선 안내(직전 회차 커밋 누락분)
   - 배포 트리거: `.github/workflows/deploy-nas.yml` 변경 → BE·FE·nginx 3개 job 전부 실행

4. **2026-07-30** — PR #281 원격 CI 통과 → 머지·배포.
   - CI: `backend-ci` pass / `frontend-ci` pass (2m2s)
   - 머지: squash + branch 삭제 (개인 계정 자동 진행 승인 범위)
   - 배포 후 자동 검증: `verify-live` job = nginx drift + `verify-cache-headers.sh`
     (아이콘 폰트 URL 의 content hash 존재 포함)

5. **2026-07-30** — 배포 성공 + **서버 측 검증 완료**. 남은 것은 사용자 기기 확인.
   - deploy-nas run 30507251616: changes/deploy-backend/deploy-frontend/sync-nginx/**verify-live 전부 success**
   - 라이브 `FontManifest.json` → `fonts/MaterialIcons-Regular.309eccd00f9c.otf`
     (로컬 빌드 해시와 동일 = 결정적), 그 URL 200 · `no-cache, must-revalidate` ·
     cmap 에 `0xE256`·`0xE384`·`0xF06BB` 존재
   - **옛 고정 URL `/assets/fonts/MaterialIcons-Regular.otf` → 404** (stale 캐시가 가릴 대상 자체가 사라짐)
   - 서빙 번들에서 정산 세그먼트 확인: `new A.a5(57942,"MaterialIcons")` + `size 18` +
     `label = null` + tooltip `"정산 보기 …"` → **아이콘 전용 + tooltip** 로 배포됨
   - 재발 방지 등록: `~/.claude/harness/lessons-learned.jsonl` (deployment_cache, ui_pattern) +
     `recurrence_check.py` 프로젝트 귀속 버그 fix(`.` 호출 시 자기 인시던트를 타 프로젝트로 집계)

6. **2026-07-30** — **사용자 라이브 검증 통과 ("모두 잘 된다") → 이번 회차 종결.**
   - 정산 아이콘 노출 확인 (아이콘 전용 토글, 하드 리프레시 없이 새 폰트 URL 수신)
   - 함께 확인: 날짜 그룹 헤더 / 전체 선택 체크박스 / 스냅샷 펼침 액션 /
     잔액 수정(ADJUSTMENT) 정산 제외 / 거래 → 이체 변환 (2026-07-27_2_result.md §3)
   - 이로써 PR #277 ~ #282 회차 전체가 "완료" 판정. 열린 작업 없음.

7. **2026-07-30** — 아이콘 재발 방지 **철저 정리**(사용자 지시). 코드 동작 변경 없음.
   - 정본 문서 신설: `docs/incidents/2026-07-30_icon-font-stale-cache.md`
     (5회 발생 타임라인 / 근본 원인 / 3·4회차 진단 오류 해부 / 방어선 4겹 / 잔존 위험 전수 /
     5분 진단 순서 / 다른 프로젝트에도 쓰는 일반 규칙)
   - 측정 2건 추가: ① pre-#277 nginx conf 확인 — `immutable` 은 **폰트 확장자에만** 걸려 있었고
     `FontManifest.json` 은 항상 no-cache → **옛 폰트 URL 404 는 안전**(manifest 고착 불가).
     ② 산출물 41개 전수 헤더 확인 — 전부 `no-cache, must-revalidate`, immutable 0건.
   - 같은 위험군 1건 발견·차단: `NotoSansKR-Subset.woff2` 도 해시 없는 고정 URL + 재생성
     스크립트 존재 → 교체 시 두부(□) 재발 가능. `project_font_pin_guard_test.dart` 가 sha256 을
     고정하고 실패 메시지로 "파일명 버전 올리고 pubspec 갱신" 3단계를 지시(음성 경로 검증 완료).
   - `verify-cache-headers.sh` 검사 대상 7종 → **21종**(유형별 대표 경로 전부: canvaskit·wasm·
     shader·아이콘 PNG·프로젝트 폰트·AssetManifest·정적 html). 라이브 전수 통과 확인.

8. **2026-07-30** — PR #284 머지·배포 성공 → **이 회차 완전 종결. `/clear` 안전.**
   - deploy run 30528256355: deploy-frontend success / **verify-live success**
     (확장된 21종 캐시 검사 + 아이콘 폰트 해시 검사 전부 통과)
   - 라이브 폰트 해시 `309eccd00f9c` 유지(아이콘 구성 동일 = 결정적), 옛 고정 URL 404 유지
   - 다음 세션은 이 대장 §3 "다음 회차 후보 — 착수 지점" 에서 시작한다

9. **2026-07-31** — 새 회차 **"이체 → 거래 역변환" 기획 완료**(승인 대기). 코드 변경 0줄.
   - 사용자 요청: "PC 재부팅 후 이어서 진행할 수 있게 준비·세팅" → 기획과 상태를 **문서로 고정**
   - 산출물: `docs/sessions/2026-07-31_transfer-to-transaction_plan.md` (설계 정본 —
     재개 절차 / 측정 사실 8건 / API 계약 / BE·FE 설계 / 테스트 / 로컬 CI)
   - 측정(hard evidence): `transfers` FK 참조는 **2개뿐**(`transactions.settlement_transfer_id` V63,
     `reconciliation_items.transfer_id` V65, 둘 다 SET NULL) · `Transfer` 에 visibility/owner 없음
     (거래 생성은 visibility 를 카테고리에서 파생) · `updateTransfer` 는 이미 CARD_SETTLEMENT 차단 ·
     `createTransaction` 은 카테고리-유형 일치 검증을 **안 한다**(update 경로에만 있음) ·
     FE `getTransfer(id)` 이미 존재(새로고침 안전 prefill 가능)
   - 설계 결정 3건: ① 순환 의존 회피 — `TransactionService.convertFromTransfer` + `TransferController`
     호출(반대는 순환) ② 승계 규칙(결제수단: EXPENSE→출금 / INCOME→입금) ③ FE 는 이체 폼에서
     거래 폼으로 push(피커 복제 금지 — 거래 폼이 이미 양쪽 폼 보유)
   - 기획 중 발견한 기존 결함 1건: 정방향 변환이 Dashboard·PaymentMethod BLoC 을 리로드하지 않음
     → 같은 PR 에서 양방향 공통 처리로 수정 예정
   - 게이트: `pre-change-audit.sh . "amount_calculation ui_pattern navigation_state"` → OK / gate OPEN
   - **다음 단계는 사용자 승인** — 승인 전 코드 편집 금지(§2 게이트)

## 3. 다음 단계

<!-- HNS:NEXT -->
- **다음 액션**: 사용자가 기획을 **승인**하면 `docs/sessions/2026-07-31_transfer-to-transaction_plan.md`
  §4(백엔드) → §5(프론트) → §6(테스트) → §7(로컬 CI) 순서로 구현한다. 승인 전에는 코드 편집 금지.
- **재부팅 후 첫 명령**: 계획서 §0 (cwd = 이 repo, `git switch main && git pull`, 이 STATE 확인)
- **선행 조건**: 승인 1건. 유실 위험 없음(로컬 실행 프로세스 없음, 작업 트리 clean)
- **완료 판정**: BE 4파일 + FE 5파일 + 문서 2 + 테스트 4 반영 → 로컬 CI 3종 통과 → PR 머지 →
  **사용자 라이브 검증**(이체 폼에서 지출/수입 선택 → 거래로 변환 → 장부 목록에서 이체 사라지고
  거래로 표시 + 월 합계·자산 잔액 즉시 갱신)
- **다른 후보로 바꾸려면**: 아래 후보 2~5 중 지정. 기획서는 남겨두면 그대로 재사용 가능.

### 다음 회차 후보 — 착수 지점 (이 절만 읽으면 바로 시작 가능)

1. **이체 → 거래 역변환** — ⏳ **기획 완료(2026-07-31) · 승인 대기.**
   상세 설계는 `docs/sessions/2026-07-31_transfer-to-transaction_plan.md` 가 정본이다(이 요약보다 우선).
   - 계약: `POST /api/v1/transfers/{id}/convert-to-transaction` → `ApiResponse<TransactionResponse>`
   - 구현 위치: `TransactionService.convertFromTransfer` + `TransferController` 에서 호출
     (반대로 넣으면 `TransactionService → TransferService` 기존 주입과 **순환 의존**)
   - 차단 3종: 정산 기록됨 / `kind == CARD_SETTLEMENT` / 결제 링크 잔존
   - 함정 선반영: `transfers.description` 은 nullable, `transactions.description` 은 NOT NULL →
     승계 결과가 비면 400 으로 먼저 막는다(안 하면 DB 제약 500)
   - FE: 이체 폼 유형 선택기 → 거래 폼(`convertFromTransferId`)으로 push. 거래 폼이 이미 양쪽 폼을
     다 갖고 있어 피커 복제를 피한다
   - 같이 고칠 기존 결함: 정방향 `_convertToTransfer` 가 Dashboard·PaymentMethod BLoC 을 리로드하지
     않는다 → 네 BLoC 리로드를 양방향 공통 헬퍼로 (`feedback_common_scope_audit`)
2. **P6 홈 대시보드 "미정산 N건" 위젯** (추천 2순위. 기존 API 재사용)
   - 데이터: `GET /reconciliations/summary` (이미 존재, `unrecordedCount`)
   - 위젯 등록: `frontend/lib/features/home/domain/entities/dashboard_widget_config.dart`
     + `features/home/presentation/widgets/` (기존 `monthly_trend_card.dart` 패턴 따르기)
   - 주의: 위젯 ON/OFF·순서 설정에도 새 위젯이 반영되는지 전수 확인(`feedback_feature_impact_check`)
3. **미기록 200건 초과 달의 추가 페이지 로드 UI**
   - 현재는 안내 문구만: `reconciliation_view.dart:191` (+ 배경 주석 `:29`)
   - BLoC: `reconciliation_bloc.dart:24` — 클라 필터링 금지 전제가 주석에 명시돼 있다
   - 거래 목록의 LoadMore 패턴 참조: `reference_transaction_pagination_focus`
4. **P4 월말 "미기록 N건" 인앱 알림** — 알림 인프라가 없어 선행 작업이 크다(가장 큰 후보)
5. **Android 배포(Play Store)** — PWA 설치는 이미 가능(`reference_pwa_android_installable`)
<!-- /HNS:NEXT -->

## 4. 산출물 지도

- `docs/sessions/2026-07-31_transfer-to-transaction_plan.md` — **현재 회차 설계 정본**(이체→거래 역변환).
  재부팅/`/clear` 후 이 대장 다음으로 읽을 문서. 승인 시 이 문서 순서대로 구현한다
- `docs/incidents/2026-07-30_icon-font-stale-cache.md` — **아이콘 캐시 사건 정본**(5회 발생 분석·방어선·진단 순서). 비슷한 증상이면 코드보다 이 문서를 먼저 본다
- `docs/sessions/2026-07-30_handoff.md` — 직전 회차 인수 문서(배포 현황·라이브 검증 체크리스트). 이력 보존용, 수정 금지
- `docs/sessions/2026-07-28_icon-missing-handoff.md` — 아이콘 사건 1·2회차 측정 기록. 수정 금지
- `infra/scripts/hash-icon-font.sh` — 아이콘 폰트 content hash (배포 파이프라인 필수 단계)
- `infra/scripts/verify-cache-headers.sh` — 배포 후 캐시 정책 + 아이콘 폰트 해시 검증 게이트
- `frontend/test/features/transaction/view_mode_toggle_guard_test.dart` — 뷰 토글 tooltip + 해시 게이트 배선 가드
- `frontend/test/core/theme/project_font_pin_guard_test.dart` — 프로젝트 폰트(NotoSansKR) 지문 고정. 교체 시 파일명도 바꾸게 강제

## 5. 미해결·리스크

- 아이콘 폰트 건은 종결(라이브 검증 통과). 잔존 위험은 `docs/incidents/2026-07-30_icon-font-stale-cache.md` §5 에 전수 정리.
- 프로젝트 폰트(`NotoSansKR-Subset.woff2`)는 여전히 해시 없는 고정 URL(`AssetManifest.bin` 등재
  때문에 빌드 후 rename 이 불가). 교체 시 파일명을 바꾸는 규칙을 지문 가드 테스트로 강제했다 —
  **자동화가 아니라 규칙 + 게이트**라는 점이 수용된 리스크.
- 2026-06-05 이전에 `main.dart.js` 를 장기 캐시로 물린 기기가 남아 있다면 앱 전체가 구버전으로
  보인다(보고 없음, `index.html` no-cache 로 대부분 자연 해소). 필요해지면 아이콘 폰트와 같은
  방식으로 해시 가능 — `flutter_bootstrap.js` 의 참조 1곳 재작성.
