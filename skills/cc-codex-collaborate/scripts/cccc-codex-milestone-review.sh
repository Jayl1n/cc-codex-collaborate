#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"

cccc_require_cmd codex
ROOT="$(cccc_repo_root)"
cd "$ROOT"
cccc_init_dirs

CONTEXT="$($SCRIPT_DIR/cccc-build-context.sh)"
MILESTONE_ID="$(jq -r '.current_milestone_id // "UNKNOWN"' docs/cccc/state.json 2>/dev/null || echo UNKNOWN)"
STAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
OUT="docs/cccc/reviews/milestones/${MILESTONE_ID}-review-$STAMP.json"
PROMPT="docs/cccc/runtime/${MILESTONE_ID}-review-prompt-$STAMP.md"
SKILL_DIR="$(cccc_skill_dir)"

cat > "$PROMPT" <<EOF2
$(cat "$SKILL_DIR/prompts/codex-milestone-review.md")

---

# Context Bundle

$(cat "$CONTEXT")
EOF2

codex exec \
  --cd "$ROOT" \
  --sandbox read-only \
  --output-schema "$SKILL_DIR/schemas/codex-milestone-review.schema.json" \
  --output-last-message "$OUT" \
  - < "$PROMPT"

echo "$OUT"
