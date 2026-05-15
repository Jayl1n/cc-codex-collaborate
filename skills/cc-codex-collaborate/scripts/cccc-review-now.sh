#!/usr/bin/env bash
# CCCC review-now — force immediate Codex review for current milestone or batch.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/cccc-common.sh"
ROOT="$(cccc_repo_root)"
cd "$ROOT"
CONFIG="docs/cccc/config.json"
STATE="docs/cccc/state.json"

if [[ ! -f "$CONFIG" || ! -f "$STATE" ]]; then
  echo "ERROR: docs/cccc/config.json or state.json not found."
  exit 1
fi

MODE="${1:-current}"

case "$MODE" in
  current)
    MID="$(jq -r '.current_milestone_id // empty' "$STATE")"
    if [[ -z "$MID" ]]; then
      echo "No current milestone. Nothing to review."
      exit 0
    fi
    echo "===REVIEW_NOW_REQUIRED==="
    echo "Mode: current milestone"
    echo "Milestone: $MID"
    echo ""
    echo "Claude Code must:"
    echo "1. Rebuild context-bundle (targeted or full depending on risk)"
    echo "2. Run Codex milestone review for $MID"
    echo "3. Update state: current_milestone_codex_review_status"
    echo "4. Increment codex_budget.codex_calls_this_run"
    echo "5. Record review fingerprint in cache"
    echo ""
    echo "If Codex is unavailable, follow bypass policy."
    ;;
  batch)
    PENDING="$(jq -r '.codex_review_batch.pending_milestones // [] | join(", ")' "$STATE")"
    if [[ -z "$PENDING" ]]; then
      echo "No pending batch milestones. Nothing to batch review."
      exit 0
    fi
    echo "===REVIEW_NOW_REQUIRED==="
    echo "Mode: batch review"
    echo "Pending milestones: $PENDING"
    echo ""
    echo "Claude Code must:"
    echo "1. Rebuild context-bundle (targeted)"
    echo "2. Run Codex batch review for all pending milestones"
    echo "3. Clear codex_review_batch.pending_milestones"
    echo "4. Increment codex_budget.codex_calls_this_run by 1"
    echo "5. Record review fingerprint in cache"
    ;;
  full)
    echo "===REVIEW_NOW_REQUIRED==="
    echo "Mode: full context review"
    echo ""
    echo "Claude Code must:"
    echo "1. Rebuild context-bundle-full.md"
    echo "2. Run Codex full context review"
    echo "3. Increment codex_budget.codex_calls_this_run"
    echo "4. Record review fingerprint in cache"
    ;;
  *)
    echo "Usage: cccc-review-now.sh [current|batch|full]"
    exit 1
    ;;
esac
