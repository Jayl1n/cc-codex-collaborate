<!-- generated-by: cc-codex-collaborate -->
<!-- generated-file: true -->
<!-- template-version: 0.1.8 -->

---
description: Coordinate Claude Code and Codex in a milestone-based collaboration loop. Use "setup" for first-time configuration, "update" for safe migration.
argument-hint: "[task description | setup | update | status | loop-status | loop-start | loop-stop]"
---

You are activating the cc-codex-collaborate skill. Follow the instructions in `.claude/skills/cc-codex-collaborate/SKILL.md` exactly.

## Subcommand routing

Parse the first argument:

- **`setup`** — Run the interactive setup wizard. Do NOT start any task. Follow the "First-run setup" and "Setup wizard flow" sections in SKILL.md.
- **`update`** — Run safe workspace migration after upgrading skill. Sync config/state fields, commands, and enabled hooks. Does NOT overwrite user planning/review history. Does NOT enable hooks if not already enabled.
- **`status`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-status.sh` and summarize.
- **`loop-status`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-loop-status.sh` and summarize.
- **`loop-start`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-loop-start.sh` and summarize.
- **`loop-stop`** — Run `.claude/skills/cc-codex-collaborate/scripts/cccc-loop-stop.sh` and summarize.
- **Any other text** — Treat as the user's coding task. Start the full collaboration loop.

## Before starting a task

If `docs/cccc/config.json` is missing, prompt the user to run `/cc-codex-collaborate setup` first. Do not proceed without a valid config.

## Key rules

- Read all thresholds and configuration from `docs/cccc/config.json`.
- Read runtime state from `docs/cccc/state.json`.
- Detect and use the user's primary language throughout.
- Never bypass hard pause conditions (secrets, wallet keys, production, real money, destructive ops, threshold failures).
- Follow the state machine, role separation, and brainstorming rules defined in SKILL.md.
