# Changelog

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
