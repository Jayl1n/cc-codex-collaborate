#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"
ROOT="$(cccc_repo_root)"
cd "$ROOT"
SKILL_DIR="$(cccc_skill_dir)"
SETTINGS=".claude/settings.json"
CONFIG="docs/cccc/config.json"
STATE="docs/cccc/state.json"
BACKUP=".claude/settings.json.cccc-backup-$(date -u +%Y%m%dT%H%M%SZ)"

# ── Step 1: Enable stop-hook automation ──

mkdir -p .claude/hooks docs/cccc/runtime
cp "$SKILL_DIR/hooks/cccc-sensitive-op-guard.sh" .claude/hooks/cccc-sensitive-op-guard.sh
cp "$SKILL_DIR/hooks/cccc-stop.sh" .claude/hooks/cccc-stop.sh
cp "$SKILL_DIR/hooks/cccc-stop-failure.sh" .claude/hooks/cccc-stop-failure.sh
chmod +x .claude/hooks/cccc-*.sh

# Ensure workspace exists
if [[ ! -f docs/cccc/state.json ]]; then
  "$SCRIPT_DIR/cccc-init.sh"
fi

# Backup and update settings.json
if [[ -f "$SETTINGS" ]]; then
  cp "$SETTINGS" "$BACKUP"
else
  mkdir -p .claude
  echo '{}' > "$SETTINGS"
fi

python3 - <<'PY'
import json
from pathlib import Path
settings_path = Path('.claude/settings.json')
try:
    settings = json.loads(settings_path.read_text())
except Exception:
    settings = {}
settings.setdefault('hooks', {})

def add_hook(event, matcher, command):
    hooks = settings['hooks'].setdefault(event, [])
    for group in hooks:
        if group.get('matcher', '') == matcher:
            entries = group.setdefault('hooks', [])
            if not any(h.get('type') == 'command' and h.get('command') == command for h in entries):
                entries.append({'type': 'command', 'command': command})
            return
    hooks.append({'matcher': matcher, 'hooks': [{'type': 'command', 'command': command}]})

add_hook('PreToolUse', 'Bash|Edit|Write|MultiEdit', '${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-sensitive-op-guard.sh')
add_hook('Stop', '', '${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop.sh')
add_hook('StopFailure', '', '${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop-failure.sh')
settings_path.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + '\n')
PY

# Update config.json: enable loop, set mode
if [[ -f "$CONFIG" ]]; then
  python3 - <<'PY'
import json
from pathlib import Path
p = Path('docs/cccc/config.json')
data = json.loads(p.read_text())
data.setdefault('automation', {})['stop_hook_loop_enabled'] = True
data.setdefault('automation', {}).setdefault('max_stop_hook_continuations', 10)
data['mode'] = 'full-auto-safe'
p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
PY
fi

# Update state.json: runtime fields only, remove mode/enabled if present
python3 - <<'PY'
import json
from pathlib import Path
state_path = Path('docs/cccc/state.json')
try:
    state = json.loads(state_path.read_text())
except Exception:
    state = {}
state['stop_hook_continuations'] = 0
state.pop('mode', None)
state.pop('enabled', None)
state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
PY

echo "Enabled cc-codex-collaborate loop automation."
echo "Installed hooks into .claude/hooks and registered them in .claude/settings.json."
echo "Updated docs/cccc/config.json: mode = full-auto-safe"
echo "Updated docs/cccc/config.json: automation.stop_hook_loop_enabled = true"
echo "Updated docs/cccc/state.json: stop_hook_continuations = 0"
if [[ -f "$BACKUP" ]]; then echo "Backup: $BACKUP"; fi

echo ""

# ── Step 2: Check if an active workflow can be continued ──

# Check docs sync status before continuing
DOCS_INVALIDATED="$(jq -r '.planning_invalidated_by_doc_change // false' "$STATE" 2>/dev/null || echo 'false')"
DOCS_STATUS="$(jq -r '.docs_sync_status // "clean"' "$STATE" 2>/dev/null || echo 'clean')"
LOOP_STATUS="$(jq -r '.status // "UNKNOWN"' "$STATE" 2>/dev/null || echo 'UNKNOWN')"

# Check curation gate before continuing
CURATION_REQUIRES_REPLAN="$(jq -r '.curation_requires_replan // false' "$STATE" 2>/dev/null || echo 'false')"
if [[ -f docs/cccc/curation-state.json ]]; then
  CURATION_STATE_REPLAN="$(jq -r '.requires_replan // false' docs/cccc/curation-state.json 2>/dev/null || echo 'false')"
  CURATION_STATE_DIRTY="$(jq -r '.canonical_docs_dirty // false' docs/cccc/curation-state.json 2>/dev/null || echo 'false')"
  CURATION_CONFLICTS="$(jq -r '.pending_conflicts // [] | length' docs/cccc/curation-state.json 2>/dev/null || echo '0')"
else
  CURATION_STATE_REPLAN="false"
  CURATION_STATE_DIRTY="false"
  CURATION_CONFLICTS="0"
fi

if [[ "$CURATION_REQUIRES_REPLAN" == "true" || "$CURATION_STATE_REPLAN" == "true" || "$CURATION_CONFLICTS" -gt 0 ]]; then
  echo "CCCC_LOOP_START_RESULT=enabled"
  echo "CCCC_WORKFLOW_ACTION=needs_curation"
  echo "CCCC_WORKFLOW_REASON=\"Raw or curated docs changed and require curation/replan before implementation.\""
  echo ""
  echo "Curation gate is blocking workflow continuation."
  if [[ "$CURATION_CONFLICTS" -gt 0 ]]; then
    echo "There are $CURATION_CONFLICTS pending conflict(s) requiring user resolution."
  fi
  echo ""
  echo "Run: /cccc curate-docs"
  echo "Or: /cccc distill-project"
  echo "Or: /cccc replan (after curation)"
  exit 0
fi

if [[ "$DOCS_INVALIDATED" == "true" || "$LOOP_STATUS" == "NEEDS_REPLAN" ]]; then
  echo "CCCC_LOOP_START_RESULT=enabled"
  echo "CCCC_WORKFLOW_ACTION=needs_replan"
  echo "CCCC_WORKFLOW_REASON=\"Documentation changes invalidated the current plan.\""
  echo ""
  echo "Planning has been invalidated by documentation changes."
  echo "Run: /cc-codex-collaborate replan"
  exit 0
fi

# Check if doc hashes are stale (quick check)
if [[ -f docs/cccc/doc-index.json ]]; then
  STALE_DOCS="$(python3 - "$SCRIPT_DIR" <<'PYCHK'
import sys, json, hashlib
from pathlib import Path
sys.path.insert(0, sys.argv[1])
from cccc_docs import WORKSPACE, TRACKED_DOCS, file_sha256, read_doc_index
index = read_doc_index()
stale = []
for doc_name in TRACKED_DOCS:
    entry = index.get("documents", {}).get(doc_name, {})
    old_hash = entry.get("sha256")
    if old_hash:
        current_hash = file_sha256(WORKSPACE / doc_name)
        if current_hash and current_hash != old_hash:
            stale.append(doc_name)
if stale:
    print("stale:" + ",".join(stale))
else:
    print("clean")
PYCHK
  )" || STALE_DOCS="clean"

  if [[ "$STALE_DOCS" != "clean" ]]; then
    STALE_LIST="${STALE_DOCS#stale:}"
    echo "CCCC_LOOP_START_RESULT=enabled"
    echo "CCCC_WORKFLOW_ACTION=needs_sync_docs"
    echo "CCCC_WORKFLOW_REASON=\"Tracked documents have changed since last sync: $STALE_LIST\""
    echo ""
    echo "Tracked documents have changed since last sync:"
    echo "  $STALE_LIST"
    echo ""
    echo "Run: /cc-codex-collaborate sync-docs"
    echo "Do not continue old workflow with stale documents."
    exit 0
  fi
fi

DETECT_RESULT="$(python3 "$SCRIPT_DIR/cccc-detect-workflow.py" detect 2>/dev/null || echo '{}')"

WORKFLOW_ACTION="$(echo "$DETECT_RESULT" | jq -r '.action // "needs_task"')"
WORKFLOW_REASON="$(echo "$DETECT_RESULT" | jq -r '.reason // "No task, roadmap, or milestone backlog found."')"
WORKFLOW_MILESTONE="$(echo "$DETECT_RESULT" | jq -r '.milestone_id // empty')"
WORKFLOW_REPAIRED="$(echo "$DETECT_RESULT" | jq -r '.state_repaired // false')"

# ── Step 3: Output machine-readable markers and human guidance ──

echo "CCCC_LOOP_START_RESULT=enabled"
echo "CCCC_WORKFLOW_ACTION=$WORKFLOW_ACTION"
echo "CCCC_WORKFLOW_REASON=\"$WORKFLOW_REASON\""
echo ""

case "$WORKFLOW_ACTION" in
  continue_now)
    echo "Loop automation is enabled and an active workflow was found."
    if [[ "$WORKFLOW_REPAIRED" == "true" && -n "$WORKFLOW_MILESTONE" ]]; then
      echo "State repaired: current_milestone_id set to $WORKFLOW_MILESTONE."
    fi
    echo "Continue the cc-codex-collaborate state machine now."
    echo "Do not stop after enabling hooks."
    echo "Read docs/cccc/config.json and docs/cccc/state.json, then execute the next safe step."
    ;;
  needs_resume)
    echo "Existing workflow found but requires resume."
    echo "Run: /cc-codex-collaborate resume"
    ;;
  needs_task)
    echo "No workflow found. Start a new task:"
    echo "  /cc-codex-collaborate \"your task description\""
    ;;
  done)
    echo "Current workflow has already completed."
    echo "Start a new task: /cc-codex-collaborate \"your task description\""
    ;;
esac
