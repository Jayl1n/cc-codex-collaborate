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

cccc_skill_dir() {
  local root
  root="$(cccc_repo_root)"
  echo "$root/.claude/skills/cc-codex-collaborate"
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
  mkdir -p docs/cccc/{reviews/plan,reviews/milestones,logs,runtime,templates}
}
