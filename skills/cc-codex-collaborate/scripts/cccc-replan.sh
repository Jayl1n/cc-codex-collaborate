#!/usr/bin/env bash
# CCCC replan — re-read project and docs, update planning, run Codex adversarial plan review.
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
  echo "Run /cc-codex-collaborate setup first."
  exit 1
fi

# Read current state
STATUS="$(jq -r '.status // "UNKNOWN"' "$STATE")"
PLANNING_INVALIDATED="$(jq -r '.planning_invalidated_by_doc_change // false' "$STATE")"
DOCS_SYNC_STATUS="$(jq -r '.docs_sync_status // "clean"' "$STATE")"

echo "cc-codex-collaborate replan"
echo "==========================="
echo ""
echo "Current status: $STATUS"
echo "Docs sync status: $DOCS_SYNC_STATUS"
echo "Planning invalidated: $PLANNING_INVALIDATED"
echo ""

# Check if replan is appropriate
if [[ "$STATUS" == "DONE" || "$STATUS" == "COMPLETED" ]]; then
  echo "Workflow is already complete. Start a new task instead."
  echo "Run: /cc-codex-collaborate \"your task\""
  exit 0
fi

# Rebuild context first
echo "Rebuilding context-bundle..."
"$SCRIPT_DIR/cccc-build-context.sh"
echo ""

# Update state to indicate replan in progress
python3 - <<'PY'
import json
from pathlib import Path
from datetime import datetime, timezone
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
state = json.loads(Path('docs/cccc/state.json').read_text())
state['status'] = 'REPLANNING'
state['pause_reason'] = 'Replan in progress.'
state['roadmap_status'] = 'being_replanned'
state['updated_at'] = ts
Path('docs/cccc/state.json').write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
print(f"State updated: status=REPLANNING, roadmap_status=being_replanned")
PY

echo ""
echo "===REPLAN_REQUIRED==="
echo ""
echo "Claude Code must now:"
echo "1. Re-read the project and docs/cccc documents"
echo "2. Update roadmap.md and milestone-backlog.md based on latest docs"
echo "3. Update current-state.md"
echo "4. Perform Claude planning self-review"
echo "5. Rebuild context-bundle"
echo "6. Run Codex adversarial plan review"
echo ""
echo "After Codex plan review:"
echo "  - If PASS: status -> READY_TO_CONTINUE, planning_invalidated = false"
echo "  - If FAIL/NEEDS_HUMAN/UNAVAILABLE: set appropriate pause status"
echo ""
echo "Do NOT start implementation until Codex plan review passes."
echo "Do NOT skip Codex gates."
