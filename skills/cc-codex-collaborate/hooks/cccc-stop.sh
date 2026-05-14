#!/usr/bin/env bash
set -euo pipefail

INPUT="$(cat)"
STOP_HOOK_ACTIVE="$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)"
STATE="docs/cccc/state.json"

if [[ ! -f "$STATE" ]]; then
  exit 0
fi

ENABLED="$(jq -r '.enabled // false' "$STATE")"
STATUS="$(jq -r '.status // "UNKNOWN"' "$STATE")"
MODE="$(jq -r '.mode // "supervised-auto"' "$STATE")"
CONTINUATIONS="$(jq -r '.stop_hook_continuations // 0' "$STATE")"
MAX_CONTINUATIONS="$(jq -r '.thresholds.max_stop_hook_continuations // 10' "$STATE")"
PAUSE_REASON="$(jq -r '.pause_reason // empty' "$STATE")"

if [[ "$ENABLED" != "true" ]]; then
  exit 0
fi

case "$STATUS" in
  DONE|FAILED|PAUSED_FOR_HUMAN|NEEDS_HUMAN|NEEDS_SECRET|SENSITIVE_OPERATION|UNSAFE|PAUSED_FOR_SYSTEM)
    exit 0
    ;;
esac

if [[ -n "$PAUSE_REASON" && "$PAUSE_REASON" != "null" ]]; then
  exit 0
fi

if [[ "$MODE" != "full-auto-safe" ]]; then
  exit 0
fi

if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  exit 0
fi

if [[ "$CONTINUATIONS" -ge "$MAX_CONTINUATIONS" ]]; then
  exit 0
fi

python3 .claude/skills/cc-codex-collaborate/scripts/cccc-update-state.py --set "stop_hook_continuations=$((CONTINUATIONS + 1))" >/dev/null 2>&1 || true

jq -n '{
  decision: "block",
  reason: "Continue the cc-codex-collaborate state machine. The loop is enabled, mode is full-auto-safe, and the current status is not done or paused. Continue safely without bypassing human, secret, production, wallet, real-money, or threshold pause conditions."
}'
