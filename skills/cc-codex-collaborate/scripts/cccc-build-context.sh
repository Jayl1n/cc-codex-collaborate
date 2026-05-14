#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"

ROOT="$(cccc_repo_root)"
cd "$ROOT"
cccc_init_dirs
NOW="$(cccc_now)"
OUT="docs/cccc/context-bundle.md"

read_file() {
  local file="$1"
  echo "\n## $file"
  if [[ -f "$file" ]]; then
    sed -n '1,240p' "$file"
  else
    echo "Missing: $file"
  fi
}

{
  echo "# CCCC Context Bundle"
  echo ""
  echo "Generated: $NOW"
  echo ""
  read_file "docs/cccc/state.json"
  read_file "docs/cccc/project-brief.md"
  read_file "docs/cccc/project-map.md"
  read_file "docs/cccc/current-state.md"
  read_file "docs/cccc/architecture.md"
  read_file "docs/cccc/test-strategy.md"
  read_file "docs/cccc/roadmap.md"
  read_file "docs/cccc/milestone-backlog.md"
  read_file "docs/cccc/decision-log.md"
  read_file "docs/cccc/risk-register.md"
  read_file "docs/cccc/open-questions.md"

  echo "\n## Git status"
  git status --short 2>/dev/null || true

  echo "\n## Git diff stat"
  git diff --stat 2>/dev/null || true

  echo "\n## Git diff"
  git diff -- . ':!docs/cccc/context-bundle.md' 2>/dev/null || true

  echo "\n## Recent logs"
  find docs/cccc/logs -type f -maxdepth 1 -print -exec tail -80 {} \; 2>/dev/null || true

  echo "\n## Recent reviews"
  find docs/cccc/reviews -type f -name '*.json' -maxdepth 3 -print -exec tail -120 {} \; 2>/dev/null || true
} > "$OUT"

echo "$OUT"
