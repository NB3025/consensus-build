#!/bin/bash
# consensus-build Stop Hook v2
# Phase 완료 전 종료를 차단하고 파이프라인 계속 진행을 강제한다.
# 핵심: tasks_completed < 실제 TASK 수이면 completed: true여도 차단한다.

set -uo pipefail

STATE_FILE=".claude/consensus-build-state.local.md"

# ==========================================================
# (#2) stdin에서 hook input 읽기
# ==========================================================
HOOK_INPUT=$(cat)

# 상태 파일 없음 = 파이프라인 비활성, 종료 허용
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# ==========================================================
# (#11) 파싱 실패 방어: 빈 파일
# ==========================================================
if [[ ! -s "$STATE_FILE" ]]; then
  echo "⚠️  consensus-build: State file is empty, removing" >&2
  rm -f "$STATE_FILE"
  exit 0
fi

# ==========================================================
# 상태 읽기
# ==========================================================
ACTIVE=$(sed -n 's/^active: *//p' "$STATE_FILE" | tr -d '[:space:]')
STATE_SESSION=$(sed -n 's/^session_id: *//p' "$STATE_FILE" | tr -d '[:space:]')
PHASE=$(sed -n 's/^phase: *//p' "$STATE_FILE" | tr -d '[:space:]')
COMPLETED=$(sed -n 's/^completed: *//p' "$STATE_FILE" | tr -d '[:space:]')
MODE=$(sed -n 's/^mode: *//p' "$STATE_FILE" | tr -d '[:space:]')
TASKS_COMPLETED=$(sed -n 's/^tasks_completed: *//p' "$STATE_FILE" | tr -d '[:space:]')
TASKS_TOTAL=$(sed -n 's/^tasks_total: *//p' "$STATE_FILE" | tr -d '[:space:]')
IMPL_FILE=$(sed -n 's/^impl_file: *//p' "$STATE_FILE" | tr -d '[:space:]')
CURRENT_TASK=$(sed -n 's/^current_task: *//p' "$STATE_FILE" | tr -d '[:space:]')

# ==========================================================
# (#11) 파싱 실패 방어: 핵심 필드 누락
# ==========================================================
if [[ -z "$ACTIVE" ]]; then
  echo "⚠️  consensus-build: 'active' field is empty or missing" >&2
  echo "   File: $STATE_FILE" >&2
  exit 0
fi

# 비활성 상태, 종료 허용
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

# ==========================================================
# (#2 + #6) 세션 격리: stdin 기반 + auto-populate
# ==========================================================
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

# 상태 파일에 session_id가 없으면 현재 세션으로 기록
if [[ -z "$STATE_SESSION" ]] && [[ -n "$HOOK_SESSION" ]]; then
  echo "session_id: $HOOK_SESSION" >> "$STATE_FILE"
  STATE_SESSION="$HOOK_SESSION"
fi

# 다른 세션이면 무시, 종료 허용
if [[ -n "$STATE_SESSION" ]] && [[ -n "$HOOK_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# ==========================================================
# (#4) 숫자 필드 검증
# ==========================================================
validate_number() {
  local name="$1" value="$2"
  if [[ -n "$value" ]] && [[ ! "$value" =~ ^[0-9]+$ ]]; then
    echo "⚠️  consensus-build: '$name' is not a number: '$value'" >&2
    return 1
  fi
  return 0
}

if ! validate_number "phase" "$PHASE"; then PHASE=""; fi
if ! validate_number "tasks_completed" "$TASKS_COMPLETED"; then TASKS_COMPLETED=""; fi
if ! validate_number "tasks_total" "$TASKS_TOTAL"; then TASKS_TOTAL=""; fi

# ==========================================================
# (#9 + #1 + #8) JSON 출력 함수 통합
# ==========================================================
output_block_json() {
  local reason="$1" sys_msg="$2"
  if command -v jq &>/dev/null; then
    jq -n --arg r "$reason" --arg m "$sys_msg" \
      '{"decision":"block","reason":$r,"systemMessage":$m}'
  else
    # (#8) 인라인 환경변수로 python3에 전달 (export 불필요)
    REASON="$reason" SYSMSG="$sys_msg" python3 -c \
      "import json,os;print(json.dumps({'decision':'block','reason':os.environ['REASON'],'systemMessage':os.environ['SYSMSG']}))" \
      2>/dev/null || {
      # 최종 fallback: 수동 이스케이핑
      local er em
      er=$(printf '%s' "$reason" | sed 's/\\/\\\\/g;s/"/\\"/g' | tr '\n' ' ')
      em=$(printf '%s' "$sys_msg" | sed 's/\\/\\\\/g;s/"/\\"/g' | tr '\n' ' ')
      echo "{\"decision\":\"block\",\"reason\":\"${er}\",\"systemMessage\":\"${em}\"}"
    }
  fi
}

# ==========================================================
# 리뷰 전용 모드: 태스크 체크 불필요
# ==========================================================
if [[ "$MODE" == "review-spec" ]] || [[ "$MODE" == "review-impl" ]]; then
  if [[ "$COMPLETED" == "true" ]]; then
    rm -f "$STATE_FILE"
    exit 0
  fi
  REASON="consensus-build 리뷰 파이프라인이 아직 완료되지 않았다. 현재 Phase ${PHASE:-?}이다. .claude/consensus-build-state.local.md 상태 파일을 Read 도구로 읽고 남은 작업을 계속 진행하라."
  output_block_json "$REASON" "🔄 consensus-build review Phase ${PHASE:-?} | 리뷰 완료 전 종료 불가"
  exit 0
fi

# ==========================================================
# Pipeline / implement / plan 모드: 태스크 완료 여부 검증
# ==========================================================

# impl 파일에서 실제 TASK 개수 카운트 (cross-check)
ACTUAL_TASK_COUNT=0
if [[ -n "$IMPL_FILE" ]] && [[ -f "$IMPL_FILE" ]]; then
  ACTUAL_TASK_COUNT=$(grep -c '^### TASK-' "$IMPL_FILE" 2>/dev/null || echo 0)
fi

# 태스크 완료 여부 판단
TASKS_DONE=false
if [[ -n "$TASKS_COMPLETED" ]] && [[ "$TASKS_COMPLETED" -gt 0 ]] 2>/dev/null; then
  # 실제 impl 파일이 있으면 그 개수를 기준으로 판단 (state file 조작 방지)
  if [[ "$ACTUAL_TASK_COUNT" -gt 0 ]]; then
    [[ "$TASKS_COMPLETED" -ge "$ACTUAL_TASK_COUNT" ]] 2>/dev/null && TASKS_DONE=true
  elif [[ -n "$TASKS_TOTAL" ]] && [[ "$TASKS_COMPLETED" -ge "$TASKS_TOTAL" ]] 2>/dev/null; then
    # impl 파일 없으면 state file의 tasks_total로 fallback
    TASKS_DONE=true
  fi
fi

# Phase 6 이전(기능정의서/구현계획 단계)에서는 태스크 체크 불필요
if [[ -n "$PHASE" ]] && [[ "$PHASE" -lt 6 ]] 2>/dev/null && [[ "$COMPLETED" == "true" ]]; then
  rm -f "$STATE_FILE"
  exit 0
fi

# 파이프라인 완료 + 태스크 완료 → 종료 허용
if [[ "$COMPLETED" == "true" ]] && [[ "$TASKS_DONE" == "true" ]]; then
  rm -f "$STATE_FILE"
  exit 0
fi

# ==========================================================
# 차단
# ==========================================================
REF_TOTAL="${ACTUAL_TASK_COUNT:-${TASKS_TOTAL:-?}}"
TASK_INFO="${CURRENT_TASK:-다음 TASK}"

# (#1) systemMessage: 컨텍스트 압축과 무관하게 매 턴 주입
SYS_MSG="🔄 consensus-build Phase ${PHASE:-?} | TASK ${TASKS_COMPLETED:-0}/${REF_TOTAL} (현재: ${TASK_INFO}) | 모든 TASK 완료 전 종료 불가"

if [[ "$COMPLETED" == "true" ]] && [[ "$TASKS_DONE" == "false" ]]; then
  # (#5) 원자적 파일 쓰기: tmp + mv
  TEMP_FILE="${STATE_FILE}.tmp.$$"
  sed 's/^completed: *true/completed: false/' "$STATE_FILE" > "$TEMP_FILE" && mv "$TEMP_FILE" "$STATE_FILE"

  # (#7 + #12) current_task 포함 + 자기 완결적 REASON
  REASON="consensus-build 파이프라인: completed를 true로 설정했지만 태스크가 완료되지 않았다 (${TASKS_COMPLETED:-0}/${REF_TOTAL} 완료). completed를 false로 되돌렸다. 지금 즉시 .claude/consensus-build-state.local.md를 Read 도구로 읽고, 구현 계획 파일(${IMPL_FILE})을 읽어 ${TASK_INFO}부터 모든 TASK를 끝까지 구현하라. Sprint 단위로 멈추지 말 것. 컨텍스트가 부족하다고 스스로 판단하지 말 것. 실제로 시스템이 컨텍스트를 압축할 때까지 계속 진행하라."
else
  # (#12) SKILL.md 간접 참조 제거 → 자기 완결적 REASON
  REASON="consensus-build 파이프라인이 아직 완료되지 않았다. 현재 Phase ${PHASE:-?}, 태스크 진행 ${TASKS_COMPLETED:-0}/${REF_TOTAL}. 지금 즉시 .claude/consensus-build-state.local.md를 Read 도구로 읽고, 구현 계획 파일(${IMPL_FILE:-없음})을 읽어 ${TASK_INFO}부터 남은 모든 TASK를 구현하라. Phase 6 이전이면 현재 Phase의 작업을 완료하고 다음 Phase로 진행하라. 모든 TASK를 완주한 후에만 종료하라."
fi

output_block_json "$REASON" "$SYS_MSG"
exit 0
