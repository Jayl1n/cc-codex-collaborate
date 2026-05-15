#!/usr/bin/env bash
# CCCC codex-recheck — re-check bypassed gates when Codex becomes available.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"
ROOT="$(cccc_repo_root)"
cd "$ROOT"
CONFIG="docs/cccc/config.json"
STATE="docs/cccc/state.json"

if [[ ! -f "$CONFIG" || ! -f "$STATE" ]]; then
  echo "ERROR: docs/cccc/config.json or state.json not found."
  echo "Run /cccc setup first."
  exit 1
fi

# Read pending rechecks
PENDING_COUNT="$(jq -r '.pending_codex_recheck | length // 0' "$STATE" 2>/dev/null || echo '0')"

echo "cc-codex-collaborate codex-recheck"
echo "=================================="
echo ""

if [[ "$PENDING_COUNT" == "0" ]]; then
  echo "No pending Codex rechecks."
  echo "All gates have been reviewed by Codex."
  exit 0
fi

echo "Pending Codex rechecks: $PENDING_COUNT"
echo ""
echo "Items:"
jq -r '.pending_codex_recheck[] | "  - gate: \(.gate), milestone: \(.milestone_id // "N/A"), bypassed at: \(.bypassed_at // "unknown"), reason: \(.reason // "unknown")"' "$STATE" 2>/dev/null || echo "  (could not parse pending list)"
echo ""

# Check Codex availability
CODEX_AVAILABLE=false
if command -v codex &>/dev/null; then
  CODEX_AVAILABLE=true
fi

if ! $CODEX_AVAILABLE; then
  echo "Codex CLI is NOT available."
  echo "Cannot perform recheck now."
  echo "Install or configure Codex CLI, then re-run: /cccc codex-recheck"
  exit 0
fi

echo "Codex CLI is available."
echo ""
echo "===CODEX_RECHECK_REQUIRED==="
echo ""
echo "Claude Code must now:"
echo "1. For each pending recheck item, run the appropriate Codex review:"
echo "   - plan_review → run Codex adversarial plan review"
echo "   - milestone_review → run Codex milestone review"
echo "   - final_review → run Codex final review"
echo ""
echo "2. If Codex review passes:"
echo "   - Update state gate status from 'bypassed' to 'pass'"
echo "   - Remove item from pending_codex_recheck"
echo "   - If no more pending items, set lower_assurance_mode = false"
echo ""
echo "3. If Codex review fails:"
echo "   - Set status = PAUSED_FOR_CODEX_RECHECK_FAILURE"
echo "   - Record findings and risk in decision-log"
echo "   - Do NOT delete original bypass artifact"
echo ""
echo "Do NOT skip any pending recheck."
