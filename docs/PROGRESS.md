# Budget Book (aiva-bb) 진행 이력 대장

> **이 파일이 진행 상황의 단일 진입점이다.** `/clear` 후에도 이 파일 하나면 어디까지 왔는지 복원된다.
> SessionStart 훅 `progress-resume.py` 가 아래 STATE·타임라인 꼬리·NEXT 를 자동 주입한다.
> 실질 진전(산출물 생성·게이트 통과·결정 확정·실패)마다 §2 타임라인에 append. **무기록 변경 금지**.

---

## 1. 현재 상태 (한눈에)

<!-- HNS:STATE -->
- **단계**: 아이콘 폰트 stale 캐시 영구 fix + 뷰 토글 라벨 제거 / 라이브 검증 대기
- **상태**: verifying
- **정본 문서**: `docs/sessions/2026-07-30_handoff.md` (직전 회차) + 이 대장
- **repo / 브랜치**: `AIVA-SaaS/budget-book` · `fix/icon-font-content-hash` → main
- **CI 3종**: `flutter analyze --no-fatal-infos` 통과 / `flutter test` 805건 통과 / `flutter build web --release` 통과 (BE 무변경)
- **blocker**: 없음
- **갱신**: 2026-07-30
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

## 3. 다음 단계

<!-- HNS:NEXT -->
- **다음 액션**: 사용자 라이브 검증 — 거래 탭 뷰 토글에서 **정산 아이콘이 보이는지**(글자 없이
  아이콘 3개), 그리고 `docs/sessions/2026-07-30_handoff.md` §3 의 미확인 5건
- **선행 조건**: PR 머지 후 deploy-nas 성공 (verify-live 의 캐시/해시 검증 포함)
- **완료 판정**: 사용자 기기에서 정산 아이콘 노출 확인 = 이 건 종결. 아니면 그 기기에서 다른
  아이콘도 빈칸인지 함께 확인(기기·브라우저 폰트 문제 분기)
<!-- /HNS:NEXT -->

## 4. 산출물 지도

- `docs/sessions/2026-07-30_handoff.md` — 직전 회차 인수 문서(배포 현황·라이브 검증 체크리스트). 이력 보존용, 수정 금지
- `docs/sessions/2026-07-28_icon-missing-handoff.md` — 아이콘 사건 1·2회차 측정 기록. 수정 금지
- `infra/scripts/hash-icon-font.sh` — 아이콘 폰트 content hash (배포 파이프라인 필수 단계)
- `infra/scripts/verify-cache-headers.sh` — 배포 후 캐시 정책 + 아이콘 폰트 해시 검증 게이트
- `frontend/test/features/transaction/view_mode_toggle_guard_test.dart` — 뷰 토글 tooltip + 해시 게이트 배선 가드

## 5. 미해결·리스크

- 사용자 기기의 stale 폰트는 새 URL 로 자동 해소되지만, **폰트 외** 다른 stale 캐시가 남아 있을
  가능성은 배제하지 못한다. 정산 아이콘이 여전히 빈칸이면 그 기기에서 다른 아이콘의 렌더 여부를
  먼저 확인해 기기·브라우저 폰트 문제와 분리한다.
- 프로젝트 폰트(`NotoSansKR-Subset.woff2`)는 여전히 해시 없는 고정 URL(AssetManifest 등재 때문).
  거의 안 바뀌는 파일이고 `no-cache` 로 서빙되므로 현재는 수용된 리스크.
