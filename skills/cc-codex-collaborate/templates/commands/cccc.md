<!-- generated-by: cc-codex-collaborate -->
<!-- generated-file: true -->
<!-- template-version: 0.1.15 -->
<!-- alias-for: cc-codex-collaborate -->

---
description: "Alias for /cc-codex-collaborate. Coordinate Claude Code and Codex in a milestone-based collaboration loop."
argument-hint: "[task description | setup | update | force-update | resume | reset | doctor | rebuild-context | gates | repair | trace | dev-smoke | codex-check | sync-docs | diff-docs | replan | status | loop-status | loop-start | loop-stop]"
---

This is a short alias for `/cc-codex-collaborate`. Follow the instructions in `.claude/skills/cc-codex-collaborate/SKILL.md` exactly.

## Subcommand routing

Parse the first argument:

- **`setup`** — Run the interactive setup wizard. Do NOT start any task. Follow the "First-run setup" and "Setup wizard flow" sections in SKILL.md.
- **`update`** — Run safe workspace migration after upgrading skill. Sync config/state fields, commands, and enabled hooks. Does NOT overwrite user planning/review history. Does NOT enable hooks if not already enabled.
- **`force-update`** — Force sync regardless of version number. Run `.claude/skills/cc-codex-collaborate/scripts/cccc-update.sh --force` and summarize the report. Does NOT overwrite user planning/review history.
- **`resume`** — Resume a paused workflow. Follow the "Resume command" section in SKILL.md. Run `cccc-resume.sh`, ask the user questions if needed, update state, and continue the state machine. Does NOT bypass Codex gates, safety pauses, or secret requirements.
- **`reset`** or **`reset state`** — Reset state machine runtime state. Run `.claude/skills/cc-codex-collaborate/scripts/cccc-reset.sh` and summarize. Rehydrates current milestone from planning docs, reviews, and git history. Does NOT delete planning docs, reviews, or logs.
- **`doctor`** — Run diagnostics. Run `python3 .claude/skills/cc-codex-collaborate/scripts/cccc-doctor.py` and present the PASS/WARN/FAIL results. Does NOT modify files.
- **`rebuild-context`** — Rebuild context-bundle.md. Run `.claude/skills/cc-codex-collaborate/scripts/cccc-build-context.sh` and report what was included/skipped. Does NOT modify milestone status or run Codex.
- **`gates`** — Show current Codex gate and state machine gate status. Run `python3 .claude/skills/cc-codex-collaborate/scripts/cccc-gates.py` and present the results. Does NOT modify files.
- **`repair`** — Auto-fix safe inconsistencies. Run `.claude/skills/cc-codex-collaborate/scripts/cccc-repair.sh` and summarize fixes. Does NOT bypass Codex gates, safety pauses, NEEDS_SECRET, SENSITIVE_OPERATION, or UNSAFE. Backs up before modifying.
- **`trace`** — Show recent state machine events. Run `python3 .claude/skills/cc-codex-collaborate/scripts/cccc-trace.py` and present the timeline. Does NOT modify files.
- **`dev-smoke`** — Developer self-test. Run `.claude/skills/cc-codex-collaborate/scripts/cccc-dev-smoke.sh` and present PASS/FAIL results. Does NOT modify user files.
- **`codex-check`** — Check Codex CLI availability. Run `.claude/skills/cc-codex-collaborate/scripts/cccc-codex-check.sh` and report.
- **`sync-docs`** — Detect and sync manual docs/cccc document changes. Run `python3 .claude/skills/cc-codex-collaborate/scripts/cccc-sync-docs.py` and present changes. If `SYNC_AWAITING_DECISION=true`, ask the user with brainstorm-style options (A-F). Does NOT silently overwrite user documents or skip Codex gates.
- **`diff-docs`** — Check for document changes without modifying state. Run `python3 .claude/skills/cc-codex-collaborate/scripts/cccc-diff-docs.py` and present results. Read-only.
- **`replan`** — Re-read project and docs, update planning, run Codex adversarial plan review. Run `.claude/skills/cc-codex-collaborate/scripts/cccc-replan.sh` then follow the `===REPLAN_REQUIRED===` instructions. Does NOT start implementation until Codex plan review passes.
- **`status`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-status.sh` and summarize.
- **`loop-status`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-loop-status.sh` and summarize.
- **`loop-start`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-loop-start.sh`. **You MUST act on the CCCC_WORKFLOW_ACTION marker immediately. See below.**
- **`loop-stop`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-loop-stop.sh` and summarize.
- **Any other text** — Treat as the user's coding task. Start the full collaboration loop.

## loop-start behavior — CRITICAL

After running cccc-loop-start.sh, check the CCCC_WORKFLOW_ACTION marker in the output:

- **`continue_now`** — **Do NOT summarize and stop.** You MUST immediately read `docs/cccc/config.json` and `docs/cccc/state.json`, determine the current milestone and status, and execute the next state-machine step right now in this same turn. The stop hook will keep you running, but you must start executing immediately. Your very next action must be reading state and executing state machine steps, not writing a summary.
- **`needs_resume`** — The workflow is paused. Execute `/cccc resume` or tell the user to run it.
- **`needs_task`** — No active workflow. Tell the user to run `/cccc "task description"`.
- **`needs_replan`** — Planning invalidated by doc changes. Tell the user to run `/cccc replan`.
- **`needs_sync_docs`** — Documents changed since last sync. Tell the user to run `/cccc sync-docs`.
- **`done`** — The workflow is already completed. Tell the user to start a new task.

**For `continue_now`: You are NOT done after running the loop-start script. The script output tells you to continue. Continuing means executing state machine steps NOW, not waiting for the stop hook.**

## Before starting a task

If `docs/cccc/config.json` is missing, prompt the user to run `/cccc setup` first. Do not proceed without a valid config.

## Key rules

- Read all thresholds and configuration from `docs/cccc/config.json`.
- Read runtime state from `docs/cccc/state.json`.
- Detect and use the user's primary language throughout.
- Never bypass hard pause conditions (secrets, wallet keys, production, real money, destructive ops, threshold failures).
- Follow the state machine, role separation, and brainstorming rules defined in SKILL.md.
