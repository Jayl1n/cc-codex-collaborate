#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"
ROOT="$(cccc_repo_root)"
cd "$ROOT"
SKILL_DIR="$(cccc_skill_dir)"
SETTINGS=".claude/settings.json"
CONFIG="docs/cccc/config.json"
STATE="docs/cccc/state.json"
BACKUP=".claude/settings.json.cccc-backup-$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p .claude/hooks docs/cccc/runtime
cp "$SKILL_DIR/hooks/cccc-sensitive-op-guard.sh" .claude/hooks/cccc-sensitive-op-guard.sh
cp "$SKILL_DIR/hooks/cccc-stop.sh" .claude/hooks/cccc-stop.sh
cp "$SKILL_DIR/hooks/cccc-stop-failure.sh" .claude/hooks/cccc-stop-failure.sh
chmod +x .claude/hooks/cccc-*.sh

# Ensure workspace exists
if [[ ! -f docs/cccc/state.json ]]; then
  "$SCRIPT_DIR/cccc-init.sh"
fi

# Backup and update settings.json
if [[ -f "$SETTINGS" ]]; then
  cp "$SETTINGS" "$BACKUP"
else
  mkdir -p .claude
  echo '{}' > "$SETTINGS"
fi

python3 - <<'PY'
import json
from pathlib import Path
settings_path = Path('.claude/settings.json')
try:
    settings = json.loads(settings_path.read_text())
except Exception:
    settings = {}
settings.setdefault('hooks', {})

def add_hook(event, matcher, command):
    hooks = settings['hooks'].setdefault(event, [])
    for group in hooks:
        if group.get('matcher', '') == matcher:
            entries = group.setdefault('hooks', [])
            if not any(h.get('type') == 'command' and h.get('command') == command for h in entries):
                entries.append({'type': 'command', 'command': command})
            return
    hooks.append({'matcher': matcher, 'hooks': [{'type': 'command', 'command': command}]})

add_hook('PreToolUse', 'Bash|Edit|Write|MultiEdit', '${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-sensitive-op-guard.sh')
add_hook('Stop', '', '${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop.sh')
add_hook('StopFailure', '', '${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop-failure.sh')
settings_path.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + '\n')
PY

# Update config.json: enable loop
if [[ -f "$CONFIG" ]]; then
  python3 - <<'PY'
import json
from pathlib import Path
p = Path('docs/cccc/config.json')
data = json.loads(p.read_text())
data.setdefault('automation', {})['stop_hook_loop_enabled'] = True
data['mode'] = 'full-auto-safe'
p.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
PY
fi

# Update state.json
python3 - <<'PY'
import json
from pathlib import Path
state_path = Path('docs/cccc/state.json')
try:
    state = json.loads(state_path.read_text())
except Exception:
    state = {}
state['enabled'] = True
state['mode'] = 'full-auto-safe'
state['pause_reason'] = None
state['stop_hook_continuations'] = 0
state_path.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
PY

echo "Enabled cc-codex-collaborate loop automation."
echo "Installed hooks into .claude/hooks and registered them in .claude/settings.json."
echo "Updated docs/cccc/config.json: automation.stop_hook_loop_enabled = true"
echo "Updated docs/cccc/state.json: mode = full-auto-safe"
if [[ -f "$BACKUP" ]]; then echo "Backup: $BACKUP"; fi
