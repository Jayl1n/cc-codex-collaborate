#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"
ROOT="$(cccc_repo_root)"
cd "$ROOT"
SETTINGS=".claude/settings.json"
CONFIG="docs/cccc/config.json"
STATE="docs/cccc/state.json"
HOOK_DIR=".claude/hooks"

# Helper: read value from JSON file using python3
json_value() {
  local file="$1" key="$2" default="$3"
  python3 - "$file" "$key" "$default" <<'PY'
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
}

# Helper: check if a hook command is registered in settings
has_hook_cmd() {
  local cmd="$1"
  python3 - "$SETTINGS" "$cmd" <<'PY'
import json, sys
try:
    settings = json.loads(open(sys.argv[1]).read())
    target = sys.argv[2]
    for event, groups in settings.get('hooks', {}).items():
        for group in groups:
            for hook in group.get('hooks', []):
                if hook.get('command') == target:
                    print('yes')
                    sys.exit(0)
    print('no')
except Exception:
    print('no')
PY
}

echo "cc-codex-collaborate status"
echo "============================"
echo ""

# ── Version information ──

SKILL_DIR="$(cccc_skill_dir)"
SKILL_VERSION="$(cat "$SKILL_DIR/VERSION" 2>/dev/null || echo 'unknown')"
PROJECT_VERSION="$(json_value "$CONFIG" '.skill.installed_version' 'unknown')"
# Fallback to old version field if skill.installed_version missing
if [[ "$PROJECT_VERSION" == "unknown" ]]; then
  PROJECT_VERSION="$(json_value "$CONFIG" '.version' 'unknown')"
fi

echo "Version:"
echo "  Skill version: $SKILL_VERSION"
echo "  Project installed version: $PROJECT_VERSION"

# Schema versions
CONFIG_SCHEMA="$(json_value "$CONFIG" '.skill.workspace_schema_version' 'unknown')"
STATE_SCHEMA="$(json_value "$STATE" '.workspace_schema_version' 'unknown')"

echo "  Config schema version: $CONFIG_SCHEMA"
echo "  State schema version: $STATE_SCHEMA"

# ── Migration history ──

if [[ -f "$STATE" ]]; then
  LAST_MIGRATION="$(json_value "$STATE" '.last_migration_at' '')"
  FROM_VERSION="$(json_value "$STATE" '.last_migration_from_version' '')"
  TO_VERSION="$(json_value "$STATE" '.last_migration_to_version' '')"
  if [[ -n "$LAST_MIGRATION" && "$LAST_MIGRATION" != "null" ]]; then
    echo "  Last migration: $LAST_MIGRATION"
    echo "  Migration: $FROM_VERSION -> $TO_VERSION"
  fi
fi

echo ""

# ── Update recommendation ──

if [[ "$SKILL_VERSION" != "$PROJECT_VERSION" ]]; then
  echo "Update recommended: YES"
  echo "  Run: /cc-codex-collaborate update"
else
  echo "Update recommended: NO (versions match)"
fi

echo ""

# ── Config status ──

if [[ -f "$CONFIG" ]]; then
  echo "Config file: present ($CONFIG)"
  echo "  mode: $(json_value "$CONFIG" '.mode' 'unknown')"
  echo "  stop_hook_loop_enabled: $(json_value "$CONFIG" '.automation.stop_hook_loop_enabled' 'false')"
  echo "  user_language: $(json_value "$CONFIG" '.language.user_language' 'auto')"
else
  echo "Config file: MISSING ($CONFIG)"
  echo "  Run /cc-codex-collaborate setup first."
fi

echo ""

# ── State status ──

if [[ -f "$STATE" ]]; then
  echo "State file: present ($STATE)"
  echo "  status: $(json_value "$STATE" '.status' 'unknown')"
  echo "  current_milestone: $(json_value "$STATE" '.current_milestone_id' 'none')"
  echo "  pause_reason: $(json_value "$STATE" '.pause_reason' '')"
  echo "  stop_hook_continuations: $(json_value "$STATE" '.stop_hook_continuations' '0')"
else
  echo "State file: MISSING ($STATE)"
fi

echo ""

# Hooks directory and files
echo "Hooks directory: $([[ -d "$HOOK_DIR" ]] && echo present || echo missing)"
for script in cccc-sensitive-op-guard.sh cccc-stop.sh cccc-stop-failure.sh; do
  if [[ -x "$HOOK_DIR/$script" ]]; then
    file_status="installed"
  elif [[ -f "$HOOK_DIR/$script" ]]; then
    file_status="present (not executable)"
  else
    file_status="missing"
  fi
  echo "  $script: $file_status"
done

echo ""

# Settings.json hook registrations
echo "Settings file: $([[ -f "$SETTINGS" ]] && echo present || echo missing)"
hook_commands=(
  "PreToolUse:\${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-sensitive-op-guard.sh"
  "Stop:\${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop.sh"
  "StopFailure:\${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop-failure.sh"
)
for entry in "${hook_commands[@]}"; do
  event="${entry%%:*}"
  cmd="${entry#*:}"
  configured="$(has_hook_cmd "$cmd")"
  echo "  $event: $configured"
done

echo ""

# Overall loop status
loop_enabled_in_config="false"
if [[ -f "$CONFIG" ]]; then
  loop_enabled_in_config="$(json_value "$CONFIG" '.automation.stop_hook_loop_enabled' 'false')"
fi
stop_hook_registered="$(has_hook_cmd '${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop.sh')"

if [[ "$loop_enabled_in_config" == "True" ]] && [[ "$stop_hook_registered" == "yes" ]]; then
  echo "Auto loop: ENABLED"
else
  echo "Auto loop: DISABLED"
fi

# ── Docs sync status ──

echo ""
echo "Docs sync:"
DOC_INDEX="docs/cccc/doc-index.json"
if [[ -f "$DOC_INDEX" ]]; then
  echo "  doc-index: present"
  echo "  docs_sync_status: $(json_value "$STATE" '.docs_sync_status' 'unknown')"
  echo "  changed_since_last_sync: $(json_value "$STATE" '.docs_changed_since_last_sync' 'unknown')"
  echo "  planning_invalidated: $(json_value "$STATE" '.planning_invalidated_by_doc_change' 'unknown')"
  LAST_IMPACT="$(json_value "$STATE" '.last_doc_change_impact' '')"
  if [[ -n "$LAST_IMPACT" && "$LAST_IMPACT" != "null" ]]; then
    echo "  last_impact: $LAST_IMPACT"
  fi
  LAST_SYNC="$(json_value "$DOC_INDEX" '.last_synced_at' '')"
  if [[ -n "$LAST_SYNC" && "$LAST_SYNC" != "null" ]]; then
    echo "  last_synced_at: $LAST_SYNC"
  fi

  PLANNING_INV="$(json_value "$STATE" '.planning_invalidated_by_doc_change' 'false')"
  DOCS_CHANGED="$(json_value "$STATE" '.docs_changed_since_last_sync' 'false')"
  if [[ "$PLANNING_INV" == "True" ]]; then
    echo "  recommended: /cccc replan"
  elif [[ "$DOCS_CHANGED" == "True" ]]; then
    echo "  recommended: /cccc sync-docs"
  else
    echo "  recommended: none"
  fi
else
  echo "  doc-index: MISSING"
  echo "  recommended: /cccc sync-docs (initialize index)"
fi

# ── Codex bypass status ──

echo ""
echo "Codex bypass:"
CODEX_POLICY="$(json_value "$CONFIG" '.codex.unavailable_policy' 'strict_pause')"
BYPASS_ENABLED="$(json_value "$CONFIG" '.codex.bypass.enabled' 'false')"
echo "  unavailable_policy: $CODEX_POLICY"
echo "  bypass enabled: $BYPASS_ENABLED"
LOWER_ASSURANCE="$(json_value "$STATE" '.lower_assurance_mode' 'false')"
CONSECUTIVE_BYPASS="$(json_value "$STATE" '.consecutive_bypassed_gates' '0')"
PENDING_RECHECK="$(jq -r '.pending_codex_recheck | length // 0' "$STATE" 2>/dev/null || echo '0')"
echo "  lower_assurance_mode: $LOWER_ASSURANCE"
echo "  consecutive_bypassed_gates: $CONSECUTIVE_BYPASS"
echo "  pending_codex_recheck: $PENDING_RECHECK"
LAST_BYPASS_FILE="$(json_value "$STATE" '.last_codex_bypass_review_file' '')"
if [[ -n "$LAST_BYPASS_FILE" && "$LAST_BYPASS_FILE" != "null" ]]; then
  echo "  last_bypass_review: $LAST_BYPASS_FILE"
fi
if [[ "$LOWER_ASSURANCE" == "True" ]]; then
  echo "  recommended: /cccc codex-recheck (when Codex available)"
fi

# ── Codex budget ──

echo ""
echo "Codex budget:"
REVIEW_POLICY_MODE="$(json_value "$CONFIG" '.codex_review_policy.mode' 'unknown')"
CODEX_CALLS="$(jq -r '.codex_budget.codex_calls_this_run // 0' "$STATE" 2>/dev/null || echo '0')"
MAX_CALLS="$(json_value "$CONFIG" '.codex_review_policy.budget.max_codex_calls_per_run' '5')"
PENDING_BATCH="$(jq -r '.codex_review_batch.pending_milestones // [] | length' "$STATE" 2>/dev/null || echo '0')"
LAST_COMMIT="$(jq -r '.checkpoint.last_codex_approved_commit // "none"' "$STATE" 2>/dev/null || echo 'none')"
echo "  review policy mode: $REVIEW_POLICY_MODE"
echo "  calls this run: $CODEX_CALLS / $MAX_CALLS"
echo "  pending batch: $PENDING_BATCH milestone(s)"
echo "  last approved commit: $LAST_COMMIT"

# ── Curation status ──

echo ""
echo "Curation:"
SOURCE_INDEX_FILE="docs/cccc/source-index.json"
CURATION_STATE_FILE="docs/cccc/curation-state.json"
if [[ -f "$SOURCE_INDEX_FILE" ]]; then
  echo "  source-index: present"
  INBOX_TOTAL="$(jq -r '.sources | length // 0' "$SOURCE_INDEX_FILE" 2>/dev/null || echo '0')"
  INBOX_PENDING="$(python3 -c "
import json
idx = json.loads(open('$SOURCE_INDEX_FILE').read())
print(sum(1 for s in idx.get('sources',{}).values() if s.get('requires_curation') and s.get('status') not in ('deleted','archived','ignored')))
" 2>/dev/null || echo '0')"
  echo "  total inbox sources: $INBOX_TOTAL"
  echo "  pending curation: $INBOX_PENDING"
else
  echo "  source-index: MISSING"
  echo "  recommended: /cccc sync-inbox"
fi

if [[ -f "$CURATION_STATE_FILE" ]]; then
  echo "  curation-state: present"
  CURATION_DIRTY="$(jq -r '.canonical_docs_dirty // false' "$CURATION_STATE_FILE" 2>/dev/null || echo 'false')"
  CURATION_REPLAN="$(jq -r '.requires_replan // false' "$CURATION_STATE_FILE" 2>/dev/null || echo 'false')"
  CURATION_CONFLICTS="$(jq -r '.pending_conflicts // [] | length' "$CURATION_STATE_FILE" 2>/dev/null || echo '0')"
  echo "  canonical docs dirty: $CURATION_DIRTY"
  echo "  requires replan: $CURATION_REPLAN"
  echo "  pending conflicts: $CURATION_CONFLICTS"
  if [[ "$CURATION_REPLAN" == "true" ]]; then
    echo "  recommended: /cccc replan"
  elif [[ "$CURATION_CONFLICTS" -gt 0 ]]; then
    echo "  recommended: /cccc curate-docs"
  fi
else
  echo "  curation-state: MISSING"
fi

# ── Resume guidance ──

echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_MILESTONE_ID="$(json_value "$STATE" '.current_milestone_id' '')"
HAS_PLANNING_DOCS="false"
if [[ -f docs/cccc/roadmap.md || -f docs/cccc/milestone-backlog.md || -f docs/cccc/current-state.md ]]; then
  HAS_PLANNING_DOCS="$(python3 "$SCRIPT_DIR/cccc-detect-workflow.py" has-planning-docs 2>/dev/null || echo "false")"
fi

# State mismatch detection
if [[ -f "$STATE" ]] && [[ "$HAS_PLANNING_DOCS" == "true" ]]; then
  if [[ -z "$CURRENT_MILESTONE_ID" || "$CURRENT_MILESTONE_ID" == "null" || "$CURRENT_MILESTONE_ID" == "none" ]]; then
    echo "State mismatch:"
    echo "  Planning docs exist (roadmap/backlog/current-state)"
    echo "  state.current_milestone_id is missing"
    CANDIDATE="$(python3 "$SCRIPT_DIR/cccc-detect-workflow.py" find-milestone 2>/dev/null || echo "null")"
    if [[ "$CANDIDATE" != "null" && "$CANDIDATE" != "" ]]; then
      CANDIDATE_ID="$(echo "$CANDIDATE" | jq -r '.id // empty')"
      CANDIDATE_TITLE="$(echo "$CANDIDATE" | jq -r '.title // empty')"
      if [[ -n "$CANDIDATE_ID" ]]; then
        echo "  Candidate milestone: $CANDIDATE_ID ${CANDIDATE_TITLE:+— $CANDIDATE_TITLE}"
      fi
    fi
    echo ""
    echo "Next: /cc-codex-collaborate resume"
  else
    # Normal resume guidance with milestone
    RESUME_STATUS="$(json_value "$STATE" '.status' 'unknown')"
    case "$RESUME_STATUS" in
      PAUSED_FOR_HUMAN|NEEDS_HUMAN)
        echo "Next: /cc-codex-collaborate resume"
        ;;
      PAUSED_FOR_CODEX)
        echo "Next: configure Codex locally, then /cc-codex-collaborate resume"
        ;;
      PAUSED_FOR_SYSTEM)
        echo "Next: inspect docs/cccc/logs/stop-failure-*.json, then /cc-codex-collaborate resume"
        ;;
      NEEDS_SECRET|SENSITIVE_OPERATION|UNSAFE|FAIL_UNCLEAR|REVIEW_THRESHOLD_EXCEEDED)
        echo "Next: /cc-codex-collaborate resume"
        ;;
      DONE|COMPLETED|FAILED)
        echo "Next: /cc-codex-collaborate \"your task\""
        ;;
      *)
        if [[ "$loop_enabled_in_config" == "True" ]]; then
          echo "Next: /cc-codex-collaborate resume or wait for Stop hook continuation"
        else
          echo "Next: /cc-codex-collaborate \"your task\""
        fi
        ;;
    esac
  fi
elif [[ -f "$STATE" ]]; then
  RESUME_STATUS="$(json_value "$STATE" '.status' 'unknown')"
  case "$RESUME_STATUS" in
    PAUSED_FOR_HUMAN|NEEDS_HUMAN|PAUSED_FOR_CODEX|PAUSED_FOR_SYSTEM|NEEDS_SECRET|SENSITIVE_OPERATION|UNSAFE|FAIL_UNCLEAR|REVIEW_THRESHOLD_EXCEEDED)
      echo "Next: /cc-codex-collaborate resume"
      ;;
    DONE|COMPLETED|FAILED)
      echo "Next: /cc-codex-collaborate \"your task\""
      ;;
    *)
      if [[ "$loop_enabled_in_config" == "True" ]]; then
        echo "Next: /cc-codex-collaborate resume or wait for Stop hook continuation"
      else
        echo "Next: /cc-codex-collaborate \"your task\""
      fi
      ;;
  esac
else
  echo "Next: /cc-codex-collaborate \"your task\""
fi

echo ""
echo "Command aliases:"
_CMD_DIR="${ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}/.claude/commands"
for alias_file in cccc.md cccc-loop-status.md cccc-loop-start.md cccc-loop-stop.md; do
  if [[ -f "$_CMD_DIR/$alias_file" ]]; then
    echo "  /${alias_file%.md}: installed"
  else
    echo "  /${alias_file%.md}: missing"
  fi
done
