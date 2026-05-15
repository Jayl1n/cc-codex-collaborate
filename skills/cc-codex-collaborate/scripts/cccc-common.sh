#!/usr/bin/env bash
# Shared helpers for cc-codex-collaborate.
set -euo pipefail

cccc_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

cccc_root() {
  echo "docs/cccc"
}

cccc_state() {
  echo "docs/cccc/state.json"
}

cccc_config() {
  echo "docs/cccc/config.json"
}

cccc_skill_dir() {
  local root
  root="$(cccc_repo_root)"
  # Prefer dev repo layout (skills/) over installed copy (.claude/skills/)
  # to avoid reading stale templates/hooks/VERSION from an older install.
  if [[ -f "$root/skills/cc-codex-collaborate/SKILL.md" ]]; then
    echo "$root/skills/cc-codex-collaborate"
    return
  fi
  if [[ -f "$root/.claude/skills/cc-codex-collaborate/SKILL.md" ]]; then
    echo "$root/.claude/skills/cc-codex-collaborate"
    return
  fi
  echo "$root/.claude/skills/cc-codex-collaborate"
}

cccc_resolve_script() {
  local script_name="$1"
  local skill_dir
  skill_dir="$(cccc_skill_dir)"
  if [[ -f "$skill_dir/scripts/$script_name" ]]; then
    echo "$skill_dir/scripts/$script_name"
    return 0
  fi
  return 1
}

cccc_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

cccc_require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Missing required command: $cmd" >&2
    exit 127
  fi
}

cccc_init_dirs() {
  mkdir -p docs/cccc/{reviews/plan,reviews/milestones,logs,runtime,templates,backups}
  mkdir -p docs/cccc/{inbox/raw-notes,inbox/gpt-discussions,inbox/imported-docs}
  mkdir -p docs/cccc/{canonical,product,archive/irrelevant,archive/superseded}
  mkdir -p docs/cccc/curation/{reports,conflicts,extractions}
}

# Read a value from config.json. Usage: cccc_config_value '.mode' 'default'
cccc_config_value() {
  local key="$1" default="$2"
  local config
  config="$(cccc_config)"
  if [[ -f "$config" ]]; then
    python3 - "$config" "$key" "$default" <<'PY'
import json, sys
try:
    data = json.loads(open(sys.argv[1]).read())
    parts = sys.argv[2].lstrip('.').split('.')
    v = data
    for p in parts:
        if isinstance(v, dict) and p in v:
            v = v[p]
        else:
            v = None
            break
    print(v if v is not None else sys.argv[3])
except Exception:
    print(sys.argv[3])
PY
  else
    echo "$default"
  fi
}
