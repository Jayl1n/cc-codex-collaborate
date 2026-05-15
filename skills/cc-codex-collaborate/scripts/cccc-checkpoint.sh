#!/usr/bin/env bash
# CCCC checkpoint — manage Codex-approved checkpoints for incremental diff review.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cccc-common.sh"
ROOT="$(cccc_repo_root)"
cd "$ROOT"
STATE="docs/cccc/state.json"
CONFIG="docs/cccc/config.json"

if [[ ! -f "$STATE" ]]; then
  echo "ERROR: docs/cccc/state.json not found."
  exit 1
fi

SUBCMD="${1:-status}"

case "$SUBCMD" in
  status)
    LAST_COMMIT="$(jq -r '.checkpoint.last_codex_approved_commit // "none"' "$STATE")"
    PENDING="$(jq -r '.checkpoint.pending_checkpoint_recommendation // false' "$STATE")"
    echo "Checkpoint status:"
    echo "  Last Codex-approved commit: $LAST_COMMIT"
    echo "  Checkpoint recommendation pending: $PENDING"

    if [[ "$LAST_COMMIT" != "none" && "$LAST_COMMIT" != "null" ]]; then
      DIFF_LINES="$(git diff --shortstat "$LAST_COMMIT" 2>/dev/null || echo '')"
      echo "  Diff since checkpoint: ${DIFF_LINES:-none}"
    else
      echo "  No checkpoint recorded yet."
    fi
    ;;

  record)
    if ! git rev-parse HEAD &>/dev/null; then
      echo "ERROR: No git HEAD. Cannot record checkpoint."
      exit 1
    fi
    HEAD_COMMIT="$(git rev-parse HEAD)"
    python3 - "$HEAD_COMMIT" <<'PY'
import json, sys
from pathlib import Path
from datetime import datetime, timezone
ts = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
head = sys.argv[1]
p = Path('docs/cccc/state.json')
st = json.loads(p.read_text())
st.setdefault('checkpoint', {})
st['checkpoint']['last_codex_approved_commit'] = head
st['checkpoint']['last_codex_reviewed_diff_base'] = head
st['checkpoint']['last_codex_reviewed_at'] = ts
st['checkpoint']['pending_checkpoint_recommendation'] = False
p.write_text(json.dumps(st, ensure_ascii=False, indent=2) + '\n')
print(f"Checkpoint recorded: {head}")
print(f"All future reviews will diff from this commit.")
PY
    ;;

  commit)
    if ! git rev-parse HEAD &>/dev/null; then
      echo "ERROR: No git HEAD. Cannot create checkpoint commit."
      exit 1
    fi

    # Check if there are changes to commit
    if git diff --quiet && git diff --cached --quiet; then
      echo "No changes to commit. Use 'record' to mark current HEAD as checkpoint."
      exit 0
    fi

    # Check config for auto_commit
    AUTO_COMMIT="$(jq -r '.codex_review_policy.checkpoint.auto_commit // false' "$CONFIG")"

    if [[ "$AUTO_COMMIT" != "true" ]]; then
      echo "===CHECKPOINT_COMMIT_CONFIRMATION==="
      echo ""
      echo "Proposed commit message:"
      echo "  cccc: checkpoint after Codex-approved review"
      echo ""
      echo "Claude Code must ask the user to confirm this commit."
      echo "Do NOT auto-commit unless user confirms."
    else
      echo "Auto-commit enabled. Creating checkpoint commit."
      git add -A
      git commit -m "cccc: checkpoint after Codex-approved review" --allow-empty
      echo "Checkpoint commit created."

      HEAD_COMMIT="$(git rev-parse HEAD)"
      "$SCRIPT_DIR/cccc-checkpoint.sh" record
    fi
    ;;

  *)
    echo "Usage: cccc-checkpoint.sh [status|record|commit]"
    ;;
esac
