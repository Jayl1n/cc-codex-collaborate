<!-- generated-by: cc-codex-collaborate -->
<!-- generated-file: true -->
<!-- template-version: 0.1.11 -->

---
description: Coordinate Claude Code and Codex in a milestone-based collaboration loop. Use "setup" for first-time configuration, "update" for safe migration, "resume" to continue a paused workflow.
argument-hint: "[task description | setup | update | resume | status | loop-status | loop-start | loop-stop]"
---

You are activating the cc-codex-collaborate skill. Follow the instructions in `.claude/skills/cc-codex-collaborate/SKILL.md` exactly.

## Subcommand routing

Parse the first argument:

- **`setup`** — Run the interactive setup wizard. Do NOT start any task. Follow the "First-run setup" and "Setup wizard flow" sections in SKILL.md.
- **`update`** — Run safe workspace migration after upgrading skill. Sync config/state fields, commands, and enabled hooks. Does NOT overwrite user planning/review history. Does NOT enable hooks if not already enabled.
- **`resume`** — Resume a paused workflow. Follow the "Resume command" section in SKILL.md. Run `cccc-resume.sh`, ask the user questions if needed, update state, and continue the state machine. Does NOT bypass Codex gates, safety pauses, or secret requirements.
- **`status`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-status.sh` and summarize.
- **`loop-status`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-loop-status.sh` and summarize.
- **`loop-start`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-loop-start.sh`. **You MUST act on the CCCC_WORKFLOW_ACTION marker immediately. See below.**
- **`loop-stop`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-loop-stop.sh` and summarize.
- **Any other text** — Treat as the user's coding task. Start the full collaboration loop.

## loop-start behavior — CRITICAL

After running cccc-loop-start.sh, check the CCCC_WORKFLOW_ACTION marker in the output:

- **`continue_now`** — **Do NOT summarize and stop.** You MUST immediately read `docs/cccc/config.json` and `docs/cccc/state.json`, determine the current milestone and status, and execute the next state-machine step right now in this same turn. The stop hook will keep you running, but you must start executing immediately. Your very next action must be reading state and executing state machine steps, not writing a summary.
- **`needs_resume`** — The workflow is paused. Execute `/cc-codex-collaborate resume` or tell the user to run it.
- **`needs_task`** — No active workflow. Tell the user to run `/cc-codex-collaborate "task description"`.
- **`done`** — The workflow is already completed. Tell the user to start a new task.

**For `continue_now`: You are NOT done after running the loop-start script. The script output tells you to continue. Continuing means executing state machine steps NOW, not waiting for the stop hook.**

## Before starting a task

If `docs/cccc/config.json` is missing, prompt the user to run `/cc-codex-collaborate setup` first. Do not proceed without a valid config.

## Key rules

- Read all thresholds and configuration from `docs/cccc/config.json`.
- Read runtime state from `docs/cccc/state.json`.
- Detect and use the user's primary language throughout.
- Never bypass hard pause conditions (secrets, wallet keys, production, real money, destructive ops, threshold failures).
- Follow the state machine, role separation, and brainstorming rules defined in SKILL.md.
