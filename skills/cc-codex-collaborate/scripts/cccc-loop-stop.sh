#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/cccc-common.sh"
ROOT="$(cccc_repo_root)"
cd "$ROOT"
SETTINGS=".claude/settings.json"
STATE="docs/cccc/state.json"
BACKUP=".claude/settings.json.cccc-backup-$(date -u +%Y%m%dT%H%M%SZ)"

if [[ -f "$SETTINGS" ]]; then
  cp "$SETTINGS" "$BACKUP"
  python3 - <<'PY'
import json
from pathlib import Path
settings_path = Path('.claude/settings.json')
try:
    settings = json.loads(settings_path.read_text())
except Exception:
    settings = {}
commands = {
    '${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-sensitive-op-guard.sh',
    '${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop.sh',
    '${CLAUDE_PROJECT_DIR}/.claude/hooks/cccc-stop-failure.sh',
}
hooks = settings.get('hooks', {})
for event in list(hooks.keys()):
    groups = []
    for group in hooks.get(event, []):
        entries = [h for h in group.get('hooks', []) if not (h.get('type') == 'command' and h.get('command') in commands)]
        if entries:
            group['hooks'] = entries
            groups.append(group)
    if groups:
        hooks[event] = groups
    else:
        hooks.pop(event, None)
if hooks:
    settings['hooks'] = hooks
else:
    settings.pop('hooks', None)
settings_path.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + '\n')
PY
fi

if [[ -f "$STATE" ]]; then
  python3 - <<'PY'
import json
from pathlib import Path
p = Path('docs/cccc/state.json')
try:
    state = json.loads(p.read_text())
except Exception:
    state = {}
state['mode'] = 'supervised-auto'
state['enabled'] = False
state['pause_reason'] = 'Loop stopped by user.'
state['stop_hook_continuations'] = 0
p.write_text(json.dumps(state, ensure_ascii=False, indent=2) + '\n')
PY
fi

echo "Disabled cc-codex-collaborate loop automation."
if [[ -f "$BACKUP" ]]; then echo "Backup: $BACKUP"; fi
echo "Hook script files under .claude/hooks are left in place, but no longer registered."
