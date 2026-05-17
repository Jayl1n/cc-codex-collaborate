#!/usr/bin/env bash
# CCCC Stop Hook — prevents Claude Code from stopping when loop is active.
# Design inspired by ralph-loop: minimize external deps on the critical path.
set -euo pipefail

INPUT="$(cat)"
ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

LOOP_STATE="$ROOT/.claude/cccc-loop.local"
CONFIG="$ROOT/docs/cccc/config.json"
STATE="$ROOT/docs/cccc/state.json"
LOG_DIR="$ROOT/docs/cccc/logs"

# ── Guard 1: Loop state file must exist ──
# This file is created by loop-start and removed by loop-stop.
# If it doesn't exist, there's no active loop — allow stop.
if [[ ! -f "$LOOP_STATE" ]]; then
  exit 0
fi

# ── Guard 2: Session isolation ──
# Prevents blocking in sessions that didn't start the loop.
LOOP_SESSION="$(grep '^session_id:' "$LOOP_STATE" 2>/dev/null | sed 's/session_id: *//' || true)"
if [[ -n "$LOOP_SESSION" ]]; then
  HOOK_SESSION="$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || true)"
  if [[ "$LOOP_SESSION" != "$HOOK_SESSION" ]]; then
    exit 0
  fi
fi

# ── Guard 3: Continuation budget from local file (no JSON parsing) ──
CONTINUATIONS="$(grep '^continuations:' "$LOOP_STATE" 2>/dev/null | sed 's/continuations: *//' || echo '0')"
MAX_CONTINUATIONS="$(grep '^max_continuations:' "$LOOP_STATE" 2>/dev/null | sed 's/max_continuations: *//' || echo '10')"

if ! [[ "$CONTINUATIONS" =~ ^[0-9]+$ ]]; then CONTINUATIONS=0; fi
if ! [[ "$MAX_CONTINUATIONS" =~ ^[0-9]+$ ]]; then MAX_CONTINUATIONS=10; fi

if [[ "$CONTINUATIONS" -ge "$MAX_CONTINUATIONS" ]]; then
  rm -f "$LOOP_STATE"
  exit 0
fi

# ── Guard 4: Read config + state in a single python3 call ──
# This replaces 6 separate jq calls with one robust call.
# Output format: mode|loop_enabled|status|pause_reason|milestone
READ_RESULT="$(python3 - "$CONFIG" "$STATE" <<'PY' 2>/dev/null || echo "supervised-auto|false|UNKNOWN||"
import json, sys
def read_json(path):
    try:
        return json.loads(open(path).read())
    except Exception:
        return {}
cfg = read_json(sys.argv[1])
st = read_json(sys.argv[2])
mode = cfg.get("mode", "supervised-auto")
loop_enabled = str(cfg.get("automation", {}).get("stop_hook_loop_enabled", False)).lower()
status = st.get("status", "UNKNOWN")
pause_reason = st.get("pause_reason") or ""
milestone = st.get("current_milestone_id") or ""
print(f"{mode}|{loop_enabled}|{status}|{pause_reason}|{milestone}")
PY
)"

IFS='|' read -r MODE LOOP_ENABLED STATUS PAUSE_REASON CURRENT_MILESTONE <<< "$READ_RESULT"

# ── Guard 5: Loop must be enabled and mode must be full-auto-safe ──
if [[ "$LOOP_ENABLED" != "true" ]]; then
  exit 0
fi
if [[ "$MODE" != "full-auto-safe" ]]; then
  exit 0
fi

# ── Guard 6: Terminal/pause statuses ──
case "$STATUS" in
  DONE|COMPLETED|FAILED|PAUSED_FOR_HUMAN|NEEDS_HUMAN|NEEDS_SECRET|SENSITIVE_OPERATION|UNSAFE|PAUSED_FOR_SYSTEM|PAUSED_FOR_CODEX)
    exit 0
    ;;
esac

if [[ -n "$PAUSE_REASON" && "$PAUSE_REASON" != "null" ]]; then
  exit 0
fi

# ── Guard 7: Prevent empty spin ──
if [[ "$STATUS" == "SETUP_COMPLETE" || "$STATUS" == "ERROR" ]]; then
  if [[ -z "$CURRENT_MILESTONE" || "$CURRENT_MILESTONE" == "null" ]]; then
    if [[ ! -f "$ROOT/docs/cccc/roadmap.md" && ! -f "$ROOT/docs/cccc/milestone-backlog.md" ]]; then
      exit 0
    fi
  fi
fi

# ── Increment continuation counter (atomic via temp file) ──
NEXT_CONTINUATIONS=$((CONTINUATIONS + 1))
TEMP_FILE="${LOOP_STATE}.tmp.$$"
sed "s/^continuations:.*/continuations: $NEXT_CONTINUATIONS/" "$LOOP_STATE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$LOOP_STATE"

# Also update state.json for compatibility (best-effort)
python3 - "$STATE" "$NEXT_CONTINUATIONS" <<'PY' >/dev/null 2>&1 || true
import json, sys
try:
    p = sys.argv[1]
    d = json.loads(open(p).read())
    d["stop_hook_continuations"] = int(sys.argv[2])
    open(p, "w").write(json.dumps(d, ensure_ascii=False, indent=2) + "\n")
except Exception:
    pass
PY

# ── Log for debugging (best-effort) ──
mkdir -p "$LOG_DIR" 2>/dev/null || true
STAMP="$(date -u +"%Y%m%dT%H%M%SZ" 2>/dev/null || echo "unknown")"
echo "$INPUT" > "$LOG_DIR/stop-$STAMP.json" 2>/dev/null || true

# ── Block the stop ──
# Prefer jq for JSON output; fall back to python3 if jq unavailable.
REASON="Continue the cc-codex-collaborate state machine. The stop-hook only prevents premature stopping. Execute multiple state-machine steps per continuation. Current status: $STATUS. Current milestone: ${CURRENT_MILESTONE:-none}. Continuation budget: $NEXT_CONTINUATIONS/$MAX_CONTINUATIONS. Continue until reaching: DONE, COMPLETED, FAILED, PAUSED_FOR_HUMAN, NEEDS_HUMAN, NEEDS_SECRET, SENSITIVE_OPERATION, UNSAFE, PAUSED_FOR_SYSTEM, PAUSED_FOR_CODEX, or budget exhausted. Never bypass human/secret/production/wallet/money/destructive pause conditions."

if command -v jq >/dev/null 2>&1; then
  jq -n --arg reason "$REASON" '{"decision":"block","reason":$reason}'
else
  python3 -c "import json,sys; print(json.dumps({'decision':'block','reason':sys.argv[1]}))" "$REASON"
fi

exit 0
