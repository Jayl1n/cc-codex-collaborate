#!/usr/bin/env bash
set -euo pipefail
STATE="docs/cccc/state.json"
if [[ ! -f "$STATE" ]]; then
  echo "cc-codex-collaborate is not initialized. Run /cc-codex-collaborate setup first."
  exit 1
fi

jq -r '
  "Skill: \(.skill_name) v\(.skill_version)\n" +
  "Workspace: \(.workspace)\n" +
  "Language: \(.user_language)\n" +
  "Mode: \(.mode)\n" +
  "Status: \(.status)\n" +
  "Project context: \(.project_context_status)\n" +
  "Roadmap: \(.roadmap_status)\n" +
  "Current milestone: \(.current_milestone_id // "none")\n" +
  "Pause reason: \(.pause_reason // "none")\n" +
  "Completed milestones: \((.completed_milestones // []) | join(", "))\n" +
  "Known risks: \((.known_risks // []) | length)"
' "$STATE"
