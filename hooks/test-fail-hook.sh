#!/bin/bash
# consensus-build PostToolUseFailure Hook
# Phase 6 구현 중 테스트 2회 연속 실패 시 docs/learnings.md에 자동 기록
#
# 입력 (stdin JSON):
#   hook_event_name: "PostToolUseFailure"
#   tool_name: "Bash"
#   tool_input: { command, description }
#   error: "Exit code N"
#   cwd: "/path/to/project"
#
# 출력 (stdout JSON):
#   { "systemMessage": "..." } — Claude에게 전달

set -uo pipefail

# stdin에서 hook input 읽기
HOOK_INPUT=$(cat)

# consensus-build Phase 6에서만 동작
STATE_FILE=".claude/consensus-build-state.local.md"
if [[ ! -f "$STATE_FILE" ]]; then exit 0; fi

PHASE=$(sed -n 's/^phase: *//p' "$STATE_FILE" | tr -d '[:space:]')
if [[ "$PHASE" != "6" ]]; then exit 0; fi

# Bash 도구인지 확인
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
if [[ "$TOOL_NAME" != "Bash" ]]; then exit 0; fi

# 테스트 명령어인지 감지
COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
if ! echo "$COMMAND" | grep -qiE '(pytest|jest|vitest|mocha|npm test|yarn test|pnpm test|bun test|cargo test|go test|python -m pytest|python -m unittest|uv run pytest|make test|gradle test|mvn test|dotnet test|rspec)'; then
  exit 0
fi

# 에러 메시지 추출
ERROR_MSG=$(echo "$HOOK_INPUT" | jq -r '.error // "unknown error"' 2>/dev/null)

# 연속 실패 카운트 관리
FAIL_COUNT_FILE=".claude/consensus-build-fail-count.local"
COUNT=$(cat "$FAIL_COUNT_FILE" 2>/dev/null || echo 0)
if [[ ! "$COUNT" =~ ^[0-9]+$ ]]; then COUNT=0; fi
COUNT=$((COUNT + 1))
echo "$COUNT" > "$FAIL_COUNT_FILE"

# 2회 미만이면 종료 (카운트만 증가)
if [[ "$COUNT" -lt 2 ]]; then
  exit 0
fi

# === 2회 연속 실패 ===

# 현재 TASK 번호 추출
CURRENT_TASK=$(sed -n 's/^current_task: *//p' "$STATE_FILE" | tr -d '[:space:]')
DATE=$(date +%Y-%m-%d)

# docs/learnings.md에 append
mkdir -p docs
COMMAND_SHORT=$(printf '%.200s' "$COMMAND")
{
  echo ""
  echo "## ${DATE} | FAIL | ${CURRENT_TASK:-unknown}"
  echo "- 테스트 2회 연속 실패 (hook 자동 기록)"
  echo "  - Why: (에이전트가 Phase 7에서 보완)"
  echo "  - How to apply: (에이전트가 Phase 7에서 보완)"
  printf '  - 실패한 명령어: %s\n' "$COMMAND_SHORT"
  printf '  - 에러: %s\n' "$ERROR_MSG"
} >> docs/learnings.md

# 카운트 리셋
echo 0 > "$FAIL_COUNT_FILE"

# Claude에게 systemMessage로 알림
if command -v jq &>/dev/null; then
  jq -n --arg msg "⚠️ 테스트 2회 연속 실패 — docs/learnings.md에 자동 기록됨 (${CURRENT_TASK:-unknown}). 다른 접근을 우선 고려하라. Phase 7에서 Why와 How to apply를 보완할 것." \
    '{"systemMessage": $msg}'
else
  echo '{"systemMessage":"⚠️ 테스트 2회 연속 실패 — docs/learnings.md에 자동 기록됨. 다른 접근을 우선 고려하라."}'
fi

exit 0
