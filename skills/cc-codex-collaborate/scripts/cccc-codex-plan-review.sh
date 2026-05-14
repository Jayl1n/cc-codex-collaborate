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
STAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
OUT="docs/cccc/reviews/plan/plan-review-$STAMP.json"
PROMPT="docs/cccc/runtime/plan-review-prompt-$STAMP.md"
SKILL_DIR="$(cccc_skill_dir)"

cat > "$PROMPT" <<EOF2
$(cat "$SKILL_DIR/prompts/codex-plan-adversarial-review.md")

---

# Context Bundle

$(cat "$CONTEXT")
EOF2

codex exec \
  --cd "$ROOT" \
  --sandbox read-only \
  --output-schema "$SKILL_DIR/schemas/codex-plan-review.schema.json" \
  --output-last-message "$OUT" \
  - < "$PROMPT"

echo "$OUT"
