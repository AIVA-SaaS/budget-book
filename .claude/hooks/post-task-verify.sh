#!/bin/bash
# Hook: PostToolUse(Edit/Write) — 개발 중 변경 파일 감시
# 하네스 audit-patterns.json의 file_scopes에 해당하는 파일이 변경되면 알림

set -euo pipefail

HARNESS_DIR="$HOME/.claude/harness"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Extract file path
FILE_PATH=$(echo "$HOOK_INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Check if the file is in a known risky scope
WARNINGS=""

# Navigation state: router or page files with context.push/go
if [[ "$FILE_PATH" =~ /pages/.*\.dart$ ]] || [[ "$FILE_PATH" =~ /router/.*\.dart$ ]]; then
  if grep -q "context\.\(push\|go\)" "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}[navigation_state] 이 파일에 context.push/go가 있습니다. year/month 전달을 확인하세요.\n"
  fi
fi

# Amount calculation: service files with sum/total
if [[ "$FILE_PATH" =~ Service\.kt$ ]] || [[ "$FILE_PATH" =~ /bloc/.*\.dart$ ]]; then
  if grep -qE "sumOf|totalAmount|totalExpense|totalIncome" "$FILE_PATH" 2>/dev/null; then
    WARNINGS="${WARNINGS}[amount_calculation] 이 파일에 금액 집계 로직이 있습니다. 다른 서비스와 일관성을 확인하세요.\n"
  fi
fi

if [ -n "$WARNINGS" ]; then
  echo "--- Harness File Watch ---"
  echo -e "$WARNINGS"
fi

exit 0
