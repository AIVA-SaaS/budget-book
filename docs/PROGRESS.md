# Budget Book (aiva-bb) 진행 이력 대장

> **이 파일이 진행 상황의 단일 진입점이다.** `/clear` 후에도 이 파일 하나면 어디까지 왔는지 복원된다.
> SessionStart 훅 `progress-resume.py` 가 아래 STATE·타임라인 꼬리·NEXT 를 자동 주입한다.
> 실질 진전(산출물 생성·게이트 통과·결정 확정·실패)마다 §2 타임라인에 append. **무기록 변경 금지**.

---

## 1. 현재 상태 (한눈에)

<!-- HNS:STATE -->
- **단계**: **타이포 재보정 배포 완료 — 남은 것은 사용자 라이브 검증뿐.**
  PR #299(체계 도입) → PR **#300**(기준점 재보정) · `main` = **`f424143`** ·
  번들 `last-modified` 2026-08-19 07:00:41 GMT
  기획서 `docs/sessions/2026-08-18_1_analysis-tab-density_plan.md`(§12 = 구현 결과·정정)
- **한 일**: calynda UI 크기 체계 이식(`bb_scale.dart` 토큰 + `app_theme.responsive()` 배선
  + ratchet 게이트 + 스윕 30건) · 월말 점검 삭제 · 분석 탭 크롬 이관 · 자산 카드 2줄화
- **실측 결과** `[측정, 대조군]`: 크롬 **284dp → 160dp**, 콘텐츠 **63.6% → 79.5%**.
  legacy 는 320~960px 에서 완전히 동일했다 = 폭 반응 0 이 대조군으로 확정
- **게이트 4+1 통과**: analyze 신규 0 / `flutter test` **1058** / `./gradlew test` /
  `build web --release` EXIT=0 / UI 크기 게이트(baseline **1699**, 시범 3파일 0)
- **전 앱 기본값 승격 완료**(회차 밖 영구): `~/.claude/domains/12-ui-scaling.md` +
  INDEX·CLAUDE.md 라우팅 + 분류 훅 키워드. 앞으로 모든 앱 UI 작업에 자동 적용
- **타이포 기준점 = 자산 탭**(사용자 검증). 테마가 그 값을 지나가도록 역산했고 가드가
  양 끝 정확 일치를 고정한다. 타이포는 **960px 에서 포화**(본문 칼럼 상한과 같다)
- ⚠ **`BbDensity` 폰트 필드가 아직 별도 정의**다(경쟁 경로 1개 잔존). 흡수는 별도 회차 —
  자산 탭이 검증된 기준점이라 768px 대에서 계단↔곡선 차이가 생긴다
- **가드 8종 가동**: 타일 API 봉인 / 색 래칫(baseline 313건·73파일) / ListTile·MediaQuery
  금지 / 32조합 매트릭스 / WCAG 명도비 / `readable()` / 저장&계속 offset 0 / ListTile 잉크.
  → 하드코딩 색·`ListTile`·`MediaQuery width` 를 넣으면 **테스트가 막는다**
- ⚠ **CI Flutter 가 로컬보다 최신**(로컬 3.41.2 vs CI `channel: stable`). 로컬 통과 ≠ CI 통과.
  CI 실패 시 `gh run view <id> --log-failed` 부터 — 메모리
  `reference_flutter_sdk_skew_listtile_ink`
- ⚠ **색은 서버로 판정 불가**(번들 grep 은 대조군도 0건 = 프로브 무효). 사용자 눈만이 판정.
  라이브 검증 0단계는 **오프라인 배너 없음 확인**
- **CI 게이트(4+1)**: analyze 전체 신규 0 / `flutter test` **1036** / `./gradlew test` /
  `build web --release` + 배포 후 `verify-cache-headers.sh`
- **blocker**: **사용자 라이브 검증 대기**(기획서 §9 시나리오 0/A/B/C/D) · **갱신**: 2026-08-18
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

27. **2026-08-11** — 월 네비게이터 회차 **착수**: 재측정으로 기획서 사실 오류 2건 정정(v2) →
   사용자 결정 → 하네스 게이트 해제. 코드 변경은 아직 0줄.
   - **하네스**: `pre-change-audit.sh . navigation_state` → 🚫 **STRUCTURAL_FIX_REQUIRED**
     (인시던트 4건: 2026-04-14 / 04-15 ×2 / **08-10 죽은 화면 배포**). v1 기획의 구조 항목이
     무효가 된 Step 3(홈 통합)에 의존하고 있어 **그대로는 게이트를 못 넘는 상태**였다
   - **정정 ①**: "사용처 13개 페이지" → **실제 렌더되는 호스트는 9개**.
     `statistics_page:68` · `budget_list_page:269/566` 은 `showMonthNavigator: false` 로만
     쓰이는 죽은 분기(유일 사용처가 `analysis_page:117/135`, `/budgets`·`/statistics` 는 redirect)
   - **정정 ②**: v1 Step 3(홈 `_MonthHeader` → MonthNavigator 통합) **무효** — 홈은 미라우팅.
     삭제도 하지 않는다(홈 복원 여부 미결 + `dashboard_widget_registry_guard_test` 연쇄 정리 필요)
   - **추가 측정**: `showCalendarPickerDialog` 호출부 18곳 중 **17곳이 "날짜 입력"이 본질**
     → 기존 함수 무변경, 월 피커 신설 / `Icons.today` 기존 사용 중 → **신규 아이콘 코드포인트 없음**
     (폰트 subset 리스크 해당 없음) / `MonthNavigator` 전용 테스트 **0건**
   - **구조적 수정 4종**(게이트 해제 근거): S1 자체 월 헤더 금지 스캔 —
     **`dashboard_page` 는 "미라우팅인 동안만" 예외**라 홈을 되살리면 테스트가 깨져 이행 강제 /
     S2 월 피커 단일 소스 / S3 **도달성 고정**(9개 호스트 목록 + 라우터 참조 검사 — 08-10 인시던트
     직결) / S4 MonthNavigator 위젯 테스트 신설
   - **사용자 결정(진입 단계)**: 거래 탭은 **일 달력 먼저**(기존 유지) + 헤더 탭으로 월→연도
     드릴업. 나머지 8곳은 월 그리드 진입. 기각안(거래 탭도 월 그리드)은 달 이동 1탭이 되는 대신
     같은 달 일 스크롤이 2→3탭으로 퇴보 — **퇴보 없는 쪽을 택했다**
   - 게이트: `acknowledge-gate.sh budget-book <plan>` ✅ 편집 허용
   - **미완**: 구현 · 로컬 CI 4종+번들 검증 · PR · 배포 · 사용자 라이브 검증

28. **2026-08-11** — 월 네비게이터 구현 완료 · **로컬 게이트 5종 전부 통과**. 커밋/PR 전.
   - 브랜치 `feat/month-navigator-drilldown-picker`
   - 산출물(신규): `core/widgets/month_year_picker_dialog.dart` —
     `MonthPickerResult{year, month, day?}` + 3단(`year ↔ month ↔ day`) 드릴다운.
     **`day == null` 이 "월까지만 골랐다"** 는 신호라, 1일 선택과 월 선택이 구별된다
     (`DateTime` 하나로 뭉갰으면 거래 목록이 매번 스크롤했을 것)
   - 산출물(수정): `core/widgets/month_navigator.dart` —
     `allowDaySelection: onDatePicked != null` / **`Icons.today` "오늘" 버튼**
     (이번 달이면 비활성, 툴팁 `이번 달로`) / 좌측 48 스페이서로 대칭 유지 +
     `Flexible`+ellipsis(좁은 화면·큰 글꼴 배율 overflow 방어)
   - 산출물(테스트 신규 30건): 가드 `month_navigator_single_source_guard_test.dart`(S1~S3) ·
     `month_navigator_test.dart`(S4) · `month_year_picker_dialog_test.dart`
   - **게이트**: analyze 신규 0(기존 info 3건만) / flutter test **924**(894 + 30) /
     `./gradlew test` BUILD SUCCESSFUL / `build web --release` ✅
   - **배포 전 번들 검증 ✅**: `이번 달로` 1 · `월 선택으로` 1 · `연도 선택` 2 · `월 선택` 2 ·
     `날짜 선택` 2 — 신규 UI 가 트리셰이킹되지 않았다
   - ⚠ **검증 방법 정정**: dart2js 는 한글을 **소문자** hex 로 이스케이프한다(`이`).
     대문자 `이` 로만 grep 하면 **0건이 나와 오탐**한다. 이번에 실제로 한 번 겪었다
     → 메모리 `reference_live_bundle_string_verification` 보강 대상
   - **미완**: PR · 머지 · 배포 · 사용자 라이브 검증

29. **2026-08-11** — PR #295 원격 CI 통과 → 머지 → 배포 성공 → **서버 측 검증 완료.
   남은 것은 사용자 라이브 검증.**
   - 원격 CI: `backend-ci` pass(9s) / `frontend-ci` pass(2m11s) → squash 머지 + 브랜치 삭제
   - main `3dc6543` · deploy-nas run **31455747310 success**
     (changes / deploy-frontend / **verify-live** success; BE 변경 없어 나머지 skipped)
   - **라이브 번들 검증**: `main.dart.js` last-modified 03:35Z · `cache-control: no-cache` ·
     `이번 달로` 1 · `월 선택으로` 1 · `연도 선택` 2 · `월 선택` 2 · `날짜 선택` 2
   - **미완**: 사용자 라이브 검증(기획서 §6 A1~C2). 통과 전까지 이 회차는 "완료" 아님

30. **2026-08-11** — 월 네비게이터 드릴다운 피커 **사용자 라이브 검증 통과 → 회차 종결(완료)**.
   동시에 **후속 요청 3건 접수**(다음 회차로 이월).
   - 사용자 확인: "다 잘 된다" — A1~C2 전 항목 통과. PR #295 배포까지 전 구간 종료
   - 이 회차가 남긴 살아 있는 산출물(§4 산출물 지도에 유지):
     `core/widgets/month_year_picker_dialog.dart`(연↔월↔일 드릴다운, `MonthPickerResult`) ·
     `MonthNavigator` 의 "오늘" 버튼 · 가드 3종(S1 자체 월 헤더 금지 / S2 피커 단일 소스 /
     S3 도달성 9곳 고정) · `MonthNavigator` 위젯 테스트(그전까지 0건)
   - **후속 요청**(사용자, 2026-08-11 — 다음 회차): ① 월 그리드와 연 그리드가 사실상 같은
     포맷인데 서로 왔다갔다 하는 게 번거롭다 → **한 공간에서 연·월을 같이** ② `날짜 선택`에서
     `2026년 8월` 을 누르면 **연도 설정이 나온다 — 월 선택이 나와야 한다** ③ (부가) 연·월을
     **스피너**로 돌려 고르는 방식
   - **②의 원인은 이미 특정됐다** `[측정]`: 그 헤더는 이번 회차가 만든 `월 선택으로` 버튼이
     아니라 **`CalendarDatePicker` 내장 헤더**(`_buildDayStage` 가 그대로 쓴다)이고,
     Material 기본 동작이 연도 목록 직행이다. 어포던스가 둘로 갈라져 있는 상태
   - **회차 경계**: 여기서 멈춘다. 다음 회차는 `/clear` 후 새 세션에서 **분석부터** 시작
     (메모리 `feedback_round_boundary_clear`)

31. **2026-08-11** — 새 회차 **"연/월 피커 단일 화면 통합 + 스피너" 기획 완료**(승인 대기). 코드 변경 0줄.
   - 산출물: `docs/sessions/2026-08-11_1_month-picker-unified_plan.md` (설계 정본)
   - 게이트 재확인 `[측정]`: `pre-change-audit.sh . navigation_state` → 여전히
     **STRUCTURAL_FIX_REQUIRED**(과거 인시던트 4건) · 게이트 LOCKED.
     기획서 §3.1 에 구조적 수정 계획을 넣고 `acknowledge-gate.sh` 로 해제하는 절차로 처리
   - 측정 재확인: 요청 ②의 헤더는 `_buildDayStage`(:332)의 **`CalendarDatePicker` 내장 헤더**이고
     **숨기거나 탭을 가로챌 공개 API 가 없다** → 어포던스 2개 상태가 결함의 정체
   - **사용자 결정 2건**(형태 선택지 제시 후):
     ① 형태 **C** — 왼쪽 연도 **휠 스피너** + 오른쪽 12개월 그리드 한 화면(단계 전환 0회,
        연도 그리드 삭제). 요청 ①·③ 이 하나로 수렴
     ② 일 선택 — `CalendarDatePicker` 를 **자체 일 그리드로 교체**, 헤더는 우리가 소유하고
        탭하면 연/월 화면으로 복귀(요청 ② 구조적 해결)
   - **구조적 수정 계획**: 피커 안에서 `CalendarDatePicker` 제거(연·월·일 전부 자체 소유) +
     `_PickerStage` 3개 → 2개 + **가드 추가**(피커 파일에 `CalendarDatePicker` 문자열 부재 /
     일 단계에 `findsNothing`). 기존 S1·S2·S3 는 약화 없이 유지
   - **미완**: 사용자 승인 → 구현 → 로컬 CI → PR → 배포 → 라이브 검증

32. **2026-08-11** — 연/월 피커 통합 **구현 완료 · 로컬 게이트 5종 전부 통과**. 커밋/PR 전.
   - 브랜치 `feat/month-picker-unified` · 게이트 해제 `acknowledge-gate.sh budget-book <기획서>` `[측정]`
   - 산출물(재작성): `core/widgets/month_year_picker_dialog.dart` —
     `_PickerStage` **3개 → 2개**(`monthYear`, `day`) · 왼쪽 `ListWheelScrollView` 연도 휠 +
     오른쪽 12개월 그리드 한 화면 · **`CalendarDatePicker` 완전 제거**, 자체 일 그리드
     (일요일 시작, 요일 라벨 한국어 하드코딩 → 로케일 델리게이트 의존 없음)
   - 설계 결정 3건:
     ① 일 1탭 = 확정(기존 `선택` 버튼 제거) — 월도 1탭이라 규칙을 하나로 맞췄다
     ② 연도 휠은 **항목 탭도 지원**(`animateToItem`) — 휠만으로는 정밀도가 낮다
     ③ `ScrollConfiguration.dragDevices` 에 mouse/trackpad 추가 — Flutter 웹 기본값은
       마우스 드래그 스크롤을 제외한다 `[1차]`. 실제 브라우저 동작은 라이브 검증 A3
   - 컨트롤러 수명: 일 그리드에서 연/월로 올라갈 때만 `FixedExtentScrollController` 를
     dispose 후 재생성한다(그 시점엔 휠이 트리에 없어 detached = 안전). 일 그리드 `‹ ›` 로
     해가 바뀐 뒤에도 휠이 옛 연도를 가리키지 않게 하는 유일한 지점
   - 산출물(테스트): `month_year_picker_dialog_test.dart` **6건 → 12건 재작성**
     (연/월 동시 노출·휠 드래그·비중앙 연도 탭·1년 범위·헤더 라벨 복귀·달 넘김·1탭 확정·
     **2026-08-01=토요일 선행공백 6칸을 열 좌표로 검증**·달 중간 자른 범위·320×640 overflow 0) /
     `month_navigator_test.dart` 3건 갱신 / 가드 S2 에 **`CalendarDatePicker(` 부재** 1건 추가
   - **게이트**: analyze 신규 0(기존 info 3건만) / flutter test **932**(924 → +8) /
     `./gradlew test` BUILD SUCCESSFUL / `build web --release` ✅
   - **배포 전 번들 검증 ✅**: `연/월 선택` 1 · `날짜 선택` 2 · `이번 달로` 1 · 요일 라벨 7종 전부
     (한글은 **소문자** hex 이스케이프로만 잡힌다 — 원문 grep 은 전부 0건)
   - **미완**: PR · 머지 · 배포 · 사용자 라이브 검증

33. **2026-08-11** — PR #296 원격 CI 통과 → 머지 → 배포 성공 → **서버 측 검증 완료.
   남은 것은 사용자 라이브 검증.**
   - 원격 CI: `backend-ci` pass(10s) / `frontend-ci` pass(2m3s) → squash 머지 + 브랜치 삭제
   - main `1ae11be` · deploy-nas run **31538119612 success**
     (changes / deploy-frontend / **verify-live** success; BE·nginx 변경 없어 skipped)
   - **라이브 번들 검증** `[측정]`: `main.dart.js` last-modified 21:31Z ·
     `cache-control: no-cache, must-revalidate` · `연/월 선택` 1 · `날짜 선택` 2 ·
     `이번 달로` 1 · `이전 달` 3 · `다음 달` 4 (전부 소문자 hex 이스케이프)
   - ⚠ 번들에 `연도 선택` 문자열이 **여전히 남아 있다** — 우리 코드가 아니라
     `flutter_localizations` 한국어 리소스(`selectYearSemanticsLabel`)다. 다른 17곳이 쓰는
     `showCalendarPickerDialog` 가 `CalendarDatePicker` 를 계속 쓰므로 정상이다.
     **번들 문자열로는 월 피커의 프레임워크 이탈을 판정할 수 없다** — 그 판정은 가드
     테스트(`CalendarDatePicker(` 소스 부재 + `findsNothing`)가 한다
   - **미완**: 사용자 라이브 검증(기획서 §9 A1~C3). 통과 전까지 이 회차는 "완료" 아님

34. **2026-08-11** — 연/월 피커 통합 **사용자 라이브 검증 통과 → 회차 종결(완료)**.
   - 사용자 확인: "전체 잘 된다" — 기획서 §9 A1~C3 전 항목 통과. PR #296 배포까지 전 구간 종료
   - 이 회차가 남긴 살아 있는 산출물(§4 산출물 지도에 유지):
     `core/widgets/month_year_picker_dialog.dart`(연도 휠 + 12개월 그리드 한 화면,
     자체 일 그리드, `CalendarDatePicker` 0개) · 가드 S2 의 프레임워크 위젯 부재 검사 ·
     위젯 테스트 12건
   - **재발 방지 등록**: `~/.claude/harness/lessons-learned.jsonl`(ui_pattern, navigation_state) +
     메모리 `reference_framework_owned_affordance`.
     교훈 한 줄 — **"경로를 추가했다"가 아니라 "경쟁 경로를 0개로 만들었다"가 완료 기준이다.**
     제어 불가한 프레임워크 어포던스가 남아 있으면 위젯 교체 외에 해결이 없다
   - **회차 경계**: 여기서 멈춘다. 다음 회차는 `/clear` 후 새 세션에서 **분석부터** 시작
     (메모리 `feedback_round_boundary_clear`)

35. **2026-08-12** — 새 회차 **"합계 ≠ 행 잔존 불일치" 분석 완료**(기획 전, 코드 변경 0줄).
   **착수 지점의 전제가 측정으로 정정됐다.**
   - 산출물: `docs/sessions/2026-08-12_1_summary-row-mismatch_analysis.md`
   - 하네스 감사: `pre-change-audit.sh . filter_propagation amount_calculation` →
     `filter_propagation` **STRUCTURAL_FIX_REQUIRED**(과거 3건, 게이트 LOCKED).
     기획서에 구조적 수정 포함 후 `acknowledge-gate.sh` 로 해제
   - **전제 정정**: §3 에 적혀 있던 근거 `StatisticsService.kt:147`(필터 활성 시 `totalTransfer=0`)은
     **FE 어디에서도 표시되지 않는 죽은 값**이었다 — 장부 합계바의 이체 칸은 클라 계산
     (`LedgerSummary.from`)이고 분석 탭은 이체 칸을 그리지 않는다(grep 측정).
     수입/지출이 갈라지려면 `EXPENSE_TRANSFER`/`INCOME_TRANSFER` 이체가 필요한데 실 DB **0건**
   - 실 DB 측정: 이체 kind = `GENERIC` 22 / `CARD_SETTLEMENT` 8 / EXPENSE·INCOME_TRANSFER **0** ·
     거래 type = EXPENSE 542 / INCOME 31 / **ADJUSTMENT 17** · 월 최대 거래 **119건**(페이지 200 미달)
   - **실제 발현 중인 결함(F1)**: 기간 필터가 포커스 월을 넘으면 **이체 스트림만 월에 갇힌다** —
     `LoadTransfers({year, month})` 는 월 단위(`transfer_event.dart:15`)인데 거래 목록과 서버 합계는
     `dateFrom/dateTo` 가 월을 완전히 덮어쓴다(`TransactionService.kt:109~118`,
     `StatisticsService.kt:78~79`)며 행 빌더는 월로 다시 자르지 않는다.
     표본(2026-06-15~08-05, 포커스 8월): 거래 192건 전량 노출 vs 이체는 8월 2건만 →
     범위 내 이체 금액의 **77%(3,385,139원) 누락**.
     `reference_transaction_merged_transfer_stream_drift` 의 5번째 변형 —
     이번엔 축 누락이 아니라 **스트림의 로드 범위 불일치**
   - 함께 확인된 잠재/표시 결함: F2 필터 경로의 이체 전량 제외(도달 가능, 이체 폼에서 kind 선택 가능) ·
     F3 ADJUSTMENT 17건·CARD_SETTLEMENT 8건이 행에는 보이나 합계 어느 칸에도 없음
     (합계바 잔액이 `LedgerSummary.balance` 를 안 쓴다) · F4 페이지네이션(월 단위 미발현, 여유 8건)
   - 근본 원인 한 문장: **행 집합과 합계 집합이 같은 소스에서 나오지 않는다** — 합계는
     서버(거래·범위 전체) + 클라(이체·포커스 월)를 한 줄에 섞고, 이체 로드 범위(월)가 필터 범위와 다르다
   - 구조적 수정 방향(안 A 권장): S1 BE `hasContentFilters` 분기 제거(이체도 필터 축 집계) ·
     S2 `LoadTransfers({required dateFrom, dateTo})` 로 컴파일 강제 · S3 합계 응답에 집계 건수 ·
     S4 합계바 혼합 소스 금지 소스검사 가드 · S5 `StatisticsServiceTest` 의 kind×필터 케이스 0건 보강
   - **다음 단계는 사용자 판정 3건**(분석서 §5): Q1 합계에 이체 포함 여부(포함으로 판정, 반증 조건 명시) ·
     Q2 기간 필터가 월을 넘을 때 화면 정체성 · Q3 ADJUSTMENT/CARD_SETTLEMENT 행 배지 여부

36. **2026-08-12** — 판정 3건 확정 + **기획 완료**(승인 대기). 코드 변경 0줄.
   - 사용자 판정: **Q1 = 합계에 이체 포함**(필터 경로를 고친다) / **Q2 = 기간 장부**(이체도 범위 로드) /
     **Q3 = 행 유지 + "합계 제외" 배지**
   - 산출물: `docs/sessions/2026-08-12_2_summary-row-mismatch_plan.md`
   - **게이트 해제 완료**: `acknowledge-gate.sh budget-book <plan>` → 편집 허용
     (근거 = 기획서 §2 S1~S8 구조적 수정)
   - 구조적 수정 설계: S1 BE `LedgerFilter` VO + `LedgerFilterAxis` enum(`when` exhaustive =
     축 추가 시 **컴파일 실패**) + 리플렉션 가드 · S2 `TransferGating` 단일 판정을 **이체 목록
     쿼리와 이체 집계가 공유** · S3 합계의 `hasContentFilters` 분기 **제거**(`totalTransfer=0`
     하드코딩 삭제) · S4 장부 전용 `LedgerTransfersCubit` 분리 · S5 합계바 서버 단일 소스 +
     FE 이체 축 판정 제거 · S6 합계 제외 배지 · S7 api-spec 선행 갱신 · S8 "합계=행" 계약 통합테스트
   - **사이드이펙트 감사(측정)**: `TransferBloc` 은 **6곳이 공유하는 lazy singleton**
     (장부 · 이체 목록 · 카드정산 · 정산 뷰 · 거래 폼 · month_sync/sync_event) →
     장부에 필터를 주입하면 나머지가 오염된다 → **장부 전용 Cubit 분리로 차단**(S4).
     이 감사 없이 진행했으면 5개 화면이 필터된 이체만 보게 됐다
   - **금액 표시 위치 전수 조사(측정)**: `totalIncome|totalExpense|totalTransfer` 참조 26파일 확인 →
     영향 7곳(합계바 계열) / 무영향 확인 근거 병기. 분석 탭·리포트는 **이체 칸을 그리지 않음**
     (grep 0건) → 분석서 §6 미해결 1건 해소. `reconciliation_view.dart:729` 는 정산 스냅샷 별개 소스
   - **자체 총괄 검토에서 잡은 누락 2건**: ① `docs/api-spec.md:1773` 이 summary 의 필터 파라미터를
     3개만 문서화(구현은 12개+) + `:42` 가 이번에 바꿀 규칙("필터 시 totalTransfer 항상 0")을
     규범으로 못박아 둠 → S7 로 선행 갱신 ② Spring `@ModelAttribute` + Kotlin 기본값 +
     `List<UUID>` 바인딩 리스크 → 구현 첫 단계에 컨트롤러 슬라이스 테스트로 선검증
   - DB 마이그레이션 없음(스키마 변경 0건)

37. **2026-08-13** — 승인 후 **구현 완료 · 로컬 CI 5종 전부 통과**. 커밋/PR 전.
   - 사용자 승인: "기획대로 한 PR" (기획서 §7 순서 그대로)
   - **BE 구조 수정**:
     - 신설 `common/filter/LedgerFilterAxis.kt` — 축 20개 enum + `TransferAxisHandling`.
       `TransferGating.handling` 의 **exhaustive when** 이 축 추가 시 컴파일을 막는다
     - 신설 `common/filter/LedgerTypeSelection.kt` — `transactionTypes` 파싱 단일 진입점.
       **`TRANSFER` 가 계약 값으로 승격**(이전엔 400). "필터 없음"과 "거래 타입 0개 선택"을 구분
     - 신설 `transfer/service/TransferGating.kt` — 이체 판정 단일 지점.
       `excludedWholesale` + `spec` 을 **목록 조회와 집계가 공유**
     - `StatisticsService.getMonthlySummary` 의 `hasContentFilters` **분기 제거** →
       `totalTransfer = 0L` 하드코딩 삭제. `getPeriodSummary` 도 같은 헬퍼(`resolveTransactionScope`)로 통일
     - `ExpenseCalculator.transferBuckets/bucketsOf` 추가(kind 별 버킷) ·
       `TransferRepository` 에 `JpaSpecificationExecutor` · 응답에 `transferCount`
     - 컨트롤러의 **필드 수동 나열 제거** — 필터 VO 통째로 전달
   - **FE 구조 수정**:
     - 신설 `LedgerTransfersCubit` — 장부 전용 이체 소스. 공유 `TransferBloc`(소비자 6곳)은
       손대지 않아 이체 목록·카드정산·정산 뷰·거래 폼 무영향. DI·month_sync·sync_event 배선
     - `ledger_gating.dart` 에서 **이체 축 판정 삭제**(서버 신뢰) — 판정 2곳이 재발 메커니즘이었다
     - 합계바 3칸 전부 **서버 단일 소스**(`serverTotalTransfer` 신설). 클라 `LedgerSummary` 는
       러닝밸런스 전용으로 축소. `toQueryParams` 가 `TRANSFER` 를 그대로 전송
     - 신설 `ledger_totals_exclusion.dart` + `ExcludedFromTotalsBadge` — ADJUSTMENT·카드정산 행에
       "합계 제외" 배지(판정은 단일 헬퍼 경유)
   - **계약 문서 선행 갱신**: `docs/api-spec.md` — summary 필터 파라미터 12개+ 문서화 ·
     `:42` 의 "필터 시 totalTransfer 항상 0" **규범 폐기 명시** · List Transfers 범위·필터 ·
     `TRANSFER` 계약 값 절 신설
   - **구현 중 테스트가 잡은 실제 버그 1건**: "타입 필터 없음"과 "타입 필터가 거래를 하나도
     고르지 않음"(이체만 보기)을 혼동해 이체만 보기에서 거래 합계가 남았다 →
     `hasTypeFilter` 로 분리. `LedgerTypeSelectionTest` 가 회귀 가드
   - **신설 테스트**: `LedgerSummaryRowContractIntegrationTest`(실 PostgreSQL, 축 조합 15건 —
     **합계 = 행** 대조 + 절대값 고정) · `LedgerFilterAxisGuardTest`(리플렉션 1:1) ·
     `TransferGatingTest` · `LedgerTypeSelectionTest` · `ledger_transfers_cubit_test.dart` ·
     `ledger_gating_test.dart` 재작성(FE 이체 판정 재도입 금지 + 장부의 `TransferBloc` 사용 금지 가드)
   - **로컬 CI 5종**: analyze 신규 0건(잔여 3건은 미변경 테스트 파일 기존 info) /
     `flutter test` **936건** / `./gradlew clean test` 통과 /
     `flutter build web --release` 통과 / **번들 문자열 확인** — `합계 제외` 1건,
     배지 툴팁 2건 존재
   - **측정 방법 보강**: 번들 문자열 확인에서 한글은 `\uXXXX` 지만 **Latin-1 범위(`·` 등)는
     `\xNN`** 로 인코딩된다. 처음 `·` 포함 문구가 0건으로 나와 대조군 실험으로 방법 결함을 찾았다
     (메모리 `reference_live_bundle_string_verification` 보강 대상)

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

## 3. 다음 단계

<!-- HNS:NEXT -->
**코드·배포 끝. 남은 것은 사용자 라이브 검증뿐이다** — 통과하면 회차 종결.

이번 배포(PR #300)의 판정 초점은 **하나**다: **자산 탭 글자 크기가 거래/분석/더보기에
그대로 반영됐는가.** 사용자가 자산 탭을 "딱 적절하다"고 승인했고, 테마 타이포를 그
값에 맞춰 역산했다(320·360 과 960·1440 에서 자산 값과 **완전 일치** — 실측).

- **0단계(필수)**: 오프라인 배너 없음 확인. 있으면 재연결 후 시작
- **A**: [거래] 목록 행 제목·금액이 [자산] 타일과 **같은 크기로 보이는가**
  (모바일에서 직전 판은 자산보다 +2px 였다)
- **B**: [분석]·[더보기]도 같은지. 특히 [분석]→[통계] 의 라벨·칩
- **C**: 자산 탭 자체는 **변하지 않았어야** 한다(기준점이므로). 바뀌어 보이면 회귀다
- **D 회귀**: 거래 탭 뷰 토글 3번째 세그먼트로 정산 뷰 진입 / 신용카드 타일 2줄 /
  분석 탭 월 이동 두 sub-tab 동기 / 통계 4탭·기간 필터

되돌릴 레버(사전 판정 기준):
- **"아직 크다"** → `_slots` 의 `min` 을 한 단 더 내린다(app_theme.dart 1곳, 가드가 자산
  탭 정합을 잡으므로 자산 쪽 값도 함께 내려야 한다)
- **"너무 작아졌다"** → `min` 을 되올린다. 어느 쪽이든 **표 1개 수정**으로 끝난다
- **"자산 탭이 변했다"** → 회귀. `BbDensity` 와 테마 중 어느 쪽이 움직였는지 정합 가드
  실패 메시지가 지목한다

통과 시: 결과 문서 `docs/sessions/2026-08-19_1_typography-anchor_result.md` + 회차 종결.
다음 회차 후보 1순위는 **`BbDensity` 폰트 필드를 `BbType` 으로 흡수**(경쟁 경로 0개).

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
