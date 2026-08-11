# Budget Book (aiva-bb) 진행 이력 대장

> **이 파일이 진행 상황의 단일 진입점이다.** `/clear` 후에도 이 파일 하나면 어디까지 왔는지 복원된다.
> SessionStart 훅 `progress-resume.py` 가 아래 STATE·타임라인 꼬리·NEXT 를 자동 주입한다.
> 실질 진전(산출물 생성·게이트 통과·결정 확정·실패)마다 §2 타임라인에 append. **무기록 변경 금지**.

---

## 1. 현재 상태 (한눈에)

<!-- HNS:STATE -->
- **단계**: **"월말 점검(미기록 N건) 카드"** 회차 — PR #293(홈 전제 오류) → PR #294(분석 탭 이전)
  → 배포 → **사용자 라이브 검증 통과 = 완료**(2026-08-11, 타임라인 26)
- **상태**: **열린 작업 없음.** 다음 회차는 아래 §3 에 착수 지점까지 고정돼 있다
- **회차 경계**: 다음 회차는 **`/clear` 후 새 세션**에서 시작한다
- ⚠ **이 앱에 홈 대시보드 화면은 없다** — `/home` → `/transactions` redirect,
  `DashboardPage` 는 미라우팅(죽은 코드), 탭 4개(거래·분석·자산·더보기).
  설정의 "홈 화면 구성" 도 고아 항목이다. **홈 위젯 전제의 계획·후보는 전부 무효**
  (메모리 `reference_dead_home_dashboard`)
- **정본 문서**: 종결 회차 = `docs/sessions/2026-08-10_2_reconciliation-widget_plan.md` /
  **다음 회차 = `docs/sessions/2026-08-10_3_month-navigator_plan.md`**
- **repo / 브랜치**: `AIVA-SaaS/budget-book` · `main` = `49fccfa` 이후 · 작업 트리 clean
- **CI 게이트(4종 + 1)**: analyze 신규 0 / flutter test **894** / `./gradlew test` /
  `build web --release` + **배포 전 번들 문자열 확인**(신규 UI 가 트리셰이킹되지 않았는지).
  마지막 항목은 이번 회차에서 추가됐다
- **blocker**: 없음
- **갱신**: 2026-08-11
- **`/clear` 안전**: 이 상태에서 컨텍스트를 비워도 §3 "다음 액션" 만 보면 이어서 진행 가능
- 이력 재작성(2026-08-06, 회사 이메일 제거)은 **푸시 완료** — 전 커밋 SHA 가 바뀌었으므로 다른 기기의
  기존 클론은 pull 이 아니라 **재클론**. 백업 `~/backup/git-email-rewrite-20260806/budget-book.bundle`
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

- **2026-08-06** — **git 이력의 회사 이메일 전량 제거(코드·문서 내용 변경 0).** 이 저장소 이력의 `donghyunele@wemeetmobility.com` **352건**(author+committer, 2026-02-25~07-30)을 `kdh-92 <kdh920411@gmail.com>` 로 치환. 기획·코드와 무관한 **위생 작업**이며 승인 게이트(§2)와 별개다.
  - 배경: 전역 `~/.gitconfig` 기본 `[user]` 가 회사 이메일이고 `~/.gitconfig-wemeet` 도 **같은 이메일**이라 includeIf 계정 분리가 실질적으로 분리를 못 했다. 같은 날 전역 기본값을 개인 계정으로 교정(재발 차단) + 이 repo 는 별도 로컬 고정 불필요.
  - 범위 결정: 6월 이후 5건만 고쳐도 이후 SHA 는 어차피 전부 바뀌는데 2~6월 291건이 남는다 → **전체 정리(A안)** 선택.
  - 검증: 잔여 오염 **0건** · 커밋 **707 → 707** · 태그 **33 → 33** · main **557 → 557** · **`git diff` 공백 = 파일 내용 완전 동일**.
  - ⚠ **푸시 대기.** `~/backup/git-email-rewrite-20260806/push-budget-book.sh` 로 민다. **`git push --all` 금지** — 로컬 91개 중 **39개가 원격에서 이미 삭제된 브랜치**라 `--all` 은 그것들을 되살린다(babylog 에서 실제 발생·원복). 스크립트가 원격 실재 **52개만** 명시해 밀고, 사전에 원격 목록 일치까지 대조한다.
  - ⚠ **이 저장소는 `.git/config` 에 `user.email = donghyunele@wemeetmobility.com` 로컬 override 를 갖고 있었다** — 전역 교정만으로는 안 막혔고, 실제로 이 대장 커밋이 회사 이메일로 한 번 들어갔다가 amend 로 정정됐다. **`git config --local user.email kdh920411@gmail.com` 으로 고정 완료.**
    - 발견이 늦은 이유: 앞선 전수 스캔이 `find -maxdepth 5` 라 깊이 6인 이 경로를 **아예 훑지 않았다**(스캔이 "없음"을 반환해 안전하다고 오판). 깊이 8로 재스캔한 결과 회사 이메일 로컬 override 는 **이 저장소 하나**였다.
    - 교훈: "스캔 결과 0건"은 **스캔 범위가 대상을 덮었을 때만** 근거가 된다. 범위를 먼저 검증할 것.
  - 남은 이력 이슈(별건): `kdh929624@gmail.com` **21건**. 회사 이메일은 아니라 이번 범위 밖 — 정리 여부는 사용자 판단.

10. **2026-08-09** — **달력 일자 시트에 "거래 추가" 진입 신설**(별건 소규모 회차. 역변환 회차와 파일 무겹침).
   - 사용자 지적: "거래 > 달력에서 거래 클릭해서 별도 노출될 때 거래를 추가할 수 없다"
   - 측정(hard evidence): `TransactionCalendarView` 가 받는 콜백은 `onTransactionTap`/`onTransferTap`
     **둘뿐**이었고 일자 시트(`_showDayBottomSheet`) 안에 추가 어포던스가 **전무**(빈 날은 `'거래 없음'`
     텍스트만). 시트가 모달이라 페이지 FAB 을 배리어로 덮어 그 상태에서 추가 불가, 시트를 닫고 FAB 을
     눌러도 `_buildCreateTransactionUrl(tab:)` 만 호출돼 **선택 일자가 승계되지 않았다**.
     목록 모드에는 `_DateHeader.onAddTap` → `_buildCreateTransactionUrl(date:)` 로 이미 있던 진입 —
     **달력에만 빠진 대칭 결함**(`feedback_common_scope_audit` 유형)
   - 공통 범위 전수: `TableCalendar` 사용처 **1곳**(이 위젯뿐) · `LedgerDateHeader` 소비처 2곳 중
     목록 페이지는 이미 보유, 정산 뷰는 그룹 체크박스 선택용이라 추가 진입 대상 아님 → **수정 2파일 확정**
   - 산출물: `transaction_calendar_view.dart`(`onAddTap` 파라미터 + 시트 헤더 `+` 버튼 + 빈 날
     [이 날짜에 거래 추가] 버튼 + `_addForDay` = pop 후 콜백) /
     `transaction_list_page.dart`(호출부에서 `_buildCreateTransactionUrl(date:)` 주입) /
     `test/features/transaction/calendar_day_sheet_add_test.dart`(신설, 4건)
   - 설계 결정: URL 조립은 **상위 페이지의 `_buildCreateTransactionUrl` 단일 소스**만 한다. 위젯이 직접
     push 하면 필터된 결제수단 전파가 끊긴다 → 가드 테스트가 위젯 내 `'/transactions/create'` 문자열
     **부재**까지 고정
   - 게이트: `pre-change-audit.sh . "navigation_state ui_pattern"` → OK / gate OPEN ·
     `flutter analyze` 통과(잔여 info 3건은 기존 테스트 파일, 이번 변경과 무관) ·
     `flutter test` **815건 통과** · `flutter build web --release` 성공
   - 아이콘 위험군 아님: 새 코드포인트 없음(`Icons.add` 는 기존 FAB 에서 이미 사용) → 폰트 subset 불변
   - 정정(§2-16 기록): 이력 재작성 **푸시는 완료**됐다. 측정 — `main` == `origin/main` (`49ef7ed`),
     원격 실재 52개 브랜치·태그 33/33 전부 동기. 잔여 diff 는 stale `worktree-agent-*` 로컬 브랜치
     7개뿐(원격과 무관한 폐기 대상)

11. **2026-08-09** — PR #287 머지 → 배포 성공 → **서버 측 검증 완료. 남은 것은 사용자 기기 확인.**
   - 원격 CI: `backend-ci` pass / `frontend-ci` pass → squash 머지 + 브랜치 삭제 (개인 계정 자동 진행 범위)
   - main `a6a437e` · deploy-nas run 31293344811: changes / **deploy-frontend success** /
     **verify-live success** (BE·nginx 는 변경 없어 skipped)
   - 라이브 번들 측정: `main.dart.js` last-modified 03:55Z(이번 배포) ·
     `'이 날짜에 거래 추가'` **2건 존재**(tooltip + 버튼 라벨). 한글은 번들에서 `\uXXXX` 로
     이스케이프되므로 **원문 grep 은 항상 0건** — escaped 형태로 대조해야 한다(측정 함정)
   - **미완**: 사용자 라이브 검증 1건(§3 참조). 이것이 통과할 때까지 이 회차는 "완료" 아님

12. **2026-08-09** — **사용자 라이브 검증 통과 ("잘 들어온다, 삭제도 된다") → 이 회차 종결. 열린 작업 없음.**
   - 확인: 달력 일자 시트의 추가 진입 → 거래 폼에 **그 날짜가 승계**되어 들어옴
   - 함께 확인: 그렇게 만든 거래의 **삭제도 정상**(시트 → 항목 탭 → 상세 경로가 살아 있음 —
     시트를 pop 한 뒤 네비게이션하는 `_addForDay`/탭 콜백 규약이 스택을 오염시키지 않았다)
   - 이로써 PR #287·#288 회차 완료. 다음은 §3 "다음 액션"(이체 → 거래 역변환, 착수 승인 대기)

13. **2026-08-09** — **이체 → 거래 역변환: 착수 승인("다음 작업 진행해줘") → 구현 완료 → 로컬 CI 4종 통과.**
   - 승인: 사용자 착수 지정. 기획 정본(`2026-07-31_transfer-to-transaction_plan.md`)을 그대로 구현,
     설계 변경 없음
   - BE 산출물: `ConvertToTransactionRequest`(DTO) / `TransactionService.convertFromTransfer` /
     `TransactionRepository.existsBySettlementTransferId` /
     `TransferController POST /{id}/convert-to-transaction`(RateLimit 30/60s)
   - 배치 결정 유지: 구현은 **거래 서비스**, 호출은 이체 컨트롤러 — 반대로 넣으면
     `TransactionService → TransferService` 기존 주입과 순환 빈 의존. 근거를 코드 주석에 남김
   - 차단 3종 + 설명 공백 가드 + 카테고리-유형 일치 검증(`createTransaction` 에는 없어 변환 경로에서
     명시적으로 태움) / `saveAndFlush` 후 이체 삭제 / `TRANSFER_DELETED` + `TRANSACTION_CREATED` 2건 발행
   - FE 산출물: `TransferRepository.convertToTransaction`(datasource·impl 포함) /
     거래 폼 `convertFromTransferId` 모드(이체 fetch → prefill, 이체 탭 숨김, 변경 배너, 저장 시 변환 API) /
     이체 폼 수정 모드 유형 선택기(지출·수입 선택 → 거래 폼으로 push) / 라우터 query param 배선
   - **기존 결함 동시 수정**: 정방향 `_convertToTransfer` 가 Dashboard·PaymentMethod 를 리로드하지
     않던 문제 → **네 BLoC 리로드를 양방향 공통 헬퍼 `_reloadAfterConversion` 로** 묶음
     (`feedback_common_scope_audit` — 한 곳만 수정 금지)
   - 테스트: BE 서비스 8케이스(승계·결제수단 방향·차단 4종·이벤트 2건·404) + 컨트롤러 위임 1건 +
     **Testcontainers 통합 4건**(실제 PG: 이체 삭제+거래 삽입 원자성, INCOME 입금 승계,
     설명 NULL 400 가드, 카드결제 차단) / FE repository 3건 + 배선 가드 5건(양방향 대칭 고정)
   - 게이트: `./gradlew test` 통과 · `flutter analyze` 신규 지적 0 · `flutter test` 820건 통과 ·
     `flutter build web --release` 성공. 아이콘 신규 코드포인트 없음(폰트 subset 불변)
   - 문서: `docs/api-spec.md` Transfers §4-1 신설 + 양방향 상호 참조 2곳
   - **미완**: 커밋·PR·머지·배포·사용자 라이브 검증

14. **2026-08-09** — PR #290 머지 → 배포 성공 → **서버 측 검증 완료. 남은 것은 사용자 기기 확인.**
   - 원격 CI: `Backend CI` pass(4m18s) / `Frontend CI` pass(2m29s) → squash 머지 + 브랜치 삭제
   - main `3215399` · deploy-nas run 31298339060: changes / **deploy-frontend success** /
     **deploy-backend success** / **verify-live success** (sync-nginx 는 변경 없어 skipped)
   - 라이브 번들 측정: `main.dart.js` last-modified 06:13Z(이번 배포) ·
     escaped `거래로 변경`("거래로 변경") **5건** ·
     `convert-to-transaction` **1건** → FE·BE 양쪽 배선이 번들에 올라갔다.
     (한글 원문 grep 은 항상 0건 — `reference_live_bundle_string_verification`)
   - **미완**: 사용자 라이브 검증 1건(§3 참조). 이것이 통과할 때까지 이 회차는 "완료" 아님

15. **2026-08-10** — 이체 → 거래 역변환 **사용자 라이브 검증 통과 → 회차 종결(완료)**.
   - 사용자 확인: 정상 동작. PR #286 기획 → #290 구현 → 배포 → 라이브 검증까지 전 구간 종료
   - 이 회차의 산출물(양방향 리로드 공통 헬퍼 + 대칭 가드 테스트)은 §4 산출물 지도에 유지

16. **2026-08-10** — 신규 회차 착수: **장부 필터 게이팅 단일화 + 동적 빈 상태 문구** (Step 1).
   - 사용자 보고: "확인 필요 등 필터 적용 시 이체를 선택 안 했는데도 이체가 보인다" +
     "결과가 없을 때 선택한 필터에 맞는 동적 문구" + "남은 요구사항 단계 정리"
   - 진단(hard evidence): `transaction_list_page.dart:727~785` 이체 게이팅이 필터 축을 **수동 나열** →
     `needsReviewOnly` · 카테고리 · 포켓 · 금액 **4축 누락**, 결제수단은 `paymentMethodIds.first`
     **1개만** 적용. `Transfer` 엔티티에는 needsReview/category/pocket 필드가 **없어** 해당 축이
     켜지면 이체는 매칭 불가 = 전량 제외가 정답. 거래·합계는 BE 가 정상 필터
     (`TransactionSpecifications.kt:100`, `StatisticsService.kt:105`) → "거래는 맞는데 이체만 남는" 비대칭
   - 하네스 감사: `filter_propagation` **STRUCTURAL_FIX_REQUIRED**(4회째 재발) → 게이트 LOCKED →
     기획서에 구조적 수정 포함 후 `acknowledge-gate.sh` 로 해제
   - 결정(사용자 승인): Step 1 범위 = 게이팅 단일화 + 동적 빈 문구 + 결제수단 복수선택 fix 한 PR
   - 산출물: `ledger_gating.dart`(신설, 이체 게이팅 단일 진입점) /
     `ledger_empty_message.dart`(신설, 빈 상태 문구 단일 생성기) /
     `ledger_gating_test.dart` · `ledger_empty_message_test.dart`(신설) /
     `transaction_list_page.dart`(인라인 게이팅 제거 + 동적 빈 상태 + 필터 초기화 액션) /
     `unified_filter_state.dart`(`kTransactionTypeLabels` 공용 상수) / `unified_filter_bar.dart`(라벨 참조)
   - 재발 방지(구조): ① 이체 게이팅 단일 진입점 ② **필드 수 가드** — `UnifiedFilterState` 에 필드가
     늘면 `kUnifiedFilterAxisCount` 불일치로 테스트 실패 → 이체 판정 갱신 강제
     ③ 페이지에 인라인 이체 필터링이 재도입되면 소스 검사 테스트가 실패
   - 게이트: 로컬 CI 4종 통과(analyze 신규 0 / flutter test 843 / gradlew test / build web)
   - 미해결로 남긴 것: 금액·기간·결제수단 필터만 켠 경우 BE summary 는 이체를 합계에서 빼는데
     FE 행에는 이체가 남는다(`StatisticsService.kt:147` "필터 활성 시 totalTransfer=0").
     이번 보고 증상과는 무관한 **기존** 불일치 → 별도 회차 후보로 §3 에 등재

17. **2026-08-10** — PR #292 생성(원격 CI 진행) + 자체 검토에서 잡은 후속 1건 반영.
   - PR: https://github.com/AIVA-SaaS/budget-book/pull/292 (커밋 `1514728`)
   - 자체 검토 지적: `toTransactionFilter(keywordOverride:)` 는 override 가 null/빈 문자열이면
     VO 의 keyword 로 fallback 하는데, FE 게이팅은 빈 검색창(`''`)을 "검색어 없음"으로 처리해
     **BE 가 좁힌 거래 ↔ FE 가 남긴 이체가 어긋날 수 있었다**(합계 ≠ 행 계열)
   - 조치: `resolveLedgerKeyword` 로 실효 검색어 규칙을 한 곳에 두고 게이팅·빈 상태 문구가 공유.
     회귀 테스트 추가(빈 검색창 → VO keyword fallback)
   - 게이트: 유틸 테스트 31건 통과 / analyze 신규 0건

18. **2026-08-10** — PR #292 원격 CI 통과 → 머지 → 배포 성공 → **서버 측 검증 완료.
   남은 것은 사용자 라이브 검증.**
   - 원격 CI: `backend-ci` pass(10s) / `frontend-ci` pass(2m11s) → squash 머지 + 브랜치 삭제
   - main `c6bed67` · deploy-nas run **31343215446 success**
     (changes / **deploy-frontend success** / **verify-live success**;
     BE 변경이 없어 deploy-backend·sync-nginx 는 skipped)
   - 라이브 번들 측정(`main.dart.js`): escaped 대조 —
     `확인/입력 필요한 거래가 없습니다` 1건 · `필터 초기화` 1건 · `적용된 필터: ` 1건 ·
     `이체 내역이 없습니다` 2건. 한글 원문 grep 은 항상 0건이 정상
     (`reference_live_bundle_string_verification`). 이 문구들은 이번 PR 에서 처음 생긴 것이라
     **번들 신원 자체가 이번 배포임을 증명**한다
   - **미완**: 사용자 라이브 검증(§3 완료 판정 6항목). 통과 전까지 이 회차는 "완료" 아님

19. **2026-08-10** — 장부 필터 게이팅 회차 **사용자 라이브 검증 통과 → 회차 종결(완료)**.
   - 사용자 확인: "잘 된다". PR #292 구현 → 배포 → 라이브 검증까지 전 구간 종료. **열린 작업 없음**
   - 사용자 지적 2건(프로세스) 반영:
     ① **다음 회차는 반드시 `/clear` 후 새 세션에서 시작**한다. 회차가 끝나면 종결 기록 +
        다음 착수 지점 고정까지만 하고 멈춘다 — 같은 세션에서 다음 단계로 넘어가지 않는다
        (메모리 `feedback_round_boundary_clear`)
     ② 후보 번호 모순 정정 — "다음은 Step 2" 라고 쓰고 추천은 Step 3 을 가리켰다.
        원인은 **개발 회차가 아닌 "남은 라이브 검증 정리"를 회차 번호에 섞어 넣은 것**.
        아래 §3 에서 회차 번호는 실제 착수 순서로만 매기고, 사용자 확인 트랙은 회차 밖으로 분리했다

20. **2026-08-10** — 새 회차 착수(대장 §3 후보 1번): **홈 대시보드 "월말 점검(미기록 N건)" 위젯
   기획 완료 — 승인 대기.** 코드 변경 0줄.
   - 산출물: `docs/sessions/2026-08-10_2_reconciliation-widget_plan.md` (설계 정본)
   - 측정(hard evidence): `GET /reconciliations/summary` 는 BE·FE 배선이 **이미 전부 존재**
     (컨트롤러 `:51`, `ReconciliationRepository.getSummary`, DI 등재) → **이번 회차는 FE 전용,
     BE·DB·api-spec 변경 0** · 위젯 추가 시 손대야 하는 지점은 **5곳**(기본 목록 / 기본 설정값 /
     `_buildWidgetById` / 설정 시트 분기 / `home_config_page._getIconData`) ·
     기존 사용자 마이그레이션 불필요(`loadConfig` 가 신규 ID 자동 append)
   - 측정으로 드러난 **차단 요인 1건**: 거래 탭 뷰 모드(리스트/달력/정산)는 SharedPreferences
     에만 있고 `/transactions` 라우트에 `view` 파라미터가 **없다** → "위젯 탭 → 정산 뷰" 는
     현재 구조로 불가능. `view` 쿼리 파라미터 신설이 이번 범위에 포함된다
   - 함께 고칠 기존 결함 1건: 홈 화면 구성에서 위젯을 켜도 **pull-to-refresh 전까지 홈에
     반영되지 않는다**(`dashboard_page` 가 initState·새로고침에서만 설정을 읽음). 새 위젯은
     기본 OFF 라 첫 동작이 "켜기" 이므로 이 결함이 그대로면 기능이 없는 것처럼 보인다(P4)
   - 하네스 감사: `ui_pattern` WARNING(타 프로젝트 2건) / `navigation_state`
     **STRUCTURAL_FIX_REQUIRED**(3건) → 게이트 LOCKED.
     **측정: 2026-04-15 인시던트가 지정한 방지책 `navigation_helpers.dart` 는 실제로 도입된 적이
     없다**(`find lib -name "navigation_helpers*"` → 0건). 3회 재발의 이유가 이것 —
     방지책이 문서로만 남고 코드 강제가 없었다
   - 구조적 수정(기획서 §3-3): ① 중앙 헬퍼 `core/utils/ledger_route.dart` 신설
     (**year/month required** = 컴파일 타임 월 누락 차단) ② `dashboard_page` 의 장부 URL 직접
     조립 **3곳**(`:647`·`:774`·`:1166`) 전수 이관 ③ raw `'/transactions?` 리터럴 0건 가드 테스트
     ④ 위젯 등록 누락(5곳) 소스 스캔 가드
   - 용어 확정: 대장 후보의 "미정산" → 앱 용어는 **미기록**. 위젯 이름은 **월말 점검**
     ("정산" 은 이 프로젝트에서 3개 동명 개념 — `reference_reconciliation_snapshot`)
   - **다음 단계는 사용자 승인** — 승인 전 코드 편집 금지(§2 게이트).
     승인 시 `acknowledge-gate.sh` 로 navigation_state 게이트 해제 후 착수

21. **2026-08-10** — 월말 점검 위젯 **승인("전체 승인") → 구현 완료 → 로컬 CI 4종 통과.**
   - 하네스: `acknowledge-gate.sh frontend` 로 navigation_state 게이트 해제(기획서에 구조적 수정 포함)
   - 구조적 수정(하네스 요구 이행): `core/utils/ledger_route.dart` 신설 —
     `ledgerLocation({required year, required month, view, ...})` **year/month required 로
     월 누락을 컴파일 타임 차단**. `dashboard_page` 의 URL 문자열 조립 3곳 전수 이관 +
     raw `'/transactions?` 리터럴 0건 가드. 뷰 전환 규칙은 순수 함수
     `nextLedgerViewOnUpdate` 로 분리(value→null 무시 규칙을 단위 테스트로 고정)
   - 신설: `/transactions?view=` 쿼리 파라미터(리스트/달력/정산). URL 명시 > 저장된 prefs,
     **URL 진입은 prefs 를 덮어쓰지 않는다**. `initialView` 가 있으면 `_loadViewMode()` 를
     호출하지 않아 비동기 prefs 복원이 URL 지정을 덮는 레이스를 차단
   - BE 변경 0 — `GET /reconciliations/summary` 재사용
   - 성능: 위젯이 **꺼져 있으면 요약 API 를 호출하지 않는다**(기본 OFF). 켠 경우에도 기존 6개
     호출과 같은 `Future.wait` 에 합류 → 직렬 지연 증가 없음
   - 함께 고친 기존 결함: 홈 화면 구성에서 위젯을 켜도 pull-to-refresh 전까지 반영되지 않던 문제 →
     `HomeConfigService.revision` ValueNotifier + 대시보드 구독(설정 저장 시 config 재로드 +
     LoadDashboard 재발행). 모든 저장 경로가 `saveConfig` 를 지나므로 토글·순서·개별 설정 전부 커버
   - 산출물(FE): `core/utils/ledger_route.dart` · `home/presentation/widgets/reconciliation_summary_card.dart`
     (신설) / `dashboard_bloc.dart`·`dashboard_state.dart`·`dashboard_page.dart`·
     `dashboard_widget_config.dart`·`home_config_service.dart`·`widget_settings_sheet.dart`·
     `home_config_page.dart`·`injection.dart`·`app_router.dart`·`transaction_list_page.dart`(수정)
   - 테스트: `ledger_route_test`(13) · `reconciliation_summary_card_test`(7) ·
     `dashboard_widget_registry_guard_test`(위젯별 렌더 분기·아이콘 매핑 전수 + 설정 시트 +
     URL 리터럴 가드) · `home_config_revision_test`(6) · `ledger_view_param_wiring_test`(4) ·
     `dashboard_bloc_test`(게이팅 verifyNever 포함 3건 추가) · 위젯 개수 가드 10→11
   - 게이트: **analyze 신규 지적 0 / flutter test 900건 통과 / `./gradlew test` 통과 /
     `flutter build web --release` 성공**. 아이콘은 `fact_check`·`check_circle` 둘 다 기존
     사용처가 있어 **폰트 subset 불변**
   - 용어: 위젯 이름 "월말 점검", 지표 "미기록 N건"(앱 용어). "미정산" 문구는 쓰지 않는다
   - **미완**: 커밋·PR·머지·배포·사용자 라이브 검증

22. **2026-08-10** — 사용자 추가 요청 접수(회차 진행 중) → **다음 회차로 등재.** 코드 변경 0줄.
   - 요청: "`< yyyy년 mm월 >` 의 달력 팝업에서 **연도별 보기 → 연도 내 달 선택**이 가능했으면,
     또 **팝업 전에 '오늘로 가는 버튼'**이 적절한 위치에 있으면 좋겠다"
   - 산출물: `docs/sessions/2026-08-10_3_month-navigator_plan.md` (설계 정본)
   - 측정: 공용 위젯 `core/widgets/month_navigator.dart` 하나를 **13개 페이지**가 쓴다 →
     한 곳 수정이 전체 반영. **단 홈 대시보드만 예외** — `dashboard_page.dart:235 _MonthHeader`
     자체 구현이고 날짜가 `Text` 라 **눌러도 팝업이 뜨지 않는다**(공용 위젯만 고치면 홈은 누락) ·
     팝업(`calendar_picker_dialog.dart`)의 `CalendarDatePicker` 는 **연도 선택은 이미 되지만
     월 그리드가 없다** — 연도를 골라도 원하는 달까지 좌우로 넘겨야 한다(요청의 정확한 결손 지점) ·
     `onDatePicked` 실사용은 **1곳뿐**(거래 목록 스크롤)이라 나머지 12곳은 "월 우선" 전환에
     부작용이 없다 · "오늘" 버튼은 **어디에도 없다**
   - 판단: 현재 회차(월말 점검 위젯)와 **파일·관심사가 겹치지 않고** 회귀 범위가 13개 페이지로
     넓다 → 같은 PR 에 섞지 않고 다음 회차로 분리(§3 후보 1번으로 승격)

23. **2026-08-10** — PR #293 머지·배포 성공. 그러나 배포 후 번들 검증에서 **회차 전제가 틀렸음을 발견**.
   ⚠ **홈 대시보드 화면은 이 앱에 더 이상 존재하지 않는다.**
   - 배포: main `f2e3d92` · deploy-nas run **31348106262 success**(deploy-frontend·**verify-live**)
   - 번들 대조 중 이상 발견: 새 카드의 고유 문구(`이 달은 정산 완료입니다`, `확인 필요 `)가
     라이브·로컬 번들 **양쪽에서 0건**. 반면 `월말 점검`(위젯 목록 이름)·`소계 표시`(설정 시트)는 존재
   - 측정(추측 배제, 실험 6회): 마커 삽입 → clean 빌드 → 소스맵 → profile 빌드 →
     **대조군 실험**(기존 위젯 `monthly_trend_card` 에 마커)에서 **대조군도 사라짐** →
     "내 코드만 제거" 가 아니라 **그 파일들을 참조하는 화면 자체가 죽은 코드**임이 드러남
   - **근본 원인**: `app_router.dart:792` — `/home` 은 **`/transactions` 로 redirect** 다.
     `DashboardPage` 를 **어디서도 라우팅하지 않는다**(전역 참조: 자기 정의 4줄뿐).
     탭은 4개(거래·분석·자산·더보기). git 이력 `ea065d0 feat(nav): Phase 25 Step 10 — 홈 탭 제거(6→5탭) #163`
   - 따라서 `dashboard_page.dart`(1,252줄)와 그것만 참조하는 위젯들(월별 추이·카테고리별 현황·
     이번 월말 점검 카드)은 전부 dart2js 가 트리셰이킹한다. 설정의 **"홈 화면 구성"**(`settings_page.dart:232`)도
     **존재하지 않는 화면을 설정하는 고아 항목**이다
   - 라이브 영향: **회귀 없음**(죽은 코드 추가일 뿐). 실제로 살아 있는 산출물은
     `/transactions?view=` 파라미터 + `parseLedgerView`/`nextLedgerViewOnUpdate`(거래 목록에서 동작),
     `HomeConfigService.revision`(설정 저장 시 bump). `ledgerLocation` 은 호출부가 죽은 화면이라 현재는 미사용
   - **프로세스 실패(재발 방지 대상)**: 기획 §2 에서 "위젯 등록 5곳" 은 전수 조사했으면서
     **그 화면이 사용자에게 도달 가능한지(라우팅 여부)는 확인하지 않았다.**
     대장 후보 목록과 메모리(`project_home_customization`)가 홈 탭 존재를 전제하고 있었고 그대로 믿었다.
     → 새 규칙: **화면에 무언가를 추가하기 전, 그 화면의 라우팅 진입점을 먼저 측정한다**
   - **다음 결정은 사용자 몫**: 홈 탭 복원 / 위젯을 살아있는 화면으로 이전 / 되돌리기

24. **2026-08-10** — 사용자 결정("위젯을 분석 탭으로 이전") → **이전 완료 + 이번 회차가 추가했던
   대시보드 배선 회수.** 로컬 CI 4종 + **번들 포함 검증** 통과.
   - 배치: 분석 탭(`analysis_page.dart`)의 **MonthNavigator 바로 아래** — 예산/통계 두 sub-tab 이
     공유하는 위치. 요약이 없으면(미조회·실패) 아무것도 그리지 않는다
   - 데이터: `ReconciliationSummaryCubit` 신설(요약 8개 숫자만 조회).
     `ReconciliationBloc` 재사용을 피한 이유 = 그쪽은 스냅샷 목록 + 미기록 항목 최대 200건까지
     함께 불러온다. `MonthSyncHandler` 에 등록해 월 이동 시 자동 재조회 + 탭 진입 시 1회 재조회
     (거래 탭에서 정산하고 돌아왔을 때 stale 방지). **늦게 도착한 지난 달 응답이 현재 달을
     덮어쓰지 않도록** 요청 연/월 대조 가드 + 회귀 테스트
   - 회수(이전이지 복사가 아니므로): 대시보드 위젯 등록 5곳 · `DashboardBloc` 요약 로드/게이팅 ·
     `DashboardLoaded.reconciliationSummary` · `HomeConfigService.revision` · 관련 테스트 전부 원복.
     위젯 개수 가드도 11 → 10 으로 복귀
   - 유지(살아 있는 산출물): `core/utils/ledger_route.dart`(이제 **분석 탭 카드가 실제로 사용** —
     구조적 수정이 죽은 코드가 아니게 됐다) · `/transactions?view=` 파라미터 ·
     `parseLedgerView`/`nextLedgerViewOnUpdate`
   - 카드 단순화: 위젯 설정(`showSubtotals`) 제거 — 설정 화면 자체가 고아라 의미가 없다
   - 새 가드: ① 분석 탭이 카드+cubit 을 호스팅하는지 ② 카드가 `ledgerLocation` 만 쓰는지
     (raw `'/transactions` 리터럴 0건) — **다시 죽은 화면으로 옮겨가는 것을 테스트가 막는다**
   - 게이트: analyze 신규 0 / flutter test **894** / `./gradlew test` / `build web --release` ·
     **배포 전 번들 검증**: `이 달은 정산 완료입니다` 1 · `확인 필요 ` 1 · `월말 점검` 1
     (직전 실패의 직접적 재발 방지 — 이제 빌드 산출물에서 카드가 확인된다)
   - **미완**: 커밋·PR·머지·배포·사용자 라이브 검증

25. **2026-08-10** — PR #294 원격 CI 통과 → 머지 → 배포 성공 → **서버 측 검증 완료.
   남은 것은 사용자 라이브 검증.**
   - 원격 CI: `backend-ci` pass(10s) / `frontend-ci` pass(2m12s) → squash 머지 + 브랜치 삭제
   - main `552cfae` · deploy-nas run **31359057515 success**
     (changes / deploy-frontend / **verify-live** success; BE 변경 없어 나머지 skipped)
   - **라이브 번들 검증(이번 회차의 핵심 게이트)**: `main.dart.js` last-modified 05:36Z ·
     `월말 점검` 1 · `이 달은 정산 완료입니다` 1 · `확인 필요 ` 1 · `미기록 ` 6 →
     **직전 배포에서 0건이던 카드 문구가 이번엔 모두 존재**. 카드가 실제로 번들에 들어갔다
   - **미완**: 사용자 라이브 검증. 통과 전까지 이 회차는 "완료" 아님

26. **2026-08-11** — 월말 점검 카드 **사용자 라이브 검증 통과 → 회차 종결(완료)**.
   - 사용자 확인: "잘 된다". PR #293(홈 전제 오류) → PR #294(분석 탭 이전) → 배포 →
     라이브 검증까지 전 구간 종료. **열린 작업 없음**
   - 이 회차가 남긴 살아 있는 산출물(§4 산출물 지도에 유지):
     `core/utils/ledger_route.dart`(`ledgerLocation`, **year/month required** — 하네스
     navigation_state 3회 재발의 구조적 수정을 실제로 이행) · `/transactions?view=` 파라미터
     (리스트/달력/정산 URL 진입, 저장된 뷰를 덮어쓰지 않음) · `ReconciliationSummaryCubit` ·
     분석 탭 월말 점검 카드
   - 이 회차의 가장 큰 소득은 기능이 아니라 **전제 검증 규칙**이다 —
     화면에 무언가를 추가하기 전 라우팅 진입점을 먼저 측정한다.
     메모리 `feedback_screen_reachability_check` · `reference_dead_home_dashboard` ·
     하네스 인시던트(`dead_code`/`navigation_state`/`deployment_verification`) 등록 완료
   - **회차 경계**: 여기서 멈춘다. 다음 회차는 `/clear` 후 새 세션에서 시작
     (메모리 `feedback_round_boundary_clear`)

## 3. 다음 단계

<!-- HNS:NEXT -->
- **현재 상태**: 월말 점검 카드 회차 **라이브 검증 통과 = 완료**(타임라인 26). **열린 작업 없음.**
- **회차 경계 규칙**: 회차가 끝나면 종결 기록 + 착수 지점 고정까지만 하고 **멈춘다**.
  다음 회차는 **반드시 `/clear` 후 새 세션에서 시작**한다 — 같은 세션에서 이어서 착수 금지
  (메모리 `feedback_round_boundary_clear`)

### 다음 회차 — **월 네비게이터 개선** (기획 완료, 착수 지점 고정)

정본: `docs/sessions/2026-08-10_3_month-navigator_plan.md` (사용자 요청 2026-08-10)

- **요청**: `< yyyy년 mm월 >` 의 달력 팝업에서 **연도별 보기 → 연도 내 달 선택**이 편하도록 +
  **팝업 전에 "오늘로 가는 버튼"** 을 적절한 위치에
- **첫 명령**: `bash ~/.claude/harness/scripts/pre-change-audit.sh . navigation_state`
  (게이트 확인 — 이번 회차의 `ledgerLocation` 이행 이력을 근거로 처리) →
  기획서 §2 Step 1(`showMonthYearPickerDialog`)부터 순서대로
- **핵심 측정(이미 완료, 재조사 불필요)**:
  - 공용 위젯 `lib/core/widgets/month_navigator.dart` 하나를 **13개 페이지**가 쓴다 →
    한 곳 수정이 전체 반영
  - 팝업 `lib/core/widgets/calendar_picker_dialog.dart` 의 `CalendarDatePicker` 는
    **연도 선택은 이미 되지만 월 그리드가 없다** — 연도를 골라도 원하는 달까지 좌우로
    넘겨야 한다. 이것이 요청의 정확한 결손 지점
  - `onDatePicked`(일 선택) 실사용은 **1곳뿐**(`transaction_list_page.dart:679`, 선택 일자로
    스크롤) → 나머지 12곳은 "월 우선" 전환에 부작용 없음
  - **"오늘" 버튼은 어디에도 없다**(네비게이터·팝업 모두)
  - 홈 대시보드 `_MonthHeader` 통합(기획서 Step 3)은 **홈 화면이 죽은 코드이므로 무의미** →
    착수 시 그 Step 은 제외하고 시작한다(기획서는 이 사실 발견 전에 작성됐다)
- **주의**: 회귀 범위가 13개 페이지로 넓다. 각 페이지의 기존 위젯 테스트 유무를 먼저 전수 확인하고,
  없는 페이지는 `MonthNavigator` 자체 위젯 테스트로 대체 커버한다

### 그 다음 대기열 (착수 순서 아님)

1. **미기록 200건 초과 달의 추가 페이지 로드 UI** — 안내 문구만 있다
   (`reconciliation_view.dart:191`). BLoC 주석에 클라 필터링 금지 전제 명시.
   LoadMore 패턴은 `reference_transaction_pagination_focus`
2. **합계 ≠ 행 잔존 불일치**(소규모 BE) — 금액/기간/결제수단 필터만 켜면 BE summary 는
   이체를 빼는데(`StatisticsService.kt:147`) FE 행에는 이체가 남는다
3. **개인 자산(ASSET-PRIVATE)** — PaymentMethod visibility/owner + 이체 visibility 파생.
   고칠 지점은 `ledger_gating.dart` 의 `_transfersExcludedWholesale` 한 곳으로 좁혀져 있다
4. **P4 월말 "미기록 N건" 인앱 알림** — 알림 인프라 선행 필요(가장 큼)
5. **Android 배포(Play Store)** — PWA 설치는 이미 가능
6. **카카오 비즈니스 앱 전환(KI-007-P2)** — placeholder email 로 본질은 해결됨. 선택 사항
7. ~~홈 대시보드 위젯 고도화~~ — **무효**(홈 화면 미라우팅). 되살리려면 홈 탭 복원 여부부터 결정

### 회차 밖 트랙 — 사용자 확인만 필요 (개발 착수 아님)

- 정산 스냅샷 라이브 검증 A1~A10 / B1~B7 / C1~C5 — `docs/sessions/2026-07-27_1_result.md §4.1`
- KI-006(지출계획 완료 시 거래 자동 등록) 배포 후 확인 — `docs/known-issues.md`
<!-- /HNS:NEXT -->

## 4. 산출물 지도

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
