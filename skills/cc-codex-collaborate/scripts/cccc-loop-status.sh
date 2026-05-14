#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"
ROOT="$(cccc_repo_root)"
cd "$ROOT"
SETTINGS=".claude/settings.json"
STATE="docs/cccc/state.json"
HOOK_DIR=".claude/hooks"

has_cmd() {
  local cmd="$1"
  [[ -f "$SETTINGS" ]] && jq -e --arg cmd "$cmd" '.. | objects | select(.command? == $cmd)' "$SETTINGS" >/dev/null 2>&1
}

state_value() {
  local key="$1" default="$2"
  if [[ -f "$STATE" ]]; then jq -r "$key // \"$default\"" "$STATE" 2>/dev/null || echo "$default"; else echo "$default"; fi
}

echo "cc-codex-collaborate loop status"
echo "- Workspace: docs/cccc"
echo "- State file: $([[ -f "$STATE" ]] && echo present || echo missing)"
echo "- Mode: $(state_value '.mode' 'unknown')"
echo "- Enabled: $(state_value '.enabled' 'false')"
echo "- Status: $(state_value '.status' 'unknown')"
echo "- Pause reason: $(state_value '.pause_reason' '')"
echo "- Settings file: $([[ -f "$SETTINGS" ]] && echo present || echo missing)"

declare -A hooks=(
  [PreToolUse]="\${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-sensitive-op-guard.sh"
  [Stop]="\${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop.sh"
  [StopFailure]="\${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop-failure.sh"
)

for name in PreToolUse Stop StopFailure; do
  script="${hooks[$name]##*/}"
  if [[ -x "$HOOK_DIR/$script" ]]; then file_status="installed"; elif [[ -f "$HOOK_DIR/$script" ]]; then file_status="present but not executable"; else file_status="missing"; fi
  if has_cmd "${hooks[$name]}"; then config_status="configured"; else config_status="not configured"; fi
  echo "- $name hook: $file_status, $config_status"
done

if [[ -f "$STATE" ]] && [[ "$(state_value '.mode' 'supervised-auto')" == "full-auto-safe" ]] && has_cmd "\${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop.sh"; then
  echo "- Auto loop: enabled"
else
  echo "- Auto loop: disabled"
fi
