#!/bin/bash
# consensus-build PostToolUse (Success) Hook
# Phase 6 구현 중 테스트 성공 시 연속 실패 카운트를 리셋
#
# 입력 (stdin JSON):
#   hook_event_name: "PostToolUse"
#   tool_name: "Bash"
#   tool_input: { command, description }

set -uo pipefail

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

# 테스트 성공 → 카운트 리셋
FAIL_COUNT_FILE=".claude/consensus-build-fail-count.local"
echo 0 > "$FAIL_COUNT_FILE" 2>/dev/null

exit 0
