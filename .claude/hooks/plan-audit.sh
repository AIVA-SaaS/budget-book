#!/bin/bash
# Hook: PostToolUse(Write) — 기획서 작성 시 자동 하네스 검토
# 기획서 파일(_plan.md)이 생성/수정되면 scope audit + recurrence check 실행

set -euo pipefail

HARNESS_DIR="$HOME/.claude/harness"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract file path
FILE_PATH=$(echo "$HOOK_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# Only run for plan documents
if [[ ! "$FILE_PATH" =~ docs/sessions/.*_plan\.md$ ]]; then
  exit 0
fi

echo "=== HARNESS AUTO-REVIEW: Plan Document Detected ==="
echo "File: $FILE_PATH"
echo ""

# Extract classification tags from the plan content
# Look for common keywords to auto-detect tags
PLAN_CONTENT=$(cat "$FILE_PATH" 2>/dev/null || echo "")
TAGS=""

if echo "$PLAN_CONTENT" | grep -qiE "navigation|context\.push|context\.go|라우트|이동|전달"; then
  TAGS="${TAGS}navigation_state,"
fi
if echo "$PLAN_CONTENT" | grep -qiE "filter|필터|파라미터|year.*month|month.*year"; then
  TAGS="${TAGS}filter_propagation,"
fi
if echo "$PLAN_CONTENT" | grep -qiE "amount|금액|합계|집계|totalExpense|totalIncome|Transfer|이체"; then
  TAGS="${TAGS}amount_calculation,"
fi
if echo "$PLAN_CONTENT" | grep -qiE "widget|위젯|UI|공통.*컴포넌트"; then
  TAGS="${TAGS}ui_pattern,"
fi
if echo "$PLAN_CONTENT" | grep -qiE "migration|마이그레이션|schema|스키마|ALTER|CREATE TABLE"; then
  TAGS="${TAGS}db_schema,"
fi

# Remove trailing comma
TAGS="${TAGS%,}"

if [ -z "$TAGS" ]; then
  echo "No classification tags detected. Skipping audit."
  exit 0
fi

echo "Auto-detected tags: $TAGS"
echo ""

# Check if harness section exists in the plan
if ! echo "$PLAN_CONTENT" | grep -q "하네스 Scope Audit 결과"; then
  echo "WARNING: 기획서에 '하네스 Scope Audit 결과' 섹션이 없습니다!"
  echo "Step 1.5 필수: bash ~/.claude/harness/scripts/pre-change-audit.sh . \"$TAGS\""
  echo ""
fi

# Run recurrence check (lightweight, fast)
echo "--- Recurrence Check ---"
python3 "$HARNESS_DIR/scripts/recurrence_check.py" "$TAGS" 2>/dev/null || echo "(recurrence check unavailable)"

echo ""
echo "=== HARNESS AUTO-REVIEW COMPLETE ==="
echo "Full audit: bash ~/.claude/harness/scripts/pre-change-audit.sh . \"$TAGS\""
