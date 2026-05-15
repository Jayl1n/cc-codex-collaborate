#!/usr/bin/env bash
# Distill project: rebuild clean project state from raw docs + canonical docs + code + git.
# Does NOT auto-implement code. Must ask user to confirm key conflicts.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"

ROOT="$(cccc_repo_root)"
cd "$ROOT"

CONFIG="docs/cccc/config.json"
STATE="docs/cccc/state.json"
SOURCE_INDEX="docs/cccc/source-index.json"
CURATION_STATE="docs/cccc/curation-state.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: docs/cccc/config.json not found. Run /cccc setup first." >&2
  exit 1
fi

NOW="$(cccc_now)"
REPORT_TS="${NOW//:/-}"
REPORT_TS="${REPORT_TS/T/_}"

mkdir -p docs/cccc/curation/reports

# Generate distill report header
REPORT="docs/cccc/curation/reports/distill-report-${REPORT_TS}.md"

{
  echo "# Distill Project Report"
  echo ""
  echo "Generated: $NOW"
  echo ""

  echo "## Input Sources"
  echo ""

  # List inbox sources
  if [[ -d docs/cccc/inbox ]]; then
    echo "### Inbox"
    find docs/cccc/inbox -type f \( -name "*.md" -o -name "*.txt" \) 2>/dev/null | sort | while read -r f; do
      echo "- $f"
    done
  fi

  echo ""
  echo "### Canonical Docs"
  for f in docs/cccc/project-brief.md docs/cccc/architecture.md docs/cccc/roadmap.md docs/cccc/milestone-backlog.md docs/cccc/test-strategy.md docs/cccc/risk-register.md docs/cccc/open-questions.md; do
    if [[ -f "$f" ]]; then
      echo "- $f (exists)"
    fi
  done
  if [[ -d docs/cccc/canonical ]]; then
    find docs/cccc/canonical -type f -name "*.md" 2>/dev/null | sort | while read -r f; do
      echo "- $f"
    done
  fi

  echo ""
  echo "### Git Status"
  git status --short 2>/dev/null || true

  echo ""
  echo "### Recent Git Log"
  git log --oneline -15 2>/dev/null || true

  echo ""
  echo "### Project Structure"
  find . -maxdepth 2 -type f \( -name "package.json" -o -name "pyproject.toml" -o -name "Cargo.toml" -o -name "go.mod" -o -name "Makefile" \) 2>/dev/null | head -20

  echo ""
  echo "---"
  echo ""
  echo "## Distillation Required"
  echo ""
  echo "Claude Code must now:"
  echo "1. Read all raw inbox docs and canonical docs"
  echo "2. Classify content: engineering facts, product context, business context, out-of-scope, conflicts, open questions"
  echo "3. Update canonical docs with confirmed engineering facts"
  echo "4. Move product/business content to docs/cccc/product/"
  echo "5. Archive irrelevant content"
  echo "6. Ask user to confirm conflicts"
  echo "7. If planning changed, recommend /cccc replan"

} > "$REPORT"

echo "DISTILL_REPORT=$REPORT"
echo "DISTILL_REQUIRED=true"
echo ""
echo "Report generated: $REPORT"
echo ""
echo "Claude Code must now read raw docs, canonical docs, and code,"
echo "then rebuild a clean project state. Ask user to confirm key conflicts."
echo "After distillation, recommend: /cccc replan"
