#!/usr/bin/env bash
# Safe workspace migration after skill upgrade.
# Does NOT download new skill. Assumes user already installed new version.
# Does NOT enable hooks if not already enabled.
# Does NOT overwrite user planning/review history.
#
# Usage:
#   cccc-update.sh           # Normal update (skips if version unchanged)
#   cccc-update.sh --force   # Force update regardless of version
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"

FORCE=false
if [[ "${1:-}" == "--force" ]]; then
  FORCE=true
  BACKUP_LABEL="force-update"
else
  BACKUP_LABEL="update"
fi

ROOT="$(cccc_repo_root)"
cd "$ROOT"

SKILL_DIR="$(cccc_skill_dir)"
TEMPLATE_DIR="$SKILL_DIR/templates"
COMMANDS_DIR="$ROOT/.claude/commands"
HOOKS_DIR="$ROOT/.claude/hooks"
SETTINGS_FILE="$ROOT/.claude/settings.json"

# Read skill current version
SKILL_VERSION="$(cat "$SKILL_DIR/VERSION" 2>/dev/null || echo "unknown")"
TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
BACKUP_DIR="docs/cccc/backups/$BACKUP_LABEL-$TIMESTAMP"

# ── Check if workspace exists ──

if [[ ! -d "docs/cccc" ]]; then
  echo "ERROR: docs/cccc does not exist." >&2
  echo "Run /cc-codex-collaborate setup first." >&2
  exit 1
fi

if [[ ! -f "docs/cccc/config.json" ]]; then
  echo "ERROR: docs/cccc/config.json missing." >&2
  echo "Run /cc-codex-collaborate setup first." >&2
  exit 1
fi

# ── Create backup directory ──

mkdir -p "$BACKUP_DIR"

# ── Backup existing files ──

backup_files=()

for f in docs/cccc/config.json docs/cccc/state.json docs/cccc/doc-index.json docs/cccc/roadmap.md docs/cccc/milestone-backlog.md docs/cccc/decision-log.md docs/cccc/risk-register.md; do
  if [[ -f "$f" ]]; then
    cp "$f" "$BACKUP_DIR/$(basename "$f")"
    backup_files+=("$f")
  fi
done

if [[ -f "$SETTINGS_FILE" ]]; then
  cp "$SETTINGS_FILE" "$BACKUP_DIR/settings.json"
  backup_files+=("$SETTINGS_FILE")
fi

if [[ -d "$COMMANDS_DIR" ]]; then
  mkdir -p "$BACKUP_DIR/commands"
  cp -r "$COMMANDS_DIR"/* "$BACKUP_DIR/commands/" 2>/dev/null || true
  backup_files+=("$COMMANDS_DIR")
fi

if [[ -d "$HOOKS_DIR" ]]; then
  mkdir -p "$BACKUP_DIR/hooks"
  cp -r "$HOOKS_DIR"/* "$BACKUP_DIR/hooks/" 2>/dev/null || true
  backup_files+=("$HOOKS_DIR")
fi

# ── Read project current version ──

PROJECT_VERSION="$(python3 -c "
import json
try:
    data = json.loads(open('docs/cccc/config.json').read())
    skill = data.get('skill', {})
    print(skill.get('installed_version', data.get('version', 'unknown')))
except Exception:
    print('unknown')
" 2>/dev/null || echo 'unknown')"

echo "Skill version: $SKILL_VERSION"
echo "Project version: $PROJECT_VERSION"

# ── Version check (skip if unchanged, unless --force) ──

if ! $FORCE && [[ "$SKILL_VERSION" == "$PROJECT_VERSION" ]]; then
  echo ""
  echo "Version unchanged ($SKILL_VERSION). Nothing to update."
  echo "Use --force or /cc-codex-collaborate force-update to force sync."
  # Clean up empty backup dir
  rmdir "$BACKUP_DIR" 2>/dev/null || true
  exit 0
fi

# ── Migrate config.json ──

echo ""
echo "Migrating config.json..."

python3 "$SCRIPT_DIR/cccc-migrate-config.py" \
  --config docs/cccc/config.json \
  --template "$TEMPLATE_DIR/cccc/config.template.json" \
  --version "$SKILL_VERSION" \
  --backup-dir "$BACKUP_DIR"

# ── Migrate state.json ──

if [[ -f "docs/cccc/state.json" ]]; then
  echo ""
  echo "Migrating state.json..."
  python3 "$SCRIPT_DIR/cccc-migrate-state.py" \
    --state docs/cccc/state.json \
    --template "$TEMPLATE_DIR/cccc/state.template.json" \
    --from-version "$PROJECT_VERSION" \
    --to-version "$SKILL_VERSION" \
    --backup-dir "$BACKUP_DIR"
fi

# ── Migrate doc-index.json ──

echo ""
echo "Checking doc-index.json..."

if [[ ! -f "docs/cccc/doc-index.json" ]]; then
  if [[ -f "$TEMPLATE_DIR/cccc/doc-index.template.json" ]]; then
    cp "$TEMPLATE_DIR/cccc/doc-index.template.json" docs/cccc/doc-index.json
    echo "Created docs/cccc/doc-index.json from template."
  else
    echo '{"version":1,"last_synced_at":null,"last_diff_at":null,"documents":{},"last_change_summary":null}' > docs/cccc/doc-index.json
    echo "Created docs/cccc/doc-index.json with defaults."
  fi
else
  echo "doc-index.json already exists. Preserving."
fi

# ── Migrate bypass fields ──

echo ""
echo "Checking bypass fields..."

mkdir -p docs/cccc/reviews/bypass

python3 - <<'PYB'
import json
from pathlib import Path

# Ensure config has bypass fields
cfg_path = Path('docs/cccc/config.json')
cfg = json.loads(cfg_path.read_text())
codex = cfg.setdefault('codex', {})

if 'unavailable_policy' not in codex:
    codex['unavailable_policy'] = 'ask_or_bypass_once'
    print('Added codex.unavailable_policy')

if 'bypass' not in codex:
    codex['bypass'] = {
        "enabled": True, "mode": "once_per_gate", "require_human_confirmation": True,
        "allowed_reasons": ["quota_exhausted","codex_cli_unavailable","codex_auth_unavailable",
                            "codex_api_error","user_explicit_override"],
        "default_scope": "current_gate_only", "max_consecutive_bypassed_gates": 1,
        "record_in_decision_log": True, "mark_outputs_as_lower_assurance": True,
        "block_bypass_for_critical_risk": True, "block_bypass_for_high_risk_by_default": True,
        "allow_for_low_risk": True, "allow_for_medium_risk": True,
        "allow_for_high_risk": False, "allow_for_critical_risk": False,
        "require_later_codex_recheck": True
    }
    print('Added codex.bypass config')

cfg_path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + '\n')

# Ensure state has bypass fields
st_path = Path('docs/cccc/state.json')
if st_path.exists():
    st = json.loads(st_path.read_text())
    bypass_fields = {
        'codex_bypass_enabled_for_current_gate': False,
        'last_codex_bypass_at': None,
        'last_codex_bypass_reason': None,
        'last_codex_bypass_scope': None,
        'last_codex_bypass_review_file': None,
        'consecutive_bypassed_gates': 0,
        'pending_codex_recheck': [],
        'lower_assurance_mode': False,
    }
    added = []
    for k, v in bypass_fields.items():
        if k not in st:
            st[k] = v
            added.append(k)
    if added:
        st_path.write_text(json.dumps(st, ensure_ascii=False, indent=2) + '\n')
        print(f'Added state fields: {", ".join(added)}')
    else:
        print('State bypass fields already present.')
else:
    print('state.json not found, skipping state migration.')
PYB

# ── Migrate codex_review_policy ──

echo ""
echo "Checking codex_review_policy..."

python3 - <<'POL'
import json
from pathlib import Path

cfg_path = Path('docs/cccc/config.json')
cfg = json.loads(cfg_path.read_text())

if 'codex_review_policy' not in cfg:
    cfg['codex_review_policy'] = {
        "mode": "balanced",
        "review_frequency": {
            "low_risk_every_n_milestones": 3,
            "medium_risk_every_n_milestones": 2,
            "high_risk_every_n_milestones": 1,
            "critical_risk_every_n_milestones": 1
        },
        "review_triggers": {
            "always_review_plan": True,
            "always_review_final": True,
            "review_on_phase_boundary": True,
            "review_on_architecture_change": True,
            "review_on_stack_change": True,
            "review_on_security_change": True,
            "review_on_large_diff": True,
            "large_diff_lines": 800,
            "large_changed_files": 12
        },
        "budget": {
            "max_codex_calls_per_run": 5,
            "max_codex_calls_per_milestone": 1,
            "max_codex_calls_per_phase": 8,
            "warn_when_remaining_calls_lte": 1
        },
        "batching": {
            "enabled": True,
            "max_milestones_per_codex_review": 3,
            "require_codex_at_phase_boundary": True
        },
        "fallback": {
            "use_claude_adversarial_between_codex_reviews": True,
            "mark_lower_assurance_until_codex_review": True,
            "require_codex_recheck_later": True
        },
        "cache": {
            "enabled": True,
            "reuse_review_when_fingerprint_matches": True,
            "fingerprint_includes_diff": True,
            "fingerprint_includes_acceptance_criteria": True
        },
        "checkpoint": {
            "enabled": True,
            "prefer_review_since_last_codex_approved_commit": True,
            "suggest_git_commit_after_codex_pass": True,
            "auto_commit": False
        }
    }
    cfg_path.write_text(json.dumps(cfg, ensure_ascii=False, indent=2) + '\n')
    print('Added codex_review_policy config.')
else:
    print('codex_review_policy already present.')

st_path = Path('docs/cccc/state.json')
if st_path.exists():
    st = json.loads(st_path.read_text())
    new_fields = {
        'codex_budget': {
            'codex_calls_this_run': 0,
            'codex_calls_this_phase': 0,
            'codex_calls_by_milestone': {},
            'last_codex_call_at': None,
            'last_codex_call_reason': None
        },
        'codex_review_batch': {
            'pending_milestones': [],
            'last_batch_review_file': None,
            'last_batch_review_at': None
        },
        'codex_review_cache': {},
        'checkpoint': {
            'last_codex_approved_commit': None,
            'last_codex_reviewed_diff_base': None,
            'last_codex_reviewed_at': None,
            'pending_checkpoint_recommendation': False
        }
    }
    added = []
    for k, v in new_fields.items():
        if k not in st:
            st[k] = v
            added.append(k)
    if added:
        st_path.write_text(json.dumps(st, ensure_ascii=False, indent=2) + '\n')
        print(f'Added state fields: {", ".join(added)}')
    else:
        print('State budget/cache/checkpoint fields already present.')
POL

# ── Sync commands ──

echo ""
echo "Syncing commands..."

mkdir -p "$COMMANDS_DIR"
updated_commands=()
preserved_commands=()
new_commands=()

if [[ -d "$TEMPLATE_DIR/commands" ]]; then
  for src in "$TEMPLATE_DIR/commands"/*.md; do
    [[ -e "$src" ]] || continue
    name="$(basename "$src")"
    dst="$COMMANDS_DIR/$name"

    if [[ ! -f "$dst" ]]; then
      # New file, create it
      cp "$src" "$dst"
      new_commands+=("$name")
    elif head -10 "$dst" | grep -qE 'generated-by:\s*cc-codex-collaborate|generated-file:\s*true'; then
      # Generated by us, safe to update
      cp "$src" "$dst"
      updated_commands+=("$name")
    else
      # User modified, don't overwrite
      # Create .new file for reference
      cp "$src" "$dst.new"
      preserved_commands+=("$name (user-modified, created $name.new)")
    fi
  done
fi

# ── Sync hooks (only if already enabled) ──

echo ""
echo "Checking hooks status..."

LOOP_ENABLED="$(python3 -c "
import json
try:
    data = json.loads(open('docs/cccc/config.json').read())
    print(data.get('automation', {}).get('stop_hook_loop_enabled', False))
except Exception:
    print('false')
" 2>/dev/null || echo 'false')"

HOOKS_REGISTERED=false
if [[ -f "$SETTINGS_FILE" ]]; then
  if python3 -c "
import json
try:
    data = json.loads(open('.claude/settings.json').read())
    hooks = data.get('hooks', {})
    for event, groups in hooks.items():
        for group in groups:
            for h in group.get('hooks', []):
                if 'cccc' in h.get('command', '').lower():
                    print('true')
                    exit(0)
    print('false')
except Exception:
    print('false')
" | grep -q true; then
    HOOKS_REGISTERED=true
  fi
fi

synced_hooks=false
hooks_updated=()

if [[ "$LOOP_ENABLED" == "True" ]] || $HOOKS_REGISTERED; then
  echo "Hooks are enabled. Syncing hook scripts..."

  mkdir -p "$HOOKS_DIR"

  for hook in "$SKILL_DIR/hooks"/cccc-*.sh; do
    [[ -e "$hook" ]] || continue
    name="$(basename "$hook")"
    dst="$HOOKS_DIR/$name"

    if [[ -f "$dst" ]]; then
      # Backup existing
      cp "$dst" "$BACKUP_DIR/hooks/$name"
    fi

    cp "$hook" "$dst"
    chmod +x "$dst"
    hooks_updated+=("$name")
  done

  synced_hooks=true
else
  echo "Hooks not enabled. Skipping hook sync."
fi

# ── Fix settings.json hook paths if registered ──

if $HOOKS_REGISTERED && [[ -f "$SETTINGS_FILE" ]]; then
  echo ""
  echo "Verifying settings.json hook paths..."

  # Check and fix hook command paths
  python3 - "$SETTINGS_FILE" "$BACKUP_DIR" <<'PY'
import json
from pathlib import Path

p = Path('.claude/settings.json')
try:
    data = json.loads(p.read_text())
except Exception:
    data = {}

hooks = data.get('hooks', {})
fixed = False

for event, groups in hooks.items():
    for group in groups:
        for h in group.get('hooks', []):
            cmd = h.get('command', '')
            if 'cccc' in cmd.lower():
                # Fix path format
                expected = '${CLAUDE_PROJECT_DIR}/.claude/hooks/' + cmd.split('/')[-1]
                if cmd != expected:
                    h['command'] = expected
                    fixed = True

if fixed:
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    print('Fixed hook paths.')
else:
    print('Hook paths OK.')
PY
fi

# ── Migration Report ──

echo ""
echo "════════════════════════════════════════════════════════════"
if $FORCE; then
  echo "CCCC Force-Update Complete"
else
  echo "CCCC Update Complete"
fi
echo "════════════════════════════════════════════════════════════"

echo ""
echo "Versions:"
echo "  Skill version: $SKILL_VERSION"
echo "  Project version (before): $PROJECT_VERSION"
echo "  Project version (after): $SKILL_VERSION"

echo ""
echo "Commands:"
if [[ ${#new_commands[@]} -gt 0 ]]; then
  echo "  New: ${new_commands[*]}"
fi
if [[ ${#updated_commands[@]} -gt 0 ]]; then
  echo "  Updated: ${updated_commands[*]}"
fi
if [[ ${#preserved_commands[@]} -gt 0 ]]; then
  echo "  Preserved (user-modified):"
  for c in ${preserved_commands[@]+"${preserved_commands[@]}"}; do
    echo "    $c"
  done
fi

echo ""
echo "Hooks:"
if $synced_hooks; then
  echo "  Synced: ${hooks_updated[*]}"
else
  echo "  Not synced (loop not enabled)"
fi

echo ""
echo "Backup:"
echo "  $BACKUP_DIR"
for f in ${backup_files[@]+"${backup_files[@]}"}; do
  echo "    $f"
done

echo ""
echo "Next steps:"
echo "  - Review any .new files and merge if needed"
echo "  - Check /cc-codex-collaborate-loop-status for version status"
echo "  - Continue your task with /cc-codex-collaborate \"your task\""