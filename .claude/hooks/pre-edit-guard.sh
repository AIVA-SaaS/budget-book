#!/bin/bash
# Hook: PreToolUse(Edit|Write|MultiEdit) — 기획서 없이 코드 수정 방지
#
# AI가 사용자 버그 신고 → 바로 코드 수정 돌입하는 패턴 방지.
# 최근 30분 이내에 docs/sessions/*_plan.md가 작성/수정된 기록이 없으면 경고.
#
# 테스트 파일, 설정 파일, 문서 파일은 허용.
# 프로덕션 코드 수정은 반드시 기획서 선행 필요.

set -euo pipefail

HOOK_INPUT=$(cat)
FILE_PATH=$(echo "$HOOK_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# 허용: 기획서, 문서, 테스트, 설정, 하네스, Git 무관
case "$FILE_PATH" in
  */docs/sessions/*_plan.md|*/docs/sessions/*_result.md) exit 0 ;;
  */docs/*|*/.claude/*|*/harness/*) exit 0 ;;
  */test/*|*/*Test.kt|*_test.dart) exit 0 ;;
  */CLAUDE.md|*/README.md|*/MEMORY.md) exit 0 ;;
  */settings.json|*/settings.local.json|*.yml|*.yaml) exit 0 ;;
  */pubspec.yaml|*.gradle.kts|*.sql) exit 0 ;;
esac

# 프로덕션 코드 (backend/src/main, frontend/lib) 수정 검사
case "$FILE_PATH" in
  */backend/src/main/*|*/frontend/lib/*) ;;
  *) exit 0 ;;
esac

# 프로젝트 루트에서 최근 기획서 확인
PROJECT_ROOT=$(echo "$FILE_PATH" | sed -E 's|/(backend|frontend)/.*$||')
SESSIONS_DIR="$PROJECT_ROOT/docs/sessions"

if [ ! -d "$SESSIONS_DIR" ]; then
  exit 0
fi

# 최근 30분 이내에 작성/수정된 _plan.md가 있는지 확인
RECENT_PLAN=$(find "$SESSIONS_DIR" -name "*_plan.md" -mmin -30 2>/dev/null | head -1)

if [ -z "$RECENT_PLAN" ]; then
  cat >&2 << 'WARN'
[⚠️ HARNESS WARNING] 최근 30분 이내 기획서(_plan.md) 작성 이력 없음.

CLAUDE.md Step 1/1.5에 따라 프로덕션 코드 수정 전 반드시:
1. 기획서 작성: docs/sessions/YYYY-MM-DD_N_plan.md
2. 하네스 Step 1.5 실행: bash ~/.claude/harness/scripts/pre-change-audit.sh . "<tags>"
3. STRUCTURAL_FIX_REQUIRED 판정 시 acknowledge-gate.sh 실행

빠른 수정이라도 사용자가 동일 문제를 반복 신고하는 것을 방지하려면
기획서 + 하네스 검토가 필수입니다.

(이 경고는 차단이 아니라 알림. 수정을 진행하려면 기획서를 먼저 작성하세요.)
WARN
fi

exit 0
