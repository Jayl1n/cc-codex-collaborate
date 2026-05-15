#!/usr/bin/env bash
# cc-codex-collaborate setup script.
# Non-interactive: accepts preset name and optional language.
# The interactive wizard is handled by Claude Code guided by SKILL.md.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"

ROOT="$(cccc_repo_root)"
cd "$ROOT"
SKILL_DIR="$(cccc_skill_dir)"
COMMAND_TEMPLATE_DIR="$SKILL_DIR/templates/commands"
TEMPLATE_DIR="$SKILL_DIR/templates/cccc"
COMMANDS_DIR="$ROOT/.claude/commands"
NOW="$(cccc_now)"

# ── Usage ──
usage() {
  cat <<'EOF'
Usage: cccc-setup.sh [preset] [language]

Presets:
  recommended  Use recommended defaults (default)
  strict       Stronger review, smaller milestones
  custom       Read custom config from stdin (JSON)
  import       Use existing docs/cccc/config.json if present
  keep         Keep existing config, only generate missing workspace files

Language:
  auto         Auto-detect (default)
  zh-CN        Simplified Chinese
  en           English
  <other>      Any language code

Examples:
  cccc-setup.sh recommended
  cccc-setup.sh strict zh-CN
  echo '{"mode":"manual",...}' | cccc-setup.sh custom en
  cccc-setup.sh import
EOF
}

PRESET="${1:-recommended}"
LANGUAGE="${2:-auto}"

if [[ "$PRESET" == "-h" || "$PRESET" == "--help" ]]; then
  usage
  exit 0
fi

cccc_init_dirs

# ── Preset generators ──

preset_recommended() {
  cat <<'JSON'
{
  "version": "0.1.4",
  "language": {"user_language": "auto", "auto_detect": true},
  "workspace": {"root": "docs/cccc", "commit_planning_docs": true, "ignore_logs_and_runtime": true},
  "mode": "supervised-auto",
  "planning": {
    "require_claude_self_review": true,
    "require_codex_adversarial_review": true,
    "max_plan_review_rounds": 3,
    "ask_human_on_ambiguity": true,
    "brainstorm_questions": true
  },
  "milestones": {
    "max_milestones_per_run": 5,
    "max_diff_lines_per_milestone": 1200,
    "max_changed_files_per_milestone": 20,
    "prefer_small_milestones": true
  },
  "review": {
    "max_review_rounds_per_milestone": 3,
    "max_fix_attempts_per_milestone": 3,
    "block_on_p0": true,
    "block_on_p1": true,
    "allow_continue_with_p2": true
  },
  "automation": {"stop_hook_loop_enabled": false, "max_stop_hook_continuations": 10},
  "safety": {
    "pause_on_real_secrets": true,
    "pause_on_wallet_private_keys": true,
    "pause_on_production_access": true,
    "pause_on_real_money": true,
    "pause_on_destructive_commands": true
  },
  "codex": {
    "enabled": true,
    "required": true,
    "fail_closed": true,
    "cli_command": "codex",
    "sandbox": "read-only",
    "require_context_bundle": true,
    "allow_direct_repo_inspection": true,
    "require_plan_review_before_implementation": true,
    "require_milestone_review_before_pass": true,
    "require_final_review_before_done": true
  }
}
JSON
}

preset_strict() {
  cat <<'JSON'
{
  "version": "0.1.4",
  "language": {"user_language": "auto", "auto_detect": true},
  "workspace": {"root": "docs/cccc", "commit_planning_docs": true, "ignore_logs_and_runtime": true},
  "mode": "supervised-auto",
  "planning": {
    "require_claude_self_review": true,
    "require_codex_adversarial_review": true,
    "max_plan_review_rounds": 4,
    "ask_human_on_ambiguity": true,
    "brainstorm_questions": true
  },
  "milestones": {
    "max_milestones_per_run": 3,
    "max_diff_lines_per_milestone": 600,
    "max_changed_files_per_milestone": 10,
    "prefer_small_milestones": true
  },
  "review": {
    "max_review_rounds_per_milestone": 4,
    "max_fix_attempts_per_milestone": 2,
    "block_on_p0": true,
    "block_on_p1": true,
    "allow_continue_with_p2": false
  },
  "automation": {"stop_hook_loop_enabled": false, "max_stop_hook_continuations": 6},
  "safety": {
    "pause_on_real_secrets": true,
    "pause_on_wallet_private_keys": true,
    "pause_on_production_access": true,
    "pause_on_real_money": true,
    "pause_on_destructive_commands": true
  },
  "codex": {
    "enabled": true,
    "required": true,
    "fail_closed": true,
    "cli_command": "codex",
    "sandbox": "read-only",
    "require_context_bundle": true,
    "allow_direct_repo_inspection": true,
    "require_plan_review_before_implementation": true,
    "require_milestone_review_before_pass": true,
    "require_final_review_before_done": true,
    "unavailable_policy": "ask_or_bypass_once",
    "bypass": {
      "enabled": true,
      "mode": "once_per_gate",
      "require_human_confirmation": true,
      "allowed_reasons": ["quota_exhausted","codex_cli_unavailable","codex_auth_unavailable","codex_api_error","user_explicit_override"],
      "default_scope": "current_gate_only",
      "max_consecutive_bypassed_gates": 1,
      "record_in_decision_log": true,
      "mark_outputs_as_lower_assurance": true,
      "block_bypass_for_critical_risk": true,
      "block_bypass_for_high_risk_by_default": true,
      "allow_for_low_risk": true,
      "allow_for_medium_risk": true,
      "allow_for_high_risk": false,
      "allow_for_critical_risk": false,
      "require_later_codex_recheck": true
    }
  }
}
JSON
}

# ── Generate config.json ──

CONFIG_EXISTS=false
if [[ -f docs/cccc/config.json ]]; then
  CONFIG_EXISTS=true
fi

case "$PRESET" in
  recommended|strict)
    if $CONFIG_EXISTS; then
      mkdir -p docs/cccc/backups
      cp docs/cccc/config.json "docs/cccc/backups/config.${NOW//:/-}.json"
    fi
    "preset_$PRESET" > docs/cccc/config.json
    ;;
  custom)
    if $CONFIG_EXISTS; then
      mkdir -p docs/cccc/backups
      cp docs/cccc/config.json "docs/cccc/backups/config.${NOW//:/-}.json"
    fi
    # Read custom config from stdin
    cat > docs/cccc/config.json
    ;;
  import)
    if ! $CONFIG_EXISTS; then
      # No existing config, use recommended as fallback
      preset_recommended > docs/cccc/config.json
    fi
    # Otherwise keep existing config.json as-is
    ;;
  keep)
    if ! $CONFIG_EXISTS; then
      # No config to keep, use recommended
      preset_recommended > docs/cccc/config.json
    fi
    ;;
  *)
    echo "Unknown preset: $PRESET" >&2
    usage >&2
    exit 1
    ;;
esac

# ── Apply language override ──

if [[ "$LANGUAGE" != "auto" ]]; then
  python3 - "$LANGUAGE" <<'PY'
import json, sys
from pathlib import Path
p = Path('docs/cccc/config.json')
data = json.loads(p.read_text())
data['language'] = {'user_language': sys.argv[1], 'auto_detect': False}
p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
PY
fi

# ── Validate config.json ──

python3 - <<'PY'
import json
from pathlib import Path
p = Path('docs/cccc/config.json')
try:
    data = json.loads(p.read_text())
    if 'version' not in data:
        raise ValueError("Missing 'version' field")
    if 'mode' not in data:
        raise ValueError("Missing 'mode' field")
except json.JSONDecodeError as e:
    print(f"ERROR: Invalid JSON in config.json: {e}", flush=True)
    raise SystemExit(1)
except ValueError as e:
    print(f"ERROR: Invalid config.json: {e}", flush=True)
    raise SystemExit(1)
PY

# ── Generate .claude/commands/ ──

mkdir -p "$COMMANDS_DIR"
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

# ── Generate docs/cccc/ workspace via cccc-init.sh ──

"$SCRIPT_DIR/cccc-init.sh"

# ── Build summary output ──

echo ""
echo "===SETUP_RESULT==="
echo ""

echo "GENERATED:"
if ! $CONFIG_EXISTS || [[ "$PRESET" != "import" && "$PRESET" != "keep" ]]; then
  echo "- docs/cccc/config.json"
fi
if [[ -f docs/cccc/state.json ]]; then
  echo "- docs/cccc/state.json"
fi
if [[ -f docs/cccc/doc-index.json ]]; then
  echo "- docs/cccc/doc-index.json"
fi
for f in project-brief project-map current-state architecture test-strategy roadmap milestone-backlog decision-log risk-register open-questions context-bundle README; do
  target="docs/cccc/${f}.md"
  if [[ -f "$target" ]]; then
    echo "- docs/cccc/${f}.md"
  fi
done
for c in ${created_commands[@]+"${created_commands[@]}"}; do
  echo "- $c"
done

echo ""
echo "PRESERVED:"
if $CONFIG_EXISTS && [[ "$PRESET" == "import" || "$PRESET" == "keep" ]]; then
  echo "- docs/cccc/config.json (kept existing)"
fi
if [[ ${#skipped_commands[@]} -gt 0 ]]; then
  for c in ${skipped_commands[@]+"${skipped_commands[@]}"}; do
    echo "- $c (already existed)"
  done
fi
# Check for existing markdown files that were not overwritten
for f in project-brief project-map current-state architecture test-strategy roadmap milestone-backlog decision-log risk-register open-questions context-bundle README; do
  target="docs/cccc/${f}.md"
  template="$TEMPLATE_DIR/${f}.template.md"
  if [[ -f "$target" ]] && [[ -f "$template" ]]; then
    if ! diff -q "$target" "$template" >/dev/null 2>&1; then
      echo "- docs/cccc/${f}.md (modified, not overwritten)"
    fi
  fi
done

echo ""
echo "NOT_ENABLED:"
echo "- Stop-hook auto-continuation not enabled"
echo "- .claude/hooks not generated"
echo "- .claude/settings.json not modified"

echo ""
echo "TIP:"
echo "- If you manually edit docs/cccc documents, run /cccc sync-docs to sync changes."

echo ""
echo "CONFIG_SUMMARY:"
CONFIG_MODE="$(python3 -c "import json; print(json.loads(open('docs/cccc/config.json').read()).get('mode','unknown'))")"
CONFIG_LANG="$(python3 -c "import json; print(json.loads(open('docs/cccc/config.json').read()).get('language',{}).get('user_language','auto'))")"
CONFIG_DIFF="$(python3 -c "import json; print(json.loads(open('docs/cccc/config.json').read()).get('milestones',{}).get('max_diff_lines_per_milestone',1200))")"
CONFIG_FILES="$(python3 -c "import json; print(json.loads(open('docs/cccc/config.json').read()).get('milestones',{}).get('max_changed_files_per_milestone',20))")"
CONFIG_REVIEW="$(python3 -c "import json; print(json.loads(open('docs/cccc/config.json').read()).get('review',{}).get('max_review_rounds_per_milestone',3))")"
echo "mode=$CONFIG_MODE"
echo "language=$CONFIG_LANG"
echo "max_review_rounds=$CONFIG_REVIEW"
echo "max_diff_lines=$CONFIG_DIFF"
echo "max_changed_files=$CONFIG_FILES"

CODEX_POLICY="$(python3 -c "import json; print(json.loads(open('docs/cccc/config.json').read()).get('codex',{}).get('unavailable_policy','strict_pause'))")"
echo "codex_unavailable_policy=$CODEX_POLICY"
BYPASS_ENABLED="$(python3 -c "import json; print(json.loads(open('docs/cccc/config.json').read()).get('codex',{}).get('bypass',{}).get('enabled',False))")"
echo "codex_bypass_enabled=$BYPASS_ENABLED"

echo ""
echo "CODEX_POLICY_SUMMARY:"
echo "  Codex required: true"
if [[ "$CODEX_POLICY" == "strict_pause" ]]; then
  echo "  Unavailable policy: strict pause (bypass disabled)"
elif [[ "$CODEX_POLICY" == "ask_or_bypass_once" ]]; then
  echo "  Unavailable policy: ask or bypass once (Claude adversarial review)"
  echo "  Bypass scope: current gate only"
  echo "  High/critical risk: bypass prohibited"
  echo "  Lower assurance: yes"
elif [[ "$CODEX_POLICY" == "auto_bypass_low_medium" ]]; then
  echo "  Unavailable policy: auto bypass for low/medium risk"
  echo "  High/critical risk: bypass prohibited"
elif [[ "$CODEX_POLICY" == "always_ask" ]]; then
  echo "  Unavailable policy: always ask user"
else
  echo "  Unavailable policy: $CODEX_POLICY"
fi

REVIEW_POLICY_MODE="$(python3 -c "
import json
try:
    data = json.loads(open('docs/cccc/config.json').read())
    print(data.get('codex_review_policy', {}).get('mode', 'unknown'))
except Exception:
    print('unknown')
" 2>/dev/null || echo 'unknown')"
echo ""
echo "CODEX_REVIEW_POLICY:"
echo "  Review policy mode: $REVIEW_POLICY_MODE"
if [[ "$REVIEW_POLICY_MODE" == "balanced" ]]; then
  echo "  Low risk: Codex every 3 milestones"
  echo "  Medium risk: Codex every 2 milestones"
  echo "  High risk: Codex every milestone"
  echo "  Critical: Codex every milestone"
  echo "  Plan review: always Codex"
  echo "  Final review: always Codex"
  echo "  Batched review: enabled (max 3 per batch)"
  echo "  Budget: max 5 Codex calls per run"
  echo "  Checkpoint: suggest git commit after Codex pass"
  echo "  Cache: reuse matching fingerprints"
fi

echo ""
echo "===END_SETUP_RESULT==="

# ── Write runtime log ──

cat > docs/cccc/runtime/last-setup.txt <<EOF2
Setup at: $NOW
Preset: $PRESET
Language: $LANGUAGE
Generated command files: $(IFS=' '; echo ${created_commands[@]+"${created_commands[*]}"} || echo "none")
Preserved existing command files: $(IFS=' '; echo ${skipped_commands[@]+"${skipped_commands[*]}"} || echo "none")
Workspace: docs/cccc
Hooks enabled: no
EOF2
