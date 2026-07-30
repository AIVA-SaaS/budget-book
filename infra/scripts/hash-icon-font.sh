#!/usr/bin/env bash
#
# 아이콘 폰트 파일명에 content hash 를 넣어 **stale 캐시를 원천 차단**한다.
#
# 왜 필요한가 (3회 재발, 매번 "새 아이콘만 빈칸")
#   Flutter web 은 `--tree-shake-icons`(release 기본값) 로 MaterialIcons 를 그 빌드가
#   쓰는 코드포인트만 남긴 subset 으로 내보낸다. 즉 **내용은 빌드마다 바뀌는데 URL 은
#   `assets/fonts/MaterialIcons-Regular.otf` 로 고정**이다.
#   - 2026-05-04: 옛 Service Worker 캐시의 구 subset → 분석 탭 Icons.insights 빈칸
#     (→ `--pwa-strategy=none` 로 SW 제거)
#   - 2026-07-27: nginx 가 이 URL 을 `immutable` 로 내보내던 시절에 캐시한 클라이언트가
#     구 subset 을 물고 **재검증 요청조차 하지 않음** → 정산 아이콘(0xe256) 만 빈칸.
#     헤더를 고쳐도(#277) 이미 캐시를 물고 있는 기기에는 도달할 수 없다.
#   근본 원인은 캐시 정책이 아니라 **URL 신원 ≠ 내용 신원**이다. 파일명에 해시를 넣으면
#   내용이 바뀌면 URL 도 바뀌므로, 어떤 캐시 상태에서도 구 폰트가 새 글리프를 가릴 수 없다.
#
# 무엇을 하는가
#   build/web/assets/FontManifest.json 의 아이콘 폰트(MaterialIcons*) 를
#   `MaterialIcons-Regular.<sha256 앞 12자>.otf` 로 rename 하고 manifest 경로를 재작성.
#   프로젝트 폰트(NotoSansKR 등)는 AssetManifest.bin.json 에도 등재돼 있어 건드리지 않는다.
#   (재실행 안전 — 이미 해시가 붙어 있으면 건너뛴다.)
#
# 사용법:
#   infra/scripts/hash-icon-font.sh [WEB_DIR]     # WEB_DIR 기본값 frontend/build/web
#
# 배선: .github/workflows/deploy-nas.yml (build web 직후, 패키징 직전)
#       배포 후 검증은 infra/scripts/verify-cache-headers.sh 가 해시 패턴을 강제한다.
#
# 종료 코드: 0 = 성공(또는 대상 없음), 1 = manifest 부재/rename 실패

set -euo pipefail

WEB_DIR="${1:-frontend/build/web}"
MANIFEST="${WEB_DIR}/assets/FontManifest.json"

echo "== Icon font content-hash: ${WEB_DIR}"

if [ ! -f "$MANIFEST" ]; then
  echo "  FAIL FontManifest.json 없음: $MANIFEST"
  echo "       (flutter build web 이후에 실행해야 한다. WEB_DIR 인자를 확인하라.)"
  exit 1
fi

python3 - "$WEB_DIR" "$MANIFEST" <<'PY'
import hashlib
import json
import os
import re
import sys

web_dir, manifest_path = sys.argv[1], sys.argv[2]

with open(manifest_path, encoding="utf-8") as fp:
    manifest = json.load(fp)

# 이미 해시가 붙은 파일명 (재실행 안전)
HASHED = re.compile(r"\.[0-9a-f]{12}\.(otf|ttf|woff2?)$")
# 트리셰이킹 대상 = Flutter 가 심는 아이콘 폰트. 프로젝트 폰트는 제외한다.
ICON_FONT = re.compile(r"(^|/)MaterialIcons[^/]*\.(otf|ttf|woff2?)$")

renamed = 0
for family in manifest:
    for font in family.get("fonts", []):
        asset = font.get("asset", "")
        if not ICON_FONT.search(asset):
            continue
        if HASHED.search(asset):
            print(f"  SKIP {asset} — 이미 content hash 있음")
            renamed += 1
            continue

        src = os.path.join(web_dir, "assets", asset)
        if not os.path.isfile(src):
            print(f"  FAIL manifest 가 가리키는 폰트 파일이 없다: {src}")
            sys.exit(1)

        with open(src, "rb") as fp:
            digest = hashlib.sha256(fp.read()).hexdigest()[:12]

        stem, ext = os.path.splitext(asset)
        new_asset = f"{stem}.{digest}{ext}"
        os.rename(src, os.path.join(web_dir, "assets", new_asset))
        font["asset"] = new_asset
        renamed += 1
        print(f"  OK   {asset} -> {new_asset} (family={family.get('family')})")

if renamed == 0:
    # 아이콘 폰트가 아예 없는 빌드(전부 커스텀 아이콘 등)는 정상이다. 다만 조용히 지나가면
    # "해시 단계가 죽었는데 아무도 모르는" 상태와 구분이 안 되므로 눈에 띄게 남긴다.
    print("  WARN 아이콘 폰트 항목을 찾지 못했다 — FontManifest 를 확인하라:")
    print("       " + json.dumps(manifest, ensure_ascii=False))
    sys.exit(0)

with open(manifest_path, "w", encoding="utf-8") as fp:
    json.dump(manifest, fp, ensure_ascii=False, separators=(",", ":"))

print(f"== 통과: 아이콘 폰트 {renamed}개 content hash 적용")
PY
