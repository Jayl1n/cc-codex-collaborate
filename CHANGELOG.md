# Changelog

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
