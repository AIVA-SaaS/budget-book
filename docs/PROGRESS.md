# Budget Book (aiva-bb) 진행 이력 대장

> **이 파일이 진행 상황의 단일 진입점이다.** `/clear` 후에도 이 파일 하나면 어디까지 왔는지 복원된다.
> SessionStart 훅 `progress-resume.py` 가 아래 STATE·타임라인 꼬리·NEXT 를 자동 주입한다.
> 실질 진전(산출물 생성·게이트 통과·결정 확정·실패)마다 §2 타임라인에 append. **무기록 변경 금지**.

---

## 1. 현재 상태 (한눈에)

<!-- HNS:STATE -->
- **단계**: **"이체 → 거래 역변환"** 회차 — 구현 → 로컬 CI → PR #290 머지 → **배포 성공**.
  서버 측 검증 완료. **남은 것은 사용자 라이브 검증 1건** (이게 통과해야 "완료")
- **상태**: 사용자 라이브 검증 대기
- **정본 문서**: `docs/sessions/2026-07-31_transfer-to-transaction_plan.md` (설계 정본, 그대로 구현됨)
- **repo / 브랜치**: `AIVA-SaaS/budget-book` · `main` = `3215399` · 작업 트리 clean ·
  실행 중 프로세스 없음
- **CI / 배포**: 로컬 4종(gradlew test / analyze 전체 / test 820건 / build web) → 원격 CI 2종 →
  squash 머지 → **deploy-nas run 31298339060 success**(deploy-frontend·deploy-backend·verify-live)
- **blocker**: 사용자 라이브 검증 1건
- **갱신**: 2026-08-09
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

## 3. 다음 단계

<!-- HNS:NEXT -->
- **다음 액션 (`/clear` 후 여기서 시작)**: 이체 → 거래 역변환은 **배포까지 끝났다**(타임라인 13·14).
  남은 것은 **사용자 라이브 검증 1건뿐** — 아래 판정 항목을 사용자에게 확인받는다.
  검증 통과 보고를 받으면 이 회차를 종결 기록하고, 다음 회차 후보를 제시한다.
  실패하면 `domains/01-diagnosis.md` 로 들어간다(추측 fix 금지, 증상-역행 grep 먼저).
- **첫 명령**: 없음(코드 변경 없음). 사용자 확인 대기 상태다.
- **완료 판정(역변환)**: PR 머지·배포로는 완료가 아니다. **사용자 라이브 검증**까지 —
  이체 수정 폼에서 지출/수입 선택 → 거래 폼(배너·승계값 확인) → 저장 → 장부 목록에서 이체가 사라지고
  거래로 표시 + **월 합계·자산 잔액 즉시 갱신**(이 회차에서 같이 고친 부분).
  함께 볼 것: 정방향(거래 → 이체)도 변환 직후 대시보드·자산이 갱신되는지 — 같은 헬퍼를 쓴다.
- **배포 후 측정 팁**: 한글은 번들에서 `\uXXXX` 이스케이프 → 원문 grep 은 항상 0건.
  `'거래로 변경'` 은 escaped 형태로 대조하고 `last-modified` + `verify-live` 를 함께 본다
  (`reference_live_bundle_string_verification`).
- **그 다음 회차**: 아래 후보 2~5 중 사용자가 지정.

### 다음 회차 후보 — 착수 지점 (이 절만 읽으면 바로 시작 가능)

1. ~~**이체 → 거래 역변환**~~ — ✅ 구현 완료(2026-08-09, 타임라인 13). 라이브 검증만 남음.
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
  2026-08-09 그대로 구현 완료 — 설계 변경 없음. 라이브 검증 시 기대 동작의 근거 문서
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
