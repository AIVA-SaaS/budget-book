#!/usr/bin/env bash
# 배치 3 C-2 (2026-04-26) — 롤백 헬퍼 스크립트
#
# Usage:
#   ./ops/rollback.sh <target-sha>
#   ./ops/rollback.sh HEAD~1
#
# 동작:
#   1) 현재 HEAD 와 target sha 사이의 PR 목록을 출력
#   2) 사용자 확인 후 git revert (single revert commit, 다중 커밋 가능)
#   3) push origin main → deploy-nas.yml 자동 트리거 → 배포 watch 안내
#
# Safety:
#   - main 브랜치에서만 실행
#   - 변경 없는 working tree 강제
#   - 사용자 확인 없으면 진행 안 함

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <target-sha>"
  echo "  target-sha 까지 롤백 (target sha 까지의 모든 커밋을 revert)"
  exit 1
fi

TARGET="$1"
CURRENT=$(git rev-parse HEAD)

# 안전장치
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$BRANCH" != "main" ]; then
  echo "ERROR: rollback 은 main 브랜치에서만 실행. 현재: $BRANCH"
  exit 1
fi

if ! git diff-index --quiet HEAD --; then
  echo "ERROR: working tree 가 dirty. commit/stash 후 재시도."
  exit 1
fi

# 대상 SHA resolve
TARGET_SHA=$(git rev-parse "$TARGET")
if [ "$TARGET_SHA" == "$CURRENT" ]; then
  echo "ERROR: target sha == current HEAD. 롤백할 커밋 없음."
  exit 1
fi

# revert 대상 커밋 미리보기
echo ""
echo "다음 커밋들을 revert 합니다 (최신순):"
echo ""
git log --oneline "$TARGET_SHA..HEAD"
echo ""
COUNT=$(git rev-list --count "$TARGET_SHA..HEAD")
echo "총 $COUNT 개 커밋 revert."
echo ""
read -p "계속하시겠습니까? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "취소됨."
  exit 0
fi

# revert 진행 (single revert commit; 충돌 시 사용자 처리)
git revert --no-edit "$TARGET_SHA..HEAD"

echo ""
echo "✅ revert 완료. 'git push origin main' 실행 시 deploy-nas.yml 자동 트리거."
echo "확인 후:"
echo "  git log --oneline -10"
echo "  git push origin main"
echo "  GH_CONFIG_DIR=~/.config/gh-personal gh run watch <run-id>"
