# Setup & Configuration

This document defines the setup wizard flow, configuration presets, bootstrap model, and update command.

## First-run setup

The first user-facing action after installation should be:

```text
/cc-codex-collaborate setup
```

Setup is an **interactive configuration wizard** conducted by Claude Code (you). It does NOT start any task, does NOT enable hooks, and does NOT modify `.claude/settings.json`.

### Setup wizard flow

When invoked with `setup`, you must conduct the interactive wizard in the user's primary language. Follow this flow:

#### 1. Detect user language

Detect the user's primary language from:
1. Explicit user preference
2. The language of the current message
3. If unclear, default to the language of the most recent user message

#### 2. Opening message

Display in the user's language:

> I will initialize cc-codex-collaborate for this project. This generates `.claude/commands` and `docs/cccc`, but does not enable hooks or start any task.

#### 3. Handle existing config first

If `docs/cccc/config.json` already exists, ask the user before proceeding:

> A. Keep existing config, only fill missing files
> B. Interactively update parts of the config
> C. Backup and rebuild config
> D. Exit

If C is chosen, backup to `docs/cccc/backups/config.<timestamp>.json` before proceeding.

If A is chosen, run `cccc-setup.sh keep [language]` and skip the preset selection.

#### 4. Ask configuration mode (only if no existing config, or user chose B/C)

Present choices using `AskUserQuestion`:

> A. Quick setup: recommended defaults for most projects (recommended)
> B. Strict setup: stronger review, smaller milestones, easier to pause
> C. Custom setup: configure thresholds and behavior step by step
> D. Import config: from existing `docs/cccc/config.json` or template
> E. Exit setup

Default: A.

#### 5. Preset details

**A. Quick / recommended preset:**
- mode: supervised-auto
- max_plan_review_rounds: 3
- max_milestones_per_run: 5, max_diff_lines: 1200, max_changed_files: 20
- max_review_rounds_per_milestone: 3, max_fix_attempts: 3
- block_on_p0: true, block_on_p1: true, allow_continue_with_p2: true
- stop_hook_loop_enabled: false

**B. Strict preset:**
- mode: supervised-auto
- max_plan_review_rounds: 4
- max_milestones_per_run: 3, max_diff_lines: 600, max_changed_files: 10
- max_review_rounds_per_milestone: 4, max_fix_attempts: 2
- block_on_p0: true, block_on_p1: true, allow_continue_with_p2: false
- stop_hook_loop_enabled: false

**C. Custom setup — ask these questions one at a time:**

1. **User language**: A. Auto detect (recommended) B. 简体中文 C. English D. Other
2. **Collaboration mode**: A. manual B. supervised-auto (recommended) C. full-auto-safe D. Custom
3. **Planning review strength**: A. Standard (recommended) B. Strict (4 rounds) C. Very strict (5 rounds, ask on any uncertainty) D. Custom
4. **Milestone granularity**: A. Small steps (600 diff, 10 files) B. Standard (1200 diff, 20 files) (recommended) C. Large steps (2500 diff, 40 files) D. Custom
5. **Review thresholds**: max review rounds (default 3), max fix attempts (default 3), block P1 (default yes), allow P2 (default yes)
6. **Auto loop**: A. Not enabled (recommended) B. Decide later C. Enable now (warning: changes Claude Code stop behavior)

If the user chooses "Enable now" for auto loop, warn that stop-hook will change Claude Code's stop behavior, and ask for explicit confirmation before modifying `.claude/settings.json`. Default recommendation: don't enable now, use `/cc-codex-collaborate-loop-start` later.

**D. Import**: Use existing `docs/cccc/config.json` as-is, or use recommended defaults if no config found.

#### 6. Execute setup script

After gathering the user's choices, build the config and run:

```bash
# For quick/strict presets:
.claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh recommended [language]
.claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh strict [language]

# For custom config, write JSON to a temp file and pipe it:
cat /tmp/cccc-custom-config.json | .claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh custom [language]

# For import/keep:
.claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh import [language]
.claude/skills/cc-codex-collaborate/scripts/cccc-setup.sh keep [language]
```

#### 7. Setup summary

After the script completes, output a summary in the user's language:

- List generated files
- List preserved files (not overwritten)
- List what was NOT enabled (hooks, settings.json)
- Show current configuration (mode, language, review rounds, diff lines, file limit, sensitive ops policy)
- Show next steps:
  - Start a task: `/cc-codex-collaborate "your free-form task description"`
  - Check loop status: `/cc-codex-collaborate-loop-status`
  - Enable auto-continuation: `/cc-codex-collaborate-loop-start`

Setup should explain:

- generated command files
- generated `docs/cccc` files (including config.json and state.json)
- that hooks were not enabled
- that loop automation can be enabled later with `/cc-codex-collaborate-loop-start`
- current configuration summary (mode, language, thresholds)

## Configuration presets

Setup offers three configuration presets:

### A. Recommended (default)

Standard settings for most projects: `supervised-auto` mode, 3 review rounds, 1200 diff lines, 20 files per milestone, P1 blocks, P2 allowed.

### B. Strict

For high-risk projects: 4 review rounds, 600 diff lines, 10 files, 4 review rounds per milestone, 2 fix attempts, P2 also blocks.

### C. Custom

Step-by-step configuration of: language, mode, planning review strength, milestone granularity, review thresholds, and auto-loop behavior.

## Command bootstrap model

The release zip should not require users to copy `.claude/commands/`, `.claude/hooks/`, or `docs/cccc/` manually.

The zip includes only the skill, scripts, prompts, schemas, hooks templates, and command templates.

Runtime generation rules:

- `/cc-codex-collaborate setup` generates `.claude/commands/` and `docs/cccc/` (including config.json and state.json). It does NOT generate `.claude/hooks/` or modify `.claude/settings.json`.
- `/cc-codex-collaborate-loop-start` generates `.claude/hooks/`, updates `.claude/settings.json`, sets `config.json` `automation.stop_hook_loop_enabled` to `true`, and sets `state.json` mode to `full-auto-safe`.
- `/cc-codex-collaborate-loop-stop` removes only this skill's hook registrations from `.claude/settings.json`, sets `config.json` `automation.stop_hook_loop_enabled` to `false`, and reverts `state.json` mode to `supervised-auto`.

## Update command

When invoked with `update`, run:

```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-update.sh
```

When invoked with `force-update`, run:

```bash
.claude/skills/cc-codex-collaborate/scripts/cccc-update.sh --force
```

Update safely migrates:
- `docs/cccc/config.json` — adds new fields, preserves user settings
- `docs/cccc/state.json` — adds new fields, preserves runtime state
- `.claude/commands/` — syncs generated commands, preserves user-modified commands
- `.claude/hooks/` — only syncs if loop is already enabled

Update does NOT overwrite:
- `roadmap.md`, `milestone-backlog.md`, `decision-log.md`, `risk-register.md`
- `docs/cccc/reviews/`, `docs/cccc/logs/`

Update creates backup under `docs/cccc/backups/update-<timestamp>/`.

If hooks were not enabled before, update does NOT enable them.
