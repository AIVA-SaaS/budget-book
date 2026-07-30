# 인시던트 정리 — "새로 추가한 아이콘만 빈칸" (5회 재발 → 2026-07-30 종결)

> 목적: **같은 부류의 버그를 다시 만들지 않기 위한 정본 기록.** 증상이 조금이라도 비슷하면
> (아이콘/글자만 안 보인다, 특정 기기만, 캐시 지웠는데도) 코드를 읽기 전에 이 문서를 먼저 본다.
> 요약 한 줄: **해시 없는 URL + 빌드마다 바뀌는 내용 = stale-pin 버그. 헤더로는 못 고친다.**

## 1. 무엇이 몇 번 일어났는가

같은 부류가 **5회** 발생했다. 매번 다른 증상으로 보였지만 원인은 하나다.

1. **PR #153 / #154 (2026-04)** — 폰트 location 이 매칭되지 않아 gzip 미적용.
   이때 "빌드 산출물은 변경 시 새 URL 이라 immutable 이 안전하다" 는 **틀린 전제**가
   nginx 주석에 명시적으로 기록되며 들어왔다. 이 한 줄이 이후 4회의 원인이다.
2. **PR #251 (2026-06-05)** — 모바일에서 계산기 아이콘 미노출.
   `main.dart.js` 가 장기 캐시 → 구 번들 고착. `location /` 를 no-cache 로 고쳤다.
   폰트는 "정규식 location 이 우선이라 immutable 유지" 로 **일부러 남겼다**.
3. **PR #277 (2026-07-27)** — 정산 아이콘(`fact_check` 0xE256) 빈칸.
   폰트 `immutable` 제거 + `verify-cache-headers.sh` 게이트 신설. 그런데 증상은 남았다.
4. **PR #279 (2026-07-28)** — 서버 결백을 4단계로 증명(폰트 cmap·글리프 외곽선·headless
   Chrome 렌더·번들 코드포인트 요청)한 뒤 **"서버가 되돌릴 수 없는 기기 상태"** 로 결론.
   진입점의 글리프 의존을 제거(아이콘 → 텍스트 라벨)하고 종결 처리했다.
5. **PR #280 (2026-07-30)** — 아이콘 복원(아이콘 + 라벨). 증상 자체는 그대로였다.
6. **PR #281 (2026-07-30, 종결)** — 폰트 파일명에 content hash. 사용자 기기에서
   **하드 리프레시 없이** 정산 아이콘 노출 확인.

## 2. 진짜 근본 원인

**URL 신원 ≠ 내용 신원.**

- Flutter web 은 release 빌드에서 `--tree-shake-icons` 로 MaterialIcons 를 **그 빌드가 쓰는
  코드포인트만** 남긴 subset 으로 낸다(빌드 로그: `tree-shaken, reducing it from 1645184 to
  37276 bytes`). 즉 **내용은 빌드마다 달라진다.**
- 그런데 URL 은 `assets/fonts/MaterialIcons-Regular.otf` 로 **고정**이다.
- 이 URL 이 `public, max-age=31536000, immutable` 로 나간 기간이 있었다(#154 ~ #277).
  그 기간에 폰트를 받은 브라우저는 **만료(1년) 전까지 서버에 재검증 요청 자체를 하지 않는다.**
- 그래서 그 기기는 정산 기능 도입 **이전 subset** 을 계속 쓴다 → 그 subset 에 없는 `0xE256`
  하나만 빈칸이고, 예전부터 쓰던 `list 0xE384`·`calendar_month 0xF06BB` 는 정상이다.
  `main.dart.js` 는 no-cache 라 나머지 UI 는 최신이었다 — 그래서 "아이콘만" 이상해 보였다.

**핵심**: `immutable` 로 이미 캐시된 응답에는 **어떤 서버 fix 도 도달하지 못한다.** 헤더를
고치는 것은 "앞으로 캐시할 사람" 에게만 유효하다. 이미 물린 기기를 구제하는 유일한 수단은
**URL 을 바꾸는 것**이다(캐시 엔트리는 URL 로 색인되므로).

## 3. 왜 3·4회차에서 못 잡았는가 (진단 오류의 해부)

측정 자체는 정확했는데 **해석**이 틀렸다.

- 4회차의 4단계 측정(cmap·외곽선·headless 렌더·번들 요청)은 모두 **"서버가 지금 내보내는
  것"** 을 봤다. 문제는 **"그 기기가 이미 갖고 있는 것"** 이었다. 측정 대상이 어긋났다.
- "서버는 결백하다" 에서 **"그러므로 서버가 할 수 있는 일이 없다"** 로 넘어간 것이 오류다.
  서버는 응답 내용을 바꿀 수 없어도 **URL 을 바꿀 수 있다.** 이 선택지를 아예 검토하지 않았다.
- 증상이 "목록·달력은 되고 정산만 안 된다" 였는데, 이 **차별적 사실**을 "옛 subset 에는 앞의
  둘만 있다" 로 연결하지 못했다. 글리프 하나만 빠지는 현상은 **폰트 subset 세대 차이**의
  거의 유일한 지문이다.
- 5회차 종결 시 결정적이었던 질문: *"내가 URL 을 바꿀 수 있나?"*

## 4. 지금 서 있는 방어선 (4겹)

1. **배포 시 URL 을 내용에 결속** — `infra/scripts/hash-icon-font.sh`
   `build/web/assets/FontManifest.json` 의 MaterialIcons 항목을
   `MaterialIcons-Regular.<sha256 앞12>.otf` 로 rename + manifest 재작성.
   재실행 안전(이미 해시 있으면 skip), manifest 부재 시 exit 1.
   배선: `deploy-nas.yml` `deploy-frontend` job, `flutter build web` 직후.
   폰트 경로는 **manifest 가 유일한 소스**라 안전하다 — 번들(`main.dart.js`/`flutter.js`/
   `flutter_bootstrap.js`)에 폰트 파일명 하드코딩 0건, `FontManifest.json` 참조만 2건(측정).
2. **배포 후 실물 검증** — `infra/scripts/verify-cache-headers.sh` (deploy `verify-live` job)
   - 해시 없는 산출물 전체의 `Cache-Control` 에 `immutable` 금지, 재검증 정책 강제
   - 라이브 `FontManifest.json` 을 읽어 아이콘 폰트 경로에 **content hash 가 있는지** 검사
   → 해시 단계가 빠지거나 죽으면 **배포가 실패**한다(증상이 몇 주 뒤에 나타나는 걸 기다리지 않는다).
3. **소스 선언 가드** — `frontend/test/features/transaction/view_mode_toggle_guard_test.dart`
   뷰 토글 세그먼트가 아이콘 전용이어도 되는 **전제**(해시 게이트가 워크플로·verify 스크립트에
   배선돼 있음)를 테스트가 고정한다. 배선을 지우면 `flutter test` 가 깨진다.
4. **정책 단일 소스** — `ops/nas-nginx/aiva-bb.conf` 하나 + 배포마다 NAS 와 diff(drift 검사).
   폰트 location 은 계속 `no-cache` 다(§5 의 프로젝트 폰트 때문에 immutable 로 못 올린다).

## 5. 잔존 위험 전수 조사 (2026-07-30 측정)

**빌드 산출물 41개 전부** 라이브 헤더를 확인했다 — `index.html` / `main.dart.js` /
`flutter.js` / `flutter_bootstrap.js` / `manifest.json` / `favicon.png` / `icons/*.png` /
`canvaskit/*.js|wasm` / `assets/AssetManifest.bin(.json)` / `assets/FontManifest.json` /
`assets/NOTICES` / `assets/shaders/*.frag` / 폰트 2종 → **전부 `no-cache, must-revalidate`.**
`immutable` 은 어디에도 없다.

과거 `immutable` 이 걸렸던 범위도 확인했다(pre-#277 conf): **폰트 확장자
`~* \.(ttf|otf|woff|woff2)$` 뿐**이고, 그 외는 2026-06-05(#251)부터 no-cache 였다.
여기서 두 가지 결론이 나온다.

- **옛 폰트 URL 을 404 로 만들어도 안전하다.** `FontManifest.json` 은 `immutable` 이었던 적이
  없으므로 어떤 기기도 옛 manifest 를 고착할 수 없다 → 항상 재검증 → 항상 새 해시 URL 을 본다.
  (그래서 hash 스크립트는 copy 가 아니라 **rename** 이다. 옛 경로에 파일을 남기면 오히려
  잘못된 subset 을 계속 서빙할 수 있다.)
- **같은 위험군에 프로젝트 폰트가 하나 더 있다.** `assets/fonts/NotoSansKR-Subset.woff2` 도
  폰트 확장자라 그 기간에 `immutable` 로 나갔다. 이 파일은 커밋된 정적 파일이지만
  **재생성 스크립트가 있다**(`ops/fonts/build-noto-subset.sh`). 지금 그 스크립트로 subset 을
  넓혀 같은 파일명으로 교체하면, 옛 폰트를 물린 기기는 **새로 포함된 글자만 두부(□)** 로
  보인다 — 이번 사건의 한글 버전이다.
  → 대응: `frontend/test/core/theme/project_font_pin_guard_test.dart` 가 이 파일의 sha256 을
  고정한다. 내용을 바꾸면 테스트가 깨지고, **"파일명에 버전을 붙여 새 URL 로 내라"** 는
  지시가 실패 메시지로 나온다. (아이콘 폰트처럼 배포 시 자동 rename 하지 않는 이유:
  이 파일은 `AssetManifest.bin`(바이너리)에도 등재돼 있어 빌드 후 rename 이 안전하지 않다.
  커밋된 자산은 **pubspec.yaml 이 단일 소스**이므로 저작 시점에 이름을 바꾸는 것이 맞다.)

수용된 리스크: 2026-06-05 이전에 `main.dart.js` 를 장기 캐시로 물린 기기가 아직 있다면 앱
전체가 구버전으로 보인다(아이콘만 빠지는 증상이 아니라 UI 전체가 옛것). 보고 사례 없음이고,
`index.html` 이 no-cache 이므로 대부분 자연 해소된다. 필요해지면 `main.dart.js` 도 같은 방식으로
해시할 수 있다(`flutter_bootstrap.js` 의 참조 1곳 재작성).

## 6. 재발 시 진단 순서 (5분 컷)

증상: "특정 아이콘/글자만 안 보인다", "내 기기만", "캐시 지웠는데도".

1. 서버가 지금 내보내는 폰트에 그 코드포인트가 있는지 — `curl` 로 받아 `fontTools` cmap 확인.
   코드포인트는 기억하지 말고 **Flutter SDK `icons.dart`** 에서 읽는다(웹 문서 값과 다르다).
2. **빠진 것이 하나뿐인지, 여러 개인지.** 하나뿐이면 **subset 세대 차이**가 1순위다.
   여러 개/전부면 폰트 로드 실패나 기기 폰트 문제로 분기.
3. 그 URL 에 content hash 가 있는지 — 없으면 **stale-pin 이 가능한 구조**다. 헤더를 보기 전에
   이걸 먼저 본다.
4. `curl -sI` 로 `Cache-Control` 확인. `immutable` 이면 확정. **단, 헤더가 이미 고쳐져 있어도
   과거에 immutable 이던 기간이 있었으면 그때 캐시한 기기는 여전히 물려 있다** — git 로그로
   nginx conf 의 과거 정책을 확인한다(`git log -p -- ops/nas-nginx/aiva-bb.conf`).
5. 결론이 "그 기기가 옛 것을 물고 있다" 면 **URL 을 바꾼다.** 사용자에게 하드 리프레시를
   요청하는 것은 fix 가 아니다(모바일에서는 잘 안 통하고, 재방문자마다 반복된다).

## 7. 일반화된 규칙 (다른 프로젝트에도 적용)

- **내용이 바뀔 수 있는 산출물은 URL 에 content hash 를 넣는다.** 캐시 헤더는 2차 방어선이다.
- **`immutable` 은 URL 에 해시가 있을 때만 쓴다.** 해시 없는 URL + immutable 은
  "되돌릴 수 없는 배포" 와 같다.
- **"서버는 결백하다" 는 "서버가 할 수 있는 일이 없다" 가 아니다.** 응답 내용을 못 바꿔도
  URL 은 바꿀 수 있다.
- **증상이 좁을수록(글리프 하나) 원인은 세대 차이다.** 전부 안 되는 것보다 하나만 안 되는 게
  진단에 유리한 정보다 — 무엇이 되는지를 먼저 세어라.
- 하네스 등록: `~/.claude/harness/lessons-learned.jsonl` (`deployment_cache`, `ui_pattern`).
  다음에 같은 태그로 `pre-change-audit.sh` 를 돌리면 이 인시던트가 경고로 뜬다.

## 8. 관련 파일

- `infra/scripts/hash-icon-font.sh` — 아이콘 폰트 content hash (배포 필수 단계)
- `infra/scripts/verify-cache-headers.sh` — 배포 후 캐시 정책 + 해시 존재 검증
- `.github/workflows/deploy-nas.yml` — `deploy-frontend`(해시 단계) / `verify-live`(검증)
- `ops/nas-nginx/aiva-bb.conf` — 캐시 정책 단일 소스
- `frontend/test/features/transaction/view_mode_toggle_guard_test.dart` — 아이콘 전용 전제 가드
- `frontend/test/core/theme/project_font_pin_guard_test.dart` — 프로젝트 폰트 지문 가드
- 이전 회차 기록(수정 금지): `docs/sessions/2026-07-28_icon-missing-handoff.md`,
  `docs/sessions/2026-07-30_handoff.md`
