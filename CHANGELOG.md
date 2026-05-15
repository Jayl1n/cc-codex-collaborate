# Changelog

## 0.1.17 - 2026-05-15

### Added

- Codex review budget and frequency policy: Strict, Balanced (default), Budget, Manual, Custom.
- Risk-based Codex review scheduling: frequency varies by risk level.
- Batched Codex review for low/medium-risk milestones.
- Review fingerprint cache to avoid duplicate Codex calls on identical diffs.
- Checkpoint support: review only diffs since last Codex-approved commit.
- `/cc-codex-collaborate codex-budget` and `/cccc codex-budget` — show budget, policy, cache, checkpoint.
- `/cc-codex-collaborate review-now` and `/cccc review-now` — force immediate Codex review.
- `/cc-codex-collaborate checkpoint` and `/cccc checkpoint` — manage checkpoints (status, record, commit).
- `cccc-review-policy.py` — review decision engine based on risk, budget, cache, and triggers.
- `cccc-review-fingerprint.py` — fingerprint computation and cache management.
- `cccc-codex-budget.py` — budget display command.
- `cccc-review-now.sh` — force review command.
- `cccc-checkpoint.sh` — checkpoint management command.
- `config.codex_review_policy` section with review frequency, triggers, budget, batching, fallback, cache, and checkpoint settings.
- State fields: `codex_budget`, `codex_review_batch`, `codex_review_cache`, `checkpoint`.
- Doctor checks: review policy existence, budget usage, cache entries, pending batch, checkpoint status.
- Gates output: review policy gate with budget, cache, and checkpoint status.
- Loop-status shows Codex budget and policy mode.
- Setup summary shows Codex review policy details.
- Update migrates codex_review_policy config and state fields.

### Changed

- SKILL.md updated with Codex Review Budget and Frequency section, new commands.
- README.md and README_EN.md updated with Reducing Codex Quota Usage sections.
- Command templates updated with codex-budget, review-now, checkpoint routing.
- Codex review scripts should consult cccc-review-policy.py before calling Codex.

## 0.1.16 - 2026-05-15

### Added

- Codex unavailable policy during setup: strict pause, one-time bypass, auto bypass low/medium, always ask, custom.
- `/cc-codex-collaborate bypass-codex` and `/cccc bypass-codex` — Manage Codex bypass with status, once, apply, off subcommands.
- `/cc-codex-collaborate codex-recheck` and `/cccc codex-recheck` — Re-check bypassed gates when Codex becomes available.
- Claude adversarial bypass review mode — lower-assurance review when Codex is unavailable.
- `claude-adversarial-bypass-review.md` prompt for Claude bypass review.
- `cccc-bypass-codex.py` — Bypass command script with risk-level gating, confirmation, and artifact generation.
- `cccc-codex-recheck.sh` — Codex recheck command wrapper.
- Bypass review artifacts stored in `docs/cccc/reviews/bypass/`.
- `config.codex.bypass` section with full bypass configuration (mode, allowed reasons, risk levels, recheck requirements).
- `config.codex.unavailable_policy` — Controls Codex unavailable behavior.
- State bypass fields: `codex_bypass_enabled_for_current_gate`, `last_codex_bypass_at`, `consecutive_bypassed_gates`, `pending_codex_recheck`, `lower_assurance_mode`.
- Gate status `bypassed` — distinct from `pass`, indicates lower assurance.
- Setup creates `docs/cccc/reviews/bypass/` directory.
- Setup summary shows Codex unavailable policy and bypass configuration.
- Doctor checks bypass state: max consecutive gates, lower assurance mode, pending rechecks, high-risk bypass artifacts.
- Loop-status shows Codex bypass info: policy, bypass enabled, lower assurance, pending rechecks.
- Gates display bypass status with assurance level and recheck follow-up.
- Update migrates config bypass fields and state bypass fields.

### Changed

- SKILL.md updated with Codex Bypass Mode section, updated Mandatory Codex Gates rules, new commands.
- README.md and README_EN.md updated with Codex Unavailable and Bypass Mode sections.
- Command templates updated with bypass-codex and codex-recheck routing.
- Setup preset functions include full bypass configuration.

### Notes

- Bypass is NEVER allowed for critical-risk scenarios, wallet keys, seed phrases, real money, production deployments, or destructive operations.
- `bypassed` gate status is NOT the same as `pass`. Bypass indicates lower assurance.
- All bypass reviews require later Codex recheck when `require_later_codex_recheck = true`.

## 0.1.15 - 2026-05-15

### Added

- `/cc-codex-collaborate sync-docs` and `/cccc sync-docs` — Detect and sync manual docs/cccc document changes with interactive decision-making.
- `/cc-codex-collaborate diff-docs` and `/cccc diff-docs` — Check for document changes without modifying state (read-only).
- `/cc-codex-collaborate replan` and `/cccc replan` — Re-read project, update planning, and run Codex adversarial plan review.
- `docs/cccc/doc-index.json` for tracking document hashes and semantic roles.
- `cccc_docs.py` — Shared module for document hash detection, semantic change classification, and impact levels.
- `cccc-diff-docs.py` — Diff-docs command script.
- `cccc-sync-docs.py` — Sync-docs command script with interactive A-F options.
- `cccc-replan.sh` — Replan command wrapper with state management.
- Semantic change classification: architecture_change, stack_change, roadmap_change, milestone_change, risk_policy_change, testing_policy_change, brief_change, open_question_change, unknown_high_impact_change.
- Impact levels: low, medium, high, critical.
- Interactive sync decisions: adopt and replan, context-only, pause, ignore, view diff, custom input.
- Planning invalidation on high/critical impact documentation changes.
- Docs sync gate in loop-start, loop-status, doctor, gates, context-bundle, and Codex plan review prompt.
- `config.json` docs_sync section with tracked_documents list and invalidation policies.
- `state.json` docs sync fields: docs_sync_status, docs_changed_since_last_sync, planning_invalidated_by_doc_change, etc.
- Resume support for `NEEDS_REPLAN` status.

### Changed

- `cccc-loop-start.sh` checks docs sync status before continuing workflow; blocks with `needs_replan` or `needs_sync_docs` actions.
- `cccc-loop-status.sh` shows docs sync status, doc-index state, and recommended next step.
- `cccc-doctor.py` checks doc-index.json, tracked docs freshness, and docs_sync config.
- `cccc-gates.py` shows docs sync gate with implementation-allowed status.
- `cccc-build-context.sh` includes Document Changes Since Last Sync section.
- `cccc-resume.sh` handles NEEDS_REPLAN status with replan guidance.
- `cccc-init.sh` generates doc-index.json from template.
- `cccc-setup.sh` generates doc-index.json and shows sync-docs tip.
- `cccc-update.sh` migrates doc-index.json if missing.
- Codex plan review prompt includes document change rules.
- README.md and README_EN.md updated with Manual Documentation Sync sections and new commands.
- SKILL.md updated with Manual Documentation Sync section, sync-docs, diff-docs, replan subcommands, and updated public commands summary.
- Command templates updated with sync-docs, diff-docs, replan routing and new loop-start actions.

## 0.1.14 - 2026-05-15

### Added

- Short slash command aliases: `/cccc`, `/cccc-loop-status`, `/cccc-loop-start`, `/cccc-loop-stop`.
- Alias command templates with `alias-for` markers for safe update/overwrite.
- Doctor checks alias commands existence (WARN if missing).
- Loop-status shows alias installation status.

### Changed

- README.md and README_EN.md use `/cccc` short aliases in command documentation.
- SKILL.md documents short aliases and their equivalence to full commands.
- All command template versions bumped to 0.1.14.

## 0.1.13 - 2026-05-15

### Added

- `/cc-codex-collaborate force-update` — Force sync skill templates to workspace regardless of version number.
- `/cc-codex-collaborate reset` / `reset state` — Reset state machine runtime state and rehydrate current progress from docs, reviews, and git history.
- `/cc-codex-collaborate doctor` — One-shot diagnostics for installation, config, hooks, Codex, gates, and context. Outputs PASS/WARN/FAIL with fix suggestions.
- `/cc-codex-collaborate rebuild-context` — Rebuild context-bundle.md for Codex review.
- `/cc-codex-collaborate gates` — Show plan/milestone/final/safety gate status and whether each phase is allowed.
- `/cc-codex-collaborate repair` — Auto-fix safe inconsistencies (deprecated fields, missing hooks, missing commands, recoverable milestone ID).
- `/cc-codex-collaborate trace` — Show recent state machine events from logs, reviews, and decision log.
- `/cc-codex-collaborate dev-smoke` — Developer self-test for JSON/shell/Python validation and core file checks.
- `/cc-codex-collaborate codex-check` — Check Codex CLI availability (wraps existing `cccc-codex-check.sh`).
- `cccc-doctor.py` — Diagnostic script with PASS/WARN/FAIL output.
- `cccc-gates.py` — Gate status display script.
- `cccc-rehydrate-state.py` — State rehydration from planning docs, reviews, and git history.
- `cccc-reset.sh` — Reset command wrapper with backup and report.
- `cccc-repair.sh` — Safe auto-repair script with backup.
- `cccc-trace.py` — Event timeline script.
- `cccc-dev-smoke.sh` — Developer smoke test script.
- `cccc-update.sh --force` flag — Force sync regardless of version.
- State rehydration fields: `last_state_rehydrated_at`, `last_state_rehydrate_sources`, `last_state_rehydrate_reason`, `rehydrate_confidence`.

### Changed

- `cccc-update.sh` now supports `--force` flag for force-update mode. Normal update skips when version is unchanged.
- SKILL.md updated with Maintenance commands section and all new subcommands.
- README.md / README_EN.md updated with maintenance and debugging command tables.
- Main command template argument-hint expanded with all new subcommands.

## 0.1.12 - 2026-05-15

### Fixed

- **P0**: Stop hook stdout now contains only JSON. Previously, human-readable log messages (`[cccc-stop] BLOCK:...`, `[cccc-stop] EXIT:...`) were mixed with JSON output on stdout, causing Claude Code to fail parsing the `decision: "block"` response and stop anyway. All log messages now go to stderr (`>&2`), ensuring reliable block behavior.

### Changed

- Command templates use CRITICAL-level emphasis to prevent Claude Code from summarizing and stopping after loop-start when `continue_now` is detected. Claude Code must immediately execute state machine steps instead of waiting for the stop hook.

## 0.1.10 - 2026-05-15

### Added

- `cccc-detect-workflow.py` — Workflow detection script that analyzes planning docs to find active milestones.
- Workflow state rehydration: loop-start can recover `current_milestone_id` from `milestone-backlog.md`, `roadmap.md`, `current-state.md`, or `open-questions.md`.
- State mismatch diagnostics in loop-status: detects planning docs without `current_milestone_id` and shows candidate milestones.
- State repair mode in resume: when state.json is missing `current_milestone_id` but planning docs exist, offers milestone selection.
- State fields: `last_state_repaired_at`, `last_state_repair_reason`.

### Changed

- Loop-start workflow detection now uses `cccc-detect-workflow.py` instead of hardcoded bash logic.
- Loop-start no longer incorrectly prompts for a new task when planning docs already exist.
- Loop-start outputs state repair info when milestone is recovered from docs.
- Loop-status shows state mismatch warning and candidate milestone when applicable.
- Resume supports state repair with `--strategy use-detected` for non-interactive milestone recovery.

## 0.1.9 - 2026-05-15

### Added

- `/cc-codex-collaborate resume` — Resume a paused workflow with safe, status-specific recovery rules.
- `cccc-resume.sh` — Resume script with non-interactive `--strategy` and `--confirm` arguments.
- Safe resume semantics: each pause status has specific recovery rules (human questions, Codex check, system error confirmation, secret configuration, sensitive operation alternatives, review budget extension).
- `READY_TO_CONTINUE` status for post-resume state machine re-entry.
- State fields: `previous_status`, `resume_reason`, `resume_strategy`, `last_resumed_at`, `last_human_decision`.
- Machine-readable loop-start markers: `CCCC_LOOP_START_RESULT`, `CCCC_WORKFLOW_ACTION`, `CCCC_WORKFLOW_REASON`.
- Loop-status resume guidance: suggests next action based on current status.
- Stop-hook empty-spin prevention: `SETUP_COMPLETE` with no milestone/backlog does not block.
- Stop-hook supports `READY_TO_CONTINUE` and `PAUSED_FOR_CODEX` in pause-state list.

### Changed

- `/cc-codex-collaborate-loop-start` now checks for active workflows after enabling hooks. Outputs `CCCC_WORKFLOW_ACTION=continue_now|needs_resume|needs_task|done` with human guidance.
- Stop-hook reason now emphasizes it is not a background worker and Claude Code must execute multiple state-machine steps per continuation.
- Loop-start output no longer writes `state.json: mode = full-auto-safe` (mode belongs to config.json only).
- README (zh/en) updated with Resume and loop-start behavior sections.
- SKILL.md updated with Resume command section, updated state machine, updated loop-start semantics.

## 0.1.8 - 2026-05-15

### Added

- Exit reason logging in `cccc-stop.sh` — every exit point now outputs a clear reason for debugging:
  - EXIT: jq not available
  - EXIT: config.json or state.json not found
  - EXIT: loop not enabled
  - EXIT: mode is not full-auto-safe
  - EXIT: terminal/pause status
  - EXIT: pause_reason present
  - EXIT: recursion guard
  - EXIT: continuation budget exhausted
  - BLOCK: continuing loop (with status/milestone/continuations details)

### Changed

- README/README_EN version numbers now correctly reflect current version.

## 0.1.7 - 2026-05-15

### Added

- `/cc-codex-collaborate update` — Safe workspace migration after skill upgrade.
- `cccc-update.sh` — Update script for config/state/command/hook sync.
- `cccc-migrate-config.py` — Config migration with deep merge, preserves user settings.
- `cccc-migrate-state.py` — State migration with deep merge, preserves runtime state.
- Generated command markers (`generated-by`, `generated-file`, `template-version`) for safe command updates.
- `skill.installed_version`, `skill.workspace_schema_version`, `skill.last_updated_at` in config.json.
- `workspace_schema_version`, `last_migration_at`, `last_migration_from_version`, `last_migration_to_version` in state.json.
- Version and schema status in `cccc-loop-status.sh`.
- Update recommendation in loop-status when skill version differs from project version.
- Update backups under `docs/cccc/backups/update-<timestamp>/`.

### Changed

- `cccc-loop-status.sh` now shows skill version, project installed version, schema versions, migration history, and update recommendation.
- Command templates now include generated markers for safe updates.
- README (zh/en) updated with Updating section and update command reference.
- SKILL.md updated with update subcommand handling and public commands summary.

### Notes

- `update` does NOT download new skill. Assumes user already installed new version.
- `update` does NOT enable hooks if not already enabled.
- `update` does NOT overwrite user planning documents (roadmap, milestone-backlog, decision-log, risk-register).
- `update` does NOT overwrite reviews or logs.

## 0.1.4 - 2026-05-15

### Added

- **Mandatory Codex Gates** — P0 invariant: Codex review is NEVER optional.
  - No Codex plan review, no implementation.
  - No Codex milestone review, no milestone pass.
  - No Codex final review, no task completion.
  - Codex unavailable means pause, not skip.
- `cccc-codex-check.sh` — Check Codex CLI availability before reviews.
- `cccc-assert-codex-gates.py` — Assert gate conditions before proceeding (assert-plan-approved, assert-milestone-approved, assert-final-approved).
- `cccc-codex-final-review.sh` — Run final review before task completion.
- State fields for Codex gates: `codex_plan_review_status`, `codex_final_review_status`, `last_codex_*_review_file`, `codex_unavailable_reason`, `current_milestone_codex_review_status`.
- Config fields for Codex enforcement: `codex.enabled`, `codex.required`, `codex.fail_closed`, `codex.cli_command`, `require_plan_review_before_implementation`, `require_milestone_review_before_pass`, `require_final_review_before_done`.
- Context bundle now includes untracked file contents preview (safe small text files only).

### Changed

- `cccc-codex-plan-review.sh` now checks Codex availability, updates state with review status, and pauses if Codex fails.
- `cccc-codex-milestone-review.sh` now checks Codex availability, updates milestone review status, and pauses if Codex fails.
- `cccc-build-context.sh` now includes untracked files preview (limited to 200 lines, 20KB per file, excludes secrets/binary).
- SKILL.md updated with "Mandatory Codex Gates" section and strict invariants.
- Version bumped to 0.1.4.

### Fixed

- **P0**: Milestones were being marked passed without Codex review. Now enforced via gate assertions and state tracking.

## 0.1.3 - 2026-05-14

### Added

- Interactive setup wizard with three configuration presets: recommended, strict, custom.
- `docs/cccc/config.json` for project-level configuration (mode, thresholds, language, safety, automation, codex behavior).
- Configuration presets: Quick (recommended), Strict (high-risk), Custom (step-by-step).
- Existing config detection: setup asks whether to keep, update, backup-and-rebuild, or exit.
- Config backup on rebuild: `docs/cccc/backups/config.<timestamp>.json`.
- `cccc_config_value()` helper in `cccc-common.sh` for reading config values.
- `docs/cccc/backups/` directory in workspace layout.

### Changed

- `docs/cccc/state.json` now only stores runtime state (milestone, status, review counts, pause reason). All thresholds moved to `config.json`.
- Setup is now an interactive wizard, not a silent bootstrap. It detects language, offers presets, and summarizes.
- Loop scripts (`loop-start`, `loop-stop`, `loop-status`) now read from `config.json` instead of `state.json`.
- `loop-stop` updates `config.json` (disables `automation.stop_hook_loop_enabled`, reverts mode to `supervised-auto`).
- `loop-start` updates `config.json` (enables loop, sets mode to `full-auto-safe`).
- Removed public `init` subcommand. Setup is the sole entry point; init is internal only.
- `cccc-init.sh` preserves existing `user_language` instead of overwriting on re-init.
- Version bumped to 0.1.3.

### Removed

- Public `/cc-codex-collaborate init` subcommand.
- Thresholds from `state.json` (now in `config.json`).

## 0.1.2 - 2026-05-14

### Changed

- Added first-run setup flow: `/cc-codex-collaborate setup`.
- The release zip no longer pre-populates root `.claude/commands/`.
- Setup now generates `.claude/commands/` from `.claude/skills/cc-codex-collaborate/templates/commands/`.
- Setup also generates or verifies the runtime workspace under `docs/cccc/`.
- Setup reports generated files, preserved files, hook state, and simple usage.
- Hooks remain opt-in and are enabled only by `/cc-codex-collaborate-loop-start` or `/cc-codex-collaborate loop-start`.

## 0.1.1 - 2026-05-14

### Changed

- Replaced old short loop command aliases with explicit commands:
  - `/cc-codex-collaborate-loop-status`
  - `/cc-codex-collaborate-loop-start`
  - `/cc-codex-collaborate-loop-stop`
- Moved hook scripts into the skill package under `.claude/skills/cc-codex-collaborate/hooks/`.
- Added loop start/stop/status scripts that install, configure, inspect, and remove CCCC hook registrations.
- Changed `docs/cccc` to a runtime-generated workspace. The zip ships templates under `.claude/skills/cc-codex-collaborate/templates/cccc/` instead of pre-populating a project workspace.

## 0.1.0 - 2026-05-14

### Added

- Initial Claude Code + Codex collaboration skill.
- Project discovery, planning, Claude self-review, Codex adversarial plan review, milestone loop, safety gates, language detection, and brainstorming-style human questions.
