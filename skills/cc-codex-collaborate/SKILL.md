---
name: cc-codex-collaborate
version: 0.1.18
description: Coordinate Claude Code and Codex in a milestone-based collaboration loop. Claude Code discovers the project, plans, implements, and fixes; Codex performs adversarial planning review and read-only milestone review. Working documents are stored under docs/cccc.
argument-hint: "[task description]"
---

# cc-codex-collaborate

You are Claude Code acting as the primary orchestrator and implementer.

Use this skill when the user wants Claude Code and Codex to collaborate on a coding task through project discovery, adversarial planning review, milestone implementation, Codex review, and iterative fixes.

The working document root is always:

```text
docs/cccc
```

## Core invariants

These rules are non-negotiable and apply at all times:

1. **No Codex plan review, no implementation.**
2. **No Codex milestone review, no milestone pass.**
3. **No Codex final review, no task completion.**
4. **Codex unavailable means pause, not skip.**
5. **Hard pause conditions** (secrets, wallet keys, production, real money, destructive ops, threshold failures) **never auto-continue**.
6. **All thresholds read from `docs/cccc/config.json`**. If missing, prompt user to run `/cccc setup`.
7. **Runtime state read from `docs/cccc/state.json`**.
8. **Detect and use the user's primary language** throughout all human-facing output.
9. **Context bundle before every Codex call** — regenerate `docs/cccc/context-bundle.md`.
10. **Bypass is NOT pass** — `bypassed` gate status indicates lower assurance.

## Documentation loading map

Detailed behavior rules are split into focused documents. Load them as needed:

| Document | Content | When to load |
| --- | --- | --- |
| `docs/workflow.md` | State machine, milestone loop, project discovery, planning, self-review, progress format | Starting a task or continuing state machine |
| `docs/setup.md` | Setup wizard flow, configuration presets, bootstrap model, update command | `setup`, `update`, `force-update` subcommands |
| `docs/safety-policy.md` | Hard pause conditions, role separation, brainstorming interaction | Any safety-sensitive decision or human question |
| `docs/codex-review.md` | Mandatory Codex gates, adversarial plan review, context bundle rule | Before/after any Codex review gate |
| `docs/codex-bypass.md` | Codex bypass mode, Claude adversarial bypass review, recheck | Codex unavailable or bypass-codex/codex-recheck commands |
| `docs/codex-budget.md` | Review budget/frequency, fingerprint cache, checkpoint, review-policy | Review scheduling or budget/cache/checkpoint commands |
| `docs/docs-sync.md` | Manual documentation sync, sync-docs, diff-docs, replan | sync-docs, diff-docs, replan commands |
| `docs/testing-policy.md` | Thresholds, quality gates, language detection, modes | Any threshold or quality gate check |
| `docs/maintenance.md` | Reset, doctor, rebuild-context, gates, repair, trace, dev-smoke, codex-check, resume | Any maintenance subcommand |
| `docs/hooks.md` | Stop hook automation rule, loop control commands | loop-start, loop-stop, or stop hook behavior |
| `docs/state-and-config.md` | config.json vs state.json separation, runtime workspace layout | Reading/writing config or state |
| `docs/commands.md` | Subcommand handling, public commands summary, aliases | Command routing or alias lookup |

All doc files are located under `.claude/skills/cc-codex-collaborate/docs/`.

## Command routing

Parse the first argument to determine the action:

- **`setup`** → Load `docs/setup.md`. Run setup wizard. Do NOT start any task.
- **`update`** → Load `docs/setup.md`. Run `scripts/cccc-update.sh`. Safe migration.
- **`force-update`** → Load `docs/setup.md`. Run `scripts/cccc-update.sh --force`.
- **`resume`** → Load `docs/maintenance.md` and `docs/codex-review.md`. Resume paused workflow.
- **`reset`** / **`reset state`** → Load `docs/maintenance.md`. Reset state machine.
- **`doctor`** → Load `docs/maintenance.md`. Run diagnostics.
- **`rebuild-context`** → Load `docs/maintenance.md`. Rebuild context-bundle.
- **`gates`** → Load `docs/maintenance.md`. Show gate status.
- **`repair`** → Load `docs/maintenance.md`. Auto-fix inconsistencies.
- **`trace`** → Load `docs/maintenance.md`. Show event timeline.
- **`dev-smoke`** → Load `docs/maintenance.md`. Developer self-test.
- **`codex-check`** → Load `docs/maintenance.md`. Check Codex CLI.
- **`sync-docs`** → Load `docs/docs-sync.md`. Detect and sync doc changes.
- **`diff-docs`** → Load `docs/docs-sync.md`. Read-only doc change check.
- **`replan`** → Load `docs/docs-sync.md` and `docs/codex-review.md`. Re-plan project.
- **`bypass-codex`** → Load `docs/codex-bypass.md`. Manage Codex bypass.
- **`codex-recheck`** → Load `docs/codex-bypass.md`. Re-check bypassed gates.
- **`codex-budget`** → Load `docs/codex-budget.md`. Show review budget.
- **`review-now`** → Load `docs/codex-budget.md`. Force immediate Codex review.
- **`checkpoint`** → Load `docs/codex-budget.md`. Manage checkpoints.
- **`status`** → Run `scripts/cccc-status.sh` and summarize.
- **`loop-status`** → Load `docs/hooks.md`. Run `scripts/cccc-loop-status.sh` and summarize.
- **`loop-start`** → Load `docs/hooks.md`. Run `scripts/cccc-loop-start.sh`. **MUST act on CCCC_WORKFLOW_ACTION marker immediately.**
- **`loop-stop`** → Load `docs/hooks.md`. Run `scripts/cccc-loop-stop.sh` and summarize.
- **Any other text** → Treat as the user's coding task. Start the full collaboration loop.

### loop-start behavior — CRITICAL

After running cccc-loop-start.sh, check the CCCC_WORKFLOW_ACTION marker in the output:

- **`continue_now`** — **Do NOT summarize and stop.** You MUST immediately read `docs/cccc/config.json` and `docs/cccc/state.json`, determine the current milestone and status, and execute the next state-machine step right now in this same turn.
- **`needs_resume`** — The workflow is paused. Execute `/cccc resume` or tell the user to run it.
- **`needs_task`** — No active workflow. Tell the user to run `/cccc "task description"`.
- **`needs_replan`** — Planning invalidated by doc changes. Tell the user to run `/cccc replan`.
- **`needs_sync_docs`** — Documents changed since last sync. Tell the user to run `/cccc sync-docs`.
- **`done`** — The workflow is already completed. Tell the user to start a new task.

**For `continue_now`: You are NOT done after running the loop-start script. The script output tells you to continue. Continuing means executing state machine steps NOW, not waiting for the stop hook.**

## Before starting a task

If `docs/cccc/config.json` is missing, prompt the user to run `/cccc setup` first. Do not proceed without a valid config.

## Default task execution algorithm

When the user provides a task description (not a known subcommand), follow this sequence:

1. **Detect language** — Identify user's primary language. Store in `config.json`.
2. **Ensure setup** — If `docs/cccc/config.json` missing, prompt setup.
3. **Discover project** — Inspect codebase, create/update project docs. (See `docs/workflow.md`)
4. **Build context** — Generate `docs/cccc/context-bundle.md`. (See `docs/codex-review.md`)
5. **Plan** — Create roadmap, milestone backlog. (See `docs/workflow.md`)
6. **Self-review** — Claude Code challenges its own plan. (See `docs/workflow.md`)
7. **Codex plan review** — Adversarial review by Codex. Must pass. (See `docs/codex-review.md`)
8. **Implement milestones** — One at a time, smallest coherent change. (See `docs/workflow.md`)
9. **Review each milestone** — Claude self-review → Codex milestone review. Must pass. (See `docs/codex-review.md`)
10. **Fix and iterate** — Fix findings → re-review → next milestone. (See `docs/workflow.md`)
11. **Final review** — Codex final review before marking DONE. Must pass. (See `docs/codex-review.md`)
12. **Record completion** — Update state, write summary in user's language.

At any point, if a hard pause condition triggers (see `docs/safety-policy.md`), pause immediately and ask the human.

## Explicit non-goals

This skill does NOT:

- Download or install Codex CLI
- Provide a substitute for human judgment on security, financial, or production decisions
- Auto-enable hooks without explicit user action
- Modify files outside of `docs/cccc/` and `.claude/commands/`/`.claude/hooks/` (except when implementing the user's actual coding task)
- Store real secrets, API keys, wallet keys, or credentials in any file
- Continue past pause conditions without human confirmation
