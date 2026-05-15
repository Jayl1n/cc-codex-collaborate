# Hooks & Loop Automation

This document defines the stop hook automation rule and loop control commands.

## Loop control commands

After setup, this package provides three explicit slash-command wrappers for loop automation:

- `/cc-codex-collaborate-loop-status`: inspect `docs/cccc/config.json`, `docs/cccc/state.json`, hook files, and `.claude/settings.json` hook registrations.
- `/cc-codex-collaborate-loop-start`: enable full-auto-safe loop continuation by installing cccc hook scripts into `.claude/hooks`, registering them in `.claude/settings.json`, and updating `config.json` automation settings. If an active workflow exists, immediately continue the state machine. If no workflow exists, prompt the user to start a task. If the workflow is paused, suggest `/cc-codex-collaborate resume`.
- `/cc-codex-collaborate-loop-stop`: disable loop automation by removing only cccc hook registrations from `.claude/settings.json` and updating `config.json` to disable the loop.

Do not enable Stop-hook automation implicitly. The user must explicitly run `/cc-codex-collaborate-loop-start`.

`docs/cccc` is a runtime workspace. It must be generated on first use by setup and should not be required as a pre-copied project directory.

## Stop hook automation rule

The optional Stop hook (`cccc-stop.sh`) reads configuration from `docs/cccc/config.json` and runtime state from `docs/cccc/state.json`.

It may block the stop (returning `decision: "block"`) only when all of these conditions are met:

- `docs/cccc/config.json` exists and `automation.stop_hook_loop_enabled` is `true`
- `docs/cccc/config.json` `mode` is `full-auto-safe`
- `docs/cccc/state.json` exists
- `status` is not a terminal or paused state (DONE, COMPLETED, FAILED, PAUSED_FOR_HUMAN, NEEDS_HUMAN, NEEDS_SECRET, SENSITIVE_OPERATION, UNSAFE, PAUSED_FOR_SYSTEM, PAUSED_FOR_CODEX)
- `pause_reason` is empty
- `stop_hook_active` in the hook input is not `true` (prevents infinite recursion)
- continuation count is below `automation.max_stop_hook_continuations` (from config.json)
- `status` is not `SETUP_COMPLETE` with no milestone and no backlog (prevents empty-spin)

The stop hook allows `READY_TO_CONTINUE` status to proceed — this is the status set after a successful resume.

When the hook blocks, it outputs a `reason` that instructs Claude to continue the state machine loop internally — not just take one small step and stop again. The skill's internal state machine must drive the actual loop; the hook merely prevents Claude Code from stopping prematurely.

The Stop hook must never continue past hard pause conditions (see [[safety-policy]]).
