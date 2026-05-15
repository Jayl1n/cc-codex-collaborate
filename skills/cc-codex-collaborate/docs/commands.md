# Commands Reference

This document defines subcommand handling, public commands, and alias mappings.

## Short aliases

`/cccc` = `/cc-codex-collaborate`, `/cccc-loop-status` = `/cc-codex-collaborate-loop-status`, `/cccc-loop-start` = `/cc-codex-collaborate-loop-start`, `/cccc-loop-stop` = `/cc-codex-collaborate-loop-stop`. Aliases call the same scripts and follow the same state-machine rules. They are convenience wrappers, not separate implementations.

## Subcommand handling

Interpret the first argument after `/cc-codex-collaborate` as a subcommand when it matches one of these values:

- `setup`: run `scripts/cccc-setup.sh`, the interactive configuration wizard. Do not start planning or implementation.
- `update`: run `scripts/cccc-update.sh`, safe workspace migration after skill upgrade. Sync config/state fields, commands, and enabled hooks. Does NOT start any task, does NOT enable hooks, does NOT run Codex review.
- `resume`: resume a paused workflow. See [[maintenance]].
- `sync-docs`: run `python3 scripts/cccc-sync-docs.py` to detect and sync docs/cccc document changes. Interactive.
- `diff-docs`: run `python3 scripts/cccc-diff-docs.py` to check for document changes without modifying state.
- `replan`: run `scripts/cccc-replan.sh` to re-read project and docs, update planning, and run Codex adversarial plan review.
- `bypass-codex`: run `python3 scripts/cccc-bypass-codex.py` to manage Codex bypass. Subcommands: `status`, `once`, `apply`, `off`.
- `codex-recheck`: run `scripts/cccc-codex-recheck.sh` to re-check bypassed gates when Codex becomes available.
- `codex-budget`: run `python3 scripts/cccc-codex-budget.py` to show Codex review budget and policy.
- `review-now`: run `scripts/cccc-review-now.sh` to force immediate Codex review for current milestone or batch.
- `checkpoint`: run `scripts/cccc-checkpoint.sh` to manage Codex-approved checkpoints. Subcommands: status, record, commit.
- `status`: run `scripts/cccc-status.sh` and summarize.
- `loop-status`: run `scripts/cccc-loop-status.sh` and summarize.
- `loop-start`: run `scripts/cccc-loop-start.sh` and summarize.
- `loop-stop`: run `scripts/cccc-loop-stop.sh` and summarize.

If no known subcommand is provided, treat the arguments as the user's coding task. Before doing project discovery or planning, ensure setup has been performed. If `docs/cccc/config.json` is missing, prompt the user to run `/cc-codex-collaborate setup` first.

## Public commands summary

| Command | Purpose |
| --- | --- |
| `/cc-codex-collaborate setup` | First-time setup. Interactive configuration wizard. Generates docs/cccc and .claude/commands. Does NOT enable hooks. |
| `/cc-codex-collaborate update` | Safe migration after skill upgrade. Syncs config/state fields, commands, enabled hooks. Does NOT overwrite user planning/review history. Does NOT enable hooks if not already enabled. |
| `/cc-codex-collaborate force-update` | Force sync regardless of version number. Same as update but ignores version check. |
| `/cc-codex-collaborate resume` | Resume a paused workflow. Does NOT bypass Codex gates, safety pauses, or secret requirements. |
| `/cc-codex-collaborate reset` / `reset state` | Reset state machine runtime state and rehydrate from docs. Does NOT delete planning docs, reviews, or logs. |
| `/cc-codex-collaborate doctor` | Diagnose installation, config, hooks, Codex, gates, and context. Does NOT modify files. |
| `/cc-codex-collaborate rebuild-context` | Rebuild context-bundle.md for Codex. Does NOT modify milestone status. |
| `/cc-codex-collaborate sync-docs` | Detect and sync manual docs/cccc document changes. Interactive. May invalidate planning. |
| `/cc-codex-collaborate diff-docs` | Check for document changes without modifying state. Read-only. |
| `/cc-codex-collaborate replan` | Re-read project, update planning, run Codex adversarial plan review. |
| `/cc-codex-collaborate bypass-codex` | Manage Codex bypass. Subcommands: status, once, apply, off. Generates lower-assurance Claude adversarial review. |
| `/cc-codex-collaborate codex-recheck` | Re-check bypassed gates when Codex becomes available. Resolves pending rechecks. |
| `/cc-codex-collaborate codex-budget` | Show Codex review budget, policy, cache, and checkpoint status. Does NOT modify files. |
| `/cc-codex-collaborate review-now` | Force immediate Codex review for current milestone or pending batch. |
| `/cc-codex-collaborate checkpoint` | Manage Codex-approved checkpoints. Subcommands: status, record, commit. |
| `/cc-codex-collaborate gates` | Show plan/milestone/final/safety/docs-sync/review-policy gate status. Shows bypass status. Does NOT modify files. |
| `/cc-codex-collaborate repair` | Auto-fix safe inconsistencies. Backs up before modifying. Does NOT bypass Codex gates or safety pauses. |
| `/cc-codex-collaborate trace` | Show recent state machine events. Does NOT modify files. |
| `/cc-codex-collaborate dev-smoke` | Developer self-test for skill installation. Does NOT modify user files. |
| `/cc-codex-collaborate codex-check` | Check Codex CLI availability. |
| `/cc-codex-collaborate "task"` | Start user's free-form task description. Full collaboration loop. |
| `/cc-codex-collaborate-loop-status` | Show loop/hooks/Codex gates/version status. Includes resume guidance. |
| `/cc-codex-collaborate-loop-start` | Enable stop-hook auto-continuation. If active workflow exists, immediately continue state machine. |
| `/cc-codex-collaborate-loop-stop` | Disable stop-hook auto-continuation. |
