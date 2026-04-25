#!/usr/bin/env bash
# Noto Sans KR Variable Font 을 한글+라틴 subset 으로 변환 (woff2).
# 원본 10MB → ~1.2MB. Hanja 미포함.
#
# 사전 요구: pip install --user "fonttools[woff]" brotli
# 입력: NotoSansKR-VF.ttf (Google Fonts 에서 다운로드)
# 출력: frontend/assets/fonts/NotoSansKR-Subset.woff2

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SRC_TTF="${1:-${REPO_ROOT}/ops/fonts/NotoSansKR-VF.ttf}"
DST_WOFF2="${REPO_ROOT}/frontend/assets/fonts/NotoSansKR-Subset.woff2"

if [ ! -f "${SRC_TTF}" ]; then
  echo "원본 TTF 없음: ${SRC_TTF}" >&2
  echo "Google Fonts → Noto Sans KR → static/Variable .ttf 다운로드 후 위 경로에 배치" >&2
  exit 1
fi

if ! command -v pyftsubset >/dev/null 2>&1; then
  echo "pyftsubset 없음. 설치: pip install --user 'fonttools[woff]' brotli" >&2
  exit 1
fi

# 유니코드 범위:
# - 라틴 기본 + 확장
# - 한글 자모 + 호환 자모 + 음절 + 확장
# - 통화 / 일반 punctuation / 숫자 형식 / 글자형 기호
pyftsubset "${SRC_TTF}" \
  --output-file="${DST_WOFF2}" \
  --flavor=woff2 \
  --unicodes="U+0000-007F,U+00A0-00FF,U+0100-017F,U+1100-11FF,U+3130-318F,U+AC00-D7AF,U+A960-A97F,U+D7B0-D7FF,U+2010-205E,U+2070-209F,U+20A0-20CF,U+2100-214F" \
  '--layout-features=*' \
  --no-hinting \
  --desubroutinize

echo "생성됨: ${DST_WOFF2}"
ls -lh "${DST_WOFF2}"
