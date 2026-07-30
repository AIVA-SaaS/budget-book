#!/usr/bin/env bash
#
# 배포 후 캐시 헤더 검증 — "해시 없는 산출물이 장기/immutable 캐시로 나가는" 사고를 막는다.
#
# 왜 필요한가 (2회 재발)
#   - 2026-06-05 PR #251: main.dart.js 가 장기 캐시 → 모바일에서 계산기 아이콘 미노출
#   - 2026-07-27       : /assets/fonts/MaterialIcons-Regular.otf 가 immutable →
#                        재방문 클라이언트가 구 서브셋 폰트를 물고 있어 정산 아이콘만 빈칸
#   두 번 다 원인이 같다: **Flutter web 산출물은 URL 에 content hash 가 없는데**
#   "빌드가 바뀌면 URL 도 바뀐다" 고 가정하고 장기 캐시를 걸었다.
#   사람이 매번 기억하는 대신 배포 파이프라인이 검사한다.
#
#   2026-07-30 보강: 헤더 fix 만으로는 **이미 immutable 로 캐시한 클라이언트**를 구제할 수
#   없다(재검증 요청 자체를 하지 않는다). 그래서 아이콘 폰트는 파일명에 content hash 를
#   붙이고(`hash-icon-font.sh`), 이 스크립트가 그 해시의 존재까지 검사한다.
#
# 사용법:
#   infra/scripts/verify-cache-headers.sh [BASE_URL]
#   BASE_URL 기본값 https://aiva-bb.duckdns.org
#
# 종료 코드: 0 = 전부 통과, 1 = 위반 있음(배포 실패 처리)

set -uo pipefail

BASE_URL="${1:-https://aiva-bb.duckdns.org}"

# content hash 가 URL 에 없는 산출물 = 매 배포마다 내용이 바뀔 수 있는 고정 URL.
# 새 산출물 유형이 생기면 여기에 추가한다.
HASHLESS_PATHS=(
  "/index.html"
  "/main.dart.js"
  "/flutter_bootstrap.js"
  "/flutter_service_worker.js"
  "/version.json"
  "/assets/AssetManifest.bin.json"
  "/assets/FontManifest.json"
)

fail=0
echo "== Cache header verification: $BASE_URL"

for path in "${HASHLESS_PATHS[@]}"; do
  headers=$(curl -sS -I --max-time 20 "${BASE_URL}${path}" 2>/dev/null)
  status=$(printf '%s' "$headers" | awk 'NR==1 {print $2}')

  if [ "$status" != "200" ]; then
    # 없는 산출물(버전에 따라 version.json 등)은 검증 대상에서 제외 — 존재할 때만 정책을 본다.
    echo "  SKIP $path (HTTP ${status:-no-response})"
    continue
  fi

  cc=$(printf '%s' "$headers" | tr -d '\r' | awk -F': ' 'tolower($1)=="cache-control" {print tolower($2)}')

  if [ -z "$cc" ]; then
    echo "  FAIL $path — Cache-Control 헤더 없음 (브라우저 휴리스틱 캐시 위험)"
    fail=1
  elif printf '%s' "$cc" | grep -q "immutable"; then
    echo "  FAIL $path — immutable (해시 없는 URL 에 금지): $cc"
    fail=1
  elif printf '%s' "$cc" | grep -qE "no-cache|max-age=0"; then
    echo "  OK   $path — $cc"
  else
    echo "  FAIL $path — 재검증 없는 캐시 정책: $cc"
    fail=1
  fi
done

# ── 아이콘 폰트: 해시 없는 고정 URL 이면 실패 ──
#
# 트리셰이킹 아이콘 폰트는 내용이 빌드마다 바뀐다. 캐시 헤더만으로는 부족했다 —
# 예전에 `immutable` 로 캐시한 클라이언트는 재검증 요청조차 하지 않아서, 헤더를 고쳐도
# 구 subset 을 계속 물고 있었다(2026-07-30 "정산 아이콘만 빈칸"의 실제 원인).
# 그래서 `infra/scripts/hash-icon-font.sh` 가 파일명에 content hash 를 넣는다.
# 그 단계가 빠지거나 죽으면 증상은 몇 주 뒤 "새 아이콘만 안 보인다"로만 드러나므로,
# 배포 파이프라인이 매번 검사한다.
echo "== Icon font URL 검증"
manifest=$(curl -sS --max-time 20 "${BASE_URL}/assets/FontManifest.json" 2>/dev/null)
icon_asset=$(printf '%s' "$manifest" |
  grep -oE '"asset":"[^"]*MaterialIcons[^"]*"' |
  head -1 | sed 's/.*"asset":"//; s/"$//')

if [ -z "$icon_asset" ]; then
  echo "  SKIP 아이콘 폰트 항목 없음 (FontManifest: ${manifest:0:200})"
else
  icon_url="${BASE_URL}/assets/${icon_asset}"
  if printf '%s' "$icon_asset" | grep -qE '\.[0-9a-f]{12}\.(otf|ttf|woff2?)$'; then
    icon_status=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 "$icon_url" 2>/dev/null)
    if [ "$icon_status" = "200" ]; then
      echo "  OK   /assets/${icon_asset} — content hash 있음"
    else
      echo "  FAIL /assets/${icon_asset} — manifest 가 가리키는데 HTTP ${icon_status} (rename 후 배포 누락)"
      fail=1
    fi
  else
    echo "  FAIL /assets/${icon_asset} — content hash 없는 고정 URL"
    echo "       hash-icon-font.sh 가 배포 파이프라인에서 실행되지 않았다."
    fail=1
  fi
fi

if [ "$fail" -ne 0 ]; then
  cat <<'EOF'

배포 검증 실패 — 캐시로 구버전이 고착될 수 있는 상태입니다.
증상은 "새 기능/아이콘만 안 보인다" 형태로 나타나며, 사용자는 하드 리프레시 전까지
계속 구버전을 봅니다.
  - 캐시 헤더 FAIL: ops/nas-nginx/aiva-bb.conf 의 해당 location 을
    `Cache-Control "no-cache, must-revalidate"` 로 고치고 nginx 를 리로드하세요.
  - 아이콘 폰트 FAIL: deploy 워크플로에서 infra/scripts/hash-icon-font.sh 가
    `flutter build web` 직후에 실행되는지 확인하세요.
EOF
  exit 1
fi

echo "== 통과: 해시 없는 산출물 전부 재검증 캐시"
