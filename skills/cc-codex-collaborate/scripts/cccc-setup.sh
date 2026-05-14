#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"

ROOT="$(cccc_repo_root)"
cd "$ROOT"
SKILL_DIR="$(cccc_skill_dir)"
COMMAND_TEMPLATE_DIR="$SKILL_DIR/templates/commands"
COMMANDS_DIR="$ROOT/.claude/commands"
NOW="$(cccc_now)"

mkdir -p "$COMMANDS_DIR" docs/cccc/runtime

created_commands=()
skipped_commands=()
if [[ -d "$COMMAND_TEMPLATE_DIR" ]]; then
  for src in "$COMMAND_TEMPLATE_DIR"/*.md; do
    [[ -e "$src" ]] || continue
    name="$(basename "$src")"
    dst="$COMMANDS_DIR/$name"
    if [[ ! -f "$dst" ]]; then
      cp "$src" "$dst"
      created_commands+=(".claude/commands/$name")
    else
      skipped_commands+=(".claude/commands/$name")
    fi
  done
fi

# Generate docs/cccc workspace. Existing files are preserved.
"$SCRIPT_DIR/cccc-init.sh" "${*:-}"

cat > docs/cccc/runtime/last-setup.txt <<EOF2
Setup at: $NOW
Generated command files: ${created_commands[*]:-none}
Preserved existing command files: ${skipped_commands[*]:-none}
Workspace: docs/cccc
Hooks enabled: no
EOF2

cat <<EOF2
cc-codex-collaborate setup completed.

Generated or verified:
- docs/cccc/ runtime workspace
- .claude/commands/ shortcut commands

Created command files:
$(if [[ ${#created_commands[@]} -eq 0 ]]; then echo '- none'; else printf -- '- %s\n' "${created_commands[@]}"; fi)

Preserved existing command files:
$(if [[ ${#skipped_commands[@]} -eq 0 ]]; then echo '- none'; else printf -- '- %s\n' "${skipped_commands[@]}"; fi)

Not enabled by setup:
- .claude/hooks/ stop-hook automation
- .claude/settings.json hook registrations

Basic usage:
- /cc-codex-collaborate "your task"
- /cc-codex-collaborate-loop-status
- /cc-codex-collaborate-loop-start
- /cc-codex-collaborate-loop-stop
EOF2
