#!/usr/bin/env bash
# Import external discussion documents into docs/cccc/inbox.
# Does NOT modify canonical docs, roadmap, or state.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"

ROOT="$(cccc_repo_root)"
cd "$ROOT"

INBOX_DIR="docs/cccc/inbox"
IMPORTED_DIR="$INBOX_DIR/imported-docs"

mkdir -p "$IMPORTED_DIR"

NOW="$(cccc_now)"

# Parse arguments: paths to import
IMPORT_PATHS=()
for arg in "$@"; do
  IMPORT_PATHS+=("$arg")
done

imported_files=()
skipped_files=()

if [[ ${#IMPORT_PATHS[@]} -eq 0 ]]; then
  echo "No paths provided."
  echo ""
  echo "Usage:"
  echo "  /cccc ingest-docs path/to/doc.md [path/to/another.md ...]"
  echo ""
  echo "Or manually place documents under:"
  echo "  docs/cccc/inbox/raw-notes/"
  echo "  docs/cccc/inbox/gpt-discussions/"
  echo "  docs/cccc/inbox/imported-docs/"
  echo ""
  echo "Then run: /cccc sync-inbox"
  echo ""
  echo "INGEST_RESULT=no_files"
  exit 0
fi

for src_path in "${IMPORT_PATHS[@]}"; do
  # Resolve relative to repo root
  if [[ ! -f "$src_path" ]]; then
    echo "Skipping (not found): $src_path"
    skipped_files+=("$src_path")
    continue
  fi

  basename="$(basename "$src_path")"
  dest="$IMPORTED_DIR/$basename"

  # Handle duplicate names by appending timestamp
  if [[ -f "$dest" ]]; then
    stem="${basename%.*}"
    ext="${basename##*.}"
    if [[ "$stem" == "$ext" ]]; then
      # No extension
      dest="$IMPORTED_DIR/${basename}-${NOW//:/-}"
    else
      dest="$IMPORTED_DIR/${stem}-${NOW//:/-}.${ext}"
    fi
  fi

  cp "$src_path" "$dest"
  imported_files+=("$dest")
  echo "Imported: $src_path -> $dest"
done

echo ""
echo "INGEST_RESULT=done"
echo "Imported: ${#imported_files[@]} file(s)"
if [[ ${#skipped_files[@]} -gt 0 ]]; then
  echo "Skipped: ${#skipped_files[@]} file(s)"
fi
echo ""
echo "Next: /cccc sync-inbox"

# Auto-run sync-inbox if any files were imported
if [[ ${#imported_files[@]} -gt 0 ]]; then
  echo ""
  echo "=== Auto-running sync-inbox ==="
  python3 "$SCRIPT_DIR/cccc-sync-inbox.py" --json
fi
